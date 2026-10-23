extends SceneTree
## Pruebas del costo de reintentar la torre, las estadisticas del run y la pantalla de fin de run.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_run.gd

const RunState := preload("res://scripts/run_state.gd")
const RunEnd := preload("res://scripts/run_end_screen.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_cost()
	await test_restart_flow()
	await test_pause_menu()
	await test_lost_menu()
	await test_end_screen()
	await test_stats()
	print("tests del run terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func make_main() -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	return main


func wait_tower(main: Node) -> void:
	await process_frame
	while main.generating or main.nueva == null:
		await process_frame


func test_cost() -> void:
	var r := RunState.new()
	check(r.restart_cost() == 25, "etapa 1: reintentar cuesta 25 (la mitad de la ficha)")
	r.stage = 8
	check(r.restart_cost() == 39, "etapa 8: 25 + 2 por etapa")
	r.stage = 15
	check(r.restart_cost() == 53, "etapa 15: 53 (la mitad de la ficha de 106)")
	r.tower_retries = 2
	check(r.restart_cost() == 159, "cada reintento de la misma torre cuesta mas: el tercero sale 3 veces el basico")
	r.claridad = 158
	check(not r.can_afford_restart(), "con 158 no alcanza para 159")
	r.claridad = 159
	check(r.can_afford_restart(), "con 159 si")


func test_restart_flow() -> void:
	var main := make_main()
	await wait_tower(main)
	main.run.stage = 1
	main.run.claridad = 100
	var l0: int = main.run.lives
	main.request_restart()
	check(main.run.claridad == 100 and main.run.lives == l0 - 1 and main.run.retries == 1 and main.run.tower_retries == 1 and not main.run_over, "reintentar por voluntad cuesta una vida y no claridad")
	check(main.toast.text.contains("vida"), "se avisa que costó una vida")
	main.request_restart()
	check(main.run.claridad == 100 and main.run.lives == l0 - 2 and main.run.retries == 2, "el segundo también cuesta una vida")
	main.run.lives = 0
	main.request_restart()
	check(main.run.retries == 2 and not main.run_over and main.toast.text.contains("vidas"), "sin vidas no se puede reintentar por voluntad")
	main.run.lives = 2
	main.run.claridad = 25
	# al perder (morir no cuesta claridad: el costo ya es la vida) se puede reintentar aunque no quede claridad
	main.nueva.perder("Caíste al vacío")
	check(main.lost_screen.visible and main.lost_screen.title_label.text == "Caíste al vacío", "al perder aparece la pantalla de derrota con el motivo")
	check(main.lost_screen.retry_button.text.begins_with("Reintentar") and main.lost_screen.hint_label.text == "", "después de morir el botón es Reintentar, sin costo de claridad, aunque no alcance la claridad")
	var lives_before: int = main.run.lives
	main.lost_screen.retry_button.pressed.emit()
	check(not main.run_over and main.run.claridad == 25 and main.run.lives == lives_before - 1 and not main.nueva.t.muerta, "reintentar después de morir no cobra claridad: cuesta una vida")
	main.queue_free()
	await process_frame
	# aviso con claridad suficiente
	main = make_main()
	await wait_tower(main)
	main.run.stage = 1
	main.run.claridad = 500
	main.nueva.perder("Caíste al vacío")
	check(main.lost_screen.visible and main.lost_screen.retry_button.text.begins_with("Reintentar") and main.lost_screen.menu_button.text == "Salir al menú principal", "al perder se muestran los botones Reintentar y Salir al menu")
	main.lost_screen.retry_button.pressed.emit()
	check(not main.lost_screen.visible and main.run.claridad == 500 and main.run.retries == 1 and not main.nueva.t.muerta, "Reintentar con el boton no cobra claridad, vuelve a empezar y esconde la pantalla")
	# entrenamiento: gratis
	main._set_training(true)
	main.run.claridad = 0
	main.run.retries = 0
	main.request_restart()
	check(not main.run_over and main.run.claridad == 0 and main.run.retries == 0, "en el entrenamiento reintentar es gratis")
	main._set_training(false)
	main.queue_free()
	await process_frame
	# cada torre nueva vuelve al costo basico
	main = make_main()
	await wait_tower(main)
	main.run.claridad = 500
	main.request_restart()
	main.request_restart()
	check(main.run.tower_retries == 2, "dos reintentos en esta torre")
	main.enter_casino()
	main.leave_casino()
	while main.generating:
		await process_frame
	check(main.run.tower_retries == 0 and main.run.retries == 2, "una torre nueva reinicia el contador de reintentos de la torre (el total del run no)")
	main.queue_free()
	await process_frame


func test_pause_menu() -> void:
	var main := make_main()
	await wait_tower(main)
	main.run.stage = 1
	main.run.claridad = 200
	main.pause_game()
	var lives0: int = main.run.lives
	check(main.pause_menu.buttons["reiniciar"].text.contains("−1 vida") and not main.pause_menu.buttons["reiniciar"].text.contains("claridad") and main.pause_menu.buttons["abandonar"].visible, "la pausa muestra que reintentar cuesta una vida (no claridad) y el boton de abandonar")
	main.pause_menu.buttons["reiniciar"].pressed.emit()
	check(main.run.claridad == 200 and main.run.lives == lives0 - 1 and not get_root_paused(), "reintentar desde la pausa cuesta una vida y no cobra claridad")
	main.pause_game()
	main.pause_menu.buttons["abandonar"].pressed.emit()
	await process_frame
	check(main.confirm_box.visible and not main.run_over, "abandonar pide confirmación antes de terminar la partida")
	main.confirm_box._open_t = -10.0
	main.confirm_box._answer(false)
	check(not main.run_over, "decir que no sigue la partida")
	main.pause_menu.buttons["abandonar"].pressed.emit()
	await process_frame
	main.confirm_box._open_t = -10.0
	main.confirm_box._answer(true)
	check(main.run_over and main.run_end.visible and main.run_end.title.text == "Fin de la partida", "confirmar lleva a la pantalla de fin de la partida")
	main.queue_free()
	await process_frame
	main = make_main()
	await wait_tower(main)
	main._set_training(true)
	main.pause_game()
	check(main.pause_menu.buttons["reiniciar"].text == "Reintentar la torre" and not main.pause_menu.buttons["abandonar"].visible, "en el entrenamiento el reintento es gratis y no hay run que abandonar")
	main.resume_game()
	main.queue_free()
	await process_frame


func get_root_paused() -> bool:
	return paused


func test_end_screen() -> void:
	var r := RunState.new()
	r.max_stage = 7
	r.towers_cleared = 6
	r.claridad_earned = 1234
	r.casino_spent = 300
	r.casino_won = 450
	r.retries = 3
	r.moves = 987
	r.boosts.assign(["freno_inexistente"])
	var rows := RunEnd.summary_rows(r, false)
	check(rows[0] == ["Etapa alcanzada", "7 / 15", false] and rows[1][1] == "6" and rows[2][1] == "1234" and rows[3][1] == "300" and rows[4][1] == "450" and rows[5][1] == "3" and rows[6][1] == "987", "el resumen trae etapa, torres, claridad, ruleta, reintentos y movimientos")
	check(RunEnd.summary_rows(r, true)[0][1] == "15 / 15", "si escapaste figura 15 / 15")
	var main := make_main()
	await wait_tower(main)
	main.run.towers_cleared = 4
	main.run.take(load("res://scripts/items.gd").get_item("aire_extra"))
	main.end_run(true)
	await process_frame
	check(main.run_end.visible and main.run_end.title.text.contains("Escapaste") and main.run_end.reason_label.text.contains("15"), "ganar el run muestra el titulo de victoria")
	check(main.run_end.stats_box.get_child_count() == 7 and main.run_end.items_row.get_child_count() == 1, "se arman las 7 filas del resumen y los iconos de los boosts")
	check(not main.hud_layer.visible and main.in_menu, "se oculta la interfaz de la torre")
	main.run_end.menu_button.pressed.emit()
	check(not main.run_end.visible and main.main_menu.visible and not main.run_over, "Menu principal vuelve al menu")
	main.queue_free()
	await process_frame
	main = make_main()
	await wait_tower(main)
	main.end_run(false, "Abandonaste la partida.")
	main.run_end.new_button.pressed.emit()
	check(not main.run_end.visible and main.in_menu and main.main_menu.scenarios.visible, "Nueva partida del fin de run lleva al selector de escenario")
	main.main_menu.scenarios.play_buttons["pesadilla"].pressed.emit()
	main.difficulty_screen._open_t = -10.0   # (La Pesadilla pregunta la dificultad primero)
	main.difficulty_screen._choose("media")
	check(not main.in_menu and main.stage_number == 1 and main.run.retries == 0 and not main.run_over, "elegir un escenario arranca un run nuevo desde la etapa 1")
	main.queue_free()
	await process_frame


func test_stats() -> void:
	var main := make_main()
	await wait_tower(main)
	check(main.run.moves == 0 and main.run.towers_cleared == 0, "al empezar las estadisticas estan en cero")
	var cam: Array = main.nueva.t.salas[0].d.camino   # (el primer paso del camino de la sala)
	main.nueva.accion(Vector3i(int(cam[0][0]), 0, int(cam[0][1])), int(cam[0][2]))
	await process_frame
	check(main.run.moves >= 1, "cada movimiento valido suma a las estadisticas")
	main.nueva.t.cosecha.sala = 60
	await main._torre_nueva_ganada()
	check(main.run.towers_cleared == 1 and main.run.claridad_earned == 60, "al pasar la torre suma torres superadas y la claridad juntada")
	main.queue_free()
	await process_frame


## Perder y salir al menú principal desde la pantalla de derrota.
func test_lost_menu() -> void:
	var main := make_main()
	await wait_tower(main)
	main.run.stage = 1
	main.run.claridad = 500
	main.nueva.perder("Caíste al vacío")
	check(main.lost_screen.visible, "al perder aparece la pantalla de derrota")
	main.lost_screen.menu_button.pressed.emit()
	check(main.in_menu and not main.lost_screen.visible, "Salir al menu principal vuelve al menu y esconde la pantalla")
	main.queue_free()
	await process_frame
