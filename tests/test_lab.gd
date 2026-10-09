extends SceneTree
## Pruebas del laboratorio (modo dev): el mundo se arma bien, cada estación se comporta como dice su cartel y los comandos funcionan.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_lab.gd

const Lab := preload("res://scripts/lab.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const DevCommands := preload("res://scripts/dev_commands.gd")
const Profile := preload("res://scripts/profile.gd")
const K := TowerLogic.Kind
const E := Vector3i(1, 0, 0)
const W := Vector3i(-1, 0, 0)
const S := Vector3i(0, 0, 1)
const N := Vector3i(0, 0, -1)
const GRAB := TowerLogic.Mode.GRAB
const HANG := TowerLogic.Mode.HANG

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_world()
	test_stations()
	await test_commands()
	print("tests del laboratorio terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


## La estación `i` con el personaje en la celda (dx, y, z) (el mundo se arma de nuevo en cada llamada).
func at(_unused, i: int, dx: int, y: int, z: int):
	var t = Lab.build(i)
	t.player = Vector3i(Lab.station_x(i) + dx, y, z)
	t.last_safe = t.player
	return t


func test_world() -> void:
	check(Lab.count() == 12 and Lab.STATIONS.size() == 12, "hay doce estaciones")
	var ids := {}
	for s in Lab.STATIONS:
		ids[s.id] = true
		check(str(s.name) != "" and str(s.desc) != "", "la estacion %s tiene nombre y descripcion" % s.id)
	check(ids.size() == 12, "los ids son únicos")
	for i in Lab.count():
		var t = Lab.build(i)
		var id: String = Lab.STATIONS[i].id
		check(t.positions.size() == t.blocks.size(), "%s: no quedan bloques fantasma (%d ids, %d bloques)" % [id, t.positions.size(), t.blocks.size()])
		check(t.removed_ids.is_empty() and not t.lost and not t.won, "%s: arranca limpia" % id)
		check(t.collapse_every >= 1000, "%s: la caída de la fila de abajo está apagada" % id)
		var inside := true
		for c in t.blocks:
			inside = inside and c.x >= Lab.X0 and c.x <= Lab.X0 + 9 and c.z >= 2 and c.z <= 6 and c.y >= 0 and t.in_bounds(c)
		check(inside, "%s: ningún bloque se sale de la franja de la estación" % id)
		var s := Lab.station_start(i)
		check(t.blocks.has(s + Vector3i.DOWN) and not t.blocks.has(s), "%s: arranca parado sobre un bloque y con el lugar libre" % id)
		check(Lab.sign_for(i).text.contains(str(Lab.STATIONS[i].name).to_upper()) and Lab.sign_for(i).text.begins_with("%d." % (i + 1)), "%s: tiene su cartel" % id)
	check(Lab.index_of("3") == 2 and Lab.index_of("bomba") == 2 and Lab.index_of("BOMBA") == 2 and Lab.index_of("nope") == -1 and Lab.index_of("0") == -1 and Lab.index_of("13") == -1, "las estaciones se buscan por número o por id")
	# los tipos presentes en cada estación
	var want := {"hielo": K.ICE, "bomba": K.BOMB, "catapulta": K.CATAPULT, "agrietado": K.CRACKED, "pesado": K.HEAVY, "trampa": K.TRAP, "pinchos": K.SPIKES}
	for id in want:
		var t2 = Lab.build(Lab.index_of(id))
		var found := false
		for c in t2.blocks:
			if t2.kind_at(c) == want[id]:
				found = true
		check(found, "la estacion %s tiene bloques de su tipo" % id)


func test_stations() -> void:
	var w = null
	# --- común: empujar, y filas
	var i := Lab.index_of("comun")
	var t = at(w, i, 2, 1, 4)
	check(t.try_action(E, GRAB).ok and t.blocks.has(Vector3i(Lab.station_x(i) + 4, 1, 4)), "comun: se empuja el bloque suelto")
	t = at(w, i, 4, 1, 2)
	check(t.try_action(E, GRAB).ok and t.blocks.has(Vector3i(Lab.station_x(i) + 8, 1, 2)), "comun: la fila de 3 se empuja entera")
	t = at(w, i, 2, 1, 6)
	check(not t.try_action(E, GRAB).ok, "comun: la fila de 4 no entra")
	# --- hielo: resbalar hasta el vacío
	i = Lab.index_of("hielo")
	t = at(w, i, 1, 1, 4)
	t.try_action(E)
	check(t.lost and t.lost_reason == "Caíste al vacío", "hielo: el carril de hielo te hace resbalar hasta caer al vacio")
	# --- bomba: justo, con un movimiento de más y con la que no llegás
	i = Lab.index_of("bomba")
	t = at(w, i, 1, 1, 4)
	for d in [E, E, E]:
		t.try_action(d)
	check(not t.lost and t.player.y == 2 and t.bomb_timer.size() == 1, "bomba: con los tres movimientos justos se desactiva")
	t = at(w, i, 1, 1, 4)
	for d in [E, W, E, E]:
		t.try_action(d)
	check(t.lost and t.exploded and t.explosion_cell == Vector3i(Lab.station_x(i) + 4, 1, 4), "bomba: un movimiento de más y explota")
	# --- catapulta: al alcance, una celda más arriba y fuera de alcance
	i = Lab.index_of("catapulta")
	for lane in [[2, 5, true], [4, 7, true], [6, 10, false]]:
		t = at(w, i, 1, 1, lane[0])
		t.try_action(E)
		if lane[2]:
			check(t.hang_dir == E and t.player.y == 1 + 4 + (0 if lane[1] == 5 else 2), "catapulta: la pared de %d tiene un borde al alcance (y=%d)" % [lane[1], t.player.y])
		else:
			check(t.hang_dir == Vector3i.ZERO and t.player.y == 1, "catapulta: la pared de %d queda fuera de alcance y volves a caer" % lane[1])
	# --- agrietado: no hay vuelta atrás
	i = Lab.index_of("agrietado")
	t = at(w, i, 2, 1, 4)
	t.try_action(E)
	t.try_action(E)
	check(not t.lost and not t.blocks.has(Vector3i(Lab.station_x(i) + 3, 0, 4)) and not t.try_action(W).ok, "agrietado: el primero se rompe al bajarte y no se puede volver")
	# --- pesado: no se empuja, salvo con Fuerza bruta; el pilar no se trepa
	i = Lab.index_of("pesado")
	t = at(w, i, 2, 1, 4)
	check(not t.try_action(E, GRAB).ok, "pesado: no se empuja")
	t.perks["fuerza_bruta"] = true
	check(t.try_action(E, GRAB).ok, "pesado: con Fuerza bruta si")
	t = at(w, i, 4, 1, 4)
	check(not t.try_action(E).ok, "pesado: el pilar de dos de alto no se trepa")
	# --- trampa: un carril cede, el otro no
	i = Lab.index_of("trampa")
	t = at(w, i, 1, 1, 4)
	for d in [E, E, E]:
		t.try_action(d)
	check(t.lost and t.trap_broke, "trampa: el carril de la cruz roja cede")
	t = at(w, i, 1, 1, 3)
	for k in 6:
		t.try_action(E)
	check(not t.lost and t.player.x == Lab.station_x(i) + 7, "trampa: el otro carril es seguro")
	# --- pinchos: empujar la fila [normal, pinchos]; subirse pierde
	i = Lab.index_of("pinchos")
	t = at(w, i, 3, 1, 4)
	check(t.try_action(E, GRAB).ok and t.kind_at(Vector3i(Lab.station_x(i) + 6, 1, 4)) == K.SPIKES, "pinchos: la fila [normal, pinchos] se empuja junta")
	t = at(w, i, 6, 1, 2)
	t.try_action(E)
	check(t.lost and t.lost_reason == "Caíste sobre los pinchos", "pinchos: subirse pierde")
	# --- fila: la fila de 2 entra en el corredor
	i = Lab.index_of("fila")
	t = at(w, i, 2, 1, 4)
	check(t.try_action(E, GRAB).ok and t.blocks.has(Vector3i(Lab.station_x(i) + 5, 1, 4)), "fila: la fila de dos avanza hacia el hueco")
	# --- colgarse: desde el borde de la plataforma
	i = Lab.index_of("colgarse")
	t = at(w, i, 7, 4, 4)
	t.try_action(E, HANG)
	check(t.hang_dir == W and t.player.y == 3, "colgarse: del borde de la plataforma se cuelga")
	# --- fijo: no se mueve
	i = Lab.index_of("fijo")
	t = at(w, i, 3, 1, 4)
	check(not t.try_action(E, GRAB).ok, "fijo: el bloque fijo no se empuja")
	# --- combos: el hielo te frena contra los pinchos (no pierdes) y subirte sí
	i = Lab.index_of("combos")
	t = at(w, i, 1, 1, 2)
	t.try_action(E)
	check(not t.lost and t.player.x == Lab.station_x(i) + 6, "combos: resbalas por el hielo y los pinchos te frenan")
	t.try_action(E)
	check(t.lost, "combos: y subirte a los pinchos pierde")


func test_commands() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	check(DevCommands.execute("help", main).contains("lab"), "la ayuda menciona el laboratorio")
	check(DevCommands.execute("spawn hielo", main).contains("sólo funciona"), "spawn fuera del laboratorio avisa")
	var out := DevCommands.execute("lab", main)
	check(main.lab_active and main.training and out.contains("estación 1"), "lab entra al laboratorio")
	check(main.logic.player == Lab.station_start(0) and main.lab_signs.size() == 1 and main.stage_label.text.contains("LABORATORIO"), "arranca en la primera estacion, con sus carteles y su titulo")
	check(main.goal_nodes.is_empty(), "el laboratorio no tiene meta")
	check(main.block_nodes.size() == main.logic.blocks.size(), "se dibujan todos los bloques")
	check(DevCommands.execute("labs", main).contains("bomba") and DevCommands.execute("labs", main).contains("12"), "labs lista las estaciones")
	out = DevCommands.execute("lab bomba", main)
	check(main.lab_station == 2 and main.logic.player == Lab.station_start(2) and out.contains("Bomba"), "lab <id> salta a esa estacion")
	check(DevCommands.execute("lab 99", main).contains("No hay"), "una estacion que no existe avisa")
	# spawn: un bloque delante del personaje
	main.logic.facing = Vector3i(0, 0, -1)
	var before: int = main.logic.blocks.size()
	out = DevCommands.execute("spawn trampa", main)
	check(main.logic.blocks.size() == before + 1 and main.logic.kind_at(main.logic.player + Vector3i(0, 0, -1)) == K.TRAP and main.block_nodes.size() == main.logic.blocks.size(), "spawn pone un bloque del tipo pedido delante (y se dibuja)")
	check(DevCommands.execute("spawn trampa", main).contains("ocupada"), "no se pone sobre otro bloque")
	check(DevCommands.execute("spawn dragon", main).contains("Tipos"), "un tipo desconocido lista los tipos")
	main.logic.facing = Vector3i(1, 0, 0)
	DevCommands.execute("spawn bomba 7", main)
	var bomb_id: int = main.logic.blocks[main.logic.player + Vector3i(1, 0, 0)]
	check(main.logic.kind_at(main.logic.player + Vector3i(1, 0, 0)) == K.BOMB and main.logic.bomb_timer[bomb_id] == 7, "spawn bomba 7 pone una bomba con cuenta 7")
	# perk y collapse
	check(DevCommands.execute("perk reflejos", main).contains("activado") and main.logic.perks.has("reflejos"), "perk activa un boost")
	var near: int = main.logic.blocks[Lab.station_start(2) + Vector3i(3, 0, 0)]
	check(main.logic.bomb_timer[near] == 6, "y se aplica de verdad: Reflejos suma 3 a la cuenta de las bombas (3 -> 6)")
	check(DevCommands.execute("perk nope", main).contains("Perks:"), "un perk desconocido lista los que hay")
	DevCommands.execute("perk reflejos", main)
	check(not main.logic.perks.has("reflejos") and main.logic.bomb_timer[near] == 3, "el mismo comando lo saca")
	# habilidades persistentes
	check(DevCommands.execute("ability", main).contains("garras_de_hielo") and DevCommands.execute("ability nope", main).contains("Habilidades:"), "ability sin id (o con uno malo) lista las habilidades")
	var claridad_before: int = main.run.claridad
	check(DevCommands.execute("ability garras_de_hielo", main).contains("activada") and main.logic.perks.has("garras_de_hielo"), "ability prende una habilidad con perk de la torre")
	check(DevCommands.execute("ability mente_despejada", main).contains("activada") and main.run.claridad == claridad_before + 25, "y una de las que cambian el run (Mente despejada: +25 de claridad)")
	check(DevCommands.execute("ability", main).contains("[x] garras_de_hielo"), "la lista marca las prendidas")
	DevCommands.execute("ability mente_despejada", main)
	DevCommands.execute("ability garras_de_hielo", main)
	check(main.run.claridad == claridad_before and not main.logic.perks.has("garras_de_hielo"), "apagarlas lo deshace")
	DevCommands.execute("ability bolsillo_sonador", main)
	check(main.run.consumable_capacity() == 4 + 6 + 1, "Bolsillo de soñador suma un casillero de consumibles")
	DevCommands.execute("ability bolsillo_sonador", main)
	# las habilidades del perfil real no valen en el laboratorio
	Profile.path = "user://test_profile.json"
	Profile.reset()
	Profile.grant_ability("garras_de_hielo")
	main.restart()
	check(not main.logic.perks.has("garras_de_hielo"), "las habilidades del perfil real no valen en el laboratorio")
	Profile.reset()
	# consumibles: se dan con give y se usan con las teclas
	check(DevCommands.execute("give freno", main).contains("Recibiste") and main.run.consumables == ["freno"], "give da un consumible")
	main.use_consumable_slot(0)
	check(main.logic.collapse_pause == 5 and main.run.consumables.is_empty(), "y se usa con su tecla (Freno pausa la caída 5 movimientos)")
	check(DevCommands.execute("give aire_extra", main).contains("Se reinició la estación") and main.run.boosts.has("aire_extra"), "give de un boost lo aplica enseguida (reinicia la estación)")
	main.run.boosts.clear()
	check(DevCommands.execute("collapse on", main).contains("encendida") and main.logic.collapse_every == 6, "collapse on enciende la caída")
	check(DevCommands.execute("collapse off", main).contains("apagada") and main.logic.collapse_every >= 1000, "collapse off la apaga")
	# R reinicia la estación actual (gratis) y los perks siguen
	DevCommands.execute("perk reflejos", main)
	main.logic.player = Vector3i(Lab.station_x(2) + 5, 1, 4)
	main.request_restart()
	check(main.lab_active and main.logic.player == Lab.station_start(2) and main.logic.perks.has("reflejos") and main.run.retries == 0, "R reinicia la estacion donde estabas, gratis, con los perks")
	check(main.logic.blocks.size() < before + 5 and main.logic.kind_at(Lab.station_start(2) + Vector3i(0, 0, -1)) != K.TRAP, "al reiniciar desaparecen los bloques puestos con spawn")
	# salir al menu
	main.open_main_menu()
	check(not main.lab_active and main.lab_signs.is_empty(), "salir al menú saca el laboratorio")
	main._cancel_jobs()
	main.queue_free()
	await process_frame
	# no existe en una compilación release
	DevCommands.disabled_for_tests = true
	var main2 = load("res://scenes/main.tscn").instantiate()
	main2.test_mode = true
	root.add_child(main2)
	await process_frame
	check(DevCommands.execute("lab", main2).contains("no está disponible"), "en release el laboratorio no existe")
	DevCommands.disabled_for_tests = false
	main2._cancel_jobs()
	main2.queue_free()
