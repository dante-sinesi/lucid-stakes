extends SceneTree
## Pruebas del tutorial: cada lección se puede ganar, las que enseñan empujar o colgarse lo exigen, y el flujo dentro del juego.
## Las flechas mueven la cámara (no al personaje).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_tutorial.gd

const Tutorial := preload("res://scripts/tutorial.gd")
const Solver := preload("res://scripts/solver.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_lessons()
	test_pull_lesson()
	await test_flow()
	await test_arrows()
	print("tests del tutorial terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_lessons() -> void:
	var lessons := Tutorial.lessons()
	check(lessons.size() == Tutorial.count() and lessons.size() >= 8, "hay varias lecciones")
	var ids := {}
	for l in lessons:
		ids[l.id] = true
		check(l.title != "" and l.text != "" and (l.has("build") or l.has("generated")), "la leccion %s trae titulo, texto y como armarla" % l.id)
	check(ids.size() == lessons.size(), "los ids de las lecciones son unicos")
	for i in lessons.size():
		var l: Dictionary = lessons[i]
		if l.has("generated") or l.has("marker"):
			continue
		var t = Tutorial.build(i)
		var res := Solver.solve(t, t.goal_y, {"max_states": 200000})
		check(res.status == "solved", "la leccion %s se puede ganar" % l.id)
		var modes := {}
		for a in res.path:
			modes[a.mode] = true
		for need in l.get("needs", []):
			check(modes.has(need), "la leccion %s exige el modo %d" % [l.id, need])
		if l.id == "empujar":
			check(Solver.solve(t, t.goal_y, {"max_states": 200000, "no_grab": true}).status != "solved", "sin empujar no se cruza el hueco")
		if l.id == "fila":
			check(Solver.solve(t, t.goal_y, {"max_states": 200000, "no_grab": true}).status != "solved", "sin empujar la fila no se cruza el hueco")
			check(res.path.size() <= 14, "la leccion de la fila es corta (%d pasos)" % res.path.size())
		if l.id == "trampa" or l.id == "pinchos":
			var walk2 = t.clone()
			for _s in 8:
				walk2.try_action(Vector3i(1, 0, 0))
			check(walk2.lost or not walk2.won, "ir en linea recta por el carril marcado no sirve (leccion %s)" % l.id)
			var lane = t.clone()
			var lost_on_lane := false
			for _s in 8:
				lane.try_action(Vector3i(1, 0, 0))
				lost_on_lane = lost_on_lane or lane.lost
			check(lost_on_lane, "ir recto sobre el peligro pierde (leccion %s)" % l.id)
		if l.id == "bomba":
			check(t.kind_at(Vector3i(3, 1, 1)) == TowerLogic.Kind.BOMB and t.positions[t.blocks[Vector3i(3, 1, 1)]].y == t.player.y, "la bomba de la leccion esta a la altura del jugador (asi cuenta)")
			var bomb_id: int = t.blocks[Vector3i(3, 1, 1)]
			var direct = t.clone()
			for k in 3:
				direct.try_action(res.path[k].dir, res.path[k].mode)
			check(t.bomb_timer[bomb_id] == 3 and not direct.bomb_timer.has(bomb_id) and not direct.lost, "la cuenta es 3: justo los movimientos que hacen falta para subirse encima (y se desactiva)")
			# perder un solo movimiento: explota
			var wasted = t.clone()
			wasted.try_action(Vector3i(1, 0, 0))
			wasted.try_action(Vector3i(-1, 0, 0))   # retrocede
			wasted.try_action(Vector3i(1, 0, 0))
			wasted.try_action(Vector3i(1, 0, 0))
			check(wasted.lost and wasted.exploded and wasted.lost_reason.begins_with("Explot"), "retroceder un paso hace que la bomba explote")
			check(wasted.explosion_cell == Vector3i(3, 1, 1), "y se sabe donde explota (para la animacion)")
			var wasted2 = t.clone()
			wasted2.try_action(Vector3i(0, 0, 1))   # chocar con el borde no cuenta como movimiento
			var ok_moves := 0
			for a in res.path:
				if wasted2.try_action(a.dir, a.mode).ok:
					ok_moves += 1
			check(not wasted2.lost and wasted2.won, "ir directo desactiva la bomba y se gana")
		if l.id == "colgarse":
			var walk = t.clone()
			walk.try_action(Vector3i(1, 0, 0))
			walk.try_action(Vector3i(1, 0, 0))
			check(not walk.try_action(Vector3i(1, 0, 0)).ok, "arriba de la torre no se baja caminando")


## Tirar: dos tirones dejan el bloque en la casilla marcada.
func test_pull_lesson() -> void:
	var idx := -1
	var lessons := Tutorial.lessons()
	for i in lessons.size():
		if lessons[i].id == "tirar":
			idx = i
	var t = Tutorial.build(idx)
	var marker: Vector3i = lessons[idx].marker
	check(not t.blocks.has(marker), "al empezar la casilla marcada esta vacia")
	var W := Vector3i(-1, 0, 0)
	check(t.try_action(W, TowerLogic.Mode.GRAB).ok and t.try_action(W, TowerLogic.Mode.GRAB).ok, "se puede tirar dos veces")
	check(t.blocks.has(marker), "el bloque tirado queda en la casilla marcada")
	check(not t.won, "llegar a esa altura no gana por si solo (lo decide el juego)")


func make_main() -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	return main


func test_flow() -> void:
	var main := make_main()
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	await main.start_tutorial(0, true)
	check(main.tutorial_index == 0 and main.training and main.dialogue.is_active() and not main.dialogue.blocking and str(main.dialogue.lines[0]).contains("W A S D"), "arranca la leccion 1 y el tabernero explica")
	check(main.logic.goal_y == 1 and main.logic.player == Vector3i(0, 1, 0), "la leccion 1 es la torre armada a mano")
	check(not main.clarity_counter.visible, "en el tutorial no se muestra la claridad")
	# Ganar la leccion con el camino del solucionador
	var res := Solver.solve(main.logic, main.logic.goal_y, {})
	for a in res.path:
		main.logic.try_action(a.dir, a.mode)
	check(main.logic.won, "el camino del solucionador gana la leccion")
	main.quick_portal = true   # sin la pausa de festejo
	await main._on_anim_done()
	check(main.casino == null and main.tutorial_index == 1 and main.logic != null and not main.logic.won and str(main.dialogue.lines[0]).contains("escalera"), "al ganar la leccion pasa sola a la siguiente (y no va al casino)")
	# Tirar: se completa al dejar el bloque en la casilla
	await main.start_tutorial(3, true)
	var W := Vector3i(-1, 0, 0)
	main.logic.try_action(W, TowerLogic.Mode.GRAB)
	main.logic.try_action(W, TowerLogic.Mode.GRAB)
	await main._on_anim_done()
	check(main.tutorial_index == 4, "la leccion de tirar se completa con el bloque en la casilla marcada y pasa a la siguiente")
	# Reintentar es gratis y recarga la leccion
	main.request_restart()
	check(not main.logic.won and main.run.claridad == 0 and main.run.retries == 0, "reintentar la leccion no cuesta nada")
	# La ultima leccion es una torre generada
	await main.start_tutorial(Tutorial.count() - 1, true)
	check(main.tutorial_index == Tutorial.count() - 1 and main.logic != null and main.logic.goal_y == 5 and main.tower_rows == main.TOWER_ROWS, "la ultima leccion es una torre generada chica")
	check(main.dialogue.is_active() and str(main.dialogue.lines[0]).contains("torres de verdad") and not main.dice.visible, "el tabernero explica la ultima leccion cuando ya cerro la pantalla de los dados (no la tapa mientras se genera)")
	# Despues de la ultima se vuelve al menu
	main.logic.won = true
	await main._on_anim_done()
	check(not main.in_menu and main.casino != null and main.casino.story and main.story_kind == "outro" and main.casino.lay.tier == 1, "al terminar la ultima leccion el tabernero te recibe en el salon de piedra")
	check(main.dialogue.blocking and main.dialogue.lines.size() >= 6 and not main.hud_layer.visible, "y te explica las habilidades, la Luz y lo demas")
	main.dialogue.skip_all()
	check(main.in_menu and main.tutorial_index == -1 and not main.training and main.casino == null and not main.dialogue.is_active(), "al terminar su cierre se vuelve al menu")
	main._cancel_jobs()
	main.queue_free()
	await process_frame
	# En la leccion de colgarse el personaje empieza arriba de una torre mas alta que la meta: toda la torre se dibuja
	main = make_main()
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	await main.start_tutorial(4, true)
	var all_visible := true
	for id in main.block_nodes:
		all_visible = all_visible and main.block_nodes[id].visible
	check(all_visible and main.block_nodes.size() == main.logic.blocks.size(), "en la leccion de colgarse se ven todos los bloques (el personaje no flota)")
	var under: Vector3i = main.logic.player + Vector3i(0, -1, 0)
	check(main.block_nodes[main.logic.blocks[under]].visible, "el bloque bajo los pies del personaje esta visible")
	main._cancel_jobs()
	main.queue_free()
	await process_frame


func key_event(code: int, pressed: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	return e


func test_arrows() -> void:
	var main := make_main()
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	main.start_game()
	while main.generating or main.logic == null:
		await process_frame
	var yaw0: float = main.yaw_target
	var pitch0: float = main.cam_pitch
	var pos0: Vector3i = main.logic.player
	Input.parse_input_event(key_event(KEY_RIGHT, true))
	await process_frame
	main._arrow_camera(0.5)
	Input.parse_input_event(key_event(KEY_RIGHT, false))
	await process_frame
	check(main.yaw_target < yaw0 - 10.0, "la flecha derecha gira la camara")
	var yaw1: float = main.yaw_target
	Input.parse_input_event(key_event(KEY_LEFT, true))
	await process_frame
	main._arrow_camera(0.5)
	Input.parse_input_event(key_event(KEY_LEFT, false))
	await process_frame
	check(main.yaw_target > yaw1 + 10.0, "la izquierda la gira para el otro lado")
	Input.parse_input_event(key_event(KEY_DOWN, true))
	await process_frame
	main._arrow_camera(0.2)
	Input.parse_input_event(key_event(KEY_DOWN, false))
	await process_frame
	check(main.cam_pitch < pitch0 - 5.0, "la flecha de abajo inclina la camara hacia abajo")
	# Las flechas ya no mueven al personaje
	var ev := key_event(KEY_UP, true)
	main._unhandled_input(ev)
	check(main.logic.player == pos0, "las flechas no mueven al personaje")
	main._cancel_jobs()
	main.queue_free()
	await process_frame
