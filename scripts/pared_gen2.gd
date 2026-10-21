extends RefCounted
## EXPERIMENTO (aislado del juego), segunda versión de las paredes colgantes (ver pared_gen.gd): cantidad de salidas de 1 a 4 (sólo cuentan las que se alcanzan), medida de riesgo (movimientos que hacen caer
## partes de la pared o que dejan la sala sin solución), bloques especiales que se prueban uno por uno y sólo se quedan si cambian el camino, y puntaje que premia empujes, bloques distintos, riesgo y variedad
## de costos entre las salidas.

const RoomLib := preload("res://scripts/room_lib.gd")
const Base := preload("res://scripts/pared_gen.gd")
const Conv := preload("res://scripts/convoy_gen.gd")
const Solver := preload("res://scripts/solver.gd")

const SPECIALS: Array[String] = ["i", "h", "c", "s", "k", "t"]   # hielo, pesado, agrietado, pinchos, catapulta, trampa (la bomba pide afinar la mecha: se prueba aparte)
const MODES: Array = [0, 1, 2]
const DIRS3: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


## Una pared al azar con `n` bloques y `faces` salidas (1 a 4, en caras elegidas al azar).
static func make(rng: RandomNumberGenerator, kind: String, h: int, n: int, faces: int) -> Dictionary:
	var room := Base.make(rng, kind, h, n, 4 if kind == "cilindro" else 1)
	if kind == "pared" or faces >= 4:
		return room
	var exits: Array = [room.exit] + Array(room.get("exits_extra", []))
	exits.shuffle()
	exits = exits.slice(0, faces)
	room.exit = exits[0]
	var extra: Array[Vector2i] = []
	for i in range(1, exits.size()):
		extra.append(exits[i])
	room["exits_extra"] = extra
	# (se rehace la pared: crece de las salidas que quedaron)
	var again := Base.make(rng, kind, h, n, 4)
	again.exit = exits[0]
	if kind != "pared":
		again.entry = Base.entry_for(exits[0])
	again["exits_extra"] = extra
	var allowed := {}
	for c in again.mass:
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
		var q: Vector3i = base + Base.SIX[rng.randi_range(0, Base.SIX.size() - 1)]
		var c := Vector2i(q.x, q.z)
		if not allowed.has(c) or q.y < 1 or q.y > h - 1 or blocks.has(q) or (c - again.entry).length() < 1.5:
			continue
		blocks[q] = true
		list.append(q)
		placed += 1
	again["cols"] = Base.cols_from_set(blocks)
	return again


## El riesgo de una sala resuelta: siguiendo su camino más corto, en cuántos pasos existe algún movimiento legal que hace caer bloques (se pierde material), y cuántos movimientos distintos lo hacen.
static func colapsos(room: Dictionary) -> Dictionary:
	var t = RoomLib.build_state(room)
	var steps := 0
	var moves := 0
	for a in room.path:
		var here := 0
		for d in DIRS3:
			for m in MODES:
				var c = t.clone()
				var r: Dictionary = c.try_action(d, m)
				if not r.ok or c.lost:
					continue
				var fell: bool = not c.removed_ids.is_empty()
				if not fell:
					for id in t.positions:
						if c.positions.has(id) and c.positions[id].y < t.positions[id].y and not t.fixed.has(t.positions[id]):
							fell = true
							break
				if fell:
					here += 1
		if here > 0:
			steps += 1
			moves += here
		t.try_action(a.dir, a.mode)
	return {"pasos_con_riesgo": steps, "movimientos_que_derrumban": moves}


