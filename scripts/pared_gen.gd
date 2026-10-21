extends RefCounted
## EXPERIMENTO (aislado del juego): paredes colgantes. La salida es un bloque fijo en el borde de arriba (nunca cae) y todo lo demás cuelga de ella (o se apoya en lo que cuelga): un bloque se sostiene si
## una cadena de vecinos llega a una salida; si se mueve un eslabón, lo que cuelga de él cae al vacío. No hay suelo debajo de la pared: el piso es sólo una franja o un anillo de 1 bloque por donde camina el jugador.
##
## Dos formatos:
##  - "pared":    una pared plana de 6 de ancho, 2 de espesor y h de alto, con una franja de piso adelante (8x1). Es el modelo simple para analizar.
##  - "cilindro": la misma pared plegada en un anillo de 6x6 con el pozo vacío de 2x2 y un anillo de piso de 1 bloque (8x8, 28 celdas); con `caras` salidas, una por lado.
## Se arma como una sala común de la biblioteca (`floor_cells`, `exits_extra`) para usar el mismo simulador, el mismo A* exacto y las mismas métricas.

const RoomLib := preload("res://scripts/room_lib.gd")
const Conv := preload("res://scripts/convoy_gen.gd")

const SIX: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]


static func arena(kind: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in 8:
		for z in (4 if kind == "pared" else 8):
			out.append(Vector2i(x, z))
	return out


static func floor_cells(kind: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in arena(kind):
		if kind == "pared":
			if c.y == 0:
				out.append(c)
		elif c.x == 0 or c.x == 7 or c.y == 0 or c.y == 7:
			out.append(c)
	return out


## Las celdas donde puede haber bloques: la pared (12) o el anillo de 2 de espesor del cilindro (32).
static func mass(kind: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if kind == "pared":
		for x in range(1, 7):
			for z in range(1, 3):
				out.append(Vector2i(x, z))
	else:
		for x in range(1, 7):
			for z in range(1, 7):
				if x >= 3 and x <= 4 and z >= 3 and z <= 4:
					continue
				out.append(Vector2i(x, z))
	return out


## Las celdas del borde de arriba donde puede estar una salida, una por cara: [la de adelante (la que mira al piso), derecha, atrás, izquierda].
static func face_cells(kind: String, rng: RandomNumberGenerator) -> Array[Vector2i]:
	if kind == "pared":
		return [Vector2i(rng.randi_range(1, 6), 1)]
	return [Vector2i(rng.randi_range(2, 5), 1), Vector2i(6, rng.randi_range(2, 5)), Vector2i(rng.randi_range(2, 5), 6), Vector2i(1, rng.randi_range(2, 5))]


## Una pared al azar con `n` bloques colgando de las salidas. `faces` = cuántas salidas (1 o 4).
static func make(rng: RandomNumberGenerator, kind: String, h: int, n: int, faces: int) -> Dictionary:
	var room := RoomLib.make_room("3x3", h)
	room.shape = "P6" if kind == "pared" else "C6H"
	room.cells = arena(kind)
	room["floor_cells"] = floor_cells(kind)
	room.entry = Vector2i(-1, 0) if kind == "pared" else Vector2i(-1, 3)
	room["exit_solo"] = true
	room["mass"] = mass(kind)
	var exits: Array[Vector2i] = face_cells(kind, rng)
	if faces == 1:
		exits = [exits[0]]
	room.exit = exits[0]
	var extra: Array[Vector2i] = []
	for i in range(1, exits.size()):
		extra.append(exits[i])
	room["exits_extra"] = extra
	var allowed := {}
	for c in room.mass:
		allowed[c] = true
	var blocks := {}
	var list: Array = []
	for e in exits:
		list.append(Vector3i(e.x, h, e.y))
	var placed := 0
	var guard := 0
	while placed < n and guard < n * 60:
		guard += 1
		var base: Vector3i = list[rng.randi_range(0, list.size() - 1)]
		var q: Vector3i = base + SIX[rng.randi_range(0, SIX.size() - 1)]
		var c := Vector2i(q.x, q.z)
		if not allowed.has(c) or q.y < 1 or q.y > h - 1 or blocks.has(q) or (c - room.entry).length() < 1.5:
			continue
		blocks[q] = true
		list.append(q)
		placed += 1
	room["cols"] = cols_from_set(blocks)
	room.origin = "cilindro"
	return room


static func block_set(room: Dictionary) -> Dictionary:
	var out := {}
	for c in room.cols:
		var text: String = room.cols[c]
		for i in text.length():
			if text[i] != RoomLib.GAP:
				out[Vector3i(c.x, i + 1, c.y)] = true
	return out


static func cols_from_set(blocks: Dictionary) -> Dictionary:
	var tops := {}
	for q in blocks:
		var c := Vector2i(q.x, q.z)
		tops[c] = maxi(int(tops.get(c, 0)), q.y)
	var cols := {}
	for c in tops:
		var text := ""
		for y in range(1, int(tops[c]) + 1):
			text += "n" if blocks.has(Vector3i(c.x, y, c.y)) else RoomLib.GAP
		cols[c] = text
	return cols


## Un cambio al azar: un bloque cualquiera pasa a un lugar pegado a otro (de cualquier lado).
static func mutate(rng: RandomNumberGenerator, room: Dictionary) -> Dictionary:
	var blocks := block_set(room)
	if blocks.size() < 3:
		return {}
	var keys: Array = blocks.keys()
	var q: Vector3i = keys[rng.randi_range(0, keys.size() - 1)]
	blocks.erase(q)
	keys = blocks.keys()
	var base: Vector3i = keys[rng.randi_range(0, keys.size() - 1)]
	if rng.randf() < 0.25:   # (a veces se parte de una salida: así las cadenas nuevas cuelgan de ella)
		var exits: Array = [room.exit] + Array(room.get("exits_extra", []))
		var e: Vector2i = exits[rng.randi_range(0, exits.size() - 1)]
		base = Vector3i(e.x, int(room.h), e.y)
	var r: Vector3i = base + SIX[rng.randi_range(0, SIX.size() - 1)]
	var c := Vector2i(r.x, r.z)
	if not (room.get("mass", []) as Array).has(c) or r.y < 1 or r.y > int(room.h) - 1 or blocks.has(r) or r == q or (c - room.entry).length() < 1.5:
		return {}
	blocks[r] = true
	var out := RoomLib.copy_room(room)
	out["cols"] = cols_from_set(blocks)
	return out


## Cuánto cuesta (A* exacto) llegar a cada salida: [{ok, moves, grabs, blocks}] por cara. Con una sola salida, una sola entrada.
static func face_costs(room: Dictionary, cap := 300000, ms := 4000) -> Array:
	var exits: Array = [room.exit] + Array(room.get("exits_extra", []))
	var out: Array = []
	for i in exits.size():
		var v := RoomLib.copy_room(room)
		v.exit = exits[i]
		var others: Array[Vector2i] = []
		for j in exits.size():
			if j != i:
				others.append(exits[j])
		v["exits_extra"] = others
		v["goal_first_only"] = true
		var ev: Dictionary = Conv.evaluate(v, cap, ms)
		if ev.is_empty():
			out.append({"ok": false, "moves": -1, "grabs": 0, "blocks": 0})
		else:
			out.append({"ok": true, "moves": int(ev.opt.moves), "grabs": int(ev.opt.grabs), "blocks": int(ev.opt.blocks), "switches": int(ev.opt.switches), "path": ev.path})
	return out


## Puntaje de una pared: con una salida, pasos + empujes + bloques distintos + cambios de bloque del camino; con varias, la suma de las caras que se resuelven más lo que se separan en costo.
static func score(room: Dictionary, costs: Array) -> float:
	var total := 0.0
	var lo := 9999
	var hi := 0
	var solved := 0
	for c in costs:
		if not c.ok:
			continue
		solved += 1
		total += float(c.moves) + 3.0 * float(c.grabs) + 4.0 * float(c.blocks) + 2.0 * float(c.get("switches", 0))
		lo = mini(lo, int(c.moves))
		hi = maxi(hi, int(c.moves))
	if solved == 0:
		return -1.0
	if costs.size() > 1:
		total += 40.0 * float(solved) + 2.0 * float(hi - lo)
	return total


## Escalada: se parte de una pared que ya se resuelve por alguna cara y se la cambia quedándose con los cambios que la dejan sostenida, resoluble y de mayor puntaje.
static func climb(rng: RandomNumberGenerator, start: Dictionary, budget_ms: int) -> Dictionary:
	var costs := face_costs(start)
	var best_score := score(start, costs)
	if best_score < 0.0:
		return {}
	var best := start
	var best_costs := costs
	var t0 := Time.get_ticks_msec()
	var tries := 0
	var accepted := 0
	while Time.get_ticks_msec() - t0 < budget_ms:
		tries += 1
		var cand := mutate(rng, best)
		if cand.is_empty() or RoomLib.validate_structure(cand) != "":
			continue
		var cc := face_costs(cand)
		var sc := score(cand, cc)
		if sc >= best_score:
			if sc > best_score:
				accepted += 1
			best = cand
			best_costs = cc
			best_score = sc
	var out := RoomLib.copy_room(best)
	out["costs"] = best_costs
	out.opt["tries"] = tries
	out.opt["accepted"] = accepted
	out.opt["score"] = int(best_score)
	return out
