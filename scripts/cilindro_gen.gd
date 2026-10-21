extends RefCounted
## EXPERIMENTO (aislado del juego): el "cilindro". Una masa de 6x6 bloques de base y altura h con el core de 2x2 en el medio (queda un anillo de espesor 2, como el muro de Catherine enrollado), apoyada en un
## piso de un bloque de espesor que la rodea. El jugador llega por afuera (sobre el piso) y sube moviendo los bloques de la masa; la meta es la cima de un pilar fijo que está en el anillo.
## Se arma como una sala común de la biblioteca (forma "C6", arena de 8x8 menos el core) para usar el mismo simulador, el mismo A* exacto y las mismas métricas.
##
## Variantes de masa (cómo se arman las alturas de las columnas):
##  - muro:   casi todas las columnas llenas (h - 1) con unos pocos huecos: hay que sacar bloques para abrirse paso.
##  - mixto:  columnas llenas con probabilidad `p` y el resto de alturas al azar.
##  - capas:  una cara baja, otras altas: la cara baja es el "camino fácil" y las otras obligan a mover más.

const RoomLib := preload("res://scripts/room_lib.gd")

const IDEAS: Array[String] = ["muro", "mixto", "capas"]
const SIDE := 8   # el piso incluido
static var inner_void := 0.35   # parte de las columnas de adentro que se sacan por completo (huecos para maniobrar)


static func cells(with_hollow := false) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in SIDE:
		for z in SIDE:
			if x >= 3 and x <= 4 and z >= 3 and z <= 4 and not with_hollow:
				continue   # el core (o, con with_hollow, el pozo vacío del medio: lleva piso)
			out.append(Vector2i(x, z))
	return out


## Las columnas de la masa: las celdas de 1 a 6 sin el core.
static func mass_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells():
		if c.x >= 1 and c.x <= 6 and c.y >= 1 and c.y <= 6:
			out.append(c)
	return out


static func make(rng: RandomNumberGenerator, h: int, idea: String) -> Dictionary:
	var room := RoomLib.make_room("3x3", h)   # (se parte de una sala común y se cambia la forma)
	room.shape = "C6"
	room.cells = cells()
	room.entry = Vector2i(-1, 3)
	var mass := mass_cells()
	var ring: Array[Vector2i] = []   # celdas de la masa donde puede estar el pilar de salida: la capa de afuera (no pegadas a la llegada)
	for c in mass:
		if c.x == 1 or c.x == 6 or c.y == 1 or c.y == 6:
			ring.append(c)
	room.exit = ring[rng.randi_range(0, ring.size() - 1)]
	var low_face := rng.randi_range(0, 3)
	var cols := {}
	for c in mass:
		if c == room.exit or (c - room.entry).length() < 1.5:
			continue
		var k := h - 1
		match idea:
			"muro":
				if rng.randf() < 0.12:
					k = rng.randi_range(0, h - 2)
			"mixto":
				if rng.randf() > 0.6:
					k = rng.randi_range(0, h - 2)
			"capas":
				var face := 0 if c.x == 1 else (1 if c.x == 6 else (2 if c.y == 1 else 3))
				if face == low_face:
					k = clampi(h - 1 - (absi(c.x - room.exit.x) + absi(c.y - room.exit.y)) / 2 - rng.randi_range(0, 2), 0, h - 1)
				elif rng.randf() < 0.15:
					k = rng.randi_range(0, h - 2)
		if k > 0:
			cols[c] = "n".repeat(k)
	room["cols"] = cols
	room.origin = "cilindro"
	return room


## Una vista de arriba de las alturas (para mirar la masa de un vistazo).
static func top_view(room: Dictionary) -> String:
	var lines: Array = []
	for z in SIDE:
		var line := ""
		for x in SIDE:
			var c := Vector2i(x, z)
			if c == room.exit:
				line += " E "
			elif x >= 3 and x <= 4 and z >= 3 and z <= 4 and not room.cols.has(c):
				line += " # "
			elif room.cols.has(c):
				line += " %d " % String(room.cols[c]).length()
			else:
				line += " . "
		lines.append(line)
	return "\n".join(lines)


# --- generador al revés dentro de la masa ---------------------------------------------------------------------------------------

const Solver := preload("res://scripts/solver.gd")
const Conv := preload("res://scripts/convoy_gen.gd")


## Las 20 celdas de la capa de afuera de la masa, en orden alrededor (sentido horario desde la esquina de arriba a la izquierda).
static func perimeter() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(1, 7):
		out.append(Vector2i(x, 1))
	for z in range(2, 7):
		out.append(Vector2i(6, z))
	for x in range(5, 0, -1):
		out.append(Vector2i(x, 6))
	for z in range(5, 1, -1):
		out.append(Vector2i(1, z))
	return out


