extends SceneTree
## Pruebas del modo dev: consola (F1), goto_end, set_claridad y give; y que no exista en una compilacion release.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_dev.gd

const DevCommands := preload("res://scripts/dev_commands.gd")
const Profile := preload("res://scripts/profile.gd")
const Items := preload("res://scripts/items.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	await test_commands()
	await test_goto_end()
	await test_goto_casino()
	await test_tower()
	await test_idea()
	await test_hud()
	await test_set_luz()
	await test_console()
	await test_release()
	print("tests del modo dev terminados, fallos: ", fails)
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


func test_commands() -> void:
	var main := make_main()
	await wait_tower(main)
	check(DevCommands.available() == OS.is_debug_build(), "el modo dev esta disponible en compilaciones de desarrollo")
	check(DevCommands.execute("help", main).contains("goto_end") and DevCommands.execute("help", main).contains("set_claridad"), "help lista los comandos")
	check(DevCommands.execute("", main) == "" and DevCommands.execute("  ", main) == "", "una linea vacia no hace nada")
	check(DevCommands.execute("cualquier_cosa", main).contains("desconocido"), "un comando desconocido avisa")
	check(DevCommands.execute("set_claridad", main).contains("Uso") and DevCommands.execute("set_claridad abc", main).contains("Uso"), "set_claridad sin numero (o con letras) muestra el uso")
	main.logic.claridad = 30
	main.run.claridad = 0
	check(DevCommands.execute("set_claridad 1000", main).contains("1000") and main.run.claridad == 970 and main.clarity_counter.value == 1000, "set_claridad 1000: el HUD muestra 1000 en total")
	check(DevCommands.execute("set_claridad 10", main).contains("10") and main.run.claridad == 0 and main.logic.claridad == 10 and main.clarity_counter.value == 10, "se puede restar: set_claridad 10 baja la claridad")
	DevCommands.execute("set_claridad -50", main)
	check(main.clarity_counter.value == 0 and main.run.claridad == 0, "la claridad no baja de 0")
	check(DevCommands.execute("give freno", main).contains("Freno") and main.run.consumables == ["freno"] and main.left_bar.slots[0].item_id == "freno", "give freno: el consumible aparece en la barra")
	check(DevCommands.execute("give mente_abierta", main).contains("Mente abierta") and main.run.boost_capacity() == 7, "give mente_abierta suma casilleros de boosts")
	check(DevCommands.execute("give nada", main).contains("desconocido") and DevCommands.execute("give bolsa_de_luz", main).contains("desconocido") and DevCommands.execute("give", main).contains("Uso"), "give con id raro, con una bolsa de claridad o sin id avisa")
	for i in 6:
		DevCommands.execute("give freno", main)
	check(DevCommands.execute("give freno", main).contains("No hay lugar"), "con la barra llena give avisa que no hay lugar")
	check(DevCommands.execute("items", main).contains("segundo_aliento") and DevCommands.execute("items", main).contains("freno"), "items lista los ids")
	main.queue_free()
	await process_frame


func test_goto_end() -> void:
	var main := make_main()
	await wait_tower(main)
	main.logic.claridad = 40
	main.run.claridad = 100
	check(not main.logic.won and main.casino == null, "al empezar se esta en la torre")
	var msg := DevCommands.execute("goto_end", main)
	check(msg.contains("portal") and main.logic.won, "goto_end te lleva al portal y se gana la torre")
	check(main.casino != null and main.run.claridad == 140, "...y entras al casino con la claridad de la torre sumada (100 + 40)")
	check(main.logic.player.y >= main.logic.goal_y, "el jugador quedo a la altura de la meta")
	check(DevCommands.execute("goto_end", main).contains("casino"), "en el casino goto_end avisa que ya estas ahi")
	check(DevCommands.execute("set_claridad 777", main).contains("777") and main.run.claridad == 777 and main.casino.clarity_counter.value == 777, "en el casino set_claridad cambia la claridad y el contador")
	main.casino.open_roulette()
	DevCommands.execute("set_claridad 900", main)
	check(main.casino.screen.claridad_counter.value == 900, "...tambien el de la ruleta abierta")
	main.casino.close_roulette()
	main.open_main_menu()
	check(DevCommands.execute("goto_end", main).contains("No hay una torre"), "en el menu no hay torre a la que ir")
	main.queue_free()
	await process_frame


func test_console() -> void:
	var main := make_main()
	await wait_tower(main)
	check(main.dev_console != null and not main.console_open, "la consola existe y arranca cerrada")
	var f1 := InputEventKey.new()
	f1.keycode = KEY_F1
	f1.pressed = true
	main._unhandled_input(f1)
	check(main.console_open and main.dev_console.is_open(), "F1 abre la consola")
	var moves_before: int = main.logic.moves_made
	var d := InputEventKey.new()
	d.keycode = KEY_D
	d.pressed = true
	main._unhandled_input(d)
	await process_frame
	check(main.logic.moves_made == moves_before and not main.busy, "con la consola abierta las teclas de juego no mueven al personaje")
	main.dev_console._on_submit("set_claridad 500")
	check(main.clarity_counter.value == 500 and main.dev_console.output.get_parsed_text().contains("Claridad = 500") and main.dev_console.history == ["set_claridad 500"], "un comando escrito se ejecuta, muestra su respuesta y queda en el historial")
	main.dev_console._on_submit("help")
	check(main.dev_console.output.get_parsed_text().contains("goto_end"), "help se muestra en la consola")
	main._unhandled_input(f1)
	check(not main.console_open and not main.dev_console.is_open(), "F1 de nuevo la cierra")
	main.queue_free()
	await process_frame


## En una compilacion release (la de Steam) no hay consola ni comandos.
func test_release() -> void:
	DevCommands.disabled_for_tests = true
	var main := make_main()
	await wait_tower(main)
	check(not DevCommands.available() and main.dev_console == null, "sin modo dev no se crea la consola")
	var f1 := InputEventKey.new()
	f1.keycode = KEY_F1
	f1.pressed = true
	main._unhandled_input(f1)
	check(not main.console_open, "F1 no hace nada")
	var f2 := InputEventKey.new()
	f2.keycode = KEY_F2
	f2.pressed = true
	main._unhandled_input(f2)
	check(not main.debug_hud and not main.hud.visible, "F2 no muestra los textos de depuracion en una compilacion release")
	check(DevCommands.execute("set_claridad 99999", main).contains("no está disponible") and main.run.claridad == 0, "los comandos no hacen nada")
	check(DevCommands.execute("goto_end", main).contains("no está disponible") and not main.logic.won, "ni goto_end")
	check(DevCommands.execute("goto_casino 20", main).contains("no está disponible") and main.casino == null, "ni goto_casino")
	check(DevCommands.execute("set_luz 500", main).contains("no está disponible") and Profile.luz() != 500, "ni set_luz")
	main.queue_free()
	await process_frame
	DevCommands.disabled_for_tests = false


## El comando tower: una torre de la etapa y el escenario que se pida, desde el menú principal, con semilla opcional.
func test_tower() -> void:
	var main := make_main()
	await wait_tower(main)
	main.open_main_menu()
	check(DevCommands.execute("tower", main).contains("Uso") and DevCommands.execute("tower 0", main).contains("Uso") and DevCommands.execute("tower 16", main).contains("Uso") and DevCommands.execute("tower 3 glaciar x", main).contains("semilla"), "sin etapa, con una etapa inválida o una semilla rara explica cómo se usa")
	check(DevCommands.execute("tower 3 nadie", main).contains("desconocido") and main.in_menu, "un escenario que no existe se avisa y no cambia nada")
	check(DevCommands.execute("help", main).contains("tower"), "help lista tower")
	var msg := DevCommands.execute("tower 4 glaciar 4242", main)
	check(msg.contains("etapa 4") and msg.contains("glaciar") and msg.contains("4242") and not main.in_menu and main.run.scenario_id == "glaciar" and main.stage_number == 4 and main.run.stage == 4, "desde el menú principal arranca una partida en esa etapa y escenario")
	check(Profile.luz() == 0 or Profile.luz() == int(Profile.luz()), "no se paga la entrada")
	while main.generating:
		await process_frame
	check((main.seed_value - 4242) % 100003 == 0 and main.logic != null and main.hud_layer.visible, "con la semilla pedida y la torre generada")
	var blocks_a: Dictionary = main.stage_start.blocks.duplicate()
	DevCommands.execute("tower 4 glaciar 4242", main)
	while main.generating:
		await process_frame
	check(main.stage_start.blocks == blocks_a, "la misma semilla da la misma torre")
	check(DevCommands.execute("torre 2", main).contains("pesadilla") and main.run.scenario_id == "pesadilla", "sin escenario: La Pesadilla (también desde el juego)")
	main._cancel_jobs()
	main.queue_free()
	await process_frame


## El comando idea: un tramo armado por una idea de las torres, desde el menú principal.
func test_idea() -> void:
	var main := make_main()
	await wait_tower(main)
	main.open_main_menu()
	check(DevCommands.execute("idea", main).contains("Uso") and DevCommands.execute("idea nada", main).contains("No se pudo") and DevCommands.execute("idea pared_pinchos x", main).contains("semilla"), "sin nombre, con una idea que no existe o con una semilla rara explica qué pasa")
	var msg := DevCommands.execute("idea pared_pinchos 21", main)
	check(msg.contains("Pared de pinchos") and msg.contains("semilla 21") and msg.contains("capa 1") and not main.in_menu, "arranca una partida con el esquema de la instancia")
	while main.generating:
		await process_frame
	check(main.logic != null and main.logic.goal_y == 5 and main.solution.size() >= 7 and main.custom_tower.is_empty(), "la partida usa el tramo armado (4 pisos) y no el generador")
	check(not main.dice.visible and main.logic.collapse_every >= 1000000, "sin dados al empezar y sin caída de la fila de abajo")
	main._cancel_jobs()
	main.queue_free()
	await process_frame


func test_goto_casino() -> void:
	var main := make_main()
	await wait_tower(main)
	main.run.claridad = 123
	check(DevCommands.execute("help", main).contains("goto_casino"), "help lista goto_casino")
	check(DevCommands.execute("goto_casino", main).contains("Uso") and DevCommands.execute("goto_casino 0", main).contains("Uso") and DevCommands.execute("goto_casino 16", main).contains("Uso") and main.casino == null, "sin etapa o con una etapa invalida explica como se usa")
	var Room := preload("res://scripts/casino_room.gd")
	for st in [1, 4, 8, 12, 15]:
		var msg := DevCommands.execute("goto_casino %d" % st, main)
		check(msg.contains(str(st)) and main.casino != null and main.run.stage == st and main.stage_number == st, "goto_casino %d abre el casino de esa etapa" % st)
		check(main.casino.lay.tier == Room.tier_of(st) and main.casino.cell == main.casino.lay.entry, "...con la sala del nivel %d" % Room.tier_of(st))
		check(main.run.claridad == 123 and main.casino.cam.current, "...sin tocar la claridad y con la camara del casino")
	# Salir de ese casino lleva a la torre de la etapa siguiente
	main.casino.quick = true
	main.casino.cell = main.casino.lay.exit
	main.casino.step(Vector2i(0, -1))
	while main.generating:
		await process_frame
	check(main.casino == null and main.stage_number == 15 and main.logic != null, "salir del casino de la etapa 15 no pasa de la 15")
	main.open_main_menu()
	check(DevCommands.execute("goto_casino 5", main).contains("Empieza"), "en el menu pide empezar una partida")
	main._cancel_jobs()
	main.queue_free()
	await process_frame


func all_labels(node: Node, out: Array) -> void:
	if node is Control and node.get("text") != null and node.get("cube") != null:
		out.append(node)
	for ch in node.get_children():
		all_labels(ch, out)


func test_hud() -> void:
	var main := make_main()
	await wait_tower(main)
	# El jugador no ve textos de controles ni de depuracion
	check(not main.debug_hud and not main.hud.visible, "el texto de depuracion (semilla, etc.) arranca oculto")
	var labels: Array = []
	all_labels(main.hud_layer, labels)
	var bad := ""
	for l in labels:
		if l != main.hud and l.visible and (str(l.text).contains("Esc:") or str(l.text).contains("flechas") or str(l.text).contains("Mouse") or str(l.text).contains("Semilla")):
			bad = str(l.text)
	check(bad == "", "el HUD no muestra textos de controles ni de depuracion (%s)" % bad)
	check(main.hud.text.contains("Semilla"), "el texto de depuracion sigue existiendo, escondido")
	# F2 lo muestra y lo oculta
	var f2 := InputEventKey.new()
	f2.keycode = KEY_F2
	f2.pressed = true
	main._unhandled_input(f2)
	check(main.debug_hud and main.hud.visible, "F2 muestra los textos de depuracion")
	main._unhandled_input(f2)
	check(not main.debug_hud and not main.hud.visible, "F2 otra vez los oculta")
	# Lo que si ve el jugador: etapa y claridad (la racha sólo sale en el cartel de ganancia; la cuenta de la fila de abajo ya no se muestra)
	check(main.stage_label.text.contains("Etapa") and not main.stage_label.text.contains("Piso"), "se ve la etapa, sin el piso")
	check(main.hud_panel.get("streak_label") == null, "la racha no está en la ventana de la partida: sólo sale en el cartel de ganancia")
	main.logic.streak = 3
	main._refresh()
	# Casino: sin textos de ayuda
	main.enter_casino()
	var cl: Array = []
	all_labels(main.casino.hud_layer, cl)
	var cbad := ""
	for l in cl:
		if l.visible and (str(l.text).contains("WASD") or str(l.text).contains("Esc") or str(l.text).contains("Empuja") or str(l.text).contains("Chocar")):
			cbad = str(l.text)
	check(cbad == "", "el casino no muestra textos de ayuda (%s)" % cbad)
	main._cancel_jobs()
	main.queue_free()
	await process_frame


func test_set_luz() -> void:
	Profile.path = "user://test_profile.json"
	Profile.reset()
	var main := make_main()
	await wait_tower(main)
	check(DevCommands.execute("help", main).contains("set_luz"), "help lista set_luz")
	check(DevCommands.execute("set_luz", main).contains("Uso") and DevCommands.execute("set_luz abc", main).contains("Uso"), "set_luz sin numero (o con letras) muestra el uso")
	check(DevCommands.execute("set_luz 120", main).contains("120") and Profile.luz() == 120, "set_luz 120 deja la Luz en 120")
	check(DevCommands.execute("set_luz -5", main).contains("0") and Profile.luz() == 0, "no baja de 0")
	# funciona en el menu y actualiza lo que se esta viendo
	main.open_main_menu()
	main.main_menu.show_panel("escenarios")
	check(main.main_menu.scenarios.luz_counter.value == 0 and main.main_menu.scenarios.play_buttons["glaciar"].disabled, "sin Luz el Glaciar esta bloqueado")
	DevCommands.execute("set_luz 40", main)
	check(main.main_menu.scenarios.luz_counter.value == 40 and not main.main_menu.scenarios.play_buttons["glaciar"].disabled and not main.main_menu.scenarios.play_buttons["polvorin"].disabled, "el selector de escenarios se actualiza al instante")
	main.main_menu.show_panel("despertar")
	DevCommands.execute("set_luz 7", main)
	check(main.main_menu.meta.luz_counter.value == 7, "la pantalla de habilidades tambien")
	# queda guardada en el perfil
	Profile.data = {}
	Profile._loaded_from = ""
	check(Profile.luz() == 7, "la Luz queda guardada en el perfil")
	Profile.reset()
	main._cancel_jobs()
	main.queue_free()
	await process_frame
