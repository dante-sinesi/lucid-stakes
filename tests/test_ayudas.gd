extends SceneTree
## Pruebas de las ayudas de los juegos: se abren solas la primera vez, se vuelven a abrir con H, se recorren con las flechas y se cierran con Esc sin cerrar el juego.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_ayudas.gd

const GameHelp := preload("res://scripts/game_help.gd")
const Profile := preload("res://scripts/profile.gd")
const Controls := preload("res://scripts/controls.gd")
const RunState := preload("res://scripts/run_state.gd")
const CasinoScene := preload("res://scripts/casino_scene.gd")
const DiceGame := preload("res://scripts/dice_game.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func key(code: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _init() -> void:
	Profile.path = "user://test_profile.json"
	Profile.reset()
	test_content()
	test_fill()
	await test_flow()
	await test_screens()
	await test_dice()
	Profile.reset()
	print("tests de las ayudas terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_content() -> void:
	for id in ["ruleta", "tragamonedas", "blackjack", "dados", "taller", "caja", "tienda"]:
		check(GameHelp.PAGES.has(id) and GameHelp.PAGES[id].size() >= 1, "hay ayuda de " + id)
		for p in GameHelp.PAGES[id]:
			check(str(p.title) != "" and str(p.text) != "" and str(p.art) != "", "cada página de %s tiene título, dibujo y texto" % id)
			check(str(p.text).length() < 300, "el texto de una página de %s entra en el panel (%d letras)" % [id, str(p.text).length()])
	check(GameHelp.PAGES.tragamonedas.any(func(p): return str(p.title) == "Retener" and str(p.text).contains("retener")), "la tragamonedas explica qué es retener")


func test_fill() -> void:
	Controls.using_pad = false
	var t := GameHelp.fill("Gira con {enter}, elige con {space}, {arrows}, {shift}")
	check(t.contains("Enter") and t.contains("Espacio") and t.contains("las flechas") and t.contains("Shift") and not t.contains("{"), "con teclado los textos nombran las teclas")
	Controls.using_pad = true
	var t2 := GameHelp.fill("Gira con {enter}, {arrows}, {shift}, {qe}")
	check(t2.contains("A") and t2.contains("la cruceta") and t2.contains("LT") and t2.contains("LB y RB") and not t2.contains("{"), "con mando nombran los botones")
	Controls.using_pad = false


func test_flow() -> void:
	GameHelp.auto_open = true
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var h = GameHelp.attach(host, "ruleta")
	await process_frame
	await process_frame
	check(h.visible and Profile.help_seen("ruleta"), "la primera vez se abre sola y se anota como vista")
	var pages: int = GameHelp.PAGES.ruleta.size()
	key(KEY_RIGHT)
	await process_frame
	check(h.page == 1, "la flecha derecha pasa de página")
	key(KEY_LEFT)
	await process_frame
	check(h.page == 0, "la izquierda vuelve")
	for i in pages:
		key(KEY_ENTER)
		await process_frame
	check(not h.visible, "Enter en la última página la cierra")
	key(KEY_H)
	await process_frame
	check(h.visible and h.page == 0, "H la vuelve a abrir desde el principio")
	key(KEY_ESCAPE)
	await process_frame
	check(not h.visible, "Esc la cierra")
	host.queue_free()
	await process_frame
	# la segunda vez ya no se abre sola
	var host2 := Control.new()
	root.add_child(host2)
	var h2 = GameHelp.attach(host2, "ruleta")
	await process_frame
	await process_frame
	check(not h2.visible, "ya vista: no se abre sola")
	host2.queue_free()
	await process_frame
	GameHelp.auto_open = false


func test_screens() -> void:
	Profile.reset()
	var run := RunState.new()
	run.stage = 9
	run.claridad = 1000
	for entry in [["ruleta", "open_roulette"], ["tragamonedas", "open_slots"]]:
		var c := CasinoScene.new()
		root.add_child(c)
		c.quick = true
		c.setup(run, RandomNumberGenerator.new())
		await process_frame
		c.call(entry[1])
		await process_frame
		var h = c.screen.get_node_or_null("ayuda") if c.screen != null else null
		check(h != null, "la pantalla de %s tiene ayuda" % entry[0])
		if h != null:
			var bar = c.screen.get("pad_hints")
			var found := false
			for it in bar.items:
				found = found or str(it.get("text", "")) == "Ayuda"
			check(found, "la botonera de %s muestra Ayuda" % entry[0])
			key(KEY_H)
			await process_frame
			check(h.visible, "H abre la ayuda de " + entry[0])
			key(KEY_ESCAPE)
			await process_frame
			check(not h.visible and c.screen != null, "Esc cierra la ayuda y no el juego (%s)" % entry[0])
		c.queue_free()
		await process_frame
	var c2 := CasinoScene.new()
	root.add_child(c2)
	c2.quick = true
	c2.setup(run, RandomNumberGenerator.new())
	await process_frame
	c2.open_service()
	await process_frame
	check(c2.screen != null and c2.screen.get_node_or_null("ayuda") != null, "las estaciones de servicio tienen ayuda")
	c2.queue_free()
	await process_frame


func test_dice() -> void:
	var g := DiceGame.new()
	root.add_child(g)
	check(g.get_node_or_null("ayuda") != null, "los dados tienen ayuda")
	g.queue_free()
	await process_frame
