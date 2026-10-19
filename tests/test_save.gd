extends SceneTree
## Pruebas de guardar y continuar: serializacion de torres y del run, archivo de guardado y el flujo completo en el juego.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_save.gd

const Gen := preload("res://scripts/tower_gen.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const RunState := preload("res://scripts/run_state.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const Items := preload("res://scripts/items.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	SaveGame.path = "user://test_save.json"
	SaveGame.delete()
	test_tower_roundtrip()
	test_run_roundtrip()
	test_file()
	await test_flow_tower()
	await test_flow_casino()
	await test_death_saves()
	await test_end_deletes()
	await test_menu_button()
	SaveGame.delete()
	print("tests de guardado terminados, fallos: ", fails)
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


func test_tower_roundtrip() -> void:
	var r := Gen.generate_stage(3, 4, 0.5, {"tries": 6, "climb": 0.5, "max_states": 2000})
	check(r.ok, "se genera una torre chica")
	var a = r.logic
	var json := JSON.stringify(a.to_dict())
	var b = TowerLogic.from_dict(JSON.parse_string(json))
	check(a.blocks == b.blocks and a.positions == b.positions and a.fixed == b.fixed, "mismos bloques, ids y fijos")
	check(a.kind_of == b.kind_of and a.bomb_timer == b.bomb_timer, "mismos tipos y cuentas de bomba")
	check(a.size == b.size and a.goal_y == b.goal_y and a.goal_cell == b.goal_cell and a.goal_block == b.goal_block and a.player == b.player, "misma meta y punto de partida")
	check(a.collapse_every == b.collapse_every and a.moves_to_collapse == b.moves_to_collapse and a.floor_y == b.floor_y and a._next_id == b._next_id, "misma caida de la fila de abajo")
	check(a.row_platforms == b.row_platforms and a.platform_row == b.platform_row, "mismas plataformas por fila (para la pista)")
	check(a.zob == b.zob, "misma huella del estado")
	var s = b.clone()
	for act in r.path:
		s.try_action(act.dir, act.mode)
	check(s.won and not s.lost, "el camino de la torre generada gana sobre la torre guardada y cargada")


func test_run_roundtrip() -> void:
	var run := RunState.new()
	run.stage = 9
	run.claridad = 431
	run.boosts.assign(["aire_extra", "mente_abierta"])
	run.consumables.assign(["freno"])
	run.casino_spent = 200
	run.casino_won = 90
	run.retries = 3
	run.tower_retries = 1
	run.towers_cleared = 8
	run.claridad_earned = 1500
	run.moves = 777
	run.max_stage = 9
	var back = RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	check(back.to_dict() == run.to_dict(), "el run se guarda y se carga igual")
	check(back.boosts == ["aire_extra", "mente_abierta"] and back.boost_capacity() == 7 and back.consumables == ["freno"], "los boosts y consumibles vuelven como Array[String] y con su capacidad")


func test_file() -> void:
	check(not SaveGame.exists() and SaveGame.read().is_empty() and SaveGame.peek_stage() == -1, "sin archivo no hay nada que continuar")
	check(SaveGame.write({"run": {"stage": 4}, "phase": "casino", "stage": 4}) and SaveGame.exists() and SaveGame.peek_stage() == 4, "se escribe y se lee")
	SaveGame.delete()
	check(not SaveGame.exists(), "borrar el archivo")
	var f := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	f.store_string("esto no es json {{{")
	f = null
	check(SaveGame.read().is_empty() and SaveGame.peek_stage() == -1, "un archivo danado se ignora")
	f = FileAccess.open(SaveGame.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 99, "run": {}, "phase": "tower", "stage": 2}))
	f = null
	check(SaveGame.read().is_empty(), "un archivo de otra version se ignora")
	f = FileAccess.open(SaveGame.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "stage": 2}))
	f = null
	check(SaveGame.read().is_empty(), "un archivo incompleto se ignora")
	SaveGame.delete()


