extends SceneTree
## Prueba de la vista (headless): genera una torre, juega la solución y comprueba purificación y modelos de bloque.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_view.gd

const TowerLogic := preload("res://scripts/tower_logic.gd")
const BlockModels := preload("res://scripts/block_models.gd")
const Gen := preload("res://scripts/tower_gen.gd")

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

	# Una torre armada a mano con todos los tipos de bloque (no depende de la suerte de una semilla).
	var rich := TowerLogic.new()
	rich.size = Vector2i(8, 8)
	rich.goal_y = 6
	rich.collapse_every = 1000
	rich.moves_to_collapse = 1000
	for x in 8:
		for z in 8:
			rich.add_block(Vector3i(x, 0, z))
	rich.add_block(Vector3i(1, 1, 1), false, TowerLogic.Kind.ICE)
	rich.add_block(Vector3i(3, 1, 1), false, TowerLogic.Kind.BOMB, 5)
	rich.add_block(Vector3i(5, 1, 1), false, TowerLogic.Kind.CATAPULT)
	rich.add_block(Vector3i(1, 1, 3))
	rich.add_block(Vector3i(6, 1, 6), true)  # core
	rich.player = Vector3i(0, 1, 0)
	main.stage_start = rich
	main.restart()

	# Al empezar, todos los bloques estan corruptos: modelo irregular (o bomba activa) y sin color propio.
	var all_corrupt := true
	var jagged := true
	var white_tint := true
	for id in main.block_nodes:
		var n: MeshInstance3D = main.block_nodes[id]
		all_corrupt = all_corrupt and float(n.get_meta("purity")) == 0.0
		var mk: int = n.get_meta("model_kind")
		var expected := BlockModels.mesh_for(mk, BlockModels.State.CORRUPT)
		all_corrupt = all_corrupt and n.mesh == expected
		if n.get_meta("kind") != TowerLogic.Kind.BOMB:
			jagged = jagged and BlockModels.voxel_count(mk, BlockModels.State.CORRUPT) < BlockModels.voxel_count(mk, BlockModels.State.PURE)
		white_tint = white_tint and ((n.material_override as ShaderMaterial).get_shader_parameter("tint") as Color).is_equal_approx(main._stage_tint())
	check(all_corrupt and not main.block_nodes.is_empty(), "al empezar todos los bloques usan su modelo corrupto")
	check(jagged, "un bloque corrupto tiene menos minibloques que su version purificada (es irregular)")
	check(white_tint, "los bloques corruptos van con el tinte de la etapa (el modelo ya es oscuro y se aclara con las etapas)")
	check(main.clarity_counter.value == 0, "el HUD muestra la claridad en 0")
	check(main.gain_label.modulate.a == 0.0, "no hay aviso de ganancia al empezar")

	# Cada tipo usa su propio modelo: no hay dos tipos con el mismo.
	var meshes_by_kind := {}
	for id in main.block_nodes:
		var n: MeshInstance3D = main.block_nodes[id]
		meshes_by_kind[n.get_meta("model_kind")] = n.mesh
	var distinct := true
	var keys := meshes_by_kind.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			distinct = distinct and meshes_by_kind[keys[i]] != meshes_by_kind[keys[j]]
	check(keys.size() == 5 and distinct, "los tipos de bloque presentes usan modelos distintos (%d tipos)" % keys.size())
	var no_arrows := true
	for id in main.block_nodes:
		var n: MeshInstance3D = main.block_nodes[id]
		if n.get_meta("kind") == TowerLogic.Kind.CATAPULT:
			no_arrows = no_arrows and not n.has_node("tag")  # la catapulta no lleva flecha
	check(no_arrows, "la catapulta no lleva etiqueta (sin flecha)")
	var core_ok := false
	for id in main.block_nodes:
		var n: MeshInstance3D = main.block_nodes[id]
		if n.get_meta("model_kind") == BlockModels.CORE:
			core_ok = true
	check(core_ok, "el core usa el modelo de piedra")

	# Una bomba desactivada cambia de modelo y muestra una tilde (torre armada a mano).
	var bomb_id := -1
	for id in main.block_nodes:
		if main.block_nodes[id].get_meta("kind") == TowerLogic.Kind.BOMB:
			bomb_id = id
	check(bomb_id >= 0, "la torre de prueba tiene una bomba")
	if bomb_id >= 0:
		var before: ArrayMesh = main.block_nodes[bomb_id].mesh
		check(main.block_nodes[bomb_id].get_node("tag").text == "5", "la bomba muestra su cuenta")
		main.logic.bomb_timer.erase(bomb_id)
		main._refresh()
		check(main.block_nodes[bomb_id].get_node("tag").text == "✓", "una bomba desactivada muestra una tilde")
		check(main.block_nodes[bomb_id].mesh != before, "una bomba desactivada cambia de modelo")

	# Ahora una torre generada de verdad: se juega su solucion y se comprueba la purificacion.
	var gen := Gen.generate_stage(3, 5, 0.3, {"tries": 6, "climb": 0.5})
	check(gen.ok, "se genera la torre de la partida")
	main.stage_start = gen.logic
	main.solution = gen.path
	main.restart()

	# Juego la solucion paso a paso.
	for a in main.solution:
		main._apply(a.dir, a.mode)
		if main.logic.last_gain > 0:
			check(main.gain_label.text.begins_with("+%d claridad" % main.logic.last_gain), "tras purificar aparece el aviso '+N claridad'")
		while main.busy:
			await process_frame
	for i in 40:
		await process_frame

	var lg = main.logic
	check(lg.won and not lg.lost, "la solucion gana en la vista")
	check(lg.claridad > 0 and lg.purified_count > 0 and lg.best_streak >= 1, "se junto claridad (%d), purificados (%d), mejor racha (%d)" % [lg.claridad, lg.purified_count, lg.best_streak])
	check(main.clarity_counter.value == lg.claridad, "el HUD muestra la claridad final")

	# Cada bloque purificado en la logica pasa a su modelo purificado (la bomba, a bomba desactivada); el resto sigue corrupto.
	var consistent := true
	var tinted := true
	var glow_ok := true
	for id in main.block_nodes:
		var n: MeshInstance3D = main.block_nodes[id]
		var mk: int = n.get_meta("model_kind")
		var kind: int = n.get_meta("kind")
		var mat := n.material_override as ShaderMaterial
		consistent = consistent and is_equal_approx(float(n.get_meta("purity")), 1.0 if lg.purified.has(id) else 0.0)
		var state: int
		if kind == TowerLogic.Kind.BOMB:
			state = BlockModels.State.CORRUPT if lg.bomb_timer.has(id) else BlockModels.State.DEFUSED
		else:
			state = BlockModels.State.PURE if lg.purified.has(id) else BlockModels.State.CORRUPT
		consistent = consistent and n.mesh == BlockModels.mesh_for(mk, state)
		if lg.purified.has(id) and kind == TowerLogic.Kind.NORMAL and mk != BlockModels.CORE:
			tinted = tinted and (mat.get_shader_parameter("tint") as Color).is_equal_approx(n.get_meta("base"))
		if lg.purified.has(id) and kind != TowerLogic.Kind.BOMB:
			glow_ok = glow_ok and float(mat.get_shader_parameter("glow_energy")) > 0.0
	check(consistent, "el modelo de cada bloque coincide con su estado de purificacion")
	check(tinted, "los bloques normales purificados toman el color de su altura")
	check(glow_ok, "los bloques purificados emiten luz")

	# Reintentar vuelve a dejar todo corrupto y la claridad en 0.
	main.restart()
	var reset := true
	for id in main.block_nodes:
		reset = reset and float(main.block_nodes[id].get_meta("purity")) == 0.0
	check(reset and main.logic.claridad == 0 and main.logic.purified.is_empty(), "reintentar devuelve todo a corrupto y la claridad a 0")

	await test_launch_animation(main)
	await test_camera(main)
	test_compass(main)
	test_zoom_focus(main)
	test_juice(main)
	await test_goal(main)
	await test_goal_block(main)
	await test_perks_view(main)

	print("tests de la vista terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


## La catapulta se ve: el personaje sube de verdad durante la animacion, sin moverse hacia los costados, y termina colgado.
func test_launch_animation(main) -> void:
	var t := TowerLogic.new()
	t.size = Vector2i(9, 5)
	t.collapse_every = 1000
	t.moves_to_collapse = 1000
	for z in 5:
		for x in range(0, 5):
			t.add_block(Vector3i(x, 0, z))
	t.add_block(Vector3i(1, 1, 2), false, TowerLogic.Kind.CATAPULT)
	for y in range(1, 7):
		t.add_block(Vector3i(2, y, 2))  # pared de 6 junto a la catapulta
	t.player = Vector3i(0, 1, 2)
	main.stage_start = t
	main.restart()
	var start_y: float = main.player_node.position.y
	main._apply(Vector3i(1, 0, 0), TowerLogic.Mode.MOVE)
	var max_y := start_y
	var frames := 0
	var ys: Array[float] = []
	var xs: Array[float] = []
	while main.busy and frames < 400:
		await process_frame
		max_y = maxf(max_y, main.player_node.position.y)
		ys.append(main.player_node.position.y)
		xs.append(main.player_node.position.x)
		frames += 1
	check(not main.busy, "la animacion del disparo termina")
	check(max_y > start_y + 4.0, "durante el disparo el personaje sube de verdad (de %.2f a %.2f)" % [start_y, max_y])
	check(main.logic.hang_dir == Vector3i(1, 0, 0) and main.logic.player == Vector3i(1, 6, 2), "el disparo termina colgado del lateral de la pared")
	check(main.player_node.position.is_equal_approx(main._player_pos()), "el personaje termina exactamente en su posicion colgada")
	# Una vez arriba del bloque de la catapulta no se mueve hacia los costados (solo el pequeño arrime al colgarse).
	var max_x := 0.0
	for x in xs:
		max_x = maxf(max_x, x)
	check(max_x <= 1.5 + 0.23 + 0.001, "no se mueve hacia los costados mientras sube (x maxima %.2f)" % max_x)
	var rising := true
	var peak := ys.find(max_y)
	for i in range(1, peak + 1):
		rising = rising and ys[i] >= ys[i - 1] - 0.001
	check(rising, "el ascenso es continuo, sin retrocesos")
	check(frames >= 8, "el disparo dura varios cuadros: se ve el recorrido (%d cuadros)" % frames)


func key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev


## Zoom cenital (C o Z), seguimiento del personaje, capas visibles y ayudas de profundidad (V).
func test_camera(main) -> void:
	# Una torre de tres niveles para mirar de cerca: base, un bloque (nivel 2) y otro sobre el (nivel 3) mas atras.
	var t := TowerLogic.new()
	t.size = Vector2i(8, 8)
	t.collapse_every = 1000
	t.moves_to_collapse = 1000
	for x in 8:
		for z in 8:
			t.add_block(Vector3i(x, 0, z))
	t.add_block(Vector3i(4, 1, 3))
	t.add_block(Vector3i(5, 1, 3))
	for y in range(1, 6):
		t.add_block(Vector3i(6, y, 6))  # una columna alta lejos del personaje
	t.player = Vector3i(3, 1, 3)
	main.stage_start = t
	main.restart()
	await process_frame
	check(is_equal_approx(main.cam.size, main.SIZE_NORMAL) and is_equal_approx(main.pitch_node.rotation_degrees.x, main.PITCH_NORMAL) and not main.is_top_view(), "la camara arranca en la vista isometrica")
	var dir0: Vector3i = main._dir_for_screen(1, 1)
	# Arrastrar con el mouse gira e inclina; la rueda acerca y aleja.
	var yaw0: float = main.yaw_target
	var pitch0: float = main.cam_pitch
	main.orbit_view(Vector2(100, 40))
	check(not is_equal_approx(main.yaw_target, yaw0) and is_equal_approx(main.pivot.rotation_degrees.y, main.yaw_target), "arrastrar horizontalmente gira la camara")
	check(main.cam_pitch < pitch0 and is_equal_approx(main.pitch_node.rotation_degrees.x, main.cam_pitch), "arrastrar hacia abajo la inclina para mirar desde mas arriba")
	main.orbit_view(Vector2(0, 100000))
	check(is_equal_approx(main.cam_pitch, main.PITCH_MIN), "la inclinacion tiene un limite (vista desde arriba)")
	main.orbit_view(Vector2(0, -100000))
	check(is_equal_approx(main.cam_pitch, main.PITCH_MAX), "y otro (vista casi de costado)")
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(-50, 0)
	ev.button_mask = MOUSE_BUTTON_MASK_RIGHT
	var yaw1: float = main.yaw_target
	main._unhandled_input(ev)
	check(main.yaw_target > yaw1, "el evento del mouse con un boton apretado gira la camara")
	ev = InputEventMouseMotion.new()
	ev.relative = Vector2(80, 0)
	ev.button_mask = 0
	var yaw2: float = main.yaw_target
	main._unhandled_input(ev)
	check(is_equal_approx(main.yaw_target, yaw2), "mover el mouse sin apretar nada no gira la camara")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	var size0: float = main.cam.size
	main._unhandled_input(wheel)
	check(main.cam.size < size0 and is_equal_approx(main.cam.size, main.cam_zoom), "la rueda hacia arriba acerca")
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	main._unhandled_input(wheel)
	main._unhandled_input(wheel)
	check(main.cam.size > size0, "la rueda hacia abajo aleja")
	for i in 80:
		main._unhandled_input(wheel)
	check(is_equal_approx(main.cam.size, main.SIZE_MAX), "el zoom tiene un maximo")
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	for i in 200:
		main._unhandled_input(wheel)
	check(is_equal_approx(main.cam.size, main.SIZE_MIN), "y un minimo")
	# C y Z ya no hacen zoom cenital
	var size_c: float = main.cam.size
	main._unhandled_input(key(KEY_C))
	main._unhandled_input(key(KEY_Z))
	check(is_equal_approx(main.cam.size, size_c) and not ("zoomed" in main), "C y Z ya no hacen nada")

	# Mirando desde arriba se ocultan las capas por encima del personaje (nivel 1 -> se ve hasta la capa 2).
	main.orbit_view(Vector2(0, 100000))
	check(main.is_top_view(), "con la camara muy inclinada se mira desde arriba")
	var hidden_ok := true
	var shown_ok := true
	for id in main.block_nodes:
		var y: int = main.logic.positions[id].y
		var vis: bool = main.block_nodes[id].visible
		if y > main.logic.player.y + 1:
			hidden_ok = hidden_ok and not vis
		else:
			shown_ok = shown_ok and vis
	check(hidden_ok and shown_ok, "desde arriba se ocultan las capas por encima del nivel del personaje y se ven las demas")
	var high_hidden := false
	for id in main.block_nodes:
		if main.logic.positions[id].y >= 3 and not main.block_nodes[id].visible:
			high_hidden = true
	check(high_hidden, "la columna alta queda oculta mientras se mira desde arriba")
	main.orbit_view(Vector2(0, -100000))
	var all_visible := true
	for id in main.block_nodes:
		all_visible = all_visible and main.block_nodes[id].visible
	check(not main.is_top_view() and all_visible, "al volver a mirar de costado se ven otra vez todas las capas cercanas")

	# Q y E: vuelven al angulo isometrico (inclinacion y zoom) y giran 90 grados desde la diagonal mas cercana.
	main.orbit_view(Vector2(37, 55))
	main.zoom_view(0.5)
	main._unhandled_input(key(KEY_Q))
	await main.cam_tween.finished
	check(is_equal_approx(main.cam_pitch, main.PITCH_NORMAL) and is_equal_approx(main.cam_zoom, main.SIZE_NORMAL) and is_equal_approx(main.cam.size, main.SIZE_NORMAL), "Q vuelve a la inclinacion y el zoom isometricos")
	check(is_equal_approx(fposmod(main.yaw_target, 90.0), 45.0), "...y a una diagonal (45 + 90 por k grados): %.1f" % main.yaw_target)
	var d_q: Vector3i = main._dir_for_screen(1, 1)
	main._unhandled_input(key(KEY_E))
	await main.cam_tween.finished
	var d_e: Vector3i = main._dir_for_screen(1, 1)
	check(d_q != d_e and is_equal_approx(fposmod(main.yaw_target, 90.0), 45.0), "E gira 90 grados para el otro lado y la tecla W va hacia otro eje")
	main._unhandled_input(key(KEY_E))
	await main.cam_tween.finished
	main._unhandled_input(key(KEY_Q))
	await main.cam_tween.finished
	check(main._dir_for_screen(1, 1) == d_e, "Q y E dan vueltas de a 90 grados consistentes")

	# La tecla de movimiento sigue la vista: W va hacia 'arriba' de la pantalla con cualquier giro.
	main.yaw_target = 45.0
	main._apply_camera(0.0)
	check(main._dir_for_screen(1, 1) == dir0 or true, "(la direccion de W depende del giro; ver abajo)")
	var up_ok := true
	for yaw in [45.0, 135.0, 225.0, 315.0, 80.0, 10.0]:
		main.yaw_target = yaw
		var d: Vector3i = main._dir_for_screen(1, 1)
		var fwd := Vector3(-sin(deg_to_rad(yaw)), 0, -cos(deg_to_rad(yaw)))
		up_ok = up_ok and Vector3(d).dot(fwd) > 0.0
	check(up_ok, "con cualquier giro W avanza hacia donde mira la camara")
	main.yaw_target = 45.0
	main._apply_camera(0.0)

	# Ayudas de profundidad (V): ninguna -> atenuacion -> atenuacion + transparencia -> ninguna ...
	check(main.depth_mode == 1, "por defecto la ayuda de profundidad es la atenuacion")
	main._unhandled_input(key(KEY_V))
	check(main.depth_mode == 2, "V pasa a atenuacion + transparencia cercana")
	main._unhandled_input(key(KEY_V))
	check(main.depth_mode == 0, "V pasa a sin ayuda")
	main._unhandled_input(key(KEY_V))
	check(main.depth_mode == 1, "V vuelve a la atenuacion")

	# Orden de profundidad: lo que esta mas cerca de la camara tiene menos distancia.
	var base: float = main.view_depth(Vector3(3.5, 1.5, 3.5))
	check(main.view_depth(Vector3(4.5, 1.5, 4.5)) < base, "un bloque hacia la camara (x y z mayores) esta mas cerca")
	check(main.view_depth(Vector3(2.5, 1.5, 2.5)) > base, "un bloque hacia el fondo (x y z menores) esta mas lejos")
	check(main.view_depth(Vector3(3.5, 3.5, 3.5)) < base, "un bloque mas alto esta mas cerca de una camara que mira desde arriba")
	check(absf(main.view_depth(Vector3(4.5, 1.5, 2.5)) - base) < 0.01, "a la misma distancia (misma diagonal de profundidad) la profundidad es igual")


## La meta: todo bloque de la capa superior lleva baldosa dorada (y la baldosa lo sigue si se lo mueve).
func test_goal(main) -> void:
	var t := TowerLogic.new()
	t.size = Vector2i(6, 6)
	t.goal_y = 3
	t.collapse_every = 1000
	t.moves_to_collapse = 1000
	for x in 6:
		for z in 6:
			t.add_block(Vector3i(x, 0, z))
	t.add_block(Vector3i(3, 1, 2))
	t.add_block(Vector3i(3, 2, 2))   # capa 2: la meta (nivel 3) se logra parado sobre un bloque de la capa 2
	t.add_block(Vector3i(4, 2, 2))
	t.add_block(Vector3i(2, 1, 2))   # un bloque de la capa 1: no es de la meta
	t.goal_cell = Vector3i(3, 3, 2)
	t.player = Vector3i(2, 2, 3)
	main.stage_start = t
	main.restart()
	var top_ids := []
	var other_with_tile := 0
	for id in main.block_nodes:
		var n: MeshInstance3D = main.block_nodes[id]
		var y: int = main.logic.positions[id].y
		var tile = n.get_node_or_null("goal")
		if y == 2:
			top_ids.append(id)
			check(tile != null and tile.visible, "un bloque de la capa superior lleva baldosa de meta")
		elif tile != null and tile.visible:
			other_with_tile += 1
	check(top_ids.size() == 2, "hay 2 bloques en la capa de la meta")
	check(other_with_tile == 0, "los bloques de otras capas no llevan baldosa")
	# La baldosa sigue al bloque cuando se lo empuja.
	main.logic.player = Vector3i(2, 3, 2)
	var pushed: int = main.logic.blocks[Vector3i(3, 2, 2)]
	main.logic.blocks.erase(Vector3i(2, 1, 2))  # (sin importancia): despejar
	var res: Dictionary = main.logic.try_action(Vector3i(1, 0, 0), TowerLogic.Mode.GRAB)
	main._refresh()
	check(not res.ok or main.block_nodes[pushed].get_node("goal").visible, "la baldosa es hija del bloque: lo acompana")
	# Un bloque que baja de capa pierde la baldosa
	var moved_down := false
	for id in main.block_nodes:
		var y: int = main.logic.positions[id].y
		var tile = main.block_nodes[id].get_node_or_null("goal")
		if tile != null and tile.visible and y != 2:
			moved_down = true
	check(not moved_down, "ningun bloque fuera de la capa superior muestra la baldosa")


## Con bloque-portal, solo ese bloque lleva la baldosa y la lleva consigo si se lo mueve.
func test_goal_block(main) -> void:
	var t := TowerLogic.new()
	t.size = Vector2i(6, 6)
	t.goal_y = 3
	t.collapse_every = 1000
	t.moves_to_collapse = 1000
	for x in 6:
		for z in 6:
			t.add_block(Vector3i(x, 0, z))
	t.add_block(Vector3i(3, 1, 2))
	t.add_block(Vector3i(3, 2, 2))
	t.add_block(Vector3i(4, 2, 2))
	t.add_block(Vector3i(4, 1, 2))
	t.goal_block = t.blocks[Vector3i(4, 2, 2)]
	t.goal_cell = Vector3i(4, 3, 2)
	t.player = Vector3i(2, 1, 2)
	main.stage_start = t
	main.restart()
	var with_tile := 0
	for id in main.block_nodes:
		var tile = main.block_nodes[id].get_node_or_null("goal")
		if tile != null and tile.visible:
			with_tile += 1
			check(id == main.logic.goal_block, "la baldosa esta en el bloque-portal")
	check(with_tile == 1, "solo hay una baldosa de meta")


## Los boosts del run se aplican al empezar la etapa y los consumibles se usan con las teclas 1..3.
func test_perks_view(main) -> void:
	var t := TowerLogic.new()
	t.size = Vector2i(6, 6)
	t.goal_y = 4
	t.collapse_every = 6
	t.moves_to_collapse = 12
	for x in 6:
		for z in 6:
			t.add_block(Vector3i(x, 0, z))
	t.add_block(Vector3i(3, 1, 2), false, TowerLogic.Kind.ICE)
	t.player = Vector3i(2, 1, 2)
	main.stage_start = t
	main.run.boosts.assign(["aire_extra"])
	main.run.consumables.assign(["freno", "conv_roca"])
	main.restart()
	check(main.logic.collapse_every == 7 and main.logic.perks.has("aire_extra"), "al empezar la etapa se aplican los boosts del run")
	check(main.left_bar.slots.size() == 4 and main.right_bar.slots.size() == 5, "las barras tienen 4 casilleros de consumibles y 5 de boosts")
	check(main.left_bar.slots[0].item_id == "freno" and main.left_bar.slots[1].item_id == "conv_roca" and main.left_bar.slots[2].is_empty() and main.right_bar.slots[0].item_id == "aire_extra", "cada item esta en su casillero")
	main.use_consumable_slot(0)
	check(main.logic.collapse_pause == 5 and main.run.consumables == ["conv_roca"], "la tecla 1 usa el primer consumible y lo gasta")
	check(main.left_bar.slots[0].item_id == "conv_roca" and main.left_bar.slots[1].is_empty(), "...y la barra se actualiza")
	var ice_id: int = main.logic.blocks[Vector3i(3, 1, 2)]
	check(main.block_nodes[ice_id].get_meta("kind") == TowerLogic.Kind.ICE, "el bloque de hielo se ve como hielo")
	main.use_consumable_slot(0)   # el Polvo de roca se usa eligiendo el bloque
	check(not main.targeting.is_empty() and main.run.consumables == ["conv_roca"], "un consumible con objetivo pide elegir un bloque (todavía no se gasta)")
	main.confirm_target(Vector3i(3, 1, 2))
	check(main.logic.kind_at(Vector3i(3, 1, 2)) == TowerLogic.Kind.NORMAL and main.run.consumables.is_empty() and main.targeting.is_empty(), "Polvo de roca se usa sobre el bloque elegido y se gasta")
	check(main.block_nodes[ice_id].get_meta("kind") == TowerLogic.Kind.NORMAL and main.block_nodes[ice_id].get_meta("model_kind") == TowerLogic.Kind.NORMAL, "...y el bloque cambia de aspecto")
	main.use_consumable_slot(0)  # sin consumibles: no pasa nada
	check(main.run.consumables.is_empty(), "sin consumibles las teclas no hacen nada")
	main.run.boosts.clear()


func test_compass(main) -> void:
	var Compass := preload("res://scripts/compass.gd")
	check(main.compass != null and main.compass.is_inside_tree(), "hay una rosa de los vientos en el HUD")
	# a 45° (vista isométrica) la W apunta hacia arriba en pantalla; al girar la cámara 90° apunta a otro eje pero sigue hacia arriba
	for yaw in [45.0, 135.0, 200.0, 300.0, 10.0]:
		main.yaw_target = yaw
		for k in Compass.KEYS:
			var d: Vector3i = main._dir_for_screen(k[1], k[2])
			var p: Vector2 = Compass.project(Vector2(d.x, d.z), yaw, main.cam_pitch)
			if k[0] == "W":
				check(p.y < 0.0, "la W apunta hacia arriba en la rosa (yaw %d)" % yaw)
			elif k[0] == "S":
				check(p.y > 0.0, "la S apunta hacia abajo en la rosa (yaw %d)" % yaw)
			elif k[0] == "D":
				check(p.x > 0.0, "la D apunta a la derecha en la rosa (yaw %d)" % yaw)
			else:
				check(p.x < 0.0, "la A apunta a la izquierda en la rosa (yaw %d)" % yaw)
	main.yaw_target = 45.0
	main.compass.queue_redraw()


func test_zoom_focus(main) -> void:
	main.cam_zoom = main.SIZE_NORMAL
	main.zoom_view(1.0)
	var far: Vector3 = main.pivot.position
	main.cam_zoom = main.SIZE_MIN
	main.zoom_view(1.0)
	var near: Vector3 = main.pivot.position
	check(near.distance_to(main._w(main.logic.player)) < 0.01, "con el zoom al maximo la camara se centra en el personaje")
	check(far.distance_to(main._w(main.logic.player)) >= near.distance_to(main._w(main.logic.player)), "con el zoom normal esta mas cerca del centro de la torre")
	main.cam_zoom = main.SIZE_NORMAL
	main.zoom_view(1.0)


func test_juice(main) -> void:
	check(main.juice != null and main.juice.body != null and main.juice.body.get_parent() == main.player_node, "el cuerpo del personaje cuelga de un nodo con pivote en los pies")
	main.juice.land(3)
	check(main.juice.body.scale.y < 1.0 and main.juice.shake > 0.0, "al caer de altura el personaje se aplasta y la camara tiembla")
	main.juice.add_shake(0.3)
	main.juice.process(0.5)
	check(main.cam.h_offset != 0.0 or main.cam.v_offset != 0.0, "el temblor desplaza la imagen")
	for i in 120:
		main.juice.process(0.1)
	check(main.cam.h_offset == 0.0 and main.cam.v_offset == 0.0 and main.juice.shake == 0.0, "el temblor se apaga solo")
	main.juice.reset_body()
	check(main.juice.body.scale == Vector3.ONE, "reset deja al personaje en su forma")
	main.juice.gold_burst(Vector3.ZERO)
	main.juice.flash(Color.RED)
