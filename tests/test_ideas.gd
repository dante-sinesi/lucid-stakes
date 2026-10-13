extends SceneTree
## Las ideas de las torres: la pared de pinchos cumple lo que promete (hay que mover bloques, y pinchos), es válida, reproducible y distinta según la semilla.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_ideas.gd

const Ideas := preload("res://scripts/ideas.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const Solver := preload("res://scripts/solver.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	check(Ideas.names() == ["pared_pinchos", "cruce_agrietado", "hielo_freno"] and not Ideas.make("nada", 1).ok, "la idea existe y las desconocidas se rechazan")
	var asciis := {}
	for sd in [11, 12, 13]:
		var r := Ideas.make("pared_pinchos", sd)
		check(r.ok, "se arma una instancia de la pared de pinchos (semilla %d)" % sd)
		if not r.ok:
			continue
		asciis[r.ascii] = true
		check(r.moves >= Ideas.MIN_MOVES and r.moves <= Ideas.MAX_MOVES, "los movimientos caen en el rango pedido (%d)" % r.moves)
		check(r.spikes_moved >= 1, "la solución mueve pinchos (%d)" % r.spikes_moved)
		check(Gen._replay_wins(r.logic, r.path, Gen.BIG), "el camino gana sobre la torre armada")
		check(Solver.solve(r.logic, Ideas.ROWS + 1, {"max_states": 40000, "no_grab": true}).status != "solved", "sin empujar ni tirar no se pasa")
		var spikes := 0
		for id in r.logic.kind_of:
			if r.logic.kind_of[id] == TowerLogic.Kind.SPIKES:
				spikes += 1
		check(spikes >= 2, "hay una pared de pinchos (%d bloques)" % spikes)
	for sd in [1, 2]:   # el cruce agrietado: pesados de 2 de alto alrededor de la salida y un solo escalón agrietado que hay que acomodar y gastar
		var cr := Ideas.make("cruce_agrietado", sd, 300)
		check(cr.ok, "se arma una instancia del cruce agrietado (semilla %d)" % sd)
		if not cr.ok:
			continue
		check(cr.moves >= Ideas.MIN_MOVES and cr.moves <= Ideas.MAX_MOVES, "el cruce cae en el rango de movimientos (%d)" % cr.moves)
		check(Gen._replay_wins(cr.logic, cr.path, Gen.BIG), "el camino del cruce gana")
		check(Solver.solve(cr.logic, Ideas.ROWS + 1, {"max_states": 40000, "no_grab": true}).status != "solved", "el cruce no se pasa sin empujar ni tirar")
		var cracked := 0
		var heavy := 0
		for id in cr.logic.kind_of:
			cracked += 1 if cr.logic.kind_of[id] == TowerLogic.Kind.CRACKED else 0
			heavy += 1 if cr.logic.kind_of[id] == TowerLogic.Kind.HEAVY else 0
		check(cracked == 1 and heavy >= 2, "el cruce tiene un escalón agrietado y su pared pesada")
	for sd in [1, 2]:   # hielo y freno: un pasillo de hielo entre paredes y un freno que hay que empujar para resbalar hasta la celda de la salida
		var hf := Ideas.make("hielo_freno", sd, 300)
		check(hf.ok, "se arma una instancia de hielo y freno (semilla %d)" % sd)
		if not hf.ok:
			continue
		check(hf.moves >= Ideas.MIN_MOVES and hf.moves <= Ideas.MAX_MOVES, "hielo y freno cae en el rango de movimientos (%d)" % hf.moves)
		check(Gen._replay_wins(hf.logic, hf.path, Gen.BIG), "el camino de hielo y freno gana")
		check(Solver.solve(hf.logic, Ideas.ROWS + 1, {"max_states": 40000, "no_grab": true}).status != "solved", "hielo y freno no se pasa sin empujar ni tirar")
		var ice := 0
		for id in hf.logic.kind_of:
			ice += 1 if hf.logic.kind_of[id] == TowerLogic.Kind.ICE else 0
		check(ice >= 5, "hay un pasillo de hielo (%d bloques)" % ice)
	var nf := Ideas.make("pared_pinchos", 11)
	check(nf.ok and nf.logic.collapse_every >= Gen.BIG and nf.logic.moves_to_collapse >= Gen.BIG, "la torre de prueba no tiene caída de la fila de abajo")
	check(asciis.size() >= 2, "semillas distintas dan instancias distintas")
	var a := Ideas.make("pared_pinchos", 21)
	var b := Ideas.make("pared_pinchos", 21)
	check(a.ok and b.ok and a.ascii == b.ascii and a.path == b.path, "la misma semilla da la misma instancia")
	print("tests de las ideas terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
