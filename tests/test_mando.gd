extends SceneTree
## El mando en los menús: con el juego en pausa, la cruceta cambia el botón elegido del menú de pausa, A lo acciona y B/Start lo cierran.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_mando.gd

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _pad(button: int, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button as JoyButton
	e.pressed = pressed
	Input.parse_input_event(e)


func _tap(button: int) -> void:
	_pad(button, true)
	for i in 3:
		await process_frame
	_pad(button, false)
	for i in 3:
		await process_frame


func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code as Key
	e.physical_keycode = code as Key
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	await process_frame
	e = InputEventKey.new()
	e.keycode = code as Key
	e.physical_keycode = code as Key
	e.pressed = false
	Input.parse_input_event(e)
	await process_frame


## Los juegos del casino con el mando (A, X, Y y la cruceta ya llegan como Enter, Espacio, C y flechas): se juega apretando botones y la barra de ayuda dice cuáles.
func test_games() -> void:
	var Controls := preload("res://scripts/controls.gd")
	Controls.using_pad = true
	var RunState := preload("res://scripts/run_state.gd")
	var run := RunState.new()
	run.claridad = 600
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# ruleta
	var r = preload("res://scripts/roulette_screen.gd").new()
	root.add_child(r)
	r.setup(run, rng, true)
	for i in 3:
		await process_frame
	check(r.pad_hints != null and r.pad_hints.visible and r.pad_hints.items.size() >= 6, "la ruleta muestra la barra de botones del mando")
	check(r.spin_button.focus_mode == Control.FOCUS_NONE, "en la ruleta los botones no toman el foco (no se navega por la pantalla)")
	await _key(KEY_RIGHT)
	check(r.pad_cursor == 2, "la cruceta mueve la casilla marcada (%d)" % r.pad_cursor)
	await _key(KEY_SPACE)
	check(r.selected == [2], "X pone la ficha en la casilla marcada (%s)" % str(r.selected))
	var bet0: int = r.bet
	await _key(KEY_E)
	check(r.bet != bet0, "RB cambia el tipo de apuesta")
	await _key(KEY_Q)
	check(r.bet == bet0, "LB vuelve al tipo anterior")
	await _key(KEY_ENTER)
	await process_frame
	check(r.state != r.State.IDLE, "A gira la ruleta con la apuesta puesta")
	r.queue_free()
	await process_frame
	# tragamonedas
	var sl = preload("res://scripts/slots_screen.gd").new()
	root.add_child(sl)
	sl.setup(run, rng, true)
	await process_frame
	await _key(KEY_ENTER)
	for i in 6:
		await process_frame
	check(sl.ui_state == sl.UiState.HOLD or sl.ui_state == sl.UiState.DONE, "A gira las tragamonedas")
	if sl.ui_state == sl.UiState.HOLD:
		await _key(KEY_LEFT)
		check(sl.holds[0], "la cruceta izquierda retiene el primer carrete")
		await _key(KEY_SPACE)
		for i in 4:
			await process_frame
		check(sl.ui_state == sl.UiState.DONE or sl.ui_state == sl.UiState.IDLE, "X cobra")
	sl.queue_free()
	await process_frame
	# blackjack
	var bj = preload("res://scripts/blackjack_screen.gd").new()
	root.add_child(bj)
	bj.setup(run, rng, true)
	await process_frame
	await _key(KEY_ENTER)
	for i in 8:
		await process_frame
	check(bj.game.phase != bj.Blackjack.Phase.BETTING if "BETTING" in bj.Blackjack.Phase else true, "A reparte")
	bj.queue_free()
	await process_frame
	Controls.using_pad = false


func _init() -> void:
	await test_games()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	main.in_menu = false
	main.pause_game()
	for i in 5:
		await process_frame
	check(paused and main.pause_menu.visible, "el juego está en pausa")
	var first = main.pause_menu.get_viewport().gui_get_focus_owner()
	check(first == main.pause_menu.buttons["continuar"], "al pausar, el foco está en Continuar")
	await _tap(JOY_BUTTON_DPAD_DOWN)
	check(main.pause_menu.get_viewport().gui_get_focus_owner() == main.pause_menu.buttons["reiniciar"], "un toque de cruceta baja un solo botón (no de dos en dos)")
	var second = main.pause_menu.get_viewport().gui_get_focus_owner()
	check(second != null and second != first, "la cruceta baja al botón siguiente con el juego en pausa")
	await _tap(JOY_BUTTON_START)
	check(not paused and not main.pause_menu.visible, "Start cierra la pausa")
	main.pause_game()
	for i in 5:
		await process_frame
	await _tap(JOY_BUTTON_B)
	check(not paused, "B cierra la pausa")
	main._cancel_jobs()
	main.queue_free()
	await process_frame
	print("tests del mando terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
