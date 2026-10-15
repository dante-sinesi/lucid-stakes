extends SceneTree
## ¿El solucionador con heurística devuelve de verdad el camino más corto? Se compara con el mismo solucionador SIN heurística (búsqueda exhaustiva por costo, exacta) en salas verticales al azar.
## Variables: N (salas, 300), W, D (arena, 3 x 3), PH (alto del pilar, 4), CAP (estados del solucionador exacto, 400000), SEED (5).
const Rooms := preload("res://scripts/rooms.gd")
const Solver := preload("res://scripts/solver.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const K := TowerLogic.Kind


func _env(name: String, def: float) -> float:
	return float(OS.get_environment(name)) if OS.get_environment(name) != "" else def


func _init() -> void:
	var n := int(_env("N", 300))
	var w := int(_env("W", 3))
	var d := int(_env("D", 3))
	var ph := int(_env("PH", 4))
	var cap := int(_env("CAP", 400000))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_env("SEED", 5))
	var arrival := Vector2i(1, 2)
	var pillar := Vector2i(2 + w - 1, 2 + d - 1)
	var cells: Array[Vector2i] = []
	for x in w:
		for z in d:
			cells.append(Vector2i(2 + x, 2 + z))
	var both := 0
	var mismatch := 0
	var worse_sum := 0
	var worst := 0
	var only_h := 0
	var states_h := 0
	var states_e := 0
	var t0 := Time.get_ticks_msec()
	for i in n:
		var cols := {}
		for c in cells:
			if c == pillar or (c - arrival).length() < 1.5:
				continue
			var hh := rng.randi_range(0, ph - 1)
			if hh > 0:
				cols[c] = {"h": hh, "kind": K.HEAVY if rng.randf() < 0.1 else K.NORMAL}
		var t = Rooms._vert_mini(cells, arrival, pillar, ph, cols, [])
		var a: Dictionary = Solver.solve(t.clone(), ph + 1, {"max_states": cap, "goal_ids": t.goal_ids})
		if a.status != "solved":
			continue   # (si ni con heurística se resuelve, el exacto tampoco en el mismo tope: se ahorra el tiempo)
		var b: Dictionary = Solver.solve(t.clone(), ph + 1, {"max_states": cap, "goal_ids": t.goal_ids, "heuristic": false})
		if a.status == "solved" and b.status != "solved":
			only_h += 1
		if a.status != "solved" or b.status != "solved":
			continue
		both += 1
		print("  sala %d: heurística %d mov (%d estados) | exacto %d mov (%d estados) | %.0f s" % [i, a.moves, a.states, b.moves, b.states, (Time.get_ticks_msec() - t0) / 1000.0])
		states_h += a.states
		states_e += b.states
		if a.moves != b.moves:
			mismatch += 1
			worse_sum += a.moves - b.moves
			worst = maxi(worst, a.moves - b.moves)
			if mismatch <= 3:
				print("  sala %d: con heurística %d, exacto %d (%s)" % [i, a.moves, b.moves, str(cols)])
	print("%d salas, %d resueltas por los dos. Camino distinto del exacto: %d (%.1f %%). Diferencia promedio %.2f, peor %d. Sólo la heurística llegó a resolver: %d. Estados: con heurística %d, exacto %d (%.0f s)" % [n, both, mismatch, 100.0 * mismatch / maxi(both, 1), float(worse_sum) / maxi(mismatch, 1), worst, only_h, states_h, states_e, (Time.get_ticks_msec() - t0) / 1000.0])
	quit()
