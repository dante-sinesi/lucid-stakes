extends SceneTree
## Pruebas de los dados de la pantalla de carga (el minijuego), sus premios, los cosméticos y cómo se enganchan al juego.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_dice.gd

const DiceGame := preload("res://scripts/dice_game.gd")
const Cosmetics := preload("res://scripts/cosmetics.gd")
const Profile := preload("res://scripts/profile.gd")
const RunState := preload("res://scripts/run_state.gd")
const Loc := preload("res://scripts/loc.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	Profile.path = "user://test_profile.json"
	Profile.reset()
	test_prizes()
	await test_game()
	test_odds()
	test_white_dice()
	test_trap()
	test_cosmetics()
	await test_main()
	await test_loading_screen()
	await test_cosmetics_screen()
	Profile.reset()
	print("tests de los dados terminados, fallos: ", fails)
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


func test_prizes() -> void:
	check(DiceGame.prize_for(0).claridad == 0 and DiceGame.prize_for(1).claridad == 2 and DiceGame.prize_for(2).claridad == 8, "premios de 0 a 2 aciertos: nada, 2 y 8 de claridad (sin Luz)")
	check(DiceGame.prize_for(0).luz == 0 and DiceGame.prize_for(1).luz == 0 and DiceGame.prize_for(2).luz == 0, "con 2 aciertos o menos no hay Luz")
	var three := DiceGame.prize_for(3)
	check(three.claridad == 25 and three.luz == 1 and three.cosmetic.is_empty(), "3 aciertos: claridad y 1 de Luz, sin cosmetico")
	var four := DiceGame.prize_for(4)
	check(four.claridad == 80 and four.luz == 2 and four.cosmetic.has("comun") and four.cosmetic.has("raro") and not four.cosmetic.has("epico") and four.cosmetic.comun > four.cosmetic.raro, "4 aciertos: Luz y un cosmetico comun (a veces raro)")
	var five := DiceGame.prize_for(5)
	check(five.luz == 5 and five.claridad == 150 and five.cosmetic.has("raro") and five.cosmetic.has("epico") and not five.cosmetic.has("comun") and five.cosmetic.raro > five.cosmetic.epico, "5 aciertos: mas Luz y un cosmetico raro (a veces epico)")
	check(DiceGame.prize_for(-3).claridad == 0 and DiceGame.prize_for(99).luz == 5, "los aciertos fuera de rango se acotan")
	for n in 6:
		check(DiceGame.LINES.has(n) and DiceGame.LINES[n].size() >= 3, "el tabernero tiene varias frases para %d aciertos" % n)
	check(DiceGame.THROWS == 3 and DiceGame.DICE == 5 and DiceGame.REROLL_COST == 1 and DiceGame.MAX_REROLLS == 2, "3 tiros de 5 dados; volver a tirar cuesta 1 de Luz por dado y hay 2 re-tiradas")
	# copias independientes
	var a := DiceGame.prize_for(4)
	a.cosmetic["comun"] = 0.0
	check(DiceGame.prize_for(4).cosmetic.comun == 0.85, "el premio es una copia: no se modifica la tabla")


func test_game() -> void:
	var g := DiceGame.new()
	g.fast = true
	root.add_child(g)
	await process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	g.open(rng)
	check(g.visible and g.phase == DiceGame.Phase.PICK and g.throws_left == 3 and g.can_throw(), "al abrir hay 3 tiros y se puede elegir")
	for i in 5:
		check(g.picks[i] >= 1 and g.picks[i] <= 6, "la cara elegida del dado %d esta entre 1 y 6" % i)
	g.set_pick(0, 6)
	g.cycle_pick(0, 1)
	check(g.picks[0] == 1, "del 6 se pasa al 1 (con vuelta)")
	g.cycle_pick(0, -1)
	check(g.picks[0] == 6, "y del 1 al 6")
	g.set_pick(2, 99)
	check(g.picks[2] == 6, "la cara se acota a 6")
	# un tiro: se guardan los resultados y el premio sale por la senal
	var got := []
	g.prize.connect(func(info): got.append(info.duplicate()))
	g.throw_dice()
	check(got.size() == 1 and g.throws_left == 2 and g.phase == DiceGame.Phase.RESULT, "un tiro gasta un tiro, se resuelve y muestra el resultado")
	var expected := 0
	for i in 5:
		check(g.rolls[i] >= 1 and g.rolls[i] <= 6, "el dado %d salio entre 1 y 6" % i)
		if g.rolls[i] == g.picks[i]:
			expected += 1
	check(got[0].hits == expected and g.hits() == expected, "los aciertos cuentan los dados que salieron como se pidio")
	check(not g.can_throw() and g.throw_button.disabled, "mientras se muestra el resultado no se puede tirar")
	# Forzar una tirada con 4 y con 5 aciertos
	for i in 5:
		g.rolls[i] = g.picks[i]
	check(g.hits() == 5, "si todos coinciden son 5 aciertos")
	g.rolls[4] = g.picks[4] % 6 + 1
	check(g.hits() == 4, "uno distinto son 4")
	# Los tres tiros y despues nada mas
	g.phase = DiceGame.Phase.PICK
	g.throw_dice()
	g.phase = DiceGame.Phase.PICK
	g.throw_dice()
	check(g.throws_left == 0 and got.size() == 3, "sólo hay 3 tiros por carga")
	g.phase = DiceGame.Phase.PICK
	g.throw_dice()
	check(got.size() == 3 and g.throws_left == 0 and not g.can_throw(), "no hay un cuarto tiro")
	# Cerrar
	var closed_count := [0]
	g.closed.connect(func(): closed_count[0] += 1)
	g.phase = DiceGame.Phase.DONE
	g.request_close()
	check(not g.visible and closed_count[0] == 1, "terminados los tiros se cierra")
	# Se vuelve a abrir con tiros nuevos
	g.open(rng)
	check(g.throws_left == 3 and g.total_claridad == 0 and g.visible, "cada carga empieza con 3 tiros nuevos")
	g.queue_free()
	await process_frame
	# Modo normal: los dados se revelan de a uno y el cierre espera al tiro en curso
	var h := DiceGame.new()
	root.add_child(h)
	await process_frame
	h.open(rng)
	h.throw_dice()
	check(h.phase == DiceGame.Phase.ROLLING and h.revealed == 0, "al tirar los dados ruedan")
	h.request_close()
	check(h.visible and h.closing, "si se pide cerrar durante un tiro, espera a que termine")
	h._process(DiceGame.ROLL_TIME + 0.01)
	check(h.phase == DiceGame.Phase.REVEAL and h.revealed == 0, "despues de rodar empiezan a mostrarse")
	var order := []
	for k in 8:
		h._process(DiceGame.REVEAL_STEP * 0.55)
		if order.is_empty() or order[-1] != h.revealed:
			order.append(h.revealed)
	check(order.has(1) and order.has(2) and order.has(3) and order.has(4), "se revelan de a uno (%s)" % str(order))
	for k in 40:
		h._process(0.3)
	check(not h.visible and not h.closing, "al terminar el tiro en curso se cierra solo")
	h.queue_free()
	await process_frame


## Probabilidades: acertar los 5 es 1 en 7.776 y el promedio de claridad por tiro es chico.
func test_odds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var counts := [0, 0, 0, 0, 0, 0]
	var n := 30000
	var claridad := 0
	for t in n:
		var hits := 0
		for i in 5:
			if (1 + rng.randi() % 6) == (1 + rng.randi() % 6):
				hits += 1
		counts[hits] += 1
		claridad += int(DiceGame.prize_for(hits).claridad)
	check(absf(counts[0] / float(n) - 0.402) < 0.02 and absf(counts[1] / float(n) - 0.402) < 0.02 and absf(counts[2] / float(n) - 0.161) < 0.015, "la distribucion de aciertos es la esperada (%s)" % str(counts))
	check(counts[5] <= 12, "acertar los 5 es rarisimo (%d en %d tiros)" % [counts[5], n])
	var avg := claridad / float(n)
	check(avg > 2.0 and avg < 4.5, "el promedio de claridad por tiro es chico (%.2f)" % avg)


func test_cosmetics() -> void:
	Profile.reset()
	check(Cosmetics.ALL.size() >= 10 and Cosmetics.get_cosmetic("").is_empty() and Cosmetics.get_cosmetic("nope").is_empty(), "hay varios cosmeticos y ninguno con id vacio")
	for c in Cosmetics.ALL:
		check(Cosmetics.SLOTS.has(c.slot), "el cosmetico %s va en un hueco valido (gorro o prenda)" % c.id)
	check(Cosmetics.by_slot("gorro").size() >= 5 and Cosmetics.by_slot("prenda").size() >= 5, "hay varios gorros y varias prendas")
	for r in Cosmetics.RARITY_ORDER:
		check(Cosmetics.by_rarity(r).size() >= 3 and Cosmetics.RARITIES.has(r), "hay al menos 3 cosmeticos %s" % r)
	for c in Cosmetics.ALL:
		check(Cosmetics.RARITIES.has(c.rarity), "el cosmetico %s tiene una rareza valida" % c.id)
	check(Cosmetics.by_rarity("comun").size() > Cosmetics.by_rarity("raro").size() and Cosmetics.by_rarity("raro").size() > Cosmetics.by_rarity("epico").size(), "hay mas comunes que raros y mas raros que epicos")
	check(Cosmetics.get_cosmetic("corona").rarity == "epico" and Cosmetics.get_cosmetic("bufanda").rarity == "comun", "la corona es epica y la bufanda comun")
	# sorteo por rareza
	var rr := RandomNumberGenerator.new()
	rr.seed = 5
	var seen := {}
	for k in 400:
		var c := Cosmetics.roll({"comun": 0.85, "raro": 0.15}, [], rr)
		seen[c.rarity] = int(seen.get(c.rarity, 0)) + 1
	check(seen.get("comun", 0) > seen.get("raro", 0) * 3 and seen.get("raro", 0) > 20 and not seen.has("epico"), "con 4 aciertos salen sobre todo comunes y a veces raros (%s)" % str(seen))
	seen = {}
	for k in 400:
		var c2 := Cosmetics.roll({"raro": 0.7, "epico": 0.3}, [], rr)
		seen[c2.rarity] = int(seen.get(c2.rarity, 0)) + 1
	check(seen.get("raro", 0) > seen.get("epico", 0) and seen.get("epico", 0) > 60 and not seen.has("comun"), "con 5 salen raros y a veces epicos (%s)" % str(seen))
	# si ya tenes todos los de esa rareza, sale de otra; si tenes todos, nada
	var all_rare: Array = []
	for c3 in Cosmetics.by_rarity("raro"):
		all_rare.append(c3.id)
	check(Cosmetics.roll({"raro": 1.0}, all_rare, rr).rarity != "raro", "si ya tenes todos los raros, sale de otra rareza")
	var everything: Array = []
	for c4 in Cosmetics.ALL:
		everything.append(c4.id)
	check(Cosmetics.roll({"raro": 1.0}, everything, rr).is_empty(), "si ya tenes todos, no sale ninguno")
	check(Profile.has_cosmetic("") and not Profile.has_cosmetic("chaleco") and Profile.equipped_hat() == "" and Profile.equipped_outfit() == "", "al empezar no se tiene ni se lleva nada")
	check(not Profile.equip("chaleco") and Profile.equipped_outfit() == "", "no se puede elegir uno que no se tiene")
	check(Profile.grant_cosmetic("chaleco") and not Profile.grant_cosmetic("chaleco") and Profile.has_cosmetic("chaleco"), "un cosmetico se gana una vez")
	check(Profile.equip("chaleco") and Profile.equipped_outfit() == "chaleco" and Profile.equipped_hat() == "", "una prenda va al hueco de la prenda")
	Profile.grant_cosmetic("copa")
	check(Profile.equip("copa") and Profile.equipped_hat() == "copa" and Profile.equipped_outfit() == "chaleco", "un gorro va al hueco del gorro y se combinan")
	Profile.data = {}
	Profile._loaded_from = ""
	check(Profile.equipped_outfit() == "chaleco" and Profile.equipped_hat() == "copa" and Profile.owned_cosmetics().size() == 2, "se guarda en el perfil")
	Profile.unequip("gorro")
	check(Profile.equipped_hat() == "" and Profile.equipped_outfit() == "chaleco", "se saca el gorro y la prenda sigue")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var drawn := {}
	var owned: Array = []
	for k in Cosmetics.ALL.size():
		var c := Cosmetics.draw_unowned(owned, rng)
		check(not c.is_empty() and not owned.has(c.id), "se sortea uno que no se tiene")
		owned.append(c.id)
		drawn[c.id] = true
	check(drawn.size() == Cosmetics.ALL.size() and Cosmetics.draw_unowned(owned, rng).is_empty(), "salen todos, y cuando se tienen todos ya no sale ninguno")
	# Los modelos: cada gorro y cada prenda se arma (y tambien su silueta), con cajas de verdad
	for c in Cosmetics.ALL:
		var piece: Node3D = Cosmetics.build_hat(c.id) if c.slot == "gorro" else Cosmetics.build_outfit(c.id)
		check(piece != null and piece.get_child_count() >= 2, "el modelo de %s se arma" % c.id)
		var ghost: Node3D = Cosmetics.build_hat(c.id, true) if c.slot == "gorro" else Cosmetics.build_outfit(c.id, true)
		check(ghost.get_child_count() == piece.get_child_count() and (ghost.get_child(0) as MeshInstance3D).material_override is ShaderMaterial, "la silueta de %s usa el material de la silueta" % c.id)
		piece.free()
		ghost.free()
	check(Cosmetics.build_hat("") == null and Cosmetics.build_outfit("") == null, "sin id no hay modelo")
	Profile.reset()


func test_main() -> void:
	Profile.reset()
	var main := make_main()
	await wait_tower(main)
	var info := DiceGame.prize_for(2)
	main._on_dice_prize(info)
	check(info.granted == 8 and main.run.claridad == 8 and main.run.dice_claridad == 8, "los dados dan claridad al run")
	# tope por partida
	main.run.dice_claridad = RunState.DICE_CAP - 5
	var info2 := DiceGame.prize_for(3)
	main._on_dice_prize(info2)
	check(info2.granted == 5 and main.run.dice_claridad == RunState.DICE_CAP, "la claridad de los dados tiene tope por partida")
	var info3 := DiceGame.prize_for(4)
	var before: int = main.run.claridad
	main._on_dice_prize(info3)
	check(info3.granted == 0 and main.run.claridad == before and Profile.luz() == 3, "con el tope lleno ya no da claridad, pero la Luz se da igual")
	check(str(info3.cosmetic_name) != "" and Cosmetics.get_cosmetic(Profile.owned_cosmetics()[0]).rarity in ["comun", "raro"], "4 aciertos dan un cosmetico comun o raro")
	check(RunState.from_dict(JSON.parse_string(JSON.stringify(main.run.to_dict()))).dice_claridad == RunState.DICE_CAP, "el tope se guarda con el run")
	# cosmetico
	var info5 := DiceGame.prize_for(5)
	main._on_dice_prize(info5)
	check(str(info5.cosmetic_name) != "" and Profile.owned_cosmetics().size() == 2 and str(info5.cosmetic_rarity) in ["raro", "epico"] and Profile.luz() == 8, "5 aciertos: Luz y un cosmetico raro o epico")
	for c in Cosmetics.ALL:
		Profile.grant_cosmetic(c.id)
	var info6 := DiceGame.prize_for(5)
	var before6: int = main.run.claridad
	main._on_dice_prize(info6)
	check(not info6.has("cosmetic_name") and info6.granted == 100 and main.run.claridad == before6 + 100, "si ya los tiene todos, da claridad en su lugar")
	# el aspecto elegido se ve en el personaje de la torre
	Profile.equip("copa")
	main.restart()
	check(main._model.get_node_or_null("gorro") != null and main._model.get_node_or_null("prenda") == null, "el personaje de la torre lleva el gorro elegido")
	Profile.equip("chaleco")
	main.restart()
	check(main._model.get_node_or_null("gorro") != null and main._model.get_node_or_null("prenda") != null, "y tambien la prenda")
	Profile.unequip("gorro")
	main.restart()
	check(main._model.get_node_or_null("gorro") == null and main._model.get_node_or_null("prenda") != null, "al sacar el gorro queda sin el")
	# y en el casino
	main.enter_casino()
	check(main.casino.model.get_node_or_null("prenda") != null and main.casino.model.get_node_or_null("gorro") == null, "tambien el del casino")
	main._cancel_jobs()
	main.queue_free()
	await process_frame
	Profile.reset()


## La pantalla de carga: aparece si la generacion tarda, se cierra cuando la torre esta lista, y nunca se ve si es instantanea.
func test_loading_screen() -> void:
	var main := make_main()
	await wait_tower(main)
	main.dice.fast = false
	main.dice.auto_start = false   # como en el juego de verdad: hay que apretar Empezar
	# Una generacion lenta (simulada con un hilo que espera)
	var th := Thread.new()
	th.start(func() -> Dictionary:
		OS.delay_msec(1900)
		return {"ok": true})
	var job := {"stage": 3, "thread": th, "t0": Time.get_ticks_msec(), "done": false}
	var was_open := false
	var first_frame_open := false
	var banner_empty := true
	var button_gray_while_loading := true
	var spiral_while_loading := false
	main._await_job(job)   # (sin esperar: lo vamos mirando cuadro a cuadro)
	var frames := 0
	while th.is_alive() and frames < 600:
		await process_frame
		frames += 1
		banner_empty = banner_empty and main.banner.text == ""
		if main.dice.visible:
			was_open = true
			if frames <= 3:
				first_frame_open = true
			button_gray_while_loading = button_gray_while_loading and (main.dice.tower_ready or main.dice.start_button.disabled)
			spiral_while_loading = spiral_while_loading or main.dice.start_button.get_node("espiral").visible
	check(was_open and first_frame_open, "si hay que esperar, se abre directo con los dados (a los pocos cuadros)")
	check(banner_empty, "sin ningun cartel de Generando la torre antes ni durante: sólo los dados")
	check(button_gray_while_loading and spiral_while_loading, "mientras se genera, Empezar esta gris y con la espiral de carga")
	check(main.dice.start_button.text == "Empezar" and main.dice.start_button.position.x + main.dice.start_button.size.x > 0.0, "el boton dice Empezar")
	# La torre esta lista: el minijuego NO se cierra solo; se habilita Empezar y desaparece la espiral
	for i in 20:
		await process_frame
	check(main.dice.visible and main.dice.tower_ready and not main.dice.start_button.disabled, "cuando la torre esta lista el minijuego sigue y Empezar se habilita")
	check(not main.dice.start_button.get_node("espiral").visible, "la espiral de carga desaparece")
	check(main.generating == main.generating and main.dice.status_label.text.contains("lista"), "el aviso dice que la torre esta lista")
	# Se puede seguir jugando mientras tanto
	main.dice.throw_dice()
	check(main.dice.phase == main.DiceGame.Phase.ROLLING and main.dice.visible, "se puede tirar aunque la torre este lista")
	# Apretar Empezar con un tiro en curso: el tiro termina y recien ahi se cierra
	main.dice.start_button.pressed.emit()
	check(main.dice.visible and main.dice.closing, "Empezar durante un tiro espera a que termine")
	var guard := 0
	while main.dice.visible and guard < 3000:
		await process_frame
		guard += 1
	check(not main.dice.visible and main.dice.throws_left == 2, "al terminar el tiro se cierra y se sigue (el tiro se jugo entero)")
	main._jobs.erase(job)
	# Y Empezar sin tiro en curso cierra al instante
	var th3 := Thread.new()
	th3.start(func() -> Dictionary:
		OS.delay_msec(1500)
		return {"ok": true})
	var job3 := {"stage": 3, "thread": th3, "t0": Time.get_ticks_msec() - 2000, "done": false}   # (ya paso la demora: abre enseguida)
	main._await_job(job3)
	frames = 0
	while th3.is_alive() and frames < 600:
		await process_frame
		frames += 1
	for i in 10:
		await process_frame
	check(main.dice.visible and not main.dice.start_button.disabled, "otra carga: queda esperando que aprietes Empezar")
	main.dice.start_button.pressed.emit()
	await process_frame
	check(not main.dice.visible, "Empezar sin tiro en curso cierra y se sigue")
	main._jobs.erase(job3)
	# La generacion usa varios hilos: gana la primera semilla que sale y frena a las demas
	var job4: Dictionary = main._start_job(6, 4242)
	check(job4.has("threads") and job4.threads.size() == main._gen_thread_count() and main._gen_thread_count() >= 1 and main._gen_thread_count() <= main.MAX_GEN_THREADS, "un trabajo de generacion usa varios hilos (%d)" % job4.threads.size())
	var wait_frames := 0
	while main._job_alive(job4) and wait_frames < 6000:
		await process_frame
		wait_frames += 1
	var gen_res: Dictionary = main._job_join(job4)
	main._jobs.erase(job4)
	check(gen_res.ok and gen_res.logic != null and gen_res.logic.goal_y > 2, "sale una torre")
	var seed_ok := false
	for k in main._gen_thread_count():
		seed_ok = seed_ok or gen_res.seed_used == 4242 + k * 7919
	check(seed_ok, "con la semilla de uno de los hilos (%d)" % gen_res.seed_used)
	check(job4.token[0] == true or job4.threads.size() == 1, "al salir una torre se frena a los otros hilos")
	# Un testigo de cancelacion detiene la generacion de esa semilla (sin tocar la bandera global)
	var Gen := preload("res://scripts/tower_gen.gd")
	var stop_token := [true]
	var stopped: Dictionary = Gen.generate_stage(7, 8, 0.4, {"tries": 4, "cancel_token": stop_token})
	check(not stopped.ok and not Gen.cancel, "con el testigo en true la generacion se corta y la bandera global queda apagada")
	# Una generacion instantanea: ni se ve
	var th2 := Thread.new()
	th2.start(func() -> Dictionary: return {"ok": true})
	var job2 := {"stage": 3, "thread": th2, "t0": Time.get_ticks_msec(), "done": false}
	OS.delay_msec(120)
	var saw := false
	main._await_job(job2)
	for i in 5:
		await process_frame
		saw = saw or main.dice.visible
	check(not saw, "si la torre ya estaba generada no se ve el minijuego")
	if th2.is_started():
		th2.wait_to_finish()
	# Volver al menu con los dados abiertos los cierra
	main.dice.open()
	main.open_main_menu()
	check(not main.dice.visible, "volver al menu cierra los dados")
	main._cancel_jobs()
	main.queue_free()
	await process_frame


func test_cosmetics_screen() -> void:
	Profile.reset()
	var main := make_main()
	await wait_tower(main)
	main.open_main_menu()
	var mm = main.main_menu
	check(mm.buttons.has("cosmeticos"), "el menu tiene el boton Cosmeticos")
	mm.buttons["cosmeticos"].pressed.emit()
	var cs = mm.cosmetics
	check(cs.visible and cs.tab == "personajes" and cs.tiles.size() == 4 and cs.tiles["gato"].owned and cs.tiles["gato"].equipped and not cs.tiles["perro"].owned, "la pantalla empieza en Personajes: solo el gatito esta disponible y elegido")
	check(cs.count_label.text.contains("Común 0/") and cs.count_label.text.contains("Raro 0/") and cs.count_label.text.contains("Épico 0/"), "dice cuantos se tienen de cada rareza")
	cs.tiles["perro"].pressed.emit()
	check(Profile.character() == "gato", "un personaje que no se tiene no se puede elegir")
	Profile.unlock_character("perro")
	cs.refresh()
	cs.tiles["perro"].pressed.emit()
	check(Profile.character() == "perro" and cs.tiles["perro"].equipped and not cs.tiles["gato"].equipped, "un personaje desbloqueado se elige con un clic")
	check(cs.name_label.text.contains("Perrito"), "y su nombre se muestra")
	cs.set_tab("gorros")
	check(cs.tiles.size() == Cosmetics.by_slot("gorro").size() + 1 and cs.tiles.has("") and cs.tiles[""].equipped and not cs.tiles["copa"].owned, "la solapa Gorros muestra 'sin gorro' y los gorros")
	cs.tiles["copa"].pressed.emit()
	check(Profile.equipped_hat() == "", "un gorro que no se tiene no se puede poner")
	Profile.grant_cosmetic("copa")
	cs.refresh()
	cs.tiles["copa"].pressed.emit()
	check(Profile.equipped_hat() == "copa" and cs.tiles["copa"].equipped and not cs.tiles[""].equipped, "un gorro ganado se pone con un clic")
	check(cs.name_label.text.contains("Sombrero de copa") and cs.count_label.text.contains("Raro 1/"), "el nombre muestra lo que lleva y se cuenta por rareza (la copa es rara)")
	cs.tiles["copa"].pressed.emit()
	check(Profile.equipped_hat() == "", "tocar el que llevas lo saca")
	cs.set_tab("ropa")
	Profile.grant_cosmetic("bufanda")
	cs.refresh()
	cs.tiles["bufanda"].pressed.emit()
	check(Profile.equipped_outfit() == "bufanda" and Profile.equipped_hat() == "", "la ropa va aparte del gorro")
	cs.tiles[""].pressed.emit()
	check(Profile.equipped_outfit() == "", "'sin prenda' la saca")
	cs.back.emit()
	check(mm.main_center.visible and not cs.visible, "Volver regresa al menu")
	main._cancel_jobs()
	main.queue_free()
	await process_frame
	Profile.reset()


func test_trap() -> void:
	Profile.path = "user://test_profile.json"
	Profile.reset()
	Profile.add_luz(30)
	var g := DiceGame.new()
	root.add_child(g)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	g.open(rng)
	var got := []
	g.prize.connect(func(info): got.append(info.duplicate(true)))
	g.picks = [1, 2, 3, 4, 5]
	g.rolls = [1, 2, 6, 6, 6]
	g.revealed = 5
	g.throws_left = 2
	g.phase = DiceGame.Phase.REVEAL
	g._after_reveal()
	check(g.phase == DiceGame.Phase.FIX and g.misses() == [2, 3, 4] and g.hits() == 2, "con Luz, tras ver el tiro se puede elegir qué volver a tirar")
	check(g.marked == [false, false, true, true, true] and g.marks_count() == 3 and g.reroll_cost() == 3 and g.rerolls_left == DiceGame.MAX_REROLLS, "por defecto se marcan todos los que fallaron (1 de Luz cada uno)")
	check(g.throw_button.text.contains("Tirar de nuevo") and g.throw_button.text.contains("3") and not g.throw_button.disabled and g.collect_button.visible, "el boton pasa a Tirar de nuevo con su costo y aparece Cobrar")
	check(g.toggle_mark(3) and not g.marked[3] and g.reroll_cost() == 2, "tocar un dado marcado lo retiene (cuesta menos volver a tirar)")
	check(not g.toggle_mark(0) and not g.marked[0], "un dado que ya acerto no se marca: queda retenido solo")
	check(g.can_reroll() and g.reroll(), "se vuelve a tirar")
	check(Profile.luz() == 28 and g.luz_spent == 2 and g.rerolls_left == 1 and g.phase == DiceGame.Phase.ROLLING and g.reroll_round, "se pagan 2 de Luz (1 por dado) y queda una re-tirada")
	check(g.unrevealed == [2, 4] and g.rolls[0] == 1 and g.rolls[1] == 2 and g.rolls[3] == 6, "sólo ruedan los marcados: los demas quedan como estaban")
	check(g._is_revealed(0) and g._is_revealed(3) and not g._is_revealed(2) and not g._is_revealed(4), "mientras ruedan, los retenidos siguen a la vista y los marcados no")
	# se fuerza el resultado de los dos que volvieron a rodar: uno acierta y el otro no (el dado 4 tiene 5 pedido)
	g.rolls[2] = 3
	g.rolls[4] = 1
	g._phase_t = DiceGame.ROLL_TIME
	g._process(0.0)
	check(g.phase == DiceGame.Phase.REVEAL, "después de rodar se revelan de a uno")
	g._phase_t = DiceGame.REVEAL_STEP * 3.0
	g._process(0.0)
	check(g.unrevealed.is_empty() and g.revealed == 5, "se revelan los dos")
	g._phase_t = DiceGame.REVEAL_STEP * 2.5
	g._process(0.0)
	check(g.phase == DiceGame.Phase.FIX and g.hits() == 3 and g.marked == [false, false, false, true, true], "si todavia fallan y quedan re-tiradas y Luz, se vuelve a elegir (por defecto los que fallaron)")
	check(g.reroll() and Profile.luz() == 26 and g.rerolls_left == 0 and g.luz_spent == 4, "la segunda re-tirada cuesta 2 mas y es la ultima")
	g.rolls[3] = 4
	g.rolls[4] = 5
	g._phase_t = DiceGame.ROLL_TIME
	g._process(0.0)
	g._phase_t = DiceGame.REVEAL_STEP * 3.0
	g._process(0.0)
	g._phase_t = DiceGame.REVEAL_STEP * 2.5
	g._process(0.0)
	check(g.phase == DiceGame.Phase.RESULT and got.size() == 1 and got[0].hits == 5 and got[0].luz_spent == 4 and got[0].luz == 5, "con los cinco acertados se cobra solo el premio de los 5 aciertos")
	# sin re-tiradas no hay mas eleccion: se cobra
	Profile.reset()
	Profile.add_luz(30)
	g.open(rng)
	g.picks = [1, 2, 3, 4, 5]
	g.rolls = [6, 6, 6, 6, 6]
	g.revealed = 5
	g.rerolls_left = 0
	g.phase = DiceGame.Phase.REVEAL
	got.clear()
	g._after_reveal()
	check(g.phase == DiceGame.Phase.RESULT and got.size() == 1, "sin re-tiradas disponibles se cobra enseguida")
	# sin Luz suficiente: no se puede marcar ni volver a tirar, y se cobra solo
	Profile.reset()
	g.open(rng)
	g.picks = [1, 2, 3, 4, 5]
	g.rolls = [6, 6, 6, 6, 6]
	g.revealed = 5
	g.phase = DiceGame.Phase.REVEAL
	got.clear()
	g._after_reveal()
	check(g.phase == DiceGame.Phase.RESULT and got.size() == 1, "sin Luz se cobra enseguida")
	# con poca Luz, por defecto se marcan sólo los que alcanzan
	Profile.add_luz(2)
	g.open(rng)
	g.picks = [1, 2, 3, 4, 5]
	g.rolls = [6, 6, 6, 6, 6]
	g.revealed = 5
	g.phase = DiceGame.Phase.REVEAL
	g._after_reveal()
	check(g.phase == DiceGame.Phase.FIX and g.marks_count() == 2 and g.reroll_cost() == 2, "con 2 de Luz se marcan 2 dados (los que alcanzan)")
	var third := g.misses()[2]
	check(not g.toggle_mark(third) and not g.marked[third], "no se puede marcar uno más que la Luz")
	# teclado: A y D eligen un dado que falló, W lo marca o lo suelta, Enter vuelve a tirar, C cobra
	var k := InputEventKey.new()
	k.pressed = true
	g.selected = 0
	k.keycode = KEY_D
	g._unhandled_input(k)
	check(g.selected in g.misses(), "el teclado elige entre los dados que fallaron")
	g.selected = g.misses()[0]
	var was: bool = g.marked[g.selected]
	k.keycode = KEY_W
	g._unhandled_input(k)
	check(g.marked[g.selected] != was, "W marca o suelta el dado elegido")
	k.keycode = KEY_ENTER
	var luz_before := Profile.luz()
	g._unhandled_input(k)
	check(g.phase == DiceGame.Phase.ROLLING and Profile.luz() < luz_before, "Enter vuelve a tirar los marcados")
	# C cobra; y el boton Empezar durante la eleccion cobra lo que hay
	Profile.add_luz(10)
	g.open(rng)
	g.picks = [1, 2, 3, 4, 5]
	g.rolls = [6, 6, 6, 6, 6]
	g.revealed = 5
	g.phase = DiceGame.Phase.REVEAL
	g._after_reveal()
	got.clear()
	k.keycode = KEY_C
	g._unhandled_input(k)
	check(g.phase == DiceGame.Phase.RESULT and got.size() == 1 and got[0].hits == 0, "C cobra lo que hay")
	g.open(rng)
	g.picks = [1, 2, 3, 4, 5]
	g.rolls = [6, 6, 6, 6, 6]
	g.revealed = 5
	g.phase = DiceGame.Phase.REVEAL
	g._after_reveal()
	got.clear()
	g.request_close()
	check(got.size() == 1 and g.closing, "si pedis empezar mientras elegis, se cobra y despues se cierra")
	g.queue_free()
	Profile.reset()


func test_white_dice() -> void:
	for c in DiceGame.DIE_COLORS:
		check(c == Color.WHITE, "todos los dados son blancos")
	check(DiceGame.DIE_COLORS.size() == DiceGame.DICE, "hay un color por dado")
