extends SceneTree
## Pruebas de las etapas especiales: el sorteo por partida (de a multiplos de 3), sus reglas, la recompensa, las habilidades
## persistentes que dan, y su efecto en el juego.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_trials.gd

const Trials := preload("res://scripts/trials.gd")
const Items := preload("res://scripts/items.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const RunState := preload("res://scripts/run_state.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
const Abilities := preload("res://scripts/abilities.gd")
const Profile := preload("res://scripts/profile.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	Profile.path = "user://test_profile.json"
	Profile.reset()
	test_schedule()
	test_catalog()
	test_visibility()
	test_reward()
	test_generator_bias()
	await test_in_game()
	await test_no_retry()
	await test_meteors()
	Profile.reset()
	print("tests de las pruebas terminados, fallos: ", fails)
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


func test_schedule() -> void:
	check(Trials.stages() == [3, 6, 9, 12, 15] and Trials.is_trial_stage(15) and not Trials.is_trial_stage(4) and not Trials.is_trial_stage(1) and not Trials.is_trial_stage(18), "las pruebas caen de a multiplos de 3 (3, 6, ... 15)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var a := Trials.draw_schedule(Scenarios.get_scenario("pesadilla").pool, rng)
	check(a.size() == 5, "se sortea una prueba para cada una de las 5 etapas")
	var no_repeat := true
	var prev := ""
	for st in Trials.stages():
		no_repeat = no_repeat and a[st] != prev and Trials.CATALOG.has(a[st])
		prev = a[st]
	check(no_repeat, "nunca la misma prueba dos veces seguidas")
	var variety := {}
	for seed_i in 12:
		rng.seed = seed_i
		variety[str(Trials.draw_schedule(Scenarios.get_scenario("pesadilla").pool, rng))] = true
	check(variety.size() >= 6, "cada partida sortea distinto (%d sorteos distintos en 12)" % variety.size())
	# Se sabe desde el principio cual es la proxima prueba y cuantas etapas faltan
	var run := RunState.new()
	run.trial_schedule = a
	var n := Trials.next_from(a, 1)
	check(n.stage == 3 and n.left == 2 and not n.trial.is_empty(), "desde la etapa 1 la proxima prueba es la 3, en 2 etapas")
	check(Trials.next_from(a, 3).left == 0 and Trials.next_from(a, 4).stage == 6 and Trials.next_from(a, 28).is_empty(), "en la prueba faltan 0; despues de la ultima no hay mas")
	check(run.next_trial_text(1).begins_with("Próxima prueba: ") and run.next_trial_text(1).contains("en 2 etapas"), "texto de la proxima prueba")
	check(run.next_trial_text(2).contains("en 1 etapa)"), "singular: en 1 etapa")
	check(run.next_trial_text(3).begins_with("Prueba: "), "en la prueba se dice su nombre")
	check(run.next_trial_text(28) == "", "sin pruebas pendientes no hay texto")
	check(RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict()))).trial_schedule == a, "el sorteo se guarda y se carga")
	# Las ultimas pagan mas
	check(run.trial_at(3).mult < run.trial_at(9).mult and run.trial_at(9).mult < run.trial_at(15).mult and run.trial_at(4).is_empty(), "las ultimas pruebas pagan mas claridad")


func test_catalog() -> void:
	for id in Trials.CATALOG:
		var t: Dictionary = Trials.CATALOG[id]
		check(t.name != "" and t.desc != "" and not t.has("ability"), "la prueba %s tiene nombre y descripcion y ya no da habilidades (se ganan por escenario)" % id)
	var seen := {}
	for sc in Scenarios.ALL:
		for aid in Scenarios.ability_ids(sc):
			check(not Abilities.get_ability(aid).is_empty() and not seen.has(aid), "la habilidad %s existe y es de un solo escenario (%s)" % [aid, sc.id])
			seen[aid] = true
	check(seen.size() == Abilities.ALL.size(), "cada habilidad se gana en algún escenario")
	for sc in Scenarios.ALL:
		for id in sc.pool:
			check(Trials.CATALOG.has(id), "el escenario %s sortea pruebas que existen" % sc.id)
	check(Gen.profile_for_stage(3, {"pace": "fast"}).pace == "fast" and Gen.profile_for_stage(3, {}, {"pace": "fast"}).pace == "fast", "una prueba o un escenario pueden fijar el ritmo")
	check(Gen.profile_for_stage(5).pace == Gen.profile_for_stage(5, {}, {}).pace, "sin prueba ni escenario el perfil no cambia")


