extends SceneTree
## Torres por situaciones (rooms.gd): catálogo por escenario, plan de salas, torres válidas y reproducibles, y cada idea por separado.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_rooms.gd

const Rooms := preload("res://scripts/rooms.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_catalog()
	test_plan()
	test_towers()
	test_taller()
	test_chica()
	print("tests de las salas terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_catalog() -> void:
	check(Rooms.catalog("pesadilla", 0.0) == ["muro_simple"], "en la etapa 1 de la Pesadilla sólo está el muro simple (sin bloques especiales)")
	check(Rooms.catalog("pesadilla", Gen.difficulty_for_stage(2)) == ["muro_simple", "hielo_freno", "hielo_pista", "hielo_billar"], "en la etapa 2 aparece el hielo")
	check("cruce_agrietado" in Rooms.catalog("pesadilla", Gen.difficulty_for_stage(4)) and not ("pared_pinchos" in Rooms.catalog("pesadilla", Gen.difficulty_for_stage(4))), "el agrietado desde la etapa 4, los pinchos todavía no")
	check(Rooms.catalog("pesadilla", 1.0).size() == Rooms.names().size(), "al final de la escalera la Pesadilla tiene todas las ideas")
	var glaciar := Rooms.catalog("glaciar", 0.0)
	check(glaciar.size() >= 3 and glaciar.all(func(n): return str(n).begins_with("hielo")), "el Glaciar tiene sus ideas de hielo desde la primera etapa")
	check(Rooms.catalog("ruinas", 1.0).size() == Rooms.names().size(), "los escenarios sin catálogo propio usan todas las ideas")
	for n in Rooms.names():
		check(Rooms.IDEAS[n].twists.size() >= 2, "la idea %s tiene giros" % n)


func test_plan() -> void:
	var rng := RandomNumberGenerator.new()
	for sd in 20:
		rng.seed = sd
		var ideas := Rooms.catalog("pesadilla", 1.0)
		var order := Rooms.plan(rng, 6, 0.8, ideas)
		check(order.size() == 6 and order[0].idea != "respiro", "con dificultad alta la primera sala ya es una idea")
		var ok := true
		var rests := 0
		for i in order.size():
			if order[i].idea == "respiro":
				rests += 1
			if i > 0 and order[i].idea == order[i - 1].idea and order[i].idea != "taller" and order[i].idea != "chica":   # (las salas de cajas pueden ir seguidas)
				ok = false
		check(ok, "no se repite la idea de la sala anterior (semilla %d)" % sd)
		check(rests == 0, "con dificultad alta no hay salas de respiro en el plan (%d)" % rests)
	var easy := Rooms.plan(rng, 6, 0.1, Rooms.catalog("pesadilla", 1.0))
	check(easy[0].idea == "respiro", "con dificultad baja la primera sala es un respiro")
	rng.seed = 5
	var again := Rooms.plan(rng, 6, 0.5, ["hielo_freno"])
	var twists_ok := true
	for i in range(2, again.size()):
		if again[i].twist == again[i - 1].twist and again[i].idea == again[i - 1].idea and again[i].idea != "respiro":
			twists_ok = false
	check(twists_ok, "no se repite el mismo giro de una idea dos veces seguidas")


func test_towers() -> void:
	for spec in [["pesadilla", 25, 0.0, 1], ["pesadilla", 25, 0.3, 2], ["pesadilla", 9, 0.9, 3], ["glaciar", 25, 0.1, 4], ["glaciar", 13, 0.7, 5], ["pesadilla", 6, 0.5, 6]]:
		var rows: int = spec[1]
		var res: Dictionary = Rooms.generate_stage(int(spec[3]), rows, float(spec[2]), {"pace": "normal", "scenario": spec[0]})
		check(res.ok, "se genera una torre de %d pisos (%s, dificultad %.1f)" % [rows, spec[0], spec[2]])
		if not res.ok:
			continue
		var lg: TowerLogic = res.logic
		check(lg.goal_y == rows + 1, "el portal queda en el piso %d (%d)" % [rows + 1, lg.goal_y])
		check(Gen._replay_wins(lg, res.path, res.collapse_every), "el camino gana con la caída de la fila de abajo (%d pisos, %s)" % [rows, spec[0]])
		check(res.rows.size() == rows, "hay una cuenta de movimientos por piso (%d de %d)" % [res.rows.size(), rows])
		check(lg.fixed.size() >= 4 * rows, "el core está (fijo, de arriba a abajo)")
		check(lg.goal_block >= 0 and lg.fixed.has(lg.positions[lg.goal_block]), "el portal es un bloque fijo")
		if spec[0] == "glaciar":
			for r in res.rooms:
				check(r.idea == "respiro" or str(r.idea).begins_with("hielo"), "en el Glaciar sólo hay ideas de hielo (%s)" % r.idea)
	var a: Dictionary = Rooms.generate_stage(7, 13, 0.6, {"pace": "normal", "scenario": "pesadilla"})
	var b: Dictionary = Rooms.generate_stage(7, 13, 0.6, {"pace": "normal", "scenario": "pesadilla"})
	check(a.ok and b.ok and a.path == b.path, "la misma semilla da la misma torre")
	# cada idea, sola, arma una sala válida en alguna semilla
	for idea in Rooms.names():
		var made := false
		for sd in 6:
			OS.set_environment("IDEA_ONLY", idea)
			var res: Dictionary = Rooms.generate_stage(100 + sd, 9, 0.2, {"pace": "normal", "scenario": "pesadilla"})
			OS.set_environment("IDEA_ONLY", "")
			if res.ok and idea in res.rooms.map(func(r): return r.idea):
				made = true
				check(Gen._replay_wins(res.logic, res.path, res.collapse_every), "la torre con %s gana" % idea)
				break
		check(made, "la idea %s se arma en alguna sala" % idea)


## La sala de cajas (taller): sólo desde cierta dificultad, de 2 pisos, y el camino que trae gana de verdad sobre la torre tal cual sale (con su caída), sin rearmarla.
func test_taller() -> void:
	check(not ("taller" in Rooms.catalog("pesadilla", 0.1)) and "taller" in Rooms.catalog("pesadilla", 0.6), "las salas de cajas aparecen desde cierta dificultad")
	OS.set_environment("IDEA_ONLY", "taller")
	var res: Dictionary = Rooms.generate_stage(11, 5, 0.7, {"pace": "normal", "scenario": "pesadilla"})
	OS.set_environment("IDEA_ONLY", "")
	check(res.ok, "se genera una torre de salas de cajas")
	if not res.ok:
		return
	var tallers := 0
	for r in res.rooms:
		if r.idea == "taller":
			tallers += 1
			check(r.h == 2, "la sala de cajas es de 2 pisos")
	check(tallers >= 1, "hay al menos una sala de cajas (%d)" % tallers)
	var lg = res.logic.clone()
	var grabs := 0
	for a in res.path:
		if a.mode == TowerLogic.Mode.GRAB:
			grabs += 1
		lg.try_action(a.dir, a.mode)
	check(lg.won and not lg.lost, "el camino guardado gana sobre la torre tal cual sale")
	check(grabs >= 4 * tallers, "cada acertijo de cajas pide mover cajas (%d agarres)" % grabs)
	check(res.path.size() >= 14 * tallers, "y no es corto (%d movimientos en %d salas)" % [res.path.size(), tallers])
	OS.set_environment("IDEA_ONLY", "taller")
	var again: Dictionary = Rooms.generate_stage(11, 5, 0.7, {"pace": "normal", "scenario": "pesadilla"})
	OS.set_environment("IDEA_ONLY", "")
	check(again.ok and again.path == res.path, "la misma semilla da la misma torre de cajas (la generación no depende del tiempo)")


## La sala chica con altura (4 o 5 pisos): columnas de altura distinta y una salida alta; el camino que trae (del solucionador) gana sobre la torre real y pide mover bloques.
func test_chica() -> void:
	OS.set_environment("IDEA_ONLY", "chica")
	var res: Dictionary = Rooms.generate_stage(5, 6, 0.6, {"pace": "normal", "scenario": "pesadilla"})
	OS.set_environment("IDEA_ONLY", "")
	check(res.ok, "se genera una torre con una sala chica con altura")
	if not res.ok:
		return
	var chicas := 0
	for r in res.rooms:
		if r.idea == "chica":
			chicas += 1
			check(r.h == 4 or r.h == 5, "la sala chica mide 4 o 5 pisos (%d)" % r.h)
	check(chicas >= 1, "hay una sala chica (%d)" % chicas)
	var lg = res.logic.clone()
	var grabs := 0
	for a in res.path:
		if a.mode == TowerLogic.Mode.GRAB:
			grabs += 1
		lg.try_action(a.dir, a.mode)
	check(lg.won and not lg.lost, "el camino de la sala chica gana sobre la torre tal cual sale")
	check(grabs >= 3, "y pide mover bloques (%d agarres)" % grabs)