## La masa resuelta: todas las columnas llenas (h - 1) salvo una escalera tallada en la capa de afuera (de alto h-2, h-3... 1, alejándose del pilar) y los bloques que se sacaron para tallarla,
## apilados en el piso de afuera. El jugador está en lo alto del pilar. Devuelve {room, state}.
static func goal_state(rng: RandomNumberGenerator, h: int) -> Dictionary:
	var room := RoomLib.make_room("3x3", h)
	room.shape = "C6"
	room.cells = cells()
	room.entry = Vector2i(-1, 3)
	var per := perimeter()
	var ei := rng.randi_range(0, per.size() - 1)
	room.exit = per[ei]
	var dir := 1 if rng.randf() < 0.5 else -1
	var cols := {}
	for c in mass_cells():
		if c != room.exit and (c - room.entry).length() >= 1.5:
			cols[c] = "n".repeat(h - 1)
	# la capa de adentro (pegada al core) tiene huecos y alturas distintas: ahí hay lugar para maniobrar; la de afuera queda como una pared lisa (salvo la escalera)
	var outer := {}
	for c in per:
		outer[c] = true
	for c in mass_cells():
		if outer.has(c) or not cols.has(c):
			continue
		var roll := rng.randf()
		if roll < inner_void:
			cols.erase(c)
		elif roll < inner_void + 0.3:
			cols[c] = "n".repeat(rng.randi_range(1, h - 1))
	var removed := 0
	for k in range(2, h):   # la celda 1 (pegada al pilar) queda llena; de la 2 en adelante se baja de a uno
		var c: Vector2i = per[posmod(ei + dir * k, per.size())]
		var keep := h - k
		if (c - room.entry).length() < 1.5 or keep < 1:
			continue
		removed += (h - 1) - keep
		cols[c] = "n".repeat(keep)
	# los bloques sacados, apilados en el piso de afuera (lejos de la llegada)
	var floor_cells: Array[Vector2i] = []
	for c in cells():
		if (c.x == 0 or c.x == 7 or c.y == 0 or c.y == 7) and (c - room.entry).length() >= 2.0:
			floor_cells.append(c)
	var guard := 0
	while removed > 0 and guard < 200:
		guard += 1
		var fc: Vector2i = floor_cells[rng.randi_range(0, floor_cells.size() - 1)]
		if String(cols.get(fc, "")).length() < 3:
			cols[fc] = String(cols.get(fc, "")) + "n"
			removed -= 1
	room["cols"] = cols
	room.origin = "cilindro"
	var t = RoomLib.build_state(room)
	t.player = Vector3i(room.exit.x, h + 1, room.exit.y)
	return {"room": room, "state": t}


## La masa escasa (versión 2, con el pozo del medio vacío): casi no hay material. Sólo la escalera hasta la salida (columnas de h-1, h-2... 1 a lo largo de la capa de afuera) y unos bloques sueltos de más
## repartidos en el anillo. La salida es un pilar fijo en el borde de arriba (la "salida" del cilindro). El jugador está arriba, en la salida.
static func goal_sparse(rng: RandomNumberGenerator, h: int, extras: int) -> Dictionary:
	var room := RoomLib.make_room("3x3", h)
	room.shape = "C6H"   # (sin core: el pozo del medio está vacío y sin piso: lo que cae ahí se pierde; el piso es el anillo de afuera y la base fija del cilindro)
	room.cells = cells()
	room.entry = Vector2i(-1, 3)
	var per := perimeter()
	var ei := rng.randi_range(0, per.size() - 1)
	room.exit = per[ei]
	var dir := 1 if rng.randf() < 0.5 else -1
	var cols := {}
	for k in range(1, h):
		var c: Vector2i = per[posmod(ei + dir * k, per.size())]
		if (c - room.entry).length() < 1.5:
			continue
		cols[c] = "n".repeat(h - k)
	var ring := mass_cells()
	var guard := 0
	while extras > 0 and guard < 200:
		guard += 1
		var c: Vector2i = ring[rng.randi_range(0, ring.size() - 1)]
		if c == room.exit or (c - room.entry).length() < 1.5:
			continue
		if String(cols.get(c, "")).length() < 3:
			cols[c] = String(cols.get(c, "")) + "n"
			extras -= 1
	room["cols"] = cols
	room.origin = "cilindro"
	var t = RoomLib.build_state(room)
	t.player = Vector3i(room.exit.x, h + 1, room.exit.y)
	return {"room": room, "state": t}


static func _inside_ok(t, room: Dictionary) -> bool:
	var inside := {}
	for c in room.cells:
		inside[c] = true
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