func test_flow_tower() -> void:
	var a := make_main()
	await wait_tower(a)
	check(SaveGame.exists() and SaveGame.read().phase == "tower" and SaveGame.read().dirty == false, "al estar lista la torre se guarda (todavia sin empezar)")
	check(a.run.stage == a.stage_number and SaveGame.peek_stage() == a.stage_number, "el guardado dice en que etapa estas")
	# Continuar sin haber empezado: misma torre y sin costo
	a.run.claridad = 300
	a.save_game()
	var blocks_a: Dictionary = a.stage_start.blocks.duplicate()
	var goal_a: int = a.stage_start.goal_block
	var c := make_main()
	await wait_tower(c)   # genera su propia torre y guarda; reescribimos el guardado de A para continuar desde ahi
	a.save_game()
	c.continue_game()
	check(c.stage_start.blocks == blocks_a and c.stage_start.goal_block == goal_a, "continuar vuelve a la misma torre")
	check(c.run.claridad == 300 and c.run.retries == 0, "si el intento no habia empezado, continuar no cuesta nada")
	check(not c.in_menu and c.hud_layer.visible and c.casino == null, "se vuelve al juego en la torre")
	# Primer movimiento: el intento ya empezo -> se guarda como 'sucio'
	a.run.stage = 1
	for dir in TowerLogic.DIRS:   # el primer movimiento valido
		if not a.attempt_dirty and not a.busy:
			a._apply(dir, 0)
	check(a.attempt_dirty and SaveGame.read().dirty == true, "al primer movimiento el guardado queda marcado como intento empezado")
	# Continuar con el intento empezado cuenta como un reintento
	var d := make_main()
	await wait_tower(d)
	a.save_game()
	d.continue_game()
	check(d.run.retries == 1 and d.run.tower_retries == 1 and d.run.claridad == 275, "continuar con el intento empezado cuesta un reintento (25)")
	check(d.logic.moves_made == 0, "...y la torre empieza de cero")
	# Sin claridad para ese reintento: el run termina
	a.run.claridad = 0
	a.save_game()
	var e := make_main()
	await wait_tower(e)
	a.save_game()
	e.continue_game()
	check(e.run_over and e.run_end.visible and not SaveGame.exists(), "si no alcanza para pagar el reintento al continuar, el run termina (y se borra el guardado)")
	for m in [a, c, d, e]:
		m._cancel_jobs()
		m.queue_free()
	await process_frame
	SaveGame.delete()


## Morir guarda al instante: si se sale al menú sin reintentar, al continuar ya cuenta la muerte (una vida menos). Alt + F4 también guarda.
func test_death_saves() -> void:
	var a := make_main()
	await wait_tower(a)
	a.run.claridad = 500
	a.attempt_dirty = true
	a.save_game()
	check(SaveGame.read().dead == false, "vivo: el guardado no dice que murió")
	var lives_before: int = a.run.lives
	a.logic.lost = true
	a.logic.lost_reason = "Caíste al vacío"
	await a._on_anim_done()
	check(SaveGame.read().dead == true and a.lost_screen.visible, "al morir se guarda al instante, marcando la muerte")
	check(a.run.lives == lives_before, "(la vida se gasta recién al continuar o reintentar)")
	var b := make_main()
	await wait_tower(b)
	a.save_game()
	b.continue_game()
	check(b.run.lives == lives_before - 1 and b.run.retries == 1, "salir sin reintentar y continuar: ya costó una vida")
	check(not b.logic.lost and SaveGame.read().dead == false, "y la torre empieza de cero (vivo)")
	# Sin vidas ni Tótem: al continuar el run termina
	a.run.lives = 0
	a.save_game()
	var c := make_main()
	await wait_tower(c)
	a.save_game()
	c.continue_game()
	check(c.run_over, "si ya no te quedaban vidas, continuar después de morir termina el run")
	# Alt + F4: guardado rápido
	var d := make_main()
	await wait_tower(d)
	SaveGame.delete()
	d.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(SaveGame.exists(), "al cerrar la ventana (Alt + F4) se guarda")
	for m in [a, b, c, d]:
		m._cancel_jobs()
		m.queue_free()
	await process_frame
	SaveGame.delete()


