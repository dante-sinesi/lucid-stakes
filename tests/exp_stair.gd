extends SceneTree
## Experimento: sala chica con altura (W x D de arena, columnas de altura variable, una columna-meta alta en una esquina). Se prueban muchas disposiciones al azar y el solucionador completo mide el camino
## más corto y los bloques movidos. Muestra la distribución y la mejor. Variables: W, D, H (alto de la meta), MAXH (alto máximo de las columnas), N, CAP, HEAVY (cantidad de pesados).
const TowerLogic := preload("res://scripts/tower_logic.gd")
const Solver := preload("res://scripts/solver.gd")
const K_ := TowerLogic.Kind


func _init() -> void:
	var w := int(OS.get_environment("W")) if OS.get_environment("W") != "" else 3
	var d := int(OS.get_environment("D")) if OS.get_environment("D") != "" else 3
	var h := int(OS.get_environment("H")) if OS.get_environment("H") != "" else 4
	var maxh := int(OS.get_environment("MAXH")) if OS.get_environment("MAXH") != "" else 3
	var n := int(OS.get_environment("N")) if OS.get_environment("N") != "" else 120
	var cap := int(OS.get_environment("CAP")) if OS.get_environment("CAP") != "" else 20000
	var nheavy := int(OS.get_environment("HEAVY")) if OS.get_environment("HEAVY") != "" else 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var solved_n := 0
	var limit_n := 0
	var hist := {}
	var best_g := -1
	var best_text := ""
	var t0 := Time.get_ticks_msec()
	for it in n:
		var t := TowerLogic.new()
		t.size = Vector2i(8, 8)
		t.collapse_every = 100000
		t.moves_to_collapse = 100000
		for x in w:
			for z in d:
				t.add_block(Vector3i(x, 0, z), true)
		var gx := w - 1
		var gz := d - 1
		for y in range(1, h + 1):
			t.add_block(Vector3i(gx, y, gz), true)
		var goal_id: int = t.blocks[Vector3i(gx, h, gz)]
		var cells: Array[Vector2i] = []
		for x in w:
			for z in d:
				if not (x == gx and z == gz) and not (x == 0 and z == 0):
					cells.append(Vector2i(x, z))
		var heights := {}
		for c in cells:
			heights[c] = 0
		# escalera hacia la meta: la celda pegada a la meta (altura h-1), la anterior h-2... por un camino de celdas libres desde la meta
		var chain: Array[Vector2i] = []
		var cur := Vector2i(gx, gz)
		var seen := {cur: true}
		for k in range(h - 1, 0, -1):
			var opts: Array[Vector2i] = []
			for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb: Vector2i = cur + dd
				if cells.has(nb) and not seen.has(nb):
					opts.append(nb)
			if opts.is_empty():
				break
			cur = opts[rng.randi_range(0, opts.size() - 1)]
			seen[cur] = true
			chain.append(cur)
			heights[cur] = k
		var extra := int(OS.get_environment("EXTRA")) if OS.get_environment("EXTRA") != "" else 3
		for _e in extra:
			var c2: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
			if int(heights[c2]) < maxh:
				heights[c2] = int(heights[c2]) + 1
		var scr := int(OS.get_environment("SCRAMBLE")) if OS.get_environment("SCRAMBLE") != "" else 25
		for _m in scr:   # se pasa un bloque de arriba de una columna a otra
			var a2: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
			var b2: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
			if a2 != b2 and int(heights[a2]) > 0 and int(heights[b2]) < maxh:
				heights[a2] = int(heights[a2]) - 1
				heights[b2] = int(heights[b2]) + 1
		var heavy_cells: Array = []
		for _i in nheavy:
			heavy_cells.append(cells[rng.randi_range(0, cells.size() - 1)])
		for c in cells:
			for y in range(1, int(heights[c]) + 1):
				t.add_block(Vector3i(c.x, y, c.y), false, K_.HEAVY if heavy_cells.has(c) else K_.NORMAL)
		t.player = Vector3i(0, 1, 0)
		t.goal_y = h + 1
		t.goal_ids = {goal_id: true}
		var res: Dictionary = Solver.solve(t, h + 1, {"max_states": cap, "goal_ids": t.goal_ids})
		if res.status == "solved":
			solved_n += 1
			var grabs := 0
			for a in res.path:
				if a.mode == TowerLogic.Mode.GRAB:
					grabs += 1
			var key := grabs
			hist[key] = int(hist.get(key, 0)) + 1
			if grabs > best_g:
				best_g = grabs
				best_text = "%d agarres, %d movimientos, %d estados\n" % [grabs, res.moves, res.states]
				for y in range(h, 0, -1):
					best_text += "   capa %d: " % y
					for z in d:
						for x in w:
							var c := Vector2i(x, z)
							var ch := "."
							if t.blocks.has(Vector3i(x, y, z)):
								ch = "G" if (x == gx and z == gz) else ("H" if t.kind_at(Vector3i(x, y, z)) == K_.HEAVY else "n")
							best_text += ch
						best_text += " "
					best_text += "\n"
		elif res.status == "limit":
			limit_n += 1
	print("arena %dx%d, meta %d, columnas hasta %d: resueltas %d, sin resolver en el tope %d, de %d (%.0f s)" % [w, d, h, maxh, solved_n, limit_n, n, (Time.get_ticks_msec() - t0) / 1000.0])
	var keys := hist.keys()
	keys.sort()
	for k in keys:
		print("  %2d agarres: %d" % [k, hist[k]])
	print("la mejor: " + best_text)
	quit()