## Juega `steps` movimientos hacia atrás desde la masa resuelta (caminar, empujar, tirar: cada uno comprobado como reversible con las reglas del juego). Devuelve la sala o {}.
static func scramble(rng: RandomNumberGenerator, h: int, steps: int, sparse := false, extras := 6) -> Dictionary:
	var g := goal_sparse(rng, h, extras) if sparse else goal_state(rng, h)
	var room: Dictionary = g.room
	var s = g.state
	var seen_blocks := {}
	var done := 0
	var pushes := 0
	var stuck := 0
	while done < steps and stuck < 20:
		var cands: Array = []
		for d in Conv.DIRS:
			for m in Conv.MODES:
				var p = s.clone()
				var r: Dictionary = p.try_action(Vector3i(d.x, 0, d.y), m)
				if not r.ok or p.lost or p.won or p.positions.size() != s.positions.size():
					continue
				if not _inside_ok(p, room):
					continue
				var mv := false
				for id in s.positions:
					if p.positions[id] != s.positions[id]:
						mv = true
						break
				if not Conv._reversible(p, s, 2 if mv else 1):
					continue
				var k: Vector3i = Solver.state_key(p)
				var w := 0.25
				if mv:
					w = 6.0
					if seen_blocks.has(Vector2i(k.x, k.y)):
						w *= 0.05
				cands.append([p, w, mv])
		if cands.is_empty():
			stuck += 1
			continue
		var total := 0.0
		for c in cands:
			total += float(c[1])
		var pick := rng.randf() * total
		var chosen = cands[cands.size() - 1]
		for c in cands:
			pick -= float(c[1])
			if pick <= 0.0:
				chosen = c
				break
		s = chosen[0]
		if chosen[2]:
			pushes += 1
		var key: Vector3i = Solver.state_key(s)
		seen_blocks[Vector2i(key.x, key.y)] = true
		done += 1
	if done < steps / 3:
		return {}
	# la sala que sale: columnas = bloques sueltos donde quedaron; el jugador empieza en la llegada
	var rows := {}
	for id in s.positions:
		var p: Vector3i = s.positions[id]
		if s.fixed.has(p) or p.y < 1:
			continue
		var c := Vector2i(p.x, p.z)
		if c == room.exit:
			continue
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
	room.opt["scramble_steps"] = done
	room.opt["scramble_pushes"] = pushes
	return room


# --- escalada de colinas sobre el cilindro (guiada por el solucionador) ----------------------------------------------------------

static func score(room: Dictionary) -> float:
	var o: Dictionary = room.opt
	return float(o.moves) + 3.0 * float(o.grabs) + 4.0 * float(o.blocks) + 2.0 * float(o.switches)


## Un cambio al azar: el bloque de arriba de una columna pasa arriba de otra (en el anillo, el piso de afuera o el pozo), o se intercambian dos columnas.
static func mutate(rng: RandomNumberGenerator, room: Dictionary) -> Dictionary:
	var r := RoomLib.copy_room(room)
	var cols: Dictionary = r.cols
	var h: int = r.h
	if cols.is_empty():
		return {}
	var keys: Array = cols.keys()
	var allowed: Array = []
	for c in cells():
		if c != r.exit and (c - r.entry).length() >= 1.5:
			allowed.append(c)
	if rng.randf() < 0.75:
		var from: Vector2i = keys[rng.randi_range(0, keys.size() - 1)]
		var to: Vector2i = allowed[rng.randi_range(0, allowed.size() - 1)]
		if from == to or String(cols.get(to, "")).length() >= h - 1:
			return {}
		var sf: String = cols[from]
		if sf.length() <= 1:
			cols.erase(from)
		else:
			cols[from] = sf.substr(0, sf.length() - 1)
		cols[to] = String(cols.get(to, "")) + "n"
	else:
		var a: Vector2i = keys[rng.randi_range(0, keys.size() - 1)]
		var b: Vector2i = allowed[rng.randi_range(0, allowed.size() - 1)]
		if a == b:
			return {}
		var ta: String = cols[a]
		var tb: String = String(cols.get(b, ""))
		if tb == "":
			cols.erase(a)
		else:
			cols[a] = tb
		if ta == "":
			cols.erase(b)
		else:
			cols[b] = ta
	return r


static func climb(rng: RandomNumberGenerator, start: Dictionary, budget_ms: int) -> Dictionary:
	var best: Dictionary = Conv.evaluate(start, 300000, 4000)
	if best.is_empty():
		return {}
	var best_score := score(best)
	var t0 := Time.get_ticks_msec()
	var tries := 0
	var accepted := 0
	while Time.get_ticks_msec() - t0 < budget_ms:
		tries += 1
		var cand := mutate(rng, best)
		if cand.is_empty():
			continue
		var ev: Dictionary = Conv.evaluate(cand, 300000, 4000)
		if ev.is_empty():
			continue
		var sc := score(ev)
		if sc >= best_score:
			if sc > best_score:
				accepted += 1
			best = ev
			best_score = sc
	best.opt["tries"] = tries
	best.opt["accepted"] = accepted
	return best


