extends SceneTree
## Demostración de "búsqueda de calidad y diversidad" (docs/evaluacion_generador.md §13.5): sin plantillas, se parte de terrenos al azar que se resuelven, se hace un cambio chico por vez
## (quitar, poner o mover un bloque, cambiar una columna a pesada), el solucionador mide cuántos bloques DISTINTOS hay que mover y cada sala válida entra en un casillero según ese número.
## Cada casillero guarda varias salas (no sólo la mejor). Al final se cuenta la historia de la mejor sala (sus antepasados) y se verifica con el solucionador exacto.
## Variables: N (evaluaciones, 600), TLIMIT (segundos máximos de búsqueda), W, D (arena, 3 x 3), PH (pilar, 4), CAP (estados del solucionador, 2500), KEEP (salas por casillero, 5), SEED (1), SAVE (archivo .json con la historia de la mejor, para tests/shot_cadenas.gd).
const Rooms := preload("res://scripts/rooms.gd")
const Solver := preload("res://scripts/solver.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const K := TowerLogic.Kind

var w := 3
var d := 3
var ph := 4
var cap := 2500
var keep := 5
var arrival := Vector2i(1, 2)
var pillar := Vector2i(4, 4)
var cells: Array[Vector2i] = []
var free: Array[Vector2i] = []
var rng := RandomNumberGenerator.new()
var all_rooms: Array = []   # {cols, moved, moves, grabs, path, parent, gen}
var archive := {}           # moved -> Array de índices en all_rooms
var seen := {}


func _env(name: String, def: float) -> float:
	return float(OS.get_environment(name)) if OS.get_environment(name) != "" else def


func key_of(cols: Dictionary) -> String:
	var ks: Array = []
	for c in cols:
		ks.append("%d,%d:%d%s" % [c.x, c.y, cols[c].h, "H" if cols[c].kind == K.HEAVY else ""])
	ks.sort()
	return ",".join(ks)


func evaluate(cols: Dictionary) -> Dictionary:
	var t = Rooms._vert_mini(cells, arrival, pillar, ph, cols, [])
	var res: Dictionary = Solver.solve(t.clone(), ph + 1, {"max_states": cap, "goal_ids": t.goal_ids})
	if res.status != "solved":
		return {}
	var plain: Dictionary = Solver.solve(t.clone(), ph + 1, {"max_states": cap, "goal_ids": t.goal_ids, "no_grab": true})
	if plain.status == "solved":
		return {}   # (se puede resolver sin tocar bloques: no sirve)
	var grabs := 0
	for a in res.path:
		if a.mode == TowerLogic.Mode.GRAB:
			grabs += 1
	return {"moved": Rooms._moved_blocks(t.clone(), res.path), "moves": res.moves, "grabs": grabs, "path": res.path}


func random_cols() -> Dictionary:
	var cols := {}
	for c in free:
		var hh := rng.randi_range(0, ph - 1)
		if hh > 0:
			cols[c] = {"h": hh, "kind": K.HEAVY if rng.randf() < 0.1 else K.NORMAL}
	return cols


func mutate(parent: Dictionary) -> Dictionary:
	var cols: Dictionary = parent.duplicate(true)
	for _i in rng.randi_range(1, 2):
		var op := rng.randi_range(0, 4)
		var a: Vector2i = free[rng.randi_range(0, free.size() - 1)]
		var b: Vector2i = free[rng.randi_range(0, free.size() - 1)]
		match op:
			0:   # poner un bloque
				if not cols.has(a):
					cols[a] = {"h": 1, "kind": K.NORMAL}
				elif int(cols[a].h) < ph - 1:
					cols[a].h = int(cols[a].h) + 1
			1:   # quitar un bloque
				if cols.has(a):
					cols[a].h = int(cols[a].h) - 1
					if int(cols[a].h) <= 0:
						cols.erase(a)
			2:   # pasar un bloque de una columna a otra
				if cols.has(a) and a != b and (not cols.has(b) or int(cols[b].h) < ph - 1):
					cols[a].h = int(cols[a].h) - 1
					if int(cols[a].h) <= 0:
						cols.erase(a)
					if cols.has(b):
						cols[b].h = int(cols[b].h) + 1
					else:
						cols[b] = {"h": 1, "kind": K.NORMAL}
			3:   # cambiar una columna entre común y pesada
				if cols.has(a):
					cols[a].kind = K.HEAVY if cols[a].kind == K.NORMAL else K.NORMAL
			4:   # intercambiar las alturas de dos columnas
				if a != b:
					var ca = cols.get(a)
					var cb = cols.get(b)
					if cb == null:
						cols.erase(a)
					else:
						cols[a] = cb
					if ca == null:
						cols.erase(b)
					else:
						cols[b] = ca
	return cols


func add(cols: Dictionary, ev: Dictionary, parent: int, gen: int) -> int:
	var k := key_of(cols)
	if seen.has(k):
		return -1
	var m: int = ev.moved
	if not archive.has(m):
		archive[m] = []
	var cell: Array = archive[m]
	var rec := {"cols": cols, "moved": m, "moves": ev.moves, "grabs": ev.grabs, "path": ev.path, "parent": parent, "gen": gen}
	if cell.size() < keep:
		all_rooms.append(rec)
		cell.append(all_rooms.size() - 1)
		seen[k] = true
		return all_rooms.size() - 1
	var worst := 0
	for i in cell.size():
		if all_rooms[cell[i]].moves < all_rooms[cell[worst]].moves:
			worst = i
	if ev.moves > all_rooms[cell[worst]].moves:
		all_rooms.append(rec)
		cell[worst] = all_rooms.size() - 1
		seen[k] = true
		return all_rooms.size() - 1
	return -1


func grid_text(cols: Dictionary) -> String:
	var out := ""
	for z in range(2, 2 + d):
		var row := "      "
		for x in range(1, 2 + w):
			var c := Vector2i(x, z)
			if c == arrival:
				row += "A  "
			elif c == pillar:
				row += "G  "
			elif cols.has(c):
				row += str(cols[c].h) + ("H " if cols[c].kind == K.HEAVY else "  ")
			else:
				row += ".  "
		out += row + "\n"
	return out


func _init() -> void:
	w = int(_env("W", 3))
	d = int(_env("D", 3))
	ph = int(_env("PH", 4))
	cap = int(_env("CAP", 2500))
	keep = int(_env("KEEP", 5))
	var n := int(_env("N", 600))
	rng.seed = int(_env("SEED", 1))
	for x in w:
		for z in d:
			cells.append(Vector2i(2 + x, 2 + z))
	pillar = Vector2i(2 + w - 1, 2 + d - 1)
	for c in cells:
		if c != pillar and (c - arrival).length() >= 1.5:
			free.append(c)
	var t0 := Time.get_ticks_msec()
	# 1) el origen: terrenos al azar que se resuelven y piden mover algún bloque
	var seeds := 0
	var tries := 0
	while seeds < 8 and tries < 400:
		tries += 1
		var cols := random_cols()
		var ev := evaluate(cols)
		if not ev.is_empty() and add(cols, ev, -1, 0) >= 0:
			seeds += 1
	print("origen: %d salas válidas de %d terrenos al azar (%.0f s)" % [seeds, tries, (Time.get_ticks_msec() - t0) / 1000.0])
	if seeds == 0:
		quit()
		return
	# 2) la búsqueda: elegir una sala de un casillero ocupado, cambiarla, evaluar
	var valid := 0
	var inserted := 0
	var snap := {}
	var tlimit := _env("TLIMIT", 1e9)
	var done_it := 0
	for it in n:
		if (Time.get_ticks_msec() - t0) / 1000.0 > tlimit:
			break
		done_it = it + 1
		if it in [n / 4, n / 2, 3 * n / 4]:
			var top := 0
			for m in archive:
				top = maxi(top, int(m))
			snap["tras %d" % it] = top
		var ms: Array = archive.keys()
		var cell: Array = archive[ms[rng.randi_range(0, ms.size() - 1)]]
		var pi: int = cell[rng.randi_range(0, cell.size() - 1)]
		var child := mutate(all_rooms[pi].cols)
		if seen.has(key_of(child)):
			continue
		var ev := evaluate(child)
		if ev.is_empty():
			continue
		valid += 1
		if add(child, ev, pi, int(all_rooms[pi].gen) + 1) >= 0:
			inserted += 1
	print("evaluaciones: %d, hijas válidas: %d, entraron al archivo: %d (%.0f s)" % [done_it, valid, inserted, (Time.get_ticks_msec() - t0) / 1000.0])
	var top_end := 0
	for m in archive:
		top_end = maxi(top_end, int(m))
	snap["al final"] = top_end
	print("mayor número de bloques distintos a mover en el archivo: ", snap)
	var ms2: Array = archive.keys()
	ms2.sort()
	print("archivo (casillero = bloques distintos que hay que mover): salas guardadas y pasos del mejor camino")
	for m in ms2:
		var best := 0
		for i in archive[m]:
			best = maxi(best, int(all_rooms[i].moves))
		print("   %2d bloques: %d salas, la más larga pide %d pasos" % [m, archive[m].size(), best])
	# 3) la historia de la mejor sala
	var bi := -1
	for i in all_rooms.size():
		if bi < 0 or all_rooms[i].moved > all_rooms[bi].moved or (all_rooms[i].moved == all_rooms[bi].moved and all_rooms[i].moves > all_rooms[bi].moves):
			bi = i
	var line: Array = []
	var cur := bi
	while cur >= 0:
		line.push_front(cur)
		cur = all_rooms[cur].parent
	print("la mejor sala tiene %d antepasados; historia (bloques distintos / pasos):" % line.size())
	var txt := ""
	for i in line:
		txt += " %d/%d" % [all_rooms[i].moved, all_rooms[i].moves]
	print("  " + txt)
	var picks: Array = [line[0], line[line.size() / 2], line[line.size() - 1]]
	var labels := ["principio", "mitad", "final"]
	for j in 3:
		var r = all_rooms[picks[j]]
		print("  %s: %d bloques distintos, %d agarres, %d pasos" % [labels[j], r.moved, r.grabs, r.moves])
		print(grid_text(r.cols))
	# 4) verificación exacta de la mejor (sin heurística)
	var rb = all_rooms[bi]
	var tb = Rooms._vert_mini(cells, arrival, pillar, ph, rb.cols, [])
	var ex: Dictionary = Solver.solve(tb.clone(), ph + 1, {"max_states": 60000, "goal_ids": tb.goal_ids, "heuristic": false})
	print("verificación exacta de la mejor: %s, mínimo %s (con heurística: %d)" % [ex.status, str(ex.get("moves", "?")), rb.moves])
	if OS.get_environment("SAVE") != "":
		var out: Array = []
		for i in picks:
			var r = all_rooms[i]
			var cl: Array = []
			for c in r.cols:
				cl.append([c.x, c.y, r.cols[c].h])
			var pt: Array = []
			for a in r.path:
				pt.append([a.dir.x, a.dir.z, int(a.mode)])
			out.append({"cols": cl, "path": pt, "moved": r.moved, "grabs": r.grabs, "w": w, "d": d, "ph": ph})
		var f := FileAccess.open(OS.get_environment("SAVE"), FileAccess.WRITE)
		f.store_string(JSON.stringify(out))
		f.close()
	quit()
