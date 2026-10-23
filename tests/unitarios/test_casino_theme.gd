extends SceneTree
## Pruebas de la estética de las mesas por nivel de casino: los juegos se "purifican" a medida que mejoran las salas (headless).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_casino_theme.gd

const CasinoTheme := preload("res://scripts/casino/casino_theme.gd")
const Rules := preload("res://scripts/casino/casino_rules.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const RouletteScreen := preload("res://scripts/casino/roulette_screen.gd")
const SlotsScreen := preload("res://scripts/casino/slots_screen.gd")
const BlackjackScreen := preload("res://scripts/casino/blackjack_screen.gd")
const CasinoScene := preload("res://scripts/casino/casino_scene.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_tiers()
	await test_screens()
	await test_ui()
	print("tests de la estética del casino terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_tiers() -> void:
	check(CasinoTheme.TIERS.size() == 4, "hay un estilo por nivel de sala")
	for t in 3:
		var a := CasinoTheme.for_tier(t)
		var b := CasinoTheme.for_tier(t + 1)
		check(a.corruption > b.corruption or (a.corruption == 0.0 and b.corruption == 0.0), "la suciedad baja del nivel %d al %d" % [t, t + 1])
		check(a.ornament <= b.ornament and a.shine <= b.shine, "y el ornamento y el brillo no bajan")
	check(CasinoTheme.for_tier(0).corruption == CasinoTheme.UI_DEFAULT and CasinoTheme.for_tier(3).corruption == 0.0, "la taberna es lo de siempre y el gran casino no tiene corrupción")
	check(CasinoTheme.for_tier(0).ornament == 0 and CasinoTheme.for_tier(0).shine == 0 and CasinoTheme.for_tier(3).ornament == 3 and CasinoTheme.for_tier(3).shine == 3, "sin adornos ni brillo en la taberna; todo en el gran casino")
	check(CasinoTheme.for_tier(-5) == CasinoTheme.for_tier(0) and CasinoTheme.for_tier(99) == CasinoTheme.for_tier(3), "un nivel fuera de rango se acota")
	check(CasinoTheme.for_tier(3).wood.get_luminance() > CasinoTheme.for_tier(0).wood.get_luminance(), "el aro de la rueda pasa de madera oscura a marfil")
	# el nivel de una partida
	var run := RunState.new()
	run.stage = 5
	check(CasinoTheme.tier_for(run) == 1, "sin visita, el nivel sale de la etapa")
	Rules.enter(run, 3)
	check(CasinoTheme.tier_for(run) == 3 and CasinoTheme.for_run(run).name == "gran_casino", "con visita, el de la sala")
	var gran := RunState.new()
	gran.stage = 1
	gran.scenario_id = "gran_casino"
	check(CasinoTheme.tier_for(gran) == 3, "el escenario Gran Casino es de nivel alto desde la etapa 1")
	check(CasinoTheme.tier_for(null) == 0, "sin partida, la taberna")
	# barrido de brillo
	check(CasinoTheme.sweep(0.0) < 0.0 and CasinoTheme.sweep(1.2) > 0.0 and CasinoTheme.sweep(1.2) < 1.0, "el brillo cruza y tiene una pausa")


func test_screens() -> void:
	for tier in 4:
		var run := RunState.new()
		run.stage = [1, 5, 9, 13][tier]
		run.claridad = 1000
		Rules.enter(run, tier)
		var expected := CasinoTheme.for_tier(tier)
		var r := RouletteScreen.new()
		var layer := CanvasLayer.new()
		root.add_child(layer)
		layer.add_child(r)
		r.setup(run, RandomNumberGenerator.new(), true)
		check(r.th == expected and r.wheel.th == expected, "la ruleta toma el estilo del nivel %d" % tier)
		var s := SlotsScreen.new()
		layer.add_child(s)
		s.setup(run, RandomNumberGenerator.new(), true)
		check(s.th == expected and s.reel_nodes[0].th == expected, "las tragamonedas, también")
		var b := BlackjackScreen.new()
		layer.add_child(b)
		b.setup(run, RandomNumberGenerator.new(), true)
		b.deal()
		await process_frame
		check(b.th == expected and b.player_views[0].th == expected, "el blackjack y sus cartas, también")
		for i in 3:
			await process_frame   # (se dibuja todo sin errores)
		layer.queue_free()
		await process_frame
	# chispas
	var sp := CasinoTheme.Sparkles.new()
	root.add_child(sp)
	sp.burst(Vector2(100, 100), 12, [Color.WHITE])
	check(sp._p.size() == 12, "un estallido de chispas")
	sp._process(2.0)
	check(sp._p.is_empty(), "y se apagan solas")
	sp.queue_free()


func test_ui() -> void:
	Draw.default_corruption = CasinoTheme.UI_DEFAULT
	for tier in [1, 3]:
		var run := RunState.new()
		run.stage = [1, 5, 9, 13][tier]
		var c := CasinoScene.new()
		root.add_child(c)
		c.quick = true
		c.setup(run, RandomNumberGenerator.new())
		check(is_equal_approx(Draw.default_corruption, float(CasinoTheme.for_tier(tier).corruption)), "en el casino de nivel %d los botones y textos se limpian (%.2f)" % [tier, Draw.default_corruption])
		c.free()
		check(is_equal_approx(Draw.default_corruption, CasinoTheme.UI_DEFAULT), "al salir del casino se restablece")
	# en el tutorial (story) no se toca
	var story := CasinoScene.new()
	story.story = true
	root.add_child(story)
	story.quick = true
	var run2 := RunState.new()
	story.setup(run2, RandomNumberGenerator.new())
	check(is_equal_approx(Draw.default_corruption, CasinoTheme.UI_DEFAULT), "el tutorial no cambia la interfaz")
	story.free()
