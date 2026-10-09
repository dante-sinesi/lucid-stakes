extends RefCounted
## Solucionador: mínimo de movimientos para que el jugador llegue a una altura (A*, costo 1 por acción).
## La heurística es la altura que falta dividida por lo máximo que puede subir una acción:
## 1 (trepar), o el impulso de la catapulta + 1 si hay catapultas en el estado inicial.
## (Se puede desactivar con opts.heuristic = false.)
##
## opts:
##   max_states   (int, 300000)  tope de estados generados; al superarlo devuelve "limit"
##   use_collapse (bool, false)  simular la caída de la fila base (el estado incluye el contador)
##   heuristic    (bool, true)
##   prefer_plain (bool, false) entre caminos del mismo largo prefiere el que usa menos empujar/tirar/colgarse (desempate; no cambia el largo)
##   goal_ids     (Dictionary, {}) ganar sólo parado sobre alguno de estos bloques (ids del estado inicial)
##   no_grab      (bool, false) prohibir empujar y tirar de bloques (sirve para saber si una fila EXIGE mover bloques)

const TowerLogic := preload("res://scripts/tower_logic.gd")
const MODES := [TowerLogic.Mode.MOVE, TowerLogic.Mode.GRAB, TowerLogic.Mode.HANG]


## Tiempo total (µs) que se pasó resolviendo (para medir cuánto de la generación es del solucionador; ver tests/bench).
static var total_usec := 0


## Devuelve {status: "solved"|"unsolvable"|"limit", moves, path: Array[Dictionary(dir, mode)], states, state}.
static func solve(start, target_y: int, opts: Dictionary = {}) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var res := _solve(start, target_y, opts)
	total_usec += Time.get_ticks_usec() - t0
	return res


static func _solve(start, target_y: int, opts: Dictionary) -> Dictionary:
	var max_states: int = opts.get("max_states", 300000)
	var use_collapse: bool = opts.get("use_collapse", false)
	var use_h: bool = opts.get("heuristic", true)
	var no_grab: bool = opts.get("no_grab", false)
	var unit := 16 if opts.get("prefer_plain", false) else 1  # con desempate cada acción vale 16 y empujar/tirar/colgarse 17

	var root = _prepare(start, target_y, use_collapse)
	root.recompute_zob()
	root.goal_ids = opts.get("goal_ids", {})
	var gain := _max_gain(root)
	var xz_goal: bool = not root.goal_ids.is_empty() and gain == 1 and not _has_ice(root)
	if root.lost:
		return {"status": "unsolvable", "moves": -1, "path": [], "states": 0, "state": root}

	var states: Array = [root]
	var parents := PackedInt32Array([-1])
	var actions := PackedInt32Array([-1])
	var gs := PackedInt32Array([0])
	var best := {_key(root, use_collapse): 0}
	var buckets := {}
	var f0 := _h(root, target_y, use_h, gain, xz_goal) * unit
	buckets[f0] = [0]
	var f := f0
	var open := 1
	var generated := 1

	while open > 0:
		if not buckets.has(f) or buckets[f].is_empty():
			f += 1
			continue
		var idx: int = buckets[f].pop_back()
		open -= 1
		var s = states[idx]
		if s.won:
			var found := _path(idx, parents, actions)
			return {"status": "solved", "moves": found.size(), "path": found, "states": generated, "state": s}
		var g := gs[idx]
		var list: Array = [TowerLogic.Mode.MOVE] if s.hang_dir != Vector3i.ZERO else MODES
		if no_grab:
			list = list.filter(func(m): return m != TowerLogic.Mode.GRAB)
		for di in TowerLogic.DIRS.size():
			var dd: Vector3i = TowerLogic.DIRS[di]
			for mode in list:
				# Descarte barato de acciones imposibles (evita clonar el estado para nada).
				if mode == TowerLogic.Mode.GRAB and not (s.blocks.has(s.player + dd) or s.blocks.has(s.player - dd)):
					continue
				if mode == TowerLogic.Mode.HANG:
					var ht: Vector3i = s.player + dd
					if s.blocks.has(ht) or s.blocks.has(ht + TowerLogic.DOWN) or s.blocks.has(ht + TowerLogic.DOWN * 2):
						continue
				var n = s.clone()
				if not n.try_action(TowerLogic.DIRS[di], mode).ok or n.lost:
					continue
				var key := _key(n, use_collapse)
				var step0 := unit + (1 if unit > 1 and mode != TowerLogic.Mode.MOVE else 0)
				if best.has(key) and best[key] <= g + step0:
					continue
				var step := unit + (1 if unit > 1 and mode != TowerLogic.Mode.MOVE else 0)
				best[key] = g + step
				states.append(n)
				parents.append(idx)
				actions.append(di * 3 + mode)
				gs.append(g + step)
				var ni := states.size() - 1
				var nf := g + step + _h(n, target_y, use_h, gain, xz_goal) * unit
				if not buckets.has(nf):
					buckets[nf] = []
				buckets[nf].append(ni)
				open += 1
				generated += 1
				if generated >= max_states:
					return {"status": "limit", "moves": -1, "path": [], "states": generated, "state": null}
		states[idx] = null  # ya expandido: liberar memoria
	return {"status": "unsolvable", "moves": -1, "path": [], "states": generated, "state": null}


