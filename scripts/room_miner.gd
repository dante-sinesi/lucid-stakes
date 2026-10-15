extends RefCounted
## Minero de salas (calidad-diversidad, ver docs/evaluacion_generador.md §13.5). Sin plantillas: parte de salas que se resuelven y la arena de cada forma y altura se llena sola con cambios chicos
## (poner, quitar, mover o cambiar de tipo un bloque) que el solucionador acepta si la sala sigue resolviéndose, no se puede resolver caminando y pide mover bloques.
## Cada casillero del archivo (forma, altura, bloques distintos que hay que mover, tipos especiales) guarda varias salas. Cada sala que entra al archivo se escribe en el .jsonl del minero.
## Las salas se verifican de a poco con el verificador exacto (camino más corto garantizado); lo que no alcanza a verificarse queda marcado "sin_probar" o "cota".
## Lo maneja la escena scenes/miner.tscn (scripts/miner_main.gd) y lo prueba tests/test_miner.gd.

const RoomLib := preload("res://scripts/room_lib.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const Solver := preload("res://scripts/solver.gd")
const NativeSolver := preload("res://scripts/native_solver.gd")

const SPECIAL := ["i", "c", "b", "k", "t", "s"]

var rng := RandomNumberGenerator.new()
var out_dir := ""
var out_path := ""
var miner_id := 0
var keep := 6              # salas por casillero
var seed_p := 0.04         # probabilidad de partir de una sala nueva en lugar de cambiar una del archivo
var cross_p := 0.07        # probabilidad de mezclar dos salas del archivo
var verify_p := 0.10       # probabilidad de dedicar el paso a verificar una sala con el verificador exacto
var exact_cap := 60000
var exact_ms := 40000
var exact_max_moves := 30  # más largo que esto el verificador exacto no llega: queda "sin_probar"
var type_p := 0.12         # probabilidad de que un cambio sea de tipo de bloque
var current_shape := ""
var climb_bias := 0.0      # sin nada que empujar o tirar: probabilidad de preferir un paso que sube (para llegar a lo alto de la escalera, donde hay bloques para desordenar)
var walk_bias := 0.0       # probabilidad de caminar hacia el bloque más cercano cuando no hay nada que empujar
var last_info := ""
var prune_on := true         # sacar el relleno de cada sala que entra al archivo
var prune_ms := 20000
var polish_max_path := 90   # el tramo final del camino se mejora con el verificador exacto en salas con caminos de hasta esta cantidad de pasos
var cap_mult := 1.0         # multiplica el tope de estados y de tiempo con el que se resuelve cada sala (más tope = salas que piden más empujes, pero cada evaluación tarda más)
var excavate_p := 0.0       # probabilidad de dedicar el paso a excavar una sala del archivo (ver _excavate_step; hace falta el solucionador nativo)
var excavate_nodes := 1000000   # estados que explora cada excavación
var excavate_top := 60
var types_p := 0.0            # probabilidad de dedicar el paso a probar variantes con bloques especiales (hielo, agrietado, bomba, catapulta, trampa, pinchos) sobre una sala del archivo
var types_eval := 8           # variantes que se prueban por paso
var excavate_free := false    # las salas excavadas pueden tener bloques sin columna hasta el piso (sostenidos por sus vecinos)
var excavate_cap := 500000    # estados que se le dan al solucionador exacto por candidato
var excavate_eval := 20     # candidatos de cada excavación que se evalúan con el solucionador exacto
var last_why := ""         # por qué falló el último desorden
var tall_h := 9            # desde esta altura el solucionador ya no llega a resolver salas de partida: se construyen con la solución plantada (ver scramble_from)
var combos_list: Array = []
var archive := {}          # casillero -> Array de salas
var by_group := {}         # "forma|h" -> Array de salas
var seen := {}             # id -> true (todo lo evaluado)
var stats := {"evals": 0, "valid": 0, "inserted": 0, "dup": 0, "seeds": 0, "seeds_ok": 0, "exact_tries": 0, "exact_ok": 0, "exact_cota": 0, "corrections": 0, "resumed": 0, "fail": {}, "write_errors": 0}
var started_ms := 0
var write_lines := true


func _init(cfg: Dictionary = {}) -> void:
	out_dir = str(cfg.get("out_dir", ""))
	miner_id = int(cfg.get("id", 0))
	keep = int(cfg.get("keep", keep))
	seed_p = float(cfg.get("seed_p", seed_p))
	verify_p = float(cfg.get("verify_p", verify_p))
	exact_cap = int(cfg.get("exact_cap", exact_cap))
	exact_ms = int(cfg.get("exact_ms", exact_ms))
	write_lines = bool(cfg.get("write", true))
	prune_on = bool(cfg.get("prune", prune_on))
	cap_mult = float(cfg.get("cap_mult", cap_mult))
	excavate_p = float(cfg.get("excavate", excavate_p))
	excavate_nodes = int(cfg.get("excavate_nodes", excavate_nodes))
	excavate_eval = int(cfg.get("excavate_eval", excavate_eval))
	excavate_cap = int(cfg.get("excavate_cap", excavate_cap))
	excavate_free = bool(cfg.get("excavate_free", excavate_free))
	types_p = float(cfg.get("types", types_p))
	types_eval = int(cfg.get("types_eval", types_eval))
	rng.seed = int(cfg.get("seed", 1 + miner_id * 7919))
	var shapes: Array = cfg.get("shapes", RoomLib.SHAPES)
	var h_lo := int(cfg.get("h_lo", RoomLib.MIN_H))
	var h_hi := int(cfg.get("h_hi", RoomLib.MAX_H))
	for pair in RoomLib.combos():
		if shapes.has(pair[0]) and pair[1] >= h_lo and pair[1] <= h_hi:
			combos_list.append(pair)
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
		out_path = out_dir.path_join("miner_%d.jsonl" % miner_id)
	started_ms = Time.get_ticks_msec()


# --- el archivo -----------------------------------------------------------------------------------------------------------

static func special_types(room: Dictionary) -> String:
	var have := {}
	for c in room.cols:
		var ks: String = room.cols[c]
		for i in ks.length():
			if SPECIAL.has(ks[i]):
				have[ks[i]] = true
	var keys: Array = have.keys()
	keys.sort()
	return "".join(keys)


static func group_key(room: Dictionary) -> String:
	return "%s|%d" % [room.shape, room.h]


static func cell_key(room: Dictionary) -> String:
	return "%s|%d|%d|%d|%s" % [room.shape, room.h, mini(int(room.opt.get("grabs", 0)), 24), int(clampf(float(room.opt.get("diff", 0.0)), 0.0, 0.99) * 10.0), special_types(room)]


func archive_size() -> int:
	var n := 0
	for k in archive:
		n += archive[k].size()
	return n


func all_rooms() -> Array:
	var out: Array = []
	for k in archive:
		out.append_array(archive[k])
	return out


func _drop(room: Dictionary) -> void:
	var key := cell_key(room)
	if archive.has(key):
		archive[key].erase(room)
		if archive[key].is_empty():
			archive.erase(key)
	var g := group_key(room)
	if by_group.has(g):
		by_group[g].erase(room)


func _store(room: Dictionary) -> void:
	var key := cell_key(room)
	if not archive.has(key):
		archive[key] = []
	archive[key].append(room)
	var g := group_key(room)
	if not by_group.has(g):
		by_group[g] = []
	by_group[g].append(room)


## Entre las salas de un mismo casillero se prefiere la más difícil (más empujes y tirones sobre el total de pasos).
func _score(room: Dictionary) -> float:
	var o: Dictionary = room.opt
	return float(o.get("diff", 0.0)) * 100.0 + float(o.get("grabs", 0)) + 0.01 * float(o.get("moved", 0))


## Entra la sala al archivo si el casillero tiene lugar o si es mejor que la peor de él. Escribe la línea en el .jsonl. true si entró.
func insert(room: Dictionary, write := true) -> bool:
	var key := cell_key(room)
	var cell: Array = archive.get(key, [])
	if cell.size() >= keep:
		var worst: Dictionary = cell[0]
		for r in cell:
			if _score(r) < _score(worst):
				worst = r
		if _score(room) <= _score(worst):
			return false
		_drop(worst)
	_store(room)
	if write and write_lines and out_path != "":
		if not RoomLib.append_line(out_path, room):
			stats.write_errors = int(stats.write_errors) + 1
	return true


## Retoma un .jsonl propio: las salas válidas con las reglas actuales vuelven al archivo sin evaluar de nuevo (sí se repite su camino).
func resume() -> int:
	if out_path == "" or not FileAccess.file_exists(out_path):
		return 0
	var best := {}
	for r in RoomLib.read_file(out_path).rooms:
		seen[r.id] = true
		if int(r.rules) != RoomLib.RULES_VERSION:
			continue
		best[r.id] = RoomLib.better(best[r.id], r) if best.has(r.id) else r
	var n := 0
	for id in best:
		var r: Dictionary = best[id]
		if RoomLib.validate_structure(r) != "" or not RoomLib.replay(r, r.path).ok:
			continue
		if insert(r, false):
			n += 1
	stats.resumed = n
	return n


# --- crear y cambiar salas ----------------------------------------------------------------------------------------------------

func eval_opts(h: int) -> Dictionary:
	return {"cap": int((2500 + 350 * h) * cap_mult), "max_ms": int((4000 + 400 * h) * cap_mult), "h_weight": 1.0 if h <= 8 else 1.6, "plain_cap": 40000}


## Una escalera a pie hasta la salida: un camino de columnas pegadas, de h - 1 de alto la que toca el pilar y un escalón menos cada una. {} si la arena no tiene un camino tan largo.
func staircase(shape: String, h: int) -> Dictionary:
	current_shape = shape
	var info := RoomLib.shape_info(shape)
	var free := RoomLib.free_cells(shape)
	var free_set := {}
	for c in free:
		free_set[c] = true
	var starts: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = info.exit + d
		if free_set.has(n):
			starts.append(n)
	if starts.is_empty():
		return {}
	var ground := {}   # las celdas de la arena pegadas a la llegada: quedan siempre vacías, de ahí se trepa al escalón más bajo (y por el suelo vacío se llega a ellas)
	for c in info.cells:
		ground[c] = true
	var budget := [6000]
	for _try in 8:
		var start: Vector2i = starts[rng.randi_range(0, starts.size() - 1)]
		var path: Array[Vector2i] = [start]
		if _walk(path, {start: true}, free_set, h - 1, budget, ground):
			var cols := {}
			for i in path.size():
				cols[path[i]] = "n".repeat(h - 1 - i)
			return cols
	return {}


func _walk(path: Array[Vector2i], used: Dictionary, free_set: Dictionary, need: int, budget: Array, arena: Dictionary) -> bool:
	if path.size() >= need:
		return _bottom_reachable(path, used, arena)
	budget[0] -= 1
	if budget[0] < 0:
		return false
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for i in range(dirs.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = dirs[i]
		dirs[i] = dirs[j]
		dirs[j] = tmp
	for d in dirs:
		var n: Vector2i = path[path.size() - 1] + d
		if free_set.has(n) and not used.has(n):
			used[n] = true
			path.append(n)
			if _walk(path, used, free_set, need, budget, arena):
				return true
			path.pop_back()
			used.erase(n)
	return false


## ¿Se llega a pie al escalón más bajo? Se anda por el suelo vacío (las celdas de la arena que no son escalón ni la salida) desde las pegadas a la llegada.
func _bottom_reachable(path: Array[Vector2i], used: Dictionary, arena: Dictionary) -> bool:
	var info := RoomLib.shape_info(current_shape)
	var seeds: Array[Vector2i] = []
	for c in arena:
		if c != info.exit and not used.has(c) and (c - info.entry).length() < 1.5:
			seeds.append(c)
	var seen_g := {}
	for c in seeds:
		seen_g[c] = true
	var queue: Array[Vector2i] = seeds.duplicate()
	var qi := 0
	var last: Vector2i = path[path.size() - 1]
	while qi < queue.size():
		var c: Vector2i = queue[qi]
		qi += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n == last:
				return true
			if arena.has(n) and n != info.exit and not used.has(n) and not seen_g.has(n):
				seen_g[n] = true
				queue.append(n)
	return false


func _clean(cols: Dictionary) -> Dictionary:
	for c in cols.keys():
		cols[c] = RoomLib._trim_gaps(String(cols[c]))
		if String(cols[c]) == "":
			cols.erase(c)
	return cols


## Una sala de partida: terreno al azar (alturas bajas) o la escalera con unos bloques cambiados de lugar (los hay que volver a poner). Puede no servir: se evalúa afuera.
func make_seed(shape: String, h: int) -> Dictionary:
	var room := RoomLib.make_room(shape, h)
	var free := RoomLib.free_cells(shape)
	var cols := {}
	if h <= 7 and rng.randf() < 0.5:
		for c in free:
			var hh := rng.randi_range(0, h - 1)
			if hh > 0 and rng.randf() < 0.7:
				cols[c] = ("h" if rng.randf() < 0.08 else "n").repeat(hh)
	else:
		cols = staircase(shape, h)
		if cols.is_empty():
			return {}
		var moves := rng.randi_range(1, 3)
		for _i in moves:
			var keys: Array = cols.keys()
			var a: Vector2i = keys[rng.randi_range(0, keys.size() - 1)]
			var ks: String = cols[a]
			if ks.length() <= 0:
				continue
			cols[a] = ks.substr(0, ks.length() - 1)
			var b: Vector2i = free[rng.randi_range(0, free.size() - 1)]
			if String(cols.get(b, "")).length() < h - 1:
				cols[b] = String(cols.get(b, "")) + "n"
			else:
				cols[a] = ks
	room.cols = _clean(cols)
	return room


func _random_kind_other(cur: String) -> String:
	var opts: Array = RoomLib.KIND_OF_CHAR.keys()
	opts.erase(cur)
	return opts[rng.randi_range(0, opts.size() - 1)]


## Un cambio chico (a veces dos o tres) sobre una sala del archivo.
func mutate(parent: Dictionary) -> Dictionary:
	var room := RoomLib.make_room(parent.shape, parent.h)
	room.parent = parent.id
	var cols: Dictionary = parent.cols.duplicate(true)
	var free := RoomLib.free_cells(parent.shape)
	var h: int = parent.h
	var n_ops := 1
	while rng.randf() < 0.35 and n_ops < 4:
		n_ops += 1
	for _i in n_ops:
		var r := rng.randf()
		var a: Vector2i = free[rng.randi_range(0, free.size() - 1)]
		var b: Vector2i = free[rng.randi_range(0, free.size() - 1)]
		if r < type_p:   # cambiar el tipo de un bloque
			var keys: Array = []
			for kc in cols:
				if String(cols[kc]).length() > 0:
					keys.append(kc)
			if keys.is_empty():
				continue
			var c: Vector2i = keys[rng.randi_range(0, keys.size() - 1)]
			var ks: String = cols[c]
			var i := rng.randi_range(0, ks.length() - 1)
			cols[c] = ks.substr(0, i) + _random_kind_other(ks[i]) + ks.substr(i + 1)
		elif r < 0.30:   # poner un bloque encima de una columna
			var cur: String = cols.get(a, "")
			if cur.length() < h - 1:
				cols[a] = cur + ("h" if rng.randf() < 0.05 else "n")
		elif r < 0.50:   # sacar el bloque de arriba
			var cur2: String = cols.get(a, "")
			if cur2.length() > 0:
				cols[a] = cur2.substr(0, cur2.length() - 1)
		elif r < 0.82:   # pasar un bloque de arriba de una columna a otra
			var from: String = cols.get(a, "")
			var to: String = cols.get(b, "")
			if a != b and from.length() > 0 and to.length() < h - 1:
				cols[b] = to + from.substr(from.length() - 1)
				cols[a] = from.substr(0, from.length() - 1)
		elif r < 0.92:   # intercambiar dos columnas
			var ca: String = cols.get(a, "")
			var cb: String = cols.get(b, "")
			cols[a] = cb
			cols[b] = ca
		else:   # sacar un bloque del medio de una columna (los de arriba bajan)
			var cur3: String = cols.get(a, "")
			if cur3.length() > 1:
				var k := rng.randi_range(0, cur3.length() - 2)
				cols[a] = cur3.substr(0, k) + cur3.substr(k + 1)
	room.cols = _clean(cols)
	return room


## Una sala hija con cada columna de uno de los dos padres.
func crossover(a: Dictionary, b: Dictionary) -> Dictionary:
	var room := RoomLib.make_room(a.shape, a.h)
	room.parent = a.id
	var cols := {}
	for c in RoomLib.free_cells(a.shape):
		var src: Dictionary = a.cols if rng.randf() < 0.5 else b.cols
		if src.has(c):
			cols[c] = src[c]
	room.cols = _clean(cols)
	return room


# --- salas altas: la solución plantada ------------------------------------------------------------------------------------------

## Camino a pie (sin mover bloques) del jugador hasta `target`: búsqueda por anchura sobre las posiciones del jugador. null si no hay.
func walk_to(t, target: Vector3i) -> Variant:
	if t.player == target:
		return []
	var seen_pos := {t.player: true}
	var queue: Array = [[t, []]]
	var qi := 0
	while qi < queue.size() and seen_pos.size() < 4000:
		var node: Array = queue[qi]
		qi += 1
		for d in TowerLogic.DIRS:
			var n = node[0].clone()
			var r: Dictionary = n.try_action(d, TowerLogic.Mode.MOVE)
			if not r.ok or n.lost or n.hang_dir != Vector3i.ZERO or seen_pos.has(n.player):
				continue
			seen_pos[n.player] = true
			var path: Array = node[1].duplicate()
			path.append({"dir": d, "mode": TowerLogic.Mode.MOVE})
			if n.player == target:
				return path
			queue.append([n, path])
	return null


## La acción (o dos) que deshace `d`/`mode` aplicada a `before` (da `after`): se prueban las candidatas en el simulador y se queda la que devuelve el mismo estado y el mismo jugador. null si no hay.
func _inverse(before, after, d: Vector3i, mode: int) -> Variant:
	var cands: Array = []
	if mode == TowerLogic.Mode.MOVE:
		cands = [[[-d, TowerLogic.Mode.MOVE]]]
	else:
		cands = [[[d, TowerLogic.Mode.MOVE], [-d, TowerLogic.Mode.GRAB]], [[-d, TowerLogic.Mode.GRAB], [d, TowerLogic.Mode.MOVE]], [[-d, TowerLogic.Mode.GRAB]]]
	var key0: Vector3i = Solver.state_key(before)
	for seq in cands:
		var b = after.clone()
		var ok := true
		for a in seq:
			if not b.try_action(a[0], a[1]).ok or b.lost or b.hang_dir != Vector3i.ZERO:
				ok = false
				break
		if ok and b.player == before.player and Solver.state_key(b) == key0:
			return seq
	return null


## Distancia (en celdas, sobre el piso) del jugador al bloque suelto más cercano de la arena.
func _block_distance(sim, base: Dictionary) -> int:
	var best := 1000
	for c in sim.blocks:
		if c.y < 1 or sim.fixed.has(c) or Vector2i(c.x, c.z) == base.exit:
			continue
		best = mini(best, absi(c.x - sim.player.x) + absi(c.z - sim.player.z))
	return best


## ¿Los bloques sueltos del estado cumplen lo que admite el formato? Dentro de la arena, apoyados en el piso o en otro bloque y lejos de la llegada.
func _state_ok(sim, arena: Dictionary, exit: Vector2i, entry: Vector2i) -> bool:
	for c in sim.blocks:
		if c.y < 1 or sim.fixed.has(c):
			continue
		var cell := Vector2i(c.x, c.z)
		if cell == exit:
			continue
		if not arena.has(cell) or (cell - entry).length() < 1.5:
			return false
		if c.y > 1 and not sim.blocks.has(c + Vector3i.DOWN):
			return false
	return true


## Desordena una sala que ya se sabe resolver (con `room.path`): se hacen acciones del juego que se pueden deshacer (caminar, empujar, tirar) y la sala nueva es el resultado.
## Se sigue desordenando hasta que la sala ya no se pueda resolver caminando (y al menos `min_steps` acciones y `min_grabs` empujes o tirones). La solución es: caminar hasta donde terminó el desorden, deshacerlo al revés
## y seguir con el camino de la sala original. Sirve para cualquier altura: no hace falta que el solucionador la encuentre. {} si no se pudo (el motivo queda en `last_why`).
func scramble_from(base: Dictionary, min_steps: int, max_steps := 120, min_grabs := 2) -> Dictionary:
	var h: int = base.h
	var sim = RoomLib.build_state(base)
	var start_blocks: int = sim.blocks.size()
	var arena := {}
	for c in base.cells:
		arena[c] = true
	var entry_pos := Vector3i(base.entry.x, 1, base.entry.y)
	var invs: Array = []
	var grabs := 0
	var recent: Array = [Solver.state_key(sim)]
	var blocked := false
	while invs.size() < max_steps:
		var opts: Array = []
		var weight := 0
		for d in TowerLogic.DIRS:
			for mode in [TowerLogic.Mode.MOVE, TowerLogic.Mode.GRAB]:
				var n = sim.clone()
				var r: Dictionary = n.try_action(d, mode)
				if not r.ok or n.lost or n.hang_dir != Vector3i.ZERO or n.blocks.size() != start_blocks:
					continue
				if mode == TowerLogic.Mode.MOVE and n.player == sim.player:
					continue
				var key: Vector3i = Solver.state_key(n)
				if mode == TowerLogic.Mode.GRAB and not _state_ok(n, arena, base.exit, base.entry):
					continue
				var inv = _inverse(sim, n, d, mode)
				if inv == null:
					continue
				var w := 4 if mode == TowerLogic.Mode.GRAB else 1
				opts.append([n, inv, mode, key, w, recent.has(key)])
		if opts.is_empty():
			break
		var fresh: Array = []   # (de preferencia no se deshace lo último; en un callejón no queda otra)
		for o in opts:
			if not o[5]:
				fresh.append(o)
		if not fresh.is_empty():
			opts = fresh
		for o in opts:
			weight += int(o[4])
		var has_grab := false
		for o in opts:
			if o[2] == TowerLogic.Mode.GRAB:
				has_grab = true
		if not has_grab and rng.randf() < climb_bias:
			var up: Array = []
			var w_up := 0
			for o in opts:
				if o[0].player.y > sim.player.y:
					up.append(o)
					w_up += int(o[4])
			if not up.is_empty():
				opts = up
				weight = w_up
		if not has_grab and rng.randf() < walk_bias:   # (sin nada que empujar o tirar: se camina hacia el bloque más cercano)
			var near := _block_distance(sim, base)
			var closer: Array = []
			var w2 := 0
			for o in opts:
				if _block_distance(o[0], base) < near:
					closer.append(o)
					w2 += int(o[4])
			if not closer.is_empty():
				opts = closer
				weight = w2
		var roll := rng.randi_range(0, weight - 1)
		var pick: Array = opts[0]
		for o in opts:
			roll -= int(o[4])
			if roll < 0:
				pick = o
				break
		sim = pick[0]
		invs.append(pick[1])
		recent.append(pick[3])
		if recent.size() > 3:
			recent.pop_front()
		if pick[2] == TowerLogic.Mode.GRAB:
			grabs += 1
		if grabs >= min_grabs and invs.size() >= min_steps and invs.size() % 2 == 0:
			var c2 = sim.clone()   # (la sala que queda: el jugador arranca en la llegada)
			c2.player = entry_pos
			c2.hang_dir = Vector3i.ZERO
			var pl: Dictionary = Solver.solve(c2, h + 1, {"max_states": 3000, "goal_ids": c2.goal_ids, "no_grab": true, "max_ms": 3000})
			if pl.status == "unsolvable":
				blocked = true
				break
	if not blocked:
		last_why = "no_bloquea"
		last_info = "pasos=%d agarres=%d" % [invs.size(), grabs]
		return {}
	# lo que quedó: columnas pegadas al piso, dentro de la arena (cada paso ya lo comprobó)
	var cols := {}
	for c in sim.blocks:
		if c.y < 1 or sim.fixed.has(c) or Vector2i(c.x, c.z) == base.exit:
			continue
		var cell := Vector2i(c.x, c.z)
		cols[cell] = int(cols.get(cell, 0)) + 1
	var room := RoomLib.make_room(base.shape, h)
	var kinds := {}
	for cell in cols:
		var ks := ""
		for y in range(1, int(cols[cell]) + 1):
			var cc := Vector3i(cell.x, y, cell.y)
			if not sim.blocks.has(cc):
				last_why = "columna_rota"
				return {}
			ks += String(RoomLib.CHAR_OF_KIND.get(sim.kind_at(cc), "n"))
		kinds[cell] = ks
	room.cols = kinds
	room.parent = base.id
	if RoomLib.validate_structure(room) != "":
		last_why = "estructura"
		return {}
	var t2 = RoomLib.build_state(room)
	var p1 = walk_to(t2, sim.player)
	if p1 == null:
		last_why = "sin_camino_a_pie"
		return {}
	var path: Array = p1
	for i in range(invs.size() - 1, -1, -1):
		for a in invs[i]:
			path.append({"dir": a[0], "mode": a[1]})
	path.append_array(base.path)
	room.path = path
	return room


## Sala alta de partida: la escalera con unos bloques de sobra, resuelta caminando (ése es su camino base), desordenada. Si la escalera encierra su escalón más bajo (no se llega a pie), se prueba otra.
func make_tall_seed(shape: String, h: int) -> Dictionary:
	var free := RoomLib.free_cells(shape)
	var base := RoomLib.make_room(shape, h)
	var walk: Dictionary = {}
	for _try in 12:
		var cols := staircase(shape, h)
		if cols.is_empty():
			last_why = "sin_escalera"
			return {}
		for _i in rng.randi_range(1, 4):
			var c: Vector2i = free[rng.randi_range(0, free.size() - 1)]
			if String(cols.get(c, "")).length() < h - 1:
				cols[c] = String(cols.get(c, "")) + "n"
		base = RoomLib.make_room(shape, h)
		base.cols = cols
		RoomLib.finalize(base)
		var s0 = RoomLib.build_state(base)
		walk = Solver.solve(s0, h + 1, {"max_states": 6000, "goal_ids": s0.goal_ids, "no_grab": true, "max_ms": 3000})
		if walk.status == "solved":
			break
	if walk.get("status", "") != "solved":
		last_why = "sin_camino_base"
		return {}
	base.path = walk.path
	return scramble_from(base, 4, 160, 2)


# --- el paso del minero ---------------------------------------------------------------------------------------------------------

func _fail(why: String) -> void:
	var f: Dictionary = stats.fail
	f[why] = int(f.get(why, 0)) + 1


## Evalúa una sala nueva; si sirve y no está repetida, entra al archivo. true si entró.
## `parent_path`: camino de la sala de la que sale (las altas lo reutilizan: si el cambio no lo rompe, la sala sigue resolviéndose).
func try_child(child: Dictionary, parent_path: Array = []) -> bool:
	if RoomLib.validate_structure(child) != "":
		_fail("estructura")
		return false
	RoomLib.finalize(child)
	if seen.has(child.id):
		stats.dup = int(stats.dup) + 1
		return false
	seen[child.id] = true
	stats.evals = int(stats.evals) + 1
	if child.h >= tall_h:
		return _try_tall(child, parent_path)
	var ev := RoomLib.evaluate(child, eval_opts(child.h))
	if not ev.ok:
		_fail(str(ev.why))
		return false
	stats.valid = int(stats.valid) + 1
	RoomLib.apply_result(child, ev.path, "sin_probar", child.h, int(ev.states))
	child.origin = "minero"
	child.stamp = int(Time.get_unix_time_from_system())
	child = _polish(child)
	if child.is_empty():
		return false
	if insert(child):
		stats.inserted = int(stats.inserted) + 1
		return true
	return false


## Antes de que una sala entre al archivo: se le saca el relleno (lo que no hace falta para su camino ni para que no se pueda resolver caminando) y se mejora el tramo final de su camino con el
## verificador exacto (si todo el camino queda probado, la sala queda con prueba exacta). {} si después de podar resulta una sala que ya se vio.
func _polish(room: Dictionary) -> Dictionary:
	var out := room
	if prune_on:
		var before_id: String = room.id
		var pr := RoomLib.prune(room, rng, prune_ms)
		if int(pr.removed) > 0:
			out = pr.room
			stats.pruned = int(stats.get("pruned", 0)) + int(pr.removed)
			var source: String = str(room.opt.get("source", ""))
			RoomLib.apply_result(out, out.path, "sin_probar", out.h, int(room.opt.get("states", 0)))
			if source != "":
				out.opt.source = source
			if out.id != before_id:
				if seen.has(out.id):
					stats.dup = int(stats.dup) + 1
					return {}
				seen[out.id] = true
	if out.path.size() <= polish_max_path:
		var imp := RoomLib.improve_tail(out, out.path, 8000, 1500)
		if imp.path.size() < out.path.size() or int(imp.proven) >= imp.path.size():
			var source2: String = str(out.opt.get("source", ""))
			var full: bool = int(imp.proven) >= imp.path.size()
			RoomLib.apply_result(out, imp.path, "exacta" if full else "sin_probar", imp.path.size() if full else out.h, int(out.opt.get("states", 0)))
			if source2 != "":
				out.opt.source = source2
			if imp.path.size() < room.path.size():
				stats.polished = int(stats.get("polished", 0)) + 1
	return out


## Sala alta: vale si su camino plantado la resuelve y no se puede resolver caminando (esa búsqueda es exacta y chica). Su dificultad queda como cota superior: `proof` "sin_probar" y `opt.source` "plantada".
func _try_tall(child: Dictionary, parent_path: Array) -> bool:
	var path: Array = child.path if not child.path.is_empty() else parent_path
	if path.is_empty():
		_fail("sin_camino")
		return false
	var rp := RoomLib.replay(child, path)
	if not rp.ok:
		_fail("camino_roto")
		return false
	var t = RoomLib.build_state(child)
	var plain: Dictionary = Solver.solve(t, child.h + 1, {"max_states": 40000, "goal_ids": t.goal_ids, "no_grab": true, "max_ms": 8000})
	if plain.status != "unsolvable":
		_fail("atajo" if plain.status == "solved" else "sin_prueba_de_atajo")
		return false
	var st := RoomLib.path_stats(child, path)
	if int(st.moved) < 1:
		_fail("sin_bloques")
		return false
	stats.valid = int(stats.valid) + 1
	RoomLib.apply_result(child, path, "sin_probar", child.h, 0)
	child.opt.source = "plantada"
	child.origin = "minero"
	child.stamp = int(Time.get_unix_time_from_system())
	child = _polish(child)
	if child.is_empty():
		return false
	if insert(child):
		stats.inserted = int(stats.inserted) + 1
		return true
	return false


## Elige una sala del archivo para cambiarla: primero un casillero de dificultad (bloques que hay que mover), con más probabilidad cuantos más bloques pide, y dentro de él una sala.
## Así las salas difíciles, que son pocas, se cambian tanto como las fáciles, que son muchas, y la frontera avanza.
func pick_parent(shape: String, h: int) -> Dictionary:
	var prefix := "%s|%d|" % [shape, h]
	var keys: Array = []
	for k in archive:
		if String(k).begins_with(prefix):
			keys.append(k)
	if keys.is_empty():
		return {}
	var total := 0.0
	var weights: Array = []
	for k in keys:
		var o0: Dictionary = archive[k][0].opt
		var w := pow(1.0 + float(o0.get("grabs", 1)), 1.5) * (0.25 + float(o0.get("diff", 0.0)))   # (los casilleros de más agarres y más dificultad, que son los que faltan, se eligen más)
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	var chosen: Array = archive[keys[keys.size() - 1]]
	for i in keys.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			chosen = archive[keys[i]]
			break
	return chosen[rng.randi_range(0, chosen.size() - 1)]


func pick_combo() -> Array:
	return combos_list[rng.randi_range(0, combos_list.size() - 1)]



## Excavar: el solucionador nativo explora el grafo de estados alrededor de la sala (y de su camino) y propone las disposiciones de bloques más difíciles que se alcanzan desde ella;
## cada una se resuelve con el solucionador exacto (camino más corto garantizado) y entra al archivo si no se puede resolver caminando. Es el motor que sube la cantidad de empujes y tirones.
func _excavate_step(par: Dictionary) -> void:
	if par.is_empty() or par.path.is_empty():
		_fail("excavar_sin_camino")
		return
	stats.excavations = int(stats.get("excavations", 0)) + 1
	var t = RoomLib.build_state(par)
	var ex := NativeSolver.excavate(t, Vector2i(par.entry.x, par.entry.y), par.exit, RoomLib.path_string(par.path), excavate_nodes, excavate_top, 0, not excavate_free, par.h - 1)
	if ex.is_empty():
		_fail("excavar_nativo")
		return
	var tried := 0
	var order: Array = []   # los primeros del ranking y, para variar, otros al azar (el ranking del grafo explorado sobrestima: muchos tienen atajos que sólo ve el solucionador exacto)
	for i in ex.cands.size():
		order.append(i)
	var head_n := mini(excavate_eval / 3, order.size())
	var tail: Array = order.slice(head_n)
	for i in range(tail.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = tail[i]
		tail[i] = tail[j]
		tail[j] = tmp
	order = order.slice(0, head_n) + tail
	for oi in order:
		var cd: Dictionary = ex.cands[oi]
		if tried >= excavate_eval:
			break
		var room := RoomLib.room_from_layout(par, cd.blocks)
		if RoomLib.validate_structure(room) != "":
			continue
		RoomLib.finalize(room)
		if seen.has(room.id):
			stats.dup = int(stats.dup) + 1
			continue
		seen[room.id] = true
		tried += 1
		stats.evals = int(stats.evals) + 1
		var t2 = RoomLib.build_state(room)
		var res: Dictionary = Solver.solve(t2.clone(), room.h + 1, {"max_states": excavate_cap, "goal_ids": t2.goal_ids, "admissible": true, "prefer_plain": true, "max_ms": 12000})
		if res.status != "solved":
			_fail("excavar_" + str(res.status))
			continue
		var plain: Dictionary = Solver.solve(t2, room.h + 1, {"max_states": 60000, "goal_ids": t2.goal_ids, "no_grab": true, "max_ms": 8000})
		if plain.status != "unsolvable":
			_fail("atajo" if plain.status == "solved" else "sin_prueba_de_atajo")
			continue
		var st := RoomLib.path_stats(room, res.path)
		if int(st.moved) < 1:
			_fail("sin_bloques")
			continue
		stats.valid = int(stats.valid) + 1
		RoomLib.apply_result(room, res.path, "exacta", int(res.moves), int(res.states))
		room.opt.source = "excavada"
		room.origin = "minero"
		room.stamp = int(Time.get_unix_time_from_system())
		if insert(room):
			stats.inserted = int(stats.inserted) + 1
			stats.excavated = int(stats.get("excavated", 0)) + 1


## Resuelve la sala con el solucionador exacto (el camino más corto, y entre los más cortos el de menos agarres) y comprueba que no se pueda resolver caminando y que pida mover bloques. La sala con su camino y sus métricas, o {}.
func _exact_room(room: Dictionary) -> Dictionary:
	var t = RoomLib.build_state(room)
	var res: Dictionary = Solver.solve(t.clone(), room.h + 1, {"max_states": excavate_cap, "goal_ids": t.goal_ids, "admissible": true, "prefer_plain": true, "max_ms": 12000})
	if res.status != "solved":
		_fail("tipos_" + str(res.status))
		return {}
	var plain: Dictionary = Solver.solve(t, room.h + 1, {"max_states": 60000, "goal_ids": t.goal_ids, "no_grab": true, "max_ms": 8000})
	if plain.status != "unsolvable":
		_fail("atajo" if plain.status == "solved" else "sin_prueba_de_atajo")
		return {}
	if int(RoomLib.path_stats(room, res.path).moved) < 1:
		_fail("sin_bloques")
		return {}
	var r := RoomLib.copy_room(room)
	RoomLib.apply_result(r, res.path, "exacta", int(res.moves), int(res.states))
	return r


## Las celdas con bloques especiales de la sala: [[celda, piso (1 = sobre el piso)], ...].
func _special_blocks(room: Dictionary) -> Array:
	var out: Array = []
	for c in room.cols:
		var ks: String = room.cols[c]
		for i in ks.length():
			if SPECIAL.has(ks[i]):
				out.append([c, i + 1])
	return out


## Un bloque especial que no cambia el camino más corto (mismos pasos y mismos agarres) es adorno: se lo cambia por uno común. Devuelve la sala sin adornos, o {} si no queda ningún especial que importe.
func _special_cleanup(room: Dictionary) -> Dictionary:
	var cur := room
	for sb in _special_blocks(room):
		var c: Vector2i = sb[0]
		var y: int = sb[1]
		var cand := RoomLib.copy_room(cur)
		var ks: String = cand.cols[c]
		cand.cols[c] = ks.substr(0, y - 1) + "n" + ks.substr(y)
		cand.path = []
		cand.opt = {}
		var ex := _exact_room(cand)
		if not ex.is_empty() and int(ex.opt.moves) == int(cur.opt.moves) and int(ex.opt.grabs) == int(cur.opt.grabs):
			cur = ex
	return cur if not _special_blocks(cur).is_empty() else {}


## Variantes con bloques especiales: a una sala del archivo se le cambia el tipo de uno o dos bloques, o se le agrega un bloque especial, y se queda con las que siguen resolviéndose, siguen pidiendo mover bloques y
## en las que el especial es necesario (si sacarlo no cambia el camino más corto, era adorno). Así el archivo tiene salas que aprovechan hielo, arenisca, bombas, catapultas, trampas y pinchos.
func _type_step(par: Dictionary) -> void:
	if par.is_empty() or par.path.is_empty():
		_fail("tipos_sin_camino")
		return
	stats.type_steps = int(stats.get("type_steps", 0)) + 1
	var specials := SPECIAL
	for n in types_eval:
		var room := RoomLib.copy_room(par)
		room.path = []
		room.opt = {}
		room.parent = str(par.get("id", ""))
		var cells: Array = room.cols.keys()
		var kind: String = specials[rng.randi_range(0, specials.size() - 1)]
		var count := 1 if rng.randf() < 0.6 else 2
		for k in count:
			if not cells.is_empty() and rng.randf() < 0.65:   # cambiar el tipo de un bloque
				var c: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
				var ks: String = room.cols[c]
				var idx: Array = []
				for i in ks.length():
					if ks[i] != RoomLib.GAP:
						idx.append(i)
				if not idx.is_empty():
					var i: int = idx[rng.randi_range(0, idx.size() - 1)]
					room.cols[c] = ks.substr(0, i) + kind + ks.substr(i + 1)
			else:   # agregar un bloque especial arriba de una columna o en una celda vacía
				var free: Array = RoomLib.free_cells(room.shape)
				var c2: Vector2i = free[rng.randi_range(0, free.size() - 1)]
				var cur: String = room.cols.get(c2, "")
				if cur.length() < int(room.h) - 1:
					room.cols[c2] = cur + kind
		room.cols = _clean(room.cols)
		if RoomLib.validate_structure(room) != "":
			_fail("estructura")
			continue
		RoomLib.finalize(room)
		if seen.has(room.id):
			stats.dup = int(stats.dup) + 1
			continue
		seen[room.id] = true
		stats.evals = int(stats.evals) + 1
		var ex := _exact_room(room)
		if ex.is_empty():
			continue
		var cleaned := _special_cleanup(ex)
		if cleaned.is_empty():
			_fail("tipos_adorno")
			continue
		RoomLib.finalize(cleaned)
		if cleaned.id != room.id:
			if seen.has(cleaned.id):
				stats.dup = int(stats.dup) + 1
				continue
			seen[cleaned.id] = true
		stats.valid = int(stats.valid) + 1
		cleaned.opt.source = "tipos"
		cleaned.origin = "minero"
		cleaned.stamp = int(Time.get_unix_time_from_system())
		if insert(cleaned):
			stats.inserted = int(stats.inserted) + 1
			stats.typed = int(stats.get("typed", 0)) + 1

## Un paso: o se verifica una sala, o se crea y evalúa una nueva.
func step() -> void:
	if combos_list.is_empty():
		return
	if rng.randf() < verify_p and verify_one():
		return
	var combo := pick_combo()
	var list: Array = by_group.get("%s|%d" % [combo[0], combo[1]], [])
	var r := rng.randf()
	var tall: bool = combo[1] >= tall_h
	if types_p > 0.0 and not list.is_empty() and rng.randf() < types_p and NativeSolver.available():
		_type_step(pick_parent(combo[0], combo[1]))
		return
	if excavate_p > 0.0 and not list.is_empty() and rng.randf() < excavate_p and NativeSolver.available():
		_excavate_step(pick_parent(combo[0], combo[1]))
		return
	if list.size() < 3 or r < seed_p:
		stats.seeds = int(stats.seeds) + 1
		var seed_room := make_tall_seed(combo[0], combo[1]) if tall else make_seed(combo[0], combo[1])
		if seed_room.is_empty():
			_fail("sin_escalera" if not tall else "semilla_" + last_why)
			return
		if try_child(seed_room):
			stats.seeds_ok = int(stats.seeds_ok) + 1
	elif tall and r < 0.55:   # extender: más desorden sobre una sala alta que ya se sabe resolver
		var par: Dictionary = pick_parent(combo[0], combo[1])
		var ext := scramble_from(par, 2, 120, rng.randi_range(2, 4))
		if ext.is_empty():
			_fail("ext_" + last_why)
			return
		try_child(ext)
	elif r < seed_p + cross_p and list.size() >= 2:
		var pa: Dictionary = pick_parent(combo[0], combo[1])
		try_child(crossover(pa, pick_parent(combo[0], combo[1])), pa.path)
	else:
		var par2: Dictionary = pick_parent(combo[0], combo[1])
		try_child(mutate(par2), par2.path)


## Verifica con el verificador exacto una sala del archivo que todavía no tenga prueba (primero las de camino corto, que son las que se pueden probar). true si hizo algo.
func verify_one() -> bool:
	var cands: Array = []
	for k in archive:
		for r in archive[k]:
			if str(r.opt.get("proof", "")) == "sin_probar" and int(r.opt.moves) <= exact_max_moves:
				cands.append(r)
	if cands.is_empty():
		return false
	cands.sort_custom(func(a, b): return int(a.opt.moves) < int(b.opt.moves))
	var room: Dictionary = cands[rng.randi_range(0, mini(cands.size(), 4) - 1)]
	stats.exact_tries = int(stats.exact_tries) + 1
	var res := RoomLib.verify_exact(room, exact_cap, exact_ms)
	_drop(room)
	var old_moves := int(room.opt.moves)
	if res.proof == "exacta":
		stats.exact_ok = int(stats.exact_ok) + 1
		if int(res.moves) < old_moves:
			stats.corrections = int(stats.corrections) + 1
		RoomLib.apply_result(room, res.path, "exacta", int(res.moves), int(res.states))
	else:
		stats.exact_cota = int(stats.exact_cota) + 1
		room.opt = room.opt.duplicate()
		room.opt.proof = "cota"
		room.opt.lower = maxi(int(room.opt.get("lower", 0)), int(res.lower))
		room.opt.states = int(res.states)
	room.stamp = int(Time.get_unix_time_from_system())
	if not insert(room):   # (con el camino más corto puede haber cambiado de casillero y estar lleno)
		return true
	return true


# --- informe --------------------------------------------------------------------------------------------------------------------

func summary() -> Dictionary:
	var secs: float = maxf((Time.get_ticks_msec() - started_ms) / 1000.0, 0.001)
	var per_shape := {}
	var max_moved := {}
	var max_grabs := {}
	var max_diff := {}
	var proofs := {"exacta": 0, "cota": 0, "sin_probar": 0}
	for r in all_rooms():
		per_shape[r.shape] = int(per_shape.get(r.shape, 0)) + 1
		max_moved[r.shape] = maxi(int(max_moved.get(r.shape, 0)), int(r.opt.get("moved", 0)))
		max_grabs[r.shape] = maxi(int(max_grabs.get(r.shape, 0)), int(r.opt.get("grabs", 0)))
		max_diff[r.shape] = maxf(float(max_diff.get(r.shape, 0.0)), snappedf(float(r.opt.get("diff", 0.0)), 0.01))
		proofs[str(r.opt.get("proof", "sin_probar"))] = int(proofs.get(str(r.opt.get("proof", "sin_probar")), 0)) + 1
	var covered := {}
	for g in by_group:
		if not by_group[g].is_empty():
			covered[g] = true
	return {"id": miner_id, "secs": secs, "evals_per_s": float(stats.evals) / secs, "stats": stats, "archive": archive_size(), "cells": archive.size(), "groups_covered": covered.size(), "groups_total": combos_list.size(),
		"per_shape": per_shape, "max_moved_by_shape": max_moved, "max_grabs_by_shape": max_grabs, "max_diff_by_shape": max_diff, "proofs": proofs}


func write_stats() -> void:
	if out_dir == "":
		return
	var f := FileAccess.open(out_dir.path_join("stats_%d.json" % miner_id), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(summary(), "  "))
		f.close()
