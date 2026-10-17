extends SceneTree
## Los cuadros de confirmación: abandonar la partida y empezar una nueva sobre una sin terminar piden confirmar y cuentan el progreso; en la pausa del casino no se puede reintentar.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_confirmaciones.gd

const SaveGame := preload("res://scripts/save_game.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	main.in_menu = false
	main.run.claridad = 321
	main.save_game()
	check(SaveGame.read().has("run"), "hay una partida guardada")
	main.in_menu = true
	main._on_new_game("pesadilla")
	await process_frame
	check(main.confirm_box.visible, "elegir un escenario nuevo con una partida sin terminar pide confirmar")
	var body: String = main.confirm_box.body_label.text
	check(body.contains("321") and body.contains("perderá"), "dice el progreso que se pierde (%s)" % body)
	main.confirm_box._open_t = -10.0
	main.confirm_box._answer(false)
	await process_frame
	check(SaveGame.read().has("run") and main.in_menu, "decir que no deja la partida como estaba")
	main._on_new_game("pesadilla")
	await process_frame
	main.confirm_box._open_t = -10.0
	main.confirm_box._answer(true)
	await process_frame
	check(not main.in_menu and main.run.claridad != 321, "decir que sí empieza la partida nueva")
	# sin partida guardada no se pregunta nada
	SaveGame.delete()
	main.in_menu = true
	main._on_new_game("pesadilla")
	await process_frame
	check(not main.confirm_box.visible, "sin partida guardada no se pide confirmación")
	# en el casino no hay reintentar
	main.pause_menu.set_restart(3, false, false, true)
	check(not main.pause_menu.buttons["reiniciar"].visible, "en la pausa del casino no aparece reintentar")
	main.pause_menu.set_restart(3, false, false, false)
	check(main.pause_menu.buttons["reiniciar"].visible and main.pause_menu.buttons["reiniciar"].text.contains("vida"), "en la torre sí, y dice que cuesta una vida")
	main._cancel_jobs()
	main.queue_free()
	await process_frame
	print("tests de las confirmaciones terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
