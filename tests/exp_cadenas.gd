extends SceneTree
## Experimento de "cadenas de movimientos" (docs/brainstorming_generador.md §5): se arma una sala desde su solución y se mide si la solución plantada es la más corta o hay atajos.
##
## Una sala vertical chica (arena de W x D, pilar de PH pisos en una esquina, llegada afuera). El terreno empieza SIN DECIDIR: una cadena de movimientos con nombre se ejecuta paso a paso en el simulador real
## (TowerLogic) y cada movimiento decide, en el momento, la altura de las columnas que necesita (la que no se tocó antes se elige libre; la que ya existe tiene que servir). Movimientos:
##   PASO (caminar, trepar o bajar un escalón), EMPUJAR (el bloque de arriba de la columna de al lado pasa a la columna siguiente, que mide lo mismo que donde estoy parado) y
##   TRAER (tiro del bloque de arriba de la columna de atrás hacia mis pies, y avanzo).
## La cadena termina cuando el jugador está en una columna pegada al pilar que lo deja a un escalón de la cima.
## Después se rellenan las columnas que la cadena no tocó (modo "vacío" o al azar), se repite la cadena sobre el terreno inicial como seguro y el solucionador completo mide el camino más corto de verdad.
##
## Variables: N (cadenas a intentar, 150), PH (altura del pilar, 4), W, D (arena, 4 x 4), MAXSTEPS (largo máximo de la cadena, 26), EPS (probabilidad de elegir al azar, 0.3), SEED (7), SHOW (cuántas salas mostrar, 3), WALK_UP (1 deja decidir escalones caminables hacia arriba, 0), WALL (probabilidad de decidir la pared más alta, 0.6).
const Rooms := preload("res://scripts/rooms.gd")
const Solver := preload("res://scripts/solver.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const K := TowerLogic.Kind
const OX := 2
const OZ := 2

var w := 4
var d := 4
var ph := 4
var arena: Array[Vector2i] = []
var arena_set := {}
var arrival := Vector2i(1, 2)
var pillar := Vector2i(5, 5)
var dirs: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
var rng := RandomNumberGenerator.new()
var WALK_UP := 0
var WALL := 0.6


func _env(name: String, def: float) -> float:
	return float(OS.get_environment(name)) if OS.get_environment(name) != "" else def


func col_h(t, c: Vector2i) -> int:
	var y := 1
	while t.blocks.has(Vector3i(c.x, y, c.y)):
		y += 1
	return y - 1


## Decide (si no estaba decidida) la altura de la columna `q` entre las permitidas; false si no se puede o la que ya está no sirve.
func decide(n: Dictionary, q: Vector2i, allowed: Array) -> bool:
	if q == arrival:
		return allowed.has(0)
	if q == pillar:
		return false
	if not arena_set.has(q):
		return false
	if n.decided.has(q):
		return allowed.has(col_h(n.t, q))
	var ok: Array = []
	for v in allowed:
		if v >= 0 and v <= ph - 1:
			ok.append(v)
	if ok.is_empty():
		return false
	var v: int = ok[rng.randi_range(0, ok.size() - 1)]
	if ok.size() > 1 and rng.randf() < WALL:   # (de preferencia, la pared más alta que permite la regla: no se trepa)
		v = ok.max()
	for y in range(1, v + 1):
		n.t.add_block(Vector3i(q.x, y, q.y), false, K.NORMAL)
	n.decided[q] = true
	n.init[q] = v
	return true


func try_move(node: Dictionary, kind: int, dd: Vector3i) -> Dictionary:
	var n := {"t": node.t.clone(), "init": node.init.duplicate(), "decided": node.decided.duplicate(), "acts": node.acts.duplicate(), "grabs": node.grabs}
	var t = n.t
	var p := Vector2i(t.player.x, t.player.z)
	var a: int = t.player.y - 1
	if col_h(t, p) != a:
		return {}
	var d2 := Vector2i(dd.x, dd.z)
	var mode := TowerLogic.Mode.MOVE
	match kind:
		0:   # PASO
			var up_ok: bool = WALK_UP != 0 or n.decided.has(p + d2)   # (sin escalones libres hacia arriba: subir se gana moviendo bloques; una columna que ya existe sí se trepa)
			if not decide(n, p + d2, [a - 1, a, a + 1] if up_ok else [a - 1, a]):
				return {}
		1:   # EMPUJAR: el bloque de arriba de la columna de al lado pasa a la siguiente, que mide lo mismo que donde estoy
			if not (decide(n, p + d2, range(a + 1, ph) as Array) and decide(n, p + d2 * 2, [a])):
				return {}
			mode = TowerLogic.Mode.GRAB
		2:   # TRAER: el bloque de arriba de la columna de atrás viene a mis pies y avanzo a una columna de mi altura
			if not (decide(n, p - d2, range(a + 1, ph) as Array) and decide(n, p + d2, [a])):
				return {}
			mode = TowerLogic.Mode.GRAB
	var r: Dictionary = t.try_action(dd, mode)
	if not r.ok or t.lost or t.hang_dir != Vector3i.ZERO:
		return {}
	if kind != 1 and Vector2i(t.player.x, t.player.z) != p + d2:
		return {}
	n.acts.append({"dir": dd, "mode": mode})
	if mode == TowerLogic.Mode.GRAB:
		n.grabs += 1
	return n


func phi(n: Dictionary) -> float:
	var t = n.t
	var adj := 0
	for dd in dirs:
		var q := pillar + Vector2i(dd.x, dd.z)
		if n.decided.has(q) or q == arrival:
			adj = maxi(adj, col_h(t, q))
	return 3.0 * t.player.y + 2.0 * adj


var best_lvl := {}


func rollout(maxsteps: int, eps: float) -> Dictionary:
	var cells: Array[Vector2i] = arena.duplicate()
	var t = Rooms._vert_mini(cells, arrival, pillar, ph, {}, [])
	var node := {"t": t, "init": {}, "decided": {}, "acts": [], "grabs": 0}
	var seen := {Solver.state_key(t): true}
	var top := 1
	for _s in maxsteps:
		var tt = node.t
		top = maxi(top, tt.player.y)
		var p := Vector2i(tt.player.x, tt.player.z)
		if col_h(tt, p) == ph - 1 and tt.player.y == ph:
			for dd in dirs:
				if p + Vector2i(dd.x, dd.z) == pillar:
					var fin = tt.clone()
					if fin.try_action(dd, TowerLogic.Mode.MOVE).ok and fin.player.y == ph + 1:
						node.acts.append({"dir": dd, "mode": TowerLogic.Mode.MOVE})
						return node
		var opts: Array = []
		for kind in 3:
			for dd in dirs:
				var r := try_move(node, kind, dd)
				if r.is_empty():
					continue
				var key: Vector3i = Solver.state_key(r.t)
				if seen.has(key):
					continue
				r["key"] = key
				r["phi"] = phi(r) + rng.randf() * 0.5
				opts.append(r)
		if opts.is_empty():
			best_lvl[top] = int(best_lvl.get(top, 0)) + 1
			return {}
		var pick: Dictionary
		if rng.randf() < eps:
			pick = opts[rng.randi_range(0, opts.size() - 1)]
		else:
			pick = opts[0]
			for o in opts:
				if o.phi > pick.phi:
					pick = o
		seen[pick.key] = true
		node = pick
	best_lvl[top] = int(best_lvl.get(top, 0)) + 1
	return {}


## La sala inicial: lo decidido (a la altura que tenía al decidirse) y el relleno de lo que la cadena no tocó.
func build_initial(chain: Dictionary, fill: String) -> Dictionary:
	var cols := {}
	for c in chain.init:
		if int(chain.init[c]) > 0:
			cols[c] = {"h": int(chain.init[c]), "kind": K.NORMAL}
	if fill == "azar":
		for c in arena:
			if c != pillar and not chain.decided.has(c) and rng.randf() < 0.6:
				cols[c] = {"h": rng.randi_range(1, ph - 1), "kind": K.NORMAL}
	var cells: Array[Vector2i] = arena.duplicate()
	return {"cols": cols, "t": Rooms._vert_mini(cells, arrival, pillar, ph, cols, [])}


func grid_text(cols: Dictionary) -> String:
	var out := ""
	for z in range(OZ - 0, OZ + d):
		var row := "     "
		for x in range(OX - 1, OX + w):
			var c := Vector2i(x, z)
			if c == arrival:
				row += "A "
			elif c == pillar:
				row += "G "
			elif cols.has(c):
				row += str(cols[c].h) + " "
			elif arena_set.has(c):
				row += ". "
			else:
				row += "  "
		out += row + "\n"
	return out


func _init() -> void:
	w = int(_env("W", 4))
	d = int(_env("D", 4))
	ph = int(_env("PH", 4))
	var n_try := int(_env("N", 150))
	var maxsteps := int(_env("MAXSTEPS", 26))
	var eps := _env("EPS", 0.3)
	var show := int(_env("SHOW", 3))
	rng.seed = int(_env("SEED", 7))
	WALK_UP = int(_env("WALK_UP", 0))
	WALL = _env("WALL", 0.6)
	for x in w:
		for z in d:
			arena.append(Vector2i(OX + x, OZ + z))
			arena_set[Vector2i(OX + x, OZ + z)] = true
	arrival = Vector2i(OX - 1, OZ)
	pillar = Vector2i(OX + w - 1, OZ + d - 1)
	var t0 := Time.get_ticks_msec()
	var chains: Array = []
	for i in n_try:
		var c := rollout(maxsteps, eps)
		if not c.is_empty():
			chains.append(c)
	print("arena %dx%d, pilar de %d: %d de %d cadenas llegaron a la meta (%.0f s)" % [w, d, ph, chains.size(), n_try, (Time.get_ticks_msec() - t0) / 1000.0])
	print("  nivel más alto alcanzado (parado en y): ", best_lvl)
	if chains.is_empty():
		quit()
		return
	var lens := []
	var gr := []
	for c in chains:
		lens.append(c.acts.size())
		gr.append(c.grabs)
	print("  largo de la cadena (pasos): min %d, max %d | agarres en la cadena: min %d, max %d" % [lens.min(), lens.max(), gr.min(), gr.max()])
	for fill in ["vacío", "azar"]:
		var replay_ok := 0
		var solved := 0
		var plain_n := 0
		var shortcut := 0
		var good := 0   # sin atajo sin bloques y con 4+ bloques distintos movidos en el camino más corto
		var sum_opt := 0.0
		var sum_chain := 0.0
		var sum_moved := 0.0
		var sum_grabs := 0.0
		var ex: Array = []
		var th := {"4 bloques": 0, "5 bloques": 0, "6 bloques": 0, "5 agarres": 0, "7 agarres": 0, "5 bloques y 6 agarres": 0}
		for c in chains:
			var ini := build_initial(c, fill)
			var chk = ini.t.clone()
			var okr := true
			for a in c.acts:
				if not chk.try_action(a.dir, a.mode).ok or chk.lost:
					okr = false
					break
			if not okr or chk.player.y != ph + 1:
				continue
			replay_ok += 1
			var res: Dictionary = Solver.solve(ini.t.clone(), ph + 1, {"max_states": 20000, "goal_ids": ini.t.goal_ids})
			if res.status != "solved":
				continue
			solved += 1
			var plain: Dictionary = Solver.solve(ini.t.clone(), ph + 1, {"max_states": 20000, "goal_ids": ini.t.goal_ids, "no_grab": true})
			var is_plain: bool = plain.status == "solved"
			if is_plain:
				plain_n += 1
			var gopt := 0
			for a in res.path:
				if a.mode == TowerLogic.Mode.GRAB:
					gopt += 1
			var moved := Rooms._moved_blocks(ini.t.clone(), res.path)
			if res.moves < c.acts.size():
				shortcut += 1
			sum_opt += res.moves
			sum_chain += c.acts.size()
			sum_moved += moved
			sum_grabs += gopt
			if not is_plain:
				if moved >= 4:
					th["4 bloques"] += 1
				if moved >= 5:
					th["5 bloques"] += 1
				if moved >= 6:
					th["6 bloques"] += 1
				if gopt >= 5:
					th["5 agarres"] += 1
				if gopt >= 7:
					th["7 agarres"] += 1
				if moved >= 5 and gopt >= 6:
					th["5 bloques y 6 agarres"] += 1
			if not is_plain and moved >= 4:
				good += 1
				ex.append([moved * 10 + gopt, ini, c, res, moved, gopt])
		print("  relleno %s: la cadena se repite bien en %d; el solucionador resuelve %d" % [fill, replay_ok, solved])
		if solved > 0:
			print("    camino más corto promedio %.1f pasos (la cadena plantada: %.1f) | atajos (óptimo < cadena): %d de %d | resueltas sin tocar bloques: %d" % [sum_opt / solved, sum_chain / solved, shortcut, solved, plain_n])
			print("    en el camino más corto: %.1f agarres y %.1f bloques distintos en promedio | buenas (sin atajo caminando y 4+ bloques distintos): %d" % [sum_grabs / solved, sum_moved / solved, good])
		print("    sin atajo caminando y con al menos... ", th)
		ex.sort_custom(func(a, b): return a[0] > b[0])
		for i in mini(show, ex.size()):
			var e = ex[i]
			print("   ejemplo (relleno %s): óptimo %d pasos, %d agarres, %d bloques distintos; cadena plantada %d pasos, %d agarres" % [fill, e[3].moves, e[5], e[4], e[2].acts.size(), e[2].grabs])
			print(grid_text(e[1].cols))
	quit()
