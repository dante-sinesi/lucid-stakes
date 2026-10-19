extends SceneTree
## Pruebas del casino jugable (headless): caminar, chocar con la mesa, portal, paredes y flujo con la torre.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_casino_scene.gd

const RunState := preload("res://scripts/run_state.gd")
const Room := preload("res://scripts/casino_room.gd")
const CasinoScene := preload("res://scripts/casino_scene.gd")

var fails := 0
var left_count := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func make(claridad := 300) -> Array:
	var run := RunState.new()
	run.stage = 8   # el casino de la distribucion clasica (nivel 3 de la sala)
	run.claridad = claridad
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var sc := CasinoScene.new()
	sc.quick = true
	root.add_child(sc)
	sc.setup(run, rng)
	left_count = 0
	sc.left.connect(func(): left_count += 1)
	return [sc, run]


func _init() -> void:
	await process_frame
	test_walking()
	test_table()
	test_portal()
	test_walls_and_screen_dirs()
	await test_roulette_layout()
	await test_flow_with_tower()
	print("tests del casino jugable terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_walking() -> void:
	var sc: Node = make()[0]
	check(sc.cell == sc.lay.entry, "se llega frente a la puerta de llegada")
	check(sc.walls.has("west") and sc.walls.has("north") and sc.cam.current, "la sala tiene sus paredes y la camara del casino esta activa")
	check(sc.step(Vector2i(1, 0)) == "moved" and sc.cell == Vector2i(1, 7), "un paso al este")
	check(sc.step(Vector2i(0, 1)) == "moved" and sc.step(Vector2i(0, 1)) == "blocked" and sc.cell == Vector2i(1, 8), "no se sale de la sala")
	sc.cell = Vector2i(2, 3)
	check(sc.step(Vector2i(0, 1)) == "moved" and sc.cell == Vector2i(2, 4), "se camina por celdas libres")
	sc.queue_free()


func test_table() -> void:
	var made := make()
	var sc: Node = made[0]
	sc.cell = Vector2i(4, 5)  # al sur de la mesa
	sc.facing = Vector2i(1, 0)
	check(sc.interact() == "blocked" and sc.screen == null, "Espacio sin mirar la mesa no hace nada")
	sc.facing = Vector2i(0, -1)
	check(sc.interact() == "roulette" and sc.screen != null and sc.busy, "Espacio mirando la mesa abre la ruleta")
	check(sc.step(Vector2i(1, 0)) == "blocked", "con la ruleta abierta no se camina")
	sc.close_roulette()
	check(sc.screen == null and not sc.busy, "al cerrar la ruleta se vuelve a caminar")
	check(sc.step(Vector2i(0, -1)) == "roulette", "chocar contra la mesa tambien la abre")
	sc.close_roulette()
	# La apuesta usa la claridad del run.
	sc.open_roulette()
	sc.screen.forced_pocket = 1
	sc.screen.select_bet(0)
	sc.screen.toggle_pocket(1)
	check(sc.screen.can_spin(), "con claridad suficiente se puede girar")
	sc.close_roulette()
	sc.cell = Vector2i(1, 2)
	check(sc.step(Vector2i(-1, 0)) == "slots" and sc.screen != null and sc.screen.has_method("toggle_hold"), "chocar contra una tragamonedas abre su pantalla")
	sc.close_roulette()
	sc.cell = Vector2i(7, 3)
	sc.facing = Vector2i(1, 0)
	check(sc.step(Vector2i(1, 0)) == "blackjack" and sc.screen != null and sc.screen.has_method("double_down"), "chocar contra la mesa de cartas abre el blackjack")
	sc.close_roulette()
	# La rosa de los vientos: cada tecla apunta al eje que mueve segun la camara (igual que en la torre)
	check(sc.compass != null and sc.compass.get_parent() == sc.hud_layer, "el casino tiene su rosa de los vientos")
	sc.yaw_target = 45.0
	sc.pivot.rotation_degrees.y = 45.0
	check(sc.compass.dir_source.call(1, 1) == Vector3i(0, 0, -1) and sc.compass.dir_source.call(-1, -1) == Vector3i(0, 0, 1), "con la vista de siempre W apunta al norte y S al sur")
	sc.yaw_target = 135.0
	check(sc.compass.dir_source.call(1, 1) != Vector3i(0, 0, -1), "al girar la camara las teclas cambian de eje en la rosa")
	var view: Vector2 = sc.compass.view_source.call()
	check(is_equal_approx(view.x, sc.pivot.rotation_degrees.y), "la rosa lee el giro real de la camara")
	sc.queue_free()


func test_portal() -> void:
	var sc: Node = make()[0]
	check(sc.cell == sc.lay.entry and left_count == 0, "al llegar se aparece frente a la puerta de llegada")
	# La puerta de llegada es solo estetica: empujarla (hacia el oeste) no hace nada.
	check(sc.step(Vector2i(-1, 0)) == "blocked" and left_count == 0 and sc.cell == sc.lay.entry, "la puerta de llegada no lleva a ningun lado")
	sc.step(Vector2i(1, 0))
	sc.step(Vector2i(-1, 0))
	check(left_count == 0, "volver al lugar de llegada no saca del casino")
	sc.queue_free()
	sc = make()[0]
	sc.cell = sc.lay.exit
	check(sc.step(Vector2i(0, -1)) == "exit" and left_count == 1, "empujar la puerta de salida lleva a la torre siguiente")
	check(sc.step(Vector2i(1, 0)) == "blocked", "ya no se camina despues de irse")
	sc.queue_free()
	sc = make()[0]
	sc.cell = Vector2i(6, 0)
	sc.step(Vector2i(0, -1))
	check(left_count == 0, "contra la pared (fuera de la puerta) no se sale")
	sc.queue_free()


func test_walls_and_screen_dirs() -> void:
	var sc: Node = make()[0]
	check(sc.hidden_walls(45.0).is_empty(), "vista por defecto: las paredes del fondo se ven")
	check(sc.hidden_walls(135.0) == ["north"] and sc.hidden_walls(315.0) == ["west"], "al girar se oculta la pared que tapa")
	check(sc.hidden_walls(225.0).size() == 2, "con la camara al noroeste se ocultan las dos")
	sc.rotate_camera(1)
	sc._process(0.0)
	check(not sc.walls.north[0].visible and sc.walls.west[0].visible, "girar la camara oculta la pared norte")
	sc.rotate_camera(-1)
	sc._process(0.0)
	check(sc.walls.north[0].visible, "volver a girar la muestra")
	sc.yaw_target = 45.0
	check(sc._dir_for_screen(1, 1) == Vector2i(0, -1) and sc._dir_for_screen(-1, -1) == Vector2i(0, 1), "W va hacia el fondo de la pantalla (norte) y S hacia la camara")
	check(sc._dir_for_screen(1, -1) == Vector2i(1, 0) and sc._dir_for_screen(-1, 1) == Vector2i(-1, 0), "D va a la derecha de la pantalla")
	# Cámara libre, como en la torre: arrastrar gira e inclina, la rueda acerca y aleja, Q/E vuelven a la diagonal
	var yaw0: float = sc.yaw_target
	sc.orbit_view(Vector2(100, 0))
	check(sc.yaw_target < yaw0 - 10.0 and is_equal_approx(sc.pivot.rotation_degrees.y, sc.yaw_target), "arrastrar a la derecha gira la camara del casino")
	sc.orbit_view(Vector2(0, 100000))
	check(is_equal_approx(sc.cam_pitch, sc.PITCH_MIN), "la inclinacion tiene tope")
	sc.orbit_view(Vector2(0, -100000))
	check(is_equal_approx(sc.cam_pitch, sc.PITCH_MAX), "y tope para el otro lado")
	var size0: float = sc.cam.size
	sc.zoom_view(0.5)
	check(sc.cam.size < size0, "la rueda acerca")
	for i in 40:
		sc.zoom_view(0.5)
	check(sc.cam.size >= float(sc.lay.cam_size) * 0.4 - 0.001, "el zoom tiene un minimo")
	sc.rotate_camera(1)
	check(is_equal_approx(fposmod(sc.yaw_target - 45.0, 90.0), 0.0) and is_equal_approx(sc.cam_pitch, sc.PITCH), "Q/E vuelven a la diagonal y a la inclinacion normal")
	sc.queue_free()


func test_flow_with_tower() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	main.quick_portal = true
	main.stage_number = 4
	main.logic.claridad = 33
	main.logic.won = true
	await main._on_anim_done()
	check(main.casino != null, "ganar en el portal lleva al casino")
	check(main.run.claridad == 33 and main.run.stage == 4, "la claridad de la torre pasa al run")
	check(not main.hud_layer.visible and main.casino.cam.current, "en el casino se oculta el HUD de la torre y manda la camara del casino")
	main.logic.won = true
	await main._on_anim_done()
	check(main.run.claridad == 33, "la claridad no se suma dos veces")
	main.casino.quick = true
	main.casino.step(Vector2i(-1, 0))
	await process_frame
	check(main.casino != null, "la puerta de llegada no devuelve a la torre")
	main.casino.cell = main.casino.lay.exit
	main.casino.step(Vector2i(0, -1))
	await process_frame
	check(main.casino == null and main.hud_layer.visible and main.stage_number == 5, "el portal del casino vuelve a la torre, una etapa mas")
	while main.generating:
		await process_frame
	check(main.logic != null and not main.logic.won and main.cam.current, "se genera la torre siguiente y vuelve la camara de la torre")
	main.queue_free()


## La ruleta del casino ocupa toda la pantalla (esta bajo una CanvasLayer): rueda grande a la izquierda, apuestas en columna a la derecha y fondo oscuro liso.
func test_roulette_layout() -> void:
	root.size = Vector2i(1280, 720)   # en pruebas sin ventana el viewport es diminuto
	await process_frame
	var made := make()
	var sc: Node = made[0]
	sc.open_roulette()
	await process_frame
	await process_frame
	var screen = sc.screen
	var vp: Vector2 = root.get_visible_rect().size
	check(screen.size.is_equal_approx(vp), "la pantalla de la ruleta ocupa toda la ventana (%s de %s)" % [str(screen.size), str(vp)])
	var wr: Rect2 = screen.wheel.get_global_rect()
	check(wr.size.x >= 560.0 and wr.size.y >= 560.0, "la rueda es grande (%s)" % str(wr.size))
	check(wr.position.x >= 0.0 and wr.end.x <= vp.x and wr.position.y >= 0.0 and wr.end.y <= vp.y, "la rueda entra entera en la pantalla")
	var xs := []
	var ys := []
	for b in screen.bet_buttons:
		xs.append(snappedf(screen.bet_buttons[b].global_position.x, 1.0))
		ys.append(screen.bet_buttons[b].global_position.y)
	var one_column := true
	for x in xs:
		one_column = one_column and x == xs[0]
	for i in range(1, ys.size()):
		one_column = one_column and ys[i] > ys[i - 1]
	check(one_column and xs[0] >= wr.end.x, "las apuestas estan en una columna a la derecha de la rueda")
	var bg = screen.get_child(0)
	check(bg is ColorRect and bg.size.is_equal_approx(vp) and bg.color.a >= 0.85 and bg.color.v < 0.1, "el fondo es un oscurecido liso que cubre toda la pantalla (sin dibujos)")
	check(not screen.spin_button.is_inside_tree() and screen.pad_hints != null and screen.pad_hints.items.size() >= 6, "GIRAR ya no es un botón en pantalla: está en la botonera de abajo (Enter o A)")
	check(not sc.hud_layer.visible, "con la ruleta abierta no se ve la interfaz del casino detras")
	sc.close_roulette()
	check(sc.hud_layer.visible, "al cerrar la ruleta vuelve la interfaz del casino")
	sc.queue_free()