func test_flow_casino() -> void:
	var a := make_main()
	await wait_tower(a)
	a.run.claridad = 400
	a.logic.claridad = 20
	a.logic.won = true
	await a._on_anim_done()
	check(a.casino != null and SaveGame.read().phase == "casino" and int(SaveGame.read().run.claridad) == 420, "al entrar al casino se guarda con la claridad ya sumada")
	# cada tirada de la ruleta se guarda al resolverse (antes de la animacion)
	a.casino.quick = true
	a.casino.open_roulette()
	a.casino.screen.fast = true
	a.casino.screen.toggle_pocket(3)
	var before := int(SaveGame.read().run.claridad)
	a.casino.screen.spin()   # sin await: se cobra al instante
	check(int(SaveGame.read().run.claridad) != before or a.run.claridad != before, "la tirada se guarda en cuanto se cobra")
	check(int(SaveGame.read().run.claridad) == a.run.claridad, "lo guardado coincide con la claridad actual")
	var saved_claridad: int = a.run.claridad
	var stage_saved: int = a.stage_number
	await process_frame
	a.casino.close_roulette()
	# continuar: vuelve al casino con el mismo run
	var b := make_main()
	await wait_tower(b)
	a.save_game()
	b.continue_game()
	check(b.casino != null and b.run.claridad == saved_claridad and b.stage_number == stage_saved and b.run.towers_cleared == a.run.towers_cleared, "continuar vuelve al casino con el mismo run")
	check(b.run.towers_cleared == 1, "sin volver a sumar la torre superada")
	b.casino.quick = true
	b.casino.cell = b.casino.lay.exit
	b.casino.step(Vector2i(0, -1))
	var loading := SaveGame.read()
	check(b.generating and str(loading.get("phase", "")) == "loading" and int(loading.stage) == stage_saved + 1, "al irse del casino (peaje pagado) se guarda la carga de la torre que sigue: al cerrar y volver no se repite el casino")
	var c := make_main()   # cerrar el juego ahora y volver: continúa la carga de la torre siguiente, no el casino
	await wait_tower(c)
	SaveGame.write(loading)   # (lo que había en disco al cerrar el juego justo después de pagar)
	c.continue_game()
	check(c.casino == null and c.stage_number == stage_saved + 1 and c.generating, "continuar después de pagar sigue la torre siguiente (sin volver al casino)")
	while b.generating or c.generating:
		await process_frame
	check(b.stage_number == stage_saved + 1 and b.logic != null, "al salir del casino empieza la etapa siguiente")
	check(c.logic != null and c.stage_number == stage_saved + 1, "la partida continuada llega a la torre siguiente")
	for m in [a, b, c]:
		m._cancel_jobs()
		m.queue_free()
	await process_frame
	SaveGame.delete()


func test_end_deletes() -> void:
	var a := make_main()
	await wait_tower(a)
	check(SaveGame.exists(), "hay un guardado en una torre")
	a.end_run(false, "x")
	check(not SaveGame.exists(), "al terminar el run se borra el guardado")
	a.save_game()
	check(not SaveGame.exists(), "y con el run terminado no se vuelve a guardar")
	a.queue_free()
	await process_frame
	# el entrenamiento no guarda
	var t := make_main()
	await wait_tower(t)
	SaveGame.delete()
	t._set_training(true)
	t.save_game()
	check(not SaveGame.exists(), "el modo entrenamiento no guarda")
	t.queue_free()
	await process_frame


func test_menu_button() -> void:
	SaveGame.delete()
	var a := make_main()
	await wait_tower(a)
	a.open_main_menu()   # guarda al salir al menu
	check(SaveGame.exists() and a.main_menu.buttons["continuar"].visible and a.main_menu.buttons["continuar"].text.contains("etapa %d" % a.stage_number), "al volver al menu aparece Continuar con la etapa")
	check(a.main_menu.buttons["continuar"].primary and not a.main_menu.buttons["nueva"].primary, "Continuar pasa a ser el boton principal")
	a.main_menu.buttons["continuar"].pressed.emit()
	check(not a.in_menu and a.logic != null, "Continuar vuelve al juego")
	a.end_run(false)
	a.open_main_menu()
	check(not a.main_menu.buttons["continuar"].visible and a.main_menu.buttons["nueva"].primary, "sin guardado no hay Continuar")
	a._cancel_jobs()
	a.queue_free()
	await process_frame