# --- pared colgante: la estructura cuelga de la salida --------------------------------------------------------------------------

const SIX: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]


## Una pared que cuelga de la salida (un solo bloque fijo en el borde de arriba, que nunca cae): crece pegando bloques a los que ya hay (cualquier lado) dentro del anillo de 2 de espesor, así que todo
## está sostenido por una cadena que llega a la salida (o a la base). Si se saca un eslabón, lo que cuelga de él cae. `n` bloques.
static func colgante(rng: RandomNumberGenerator, h: int, n: int) -> Dictionary:
	var room := RoomLib.make_room("3x3", h)
	room.shape = "C6H"
	room.cells = cells()
	room.entry = Vector2i(-1, 3)
	room["exit_solo"] = true
	var ring := mass_cells()
	var rim: Array[Vector2i] = []
	for c in ring:
		if c.x == 1 or c.x == 6 or c.y == 1 or c.y == 6:
			rim.append(c)
	room.exit = rim[rng.randi_range(0, rim.size() - 1)]
	var allowed := {}
	for c in ring:
		allowed[c] = true
	var blocks := {Vector3i(room.exit.x, h, room.exit.y): true}
	var list: Array = [Vector3i(room.exit.x, h, room.exit.y)]
	var guard := 0
	var placed := 0
	while placed < n and guard < n * 40:
		guard += 1
		var base: Vector3i = list[rng.randi_range(0, list.size() - 1)]
		var q: Vector3i = base + SIX[rng.randi_range(0, SIX.size() - 1)]
		var c := Vector2i(q.x, q.z)
		if not allowed.has(c) or q.y < 1 or q.y > h - 1 or blocks.has(q) or (c - room.entry).length() < 1.5:
			continue
		blocks[q] = true
		list.append(q)
		placed += 1
	var cols := {}
	for q in blocks:
		if q.y == h:
			continue
		var c := Vector2i(q.x, q.z)
		if cols.has(c):
			continue
		var top := 0
		for y in range(1, h):
			if blocks.has(Vector3i(c.x, y, c.y)):
				top = y
		var text := ""
		for y in range(1, top + 1):
			text += "n" if blocks.has(Vector3i(c.x, y, c.y)) else RoomLib.GAP
		cols[c] = text
	room["cols"] = cols
	room.origin = "cilindro"
	return room


## Los bloques de una pared colgante como conjunto de posiciones (x, nivel, z).
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


## Un cambio al azar de la pared colgante: un bloque cualquiera pasa a un lugar pegado a otro (de cualquier lado).
static func mutate_colgante(rng: RandomNumberGenerator, room: Dictionary) -> Dictionary:
	var blocks := block_set(room)
	if blocks.size() < 3:
		return {}
	var keys: Array = blocks.keys()
	var q: Vector3i = keys[rng.randi_range(0, keys.size() - 1)]
	blocks.erase(q)
	keys = blocks.keys()
	var base: Vector3i = keys[rng.randi_range(0, keys.size() - 1)]
	var r: Vector3i = base + SIX[rng.randi_range(0, SIX.size() - 1)]
	var c := Vector2i(r.x, r.z)
	var inside := false
	for m in mass_cells():
		if m == c:
			inside = true
	if not inside or r.y < 1 or r.y > int(room.h) - 1 or blocks.has(r) or r == q or (c - room.entry).length() < 1.5:
		return {}
	blocks[r] = true
	var out := RoomLib.copy_room(room)
	out["cols"] = cols_from_set(blocks)
	return out


static func climb_colgante(rng: RandomNumberGenerator, start: Dictionary, budget_ms: int) -> Dictionary:
	var best: Dictionary = Conv.evaluate(start, 300000, 4000)
	if best.is_empty():
		return {}
	var best_score := score(best)
	var t0 := Time.get_ticks_msec()
	var tries := 0
	var accepted := 0
	while Time.get_ticks_msec() - t0 < budget_ms:
		tries += 1
		var cand := mutate_colgante(rng, best)
		if cand.is_empty():
			continue
		var ev: Dictionary = Conv.evaluate(cand, 300000, 4000)
		if ev.is_empty():
			continue
		var sc := score(ev)
		if sc >= best_score:
			if sc > best_score:
				accepted += 1
			best = ev
			best_score = sc
	best.opt["tries"] = tries
	best.opt["accepted"] = accepted
	return best