## Los movimientos del camino más corto desde los que, además, hay alguna alternativa que deja la sala SIN solución (un paso en falso que pierde la sala entera). Usa el solucionador: caro, sólo para los finales.
static func muertes(room: Dictionary) -> Dictionary:
	var t = RoomLib.build_state(room)
	var h: int = room.h
	var steps := 0
	var dead := 0
	for a in room.path:
		var here := 0
		for d in DIRS3:
			for m in MODES:
				var c = t.clone()
				var r: Dictionary = c.try_action(d, m)
				if not r.ok or c.lost:
					continue
				if c.positions.size() == t.positions.size() and c.player == t.player and c.hang_dir == t.hang_dir:
					continue
				var res: Dictionary = Solver.solve(c, h + 1, {"max_states": 60000, "goal_ids": c.goal_ids, "admissible": true, "max_ms": 800})
				if res.status == "unsolvable":
					here += 1
		if here > 0:
			steps += 1
			dead += here
		t.try_action(a.dir, a.mode)
	return {"pasos_con_muerte": steps, "movimientos_mortales": dead}


## Puntaje: por cada salida que se resuelve, pasos + empujes + bloques distintos + cambios de bloque; más el riesgo (derrumbes), más la variedad de costos entre salidas; menos lo que cuestan las salidas imposibles.
static func score(room: Dictionary, costs: Array) -> float:
	var total := 0.0
	var lo := 9999
	var hi := 0
	var solved := 0
	var h: int = room.h
	for c in costs:
		if not c.ok:
			continue
		if float(c.grabs) < min_empujes_por_piso * float(h) or float(c.moves) < min_pasos_por_piso * float(h):
			continue   # (una cara que se resuelve con muy poco —un salto de catapulta, un par de empujes— no cuenta como resuelta: es trivial)
		solved += 1
		total += float(c.moves) + 3.0 * float(c.grabs) + 4.0 * float(c.blocks) + 2.0 * float(c.get("switches", 0)) - peso_caminata * float(c.get("walk", 0.0))
		lo = mini(lo, int(c.moves))
		hi = maxi(hi, int(c.moves))
	if solved == 0:
		return -1.0
	if costs.size() > 1:
		total += 30.0 * float(solved) + 2.0 * float(hi - lo) - 80.0 * float(costs.size() - solved)
	return total


static func _with_kind(room: Dictionary, cell: Vector2i, level: int, ch: String) -> Dictionary:
	var r := RoomLib.copy_room(room)
	var text: String = r.cols[cell]
	r.cols[cell] = text.substr(0, level - 1) + ch + text.substr(level)
	return r


## Escalada guiada por el solucionador (como Base.climb pero con el puntaje nuevo).
static func climb(rng: RandomNumberGenerator, start: Dictionary, budget_ms: int) -> Dictionary:
	var costs := Base.face_costs(start)
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
		var cand := Base.mutate(rng, best)
		if cand.is_empty() or RoomLib.validate_structure(cand) != "":
			continue
		var cc := Base.face_costs(cand)
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


## Saca las salidas que no se alcanzan (no tienen sentido) si la pared sigue sostenida y las demás se siguen resolviendo.
static func podar_salidas(room: Dictionary) -> Dictionary:
	var costs: Array = room.get("costs", Base.face_costs(room))
	var exits: Array = [room.exit] + Array(room.get("exits_extra", []))
	var keep: Array = []
	for i in exits.size():
		if costs[i].ok:
			keep.append(exits[i])
	if keep.size() == exits.size() or keep.is_empty():
		return room
	var r := RoomLib.copy_room(room)
	r.exit = keep[0]
	var extra: Array[Vector2i] = []
	for i in range(1, keep.size()):
		extra.append(keep[i])
	r["exits_extra"] = extra
	if RoomLib.validate_structure(r) != "":
		return room
	var c2 := Base.face_costs(r)
	for c in c2:
		if not c.ok:
			return room
	r["costs"] = c2
	return r


