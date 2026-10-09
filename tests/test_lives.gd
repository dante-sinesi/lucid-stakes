extends SceneTree
## Pruebas de las vidas: tres revividas por partida, el contador de corazones 3D, la Vida extra y el fin de la partida sin vidas (headless).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_lives.gd

const RunState := preload("res://scripts/run_state.gd")
const Items := preload("res://scripts/items.gd")
const ItemIcons := preload("res://scripts/item_icons.gd")
const LivesHud := preload("res://scripts/lives_hud.gd")
const CasinoScene := preload("res://scripts/casino_scene.gd")

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
	# el seguro, que ahorra claridad, igual gasta la vida si se murió
	var r2 := RunState.new()
	r2.insurance = true
	r2.note_retry(true)
	check(r2.lives == 2 and not r2.insurance, "el seguro cubre la claridad pero no la vida")


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
	while main.generating or main.logic == null:
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
	main.logic.lost = true
	main.logic.lost_reason = "Caíste al vacío"
	main.request_restart()
	check(main.run.lives == 2 and not main.run_over and not main.logic.lost, "morir y reintentar cuesta una vida")
	check(main.lives_hud.lives == 2, "y el contador se actualiza")
	# reintentar sin morir no gasta vidas
	main.request_restart()
	check(main.run.lives == 2, "un reintento voluntario no gasta vidas")
	# sin vidas, morir termina la partida
	main.run.lives = 0
	main.logic.lost = true
	main.logic.lost_reason = "Caíste al vacío"
	main.request_restart()
	check(main.run_over and main.run.lives == 0, "sin vidas, al morir se termina la partida")
	main._cancel_jobs()
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
	t._cancel_jobs()
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
