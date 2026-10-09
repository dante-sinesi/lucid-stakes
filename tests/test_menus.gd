extends SceneTree
## Pruebas de los menús (principal y pausa), del aclarado por etapa y del final del juego (headless).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_menus.gd

const Gen := preload("res://scripts/tower_gen.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	await test_start()
	await test_pause_and_back()
	await test_stage_look()
	await test_final()
	print("tests de los menus terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func make_main(test := false) -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = test
	main.quit_game_override = true  # no cerrar el proceso de pruebas
	main.ready.connect(func(): main.dice.auto_start = true)   # la pantalla de carga de los dados no espera el boton Empezar
	root.add_child(main)
	return main


func test_start() -> void:
	var main := make_main()
	await process_frame
	check(main.in_menu and main.main_menu.visible and not main.generating and main.logic == null, "al abrir el juego se ve el menu principal y no se genera nada")
	check(not main.hud_layer.visible, "el HUD de la torre esta oculto en el menu")
	var keys: Array = main.main_menu.buttons.keys()
	check(keys.has("nueva") and keys.has("salir") and not keys.has("ayuda") and not keys.has("tutorial"), "el menu tiene Nueva partida y Salir; ya no Como jugar ni Tutorial suelto (el tutorial es una tarjeta de Nueva partida)")
	# Créditos: botón abajo a la izquierda con el aviso y la licencia MIT de Godot
	var cb: Control = main.main_menu.buttons["creditos"]
	check(cb.visible and cb.anchor_top == 1.0 and cb.anchor_left == 0.0, "el boton de creditos esta abajo a la izquierda")
	cb.pressed.emit()
	check(main.main_menu.credits.visible and not cb.visible and not main.main_menu.column.get_parent().visible, "Creditos abre la ventana y esconde el menu")
	var ctext: String = main.main_menu.credits.find_child("texto_creditos", true, false).text
	check(ctext.contains("Godot Engine") and not ctext.contains("Permission is hereby granted") and ctext.length() < 400, "los creditos son cortos: nombran a Godot pero no traen las licencias")
	main.main_menu.credits.find_child("licencias", true, false).pressed.emit()
	var ltext: String = main.main_menu.licenses.find_child("texto_licencias", true, false).text
	check(main.main_menu.licenses.visible and not main.main_menu.credits.visible and ltext.contains("MIT") and ltext.contains("Permission is hereby granted") and ltext.contains("Juan Linietsky"), "la pantalla de licencias trae el aviso de copyright y la licencia MIT de Godot")
	main.main_menu.licenses.find_child("volver_licencias", true, false).pressed.emit()
	check(main.main_menu.credits.visible and not main.main_menu.licenses.visible, "Volver de las licencias vuelve a los creditos")
	main.main_menu.credits.find_child("volver_creditos", true, false).pressed.emit()
	check(not main.main_menu.credits.visible and cb.visible and main.main_menu.column.get_parent().visible, "Volver cierra los creditos")
	# Entrar al juego: etapa 1 con torre de 25 pisos
	main.tower_rows = 4  # torre chica para que el test sea rapido
	main.test_mode_jobs = true
	main.main_menu.buttons["nueva"].pressed.emit()   # abre el selector de escenario
	check(main.main_menu.scenarios.visible and not main.main_menu.main_center.visible and main.in_menu, "Nueva partida abre el selector de escenario")
	main.main_menu.scenarios.play_buttons["pesadilla"].pressed.emit()   # el gratuito
	check(not main.in_menu and not main.main_menu.visible and main.hud_layer.visible and main.stage_number == 1, "Nueva partida arranca en la etapa 1 con el HUD")
	while main.generating or main.logic == null:
		await process_frame
	check(main.logic.goal_y == 5 and main.run.stage == 1, "se genero la torre de la etapa (4 filas en el test)")
	main._cancel_jobs()
	main.queue_free()
	await process_frame


func test_pause_and_back() -> void:
	var main := make_main(true)
	await process_frame
	main.hud_layer.visible = true
	while main.generating or main.logic == null:
		await process_frame
	main.pause_game()
	check(get_root_paused() and main.pause_menu.visible, "pausar muestra el menu y detiene el juego")
	var before: Vector3i = main.logic.player
	main.resume_game()
	check(not get_root_paused() and not main.pause_menu.visible, "continuar cierra la pausa")
	main.pause_game()
	check(not main.pause_menu.buttons.has("ayuda"), "la pausa ya no tiene Como jugar")
	main.run.claridad = 100   # reintentar cuesta claridad
	main.pause_menu.buttons["reiniciar"].pressed.emit()
	check(not get_root_paused() and main.logic.player == before and main.logic.moves_made == 0, "reintentar la torre sale de la pausa y reinicia")
	# Volver al menu principal desde el juego
	main.pause_game()
	main.pause_menu.buttons["menu"].pressed.emit()
	check(main.in_menu and main.main_menu.visible and not get_root_paused() and not main.pause_menu.visible and not main.hud_layer.visible, "volver al menu principal desde la pausa")
	main.queue_free()
	await process_frame


func get_root_paused() -> bool:
	return paused


func test_stage_look() -> void:
	var main := make_main(true)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	main.stage_number = 1
	check(is_equal_approx(main.stage_tone(), 0.0) and main._stage_tint().is_equal_approx(Color.WHITE), "etapa 1: tono 0 y tinte neutro")
	main.stage_number = 27
	check(is_equal_approx(main.stage_tone(), 1.0), "etapa 27: tono 1")
	var lum := func(c: Color) -> float: return c.get_luminance()
	var prev := -1.0
	var bgs_ok := true
	var tint_ok := true
	var prev_tint := 0.0
	for st in range(1, 28):
		main.stage_number = st
		main._apply_stage_look()
		var l: float = lum.call(main.env.background_color)
		bgs_ok = bgs_ok and l > prev
		prev = l
		var tl: float = main._stage_tint().r
		tint_ok = tint_ok and tl > prev_tint
		prev_tint = tl
	check(bgs_ok, "el fondo es mas claro en cada etapa que en la anterior")
	check(tint_ok, "el tinte de los bloques es mas claro en cada etapa")
	# Dentro de una misma etapa el fondo no cambia aunque se suba.
	main.stage_number = 10
	main._apply_stage_look()
	var bg_a: Color = main.env.background_color
	main.logic.player = main.logic.player + Vector3i(0, 2, 0)
	main._refresh()
	check(main.env.background_color == bg_a, "dentro de una etapa el fondo no cambia con la altura")
	main.queue_free()
	await process_frame


func test_final() -> void:
	var main := make_main(true)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	main.quick_portal = true
	main.stage_number = 27
	main.logic.claridad = 10
	main.logic.won = true
	await main._on_anim_done()
	check(main.casino == null and main.in_menu and main.run_end.visible and main.run_over, "al pasar la etapa 27 no hay casino: termina el run y se ve la pantalla de fin")
	main.queue_free()
	await process_frame
