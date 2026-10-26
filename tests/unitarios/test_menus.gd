extends SceneTree
## Pruebas de los menús (principal y pausa), del aclarado por etapa y del final del juego (headless).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_menus.gd


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
	var P := preload("res://scripts/datos/profile.gd")
	P.path = "user://test_profile.json"   # (el perfil de prueba: con el tutorial ya hecho, si no el juego arranca en el tutorial)
	P._loaded_from = ""
	P.mark_tutorial_done()
	var SaveG := preload("res://scripts/datos/save_game.gd")
	SaveG.path = "user://test_save.json"   # (que una partida guardada por otra prueba no cambie cómo arranca el menú)
	SaveG.delete()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = test
	main.quit_game_override = true  # no cerrar el proceso de pruebas
	main.ready.connect(func(): main.dice.auto_start = true)   # la pantalla de carga de los dados no espera el boton Empezar
	root.add_child(main)
	return main


func test_start() -> void:
	var main := make_main()
	await process_frame
	check(main.in_menu and main.main_menu.visible and not main.generating and main.torre == null, "al abrir el juego se ve el menu principal y no se genera nada")
	check(not main.hud_layer.visible, "el HUD de la torre esta oculto en el menu")
	var keys: Array = main.main_menu.buttons.keys()
	check(keys.has("nueva") and keys.has("salir") and not keys.has("ayuda") and not keys.has("tutorial"), "el menu tiene Nueva partida y Salir; ya no Como jugar ni Tutorial suelto (el tutorial es una tarjeta de Nueva partida)")
	# Créditos: botón abajo a la izquierda con el aviso y la licencia MIT de Godot
	var cb: Control = main.main_menu.buttons["creditos"]
	check(not cb.visible and main.main_menu.main_hints != null and main.main_menu.main_hints.visible, "los creditos se abren desde la botonera de abajo (Y o C), sin boton")
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
	check(not main.main_menu.credits.visible and main.main_menu.main_hints.visible and main.main_menu.column.get_parent().visible, "Volver cierra los creditos")
	# Entrar al juego: etapa 1 con torre de 25 pisos
	main.main_menu.buttons["nueva"].pressed.emit()   # abre el selector de escenario
	check(main.main_menu.scenarios.visible and not main.main_menu.main_center.visible and main.in_menu, "Nueva partida abre el selector de escenario")
	main.main_menu.scenarios.play_buttons["pesadilla"].pressed.emit()   # el gratuito
	main.difficulty_screen._open_t = -10.0   # (La Pesadilla pregunta la dificultad primero)
	var teclas := []
	main.difficulty_screen.chosen.connect(func(id): teclas.append(id))
	for k in [KEY_S]:   # con WASD se baja una vez (de Medio a Difícil) y Espacio elige "Difícil", no "Medio"
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.pressed = true
		main.difficulty_screen._input(ev)
	var esp := InputEventKey.new()
	esp.keycode = KEY_SPACE
	esp.pressed = true
	main.difficulty_screen._input(esp)
	check(teclas == ["dificil"], "en el selector de dificultad, WASD mueve y Espacio elige la opción apuntada")
	if main.confirm_box.visible:   # (había una partida guardada: pide confirmar que se pierde)
		main.confirm_box._open_t = -10.0
		main.confirm_box._answer(true)
		await process_frame
	check(not main.in_menu and not main.main_menu.visible and main.hud_layer.visible and main.stage_number == 1, "Nueva partida arranca en la etapa 1 con el HUD")
	while main.generating or main.torre == null:
		await process_frame
	check(main.torre.t.salas.size() >= 5 and main.run.stage == 1, "se armó la torre de la etapa 1")
	check(main.fondo != null and main.env.background_mode == Environment.BG_CANVAS and main.fondo.layer < 0, "el fondo animado va detrás de todo (BG_CANVAS)")
	main.queue_free()
	await process_frame


func test_pause_and_back() -> void:
	var main := make_main(true)
	await process_frame
	main.hud_layer.visible = true
	while main.generating or main.torre == null:
		await process_frame
	main.pause_game()
	check(get_root_paused() and main.pause_menu.visible, "pausar muestra el menu y detiene el juego")
	var before: Vector3i = main.torre.t.motor.jugador
	main.resume_game()
	check(not get_root_paused() and not main.pause_menu.visible, "continuar cierra la pausa")
	main.pause_game()
	check(not main.pause_menu.buttons.has("ayuda"), "la pausa ya no tiene Como jugar")
	main.run.claridad = 100   # reintentar cuesta claridad
	main.pause_menu.buttons["reiniciar"].pressed.emit()
	check(not get_root_paused() and main.torre.t.motor.jugador == before and main.torre.t.movs == 0, "reintentar la torre sale de la pausa y reinicia")
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
	while main.generating or main.torre == null:
		await process_frame
	main.stage_number = 1
	check(is_equal_approx(main.stage_tone(), 0.0), "etapa 1: tono 0")
	main.stage_number = 15
	check(is_equal_approx(main.stage_tone(), 1.0), "etapa 15: tono 1")
	var lum := func(c: Color) -> float: return c.get_luminance()
	var prev := 2.0
	var bgs_ok := true
	for st in range(1, 16):
		main.stage_number = st
		main._apply_stage_look()
		var l: float = lum.call(main.env.background_color)
		bgs_ok = bgs_ok and l <= prev
		prev = l
	check(bgs_ok, "el fondo es más oscuro (o igual) en cada etapa que en la anterior: los bloques se aclaran y tienen que recortarse")
	# Dentro de una misma etapa el fondo no cambia aunque se suba.
	main.stage_number = 8
	main._apply_stage_look()
	var bg_a: Color = main.env.background_color
	main._refresh()
	check(main.env.background_color == bg_a, "dentro de una etapa el fondo no cambia con la altura")
	main.queue_free()
	await process_frame


func test_final() -> void:
	var main := make_main(true)
	await process_frame
	while main.generating or main.torre == null:
		await process_frame
	main.quick_portal = true
	main.stage_number = 15
	main.torre.t.cosecha.sala = 10
	await main._torre_ganada()
	check(main.casino == null and main.in_menu and main.run_end.visible and main.run_over, "al pasar la etapa 15 no hay casino: termina el run y se ve la pantalla de fin")
	main.queue_free()
	await process_frame
