extends SceneTree
## Pruebas de los escenarios (entrada con Luz, reglas propias), las habilidades persistentes y el perfil.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_scenarios.gd

const Scenarios := preload("res://scripts/scenarios.gd")
const Profile := preload("res://scripts/profile.gd")
const AbilityArt := preload("res://scripts/ability_art.gd")
const Abilities := preload("res://scripts/abilities.gd")
const Trials := preload("res://scripts/trials.gd")
const RunState := preload("res://scripts/run_state.gd")
const Roulette := preload("res://scripts/roulette.gd")
const Room := preload("res://scripts/casino_room.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	Profile.path = "user://test_profile.json"
	Profile.reset()
	test_catalog()
	test_profile()
	test_award()
	test_abilities_effects()
	test_price_and_casino()
	await test_flow()
	await test_screens()
	Profile.reset()
	print("tests de los escenarios terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func make_main() -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	main.tower_rows = 3
	main.test_mode_jobs = false
	root.add_child(main)
	return main


func wait_tower(main: Node) -> void:
	await process_frame
	while main.generating or main.logic == null:
		await process_frame


func test_catalog() -> void:
	check(Scenarios.get_scenario("pesadilla").entry == 0 and Scenarios.FREE == "pesadilla", "La Pesadilla es gratis")
	var ids := {}
	for s in Scenarios.ALL:
		ids[s.id] = true
		check(s.name != "" and s.desc != "" and s.luz_mult >= 1.0 and s.pool.size() >= 4, "el escenario %s trae nombre, descripcion, multiplicador y un sorteo de pruebas" % s.id)
		if s.id != "pesadilla":
			check(s.entry > 0, "%s se paga con Luz" % s.id)
	check(ids.size() == Scenarios.ALL.size() and Scenarios.ALL.size() >= 6, "hay varios escenarios distintos (%d)" % Scenarios.ALL.size())
	check(Scenarios.get_scenario("no_existe").id == "pesadilla", "un escenario desconocido cae en el gratuito")
	# Mas dificiles pagan mas Luz
	check(Scenarios.get_scenario("relojeria").luz_mult > Scenarios.get_scenario("glaciar").luz_mult, "los escenarios mas dificiles pagan mas Luz")
	# Cada escenario permite ganar habilidades que le son propias
	check(Scenarios.ability_ids(Scenarios.get_scenario("glaciar")).has("garras_de_hielo") and not Scenarios.ability_ids(Scenarios.get_scenario("pesadilla")).has("garras_de_hielo"), "las garras de hielo sólo se ganan en el Glaciar")
	check(Scenarios.ability_ids(Scenarios.get_scenario("ruinas")).has("fuerza_bruta") and Scenarios.ability_ids(Scenarios.get_scenario("polvorin")).has("mecha_larga"), "cada escenario tiene su habilidad exclusiva")


func test_profile() -> void:
	Profile.reset()
	check(Profile.luz() == 0 and Profile.owned_abilities().is_empty() and not Profile.can_enter("glaciar") and Profile.can_enter("pesadilla"), "perfil nuevo: sin Luz, sin habilidades; el gratuito siempre se puede")
	check(Profile.pay_entry("pesadilla") and Profile.luz() == 0, "entrar al gratuito no cuesta nada")
	check(not Profile.pay_entry("glaciar") and Profile.luz() == 0, "sin Luz no se entra a un escenario de pago (y no se cobra)")
	# Un run da Luz segun lo que avanzaste, multiplicada por el escenario
	var run := RunState.new()
	run.towers_cleared = 10
	run.trials_cleared = 3
	run.max_stage = 11
	check(Profile.luz_for_run(run, false) == 10 * 5 + 3 * 20 and Profile.luz_for_run(run, true) == 110 + 100, "Luz: 5 por torre, 20 por prueba, 100 por escapar")
	run.scenario_id = "glaciar"
	check(Profile.luz_for_run(run, false) == int(round(110 * 1.5)), "el escenario multiplica la Luz")
	run.scenario_id = "pesadilla"
	var gained := Profile.record_run(run, false)
	check(gained == 110 and Profile.luz() == 110 and Profile.data.runs == 1 and Profile.data.best_stage == 11 and Profile.data.trials_cleared == 3, "record_run suma Luz y estadisticas")
	check(Profile.can_enter("glaciar") and Profile.pay_entry("glaciar") and Profile.luz() == 110 - 15, "con Luz se paga la entrada")
	# Se guarda y se carga
	Profile.grant_ability("pies_ligeros")
	Profile.data = {}
	Profile._loaded_from = ""
	Profile.load_profile()
	check(Profile.luz() == 95 and Profile.has_ability("pies_ligeros") and int(Profile.data.runs) == 1, "el perfil se guarda y se carga")
	# Archivo roto: se ignora
	var f := FileAccess.open(Profile.path, FileAccess.WRITE)
	f.store_string("esto no es json {{{")
	f = null
	Profile.data = {}
	Profile._loaded_from = ""
	check(Profile.luz() == 0 and Profile.owned_abilities().is_empty(), "un perfil danado se ignora")
	Profile.reset()


## Las habilidades se ganan por escenario: al escapar se da una de las del escenario que todavía no tengas; cuando no quedan, Luz.
func test_award() -> void:
	Profile.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pesadilla := Scenarios.ability_ids(Scenarios.get_scenario("pesadilla"))
	check(pesadilla.size() == 3, "La Pesadilla tiene 3 habilidades posibles")
	var got := []
	for i in 3:
		var res := Profile.award_scenario_ability("pesadilla", rng)
		check(res.ability != "" and res.luz == 0 and pesadilla.has(res.ability) and not got.has(res.ability) and Profile.has_ability(res.ability), "escape %d: gana una habilidad del escenario que no tenía (%s)" % [i + 1, res.ability])
		got.append(res.ability)
	check(Profile.luz() == 0, "mientras hay habilidades por ganar no se da Luz")
	var done := Profile.award_scenario_ability("pesadilla", rng)
	check(done.ability == "" and done.luz == Profile.ABILITY_LUZ and Profile.luz() == Profile.ABILITY_LUZ, "cuando ya las tiene todas, da Luz (%d)" % Profile.ABILITY_LUZ)
	var glaciar := Profile.award_scenario_ability("glaciar", rng)
	check(glaciar.ability == "garras_de_hielo" and Profile.has_ability("garras_de_hielo"), "cada escenario da las suyas (el Glaciar, las garras de hielo)")
	var again := Profile.award_scenario_ability("glaciar", rng)
	check(again.ability == "" and again.luz == int(round(Profile.ABILITY_LUZ * 1.5)), "y la Luz de reemplazo escala con el escenario")
	check(Profile.award_scenario_ability("tutorial", rng) == {"ability": "", "luz": 0}, "el tutorial no da nada")
	check(Scenarios.scenarios_for_ability("fuerza_bruta").size() == 1 and Scenarios.scenarios_for_ability("fuerza_bruta")[0].id == "ruinas", "se sabe en qué escenario se gana cada una")
	Profile.reset()


func test_abilities_effects() -> void:
	Profile.reset()
	for id in ["mente_despejada", "pies_ligeros", "bolsillo_sonador", "segunda_oportunidad"]:
		Profile.grant_ability(id)
	check(not Profile.grant_ability("pies_ligeros") and Profile.owned_abilities().size() == 4, "una habilidad se gana una sola vez")
	var run := RunState.new()
	Profile.apply_to_run(run)
	check(run.claridad == 25 and run.collapse_bonus == 1 and run.meta_consumable_slots == 1 and is_equal_approx(run.restart_discount, 0.15), "las habilidades se aplican al empezar el run")
	check(run.consumable_capacity() == RunState.BASE_CONSUMABLES + 1 and run.restart_cost() == int(round(25 * 0.85)), "Bolsillo de soñador y Segunda oportunidad: un lugar mas y reintentos 15 % mas baratos")
	check(RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict()))).collapse_bonus == 1, "los efectos se guardan con el run")
	# Habilidades de la torre
	var K := TowerLogic.Kind
	var base := func(perk: String) -> RefCounted:
		var t := TowerLogic.new()
		t.size = Vector2i(5, 5)
		t.goal_y = 99
		t.collapse_every = 1000
		t.moves_to_collapse = 1000
		for x in 5:
			for z in 5:
				t.add_block(Vector3i(x, 0, z))
		t.add_block(Vector3i(3, 1, 2), false, K.HEAVY)
		t.add_block(Vector3i(0, 0, 2), false, K.ICE)
		t.player = Vector3i(2, 1, 2)
		t.apply_perks([perk] if perk != "" else [])
		return t
	var t0 = base.call("")
	check(not t0.try_action(Vector3i(1, 0, 0), TowerLogic.Mode.GRAB).ok, "sin Fuerza bruta no se empuja un pesado")
	var t1 = base.call("fuerza_bruta")
	check(t1.try_action(Vector3i(1, 0, 0), TowerLogic.Mode.GRAB).ok and t1.blocks.has(Vector3i(4, 1, 2)), "con Fuerza bruta si")
	# Garras de hielo: colgarse del borde de un bloque de hielo
	var h0 = base.call("")
	h0.blocks.erase(Vector3i(0, 0, 2))
	var ice_edge := func(perk: String) -> bool:
		var t := TowerLogic.new()
		t.size = Vector2i(3, 3)
		t.goal_y = 99
		t.collapse_every = 1000
		t.moves_to_collapse = 1000
		for x in 3:
			for z in 3:
				t.add_block(Vector3i(x, 0, z), false, K.ICE)
		t.player = Vector3i(1, 1, 1)
		t.apply_perks([perk] if perk != "" else [])
		t.hang_dir = Vector3i.ZERO
		t.player = Vector3i(1, 1, 2)
		return t.try_action(Vector3i(0, 0, 1), TowerLogic.Mode.HANG).ok
	check(not ice_edge.call("") and ice_edge.call("garras_de_hielo"), "Garras de hielo: se puede colgar de un borde de hielo")
	var streak := TowerLogic.new()
	streak.apply_perks(["sin_racha"])
	check(streak.streak_mult(6) == 1.0, "la prueba Sin racha deja el multiplicador en 1")
	Profile.reset()


