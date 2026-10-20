extends RefCounted
## Salas "al revés" (prototipo para las formas L y U): en vez de buscar una sala y excavar cerca de su camino, se parte del estado RESUELTO (la escalera ya armada junto al pilar de
## salida, el jugador arriba) y se juega hacia atrás con movimientos que se pueden deshacer (caminar, empujar y tirar, comprobado con las reglas del juego). Los bloques de la escalera
## se van llevando lejos del pilar, así que para resolverla hay que traerlos de vuelta desde todos lados: el recorrido ocupa toda la arena y el puzzle es uno solo. Después el
## A* exacto verifica la sala y mide cuánto se entrelaza el camino (ver `metrics`).
##
## Ideas (cómo se desordena):
##  - dispersion:  los bloques se alejan del pilar en cualquier dirección.
##  - convoy:      un bloque "clave" se aleja mucho (todo el brazo) y los demás se mueven poco: hay que traer ese bloque de lejos y se usa para cruzar.
##  - barrera:     además se cierran los pasillos de la arena con una pared de bloques pesados con un solo paso: la escalera se arma de a una pieza y hay que pasar los bloques por el hueco.

const RoomLib := preload("res://scripts/room_lib.gd")
const Solver := preload("res://scripts/solver.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const K := TowerLogic.Kind

const IDEAS: Array[String] = ["dispersion", "convoy", "barrera"]
const IDEA_NAMES := {"dispersion": "Dispersión", "convoy": "Convoy", "barrera": "Barrera"}
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
static var last_info := {}
const MODES: Array = [TowerLogic.Mode.MOVE, TowerLogic.Mode.GRAB]


static func shapes_for(_idea: String) -> Array:
	return ["L", "U"]


static func heights_for(_idea: String) -> Array:
	return [5, 6, 7]


## Las celdas de la arena a las que se llega desde la salida (sin atravesar el core), con su distancia a pie.
static func _dist_from_exit(room: Dictionary) -> Dictionary:
	var inside := {}
	for c in room.cells:
		inside[c] = true
	var dist := {room.exit: 0}
	var queue: Array = [room.exit]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in DIRS:
			var n: Vector2i = c + d
			if inside.has(n) and not dist.has(n):
				dist[n] = int(dist[c]) + 1
				queue.append(n)
	return dist


## El estado resuelto: una escalera de h - 1 columnas (cada una un bloque más baja que la anterior, desde el pilar hacia afuera) y el jugador parado en el tope del pilar.
static func goal_state(rng: RandomNumberGenerator, room: Dictionary, idea: String) -> Dictionary:
	var h: int = room.h
	var dist := _dist_from_exit(room)
	var free := RoomLib.free_cells(str(room.shape))
	var cols := {}
	var cur: Vector2i = room.exit
	var used := {room.exit: true}
	for level in range(h - 1, 0, -1):
		var opts: Array = []
		for d in DIRS:
			var n: Vector2i = cur + d
			if free.has(n) and not used.has(n) and int(dist.get(n, 0)) == int(dist[cur]) + 1:
				opts.append(n)
		if opts.is_empty():
			return {}
		cur = opts[rng.randi_range(0, opts.size() - 1)]
		used[cur] = true
		cols[cur] = "n".repeat(level)
	# material de más: unos bloques sueltos (hacen falta para que haya con qué maniobrar)
	var extra := rng.randi_range(2, 5)
	var tries := 0
	while extra > 0 and tries < 60:
		tries += 1
		var c: Vector2i = free[rng.randi_range(0, free.size() - 1)]
		if used.has(c) or int(dist.get(c, 0)) < 3:
			continue
		used[c] = true
		cols[c] = "n"
		extra -= 1
	if idea == "barrera":
		_wall(rng, room, cols, used, dist)
	room["cols"] = cols
	var t = RoomLib.build_state(room)
	t.player = Vector3i(room.exit.x, h + 1, room.exit.y)
	return {"room": room, "state": t}


## Una pared de pesados que cruza un brazo de la arena, con un solo paso libre.
static func _wall(rng: RandomNumberGenerator, room: Dictionary, cols: Dictionary, used: Dictionary, dist: Dictionary) -> void:
	var free := RoomLib.free_cells(str(room.shape))
	var maxd := 0
	for c in free:
		maxd = maxi(maxd, int(dist.get(c, 0)))
	var want := rng.randi_range(maxi(int(maxd * 0.45), 4), maxi(int(maxd * 0.7), 5))
	var line: Array = []
	for c in free:
		if int(dist.get(c, 0)) == want and not used.has(c):
			line.append(c)
	if line.size() < 2:
		return
	line.shuffle()
	for i in range(1, line.size()):   # (la primera queda libre: el único paso)
		cols[line[i]] = "h"
		used[line[i]] = true


## Los bloques sueltos tienen que quedar adentro de la arena y lejos de la llegada (si no, la sala no se puede guardar).
static func _inside_ok(t, room: Dictionary) -> bool:
	var inside := _inside_set(room)
	for id in t.positions:
		var p: Vector3i = t.positions[id]
		if t.fixed.has(p) or p.y < 1:
			continue
		var c := Vector2i(p.x, p.z)
		if c == room.exit:
			continue
		if not inside.has(c) or (c - room.entry).length() < 1.5:
			return false
	return true


static var _inside_cache := {}


static func _inside_set(room: Dictionary) -> Dictionary:
	var key := str(room.shape)
	if not _inside_cache.has(key):
		var d := {}
		for c in room.cells:
			d[c] = true
		_inside_cache[key] = d
	return _inside_cache[key]


static func _same(a, b) -> bool:
	return a.player == b.player and a.hang_dir == b.hang_dir and a.positions == b.positions


## Juega `steps` movimientos hacia atrás desde el estado resuelto. Devuelve la sala (con el jugador en la llegada) o {} si no se pudo.
static func scramble(rng: RandomNumberGenerator, shape: String, h: int, idea: String, steps: int) -> Dictionary:
	var room := RoomLib.make_room(shape, h)
	room.origin = "convoy"
	var g := goal_state(rng, room, idea)
	last_info = {"goal": not g.is_empty(), "done": 0, "stuck": 0}
	if g.is_empty():
		return {}
	var s = g.state
	var exit: Vector2i = room.exit
	var seen := {Solver.state_key(s): true}
	var seen_blocks := {Vector2i(Solver.state_key(s).x, Solver.state_key(s).y): true}
	var key_block := -1
	if idea == "convoy":   # el bloque clave: uno de los de la escalera, el más lejos
		var best := -1.0
		for id in s.positions:
			var p: Vector3i = s.positions[id]
			if s.fixed.has(p) or room.cols.has(Vector2i(p.x, p.z)) == false:
				continue
			var dd := float(absi(p.x - exit.x) + absi(p.z - exit.y)) + rng.randf()
			if dd > best:
				best = dd
				key_block = id
	var done := 0
	var stuck := 0
	while done < steps and stuck < 30:
		var cands: Array = []
		for d in DIRS:
			for m in MODES:
				var a := {"dir": Vector3i(d.x, 0, d.y), "mode": m}
				var p = s.clone()
				var r: Dictionary = p.try_action(a.dir, a.mode)
				if not r.ok or p.lost or p.won:
					continue
				var k: Vector3i = Solver.state_key(p)
				if p.positions.size() != s.positions.size():   # (un bloque cayó al vacío: no se puede deshacer)
					continue
				if not _inside_ok(p, room):
					continue
				var mv := false
				for id2 in s.positions:
					if p.positions[id2] != s.positions[id2]:
						mv = true
						break
				if mv:
					last_info["push_ok"] = int(last_info.get("push_ok", 0)) + 1
				if not _reversible(p, s, 2 if mv else 1):   # (empujar no mueve al jugador y tirar sí: deshacer un empuje cuesta dos acciones)
					if mv:
						last_info["push_nonrev"] = int(last_info.get("push_nonrev", 0)) + 1
					continue
				var moved := -1
				for id in s.positions:
					if p.positions[id] != s.positions[id]:
						moved = id
						break
				var w := 0.12   # (caminar casi no cuenta: lo que desordena es mover bloques)
				if moved >= 0:
					var before: Vector3i = s.positions[moved]
					var after: Vector3i = p.positions[moved]
					var away := float(absi(after.x - exit.x) + absi(after.z - exit.y) - absi(before.x - exit.x) - absi(before.z - exit.y))
					w = 8.0 if away > 0.0 else (0.15 if away == 0.0 else 0.02)   # (los bloques se alejan del pilar y casi nunca vuelven)
					if seen_blocks.has(Vector2i(k.x, k.y)):
						w *= 0.04   # (volver a una disposición de bloques ya vista deshace lo hecho)
					if idea == "convoy":
						w = w * (4.0 if moved == key_block else 0.25)
					w = maxf(w, 0.3)
				if seen.has(k):
					w *= 0.06   # (volver a un estado ya visto se puede, pero casi nunca: si no, el recorrido se encierra)
				cands.append([p, w])
		if cands.is_empty():
			stuck += 1
			if stuck == 1:
				last_info["at"] = str(s.player)
				var info: Array = []
				for d in DIRS:
					for m in MODES:
						var p2 = s.clone()
						var r2: Dictionary = p2.try_action(Vector3i(d.x, 0, d.y), m)
						info.append("%s%d:%s%s%s" % [str(d), m, "ok" if r2.ok else "no", ("/vistos" if seen.has(Solver.state_key(p2)) else ""), ("/rev" if r2.ok and _reversible(p2, s) else "")])
				last_info["acc"] = info
			continue
		var total := 0.0
		for c in cands:
			total += float(c[1])
		var pick := rng.randf() * total
		var chosen = cands[cands.size() - 1][0]
		for c in cands:
			pick -= float(c[1])
			if pick <= 0.0:
				chosen = c[0]
				break
		s = chosen
		seen[Solver.state_key(s)] = true
		seen_blocks[Vector2i(Solver.state_key(s).x, Solver.state_key(s).y)] = true
		done += 1
	last_info["done"] = done
	last_info["stuck"] = stuck
	if done < steps / 3:
		return {}
	return _to_room(room, s)


## ¿Se puede volver de `p` a `s` con `depth` acciones o menos? (es lo que hace que el movimiento hacia atrás sea un movimiento válido hacia adelante)
static func _reversible(p, s, depth := 1) -> bool:
	for d in DIRS:
		for m in MODES:
			var q = p.clone()
			var r: Dictionary = q.try_action(Vector3i(d.x, 0, d.y), m)
			if not r.ok or q.lost:
				continue
			if _same(q, s):
				return true
			if depth > 1 and _reversible(q, s, depth - 1):
				return true
	return false


## La sala que sale del estado desordenado: las columnas son los bloques sueltos donde quedaron; el jugador empieza en la llegada.
static func _to_room(room: Dictionary, s) -> Dictionary:
	var inside := {}
	for c in room.cells:
		inside[c] = true
	var rows := {}   # celda -> {nivel: tipo}
	for id in s.positions:
		var p: Vector3i = s.positions[id]
		if s.fixed.has(p) or p.y < 1:
			continue
		var c := Vector2i(p.x, p.z)
		if c == room.exit:
			continue
		if not inside.has(c):
			return {}
		if not rows.has(c):
			rows[c] = {}
		rows[c][p.y] = RoomLib.CHAR_OF_KIND.get(s.kind_at(p), "n")
	var cols := {}
	for c in rows:
		var top := 0
		for y in rows[c]:
			top = maxi(top, int(y))
		var text := ""
		for y in range(1, top + 1):
			text += str(rows[c].get(y, RoomLib.GAP))
		cols[c] = text
	room["cols"] = cols
	return room


## Cuánto se entrelaza y se reparte el camino de una sala resuelta: bloques distintos movidos, cuántas veces se cambia de bloque, cuántos empujes en total, cuánto se camina antes
## del primer agarre y qué parte de la arena toca el puzzle.
static func metrics(room: Dictionary) -> Dictionary:
	var t = RoomLib.build_state(room)
	var last_id := -1
	var switches := 0
	var grabs := 0
	var first_grab := -1
	var per_block := {}
	var touched := {}
	var step := 0
	for a in room.path:
		var before: Dictionary = t.positions.duplicate()
		t.try_action(a.dir, a.mode)
		if a.mode == TowerLogic.Mode.GRAB:
			for id in t.positions:
				if t.positions[id] != before[id] and not t.fixed.has(before[id]):
					grabs += 1
					if first_grab < 0:
						first_grab = step
					per_block[id] = int(per_block.get(id, 0)) + 1
					if id != last_id:
						switches += 1
						last_id = id
					touched[Vector2i(before[id].x, before[id].z)] = true
					touched[Vector2i(t.positions[id].x, t.positions[id].z)] = true
					break
		step += 1
	var most := 0
	for id in per_block:
		most = maxi(most, int(per_block[id]))
	var spread := float(touched.size()) / float(maxi(room.cells.size(), 1))
	return {"grabs": grabs, "blocks": per_block.size(), "switches": switches, "first_grab": first_grab, "most": most, "spread": spread, "walk": float(maxi(first_grab, 0)) / float(maxi(room.path.size(), 1))}
