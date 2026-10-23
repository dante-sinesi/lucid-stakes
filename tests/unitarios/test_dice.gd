extends SceneTree
## Pruebas de los dados de la pantalla de carga (el minijuego), sus premios, los cosméticos y cómo se enganchan al juego.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_dice.gd

const DiceGame := preload("res://scripts/casino/dice_game.gd")
const Cosmetics := preload("res://scripts/personajes/cosmetics.gd")
const Profile := preload("res://scripts/datos/profile.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Loc := preload("res://scripts/idioma/loc.gd")

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
	test_hold()
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
	while main.generating or main.torre == null:
		await process_frame


func test_prizes() -> void:
	check(DiceGame.prize_for(0).claridad == 0 and DiceGame.prize_for(1).claridad == 0 and DiceGame.prize_for(2).claridad == 8, "premios: con 0 o 1 acierto nada, con 2 +8 de claridad")
	check(DiceGame.prize_for(0).luz == 0 and DiceGame.prize_for(1).luz == 0 and DiceGame.prize_for(2).luz == 0, "con 2 aciertos o menos no hay Luz")
	var three := DiceGame.prize_for(3)
	check(three.claridad == 25 and three.luz == 0 and three.cosmetic.is_empty(), "3 aciertos: claridad, sin Luz ni cosmetico")
	var four := DiceGame.prize_for(4)
	check(four.claridad == 80 and four.luz == 0 and four.cosmetic.has("comun") and four.cosmetic.has("raro") and not four.cosmetic.has("epico") and four.cosmetic.comun > four.cosmetic.raro, "4 aciertos: Luz y un cosmetico comun (a veces raro)")
	check(is_equal_approx(float(four.cosmetic_chance), 0.15), "con 4 aciertos el cosmetico sale con 15 % de chance")
	var five := DiceGame.prize_for(5)
	check(five.luz == 0 and five.claridad == 150 and five.cosmetic.has("raro") and five.cosmetic.has("epico") and not five.cosmetic.has("comun") and five.cosmetic.raro > five.cosmetic.epico, "5 aciertos: mas Luz y un cosmetico raro (a veces epico)")
	check(is_equal_approx(float(five.cosmetic_chance), 1.0), "con 5 aciertos el cosmetico es seguro")
	check(DiceGame.prize_for(-3).claridad == 0 and DiceGame.prize_for(99).luz == 0, "los aciertos fuera de rango se acotan")
	for n in 6:
		check(DiceGame.LINES.has(n) and DiceGame.LINES[n].size() >= 3, "el tabernero tiene varias frases para %d aciertos" % n)
	check(DiceGame.THROWS == 3 and DiceGame.DICE == 5, "una predicción de 5 dados y 3 tiradas para cumplirla")
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
	check(g.visible and g.phase == DiceGame.Phase.PICK and g.throws_left == 3 and g.can_throw(), "al abrir hay 3 tiradas y se puede elegir")
	for i in 5:
		check(g.picks[i] >= 1 and g.picks[i] <= 6, "la cara elegida del dado %d esta entre 1 y 6" % i)
	g.set_pick(0, 6)
	g.cycle_pick(0, 1)
	check(g.picks[0] == 1, "del 6 se pasa al 1 (con vuelta)")
	g.cycle_pick(0, -1)
	check(g.picks[0] == 6, "y del 1 al 6")
	g.set_pick(2, 99)
	check(g.picks[2] == 6, "la cara se acota a 6")
	# con una predicción y 3 tiradas (fast: se resuelven todas de golpe): los acertados se retienen y sólo se vuelven a tirar los que fallaron
	var got := []
	g.prize.connect(func(info): got.append(info.duplicate()))
	g.throw_dice()
	check(got.size() == 1 and g.phase == DiceGame.Phase.RESULT, "se tira, se resuelve y se muestra el resultado (un solo premio por carga)")
	check(g.throws_left == 0 or g.hits() == 5, "se usan las 3 tiradas, salvo que se acierten los 5 antes")
	var expected := 0
	for i in 5:
		check(g.rolls[i] >= 1 and g.rolls[i] <= 6, "el dado %d salio entre 1 y 6" % i)
		if g.rolls[i] == g.picks[i]:
			expected += 1
	check(got[0].hits == expected and g.hits() == expected, "los aciertos cuentan los dados que salieron como se pidio")
	check(not g.can_throw() and g.throw_button.disabled, "mientras se muestra el resultado no se puede tirar")
	# Forzar 4 y 5 aciertos
	for i in 5:
		g.rolls[i] = g.picks[i]
	check(g.hits() == 5, "si todos coinciden son 5 aciertos")
	g.rolls[4] = g.picks[4] % 6 + 1
	check(g.hits() == 4, "uno distinto son 4")
	# no hay una segunda carga de premio ni una cuarta tirada
	g.phase = DiceGame.Phase.PICK
	g.throws_left = 0
	g.throw_dice()
	check(got.size() == 1 and not g.can_throw(), "no hay una tirada más después de las 3")
	# Cerrar
	var closed_count := [0]
	g.closed.connect(func(): closed_count[0] += 1)
	g.phase = DiceGame.Phase.DONE
	g.request_close()
	check(not g.visible and closed_count[0] == 1, "terminados los tiros se cierra")
	# Se vuelve a abrir con tiros nuevos
	g.open(rng)
	check(g.throws_left == 3 and g.total_claridad == 0 and g.visible, "cada carga empieza con una predicción nueva y 3 tiradas")
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
	check(h.visible and not h.closing, "no se puede cerrar durante un tiro: jugar es obligatorio")
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
	check(h.visible and not h.closing, "al terminar el tiro los dados siguen abiertos hasta que se aprieta Empezar")
	h.queue_free()
	await process_frame


## Probabilidades: cada dado se acierta con 1/6 por tirada y, con 3 tiradas y los aciertos retenidos, con 1 - (5/6)^3 = 42 %.
func test_odds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var counts := [0, 0, 0, 0, 0, 0]
	var n := 30000
	var claridad := 0
	var cosmetics := 0
	for t in n:
		var hits := 0
		for i in 5:
			for throw in 3:
				if rng.randi() % 6 == 0:
					hits += 1
					break
		counts[hits] += 1
		claridad += int(DiceGame.prize_for(hits).claridad)
		if hits == 5 or (hits == 4 and rng.randf() < 0.15):
			cosmetics += 1
	check(absf(counts[0] / float(n) - 0.065) < 0.01 and absf(counts[2] / float(n) - 0.344) < 0.02 and absf(counts[4] / float(n) - 0.091) < 0.012, "la distribucion de aciertos es la esperada (%s)" % str(counts))
	check(counts[5] / float(n) > 0.008 and counts[5] / float(n) < 0.02, "acertar los 5 pasa ~1,3 %% de las veces (%d en %d)" % [counts[5], n])
	var rate := cosmetics / float(n)
	check(rate > 0.015 and rate < 0.035, "un cosmetico sale en ~2,7 %% de las cargas (%.3f)" % rate)
	var avg := claridad / float(n)
	check(avg > 14.0 and avg < 22.0, "el promedio de claridad por carga es ~18 (%.2f)" % avg)


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
	info3["cosmetic_chance"] = 1.0   # (acá se prueba el cosmético: en el juego sale con 15 % de chance)
	var before: int = main.run.claridad
	main._on_dice_prize(info3)
	check(Profile.luz() == 0 and Profile.owned_cosmetics().is_empty() and main.run.dice_pending.cosmetics.size() == 1, "los dados dejan el cosmético pendiente: no pasan al perfil hasta superar una torre")
	main._claim_dice_rewards()
	check(main.run.dice_pending.luz == 0 and main.run.dice_pending.cosmetics.is_empty(), "al reclamarlos el run queda sin pendientes")
	check(info3.granted == 0 and main.run.claridad == before and Profile.luz() == 0, "con el tope lleno ya no da claridad (y los dados no dan Luz)")
	check(str(info3.cosmetic_name) != "" and Cosmetics.get_cosmetic(Profile.owned_cosmetics()[0]).rarity in ["comun", "raro"], "4 aciertos dan un cosmetico comun o raro")
	check(RunState.from_dict(JSON.parse_string(JSON.stringify(main.run.to_dict()))).dice_claridad == RunState.DICE_CAP, "el tope se guarda con el run")
	# cosmetico
	var info5 := DiceGame.prize_for(5)
	main._on_dice_prize(info5)
	main._claim_dice_rewards()
	check(str(info5.cosmetic_name) != "" and Profile.owned_cosmetics().size() == 2 and str(info5.cosmetic_rarity) in ["comun", "raro"] and Profile.luz() == 0, "5 aciertos en Medio: un cosmetico comun o raro (los dados no dan Luz)")
	for c in Cosmetics.ALL:
		Profile.grant_cosmetic(c.id)
	var info6 := DiceGame.prize_for(5)
	var before6: int = main.run.claridad
	main._on_dice_prize(info6)
	main._claim_dice_rewards()
	check(not info6.has("cosmetic_name") and info6.granted == 100 and main.run.claridad == before6 + 100, "si ya los tiene todos, da claridad en su lugar")
	# el aspecto elegido se ve en el personaje de la torre
	Profile.equip("copa")
	main.restart()
	check(main.torre.gato.get_node_or_null("gorro") != null and main.torre.gato.get_node_or_null("prenda") == null, "el personaje de la torre lleva el gorro elegido")
	Profile.equip("chaleco")
	main.restart()
	check(main.torre.gato.get_node_or_null("gorro") != null and main.torre.gato.get_node_or_null("prenda") != null, "y tambien la prenda")
	Profile.unequip("gorro")
	main.restart()
	check(main.torre.gato.get_node_or_null("gorro") == null and main.torre.gato.get_node_or_null("prenda") != null, "al sacar el gorro queda sin el")
	# y en el casino
	main.enter_casino()
	check(main.casino.model.get_node_or_null("prenda") != null and main.casino.model.get_node_or_null("gorro") == null, "tambien el del casino")
	Profile.reset()
	var no_cosmetic := 0
	for k in 40:
		var info4 := DiceGame.prize_for(4)
		main._on_dice_prize(info4)
		if not info4.has("cosmetic_name"):
			no_cosmetic += 1
	check(no_cosmetic > 20 and no_cosmetic < 40, "con 4 aciertos el cosmetico sale solo a veces (%d de 40 sin cosmetico)" % no_cosmetic)
	main.queue_free()
	await process_frame
	Profile.reset()


## Juega las tiradas que queden hasta terminar (acierte o no).
func _play_out(d) -> void:
	var guard := 0
	while d.visible and not (d.phase == d.Phase.RESULT or d.phase == d.Phase.DONE) and guard < 4000:
		if d.can_throw():
			d.throw_dice()
		await process_frame
		guard += 1


## La pantalla de carga: al empezar cada torre aparecen los dados del tabernero (con Empezar habilitado al terminar las tiradas) y Empezar entra a la torre.
func test_loading_screen() -> void:
	var main := make_main()
	await wait_tower(main)
	main.dice.fast = false
	main.dice.auto_start = false   # como en el juego de verdad: hay que apretar Empezar
	main.dice_always = true
	main.new_tower(4242)   # (sin esperar: se mira cuadro a cuadro)
	for i in 6:
		await process_frame
	check(main.dice.visible and main.dice.tower_ready and not main.dice.start_button.visible, "al empezar la torre se abren los dados y hay que jugarlos (todavía no hay botón Empezar)")
	check(main.banner.text == "" and main.dice.status_label.text == "", "sin ningún cartel de la torre: sólo los dados")
	main.dice.request_close()
	check(main.dice.visible and not main.dice.closing, "no se puede saltear el juego")
	await _play_out(main.dice)
	check(main.dice.start_button.visible and not main.dice.start_button.disabled and not main.dice.start_button.get_node("espiral").visible, "terminadas las tiradas: Empezar listo para apretar")
	check(main.dice.start_button.text == "Empezar" and main.dice.start_button.position.x + main.dice.start_button.size.x > 0.0, "el botón dice Empezar")
	main.dice.start_button.pressed.emit()
	for i in 4:
		await process_frame
	check(not main.dice.visible and main.torre != null and main.torre.semilla == 4242, "Empezar cierra los dados y se entra a la torre")
	main.dice_always = false
	# Volver al menú con los dados abiertos los cierra
	main.dice.open()
	main.open_main_menu()
	check(not main.dice.visible, "volver al menú cierra los dados")
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
	check(cs.visible and cs.tab == "personajes" and cs.tiles.size() == 5 and cs.tiles["gato"].owned and cs.tiles["gato"].equipped and cs.tiles["dante"].owned and cs.tiles["gaby"].owned and cs.tiles["perro"].owned, "la pantalla empieza en Personajes: el gatito (elegido), Dante, Gaby y el perrito disponibles")
	check(cs.count_label.text.contains("Común 0/") and cs.count_label.text.contains("Raro 0/") and cs.count_label.text.contains("Épico 0/"), "dice cuantos se tienen de cada rareza")
	Profile.unlock_character("conejo")
	cs.refresh()
	cs.tiles["conejo"].pressed.emit()
	check(Profile.character() == "conejo" and cs.tiles["conejo"].equipped and not cs.tiles["gato"].equipped, "un personaje desbloqueado se elige con un clic")
	check(cs.name_label.text.contains("Conejito"), "y su nombre se muestra")
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
	main.queue_free()
	await process_frame
	Profile.reset()


func test_hold() -> void:
	Profile.path = "user://test_profile.json"
	Profile.reset()
	var g := DiceGame.new()
	root.add_child(g)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	g.open(rng)
	var got := []
	g.prize.connect(func(info): got.append(info.duplicate(true)))
	g.picks = [1, 2, 3, 4, 5]
	g.throw_dice()
	check(g.phase == DiceGame.Phase.ROLLING and g.throws_left == 2 and g.unrevealed.size() == 5 and not g.reroll_round, "la primera tirada rueda los 5 dados")
	# se fuerza el resultado: acierta el 1 y el 2
	g.rolls = [1, 2, 6, 6, 6]
	g._phase_t = DiceGame.ROLL_TIME
	g._process(0.0)
	g._phase_t = DiceGame.REVEAL_STEP * 6.0
	g._process(0.0)
	check(g.phase == DiceGame.Phase.HOLD and g.hits() == 2 and g.misses() == [2, 3, 4], "con tiradas por delante, los acertados quedan retenidos y se espera la próxima tirada")
	check(g.throw_button.text.contains("Tirar de nuevo") and not g.throw_button.disabled and g.can_throw(), "el botón pasa a Tirar de nuevo")
	check(g.message.contains("2 tiradas") and g.message.contains("Verdes"), "el mensaje explica que los verdes quedan retenidos")
	g.picks = [1, 2, 3, 4, 5]
	g.throw_dice()
	check(g.phase == DiceGame.Phase.ROLLING and g.throws_left == 1 and g.reroll_round, "la segunda tirada gasta una tirada")
	check(g.unrevealed == [2, 3, 4] and g.rolls[0] == 1 and g.rolls[1] == 2, "sólo ruedan los que fallaron: los acertados quedan como estaban")
	check(g._is_revealed(0) and g._is_revealed(1) and not g._is_revealed(2) and not g._is_revealed(4), "mientras ruedan, los retenidos siguen a la vista y los demás no")
	# resultado forzado: acierta el 3
	g.rolls = [1, 2, 3, 6, 6]
	g._phase_t = DiceGame.ROLL_TIME
	g._process(0.0)
	g._phase_t = DiceGame.REVEAL_STEP * 5.0
	g._process(0.0)
	check(g.phase == DiceGame.Phase.HOLD and g.hits() == 3 and g.throws_left == 1 and g.message.contains("última"), "queda una tirada: el aviso dice que es la última")
	# teclado: Enter tira de nuevo
	var k := InputEventKey.new()
	k.pressed = true
	k.keycode = KEY_ENTER
	g._unhandled_input(k)
	check(g.phase == DiceGame.Phase.ROLLING and g.throws_left == 0, "Enter tira de nuevo los que fallaron")
	g.rolls = [1, 2, 3, 6, 6]   # no aciertan
	g._phase_t = DiceGame.ROLL_TIME
	g._process(0.0)
	g._phase_t = DiceGame.REVEAL_STEP * 4.0
	g._process(0.0)
	check(g.phase == DiceGame.Phase.RESULT and got.size() == 1 and got[0].hits == 3 and got[0].luz == 0, "sin tiradas se cobra solo con lo que haya (3 aciertos)")
	g._phase_t = DiceGame.RESULT_TIME
	g._process(0.0)
	check(g.phase == DiceGame.Phase.DONE and not g.can_throw() and not g.throw_button.visible, "después del premio se terminó: una sola predicción por carga")
	# si se acierta todo antes, se cobra enseguida y quedan tiradas sin usar
	g.open(rng)
	g.picks = [1, 2, 3, 4, 5]
	g.throw_dice()
	g.rolls = [1, 2, 3, 4, 5]
	got.clear()
	g._phase_t = DiceGame.ROLL_TIME
	g._process(0.0)
	g._phase_t = DiceGame.REVEAL_STEP * 6.0
	g._process(0.0)
	check(g.phase == DiceGame.Phase.RESULT and got.size() == 1 and got[0].hits == 5 and g.throws_left == 2, "si se aciertan los 5 se cobra enseguida")
	# pedir Empezar mientras se espera la próxima tirada cobra lo que hay
	g.open(rng)
	g.picks = [1, 2, 3, 4, 5]
	g.throw_dice()
	g.rolls = [6, 6, 6, 6, 6]
	g._phase_t = DiceGame.ROLL_TIME
	g._process(0.0)
	g._phase_t = DiceGame.REVEAL_STEP * 6.0
	g._process(0.0)
	check(g.phase == DiceGame.Phase.HOLD and g.hits() == 0, "con 0 aciertos también se espera la próxima tirada")
	got.clear()
	g.request_close()
	check(got.is_empty() and not g.closing and g.phase == DiceGame.Phase.HOLD, "mientras esperas la próxima tirada no se puede empezar")
	# pedir Empezar mientras ruedan: al terminar de revelar se cobra directo (no queda esperando)
	g.open(rng)
	g.picks = [1, 2, 3, 4, 5]
	g.throw_dice()
	g.rolls = [6, 6, 6, 6, 6]
	g.request_close()
	g._phase_t = DiceGame.ROLL_TIME
	g._process(0.0)
	g._phase_t = DiceGame.REVEAL_STEP * 6.0
	g._process(0.0)
	check(g.phase == DiceGame.Phase.HOLD and not g.closing, "pedir empezar a mitad de un tiro no hace nada")
	# Espacio durante la animación la saltea
	g.open(rng)
	g.picks = [1, 2, 3, 4, 5]
	var sp := InputEventKey.new()
	sp.pressed = true
	sp.keycode = KEY_SPACE
	g._unhandled_input(sp)   # (en la elección, Espacio tira)
	check(g.phase == DiceGame.Phase.ROLLING and g.throws_left == 2, "Espacio tira los dados")
	g.rolls = [1, 2, 6, 6, 6]
	g._unhandled_input(sp)   # (rodando: se saltea)
	check(g.phase == DiceGame.Phase.HOLD and g.unrevealed.is_empty() and g.revealed == DiceGame.DICE and g.hits() == 2, "Espacio mientras ruedan saltea la animación y deja los resultados a la vista")
	g._unhandled_input(sp)
	check(g.phase == DiceGame.Phase.ROLLING and g.throws_left == 1, "Espacio tira de nuevo los que fallaron")
	g._unhandled_input(sp)
	check(g.phase == DiceGame.Phase.HOLD or g.phase == DiceGame.Phase.RESULT, "saltear también sirve en la segunda tirada")
	# la última tirada: se saltea y, con la torre lista, se entra
	g.open(rng)
	var shut := []
	g.closed.connect(func(): shut.append(true))
	g.picks = [1, 2, 3, 4, 5]
	g.throws_left = 1
	g.throw_dice()
	g.rolls = [6, 6, 6, 6, 6]
	g.set_ready(true)
	g._unhandled_input(sp)
	check(g.phase == DiceGame.Phase.RESULT and g.visible and shut.size() == 0, "Espacio en la animación de la última tirada la saltea y muestra los resultados (no entra a la torre)")
	g._unhandled_input(sp)
	check(shut.size() == 1 and not g.visible, "con los resultados a la vista, otro Espacio entra a la torre")
	# la última tirada sin la torre lista: se saltea y se espera
	g.open(rng)
	g.picks = [1, 2, 3, 4, 5]
	g.throws_left = 1
	g.throw_dice()
	g.rolls = [6, 6, 6, 6, 6]
	g._unhandled_input(sp)
	check(g.phase == DiceGame.Phase.RESULT and g.visible and shut.size() == 1, "sin la torre lista se saltea pero no se entra")
	g.set_ready(true)
	g._unhandled_input(sp)
	check(shut.size() == 2 and not g.visible, "cuando la torre está lista, Espacio entra")
	g.queue_free()
	Profile.reset()


func test_white_dice() -> void:
	var g := DiceGame.new()
	check(g.dice3d != null and g.dice3d.dice.size() == DiceGame.DICE, "hay un dado 3D por dado")
	g.free()