func test_visibility() -> void:
	var player := Vector3i(3, 10, 3)
	check(Trials.visible_from({}, Vector3i(0, 40, 0), player), "sin prueba se ve todo")
	var fog: Dictionary = Trials.CATALOG.niebla
	check(Trials.visible_from(fog, Vector3i(3, 10 + Trials.FOG_ABOVE, 3), player) and not Trials.visible_from(fog, Vector3i(3, 10 + Trials.FOG_ABOVE + 1, 3), player), "con niebla se ven pocos pisos por encima")
	check(Trials.visible_from(fog, Vector3i(3, 0, 3), player), "...pero lo de abajo se ve")
	var dark: Dictionary = Trials.CATALOG.oscuridad
	check(Trials.visible_from(dark, Vector3i(4, 10, 3), player) and not Trials.visible_from(dark, Vector3i(10, 10, 3), player) and not Trials.visible_from(dark, Vector3i(3, 20, 3), player), "en la oscuridad sólo se ven los bloques cercanos")


func test_reward() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var run := RunState.new()
	run.trial_schedule = {3: "niebla", 15: "prisa"}
	var r := Trials.reward(run.trial_at(3), 3, run, rng)
	check(not r.item.is_empty() and r.item.type == Items.Type.BOOST and run.has_room_for(r.item) and r.text.begins_with("Recompensa"), "superar una prueba da un boost")
	check(Trials.reward({}, 4, run, rng).text == "", "una etapa comun no da recompensa")
	run.boosts.assign(["aire_extra", "ojo_de_hielo", "ahorro", "pies_de_luz", "paso_firme"])
	var full := Trials.reward(run.trial_at(15), 15, run, rng)
	check(full.item.is_empty() and full.claridad == 310 and full.text.contains("310"), "sin lugar para boosts la recompensa es claridad")


func test_generator_bias() -> void:
	# Un escenario o una prueba sesgan los tipos de bloque que genera el generador
	var K := TowerLogic.Kind
	var count := func(bias: Dictionary, kind: int) -> int:
		var total := 0
		for seed_i in 3:
			var r := Gen.generate_stage(seed_i + 1, 5, 0.3, {"tries": 5, "climb": 0.4, "max_states": 1500, "bias": bias})
			if r.ok:
				for id in r.logic.kind_of:
					if r.logic.kind_of[id] == kind:
						total += 1
		return total
	var plain: int = count.call({}, K.ICE)
	var icy: int = count.call({"kinds": {K.ICE: 1.6}, "plat_ice": 0.35, "cap_bonus": 3}, K.ICE)
	check(icy > plain, "el sesgo de hielo genera mas hielo (%d contra %d)" % [icy, plain])
	var bombs: int = count.call({"kinds": {K.BOMB: 2.0}, "cap_bonus": 2}, K.BOMB)
	check(bombs > 0, "el sesgo de bombas genera bombas aunque la dificultad sea baja (%d)" % bombs)
	var merged := Scenarios.merge_bias({"kinds": {K.ICE: 1.0}, "cap_bonus": 1}, {"kinds": {K.ICE: 0.5, K.BOMB: 1.0}, "plat_ice": 0.2})
	check(merged.kinds[K.ICE] == 1.5 and merged.kinds[K.BOMB] == 1.0 and merged.cap_bonus == 1 and is_equal_approx(merged.plat_ice, 0.2), "los sesgos del escenario y de la prueba se suman")
	var prof := Gen.profile_for_stage(9, Trials.CATALOG.hielo_total, Scenarios.get_scenario("glaciar"))
	check(prof.bias.kinds[K.ICE] > 2.0 and prof.bias.plat_ice > 0.4, "el perfil de una prueba en un escenario junta los sesgos")


