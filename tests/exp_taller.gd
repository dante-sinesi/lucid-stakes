extends SceneTree
## Experimento "taller": arena chica con muros pesados de 3 de alto, un pilar de 2 (la meta es pararse arriba) y cajas de 1. Se prueban muchas disposiciones al azar y el solucionador
## mide el camino más corto. Muestra la distribución y la mejor. Variables: W, D, BOXES, WALLS, N (disposiciones), CAP (estados del solucionador).
const TowerLogic := preload("res://scripts/tower_logic.gd")
const Solver := preload("res://scripts/solver.gd")
const K_ := TowerLogic.Kind

var W := 5
var D := 4


func build(pillar: Vector2i, walls: Array, boxes: Array, start: Vector2i):
	var t := TowerLogic.new()
	t.size = Vector2i(8, 8)
	t.collapse_every = 100000
	t.moves_to_collapse = 100000
	for x in W:
		for z in D:
			t.add_block(Vector3i(x, 0, z), true)
	t.add_block(Vector3i(pillar.x, 1, pillar.y), false, K_.HEAVY)
	t.add_block(Vector3i(pillar.x, 2, pillar.y), false, K_.NORMAL)
	var goal_id: int = t.blocks[Vector3i(pillar.x, 2, pillar.y)]
	for c in walls:
		for y in range(1, 4):
			t.add_block(Vector3i(c.x, y, c.y), false, K_.HEAVY)
	for c in boxes:
		t.add_block(Vector3i(c.x, 1, c.y), false, K_.NORMAL)
	t.player = Vector3i(start.x, 1, start.y)
	t.goal_y = 3
	t.goal_ids = {goal_id: true}
	return t


func _init() -> void:
	W = int(OS.get_environment("W")) if OS.get_environment("W") != "" else 5
	D = int(OS.get_environment("D")) if OS.get_environment("D") != "" else 4
	var nb := int(OS.get_environment("BOXES")) if OS.get_environment("BOXES") != "" else 3
	var nw := int(OS.get_environment("WALLS")) if OS.get_environment("WALLS") != "" else 5
	var n := int(OS.get_environment("N")) if OS.get_environment("N") != "" else 150
	var cap := int(OS.get_environment("CAP")) if OS.get_environment("CAP") != "" else 30000
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hist := {}
	var best_moves := -1
	var best_text := ""
	var t0 := Time.get_ticks_msec()
	var solved_n := 0
	var limit_n := 0
	for it in n:
		var cells: Array[Vector2i] = []
		for x in W:
			for z in D:
				cells.append(Vector2i(x, z))
		var start := Vector2i(0, 0)
		cells.erase(start)
		var pillar: Vector2i = Vector2i(W - 1, D - 1)
		cells.erase(pillar)
		var walls: Array = []
		var boxes: Array = []
		# el vecino del pilar que queda libre (T): el otro es muro
		var t_cell := Vector2i(W - 2, D - 1) if rng.randf() < 0.5 else Vector2i(W - 1, D - 2)
		var w_cell := Vector2i(W - 1, D - 2) if t_cell.x == W - 2 else Vector2i(W - 2, D - 1)
		cells.erase(t_cell)
		cells.erase(w_cell)
		walls.append(w_cell)
		for _i in nw:
			if cells.is_empty():
				break
			var c: Vector2i = cells.pop_at(rng.randi_range(0, cells.size() - 1))
			if (c - start).length() < 1.5:
				continue
			walls.append(c)
		for _i in nb:
			if cells.is_empty():
				break
			boxes.append(cells.pop_at(rng.randi_range(0, cells.size() - 1)))
		var t = build(pillar, walls, boxes, start)
		var res: Dictionary = Solver.solve(t, 3, {"max_states": cap, "goal_ids": t.goal_ids})
		if res.status == "solved":
			solved_n += 1
			var key: int = res.moves / 4 * 4
			hist[key] = int(hist.get(key, 0)) + 1
			if res.moves > best_moves:
				best_moves = res.moves
				var grabs := 0
				for a in res.path:
					if a.mode == TowerLogic.Mode.GRAB:
						grabs += 1
				best_text = "%d mov, %d agarres, %d estados\n" % [res.moves, grabs, res.states]
				for z in D:
					var line := "   "
					for x in W:
						var c := Vector2i(x, z)
						line += "P " if c == start else ("G " if c == pillar else ("# " if walls.has(c) else ("n " if boxes.has(c) else ". ")))
					best_text += line + "\n"
		elif res.status == "limit":
			limit_n += 1
	print("resueltas %d, sin resolver en el tope %d, de %d  (%.1f s)" % [solved_n, limit_n, n, (Time.get_ticks_msec() - t0) / 1000.0])
	var keys := hist.keys()
	keys.sort()
	for k in keys:
		print("  %2d-%2d movimientos: %d" % [k, k + 3, hist[k]])
	print("la mejor: " + best_text)
	quit()
