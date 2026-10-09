extends RefCounted
## Pista del modo entrenamiento: el mejor próximo movimiento desde el estado actual.
##
## Se resuelve con el mismo solucionador que usa el generador, pero sobre una ventana de capas alrededor del personaje
## (resolver las 25 capas de golpe sería inabarcable): "llegar `k` pisos más arriba". Con k = 1 sale casi al instante; con
## k = 2 y 3 la pista tiene más visión (evita callejones sin salida) pero tarda más. Cuando la meta (el bloque-portal)
## queda a menos de `k` pisos se resuelve directamente hasta pararse en el portal.

const TowerLogic := preload("res://scripts/tower_logic.gd")
const Solver := preload("res://scripts/solver.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const Loc := preload("res://scripts/loc.gd")

const LEVELS := [1, 2, 3]            # cuántos pisos mirar hacia adelante, de menos a más
const MAX_STATES := {1: 6000, 2: 9000, 3: 12000}


## Pista exacta usando la estructura de la torre generada: llegar a la plataforma de la fila que toca (la misma pregunta
## que le hizo el generador al solucionador), o al bloque-portal en la última. Devuelve {status, moves, path, k: 0}; si la
## torre no trae plataformas por fila (torres de prueba) devuelve status "none".
static func solve_row(src, max_states := 9000) -> Dictionary:
	# Objetivo: la plataforma de la fila siguiente a la más alta que ya se pisó (no cambia si el camino exige bajar un escalón).
	var row: int = mini(src.reached_row + 1, src.goal_y - 1) if not src.platform_row.is_empty() else src.player.y
	if row >= src.goal_y or not src.row_platforms.has(row):
		return {"status": "none", "moves": -1, "path": [], "k": 0}
	var ids := {}
	if row == src.goal_y - 1 and src.goal_block >= 0:
		ids[src.goal_block] = true  # la última fila termina en el portal, no en cualquier bloque de su plataforma
	else:
		for id in src.row_platforms[row]:
			ids[id] = true
	var w = Gen._window(src, row, ids)
	var res := Solver.solve(w, row + 1, {"max_states": max_states, "goal_ids": w.goal_ids, "prefer_plain": true})
	return {"status": res.status, "moves": res.moves, "path": res.path, "k": 0}


## Ventana de `src` desde 3 capas por debajo del personaje hasta `k` por encima. Si la meta cae dentro, se gana sólo
## parado en el bloque-portal.
static func window_up(src, k: int):
	var y0: int = src.player.y
	var top := mini(y0 + k, src.goal_y)
	var w = TowerLogic.new()
	w.size = src.size
	w.collapse_every = 1 << 30
	w.moves_to_collapse = 1 << 30
	w.floor_y = maxi(y0 - 4, 0)
	for c in src.blocks:
		if c.y >= y0 - 3 and c.y <= top:
			var id: int = src.blocks[c]
			if id == src.goal_block and top >= src.goal_y:
				w.goal_ids[w._next_id] = true
			w.add_block(c, src.fixed.has(c), src.kind_of.get(id, TowerLogic.Kind.NORMAL), src.bomb_timer.get(id, 0))
	w.player = src.player
	w.hang_dir = src.hang_dir
	w.goal_y = top
	return w


## Resuelve "llegar k pisos más arriba" desde `src`. Devuelve {status, moves, path, k}; el primer paso de `path` es la pista.
static func solve_levels(src, k: int) -> Dictionary:
	var w = window_up(src, k)
	var res := Solver.solve(w, w.goal_y, {"max_states": MAX_STATES[k], "goal_ids": w.goal_ids, "prefer_plain": true})
	return {"status": res.status, "moves": res.moves, "path": res.path, "k": k}


## Mejor próximo movimiento: {ok, dir, mode, moves, k} o {ok: false}. Toma la solución más profunda que se resuelva.
static func best_move(src) -> Dictionary:
	if src.won or src.lost:
		return {"ok": false}
	var row := solve_row(src)
	if row.status == "solved" and not row.path.is_empty():
		var a0: Dictionary = row.path[0]
		return {"ok": true, "dir": a0.dir, "mode": a0.mode, "moves": row.moves, "k": 0}
	var best := {}
	for k in LEVELS:
		var res := solve_levels(src, k)
		if res.status == "solved" and not res.path.is_empty():
			best = res
		elif res.status == "solved":
			break  # ya está en la meta
	if best.is_empty():
		return {"ok": false}
	var a: Dictionary = best.path[0]
	return {"ok": true, "dir": a.dir, "mode": a.mode, "moves": best.moves, "k": best.k}


## Texto de la tecla: "W", "Shift + W" o "Espacio + W" según el modo. `key_for_dir` es una Callable(dir) -> String (la letra
## que mueve hacia esa dirección con la cámara actual).
static func describe(mode: int, dir: Vector3i, key_for_dir: Callable) -> String:
	var key: String = key_for_dir.call(dir)
	match mode:
		TowerLogic.Mode.GRAB:
			return Loc.f("Shift + %s", [key])
		TowerLogic.Mode.HANG:
			return Loc.f("Espacio + %s", [key])
	return key