func test_in_game() -> void:
	var main := make_main()
	await wait_tower(main)
	# Una partida con un sorteo conocido
	main.run.trial_schedule = {6: "niebla", 9: "sin_ayudas"}
	main.stage_number = 6
	main.run.stage = 6
	main.trial = main.run.trial_at(6)
	main._refresh()
	check(main.trial_label.visible and main.trial_label.text.contains("Niebla") and main.stage_label.text.contains("*"), "se ve la prueba en el HUD, con sus efectos")
	var hidden := 0
	var lim: int = main.logic.player.y + Trials.FOG_ABOVE
	for id in main.block_nodes:
		if main.logic.positions[id].y > lim:
			hidden += 1
			if main.block_nodes[id].visible:
				hidden = -1000
	check(hidden > 0, "con niebla se esconden los pisos altos (%d)" % hidden)
	# En una etapa comun el HUD anuncia la proxima
	main.stage_number = 7
	main.trial = {}
	main._refresh()
	var nxt: Dictionary = main.run.next_trial_info(8)
	check(not main.trial_label.visible and not nxt.is_empty() and str(nxt.trial.name) == "Sin ayudas" and int(nxt.left) == 1, "en una etapa comun no se muestra la prueba: la cuenta el tabernero (quedan %s)" % str(nxt.get("left")))
	# Superar la prueba: claridad multiplicada, boost de regalo y habilidad persistente (sólo la primera vez)
	main.stage_number = 6
	main.trial = main.run.trial_at(6)
	main.run.claridad = 100
	main.logic.claridad = 30
	main.banked = false
	var boosts_before: int = main.run.boosts.size()
	main._bank_claridad()
	var mult: float = main.trial.mult
	check(main.run.claridad >= 100 + int(round(30 * mult)) and main.run.trials_cleared == 1, "la claridad de la prueba se multiplica")
	check(main.run.boosts.size() == boosts_before + 1 and main._trial_msg.contains("Prueba superada") and main._trial_msg.contains("Recompensa"), "y da un boost de regalo")
	check(not main._trial_msg.contains("Habilidad persistente") and Profile.owned_abilities().is_empty() and main.run_new_abilities.is_empty(), "superar una prueba ya no da habilidades persistentes (se ganan por escenario)")
	# Las habilidades valen en los proximos runs
	Profile.grant_ability("mente_despejada")
	var run2 := RunState.new()
	Profile.apply_to_run(run2)
	check(run2.claridad == 25, "Mente despejada: se empieza con +25 de claridad")
	# Sin ayudas: no se usan consumibles
	main.trial = main.run.trial_at(9)
	main.run.consumables.assign(["freno"])
	main.logic.won = false
	main.use_consumable_slot(0)
	check(main.run.consumables == ["freno"] and main.toast.text.contains("consumibles"), "en Sin ayudas no se usan consumibles")
	main.trial = {}
	main.use_consumable_slot(0)
	check(main.run.consumables.is_empty(), "fuera de la prueba si")
	main._cancel_jobs()
	main.queue_free()
	await process_frame
	# Habilidades de la torre: garras de hielo, fuerza bruta
	Profile.grant_ability("garras_de_hielo")
	Profile.grant_ability("fuerza_bruta")
	var perks := Abilities.perks_for(Profile.owned_abilities())
	check(perks.has("garras_de_hielo") and perks.has("fuerza_bruta"), "las habilidades dan perks a la torre")
	Profile.reset()


func test_meteors() -> void:
	var main := make_main()
	await wait_tower(main)
	main.run.trial_schedule = {3: "meteoritos"}
	main.stage_number = 3
	main.run.stage = 3
	main.trial = main.run.trial_at(3)
	main.new_tower(7)
	await wait_tower(main)
	check(main.logic.meteors and not main.logic.protected_ids.is_empty() and main.logic.meteor_cell != TowerLogic.NO_CELL, "en Lluvia de meteoritos la torre tiene meteoritos, camino protegido y un bloque marcado")
	var marked: Vector3i = main.logic.meteor_cell
	var step: Dictionary = main.solution[0]
	main._apply(step.dir, step.mode)
	check(not main.logic.blocks.has(marked) and main.logic.meteor_hit == marked, "con el primer movimiento cae el meteorito sobre el bloque marcado")
	main._cancel_jobs()
	main.queue_free()
	await process_frame


func test_no_retry() -> void:
	var main := make_main()
	await wait_tower(main)
	main.run.trial_schedule = {6: "todo_o_nada"}
	main.stage_number = 6
	main.trial = main.run.trial_at(6)
	main.run.stage = 6
	main.run.claridad = 500
	main.request_restart()
	check(main.run.retries == 0 and main.run.claridad == 500 and main.toast.text.contains("no hay reintentos"), "en Todo o nada no hay reintentos")
	main.pause_game()
	check(main.pause_menu.buttons["reiniciar"].disabled, "ni en el menu de pausa")
	main.resume_game()
	main.logic.lost = true
	main.logic.lost_reason = "Caíste al vacío"
	await main._on_anim_done()
	check(main.run_over and main.run_end.visible and main.run_end.reason_label.text.contains("Todo o nada"), "caer en Todo o nada termina el run")
	main._cancel_jobs()
	main.queue_free()
	await process_frame