static func _prepare(start, target_y: int, use_collapse: bool):
	var s = start.clone()
	s.won = false
	s.lazy_settle = true   # los estados del solucionador sólo cambian bloques a través de la lógica: se evita revisar el apoyo de todos en cada paso
	s.track_purify = false  # la claridad no cambia la dinámica (sí desactivar bombas, que se sigue haciendo)
	s.goal_y = target_y
	if target_y != start.goal_y:
		s.goal_block = -1  # metas intermedias (por fila): basta con la altura
	if not use_collapse:
		s.collapse_every = 1 << 30
		s.moves_to_collapse = 1 << 30
	return s


## Perfil de dificultad por fila a partir de UN camino óptimo global hasta start.goal_y: cada
## entrada son los movimientos entre una subida de altura y la siguiente. La suma es el mínimo
## total. {status, rows: Array[int], total, states}.
static func solve_rows(start, opts: Dictionary = {}) -> Dictionary:
	var res := solve(start, start.goal_y, opts)
	if res.status != "solved":
		return {"status": res.status, "rows": [], "total": -1, "states": res.states}
	var s = _prepare(start, start.goal_y, opts.get("use_collapse", false))
	var rows: Array[int] = []
	var best_y: int = s.player.y
	var last := 0
	for i in res.path.size():
		s.try_action(res.path[i].dir, res.path[i].mode)
		if s.player.y > best_y:
			best_y = s.player.y
			rows.append(i + 1 - last)
			last = i + 1
	if last < res.path.size() and not rows.is_empty():
		rows[rows.size() - 1] += res.path.size() - last
	return {"status": "solved", "rows": rows, "total": res.moves, "states": res.states}


## Aproximación barata para torres grandes: resuelve fila por fila, cada una desde el estado en
## que dejó la anterior. Sobrestima: el mínimo global puede ser menor (la solución óptima de una
## fila puede dejar al jugador mal parado para la siguiente). {status, rows, total, states}.
static func solve_rows_greedy(start, opts: Dictionary = {}) -> Dictionary:
	var state = start.clone()
	var rows: Array[int] = []
	var total_states := 0
	var target: int = state.player.y + 1
	while target <= start.goal_y:
		var res := solve(state, target, opts)
		total_states += res.states
		if res.status != "solved":
			return {"status": res.status, "rows": rows, "total": -1, "states": total_states}
		rows.append(res.moves)
		state = res.state
		state.won = false
		target = state.player.y + 1
	var total := 0
	for m in rows:
		total += m
	return {"status": "solved", "rows": rows, "total": total, "states": total_states}


static func _h(s, target_y: int, use_h: bool, gain: int, xz_goal := false) -> int:
	if not use_h:
		return 0
	var h := ceili(float(maxi(0, target_y - s.player.y)) / gain)
	if xz_goal:
		# Hay que terminar parado sobre uno de los bloques-meta. Sin hielo ni catapultas, cada acción acerca al jugador (o al
		# bloque meta) como mucho 1 celda en distancia de Chebyshev (las esquinas colgado cuentan 1 en cada eje), así que
		# esa distancia al bloque meta más cercano es una cota que no sobrestima (y es consistente).
		var best := 1000
		for id in s.goal_ids:
			if s.positions.has(id):
				var p: Vector3i = s.positions[id]
				best = mini(best, maxi(absi(p.x - s.player.x), absi(p.z - s.player.z)))
		h = maxi(h, best)
	return h


## Cuánto puede subir el jugador en una sola acción: trepar (1) o, con catapultas, trepar a la
## catapulta (1) + su impulso vertical.
static func _has_ice(s) -> bool:
	for id in s.kind_of:
		if s.kind_of[id] == TowerLogic.Kind.ICE:
			return true
	return false


static func _max_gain(s) -> int:
	for id in s.kind_of:
		if s.kind_of[id] == TowerLogic.Kind.CATAPULT:
			return TowerLogic.CATAPULT_RISE + 1
	return 1


static func _path(idx: int, parents: PackedInt32Array, actions: PackedInt32Array) -> Array:
	var path: Array = []
	while parents[idx] != -1:
		var a := actions[idx]
		path.push_front({"dir": TowerLogic.DIRS[a / 3], "mode": a % 3})
		idx = parents[idx]
	return path


static func _enc(c: Vector3i) -> int:
	# Los bloques empujados pueden salir de la huella (x, z negativas o mayores que el tamaño): por eso el desplazamiento.
	return (c.x + 8) + 64 * ((c.z + 8) + 64 * (c.y + 64))


static func _key(s, use_collapse: bool) -> Vector3i:
	var h: int = s.zob  # bloques y tipos (los fijos son constantes: no cambian la identidad del estado)
	for id in s.bomb_timer:  # cuenta de cada bomba, atada a su posición
		h ^= TowerLogic.zob_hash(s.positions[id], 40 + clampi(s.bomb_timer[id], 0, 200))
	if use_collapse:
		h ^= TowerLogic.zob_hash(Vector3i(s.moves_to_collapse & 31, s.floor_y & 63, 0), 300 + (s.moves_to_collapse >> 5))
	return Vector3i(h & 0xFFFFFFFF, (h >> 32) & 0xFFFFFFFF, _enc(s.player) * 27 + _enc_dir(s.hang_dir))


static func _enc_dir(d: Vector3i) -> int:
	return (d.x + 1) + 3 * ((d.y + 1) + 3 * (d.z + 1))
