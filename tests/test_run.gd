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
	await test_prefetch()
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
	while main.generating or main.logic == null:
		await process_frame


func test_cost() -> void:
	var r := RunState.new()
	check(r.restart_cost() == 25, "etapa 1: reintentar cuesta 25 (la mitad de la ficha)")
	r.stage = 10
	check(r.restart_cost() == 34, "etapa 10: 25 + 9")
	r.stage = 27
	check(r.restart_cost() == 51, "etapa 27: 51 (la mitad de la ficha de 102)")
	r.tower_retries = 2
	check(r.restart_cost() == 153, "cada reintento de la misma torre cuesta mas: el tercero sale 3 veces el basico")
	r.claridad = 152
	check(not r.can_afford_restart(), "con 152 no alcanza para 153")
	r.claridad = 153
	check(r.can_afford_restart(), "con 153 si")


func test_restart_flow() -> void:
	var main := make_main()
	await wait_tower(main)
	main.run.stage = 1
	main.run.claridad = 100
	main.request_restart()
	check(main.run.claridad == 75 and main.run.retries == 1 and main.run.tower_retries == 1 and not main.run_over, "el primer reintento cuesta 25")
	check(main.toast.text.contains("25"), "se avisa cuanto costo")
	main.request_restart()
	check(main.run.claridad == 25 and main.run.retries == 2, "el segundo cuesta 50")
	check(main.run.restart_cost() == 75 and not main.run.can_afford_restart(), "el tercero ya no se puede pagar")
	# al perder, el aviso dice cuanto cuesta (o que ya no alcanza)
	main.logic.lost = true
	main.logic.lost_reason = "Caíste al vacío"
	main._on_anim_done()
	check(main.lost_screen.visible and main.lost_screen.title_label.text == "Caíste al vacío", "al perder aparece la pantalla de derrota con el motivo")
	check(main.lost_screen.hint_label.text.contains("No te alcanza") and main.lost_screen.hint_label.text.contains("75") and main.lost_screen.retry_button.text == "Terminar el run", "sin claridad el boton pasa a Terminar el run y dice cuanto costaba")
	main.lost_screen.retry_button.pressed.emit()
	check(main.run_over and main.run_end.visible and main.in_menu, "sin claridad para reintentar el run termina")
	check(main.run_end.reason_label.text.contains("No te alcanza"), "la pantalla de fin dice el motivo")
	main.queue_free()
	await process_frame
	# aviso con claridad suficiente
	main = make_main()
	await wait_tower(main)
	main.run.stage = 1
	main.run.claridad = 500
	main.logic.lost = true
	main.logic.lost_reason = "Caíste al vacío"
	main._on_anim_done()
	check(main.lost_screen.visible and main.lost_screen.retry_button.text.contains("−25") and main.lost_screen.menu_button.text == "Salir al menú principal", "al perder se muestran los botones Reintentar (con su costo) y Salir al menu")
	main.lost_screen.retry_button.pressed.emit()
	check(not main.lost_screen.visible and main.run.claridad == 475 and main.run.retries == 1 and not main.logic.lost, "Reintentar con el boton cobra, vuelve a empezar y esconde la pantalla")
	# entrenamiento: gratis
	main.logic.lost = false
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
	check(main.pause_menu.buttons["reiniciar"].text.contains("(−25)") and main.pause_menu.buttons["abandonar"].visible, "la pausa muestra el costo del reintento y el boton de abandonar")
	main.pause_menu.buttons["reiniciar"].pressed.emit()
	check(main.run.claridad == 175 and not get_root_paused(), "reintentar desde la pausa cobra el costo")
	main.pause_game()
	check(main.pause_menu.buttons["reiniciar"].text.contains("(−50)"), "y el siguiente cuesta mas")
	main.pause_menu.buttons["abandonar"].pressed.emit()
	check(main.run_over and main.run_end.visible and main.run_end.title.text == "Fin del run", "Abandonar el run lleva a la pantalla de fin de run")
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
	check(rows[0] == ["Etapa alcanzada", "7 / 27", false] and rows[1][1] == "6" and rows[2][1] == "1234" and rows[3][1] == "300" and rows[4][1] == "450" and rows[5][1] == "3" and rows[6][1] == "987", "el resumen trae etapa, torres, claridad, ruleta, reintentos y movimientos")
	check(RunEnd.summary_rows(r, true)[0][1] == "27 / 27", "si escapaste figura 27 / 27")
	var main := make_main()
	await wait_tower(main)
	main.run.towers_cleared = 4
	main.run.take(load("res://scripts/items.gd").get_item("aire_extra"))
	main.end_run(true)
	await process_frame
	check(main.run_end.visible and main.run_end.title.text.contains("Escapaste") and main.run_end.reason_label.text.contains("27"), "ganar el run muestra el titulo de victoria")
	check(main.run_end.stats_box.get_child_count() == 7 and main.run_end.items_row.get_child_count() == 1, "se arman las 7 filas del resumen y los iconos de los boosts")
	check(not main.hud_layer.visible and main.in_menu, "se oculta la interfaz de la torre")
	main.run_end.menu_button.pressed.emit()
	check(not main.run_end.visible and main.main_menu.visible and not main.run_over, "Menu principal vuelve al menu")
	main.queue_free()
	await process_frame
	main = make_main()
	await wait_tower(main)
	main.end_run(false, "Abandonaste el run.")
	main.run_end.new_button.pressed.emit()
	check(not main.run_end.visible and main.in_menu and main.main_menu.scenarios.visible, "Nueva partida del fin de run lleva al selector de escenario")
	main.main_menu.scenarios.play_buttons["pesadilla"].pressed.emit()
	check(not main.in_menu and main.stage_number == 1 and main.run.retries == 0 and not main.run_over, "elegir un escenario arranca un run nuevo desde la etapa 1")
	main._cancel_jobs()
	main.queue_free()
	await process_frame


