extends SceneTree
## Pruebas de las vidas: tres revividas por partida, el contador de corazones 3D, la Vida extra y el fin de la partida sin vidas (headless).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_lives.gd

const RunState := preload("res://scripts/datos/run_state.gd")
const Items := preload("res://scripts/datos/items.gd")
const Abilities := preload("res://scripts/datos/abilities.gd")
const ItemIcons := preload("res://scripts/ui/item_icons.gd")
const LivesHud := preload("res://scripts/ui/lives_hud.gd")
const CasinoScene := preload("res://scripts/casino/casino_scene.gd")
const Profile := preload("res://scripts/datos/profile.gd")
const Scenarios := preload("res://scripts/datos/scenarios.gd")
const Roulette := preload("res://scripts/casino/roulette.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_run()
	test_item()
	test_hud()
	await test_main()
	await test_casino()
	test_compromiso()
	await test_compromiso_main()
	print("tests de las vidas terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_run() -> void:
	var run := RunState.new()
	check(run.lives == 3 and RunState.MAX_LIVES == 3 and run.can_revive(), "se empieza con 3 vidas")
	run.note_retry(true)
	check(run.lives == 2 and run.retries == 1, "reintentar después de morir gasta una vida")
	run.note_retry(false)
	check(run.lives == 2, "reintentar por voluntad (sin morir) no gasta vidas")
	run.note_retry(true)
	run.note_retry(true)
	check(run.lives == 0 and not run.can_revive(), "con 3 muertes se acaban las vidas")
	run.note_retry(true)
	check(run.lives == 0, "no baja de cero")
	run.consumables.assign(["totem"])
	check(run.can_revive(), "con un Tótem todavía se puede revivir")
	run.note_retry(true)
	check(run.lives == 0 and run.consumables.is_empty(), "el Tótem revive sin gastar vida")
	check(run.add_life() and run.lives == 1 and run.add_life() and run.add_life() and run.lives == 3, "se suman vidas hasta 3")
	check(not run.add_life() and run.lives == 3, "no se pueden tener 4")
	# se guarda con el run
	run.lives = 1
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	check(back.lives == 1, "las vidas se guardan con la partida")
	check(RunState.from_dict({}).lives == 3 and RunState.from_dict({"lives": 99}).lives == 3, "un guardado viejo (o raro) arranca con 3")
	# morir ya no cuesta claridad: la vida sí
	var r2 := RunState.new()
	r2.note_retry(true)
	check(r2.lives == 2, "morir gasta la vida")


func test_item() -> void:
	var it := Items.get_item("vida_extra")
	check(not it.is_empty() and it.type == Items.Type.CONSUMABLE and it.tier == Items.Tier.RARO and ItemIcons.has_icon("vida_extra") and it.desc.contains("3"), "existe la Vida extra (consumible raro con ícono)")
	check(Items.get_item("totem").desc.contains("vida"), "el Tótem aclara que tampoco gasta una vida")


func test_hud() -> void:
	var h := LivesHud.new()
	root.add_child(h)
	check(h.max_lives == 3 and h.lives == 3, "el contador muestra 3 corazones")
	h.lives = 1
	check(h.lives == 1 and h._pop > 0.0, "al cambiar de vidas el corazón da un saltito")
	h._process(0.1)
	h.queue_free()


func test_main() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	await process_frame
	while main.generating or main.torre == null:
		await process_frame
	check(main.lives_hud != null and main.lives_hud.lives == 3 and main.lives_hud.visible, "el juego tiene el contador de vidas a la vista")
	# Vida extra: sólo si hay menos de 3
	main.run.consumables.assign(["vida_extra", "vida_extra"])
	main.use_consumable_slot(0)
	check(main.run.lives == 3 and main.run.consumables.size() == 2, "con las 3 vidas, la Vida extra no se usa (y no se gasta)")
	main.run.lives = 1
	main.use_consumable_slot(0)
	check(main.run.lives == 2 and main.run.consumables == ["vida_extra"] and main.lives_hud.lives == 2, "con menos de 3, da una vida y se gasta")
	main.use_consumable_slot(0)
	main.use_consumable_slot(0)
	check(main.run.lives == 3 and main.run.consumables.size() == 0 or main.run.consumables.size() == 1, "(la siguiente completa las 3)")
	# morir y reintentar gasta una vida
	main.run.claridad = 1000
	main.run.consumables.clear()
	main.run.lives = 3
	main.torre.perder("Caíste al vacío")
	main.request_restart()
	check(main.run.lives == 2 and not main.run_over and not main.torre.t.muerta, "morir y reintentar cuesta una vida")
	check(main.lives_hud.lives == 2, "y el contador se actualiza")
	# reintentar sin morir (desde la pausa) también cuesta una vida
	main.request_restart()
	check(main.run.lives == 1, "un reintento voluntario cuesta una vida")
	# sin vidas, morir termina la partida
	main.run.lives = 0
	main.torre.perder("Caíste al vacío")
	await create_timer(0.4).timeout   # (en las pruebas la caída espera 0,1 s antes de terminar la partida)
	check(main.run_over and main.run.lives == 0, "sin vidas, al morir se termina la partida")
	main.queue_free()
	await process_frame
	# en el tutorial no hay vidas
	var t = load("res://scenes/main.tscn").instantiate()
	t.test_mode = true
	root.add_child(t)
	await process_frame
	t.start_tutorial(0, true)
	await process_frame
	check(not t.lives_hud.visible, "en el tutorial no se ven las vidas")
	t.queue_free()
	await process_frame


func test_casino() -> void:
	var run := RunState.new()
	run.stage = 8
	run.lives = 2
	var c := CasinoScene.new()
	root.add_child(c)
	c.quick = true
	c.setup(run, RandomNumberGenerator.new())
	await process_frame
	check(c.lives_hud != null and c.lives_hud.lives == 2, "el casino también muestra las vidas")
	run.lives = 3
	c._refresh_hud()
	check(c.lives_hud.lives == 3, "y se actualizan")
	c.free()


func test_compromiso() -> void:
	Profile.path = "user://test_profile.json"
	Profile.reset()
	var scn := Scenarios.get_scenario("compromiso")
	check(scn.id == "compromiso" and scn.entry > 0 and scn.lives == 1 and scn.permadeath and scn.no_totem and scn.no_extra_life, "existe el escenario Compromiso: una vida, sin segundas oportunidades, sin Tótems ni Vidas extra")
	check(Scenarios.ability_ids(scn) == ["corazon_extra"], "y da el Corazón extra")
	var a := Abilities.get_ability("corazon_extra")
	check(not a.is_empty() and a.desc.contains("4"), "el Corazón extra existe (4 corazones)")
	# en un escenario común el Corazón extra suma un corazón; en Compromiso sigue siendo una sola vida
	var run := RunState.new()
	Profile.grant_ability("corazon_extra")
	Profile.apply_to_run(run)
	check(run.max_lives() == 4 and run.lives == 4, "con el Corazón extra se empieza con 4 vidas")
	check(run.add_life() == false, "y no se pasa de 4")
	run.lives = 3
	check(run.add_life() and run.lives == 4, "la Vida extra llega hasta 4")
	var c := RunState.new()
	c.scenario_id = "compromiso"
	Profile.apply_to_run(c)
	check(c.max_lives() == 1 and c.lives == 1 and c.permadeath() and not c.can_revive(), "en Compromiso: una sola vida y no se revive (aunque tengas el Corazón extra)")
	c.consumables.assign(["totem", "vida_extra"])
	check(c.item_blocked("totem") and c.item_blocked("vida_extra") and not c.item_blocked("freno"), "los Tótems y las Vidas extra no sirven")
	c.lives = 0
	check(not c.add_life(), "no se pueden recuperar vidas")
	# la ruleta no regala lo que el escenario inhabilita
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	c.claridad = 100000
	var blocked := 0
	for i in 400:
		var res := Roulette.resolve(c, rng, 4)   # una casilla rara (donde puede salir el Tótem)
		if res.prize.has("id") and c.item_blocked(str(res.prize.id)):
			blocked += 1
	check(blocked == 0, "la ruleta nunca da un Tótem en Compromiso (%d)" % blocked)
	# se guarda con el run
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	check(back.bonus_lives == 1 and back.lives == 4 and back.max_lives() == 4, "los corazones de más se guardan con la partida")
	var back2 := RunState.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	check(back2.max_lives() == 1 and back2.lives == 0, "y las vidas de Compromiso también")
	Profile.reset()


func test_compromiso_main() -> void:
	Profile.path = "user://test_profile.json"
	Profile.reset()
	Profile.grant_ability("corazon_extra")
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	await process_frame
	while main.generating or main.torre == null:
		await process_frame
	# el contador se adapta a la cantidad de corazones
	main.run = RunState.new()
	main.run.bonus_lives = 1
	main.run.lives = 4
	main._refresh()
	check(main.lives_hud.max_lives == 4 and main.lives_hud.lives == 4, "con el Corazón extra el contador muestra 4 corazones")
	# Compromiso: morir termina la partida de una
	main.run = RunState.new()
	main.run.scenario_id = "compromiso"
	Profile.apply_to_run(main.run)
	main._refresh()
	check(main.lives_hud.max_lives == 1 and main.lives_hud.lives == 1, "en Compromiso se ve un solo corazón")
	main.run.consumables.assign(["vida_extra", "totem"])
	main.use_consumable_slot(0)
	check(main.run.lives == 1 and main.run.consumables.size() == 2, "la Vida extra no funciona (y no se gasta)")
	main.run.claridad = 1000
	main.torre.perder("Caíste al vacío")
	await create_timer(0.4).timeout
	check(main.run_over, "morir en Compromiso termina la partida (con Tótem y todo)")
	main.queue_free()
	await process_frame
	Profile.reset()
