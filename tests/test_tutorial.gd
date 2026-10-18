extends SceneTree
## Pruebas del tutorial: cada lección se puede ganar, las que enseñan algo lo exigen, la ayuda con las teclas (se doran al usarlas) y el flujo dentro del juego.
## Las flechas mueven la cámara (no al personaje).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_tutorial.gd

const Tutorial := preload("res://scripts/tutorial.gd")
const Solver := preload("res://scripts/solver.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const Story := preload("res://scripts/story.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_lessons()
	test_move_lesson()
	test_pull_lesson()
	test_hang_lessons()
	await test_flow()
	await test_arrows()
	await test_key_hint()
	print("tests del tutorial terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func _index_of(id: String) -> int:
	for i in Tutorial.count():
		if Tutorial.lessons()[i].id == id:
			return i
	return -1


func make_main() -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	return main


func test_lessons() -> void:
	var lessons := Tutorial.lessons()
	check(lessons.size() == Tutorial.count() and lessons.size() == 7, "hay 7 lecciones (sólo mecánicas)")
	var order := []
	for l in lessons:
		order.append(l.id)
	check(order == ["moverse", "camara", "empujar", "tirar", "colgarse", "soltarse", "torre"], "el orden de las lecciones (%s)" % str(order))
	var ids := {}
	for l in lessons:
		ids[l.id] = true
		check(l.title != "" and l.has("help") and (l.has("build") or l.has("generated")), "la leccion %s trae titulo, ayuda y como armarla" % l.id)
		check(Story.LESSONS.has(l.id) and not str(Story.LESSONS[l.id]).contains("botón") and not str(Story.LESSONS[l.id]).contains("tecla"), "el tabernero cuenta lore de %s sin hablar de teclas" % l.id)
	check(ids.size() == lessons.size(), "los ids de las lecciones son unicos")
	for i in lessons.size():
		var l: Dictionary = lessons[i]
		if l.has("generated") or l.get("complete", "") == "keys":
			continue
		var t = Tutorial.build(i)
		var res := Solver.solve(t, t.goal_y, {"max_states": 400000})
		check(res.status == "solved", "la leccion %s se puede ganar" % l.id)
		var modes := {}
		for a in res.path:
			modes[a.mode] = true
		for need in l.get("needs", []):
			check(modes.has(need), "la leccion %s exige el modo %d" % [l.id, need])
		if l.id == "empujar":
			check(Solver.solve(t, t.goal_y, {"max_states": 400000, "no_grab": true}).status != "solved", "sin empujar no se llega a la plataforma")
		if l.id == "soltarse":
			var walk = t.clone()
			walk.try_action(Vector3i(1, 0, 0))
			walk.try_action(Vector3i(1, 0, 0))
			check(not walk.try_action(Vector3i(1, 0, 0)).ok, "arriba de la torre no se baja caminando")


## Camina (sólo MOVE) con una búsqueda en anchura: la lista de direcciones del camino más corto a la meta ([] si no se llega caminando).
func _walk_path(t) -> Array:
	var queue: Array = [[t.clone(), []]]
	var seen := {t.player: true}
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var n = item[0].clone()
			if not n.try_action(d).ok or n.lost:
				continue
			var path: Array = item[1] + [d]
			if n.won:
				return path
			if not seen.has(n.player):
				seen[n.player] = true
				queue.append([n, path])
	return []


## Moverse: un sendero en S que obliga a usar las cuatro direcciones.
func test_move_lesson() -> void:
	var t = Tutorial.build(_index_of("moverse"))
	var path := _walk_path(t)
	var dirs := {}
	for d in path:
		dirs[d] = true
	check(not path.is_empty() and dirs.size() == 4, "el sendero de moverse se recorre caminando y usa las cuatro direcciones (%d)" % dirs.size())
	var straight = t.clone()
	for _i in 6:
		straight.try_action(Vector3i(1, 0, 0))
	check(not straight.won, "ir siempre derecho no llega")


## Tirar: la escalera queda a la espalda y el bloque que la hace demasiado alta se saca tirando de él; sin agarrar no se llega y el camino más corto incluye un tirón.
func test_pull_lesson() -> void:
	var t = Tutorial.build(_index_of("tirar"))
	check(t.goal_y < 100, "la lección de tirar tiene meta (el portal)")
	check(Solver.solve(t, t.goal_y, {"max_states": 400000, "no_grab": true}).status != "solved", "sin agarrar no se llega al portal")
	var res := Solver.solve(t, t.goal_y, {"max_states": 400000})
	var sim = t.clone()
	var pulls := 0
	var pushes := 0
	for a in res.path:
		sim.try_action(a.dir, a.mode)
		if sim.last_grab == "pull":
			pulls += 1
		elif sim.last_grab == "push":
			pushes += 1
	check(res.status == "solved" and pulls >= 1 and sim.won, "la solución tira de un bloque (%d tirones, %d empujes)" % [pulls, pushes])
	var walked = t.clone()
	walked.try_action(Vector3i(0, 0, -1))
	check(walked.last_grab == "", "caminar no es ni empujar ni tirar")


## Colgarse: la S de hierro exige colgarse (caminando no se llega); soltarse: la torre alta.
func test_hang_lessons() -> void:
	var t = Tutorial.build(_index_of("colgarse"))
	var res := Solver.solve(t, t.goal_y, {"max_states": 400000})
	check(res.status == "solved", "la S de hierro se puede cruzar")
	var hangs := 0
	for a in res.path:
		if a.mode == TowerLogic.Mode.HANG:
			hangs += 1
	check(hangs > 0, "la S de hierro exige colgarse (%d)" % hangs)
	check(_walk_path(t).is_empty(), "caminando no se cruza la S de hierro")
	for c in t.blocks:
		check(t.kind_at(c) == TowerLogic.Kind.HEAVY and c.y < 2, "los bloques de la S son inamovibles y de 2 de alto")
	# la plataforma de salida es ancha: Espacio + cualquiera de las cuatro direcciones cuelga del borde
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		var edge = t.clone()
		for _i in 3:
			edge.try_action(d)   # camina hasta el borde de la plataforma
		check(edge.try_action(d, TowerLogic.Mode.HANG).ok and edge.hang_dir == -d, "se puede colgar hacia %s" % str(d))
	# colgado: la dirección contraria al bloque ya no suelta (sólo Espacio); el solucionador sigue pudiendo soltarse así
	var h = t.clone()
	h.try_action(Vector3i(1, 0, 0))
	h.try_action(Vector3i(1, 0, 0), TowerLogic.Mode.HANG)
	check(h.hang_dir == Vector3i(-1, 0, 0), "colgado del borde")
	h.release_with_opposite = false
	check(not h.try_action(Vector3i(1, 0, 0), TowerLogic.Mode.HANG).ok and h.hang_dir == Vector3i(-1, 0, 0), "colgado, la dirección contraria al bloque no suelta")
	check(h.release_hang().ok and h.hang_dir == Vector3i.ZERO, "Espacio estando colgado suelta")
	check(h.release_with_opposite == false and h.clone().release_with_opposite == false, "(y la opción se conserva en las copias)")


func test_flow() -> void:
	var main := make_main()
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	await main.start_tutorial(0, true)
	check(main.tutorial_index == 0 and main.training and main.dialogue.is_active() and main.dialogue.blocking and main.dialogue.any_key, "arranca la leccion 1: el tabernero cuenta (cualquier tecla lo cierra)")
	check(not main.key_hint.visible, "mientras el tabernero habla no se ve la ayuda")
	var presses := 0
	while main.dialogue.is_active() and presses < 4:   # (la primera tecla termina de escribir la línea, la siguiente la cierra)
		main.dialogue._unhandled_input(key_event(KEY_X, true))
		presses += 1
	check(not main.dialogue.is_active() and main.key_hint.visible and main.key_hint.has_keys(), "con una tecla el tabernero se va y aparece sólo la ayuda")
	check(main.logic.goal_y == 1 and main.logic.player == Vector3i(0, 1, 0), "la leccion 1 es la torre armada a mano")
	check(not main.clarity_counter.visible, "en el tutorial no se muestra la claridad")
	# Ganar la leccion con el camino del solucionador
	var res := Solver.solve(main.logic, main.logic.goal_y, {})
	for a in res.path:
		main.logic.try_action(a.dir, a.mode)
	check(main.logic.won, "el camino del solucionador gana la leccion")
	main.quick_portal = true   # sin la pausa de festejo
	await main._on_anim_done()
	check(main.casino == null and main.tutorial_index == 1 and main.logic != null and not main.logic.won and main.dialogue.is_active(), "al ganar la leccion pasa sola a la siguiente (y no va al casino)")
	# Reintentar es gratis y recarga la leccion
	main.request_restart()
	check(not main.logic.won and main.run.claridad == 0 and main.run.retries == 0, "reintentar la leccion no cuesta nada")
	# La ultima leccion es una torre generada, con los dados explicados por el tabernero
	await main.start_tutorial(Tutorial.count() - 1, true)
	check(main.tutorial_index == Tutorial.count() - 1 and main.logic != null and main.logic.goal_y == 5 and main.tower_rows == main.TOWER_ROWS, "la ultima leccion es una torre generada chica")
	check(main.dialogue.is_active() and not main.dice.visible, "el tabernero cuenta el lore de la torre cuando ya cerro la pantalla de los dados")
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
	# En la leccion de la S de hierro el personaje empieza arriba y se ven todos los bloques
	main = make_main()
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	await main.start_tutorial(_index_of("soltarse"), true)
	var all_visible := true
	for id in main.block_nodes:
		all_visible = all_visible and main.block_nodes[id].visible
	check(all_visible and main.block_nodes.size() == main.logic.blocks.size(), "en la leccion de soltarse se ven todos los bloques (el personaje no flota)")
	var under: Vector3i = main.logic.player + Vector3i(0, -1, 0)
	check(main.block_nodes[main.logic.blocks[under]].visible, "el bloque bajo los pies del personaje esta visible")
	main._cancel_jobs()
	main.queue_free()
	await process_frame


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


func key_event(code: int, pressed: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	return e




## La ayuda de arriba: una frase con las teclas, grises hasta que se usan bien; no se pasa si faltan.
func test_key_hint() -> void:
	var KeyHint = load("res://scripts/key_hint.gd")
	var h = KeyHint.new()
	root.add_child(h)
	h.size = Vector2(1120, 90)
	var done := [0]
	h.completed.connect(func(): done[0] += 1)
	check(not h.visible, "sin lección, la ayuda no se ve")
	h.show_help("Pulsá {mover_adelante} {mover_izquierda} {mover_atras} {mover_derecha}", "move")
	check(h.visible and h.pressed.is_empty() and h.required_keys().size() == 4, "WASD: cuatro teclas obligatorias, todas grises al principio")
	h.note("mover_adelante", TowerLogic.Mode.GRAB)
	check(h.pressed.is_empty(), "con Shift no cuenta en la lección de moverse")
	h.note("mover_adelante", TowerLogic.Mode.MOVE)
	check(h.pressed.has("mover_adelante") and not h.all_done(), "al usar una tecla se pone dorada")
	for a in ["mover_izquierda", "mover_atras", "mover_derecha"]:
		h.note(a, TowerLogic.Mode.MOVE)
	check(h.all_done() and done[0] == 1, "con las cuatro doradas se completa (una sola vez)")
	h.note("mover_atras", TowerLogic.Mode.MOVE)
	check(done[0] == 1, "no se repite el aviso")
	h.show_help("Mantén {empujar} y pulsa {?mover_adelante} {?mover_izquierda} {?mover_atras} {?mover_derecha}", "push")
	check(h.required_keys() == ["empujar"] and h.pressed.is_empty(), "empujar: sólo Shift es obligatoria (las demás se doran pero no se exigen)")
	h.note("mover_derecha", TowerLogic.Mode.MOVE)
	check(h.pressed.is_empty(), "sin Shift no se doran")
	h.note("mover_derecha", TowerLogic.Mode.GRAB, "pull")
	check(h.pressed.is_empty(), "en la lección de empujar, tirar de un bloque no cuenta")
	h.note("mover_derecha", TowerLogic.Mode.GRAB, "push")
	check(h.pressed.has("empujar") and h.pressed.has("mover_derecha") and h.all_done(), "con Shift se doran Shift y la dirección")
	h.show_help("Mantén {empujar} y pulsa {?mover_adelante} {?mover_izquierda} {?mover_atras} {?mover_derecha}", "pull")
	h.note("mover_atras", TowerLogic.Mode.GRAB, "push")
	check(h.pressed.is_empty(), "en la lección de tirar, empujar no cuenta")
	h.note("mover_atras", TowerLogic.Mode.GRAB, "pull")
	check(h.all_done(), "tirar de un solo bloque alcanza")
	var rects: Dictionary = h.key_rects()
	check(rects.has("empujar") and (rects.empujar as Rect2).end.x < (rects.mover_adelante as Rect2).position.x, "el Shift va a la izquierda de las direcciones, en una sola fila")
	h.show_help("Mantén {colgarse} y pulsa una dirección", "hang")
	h.note("mover_atras", TowerLogic.Mode.HANG)
	check(h.pressed.has("colgarse") and h.all_done(), "con Espacio se dora Espacio")
	h.show_help("Pulsá {camara_arriba} {camara_izquierda} {camara_abajo} {camara_derecha}", "camera")
	h.note("mover_adelante", TowerLogic.Mode.MOVE)
	check(h.pressed.is_empty(), "las teclas de movimiento no cuentan en la lección de la cámara")
	for id in ["camara_arriba", "camara_izquierda", "camara_abajo"]:
		h.note_camera(id)
	check(not h.all_done(), "con una flecha sin probar falta")
	h.note_camera("camara_derecha")
	check(h.all_done(), "con las cuatro flechas se completa")
	h.show_help("Pisar los pinchos pierde", "")
	check(h.visible and not h.has_keys() and h.all_done() == true, "una ayuda de sólo texto se muestra y no exige nada")
	h.queue_free()
	# En el tutorial: primero el tabernero, después la ayuda, y no se pasa sin usar todas las teclas
	var main := make_main()
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	main.start_tutorial(0, true)
	for i in 5:
		await process_frame
	check(not main.key_hint.visible and main.dialogue.is_active(), "la lección de moverse empieza con el tabernero")
	main.dialogue.skip_all()
	check(main.key_hint.visible and main.key_hint.mode == "move", "después aparece la ayuda de moverse")
	check(main.tutorial_locked_for_test(), "con las teclas sin usar no se puede pasar")
	for code in [KEY_W, KEY_A, KEY_S, KEY_D]:
		main._unhandled_input(key_event(code, true))
		main.busy = false
	check(not main.key_hint.pressed.is_empty(), "usar una tecla con la que el personaje se mueve la dora")
	main.start_tutorial(_index_of("camara"), true)
	main.dialogue.skip_all()
	check(main.logic.blocks.size() == 1 and main.logic.goal_y > 100 and main.logic.blocks.has(main.logic.player + Vector3i(0, -1, 0)), "la cámara: el personaje solo sobre un bloque, sin meta")
	for id in ["camara_arriba", "camara_izquierda", "camara_abajo"]:
		main.key_hint.note_camera(id)
		main._check_keys_complete()
	check(not main.logic.won, "con una flecha sin tocar no se completa")
	main.key_hint.note_camera("camara_derecha")
	main.quick_portal = true
	main._check_keys_complete()
	check(main.logic.won or main.tutorial_index == _index_of("camara") + 1, "al tocar las cuatro flechas se completa la lección")
	main.start_tutorial(_index_of("camara"), true)
	main.dialogue.skip_all()
	check(main.key_hint.mode == "camera" and main.key_hint.required_keys() == ["camara_arriba", "camara_izquierda", "camara_abajo", "camara_derecha"], "la lección 2 enseña la cámara con las flechas")
	main.start_tutorial(_index_of("tirar"), true)
	main.dialogue.skip_all()
	check(main.key_hint.mode == "pull" and main.key_hint.required_keys() == ["empujar"], "tirar: alcanza con tirar de un bloque (Shift)")
	main._cancel_jobs()
	main.queue_free()
	await process_frame