func test_stats() -> void:
	var main := make_main()
	await wait_tower(main)
	check(main.run.moves == 0 and main.run.towers_cleared == 0, "al empezar las estadisticas estan en cero")
	for d in [Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]:   # (la torre es al azar: se prueba hasta que alguna direccion sea valida)
		main._apply(d, 0)
		if main.run.moves >= 1:
			break
	await process_frame
	check(main.run.moves >= 1, "cada movimiento valido suma a las estadisticas")
	main.logic.claridad = 60
	main.logic.won = true
	await main._on_anim_done()
	check(main.run.towers_cleared == 1 and main.run.claridad_earned == 60, "al pasar la torre suma torres superadas y la claridad juntada")
	main.queue_free()
	await process_frame


## La torre siguiente se genera de antemano: ya al entrar al casino hay una generación en curso (o terminada) para la etapa siguiente.
func test_prefetch() -> void:
	var main := make_main()
	main.test_mode_jobs = true
	await wait_tower(main)
	check(not main._find_job(main.stage_number + 1).is_empty(), "al estar lista la torre ya se genera la siguiente")
	main._cancel_jobs()
	check(main._find_job(main.stage_number + 1).is_empty(), "(sin generaciones pendientes)")
	main.enter_casino()
	check(not main._find_job(main.stage_number + 1).is_empty(), "al entrar al casino se asegura que la torre siguiente se este generando")
	var job: Dictionary = main._find_job(main.stage_number + 1)
	main.enter_casino()   # no duplica
	check(main._jobs.size() == 1 and main._find_job(main.stage_number + 1) == job, "no se lanza dos veces la misma generacion")
	main.leave_casino()   # usa la generacion ya hecha (o la espera): no empieza de cero
	while main.generating:
		await process_frame
	check(main.logic != null and main.stage_number == 7, "al cruzar el portal se usa la torre que ya venia generandose")
	main._cancel_jobs()
	main.queue_free()
	await process_frame


## Perder y salir al menú principal desde la pantalla de derrota.
func test_lost_menu() -> void:
	var main := make_main()
	await wait_tower(main)
	main.run.stage = 1
	main.run.claridad = 500
	main.logic.lost = true
	main.logic.lost_reason = "Caíste al vacío"
	main._on_anim_done()
	check(main.lost_screen.visible, "al perder aparece la pantalla de derrota")
	main.lost_screen.menu_button.pressed.emit()
	check(main.in_menu and not main.lost_screen.visible, "Salir al menu principal vuelve al menu y esconde la pantalla")
	main.queue_free()
	await process_frame
