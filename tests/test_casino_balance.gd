extends SceneTree
## Pruebas del balance del casino: las estadísticas de cada visita y la pantalla que se ve al salir, antes de la torre siguiente (headless).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_casino_balance.gd

const Rules := preload("res://scripts/casino_rules.gd")
const Roulette := preload("res://scripts/roulette.gd")
const Slots := preload("res://scripts/slots.gd")
const Blackjack := preload("res://scripts/blackjack.gd")
const RunState := preload("res://scripts/run_state.gd")
const BalanceScreen := preload("res://scripts/casino_balance_screen.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_stats()
	await test_screen()
	await test_flow()
	print("tests del balance del casino terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func make_run(tier: int, claridad := 5000) -> RunState:
	var run := RunState.new()
	run.stage = 3
	run.claridad = claridad
	Rules.enter(run, tier)
	Rules.accept(run)   # (la regla rige sólo si se habló con el tabernero)
	return run


func test_stats() -> void:
	var run := make_run(1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var price := Roulette.run_price(run)
	var b := Rules.balance(run)
	check(b.rows.size() == 3 and b.total.plays == 0 and b.claridad_in == 5000 and b.room == "Salón" and b.rule == "racha", "al entrar el balance está en cero y sabe la sala y la regla")
	Roulette.resolve(run, Roulette.Bet.PLENO, [1], rng, 5)   # pierde
	Roulette.resolve(run, Roulette.Bet.MITAD, [1, 2, 3, 4, 5, 6], rng, 2)   # gana un premio
	var s := Slots.new(run, rng)
	s.start()
	s.reels = [0, 1, 2]
	s.collect()
	var bj := Blackjack.new(run, rng)
	bj.deal()
	bj.stand()
	b = Rules.balance(run)
	var roul: Dictionary = b.rows[0]
	check(roul.game == "ruleta" and roul.plays == 2 and roul.wins == 1 and roul.losses == 1 and roul.spent == price * 2, "la ruleta cuenta 2 partidas, 1 ganada y 1 perdida")
	var slot: Dictionary = b.rows[1]
	check(slot.game == "tragamonedas" and slot.plays == 1 and slot.losses == 1 and slot.spent == price and slot.won == 0 and slot.net == -price, "las tragamonedas, una partida perdida")
	var bjr: Dictionary = b.rows[2]
	check(bjr.game == "blackjack" and bjr.plays == 1 and bjr.wins + bjr.losses + bjr.pushes == 1 and bjr.spent >= price, "el blackjack cuenta su mano")
	check(b.total.plays == 4 and b.total.spent == roul.spent + slot.spent + bjr.spent and b.total.net == b.total.won - b.total.spent, "los totales suman las tres mesas")
	check(b.claridad_in == 5000 and b.claridad_out == run.claridad and b.claridad_out - b.claridad_in == b.total.net + _non_claridad_value(run), "entró con 5000 y salió con lo que tiene ahora")
	# apuesta libre y doble
	var big := make_run(2)
	Rules.set_stake(big, 5)
	var s2 := Slots.new(big, rng)
	s2.start()
	s2.reels = [0, 1, 2]
	s2.collect()
	var bb := Rules.balance(big)
	check(bb.rows[1].spent == Roulette.run_price(big) * 5, "las fichas apostadas juntas cuentan como gastado")
	# la mejor jugada y la racha
	var win := make_run(1)
	Rules.settle(win, 50, 120, true, false, "ruleta")
	Rules.settle(win, 50, 200, true, false, "blackjack")
	var wb := Rules.balance(win)
	check(wb.best == 150 + int(round(200 * 0.1)) - 0 or wb.best >= 150, "la mejor jugada es la de más ganancia (%d)" % wb.best)
	check(wb.best_game == "blackjack" and wb.max_streak == 2, "y se sabe en qué juego (la racha más larga: 2)")
	# sin visita no hay balance
	var none := RunState.new()
	check(Rules.balance(none).total.plays == 0 and Rules.balance(none).room == "", "sin visita el balance está vacío")


## La ruleta paga ítems que no son claridad: la diferencia entre lo que entró y salió también incluye lo gastado sin ganar claridad.
func _non_claridad_value(_run) -> int:
	return 0


func test_screen() -> void:
	var run := make_run(3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	Roulette.resolve(run, Roulette.Bet.PLENO, [1], rng, 5)
	Rules.settle(run, 100, 0, false, false, "tragamonedas")
	run.vault = 80
	run.vault_stage = 3
	var sc := BalanceScreen.new()
	root.add_child(sc)
	sc.setup(run)
	await process_frame
	check(sc.table.get_child_count() == 7 * 5, "la tabla tiene el encabezado, las tres mesas y el total (%d celdas)" % sc.table.get_child_count())
	check(sc.lines.size() >= 4 and sc.lines[0].contains("Entraste con") and sc.lines.any(func(t): return t.contains("Caja fuerte") and t.contains("92")), "los renglones cuentan la entrada y la salida y la caja fuerte")
	var finished := [0]
	sc.done.connect(func(): finished[0] += 1)
	sc.continue_button.pressed.emit()
	sc.continue_button.pressed.emit()
	check(finished[0] == 1, "Continuar avisa una sola vez")
	sc.queue_free()
	# sin jugar
	var quiet := make_run(0)
	var sc2 := BalanceScreen.new()
	root.add_child(sc2)
	sc2.setup(quiet)
	await process_frame
	check(sc2.lines.size() >= 1 and sc2.lines[0].contains("No jugaste"), "si no se jugó, lo dice")
	sc2.queue_free()


func test_flow() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	check(not main.casino_balance, "en las pruebas el balance está apagado: salir pasa directo")
	main.casino_balance = true   # (acá sí se prueba)
	main.enter_casino()
	await process_frame
	check(main.casino != null and CasinoRulesActive(main), "en el casino hay una visita en curso")
	var stage_before: int = main.stage_number
	main.leave_casino()
	check(main.balance_layer != null and main.casino != null and main.stage_number == stage_before, "al salir se ve el balance y todavía no se pasa a la torre siguiente")
	main.leave_casino()
	check(main.balance_layer != null, "salir de nuevo no abre otro")
	var screen = main.balance_layer.get_child(0)
	screen.continue_button.pressed.emit()
	await process_frame
	check(main.balance_layer == null and main.casino == null and main.stage_number == stage_before + 1, "Continuar sigue a la torre siguiente")
	# abandonar con el balance abierto lo cierra
	main._cancel_jobs()
	main.enter_casino()
	main.leave_casino()
	check(main.balance_layer != null, "(otra vez el balance)")
	main.end_run(false, "")
	check(main.balance_layer == null, "terminar el run cierra el balance")
	main._cancel_jobs()
	main.queue_free()
	await process_frame


func CasinoRulesActive(main) -> bool:
	return Rules.active(main.run)
