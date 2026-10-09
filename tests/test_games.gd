extends SceneTree
## Pruebas de la tragamonedas con retener y del blackjack: reglas, cuentas de claridad, rendimiento y pantallas (headless).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_games.gd

const Slots := preload("res://scripts/slots.gd")
const Blackjack := preload("res://scripts/blackjack.gd")
const RunState := preload("res://scripts/run_state.gd")
const Roulette := preload("res://scripts/roulette.gd")
const SlotsScreen := preload("res://scripts/slots_screen.gd")
const BlackjackScreen := preload("res://scripts/blackjack_screen.gd")
const Items := preload("res://scripts/items.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func make_run(claridad := 1000) -> RefCounted:
	var r := RunState.new()
	r.claridad = claridad
	return r


func rng_with(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func _init() -> void:
	test_slots_rules()
	test_slots_game()
	test_blackjack_rules()
	test_blackjack_game()
	await test_slots_screen()
	await test_blackjack_screen()
	print("tests de tragamonedas y blackjack terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


# --- tragamonedas --------------------------------------------------------------------------------------------------

func test_slots_rules() -> void:
	check(Slots.payout([0, 0, 0]).kind == "triple" and Slots.payout([0, 0, 0]).mult == Slots.TRIPLE[0], "tres iguales pagan el triple del simbolo")
	check(Slots.payout([3, 1, 3]).kind == "pair" and Slots.payout([3, 1, 3]).mult == Slots.PAIR[3], "dos iguales (aunque no sean contiguos) pagan el par del simbolo")
	check(Slots.payout([0, 1, 2]).kind == "none" and Slots.payout([0, 1, 2]).mult == 0.0, "tres distintos no pagan")
	check(Slots.TRIPLE[4] > Slots.TRIPLE[3] and Slots.TRIPLE[3] > Slots.TRIPLE[2] and Slots.TRIPLE[2] > Slots.TRIPLE[1] and Slots.TRIPLE[1] > Slots.TRIPLE[0], "los simbolos mas raros pagan mas")
	var rtp := Slots.optimal_rtp()
	print("rendimiento de la tragamonedas con la mejor estrategia: %.3f" % rtp)
	check(rtp > 0.88 and rtp < 0.96, "jugando bien rinde un poco menos de lo que cuesta (%.3f)" % rtp)
	# Frecuencias: los comunes salen mas
	var r := rng_with(5)
	var counts := [0, 0, 0, 0, 0]
	for i in 18000:
		counts[Slots.random_symbol(r)] += 1
	check(counts[0] > counts[1] and counts[1] > counts[2] and counts[2] > counts[3] and counts[3] > counts[4], "los simbolos comunes salen mas seguido (%s)" % str(counts))
	check(counts[4] > 700 and counts[4] < 1300, "la corona sale ~1 de cada 18 (%d)" % counts[4])
	check(Slots.respin_price(50) == 25 and Slots.respin_price(1) == 1, "volver a girar cuesta media ficha")


func test_slots_game() -> void:
	var run := make_run(1000)
	var g := Slots.new(run, rng_with(3))
	var price: int = Roulette.run_price(run)
	var res: Dictionary = g.start()
	check(res.ok and run.claridad == 1000 - price and run.casino_spent == price and g.phase == Slots.Phase.HOLD, "girar cobra la ficha y deja elegir")
	check(not g.start().ok, "no se puede girar de nuevo con una tirada abierta")
	# Retener: lo retenido no cambia y el giro de vuelta cuesta media ficha
	g.reels.assign([2, 3, 4])
	var before: int = run.claridad
	res = g.respin([true, false, true])
	check(res.ok and g.reels[0] == 2 and g.reels[2] == 4, "los rodillos retenidos no cambian")
	check(before - run.claridad >= Slots.respin_price(price) and g.phase == Slots.Phase.DONE, "volver a girar cobra media ficha y termina la tirada (si no pago algo)")
	check(not g.respin([false, false, false]).ok, "una vez terminada no se puede volver a girar")
	# No se puede retener todo
	run = make_run(1000)
	g = Slots.new(run, rng_with(4))
	g.start()
	check(not g.respin([true, true, true]).ok and g.phase == Slots.Phase.HOLD, "retener los tres no es volver a girar")
	# Cobrar con un par: paga y suma a casino_won
	g.reels.assign([1, 1, 0])
	var claridad: int = run.claridad
	res = g.collect()
	var expect: int = int(round(Slots.PAIR[1] * price))
	check(res.kind == "pair" and res.claridad == expect and run.claridad == claridad + expect and run.casino_won == expect, "cobrar un par paga %d" % expect)
	check(g.collect() == res and run.claridad == claridad + expect, "cobrar dos veces no paga dos veces")
	# Tres coronas: claridad y un boost epico (o su equivalente en claridad si no hay lugar)
	run = make_run(1000)
	g = Slots.new(run, rng_with(8))
	g.start()
	g.reels.assign([4, 4, 4])
	var boosts: int = run.boosts.size()
	res = g.collect()
	check(res.kind == "triple" and res.claridad >= int(round(Slots.TRIPLE[4] * price)) and not res.item.is_empty(), "tres coronas pagan el premio gordo y traen un boost")
	check(run.boosts.size() == boosts + 1 or res.converted, "el boost entra al run (o se convierte si no hay lugar)")
	# Sin claridad no se gira
	run = make_run(3)
	g = Slots.new(run, rng_with(1))
	check(not g.start().ok and run.claridad == 3, "sin claridad para la ficha no se gira")
	# Y si no alcanza para volver a girar, no se puede
	run = make_run(price + Slots.respin_price(price) - 1)
	g = Slots.new(run, rng_with(1))
	g.start()
	check(not g.can_respin(), "sin claridad para la media ficha no se puede volver a girar")


# --- blackjack ----------------------------------------------------------------------------------------------------

func c(rank: int, suit := 0) -> Vector2i:
	return Vector2i(rank, suit)


## Un mazo armado a mano: las cartas se reparten desde el final, en el orden jugador, crupier, jugador, crupier y despues las que se pidan.
func stacked(player_cards: Array, dealer_cards: Array, extra: Array = []) -> Array:
	var order: Array = [player_cards[0], dealer_cards[0], player_cards[1], dealer_cards[1]] + extra
	order.reverse()
	return order


func test_blackjack_rules() -> void:
	check(Blackjack.value([c(1), c(13)]).total == 21 and Blackjack.value([c(1), c(13)]).soft, "A + K = 21 blando")
	check(Blackjack.value([c(1), c(1), c(9)]).total == 21, "A + A + 9 = 21")
	check(Blackjack.value([c(1), c(1), c(9), c(10)]).total == 21 and not Blackjack.value([c(1), c(1), c(9), c(10)]).soft, "A + A + 9 + 10 = 21 duro (los ases valen 1)")
	check(Blackjack.value([c(10), c(7), c(9)]).total == 26, "26 se pasa")
	check(Blackjack.value([c(12), c(11)]).total == 20, "las figuras valen 10")
	check(Blackjack.is_blackjack([c(1), c(11)]) and not Blackjack.is_blackjack([c(7), c(7), c(7)]), "blackjack: 21 con dos cartas")
	var rtp := Blackjack.simulate_rtp(20000, 11)
	print("rendimiento del blackjack con estrategia simple: %.3f" % rtp)
	check(rtp > 0.93 and rtp < 1.02, "con una estrategia simple rinde casi parejo (%.3f)" % rtp)


func test_blackjack_game() -> void:
	var run := make_run(1000)
	var bet: int = Roulette.run_price(run)
	var g := Blackjack.new(run, rng_with(1))
	# Blackjack del jugador: paga 3 a 2
	check(g.deal(stacked([c(1), c(13)], [c(9), c(7)])).ok, "se reparte")
	check(g.phase == Blackjack.Phase.DONE and g.outcome == Blackjack.Outcome.BLACKJACK and run.claridad == 1000 - bet + int(round(2.5 * bet)), "blackjack paga 3 a 2")
	# Empate de blackjacks
	run = make_run(1000)
	g = Blackjack.new(run, rng_with(1))
	g.deal(stacked([c(1), c(13)], [c(1), c(12)]))
	check(g.outcome == Blackjack.Outcome.PUSH and run.claridad == 1000, "dos blackjacks empatan y se devuelve la apuesta")
	# Blackjack del crupier: se pierde de entrada
	run = make_run(1000)
	g = Blackjack.new(run, rng_with(1))
	g.deal(stacked([c(10), c(9)], [c(1), c(13)]))
	check(g.outcome == Blackjack.Outcome.LOSE and run.claridad == 1000 - bet and not g.hole_hidden, "blackjack del crupier: pierde y se muestra su carta")
	# Pedir y pasarse
	run = make_run(1000)
	g = Blackjack.new(run, rng_with(1))
	g.deal(stacked([c(10), c(6)], [c(10), c(8)], [c(13)]))
	check(g.phase == Blackjack.Phase.PLAYER and g.hole_hidden, "con 16 se sigue jugando y la carta del crupier esta tapada")
	g.hit()
	check(g.phase == Blackjack.Phase.DONE and g.outcome == Blackjack.Outcome.BUST and run.claridad == 1000 - bet, "pedir y pasarse de 21 pierde")
	# Plantarse: el crupier pide hasta 17 y se pasa
	run = make_run(1000)
	g = Blackjack.new(run, rng_with(1))
	g.deal(stacked([c(10), c(8)], [c(10), c(6)], [c(10)]))
	g.stand()
	check(g.dealer.size() == 3 and g.outcome == Blackjack.Outcome.WIN and run.claridad == 1000 - bet + 2 * bet, "el crupier pide con 16, se pasa y ganas 1 a 1")
	# El crupier se planta en 17 (tambien blando)
	run = make_run(1000)
	g = Blackjack.new(run, rng_with(1))
	g.deal(stacked([c(10), c(8)], [c(1), c(6)]))
	g.stand()
	check(g.dealer.size() == 2 and g.outcome == Blackjack.Outcome.WIN, "el crupier se planta con 17 blando y 18 le gana")
	# Empate
	run = make_run(1000)
	g = Blackjack.new(run, rng_with(1))
	g.deal(stacked([c(10), c(8)], [c(9), c(9)]))
	g.stand()
	check(g.outcome == Blackjack.Outcome.PUSH and run.claridad == 1000, "18 contra 18 empata")
	# Doblar: una apuesta mas, una sola carta, y se planta
	run = make_run(1000)
	g = Blackjack.new(run, rng_with(1))
	g.deal(stacked([c(5), c(6)], [c(10), c(7)], [c(10)]))
	check(g.can_double(), "con las dos primeras cartas se puede doblar")
	g.double_down()
	check(g.phase == Blackjack.Phase.DONE and g.player.size() == 3 and g.bet == 2 * bet and g.outcome == Blackjack.Outcome.WIN and run.claridad == 1000 - 2 * bet + 4 * bet, "doblar: una carta mas y paga el doble")
	check(run.casino_spent == 2 * bet and run.casino_won == 4 * bet, "las estadisticas del casino suman lo doblado")
	# No se puede doblar sin claridad ni con tres cartas
	run = make_run(bet)
	g = Blackjack.new(run, rng_with(1))
	g.deal(stacked([c(5), c(6)], [c(10), c(7)]))
	check(not g.can_double(), "sin claridad para otra ficha no se dobla")
	run = make_run(1000)
	g = Blackjack.new(run, rng_with(1))
	g.deal(stacked([c(2), c(3)], [c(10), c(7)], [c(2)]))
	g.hit()
	check(not g.can_double(), "con tres cartas ya no se dobla")
	# Sin claridad no se reparte
	run = make_run(3)
	g = Blackjack.new(run, rng_with(1))
	check(not g.deal().ok and run.claridad == 3, "sin claridad para la ficha no se reparte")
	# El mazo completo tiene 52 cartas distintas
	g = Blackjack.new(make_run(1000), rng_with(2))
	g.deal()
	var seen := {}
	for card in g.deck + g.player + g.dealer:
		seen[card] = true
	check(seen.size() == 52, "el mazo tiene 52 cartas distintas (%d)" % seen.size())


# --- pantallas ------------------------------------------------------------------------------------------------------------

func test_slots_screen() -> void:
	var run := make_run(1000)
	var s: Control = SlotsScreen.new()
	root.add_child(s)
	s.setup(run, rng_with(21), true)
	await process_frame
	check(s.ui_state == SlotsScreen.UiState.IDLE and not s.spin_button.disabled and not s.respin_button.visible, "al abrir se puede girar")
	var price: int = Roulette.run_price(run)
	s.spin()
	check(run.claridad == 1000 - price, "girar cobra la ficha")
	check(s.ui_state == SlotsScreen.UiState.HOLD and s.respin_button.visible and s.collect_button.visible and s.spin_button.disabled, "tras girar se puede retener y volver a girar, o cobrar")
	s.toggle_hold(0)
	check(s.holds[0] and s.hold_buttons[0].selected, "el primer rodillo queda retenido")
	s.toggle_hold(0)
	check(not s.holds[0], "y se suelta")
	s.toggle_hold(1)
	var kept: int = s.game.reels[1]
	s.respin()
	check(s.ui_state == SlotsScreen.UiState.DONE and s.game.reels[1] == kept, "volver a girar termina la tirada y respeta lo retenido")
	check(s.result_label.text != "" and not s.spin_button.disabled, "se muestra el resultado y se puede jugar otra vez")
	# Cobrar sin volver a girar
	s.spin()
	s.collect()
	check(s.ui_state == SlotsScreen.UiState.DONE, "cobrar termina la tirada")
	# Sin claridad se avisa y no pasa nada
	run.claridad = 2
	s.spin()
	check(s.ui_state == SlotsScreen.UiState.DONE and run.claridad == 2 and s.result_label.text.contains("claridad"), "sin claridad se avisa")
	# Salir con una tirada abierta la cobra
	run.claridad = 1000
	s.spin()
	var closed := [0]
	s.closed.connect(func(): closed[0] += 1)
	s.request_close()
	check(closed[0] == 1 and s.game.phase == Slots.Phase.DONE, "salir con una tirada abierta la cobra (cierres %d, fase %d, estado %d)" % [closed[0], s.game.phase, s.ui_state])
	check(s.prizes_panel.get_child_count() > 0, "la tabla de premios existe")
	s.queue_free()


func test_blackjack_screen() -> void:
	var run := make_run(1000)
	var b: Control = BlackjackScreen.new()
	root.add_child(b)
	b.setup(run, rng_with(31), true)
	await process_frame
	check(b.can_deal() and b.deal_button.visible and not b.hit_button.visible, "al abrir solo se puede repartir")
	var bet: int = Roulette.run_price(run)
	b.game.deck.clear()
	await b.deal()   # (mazo al azar)
	check(run.claridad <= 1000 - bet + int(round(2.5 * bet)) and b.player_views.size() == 2 and b.dealer_views.size() == 2, "se reparten dos cartas a cada uno")
	if b.game.phase == Blackjack.Phase.PLAYER:
		check(b.hit_button.visible and b.stand_button.visible and b.double_button.visible and not b.deal_button.visible, "en juego: Pedir, Plantarse y Doblar")
		await b.stand()
		check(b.game.phase == Blackjack.Phase.DONE and b.message.text != "" and b.deal_button.visible, "al plantarse se muestra el resultado y se puede repartir otra vez")
	else:
		check(b.message.text != "", "mano terminada de entrada: hay resultado")
	# Una mano armada: doblar
	run.claridad = 1000
	b.game.phase = Blackjack.Phase.IDLE
	await b.game.deal(stacked([c(5), c(6)], [c(10), c(7)], [c(10)]))
	b._clear_hands()
	await b._add_card(b.player_box, b.player_views, b.game.player[0], true)
	await b._add_card(b.player_box, b.player_views, b.game.player[1], true)
	await b._add_card(b.dealer_box, b.dealer_views, b.game.dealer[0], true)
	await b._add_card(b.dealer_box, b.dealer_views, b.game.dealer[1], false)
	await b.double_down()
	check(b.game.phase == Blackjack.Phase.DONE and b.player_views.size() == 3 and b.message.text.contains("Ganaste"), "doblar reparte una carta y resuelve la mano (%s)" % b.message.text)
	b.queue_free()