## Prueba poner bloques especiales de los `kinds` (cambiando bloques comunes), de a uno: se queda con el cambio si la sala sigue sosteniéndose y resolviéndose, el camino cambió (el especial
## importa) y el puntaje no baja. Devuelve la sala con los especiales que quedaron y cuántos de cada tipo.
static func con_especiales(rng: RandomNumberGenerator, room: Dictionary, kinds: Array, intentos: int) -> Dictionary:
	var best := RoomLib.copy_room(room)
	var costs: Array = best.get("costs", Base.face_costs(best))
	var best_score := score(best, costs)
	var kept := {}
	var tried := 0
	for i in intentos:
		var cells: Array = best.cols.keys()
		if cells.is_empty():
			break
		var c: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var text: String = best.cols[c]
		var level := rng.randi_range(1, text.length())
		if text[level - 1] != "n":
			continue
		var ch: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		var cand := _with_kind(best, c, level, ch)
		tried += 1
		if RoomLib.validate_structure(cand) != "":
			continue
		var cc := Base.face_costs(cand)
		var sc := score(cand, cc)
		if sc < 0.0:
			continue
		var changed := false
		for k in cc.size():
			if cc[k].ok != costs[k].ok or (cc[k].ok and (int(cc[k].moves) != int(costs[k].moves) or int(cc[k].grabs) != int(costs[k].grabs))):
				changed = true
		if changed and sc >= best_score:
			best = cand
			costs = cc
			best_score = sc
			kept[ch] = int(kept.get(ch, 0)) + 1
	best["costs"] = costs
	best.opt["score"] = int(best_score)
	best.opt["especiales"] = kept
	best.opt["especiales_probados"] = tried
	return best


# --- paredes con especiales dentro de la escalada ---------------------------------------------------------------------------------

## Los bloques de la pared con su tipo: {Vector3i: carácter}.
static func chars_of(room: Dictionary) -> Dictionary:
	var out := {}
	for c in room.cols:
		var text: String = room.cols[c]
		for i in text.length():
			if text[i] != RoomLib.GAP:
				out[Vector3i(c.x, i + 1, c.y)] = text[i]
	return out


static func cols_from_chars(blocks: Dictionary) -> Dictionary:
	var tops := {}
	for q in blocks:
		var c := Vector2i(q.x, q.z)
		tops[c] = maxi(int(tops.get(c, 0)), q.y)
	var cols := {}
	for c in tops:
		var text := ""
		for y in range(1, int(tops[c]) + 1):
			text += str(blocks.get(Vector3i(c.x, y, c.y), RoomLib.GAP))
		cols[c] = text
	return cols


static func special_count(room: Dictionary) -> int:
	var n := 0
	for c in room.cols:
		for ch in String(room.cols[c]):
			if ch != "n" and ch != RoomLib.GAP:
				n += 1
	return n


