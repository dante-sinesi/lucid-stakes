extends RefCounted
## Constructor inverso de salas: se parte del final (el jugador a un paso de la salida, con la escalera armada) y se va hacia atrás, de a un movimiento. Cada paso propone un "movimiento invertido" (el contrario de
## empujar, tirar, caminar, saltar con una catapulta, patinar sobre hielo, pisar arenisca o pisar una trampa), que arma el estado anterior poniendo lo que ese movimiento necesita (el bloque que se empuja, la catapulta
## debajo, el hielo con su tope, el bloque agrietado...). Una propuesta sólo se acepta si el estado anterior es estable y si repitiendo hacia adelante todo el camino acumulado se llega a la salida: así la sala se resuelve
## por construcción y ninguna propuesta nueva puede arruinar a las anteriores. Los empujes y tirones eligen bloques que ya están (para que unos pocos bloques hagan todo el trabajo).
## El resultado es una sala resoluble con un camino conocido (cota superior): el verificador exacto mide después la dificultad real. Lo usa el minero (--reverse) y tests/exp_inverso.gd.

const RoomLib := preload("res://scripts/room_lib.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const K := TowerLogic.Kind
const DIRS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const UP := Vector3i(0, 1, 0)
const DOWN := Vector3i(0, -1, 0)

var rng := RandomNumberGenerator.new()
var weights := {"push": 6.0, "pull": 6.0, "walk": 1.5, "catapult": 1.5, "ice": 1.5, "cracked": 1.0, "trap": 1.0}
var last_why := ""
var cells := {}        # celdas de la arena
var h := 5
var room_exit := Vector2i.ZERO


func _init(seed_value := 1) -> void:
	rng.seed = seed_value


## Una sala de `shape` y `h` pisos con `grabs` empujes o tirones invertidos como mínimo (y hasta `max_steps` pasos). `base_cols`: la escalera de partida ({celda: columna}). Devuelve {room, path, grabs, specials} o {}.
func build(shape: String, height: int, base_cols: Dictionary, grabs: int, max_steps := 60, special_p := 0.35) -> Dictionary:
	h = height
	var room := RoomLib.make_room(shape, h)
	room.cols = base_cols.duplicate(true)
	room_exit = room.exit
	cells = {}
	for c in room.cells:
		cells[c] = true
	var t = RoomLib.build_state(room)
	# el último paso: parado sobre la columna más alta pegada al pilar, caminar hacia la salida
	var start := Vector3i(-999, 0, 0)
	var last_dir := Vector3i.ZERO
	for d in DIRS:
		var n := Vector2i(room.exit.x + d.x, room.exit.y + d.z)
		var ks: String = room.cols.get(n, "")
		if ks.length() >= h - 1 and h - 1 >= 1:
			start = Vector3i(n.x, h, n.y)
			last_dir = -d
	if start.x == -999:
		last_why = "sin_escalera"
		return {}
	t.player = start
	var path: Array = [{"dir": last_dir, "mode": TowerLogic.Mode.MOVE}]
	_normalize(t)
	if not _wins(t, path):
		last_why = "final_no_gana"
		return {}
	var done := 0
	var used := {}
	for step in max_steps:
		if done >= grabs and rng.randf() < 0.5:
			break
		var cands := _candidates(t, special_p)
		var picked := false
		while not cands.is_empty():
			var i := _pick(cands)
			var cd: Dictionary = cands[i]
			cands.remove_at(i)
			var sb = cd.state
			_normalize(sb)
			if not _inside(sb):
				continue
			if not _stable(sb):
				continue
			var trial: Array = [cd.action] + path
			if not _wins(sb, trial):
				continue
			t = sb
			path = trial
			if cd.kind == "push" or cd.kind == "pull":
				done += 1
			elif cd.kind != "walk":
				used[cd.kind] = int(used.get(cd.kind, 0)) + 1
			picked = true
			break
		if not picked:
			last_why = "sin_propuestas"
			break
	if done < grabs:
		last_why = "pocos_agarres"
		return {}
	# la sala: los bloques sueltos del estado alcanzado (sin el pilar de salida)
	var blocks: Array = []
	for c in t.blocks:
		if t.fixed.has(c) or c.y < 1 or Vector2i(c.x, c.z) == room_exit:
			continue
		blocks.append([c.x, c.y, c.z, t.kind_at(c)])
	var out := RoomLib.room_from_layout(room, blocks)
	return {"room": out, "path": path, "grabs": done, "specials": used, "player": t.player}


# --- propuestas --------------------------------------------------------------------------------------------------------------

func _pick(cands: Array) -> int:
	var total := 0.0
	for cd in cands:
		total += float(weights.get(cd.kind, 1.0)) * float(cd.get("w", 1.0))
	var roll := rng.randf() * total
	for i in cands.size():
		roll -= float(weights.get(cands[i].kind, 1.0)) * float(cands[i].get("w", 1.0))
		if roll <= 0.0:
			return i
	return cands.size() - 1


func _free(t, c: Vector3i) -> bool:
	return not t.blocks.has(c) and c.y >= 1


func _supported(t, c: Vector3i) -> bool:
	return t.blocks.has(c + DOWN)


func _candidates(t, special_p: float) -> Array:
	var out: Array = []
	var p: Vector3i = t.player
	var hanging: bool = t.hang_dir != Vector3i.ZERO
	for d in DIRS:
		# empujar al revés: el bloque está a dos celdas, una celda vacía en medio (antes estaba pegado y se empujó)
		if not hanging:
			var b2: Vector3i = p + d * 2
			var b1: Vector3i = p + d
			if t.blocks.has(b2) and not t.fixed.has(b2) and t.kind_at(b2) != K.HEAVY and _free(t, b1):
				var s = t.clone()
				s._move_block(b2, b1)
				out.append({"state": s, "action": {"dir": d, "mode": TowerLogic.Mode.GRAB}, "kind": "push", "w": 1.0 + _reuse(t, b2)})
			# tirar al revés: el jugador estaba una celda atrás y el bloque, otra más atrás
			var bb: Vector3i = p - d
			var bb2: Vector3i = p - d * 2
			if t.blocks.has(bb) and not t.fixed.has(bb) and t.kind_at(bb) != K.HEAVY and _free(t, bb2):
				var s2 = t.clone()
				s2._move_block(bb, bb2)
				s2.player = bb
				out.append({"state": s2, "action": {"dir": d, "mode": TowerLogic.Mode.GRAB}, "kind": "pull", "w": 1.0 + _reuse(t, bb)})
		# caminar al revés: a nivel, subiendo (venía de un piso más abajo) o bajando (venía de un piso más arriba)
		if not hanging:
			for dy in [0, -1, 1]:
				var p0: Vector3i = p - d + Vector3i(0, dy, 0)
				if _free(t, p0) and _supported(t, p0):
					var s3 = t.clone()
					s3.player = p0
					out.append({"state": s3, "action": {"dir": d, "mode": TowerLogic.Mode.MOVE}, "kind": "walk", "w": 0.3 + 6.0 / (1.0 + _near(t, p0))})
	if rng.randf() < special_p:
		_special_candidates(t, out)
	return out


## Cuántos movimientos ya se hicieron con este bloque no se sabe (el estado no lo guarda): se prefieren los bloques que tienen vecinos (los que ya forman parte de la estructura).
func _reuse(t, c: Vector3i) -> float:
	var n := 0
	for d in DIRS:
		if t.blocks.has(c + d):
			n += 1
	return float(n)


## Distancia (en celdas) del jugador al bloque suelto más cercano: caminar hacia los bloques lleva a más empujes y tirones.
func _near(t, c: Vector3i) -> float:
	var best := 99.0
	for b in t.blocks:
		if t.fixed.has(b) or Vector2i(b.x, b.z) == room_exit:
			continue
		best = minf(best, absf(float(b.x - c.x)) + absf(float(b.z - c.z)) + 0.5 * absf(float(b.y - c.y)))
	return best


func _special_candidates(t, out: Array) -> void:
	var p: Vector3i = t.player
	# catapulta: el jugador terminó colgado arriba; salió de pisar una catapulta unas celdas más abajo
	if t.hang_dir != Vector3i.ZERO:
		for m in range(1, 6):
			var tcell := Vector3i(p.x, p.y - m, p.z)
			if tcell.y < 2:
				continue
			for d in DIRS:
				var p0: Vector3i = tcell - d
				if _free(t, p0) and _supported(t, p0) and _free(t, tcell) and _free(t, tcell + DOWN):
					var s = t.clone()
					s.add_block(tcell + DOWN, false, K.CATAPULT)
					s.player = p0
					s.hang_dir = Vector3i.ZERO
					out.append({"state": s, "action": {"dir": d, "mode": TowerLogic.Mode.MOVE}, "kind": "catapult"})
	if t.hang_dir != Vector3i.ZERO:
		return
	for d in DIRS:
		# hielo: el jugador terminó de pie después de patinar L celdas
		for L in range(1, 5):
			var c0: Vector3i = p - d * L
			var ok := true
			for i in L:
				var ci: Vector3i = c0 + d * i
				if t.blocks.has(ci) or not t.blocks.has(ci + DOWN) or t.fixed.has(ci + DOWN) or t.kind_at(ci + DOWN) == K.ICE or ci.y < 1:
					ok = false
			var p0: Vector3i = c0 - d
			if ok and _free(t, p0) and _supported(t, p0) and t.blocks.has(p + DOWN):
				var s2 = t.clone()
				s2._own_maps()
				for i in L:
					var below: Vector3i = c0 + d * i + DOWN
					s2.kind_of[s2.blocks[below]] = K.ICE
				s2.recompute_zob()
				s2.player = p0
				out.append({"state": s2, "action": {"dir": d, "mode": TowerLogic.Mode.MOVE}, "kind": "ice"})
		# arenisca: el jugador pisó un bloque agrietado (que se rompió al bajarse) y siguió
		var q: Vector3i = p - d + DOWN
		if q.y >= 1 and not t.blocks.has(q) and _free(t, p - d):
			var s3 = t.clone()
			s3.add_block(q, false, K.CRACKED)
			s3.player = q + UP
			out.append({"state": s3, "action": {"dir": d, "mode": TowerLogic.Mode.MOVE}, "kind": "cracked"})
		# trampa: el jugador cayó dos o más celdas porque la trampa en la que había pisado se desarmó
		for m in range(1, 4):
			var tc: Vector3i = p + UP * m
			var p1: Vector3i = tc - d
			if tc.y >= 2 and _free(t, tc) and _free(t, tc + DOWN) and _free(t, p1) and _supported(t, p1):
				var clear := true
				for j in range(1, m + 1):
					if t.blocks.has(p + UP * j):
						clear = false
				if clear:
					var s4 = t.clone()
					s4.add_block(tc + DOWN, false, K.TRAP)
					s4.player = p1
					out.append({"state": s4, "action": {"dir": d, "mode": TowerLogic.Mode.MOVE}, "kind": "trap"})


# --- validación -------------------------------------------------------------------------------------------------------------

## Como una sala recién armada: sin la historia de qué bloques estuvieron apoyados (se marcan en la primera acción).
func _normalize(t) -> void:
	t._own_maps()
	t.standing = {}
	t._standing_ready = false
	t._blocks_dirty = true
	t.won = false
	t.lost = false


func _wins(s, actions: Array) -> bool:
	var t = s.clone()
	for a in actions:
		var r: Dictionary = t.try_action(a.dir, a.mode)
		if not r.ok or t.lost:
			return false
	return t.won


## Ningún bloque cae ni el jugador se cae al empezar.
func _stable(s) -> bool:
	var t = s.clone()
	var before: Dictionary = t.blocks.duplicate()
	var pl: Vector3i = t.player
	t.mark_standing()
	t._settle()
	return before.hash() == t.blocks.hash() and pl == t.player and not t.lost


## Los bloques sueltos quedan sobre la arena y por debajo de lo alto del pilar.
func _inside(s) -> bool:
	for c in s.blocks:
		if s.fixed.has(c):
			continue
		if Vector2i(c.x, c.z) == room_exit:
			continue
		if not cells.has(Vector2i(c.x, c.z)) or c.y < 1 or c.y > h - 1:
			return false
	return true
