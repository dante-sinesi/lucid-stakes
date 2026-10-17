extends SceneTree
## "Abandonar el run" (y los demás caminos que cancelan la generación) no puede colgar el juego: tiene que volver en poco tiempo
## aunque se esté generando una torre alta (la actual o la de la etapa siguiente).
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_abandonar.gd

const MAX_MS := 2500   # lo más que puede tardar `end_run` con trabajos de generación vivos

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	await test_abandon_while_generating()
	await test_abandon_from_pause()
	print("tests de abandonar terminados, fallos: ", fails)
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


## Se deja generando la etapa siguiente (torre alta) y se abandona: end_run tiene que volver rápido.
func test_abandon_while_generating() -> void:
	var main := make_main()
	await wait_tower(main)
	main.in_menu = false
	main.stage_number = 12   # (torres de 80+ pisos: la generación tarda bastante)
	main.run.stage = 12
	var job: Dictionary = main._start_job(13, 424242)
	await process_frame
	check(main._job_alive(job), "la generación de la etapa 13 está en curso")
	var t0 := Time.get_ticks_msec()
	main.end_run(false, "Abandonaste el run.")
	var ms := Time.get_ticks_msec() - t0
	print("end_run con generación viva: ", ms, " ms")
	check(ms < MAX_MS, "abandonar con una torre generándose no se cuelga (%d ms)" % ms)
	check(main.run_over, "el run terminó")
	# los hilos cancelados tienen que terminar solos poco después (no quedan colgados de fondo) y bajar la bandera
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 20000 and not main._zombies.is_empty():
		await process_frame
	print("los hilos cancelados terminaron en ", Time.get_ticks_msec() - t1, " ms")
	check(main._zombies.is_empty(), "los hilos cancelados terminaron")
	check(not preload("res://scripts/gen_abort.gd").flag and not preload("res://scripts/tower_gen.gd").cancel, "la bandera de cancelación se bajó")
	main.queue_free()
	await process_frame


## El botón del menú de pausa hace lo mismo.
func test_abandon_from_pause() -> void:
	var main := make_main()
	await wait_tower(main)
	main.in_menu = false
	main.stage_number = 12
	main.run.stage = 12
	var job: Dictionary = main._start_job(13, 777)
	await process_frame
	main.pause_game()
	var t0 := Time.get_ticks_msec()
	main.pause_menu.abandon_run.emit()
	var ms := Time.get_ticks_msec() - t0
	print("abandonar desde la pausa: ", ms, " ms")
	check(ms < MAX_MS, "el botón Abandonar el run vuelve rápido (%d ms)" % ms)
	check(not paused, "el juego no queda en pausa")
	check(main.run_over, "el run terminó")
	main.queue_free()
	await process_frame