## Un cambio al azar que conserva los tipos: mover un bloque (con su tipo) a un lugar pegado a otro, cambiar el tipo de uno (común <-> especial) o intercambiar los tipos de dos.
static func mutate2(rng: RandomNumberGenerator, room: Dictionary, kinds: Array, max_special: int) -> Dictionary:
	var blocks := chars_of(room)
	if blocks.size() < 3:
		return {}
	var keys: Array = blocks.keys()
	var roll := rng.randf()
	if roll < 0.12 and cambiar_cantidad:   # agregar un bloque pegado a otro (o a una salida)
		var base0: Vector3i = keys[rng.randi_range(0, keys.size() - 1)]
		if rng.randf() < 0.3:
			var ex0: Array = [room.exit] + Array(room.get("exits_extra", []))
			var e0: Vector2i = ex0[rng.randi_range(0, ex0.size() - 1)]
			base0 = Vector3i(e0.x, int(room.h), e0.y)
		var r0: Vector3i = base0 + Base.SIX[rng.randi_range(0, Base.SIX.size() - 1)]
		var c0 := Vector2i(r0.x, r0.z)
		if not (room.get("mass", []) as Array).has(c0) or r0.y < 1 or r0.y > int(room.h) - 1 or blocks.has(r0) or (c0 - room.entry).length() < 1.5:
			return {}
		blocks[r0] = "n"
	elif roll < 0.22 and cambiar_cantidad:   # sacar un bloque
		if blocks.size() <= int(room.h):
			return {}
		blocks.erase(keys[rng.randi_range(0, keys.size() - 1)])
	elif roll < 0.7 or kinds.is_empty():
		var q: Vector3i = keys[rng.randi_range(0, keys.size() - 1)]
		var ch: String = blocks[q]
		blocks.erase(q)
		keys = blocks.keys()
		var base: Vector3i = keys[rng.randi_range(0, keys.size() - 1)]
		if rng.randf() < 0.25:
			var exits: Array = [room.exit] + Array(room.get("exits_extra", []))
			var e: Vector2i = exits[rng.randi_range(0, exits.size() - 1)]
			base = Vector3i(e.x, int(room.h), e.y)
		var r: Vector3i = base + Base.SIX[rng.randi_range(0, Base.SIX.size() - 1)]
		var c := Vector2i(r.x, r.z)
		if not (room.get("mass", []) as Array).has(c) or r.y < 1 or r.y > int(room.h) - 1 or blocks.has(r) or r == q or (c - room.entry).length() < 1.5:
			return {}
		blocks[r] = ch
	elif roll < 0.9:
		var q2: Vector3i = keys[rng.randi_range(0, keys.size() - 1)]
		if blocks[q2] == "n":
			if special_count(room) >= max_special:
				return {}
			blocks[q2] = kinds[rng.randi_range(0, kinds.size() - 1)]
		else:
			blocks[q2] = "n" if rng.randf() < 0.5 else kinds[rng.randi_range(0, kinds.size() - 1)]
	else:
		var a: Vector3i = keys[rng.randi_range(0, keys.size() - 1)]
		var b: Vector3i = keys[rng.randi_range(0, keys.size() - 1)]
		var t: String = blocks[a]
		blocks[a] = blocks[b]
		blocks[b] = t
	var out := RoomLib.copy_room(room)
	out["cols"] = cols_from_chars(blocks)
	return out


## Cuántos de los bloques especiales hacen falta: sacarlos (cambiarlos por comunes) cambia el camino más corto o deja la sala sin solución.
static func needed_specials(room: Dictionary, costs: Array) -> int:
	var blocks := chars_of(room)
	var n := 0
	for q in blocks:
		var ch: String = blocks[q]
		if ch == "n":
			continue
		var plain := blocks.duplicate()
		plain[q] = "n"
		var v := RoomLib.copy_room(room)
		v["cols"] = cols_from_chars(plain)
		var cc := Base.face_costs(v)
		var differs := false
		for k in cc.size():
			if cc[k].ok != costs[k].ok or (cc[k].ok and (int(cc[k].moves) != int(costs[k].moves) or int(cc[k].grabs) != int(costs[k].grabs))):
				differs = true
		if differs:
			n += 1
	return n


## Escalada con especiales: el puntaje suma 30 por cada especial que hace falta y se quita 15 por cada uno que sobra (así no quedan de adorno).
static var peso_riesgo := 1.0      # puntos por cada movimiento legal que hace caer partes de la pared (en los pasos del camino más corto), hasta 30
static var cambiar_cantidad := true   # la escalada también agrega y saca bloques
static var temperatura := 0.0         # 0: sólo acepta lo que no baja el puntaje; más: acepta bajas chicas con probabilidad exp(-baja / temperatura)
static var min_empujes_por_piso := 1.0   # una cara con menos empujes que esto (por piso) no cuenta
static var min_pasos_por_piso := 3.0     # ni con menos pasos que esto (por piso)
static var peso_caminata := 40.0   # puntos que se restan por la parte del camino que se camina antes del primer empuje (0 a 1)
static var peso_caras := 0.0       # puntos por cada cara del cilindro (más allá de la primera) de la que el camino más corto saca algún bloque: hace que el material de todo el anillo cuente
static var peso_bloques := 0.0     # puntos que se restan por cada bloque de la pared (empuja a que haya el material justo)
static var peso_cobertura := 3.0   # puntos por cada columna distinta de la masa que tiene bloques (que no quede todo amontonado en un racimo)