func test_price_and_casino() -> void:
	var run := RunState.new()
	check(Roulette.run_price(run) == 50, "el precio de la ficha normal")
	run.price_mult = 0.75
	check(Roulette.run_price(run) == 38 and Roulette.price(10, 0.5) == 43 and Roulette.price(1) == 50, "el escenario puede abaratar la ficha")
	var lay := Room.layout(1, 3)
	check(lay.tier == 3 and Room.layout(1).tier == 0 and Room.layout(15, 0).tier == 0, "el escenario puede fijar el nivel del casino")
	var v := Room.build_voxels(1, 3)
	check(v.solid.size() > Room.build_voxels(1).solid.size(), "el gran casino de la etapa 1 es mas grande que la taberna")


func test_flow() -> void:
	Profile.reset()
	var main := make_main()
	await wait_tower(main)
	# Sin Luz: pedir un escenario de pago cae en La Pesadilla
	main.start_game("glaciar")
	check(main.run.scenario_id == "pesadilla" and Profile.luz() == 0, "sin Luz alcanza con el gratuito: no se entra al de pago")
	await wait_tower(main)
	check(main.run.trial_schedule.size() == 5 and main.run.next_trial_text(1) != "", "al empezar se sortean las pruebas")
	main.open_main_menu()
	# Con Luz: se paga la entrada y rigen las reglas del escenario
	Profile.data.luz = 100
	Profile.save()
	main.start_game("relojeria")
	check(main.run.scenario_id == "relojeria" and Profile.luz() == 75 and is_equal_approx(main.run.price_mult, 0.75), "con Luz se entra: se cobra la entrada y rigen las reglas")
	while main.generating or main.logic == null:
		await process_frame
	check(main.profile.pace == "fast", "Relojeria: todas las etapas son rapidas")
	var pool: Array = Scenarios.get_scenario("relojeria").pool
	var all_in_pool := true
	for st in main.run.trial_schedule:
		all_in_pool = all_in_pool and pool.has(main.run.trial_schedule[st])
	check(all_in_pool, "las pruebas del sorteo salen del conjunto del escenario")
	# Al terminar el run la Luz se multiplica por el escenario y queda anotada
	main.run.towers_cleared = 4
	var before := Profile.luz()
	main.end_run(false, "x")
	check(Profile.luz() == before + int(round(20 * 1.8)) and main.run_end.luz_row.visible and main.run_end.luz_gain.value == int(round(20 * 1.8)) and main.run_end.luz_total_counter.value == Profile.luz(), "el fin del run da Luz (multiplicada) y la muestra con el sol")
	check(not all_text(main.run_end).contains("Luz"), "la pantalla de fin de run no nombra la Luz con texto")
	# El escenario viaja en el guardado
	var run2 := RunState.new()
	run2.scenario_id = "polvorin"
	run2.price_mult = 1.0
	check(RunState.from_dict(JSON.parse_string(JSON.stringify(run2.to_dict()))).scenario_id == "polvorin", "el escenario se guarda con el run")
	main._cancel_jobs()
	main.queue_free()
	await process_frame
	Profile.reset()


