extends SceneTree
## Los boosts y consumibles del casino (docs/diseno.md §49): Mano de 23, Mesa caliente, Blackjack de oro, Ficha barata, Casilla de regalo, Red de seguridad, Giro de cortesía, Llave de la vitrina,
## Doble o nada, Ficha gratis y Rayos X.
## Ejecutar: godot --headless --path . -s tests/unitarios/test_casino_items.gd

const RunState := preload("res://scripts/datos/run_state.gd")
const Items := preload("res://scripts/datos/items.gd")
const Roulette := preload("res://scripts/casino/roulette.gd")
const Slots := preload("res://scripts/casino/slots.gd")
const Blackjack := preload("res://scripts/casino/blackjack.gd")
const Rules := preload("res://scripts/casino/casino_visit.gd")
const Showcase := preload("res://scripts/casino/showcase.gd")
const CasinoScene := preload("res://scripts/casino/casino_scene.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func make_run(boosts: Array = []) -> RunState:
	var run := RunState.new()
	run.stage = 3
	run.claridad = 5000
	run.boosts.assign(boosts)
	return run


func _init() -> void:
	test_blackjack()
	test_prices()
	test_roulette()
	test_rules()
	test_slots()
	test_showcase()
	await test_casino_use()
	print("tests de los premios del casino terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


## El mazo se saca desde el final: jugador, crupier, jugador, crupier, y después lo que se pida.
func _deck(draws: Array) -> Array:
	var d: Array = draws.duplicate()
	d.reverse()
	return d


func test_blackjack() -> void:
	# 10 + 7 = 17 contra 10 + 6: pide un 5 (22) y un as (23); el crupier pide un 9 (25) y se pasa
	var deck := _deck([Vector2i(10, 0), Vector2i(10, 0), Vector2i(7, 0), Vector2i(6, 0), Vector2i(5, 0), Vector2i(1, 0), Vector2i(9, 0)])
	var rng := RandomNumberGenerator.new()
	var run := make_run(["mano_23"])
	var g := Blackjack.new(run, rng)
	check(g.limit() == 23, "Mano de 23: el tope es 23")
	g.deal(deck)
	g.hit()   # 22: con el tope en 23 todavía no se pasó
	check(g.phase == Blackjack.Phase.PLAYER and Blackjack.value(g.player).total == 22, "con 22 sigue la mano (no se pasó)")
	g.hit()   # el as vale 1: 23
	check(g.phase == Blackjack.Phase.DONE and g.outcome == Blackjack.Outcome.WIN and int(g.result.player) == 23, "con 23 se planta solo y gana si el crupier se pasa de 21")
	var run2 := make_run()
	var g2 := Blackjack.new(run2, rng)
	check(g2.limit() == 21, "sin el boost el tope es 21")
	g2.deal(deck)
	g2.hit()
	check(g2.phase == Blackjack.Phase.DONE and g2.outcome == Blackjack.Outcome.BUST, "sin el boost, 22 es pasarse")
	# blackjack natural: 3 a 2 y, con Blackjack de oro, 3 a 1
	var nat := _deck([Vector2i(1, 0), Vector2i(9, 0), Vector2i(13, 0), Vector2i(7, 0)])
	var g3 := Blackjack.new(make_run(), rng)
	g3.deal(nat)
	check(g3.outcome == Blackjack.Outcome.BLACKJACK and int(g3.result.claridad) == int(round(2.5 * g3.bet)), "el blackjack natural paga 3 a 2")
	var run4 := make_run(["blackjack_de_oro"])
	var g4 := Blackjack.new(run4, rng)
	g4.deal(nat)
	check(g4.outcome == Blackjack.Outcome.BLACKJACK and int(g4.result.claridad) == int(round(4.0 * g4.bet)), "Blackjack de oro: paga 3 a 1")
	# Rayos X: se ve la carta tapada
	var run5 := make_run()
	run5.xray = true
	var g5 := Blackjack.new(run5, rng)
	g5.deal(_deck([Vector2i(10, 0), Vector2i(9, 0), Vector2i(2, 0), Vector2i(3, 0)]))
	check(not g5.hole_hidden and not run5.xray, "Rayos X: se ve la carta tapada del crupier y se gasta")


func test_prices() -> void:
	var base := Roulette.run_price(make_run())
	check(Roulette.run_price(make_run(["ficha_barata"])) == int(round(base * 0.8)), "Ficha barata: −20 %")
	check(Roulette.run_price(make_run(["ficha_barata", "ficha_barata"])) == int(round(base * 0.6)), "dos Fichas baratas: −40 %")
	var run := make_run(["ficha_barata", "ficha_barata"])
	check(not run.has_room_for(Items.get_item("ficha_barata")), "la Ficha barata se acumula sólo hasta 2")


func test_roulette() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	# Casilla de regalo: una de las casillas comunes de la rueda pasa a ser épica
	var run := make_run(["casilla_de_regalo"])
	var epicas := Roulette.wheel_tiers(run).count(Items.Tier.EPICO)
	check(epicas == 2 and Roulette.wheel_tiers(run).count(Items.Tier.COMUN) == 3, "Casilla de regalo: la rueda tiene 2 casillas épicas y 3 comunes")
	var nuevas := 0
	for i in 400:
		var r := make_run(["casilla_de_regalo"])
		nuevas += 1 if int(Roulette.resolve(r, rng).tier) == Items.Tier.EPICO else 0
	check(nuevas > 400 * 2.0 / 13.0 * 0.6 and nuevas < 400 * 2.0 / 13.0 * 1.5, "con Casilla de regalo caen épicos ~2 de cada 13 giros (%d de 400)" % nuevas)
	# Ficha gratis: el giro no cuesta (y se gasta)
	var run2 := make_run()
	run2.free_chip = true
	var before := run2.claridad
	var res2 := Roulette.resolve(run2, rng, 4)   # una casilla rara: no da claridad
	check(res2.ok and run2.claridad == before and not run2.free_chip, "Ficha gratis: el giro no cuesta claridad y se gasta")
	var res3 := Roulette.resolve(run2, rng, 4)
	check(res3.ok and run2.claridad == before - Roulette.spin_price(run2), "el siguiente giro sí cuesta")
	# la ruleta no pierde: no cuenta para la devolución, la racha ni el pozo (son de las mesas con apuestas)
	var run3 := make_run(["red_de_seguridad", "racha_de_la_casa", "pozo_del_jackpot"])
	Rules.enter(run3, 1)
	var antes := run3.claridad
	var res4 := Roulette.resolve(run3, rng, 4)
	check(int(res4.rules.refund) == 0 and int(res4.rules.jackpot) == 0 and int(res4.rules.bonus) == 0 and run3.claridad == antes - Roulette.spin_price(run3) and int(run3.casino_visit.pool) == 0 and int(run3.casino_visit.streak) == 0, "la ruleta no cuenta para Red de seguridad, Racha de la casa ni Pozo del jackpot")
	# Mesa caliente sí: paga más la claridad ganada (una bolsa)
	var run4 := make_run(["mesa_caliente"])
	Rules.enter(run4, 1)
	var res5 := Roulette.resolve(run4, rng, 1)   # una casilla de bolsas
	if res5.prize.type == Items.Type.CLARITY:
		check(int(res5.rules.total) == int(round(float(round(res5.prize.mult * Roulette.run_price(run4))) * 0.25)), "Mesa caliente paga un 25 % más la claridad de una bolsa de la ruleta")


func test_rules() -> void:
	var run := make_run(["red_de_seguridad"])
	Rules.enter(run, 1)
	var before := run.claridad
	var out := Rules.settle(run, 100, 0, false, false, "tragamonedas")
	check(int(out.total) == 10 and run.claridad == before + 10, "Red de seguridad: devuelve el 10 % de lo perdido")
	var run2 := make_run(["mesa_caliente"])
	Rules.enter(run2, 1)
	var out2 := Rules.settle(run2, 100, 200, true, false, "tragamonedas")
	check(int(out2.total) == 50, "Mesa caliente: lo ganado paga un 25 %% más (%d)" % int(out2.total))
	var run3 := make_run()
	Rules.enter(run3, 1)
	run3.casino_visit["double"] = true
	var out3 := Rules.settle(run3, 100, 200, true, false, "ruleta")
	check(int(out3.total) == 200, "Doble o nada: lo ganado vale el doble (%d)" % int(out3.total))
	var run4 := make_run(["mesa_caliente"])
	run4.casino_visit["double"] = true
	Rules.enter(run4, 1)   # (entrar a otra visita apaga el Doble o nada)
	var out4 := Rules.settle(run4, 100, 200, true, false, "ruleta")
	check(int(out4.total) == 50, "el Doble o nada vale una sola visita")


func test_slots() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var run := make_run(["giro_de_cortesia"])
	var s := Slots.new(run, rng)
	s.start()
	var price_before := s.price
	var res := s.respin([false, true, true])
	check(res.ok and s.price == price_before, "Giro de cortesía: volver a girar no cuesta")
	var run2 := make_run()
	var s2 := Slots.new(run2, rng)
	s2.start()
	var p2 := s2.price
	s2.respin([false, true, true])
	check(s2.price > p2, "sin el boost, volver a girar cuesta media ficha")


func test_showcase() -> void:
	var rng := RandomNumberGenerator.new()
	var run := make_run(["llave_de_la_vitrina"])
	run.claridad = 5000
	Showcase.generate(run, rng)
	check(Showcase.rotate_cost(run) == 0, "Llave de la vitrina: la primera rotación es gratis")
	check(Showcase.rotate(run, rng) and run.claridad == 5000, "y no cobra")
	check(Showcase.rotate_cost(run) == Roulette.run_price(run) * 2, "la segunda cuesta como siempre")


func test_casino_use() -> void:
	var run := make_run()
	run.consumables.assign(["doble_o_nada", "ficha_gratis", "rayos_x", "freno"])
	var rng := RandomNumberGenerator.new()
	var c = CasinoScene.new()
	c.quick = true
	root.add_child(c)
	c.setup(run, rng)
	c.use_consumable_slot(0)
	check(bool(run.casino_visit.get("double", false)) and not run.consumables.has("doble_o_nada"), "Doble o nada se usa en el casino")
	c.use_consumable_slot(0)   # (ahora el lugar 0 es la Ficha gratis)
	check(run.free_chip and not run.consumables.has("ficha_gratis"), "Ficha gratis se usa en el casino")
	c.use_consumable_slot(0)
	check(run.xray and not run.consumables.has("rayos_x"), "Rayos X se usa en el casino")
	c.use_consumable_slot(0)
	check(run.consumables == ["freno"], "el Freno no se gasta en el casino")
	for id in ["mano_23", "mesa_caliente", "blackjack_de_oro", "ficha_barata", "casilla_de_regalo", "red_de_seguridad", "giro_de_cortesia", "llave_de_la_vitrina", "doble_o_nada", "ficha_gratis", "rayos_x"]:
		check(not Items.get_item(id).is_empty() and preload("res://scripts/ui/item_icons.gd").has_icon(id), "%s está en el catálogo y tiene ícono" % id)
	c.queue_free()
	await process_frame