## En qué caras del cilindro (0 norte, 1 este, 2 sur, 3 oeste; las esquinas cuentan para las dos) estaban los bloques que el camino mueve.
static func caras_usadas(room: Dictionary, path: Array) -> int:
	var t = RoomLib.build_state(room)
	var faces := {}
	for a in path:
		if a.mode == 1:
			var before: Dictionary = t.positions.duplicate()
			t.try_action(a.dir, a.mode)
			for id in t.positions:
				if before.has(id) and t.positions[id] != before[id] and not t.fixed.has(before[id]):
					var c := Vector2i(before[id].x, before[id].z)
					if c.y <= 2:
						faces[0] = true
					if c.x >= 5:
						faces[1] = true
					if c.y >= 5:
						faces[2] = true
					if c.x <= 2:
						faces[3] = true
					break
		else:
			t.try_action(a.dir, a.mode)
	return faces.size()


static func total_score(room: Dictionary, costs: Array, with_needed: bool) -> float:
	var base := score(room, costs)
	if base < 0.0:
		return base
	if with_needed:
		var cells := {}
		for c in room.cols:
			cells[c] = true
		base += peso_cobertura * float(mini(cells.size(), 24)) - peso_bloques * float(RoomLib.block_count(room))
		if peso_riesgo > 0.0 or peso_caras > 0.0:
			for c in costs:
				if c.ok:
					var rr := RoomLib.copy_room(room)
					rr["path"] = c.path
					if peso_riesgo > 0.0:
						base += peso_riesgo * float(mini(int(colapsos(rr).movimientos_que_derrumban), 30))
					if peso_caras > 0.0:
						base += peso_caras * float(maxi(caras_usadas(rr, c.path) - 1, 0))
					break
	var sp := special_count(room)
	if sp == 0 or not with_needed:
		return base
	var need := needed_specials(room, costs)
	return base + 30.0 * float(need) - 15.0 * float(sp - need)


static func climb2(rng: RandomNumberGenerator, start: Dictionary, kinds: Array, max_special: int, budget_ms: int) -> Dictionary:
	var costs := Base.face_costs(start)
	var cur := start
	var cur_costs := costs
	var cur_score := total_score(start, costs, true)
	if cur_score < -0.5:
		return {}
	var best := cur
	var best_costs := cur_costs
	var best_score := cur_score
	var t0 := Time.get_ticks_msec()
	var tries := 0
	var accepted := 0
	while Time.get_ticks_msec() - t0 < budget_ms:
		tries += 1
		var cand := mutate2(rng, cur, kinds, max_special)
		if cand.is_empty() or RoomLib.validate_structure(cand) != "":
			continue
		var cc := Base.face_costs(cand)
		var quick := score(cand, cc)
		if quick < 0.0:
			continue
		var sc := total_score(cand, cc, quick >= cur_score - 60.0)   # (lo caro, probar cada especial, sólo si el resto del puntaje es competitivo)
		var take := sc >= cur_score
		if not take and temperatura > 0.0:
			take = rng.randf() < exp((sc - cur_score) / temperatura)
		if take:
			if sc > cur_score:
				accepted += 1
			cur = cand
			cur_costs = cc
			cur_score = sc
			if sc > best_score:
				best = cand
				best_costs = cc
				best_score = sc
	var out := RoomLib.copy_room(best)
	out["costs"] = best_costs
	out.opt["tries"] = tries
	out.opt["accepted"] = accepted
	out.opt["score"] = int(best_score)
	var kept := {}
	var blocks := chars_of(out)
	for q in blocks:
		if blocks[q] != "n":
			kept[blocks[q]] = int(kept.get(blocks[q], 0)) + 1
	out.opt["especiales"] = kept
	out.opt["especiales_necesarios"] = needed_specials(out, best_costs)
	return out