## Todo el texto que muestran los controles de un arbol.
func all_text(root_node: Node) -> String:
	var out := ""
	var stack: Array = [root_node]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n.get("text") != null and n.get("cube") != null:
			out += str(n.text) + "\n"
		stack.append_array(n.get_children())
	return out


func test_screens() -> void:
	Profile.reset()
	var main := make_main()
	await wait_tower(main)
	main.open_main_menu()
	var mm = main.main_menu
	mm.buttons["nueva"].pressed.emit()
	var sc = mm.scenarios
	check(sc.visible and sc.play_buttons.size() == Scenarios.ALL.size() + 1 and not sc.play_buttons["pesadilla"].disabled and not sc.play_buttons["tutorial"].disabled, "el selector lista el tutorial y todos los escenarios; los gratuitos se pueden jugar")
	check(sc.play_buttons["glaciar"].disabled and sc.luz_counter.value == 0, "sin Luz los de pago estan bloqueados")
	Profile.data.luz = 20
	sc.refresh()
	check(not sc.play_buttons["glaciar"].disabled and sc.play_buttons["relojeria"].disabled and sc.luz_counter.value == 20, "con 20 de Luz se puede entrar a los que cuestan 15 o menos")
	# Tarjetas: una por escenario, con "?" y el boton de entrada; se desplazan en horizontal
	var card = sc.cards["glaciar"]
	check(sc.cards.size() == Scenarios.ALL.size() + 1 and card.info_button.text == "?" and card.info_button.position.x > card.size.x * 0.7 and card.info_button.position.y < 30.0, "cada escenario es una tarjeta con un ? arriba a la derecha")
	check(card.enter_button.position.y > card.size.y * 0.7 and absf(card.enter_button.position.x + card.enter_button.custom_minimum_size.x * 0.5 - card.size.x * 0.5) < 2.0, "y el boton de entrada abajo al centro")
	check(card.enter_button.cost == 15 and sc.cards["pesadilla"].enter_button.cost == 0 and sc.cards["pesadilla"].enter_button.text == "Jugar", "el boton de entrada muestra el costo (el gratuito dice Jugar)")
	await process_frame
	await process_frame
	sc.scroll.scroll_horizontal = 0
	sc.scroll_cards(1)
	check(sc.scroll.scroll_horizontal > 0, "se desplazan las tarjetas hacia la derecha")
	sc.scroll_cards(-1)
	check(sc.scroll.scroll_horizontal == 0, "y hacia la izquierda")
	check(not all_text(sc).contains("Luz"), "el selector no nombra la Luz con texto: es el sol")
	# El "?" abre toda la informacion
	card.info_button.pressed.emit()
	var texts := all_text(sc.info_panel)
	check(sc.info_panel.visible and texts.contains("Garras de hielo") and texts.contains("Hielo total") and texts.contains("hielo"), "el ? muestra las reglas, las pruebas y las habilidades del escenario")
	check(sc.info_box.find_child("costo", true, false).value == 15 and sc.info_box.find_child("multiplicador", true, false).label.text == "x1.5", "...y el costo y lo que paga, con el sol")
	check(not texts.contains("Luz"), "la informacion tampoco nombra la Luz con texto")
	sc.info_close.pressed.emit()
	check(not sc.info_panel.visible, "se cierra con Volver")
	sc.back.emit()
	check(mm.main_center.visible and not sc.visible, "Volver regresa al menu")
	# Pantalla de habilidades: una grilla de iconos
	mm.buttons["despertar"].pressed.emit()
	var meta = mm.meta
	check(meta.visible and meta.tiles.size() == Abilities.ALL.size() and meta.grid.get_child_count() == Abilities.ALL.size(), "Habilidades muestra un icono por habilidad")
	check(not all_text(meta).contains("Luz") and meta.luz_counter.value == Profile.luz(), "la pantalla de habilidades muestra la Luz con el sol, sin texto")
	for a in Abilities.ALL:
		check(AbilityArt.ART.has(a.id) and AbilityArt.ART[a.id].rows.size() == 9, "la habilidad %s tiene su propio icono de 9 filas" % a.id)
		for row in AbilityArt.ART[a.id].rows:
			check(row.length() == 9, "el icono de %s tiene filas de 9 columnas" % a.id)
	check(not meta.tiles["garras_de_hielo"].owned and not meta.tiles["fuerza_bruta"].owned, "sin la habilidad el casillero esta en gris")
	Profile.grant_ability("garras_de_hielo")
	meta.refresh()
	check(meta.tiles["garras_de_hielo"].owned and not meta.tiles["fuerza_bruta"].owned, "con la habilidad el casillero esta a color")
	# Los iconos se ven distintos si se tiene la habilidad o no (gris y quieto contra color y animado)
	var colors_owned := {}
	var colors_gray := {}
	var ids: Array = AbilityArt.ART.keys()
	ids.erase("corazon")   # (el corazón de las vidas usa el mismo dibujo pero no es una habilidad)
	check(ids.size() == Abilities.ALL.size() and AbilityArt.ART.has("corazon"), "cada habilidad tiene un icono (y las vidas su corazón)")
	for id in ids:
		for row in AbilityArt.ART[id].rows:
			for ch in row:
				if ch != ".":
					var c: Color = AbilityArt.ART[id].pal[ch]
					colors_owned[c] = true
					colors_gray[c.get_luminance()] = true
	check(colors_owned.size() > 20, "los iconos usan muchos colores (%d)" % colors_owned.size())
	# Los iconos son 3D: tienen espesor (varias capas en profundidad) y los que se tienen giran despacio
	for id in AbilityArt.ART:
		var voxels: Array = AbilityArt.model(id)
		var zs := {}
		for v in voxels:
			zs[v.z] = true
		check(voxels.size() > 60 and zs.size() >= 3 and zs.has(0) and zs.has(1) and zs.has(-1), "el icono de %s es un volumen de cubitos con %d capas" % [id, zs.size()])
	check(AbilityArt.SPIN > 0.0 and AbilityArt.SPIN < 1.0, "giran despacio")
	check(AbilityArt.model("ojos_de_gato").size() > AbilityArt.ART.ojos_de_gato.rows.size() * 9 * 0.4, "el modelo tiene mas cubitos que celdas de la figura plana")
	# Pasar el mouse por un icono muestra un cartel con la informacion (sin hacer clic)
	meta.tiles["garras_de_hielo"].mouse_entered.emit()
	check(meta.tip.visible and meta.tip.text.contains("Garras de hielo") and meta.tip.text.contains("colgarte de los bloques de hielo") and meta.tip.text.contains("Glaciar") and not meta.tip.text.contains("Luz"), "al pasar el mouse sale un cartel con el nombre, el efecto y dónde se gana")
	meta.tiles["garras_de_hielo"].mouse_exited.emit()
	check(not meta.tip.visible, "y se va al sacar el mouse")
	meta.tiles["fuerza_bruta"].mouse_entered.emit()
	check(meta.tip.text.contains("Todavía no la tenés") and meta.tip.text.contains("Ruinas"), "el cartel dice si todavía no se tiene y dónde ganarla")
	meta.tiles["fuerza_bruta"].mouse_exited.emit()
	# Tocar un icono abre la descripcion: efecto, como se consiguio y en que escenarios
	meta.tiles["garras_de_hielo"].pressed.emit()
	var t2 := all_text(meta.info_panel)
	check(meta.info_panel.visible and t2.contains("Garras de hielo") and t2.contains("Ya la tenés") and t2.contains("Podés colgarte de los bloques de hielo"), "tocar un icono muestra la habilidad que se tiene y su efecto")
	check(t2.contains("Cómo la conseguiste") and t2.contains("Escapando de la pesadilla") and t2.contains("Glaciar") and not t2.contains("La Pesadilla"), "dice que se gana al escapar y en que escenarios (el Glaciar, no La Pesadilla)")
	meta.info_close.pressed.emit()
	check(not meta.info_panel.visible, "se cierra con Volver")
	meta.tiles["fuerza_bruta"].pressed.emit()
	var t3 := all_text(meta.info_panel)
	check(t3.contains("Todavía no la tenés") and t3.contains("Cómo conseguirla") and t3.contains("Escapando de la pesadilla") and t3.contains("Ruinas") and t3.contains("empujar"), "la que no se tiene tambien da su descripcion y como y donde conseguirla")
	check(not t3.contains("Luz"), "la descripcion tampoco nombra la Luz con texto")
	check(meta.info_panel.find_child("*", true, false) != null, "la ventana de descripcion tiene contenido")
	# La prueba de la Pesadilla aparece en la Pesadilla (gratis)
	meta.info_close.pressed.emit()
	meta.tiles["mente_despejada"].pressed.emit()
	check(all_text(meta.info_panel).contains("La Pesadilla") and all_text(meta.info_panel).contains("(gratis)"), "Mente despejada se gana en La Pesadilla, que es gratis")
	meta.info_close.pressed.emit()
	meta.tiles["pies_ligeros"].pressed.emit()   # (Relojería: un escenario de pago)
	var luz_costs := 0
	var stack: Array = [meta.info_panel]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n.get("prefix") != null and n.get("value") != null:
			luz_costs += 1
		stack.append_array(n.get_children())
	check(luz_costs > 0, "los escenarios de pago muestran su costo con el sol")
	main._cancel_jobs()
	main.queue_free()
	await process_frame
	Profile.reset()
