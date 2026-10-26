extends SceneTree
## Pruebas de la visita al casino (scripts/casino/casino_visit.gd): la racha y el pozo del jackpot, que ya no son reglas de la casa sino un boost y un consumible, y su efecto en las tres mesas (headless).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_casino_visit.gd

const Visit := preload("res://scripts/casino/casino_visit.gd")
const Roulette := preload("res://scripts/casino/roulette.gd")
const Slots := preload("res://scripts/casino/slots.gd")
const Blackjack := preload("res://scripts/casino/blackjack.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Items := preload("res://scripts/datos/items.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_catalogo()
	test_sin_efectos()
	test_racha()
	test_racha_consumible()
	test_pozo()
	test_sin_visita()
	print("tests de la visita al casino terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func make_run(boosts: Array = [], tier := 1, claridad := 5000) -> RunState:
	var run := RunState.new()
	run.claridad = claridad
	run.stage = 1
	run.boosts.assign(boosts)
	Visit.enter(run, tier)
	return run


func test_catalogo() -> void:
	var racha := Items.get_item("racha_de_la_casa")
	var visita := Items.get_item("racha_de_visita")
	var pozo := Items.get_item("pozo_del_jackpot")
	check(racha.type == Items.Type.BOOST and racha.tier == Items.Tier.RARO, "la Racha de la casa es un boost raro")
	check(visita.type == Items.Type.CONSUMABLE and Items.CASINO_USABLE.has("racha_de_visita"), "la Racha de visita es un consumible del casino")
	check(pozo.type == Items.Type.BOOST and pozo.tier == Items.Tier.EPICO, "el Pozo del jackpot es un boost épico")
	for id in ["racha_de_la_casa", "racha_de_visita", "pozo_del_jackpot", "caja_fuerte", "alcancia"]:
		check(preload("res://scripts/ui/item_icons.gd").has_icon(id), "%s tiene ícono" % id)


## Sin boosts, ninguna sala tiene efectos: perder no devuelve nada, ni hay racha, ni pozo (ya no hay reglas de la casa).
func test_sin_efectos() -> void:
	for tier in 4:
		var run := make_run([], tier)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		var price := Roulette.run_price(run)
		var antes := run.claridad
		var res := Roulette.resolve(run, Roulette.Bet.PLENO, [1], rng, 5)   # cae el 5: se pierde
		check(not res.won and res.rules.total == 0 and res.rules.notes.is_empty(), "nivel %d: perder no devuelve nada" % tier)
		check(run.claridad == antes - price, "nivel %d: la claridad refleja la pérdida entera" % tier)
		Visit.settle(run, price, price * 2, true, false)
		Visit.settle(run, price, price * 2, true, false)
		var out := Visit.settle(run, price, price * 2, true, false)
		check(out.bonus == 0 and Visit.pool(run) == 0, "nivel %d: sin boosts no hay racha ni pozo" % tier)
	var run2 := make_run([], 2)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 2
	var s := Slots.new(run2, rng2)
	s.start()
	check(s.price == Roulette.run_price(run2), "las tragamonedas cobran siempre una ficha (ya no hay apuesta libre)")
	var bj := Blackjack.new(run2, rng2)
	bj.deal([Vector2i(2, 0), Vector2i(5, 1), Vector2i(10, 2), Vector2i(9, 3), Vector2i(10, 0)])
	check(bj.bet == Roulette.run_price(run2), "y el blackjack también")


## Racha de la casa: cada victoria seguida suma 10 % al pago de la siguiente (tope 50 %); perder corta la racha.
func test_racha() -> void:
	var run := make_run(["racha_de_la_casa"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var price := Roulette.run_price(run)
	check(Visit.streak_bonus(1) == 0.0 and is_equal_approx(Visit.streak_bonus(2), 0.1) and is_equal_approx(Visit.streak_bonus(6), 0.5) and is_equal_approx(Visit.streak_bonus(60), 0.5), "el extra sube 10 % por victoria desde la segunda y topa en 50 %")
	var out := Visit.settle(run, price, price * 2, true, false)
	check(out.bonus == 0 and run.casino_visit.streak == 1, "la primera victoria no suma extra pero empieza la racha")
	var antes := run.claridad
	out = Visit.settle(run, price, price * 2, true, false)
	check(out.bonus == int(round(price * 2 * 0.1)) and run.claridad == antes + out.bonus and run.casino_visit.streak == 2, "la segunda suma 10 % del pago")
	for i in 10:
		out = Visit.settle(run, price, price * 2, true, false)
	check(out.bonus == int(round(price * 2 * 0.5)), "el extra tiene tope de 50 %")
	out = Visit.settle(run, price, 0, false, false)
	check(run.casino_visit.streak == 0 and out.total == 0, "una pérdida corta la racha")
	Visit.settle(run, price, price, false, false)
	check(run.casino_visit.streak == 0, "un empate no suma")
	Visit.settle(run, price, price * 3, true, false)
	Visit.settle(run, price, price, false, false)
	check(run.casino_visit.streak == 1, "un empate no corta la racha")
	Visit.enter(run, 1)
	var res := Roulette.resolve(run, Roulette.Bet.RANGO, [1, 2, 3, 4, 5, 6, 7, 8, 9], rng, 3)
	check(res.won and run.casino_visit.streak == 1, "ganar un premio en la ruleta suma a la racha")


## Racha de visita (consumible): lo mismo, pero sólo el resto de la visita.
func test_racha_consumible() -> void:
	var run := make_run()
	var price := Roulette.run_price(run)
	Visit.settle(run, price, price * 2, true, false)
	Visit.settle(run, price, price * 2, true, false)
	check(run.casino_visit.streak == 0, "sin racha encendida las victorias no cuentan")
	check(Visit.encender_racha(run) and not Visit.encender_racha(run), "se enciende una vez por visita")
	Visit.settle(run, price, price * 2, true, false)
	var out := Visit.settle(run, price, price * 2, true, false)
	check(out.bonus == int(round(price * 2 * 0.1)), "con la racha encendida la segunda victoria suma 10 %")
	Visit.enter(run, 1)
	check(not Visit.racha_activa(run), "en la próxima visita ya no está encendida")
	var vacio := RunState.new()
	check(not Visit.encender_racha(vacio), "sin visita no se puede encender")


## Pozo del jackpot: lo perdido alimenta un pozo; el premio mayor se lo lleva.
func test_pozo() -> void:
	var run := make_run(["pozo_del_jackpot"], 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var price := Roulette.run_price(run)
	check(Visit.pool(run) == 0, "el pozo empieza vacío")
	Roulette.resolve(run, Roulette.Bet.PLENO, [1], rng, 5)
	check(Visit.pool(run) == int(round(price * 0.5)), "una pérdida suma la mitad de lo perdido al pozo")
	Roulette.resolve(run, Roulette.Bet.PLENO, [1], rng, 5)
	check(Visit.pool(run) == int(round(price * 0.5)) * 2, "y otra más")
	var pozo := Visit.pool(run)
	var antes := run.claridad
	var res := Roulette.resolve(run, Roulette.Bet.PLENO, [1], rng, 1)   # pleno: premio mayor
	check(res.won and res.rules.jackpot == pozo and Visit.pool(run) == 0, "un pleno ganado se lleva el pozo")
	check(res.claridad_delta >= pozo - price and run.claridad >= antes - price + pozo, "el pozo se suma a lo que ya paga el pleno")
	Roulette.resolve(run, Roulette.Bet.PLENO, [1], rng, 5)
	var pozo2 := Visit.pool(run)
	Roulette.resolve(run, Roulette.Bet.MITAD, [1, 2, 3, 4, 5, 6], rng, 2)
	check(Visit.pool(run) == pozo2, "un acierto común no toca el pozo")
	var s := Slots.new(run, rng)
	s.start()
	s.reels = [4, 4, 4]
	var sr := s.collect()
	check(sr.rules.jackpot == pozo2, "tres coronas se llevan el pozo")
	Roulette.resolve(run, Roulette.Bet.PLENO, [1], rng, 5)
	var pozo3 := Visit.pool(run)
	var bj := Blackjack.new(run, rng)
	bj.deal([Vector2i(5, 0), Vector2i(6, 1), Vector2i(1, 2), Vector2i(9, 3), Vector2i(13, 0)])   # se saca del final: jugador K y A... (blackjack)
	if Blackjack.is_blackjack(bj.player) and not Blackjack.is_blackjack(bj.dealer):
		check(bj.result.rules.jackpot == pozo3, "un blackjack se lleva el pozo")
	var sin := make_run([], 3)
	Roulette.resolve(sin, Roulette.Bet.PLENO, [1], rng, 5)
	check(Visit.pool(sin) == 0, "sin el boost no hay pozo")


## Sin visita (pruebas, entrenamiento) no hay efectos.
func test_sin_visita() -> void:
	var run := RunState.new()
	run.claridad = 1000
	run.boosts.assign(["racha_de_la_casa", "pozo_del_jackpot"])
	var rng := RandomNumberGenerator.new()
	var out := Visit.settle(run, 50, 0, false, false)
	check(out.total == 0 and not Visit.active(run) and not Visit.racha_activa(run), "sin visita no hay ningún efecto")
	var res := Roulette.resolve(run, Roulette.Bet.PLENO, [1], rng, 5)
	check(res.claridad_delta == -res.price and res.rules.total == 0, "la ruleta paga como siempre")
