extends SceneTree
## Pruebas de las reglas de la casa por nivel de sala (racha, apuesta libre, jackpot) y de su efecto en las tres mesas (headless).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_casino_rules.gd

const Rules := preload("res://scripts/casino_rules.gd")
const Roulette := preload("res://scripts/roulette.gd")
const Slots := preload("res://scripts/slots.gd")
const Blackjack := preload("res://scripts/blackjack.gd")
const RunState := preload("res://scripts/run_state.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_catalog()
	test_taberna_sin_regla()
	test_racha()
	test_libre()
	test_jackpot()
	test_no_visit()
	print("tests de las reglas de la casa terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func make_run(tier: int, claridad := 5000) -> RunState:
	var run := RunState.new()
	run.claridad = claridad
	run.stage = 1
	Rules.enter(run, tier)
	Rules.accept(run)
	return run


func test_catalog() -> void:
	check(Rules.RULES.size() == 4, "hay una regla por nivel de sala")
	check(Rules.rule_of(0).id == "" and Rules.rule_of(1).id == "racha" and Rules.rule_of(2).id == "libre" and Rules.rule_of(3).id == "jackpot", "taberna: sin regla, salón: racha, casino: apuesta libre, gran casino: jackpot")
	check(Rules.rule_of(99).id == "jackpot" and Rules.rule_of(-3).id == "", "un nivel fuera de rango se acota")


## Taberna: no tiene regla de la casa (antes tenía el "Fiado"): perder no devuelve nada, en ninguna de las tres mesas.
func test_taberna_sin_regla() -> void:
	var run := make_run(0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var price := Roulette.run_price(run)
	var before := run.claridad
	var res := Roulette.resolve(run, Roulette.Bet.PLENO, [1], rng, 5)   # cae el 5: se pierde
	check(not res.won and res.rules.refund == 0 and res.rules.notes.is_empty(), "la primera pérdida no devuelve nada")
	check(run.claridad == before - price and res.claridad_delta == -price, "la claridad refleja la pérdida entera")
	Rules.enter(run, 0)
	Rules.accept(run)
	var s := Slots.new(run, rng)
	s.start()
	s.reels = [0, 1, 2]
	var sr := s.collect()
	check(sr.claridad == 0 and sr.rules.refund == 0, "las tragamonedas sin premio no devuelven nada")
	Rules.enter(run, 0)
	Rules.accept(run)
	var bj := Blackjack.new(run, rng)
	bj.deal([Vector2i(10, 0), Vector2i(10, 1), Vector2i(9, 2), Vector2i(8, 3), Vector2i(2, 0)])
	bj.stand()
	check(bj.result.rules.refund == 0, "el blackjack tampoco devuelve nada")


## Salón: cada victoria seguida suma 10 % al pago de la siguiente (tope 50 %); perder corta la racha.
func test_racha() -> void:
	var run := make_run(1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var price := Roulette.run_price(run)
	check(Rules.streak_bonus(1) == 0.0 and is_equal_approx(Rules.streak_bonus(2), 0.1) and is_equal_approx(Rules.streak_bonus(6), 0.5) and is_equal_approx(Rules.streak_bonus(60), 0.5), "el extra: 0 % la primera, 10 % la segunda, tope 50 %")
	var out := Rules.settle(run, price, price * 2, true, false)
	check(out.bonus == 0 and run.casino_visit.streak == 1, "la primera victoria no suma extra pero empieza la racha")
	var before := run.claridad
	out = Rules.settle(run, price, price * 2, true, false)
	check(out.bonus == int(round(price * 2 * 0.1)) and run.claridad == before + out.bonus and run.casino_visit.streak == 2, "la segunda suma 10 % del pago")
	for i in 10:
		out = Rules.settle(run, price, price * 2, true, false)
	check(out.bonus == int(round(price * 2 * 0.5)), "el extra tiene tope de 50 %")
	out = Rules.settle(run, price, 0, false, false)
	check(run.casino_visit.streak == 0 and out.total == 0, "una pérdida corta la racha")
	Rules.settle(run, price, price, false, false)
	check(run.casino_visit.streak == 0, "un empate no suma")
	Rules.settle(run, price, price * 3, true, false)
	Rules.settle(run, price, price, false, false)
	check(run.casino_visit.streak == 1, "un empate no corta la racha")
	# con una apuesta de la ruleta que da un ítem (no claridad) también cuenta la victoria
	Rules.enter(run, 1)
	Rules.accept(run)
	var res := Roulette.resolve(run, Roulette.Bet.RANGO, [1, 2, 3, 4, 5, 6, 7, 8, 9], rng, 3)
	check(res.won and run.casino_visit.streak == 1, "ganar un premio en la ruleta suma a la racha")


## Casino: se apuestan 1, 2, 3 o 5 fichas juntas en tragamonedas y blackjack; el pago es proporcional.
func test_libre() -> void:
	var run := make_run(2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var price := Roulette.run_price(run)
	check(Rules.stake(run) == 1 and Rules.set_stake(run, 3) and Rules.stake(run) == 3, "se elige apostar 3 fichas")
	check(not Rules.set_stake(run, 4) and Rules.stake(run) == 3, "sólo valen 1, 2, 3 o 5")
	var before := run.claridad
	var s := Slots.new(run, rng)
	s.start()
	check(s.price == price * 3 and run.claridad == before - price * 3, "las tragamonedas cobran 3 fichas")
	s.reels = [3, 3, 0]   # dos soles: paga 1,4 fichas
	var res := s.collect()
	check(res.claridad == int(round(1.4 * price * 3)) and res.spent == price * 3, "y pagan en proporción (1,4 × 3 fichas)")
	var respin_cost := Slots.respin_price(price * 3)
	check(respin_cost == int(round(price * 3 * 0.5)), "volver a girar cuesta media apuesta")
	Rules.set_stake(run, 5)
	var bj := Blackjack.new(run, rng)
	var bal := run.claridad
	bj.deal([Vector2i(2, 0), Vector2i(5, 1), Vector2i(10, 2), Vector2i(9, 3), Vector2i(10, 0)])   # jugador 10+10... (se saca del final)
	check(bj.bet == price * 5 and run.claridad == bal - price * 5, "el blackjack cobra 5 fichas")
	bj.stand()
	check(bj.result.bet == price * 5, "el resultado lleva la apuesta total")
	# en otras salas no se puede
	var other := make_run(1)
	check(not Rules.set_stake(other, 3) and Rules.stake(other) == 1, "fuera del casino sólo se apuesta una ficha")
	# la ruleta no cambia
	Rules.set_stake(run, 5)
	var rr := Roulette.resolve(run, Roulette.Bet.MITAD, [1, 2, 3, 4, 5, 6], rng, 12)
	check(rr.price == price, "la ruleta sigue con una sola ficha")


## Gran casino: lo perdido alimenta un pozo; el premio mayor se lo lleva.
func test_jackpot() -> void:
	var run := make_run(3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var price := Roulette.run_price(run)
	check(Rules.pool(run) == 0, "el pozo empieza vacío")
	Roulette.resolve(run, Roulette.Bet.PLENO, [1], rng, 5)
	check(Rules.pool(run) == int(round(price * 0.5)), "una pérdida suma la mitad de lo perdido al pozo")
	Roulette.resolve(run, Roulette.Bet.PLENO, [1], rng, 5)
	check(Rules.pool(run) == int(round(price * 0.5)) * 2, "y otra más")
	var pool := Rules.pool(run)
	var before := run.claridad
	var res := Roulette.resolve(run, Roulette.Bet.PLENO, [1], rng, 1)   # pleno: premio mayor
	check(res.won and res.rules.jackpot == pool and Rules.pool(run) == 0, "un pleno ganado se lleva el pozo")
	check(res.claridad_delta >= pool - price and run.claridad >= before - price + pool, "el pozo se suma a lo que ya paga el pleno")
	# una victoria común no se lo lleva
	Roulette.resolve(run, Roulette.Bet.PLENO, [1], rng, 5)
	var pool2 := Rules.pool(run)
	Roulette.resolve(run, Roulette.Bet.MITAD, [1, 2, 3, 4, 5, 6], rng, 2)
	check(Rules.pool(run) == pool2, "un acierto común no toca el pozo")
	# tres coronas y blackjack
	var s := Slots.new(run, rng)
	s.start()
	s.reels = [4, 4, 4]
	var sr := s.collect()
	check(sr.rules.jackpot == pool2, "tres coronas se llevan el pozo")
	Roulette.resolve(run, Roulette.Bet.PLENO, [1], rng, 5)
	var pool3 := Rules.pool(run)
	var bj := Blackjack.new(run, rng)
	bj.deal([Vector2i(5, 0), Vector2i(6, 1), Vector2i(1, 2), Vector2i(9, 3), Vector2i(13, 0)])   # se saca del final: jugador K y A... (blackjack)
	if Blackjack.is_blackjack(bj.player) and not Blackjack.is_blackjack(bj.dealer):
		check(bj.result.rules.jackpot == pool3, "un blackjack se lleva el pozo")


## Sin visita (pruebas, entrenamiento) no hay reglas.
func test_no_visit() -> void:
	var run := RunState.new()
	run.claridad = 1000
	var rng := RandomNumberGenerator.new()
	var out := Rules.settle(run, 50, 0, false, false)
	check(out.total == 0 and not Rules.active(run) and Rules.stake(run) == 1 and not Rules.set_stake(run, 2), "sin visita no hay ninguna regla")
	var res := Roulette.resolve(run, Roulette.Bet.PLENO, [1], rng, 5)
	check(res.claridad_delta == -res.price and res.rules.total == 0, "la ruleta paga como siempre")
