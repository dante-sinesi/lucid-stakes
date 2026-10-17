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


func _init() -> void:
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
