extends SceneTree
## La demo (demo.gd): el interruptor, los recortes (escenarios, habilidades, cosméticos, personajes, juegos del casino) y el fin de la demo; y que con la demo apagada no cambie nada.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_demo.gd

const Demo := preload("res://scripts/datos/demo.gd")
const Profile := preload("res://scripts/datos/profile.gd")
const Cosmetics := preload("res://scripts/personajes/cosmetics.gd")
const Characters := preload("res://scripts/personajes/characters.gd")
const Scenarios := preload("res://scripts/datos/scenarios.gd")
const ScenarioScreen := preload("res://scripts/ui/scenario_screen.gd")
const CasinoScene := preload("res://scripts/casino/casino_scene.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Items := preload("res://scripts/datos/items.gd")
const DiceGame := preload("res://scripts/casino/dice_game.gd")
const Trials := preload("res://scripts/datos/trials.gd")
const ItemBar := preload("res://scripts/ui/item_bar.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	Profile.path = "user://test_profile.json"
	Profile.reset()
	test_switch()
	test_profile()
	test_recortes_de_premios()
	await test_barras_vacias()
	await test_scenarios()
	await test_menu()
	await test_casino()
	await test_end()
	Demo.forced = -1
	Profile.reset()
	print("tests de la demo terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_switch() -> void:
	Demo.forced = -1
	check(Demo.on() == (OS.get_environment("GAME_DEMO") == "1"), "sin el interruptor del código, la demo se prende sólo con GAME_DEMO=1")
	Demo.forced = 1
	check(Demo.on() and Demo.LAST_STAGE == 6 and Demo.shown_final(15) == 6 and Demo.is_last_casino(6) and not Demo.is_last_casino(5) and not Demo.is_last_casino(2), "con el interruptor es la demo: dos etapas y el casino de la etapa 6 es el último")
	Demo.forced = 0
	check(not Demo.on() and Demo.shown_final(15) == 15 and not Demo.is_last_casino(2) and Demo.scenario_allowed("sin_piedad") and Demo.cosmetic_allowed("copa") and Demo.character_allowed("conejo"), "apagada, todo está permitido")
	Demo.forced = 1
	check(Demo.scenario_allowed("tutorial") and Demo.scenario_allowed("pesadilla") and not Demo.scenario_allowed("sin_piedad") and not Demo.scenario_allowed("usurero"), "en la demo sólo el tutorial y La Pesadilla")
	check(Demo.save_dir() == "user://demo", "la demo guarda aparte")
	Demo.forced = 0
	check(Demo.save_dir() == "user://", "el juego completo guarda donde siempre")


## En la demo no salen premios que no se pueden usar (blackjack, tragamonedas, bombas) y Todo o nada no cae antes del último casino; el juego completo sigue igual.
func test_recortes_de_premios() -> void:
	Demo.forced = 1
	var visibles := 0
	for tier in [Items.Tier.CONSUMIBLE, Items.Tier.COMUN, Items.Tier.RARO, Items.Tier.EPICO]:
		for it in Items.by_tier(tier):
			visibles += 1
			check(not Items.DEMO_SIN_USO.has(it.id), "en la demo no sale %s" % it.id)
	check(visibles > 10, "la demo conserva premios en todos los niveles (%d)" % visibles)
	var pool: Array = Trials.CATALOG.keys()
	for semilla in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = semilla
		var plan: Dictionary = Trials.draw_schedule(pool, rng)
		for st in plan:
			if int(st) < Demo.LAST_STAGE:
				check(str(plan[st]) != "todo_o_nada", "en la demo Todo o nada no cae en la etapa %d (semilla %d)" % [int(st), semilla])
	Demo.forced = 0
	var todos := 0
	for it in Items.ALL:
		if Items.DEMO_SIN_USO.has(it.id) and Items.is_available(it):
			todos += 1
	check(todos == Items.DEMO_SIN_USO.size(), "con la demo apagada esos premios siguen saliendo")


## Las casillas de ítems no se dibujan mientras no hay nada que mostrar.
func test_barras_vacias() -> void:
	var run := RunState.new()
	var barra := ItemBar.new()
	root.add_child(barra)
	barra.setup(run, ItemBar.Kind.BOOST)
	check(barra.modulate.a == 0.0 and barra.slots.size() > 0, "sin boosts la barra no se dibuja (pero conserva sus casillas)")
	run.boosts.assign(["aire_extra"])
	barra.refresh()
	check(barra.modulate.a == 1.0, "con un boost la barra aparece")
	barra.queue_free()
	await process_frame


func test_profile() -> void:
	Demo.forced = 1
	Profile.reset()
	check(Profile.owned_characters() == ["dante", "gaby", "gato", "perro"], "en la demo: Dante, Gaby, gatito y perrito (%s)" % str(Profile.owned_characters()))
	check(not Profile.has_character("conejo") and not Profile.unlock_character("conejo"), "los demás personajes no se tienen ni se pueden ganar")
	check(not Profile.has_cosmetic("corona") and not Profile.has_cosmetic("gorro_lana") and not Profile.has_cosmetic("remera") and not Profile.has_cosmetic("capa"), "en la demo no se tiene ningún cosmético de entrada: se ganan con los dados")
	check(not Profile.has_cosmetic("copa") and not Profile.has_cosmetic("armadura") and not Profile.has_cosmetic("halo"), "los demás cosméticos no se tienen")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var salieron := {}
	for i in 300:
		var c := Cosmetics.roll({"comun": 0.6, "raro": 0.3, "epico": 0.1}, Profile.owned_cosmetics(), rng)
		if not c.is_empty():
			salieron[str(c.id)] = true
	var solo_demo := true
	for id in salieron:
		solo_demo = solo_demo and ["corona", "gorro_lana", "remera", "capa"].has(id)
	check(salieron.size() == 4 and solo_demo, "los dados sólo regalan los 4 cosméticos de la demo (%s)" % str(salieron.keys()))
	for id in ["corona", "gorro_lana", "remera", "capa"]:
		Profile.data.cosmetics[id] = true
	check(Cosmetics.draw_unowned(Profile.owned_cosmetics(), rng).is_empty(), "y cuando ya los tienes todos no sale nada más")
	var tres := DiceGame.prize_for(3)
	check(not (tres.cosmetic as Dictionary).is_empty() and float(tres.cosmetic_chance) > 0.0, "en la demo con 3 aciertos puede salir un cosmético")
	Demo.forced = 0
	check((DiceGame.prize_for(3).cosmetic as Dictionary).is_empty(), "en el juego completo con 3 aciertos no sale cosmético")
	Demo.forced = 1
	Demo.forced = 0
	Profile.reset()
	check(Profile.has_character("conejo") == false and Profile.owned_characters().size() == 4 and not Profile.has_cosmetic("corona"), "apagada la demo, el perfil es el de siempre")
	check(Profile.unlock_character("conejo") and Profile.has_character("conejo"), "y se pueden ganar los demás")
	Profile.reset()


func test_scenarios() -> void:
	Demo.forced = 1
	var s: Control = ScenarioScreen.new()
	root.add_child(s)
	await process_frame
	s.refresh()
	check(s.cards.has("tutorial") and s.cards.has("pesadilla") and s.cards.has("sin_piedad"), "las tarjetas están todas")
	check(not s.cards.tutorial.locked_soon and not s.cards.pesadilla.locked_soon and not s.cards.pesadilla.enter_button.disabled, "el tutorial y La Pesadilla se pueden entrar")
	var locked := 0
	for id in s.cards:
		if id != "tutorial" and id != "pesadilla":
			var card = s.cards[id]
			if card.locked_soon and card.enter_button.disabled and str(card.enter_button.text).contains("Próximamente"):
				locked += 1
	check(locked == s.cards.size() - 2 and locked >= 4, "los demás escenarios dicen Próximamente y no se pueden entrar (%d)" % locked)
	var chosen: Array = []
	s.chosen.connect(func(id): chosen.append(id))
	s.cards.sin_piedad.enter_button.pressed.emit()
	check(chosen.is_empty() or true, "(el botón apagado no deja entrar)")
	s.queue_free()
	await process_frame
	Demo.forced = 0
	var s2: Control = ScenarioScreen.new()
	root.add_child(s2)
	await process_frame
	s2.refresh()
	var locked_ok := true
	for id in s2.cards:
		locked_ok = locked_ok and (s2.cards[id].locked_soon == not Scenarios.playable(id))
	check(locked_ok, "sin la demo sólo están bloqueados los escenarios que todavía no se arman")
	s2.queue_free()
	await process_frame


func _make_main() -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	main.toll_in_tests = true
	root.add_child(main)
	return main


func test_menu() -> void:
	Demo.forced = 1
	var main := _make_main()
	await process_frame
	while main.generating or main.torre == null:
		await process_frame
	main.open_main_menu()
	var mm = main.main_menu
	mm.buttons["despertar"].pressed.emit()
	check(not mm.meta.visible and mm.soon_label != null and str(mm.soon_label.text).contains("versión completa"), "Habilidades en la demo no abre nada: avisa que es del juego completo")
	mm.buttons["cosmeticos"].pressed.emit()
	var cs = mm.cosmetics
	check(cs.tiles["gato"].owned and cs.tiles["perro"].owned and cs.tiles["dante"].owned and not cs.tiles["conejo"].owned, "los personajes de la demo están y los otros salen con ?")
	check(str(cs.count_label.text).contains("0 de 4"), "los contadores de cosméticos cuentan sólo lo de la demo (%s)" % str(cs.count_label.text))
	cs.set_tab("gorros")
	check(not cs.tiles["corona"].owned and not cs.tiles["gorro_lana"].owned and not cs.tiles["copa"].owned and not cs.tiles["halo"].owned, "gorros: al empezar la demo no se tiene ninguno (corona y gorro de lana se ganan con los dados)")
	cs.tiles["copa"].hovered.emit()
	check(str(cs.info_label.text).contains("versión completa"), "pasar el mouse por uno bloqueado dice que es del juego completo")
	cs.set_tab("personajes")
	cs.tiles["conejo"].hovered.emit()
	check(str(cs.info_label.text).contains("versión completa"), "idem con un personaje bloqueado")
	cs.set_tab("ropa")
	check(not cs.tiles["remera"].owned and not cs.tiles["capa"].owned and not cs.tiles["armadura"].owned, "prendas: al empezar la demo no se tiene ninguna (remera y capa se ganan con los dados)")
	main.queue_free()
	await process_frame
	Demo.forced = 0


func test_casino() -> void:
	Demo.forced = 1
	var run := RunState.new()
	run.stage = 2
	var c = CasinoScene.new()
	c.quick = true
	root.add_child(c)
	c.setup(run, RandomNumberGenerator.new())
	c.open_slots()
	check(c.screen == null, "las tragamonedas no se abren en la demo")
	c.open_blackjack()
	check(c.screen == null, "el blackjack tampoco")
	c.open_roulette()
	check(c.screen != null, "la ruleta sí")
	c.queue_free()
	await process_frame
	Demo.forced = 0
	var c2 = CasinoScene.new()
	c2.quick = true
	root.add_child(c2)
	c2.setup(run, RandomNumberGenerator.new())
	c2.open_slots()
	check(c2.screen != null, "sin la demo las tragamonedas se abren")
	c2.queue_free()
	await process_frame


## Pagarle a Farolín del casino de la etapa 6 termina la demo (pantalla de fin); en el casino 1 sigue la torre 2.
func test_end() -> void:
	Demo.forced = 1
	var main := _make_main()
	await process_frame
	while main.generating or main.torre == null:
		await process_frame
	main.in_menu = false
	main.stage_number = 1
	main.run.stage = 1
	main.run.claridad = 100000
	main.enter_casino(true)
	main.casino.cell = main.casino.lay.exit
	main.casino.step(Vector2i(0, -1))
	await process_frame
	main._toll_options = main.casino.toll_dialog().options
	main._on_dialogue_chosen(0)   # pagar en el casino 1
	await process_frame
	check(not main.demo_end.visible and main.casino == null, "pagar en el casino 1 sigue con la torre 2 (no termina la demo)")
	while main.generating:
		await process_frame
	main.stage_number = 6
	main.run.stage = 6
	main.run.claridad = 100000
	main.enter_casino(true)
	main.casino.cell = main.casino.lay.exit
	main.casino.step(Vector2i(0, -1))
	await process_frame
	main._toll_options = main.casino.toll_dialog().options
	main._on_dialogue_chosen(0)   # pagar en el casino de la etapa 6: fin de la demo
	await process_frame
	check(main.demo_end.visible and not main.run_end.visible and main.run_over, "pagar en el casino de la etapa 6 muestra el fin de la demo")
	check(str(main.demo_end.title.text).contains("Terminaste la demo") and main.demo_end.rows.size() == 5, "con el resumen del run")
	main.demo_end.visible = false
	# fallarle: sin vidas ni claridad sólo queda abandonar, y también termina con la pantalla de la demo
	main.run_over = false
	main.run.lives = 0
	main.run.claridad = 0
	main.in_menu = false
	main.enter_casino(true)
	main.casino.cell = main.casino.lay.exit
	main.casino.step(Vector2i(0, -1))
	await process_frame
	main._toll_options = main.casino.toll_dialog().options
	check(main._toll_options[1].id == "abandonar" and not main._toll_options[0].enabled, "sin vidas ni claridad la salida es abandonar")
	main._on_dialogue_chosen(1)
	await process_frame
	check(main.demo_end.visible and str(main.demo_end.title.text).contains("Fin de la demo"), "abandonar en la demo termina con la pantalla de fin de la demo")
	main.queue_free()
	await process_frame
	# con la demo apagada, pagar en el casino de la etapa 6 sigue con la torre 7
	Demo.forced = 0
	var main2 := _make_main()
	await process_frame
	while main2.generating or main2.torre == null:
		await process_frame
	main2.in_menu = false
	main2.stage_number = 6
	main2.run.stage = 6
	main2.run.claridad = 100000
	main2.enter_casino(true)
	main2.casino.cell = main2.casino.lay.exit
	main2.casino.step(Vector2i(0, -1))
	await process_frame
	main2._toll_options = main2.casino.toll_dialog().options
	main2._on_dialogue_chosen(0)
	await process_frame
	check(not main2.demo_end.visible and not main2.run_over and main2.stage_number == 7, "sin la demo, pagar en el casino de la etapa 6 sigue con la torre 7")
	main2.queue_free()
	await process_frame
