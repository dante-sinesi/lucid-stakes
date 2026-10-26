extends SceneTree
## Pruebas de las ayudas de los juegos: se abren solas la primera vez, se vuelven a abrir con H, se recorren con las flechas y se cierran con Esc sin cerrar el juego.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_ayudas.gd

const GameHelp := preload("res://scripts/ui/game_help.gd")
const Profile := preload("res://scripts/datos/profile.gd")
const Controls := preload("res://scripts/entrada/controls.gd")
const PadGlyph := preload("res://scripts/ui/pad_glyph.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const CasinoScene := preload("res://scripts/casino/casino_scene.gd")
const DiceGame := preload("res://scripts/casino/dice_game.gd")

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
	for id in ["ruleta", "tragamonedas", "blackjack", "dados", "taller", "tienda"]:
		check(GameHelp.PAGES.has(id) and GameHelp.PAGES[id].size() >= 1, "hay ayuda de " + id)
		for p in GameHelp.PAGES[id]:
			check(str(p.title) != "" and str(p.text) != "" and str(p.art) != "", "cada página de %s tiene título, dibujo y texto" % id)
			check(str(p.text).length() < 300, "el texto de una página de %s entra en el panel (%d letras)" % [id, str(p.text).length()])
	check(GameHelp.PAGES.tragamonedas.any(func(p): return str(p.title) == "Retener" and str(p.text).contains("retener")), "la tragamonedas explica qué es retener")


func test_fill() -> void:
	var kb := GameHelp.glyph_parts("space", false)
	check(kb.size() == 1 and kb[0].get("cap", "") == "Espacio", "con teclado {space} es la tecla Espacio")
	check(GameHelp.glyph_parts("lr", false).size() == 2 and GameHelp.glyph_parts("hold", false).size() == 3 and GameHelp.glyph_parts("arrows", false).size() == 4, "las flechas y 1, 2, 3 son varias teclas")
	var pad := GameHelp.glyph_parts("space", true)
	check(pad.size() == 1 and pad[0].has("slot") and int(pad[0].slot) == PadGlyph.Slot.WEST, "con mando {space} es el botón de la izquierda (X o cuadrado)")
	check(GameHelp.glyph_parts("enter", true)[0].has("slot") and GameHelp.glyph_parts("shift", true)[0].named == "LT" and GameHelp.glyph_parts("help", true)[0].named == "BACK" and GameHelp.glyph_parts("hold", true)[0].named == "DPAD", "con mando: A, LT, Select y la cruceta")
	# ningún texto nombra una tecla suelta: todas son fichas
	for id in GameHelp.PAGES:
		for p in GameHelp.PAGES[id]:
			var t := str(p.text)
			for bad in ["Enter", "Espacio", "Shift", "Esc ", " con C", "las flechas", "la cruceta"]:
				check(not t.contains(bad), "el texto de %s no nombra la tecla a mano (%s)" % [id, bad])
	# el texto con fichas se acomoda en renglones
	var rich = GameHelp.new()
	root.add_child(rich)
	var r = GameHelp._Rich.new()
	r.size = Vector2(880, 150)
	root.add_child(r)
	r.set_markup("Gira con {enter} y elige con {space}, {lr}")
	check(r._ops.size() >= 5, "el texto con fichas arma sus piezas (%d)" % r._ops.size())
	r.queue_free()
	rich.queue_free()


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
	run.stage = 5   # (el Taller está en el salón)
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
