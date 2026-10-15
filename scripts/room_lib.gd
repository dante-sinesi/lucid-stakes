extends RefCounted
## Biblioteca de salas: el formato estándar de una sala suelta (independiente de la torre), su construcción en el simulador, la verificación, los tres hashes y la lectura y escritura de archivos.
## Ver docs/evaluacion_generador.md. Lo usan el minero (scripts/room_miner.gd) y el Estudio de salas (scripts/studio.gd).
##
## Una sala es un Dictionary:
##   shape  "3x3" | "3x5" | "3x8" | "L" | "U"      forma de la arena (ver shape_info)
##   h      pisos de la sala (alto del pilar de salida; el jugador sube h pisos y queda parado sobre el tope)
##   cols   {Vector2i: String}  columnas de la arena: de abajo hacia arriba, un carácter por bloque (n común, h pesado, i hielo, c agrietado)
##   cells, entry, exit        derivados de la forma (se guardan para poder tener salas a medida)
##   path   Array de {dir: Vector3i, mode: int}  camino más corto conocido
##   opt    {moves, lower, grabs, moved, proof, states}    proof: "exacta" | "cota" | "sin_probar"
##   id, family, pattern       hashes (exacto, familia sin tipos, patrón de solución)
##   origin ("minero" | "manual" | "autor"), parent, variant_of, slots, variants, status, note, stamp, rules

const TowerLogic := preload("res://scripts/tower_logic.gd")
const Solver := preload("res://scripts/solver.gd")
const K := TowerLogic.Kind

const FORMAT := 1
const RULES_VERSION := 1   # sube cuando cambian las reglas del juego: las salas viejas se revalidan o se descartan
const BIG := 1 << 30
const WORLD := 8
const MIN_H := 5
const MAX_H := 20
const SHAPES: Array = ["3x3", "3x5", "3x8", "L", "U"]
const KIND_OF_CHAR := {"n": K.NORMAL, "h": K.HEAVY, "i": K.ICE, "c": K.CRACKED}
const CHAR_OF_KIND := {K.NORMAL: "n", K.HEAVY: "h", K.ICE: "i", K.CRACKED: "c"}
const DIR_CHARS := {Vector3i(1, 0, 0): "E", Vector3i(-1, 0, 0): "W", Vector3i(0, 0, 1): "S", Vector3i(0, 0, -1): "N"}
const MODE_CHARS := {TowerLogic.Mode.MOVE: "m", TowerLogic.Mode.GRAB: "g", TowerLogic.Mode.HANG: "h"}
const STATUSES := ["nuevo", "buena", "mala", "mejorable"]

static var _shape_cache := {}


# --- formas ---------------------------------------------------------------------------------------------------------------

## Las celdas de la arena, la llegada (afuera, pegada a la arena) y la salida (la columna del pilar).
##   3x3, 3x5, 3x8: una franja de 3 de ancho y 3, 5 u 8 de largo. Llegada pegada a un extremo, salida en el otro.
##   L: una franja de 8x3 (un lado completo de la torre) más un tramo de 2x3 que sale de un extremo en perpendicular. La llegada es el extremo del tramo corto: hay que recorrer la L entera.
##   U: dos brazos de 5x3 unidos por un tramo de 2x3 (el ancho total es 8: un lado completo de la torre). La llegada es la punta de un brazo, la salida la punta del otro.
static func shape_info(shape: String) -> Dictionary:
	if _shape_cache.has(shape):
		return _shape_cache[shape]
	var cells: Array[Vector2i] = []
	var entry := Vector2i(-1, 0)
	var exit := Vector2i(0, 0)
	match shape:
		"3x3", "3x5", "3x8":
			var n := int(shape.substr(2))
			for x in n:
				for z in 3:
					cells.append(Vector2i(x, z))
			exit = Vector2i(n - 1, 2)
		"L":
			for x in 8:
				for z in 3:
					cells.append(Vector2i(x, z))
			for x in 3:
				for z in range(3, 5):
					cells.append(Vector2i(x, z))
			entry = Vector2i(1, 5)
			exit = Vector2i(7, 0)
		"U":
			for x in 5:
				for z in 3:
					cells.append(Vector2i(x, z))
					cells.append(Vector2i(x, z + 5))
			for x in 3:
				for z in range(3, 5):
					cells.append(Vector2i(x, z))
			entry = Vector2i(5, 0)
			exit = Vector2i(4, 7)
		_:
			return {"cells": cells, "entry": entry, "exit": exit}
	var info := {"cells": cells, "entry": entry, "exit": exit}
	_shape_cache[shape] = info
	return info


## Celdas donde puede haber columnas: todas menos la salida y las pegadas a la llegada (el jugador tiene que poder empezar).
static func free_cells(shape: String) -> Array[Vector2i]:
	var info := shape_info(shape)
	var out: Array[Vector2i] = []
	for c in info.cells:
		if c != info.exit and (c - info.entry).length() >= 1.5:
			out.append(c)
	return out


## Alturas posibles de una forma: una escalera a pie hasta la salida necesita h - 1 columnas distintas (cada una un escalón más alta), así que la arena limita la altura.
static func max_height(shape: String) -> int:
	var cap: int = {"3x3": 7, "3x5": 8}.get(shape, MAX_H)   # (en una arena chica casi no hay lugar para desordenar una escalera alta: lo medido con el minero)
	return clampi(mini(cap, free_cells(shape).size() + 1), MIN_H, MAX_H)


static func combos() -> Array:
	var out: Array = []
	for sh in SHAPES:
		for h in range(MIN_H, max_height(sh) + 1):
			out.append([sh, h])
	return out


static func make_room(shape: String, h: int) -> Dictionary:
	var info := shape_info(shape)
	return {"format": FORMAT, "rules": RULES_VERSION, "shape": shape, "h": h, "cols": {}, "cells": info.cells.duplicate(), "entry": info.entry, "exit": info.exit,
		"path": [], "opt": {}, "id": "", "family": "", "pattern": "", "origin": "minero", "parent": "", "variant_of": "", "slots": {}, "variants": [], "status": "nuevo", "note": "", "stamp": 0}


static func copy_room(room: Dictionary) -> Dictionary:
	var r: Dictionary = room.duplicate(true)
	return r


## "" si la sala es coherente, si no el motivo. Comprueba lo que el simulador no puede: columnas fuera de la arena o encima de la salida, alturas, tipos, y que la llegada tenga lugar.
static func validate_structure(room: Dictionary) -> String:
	var cells := {}
	for c in room.cells:
		cells[c] = true
	var h: int = room.h
	if h < 2 or h > 40:
		return "altura fuera de rango"
	if not cells.has(room.exit):
		return "la salida no está en la arena"
	if cells.has(room.entry):
		return "la llegada tiene que estar afuera de la arena"
	var near := false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if cells.has(room.entry + d):
			near = true
	if not near:
		return "la llegada no toca la arena"
	for c in room.cols:
		if not cells.has(c):
			return "hay una columna fuera de la arena"
		if c == room.exit:
			return "hay una columna sobre la salida"
		if (c - room.entry).length() < 1.5:
			return "hay una columna pegada a la llegada"
		var ks: String = room.cols[c]
		if ks.length() > h - 1:
			return "una columna es más alta que el pilar"
		for i in ks.length():
			if not KIND_OF_CHAR.has(ks[i]):
				return "tipo de bloque desconocido"
	return ""


# --- simulador ------------------------------------------------------------------------------------------------------------

## La sala sola, en una torre chica: piso fijo (la arena y la llegada), el pilar de salida (h - 1 bloques pesados y arriba un bloque fijo) y las columnas. El jugador empieza en la llegada.
static func build_state(room: Dictionary):
	var t = TowerLogic.new()
	t.size = Vector2i(WORLD, WORLD)
	t.collapse_every = BIG
	t.moves_to_collapse = BIG
	var entry: Vector2i = room.entry
	var exit: Vector2i = room.exit
	var h: int = room.h
	for c in room.cells:
		t.add_block(Vector3i(c.x, 0, c.y), true)
	t.add_block(Vector3i(entry.x, 0, entry.y), true)
	for y in range(1, h):
		t.add_block(Vector3i(exit.x, y, exit.y), false, K.HEAVY)
	t.add_block(Vector3i(exit.x, h, exit.y), true, K.NORMAL)
	var goal_id: int = t.blocks[Vector3i(exit.x, h, exit.y)]
	var keys: Array = room.cols.keys()
	keys.sort_custom(func(a, b): return a.y * 100 + a.x < b.y * 100 + b.x)
	for c in keys:
		var ks: String = room.cols[c]
		for i in ks.length():
			t.add_block(Vector3i(c.x, i + 1, c.y), false, int(KIND_OF_CHAR.get(ks[i], K.NORMAL)))
	t.player = Vector3i(entry.x, 1, entry.y)
	t.goal_y = h + 1
	t.goal_ids = {goal_id: true}
	return t


## ¿Estar parado en la cima de la salida? (el final de todo camino)
static func at_goal(t, h: int) -> bool:
	return t.player.y == h + 1 and t.goal_ids.has(int(t.blocks.get(t.player + Vector3i.DOWN, -1)))


## Repite un camino sobre la sala. {ok, at (paso donde falla o -1), msg}.
static func replay(room: Dictionary, path: Array) -> Dictionary:
	var t = build_state(room)
	for i in path.size():
		var a: Dictionary = path[i]
		var r: Dictionary = t.try_action(a.dir, a.mode)
		if not r.ok or t.lost:
			return {"ok": false, "at": i, "msg": str(r.get("msg", "perdió"))}
	if not at_goal(t, room.h):
		return {"ok": false, "at": path.size(), "msg": "el camino no termina en la salida"}
	return {"ok": true, "at": -1, "msg": ""}


## Cuántos bloques DISTINTOS se mueven siguiendo el camino (un bloque empujado cuatro veces cuenta uno) y cuántos empujes y tirones hay.
static func path_stats(room: Dictionary, path: Array) -> Dictionary:
	var t = build_state(room)
	var moved := {}
	var grabs := 0
	for a in path:
		var before: Dictionary = {}
		if a.mode == TowerLogic.Mode.GRAB:
			before = t.positions.duplicate()
			grabs += 1
		t.try_action(a.dir, a.mode)
		if a.mode == TowerLogic.Mode.GRAB:
			for id in t.positions:
				if before.get(id, t.positions[id]) != t.positions[id]:
					moved[id] = true
	return {"moved": moved.size(), "grabs": grabs}


# --- resolver y evaluar -----------------------------------------------------------------------------------------------------

## Evalúa una sala: la resuelve con el solucionador de producción (rápido; sin garantía de que el camino sea el más corto), comprueba que no se pueda resolver sin mover bloques
## (esa búsqueda sólo mueve al jugador, así que es chica y exacta) y mide. {ok, why, path, moves, grabs, moved, states}.
## opts: cap (estados), max_ms, h_weight (>1: más codicioso), plain_cap.
static func evaluate(room: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var h: int = room.h
	var t = build_state(room)
	var so := {"max_states": int(opts.get("cap", 3000)), "goal_ids": t.goal_ids, "max_ms": int(opts.get("max_ms", 0)), "h_weight": float(opts.get("h_weight", 1.0))}
	var res: Dictionary = Solver.solve(t.clone(), h + 1, so)
	if res.status != "solved":
		return {"ok": false, "why": str(res.status), "states": int(res.states)}
	var plain: Dictionary = Solver.solve(t.clone(), h + 1, {"max_states": int(opts.get("plain_cap", 40000)), "goal_ids": t.goal_ids, "no_grab": true, "max_ms": int(opts.get("max_ms", 0))})
	if plain.status == "solved":
		return {"ok": false, "why": "atajo", "states": int(res.states) + int(plain.states)}
	if plain.status == "limit":
		return {"ok": false, "why": "sin_prueba_de_atajo", "states": int(res.states) + int(plain.states)}
	var st := path_stats(room, res.path)
	if int(st.moved) < 1:
		return {"ok": false, "why": "sin_bloques", "states": int(res.states)}
	return {"ok": true, "why": "", "path": res.path, "moves": res.moves, "grabs": st.grabs, "moved": st.moved, "states": int(res.states) + int(plain.states)}


## Verificador exacto: A* con la heurística demostrable (nunca sobrestima: distancia de subida y distancia al bloque meta), que garantiza el camino más corto cuando termina. {proof: "exacta"|"cota", moves, lower, path, states}.
## Si se acaba el presupuesto, `lower` es una cota inferior de los pasos (todo lo que cuesta menos se miró entero).
static func verify_exact(room: Dictionary, cap := 60000, max_ms := 60000) -> Dictionary:
	var h: int = room.h
	var t = build_state(room)
	var res: Dictionary = Solver.solve(t, h + 1, {"max_states": cap, "goal_ids": t.goal_ids, "admissible": true, "max_ms": max_ms})
	if res.status == "solved":
		return {"proof": "exacta", "moves": res.moves, "lower": res.moves, "path": res.path, "states": res.states}
	if res.status == "unsolvable":
		return {"proof": "imposible", "moves": -1, "lower": -1, "path": [], "states": res.states}
	return {"proof": "cota", "moves": -1, "lower": int(res.get("f_reached", 0)), "path": [], "states": res.states}


## Completa y deja coherente la sala con el resultado de una evaluación (camino, métricas, hashes).
static func apply_result(room: Dictionary, path: Array, proof: String, lower: int, states: int) -> void:
	var st := path_stats(room, path)
	room.path = path
	room.opt = {"moves": path.size(), "lower": lower, "grabs": st.grabs, "moved": st.moved, "proof": proof, "states": states}
	finalize(room)


# --- hashes ---------------------------------------------------------------------------------------------------------------

static func _sym(i: int, x: int, z: int) -> Vector2i:
	match i:
		0:
			return Vector2i(x, z)
		1:
			return Vector2i(-x, z)
		2:
			return Vector2i(x, -z)
		3:
			return Vector2i(-x, -z)
		4:
			return Vector2i(z, x)
		5:
			return Vector2i(-z, x)
		6:
			return Vector2i(z, -x)
	return Vector2i(-z, -x)


## La sala vista con la simetría `s` (giros y espejos), trasladada a la esquina: {text, blocks}. Con `erase_types` los bloques que no son pesados se tratan como uno solo.
static func _image(room: Dictionary, s: int, erase_types: bool) -> Dictionary:
	var mn := Vector2i(1 << 20, 1 << 20)
	var cells: Array = []
	for c in room.cells:
		var q := _sym(s, c.x, c.y)
		cells.append(q)
		mn = Vector2i(mini(mn.x, q.x), mini(mn.y, q.y))
	var en := _sym(s, room.entry.x, room.entry.y)
	var ex := _sym(s, room.exit.x, room.exit.y)
	mn = Vector2i(mini(mn.x, en.x), mini(mn.y, en.y))
	var cs := PackedStringArray()
	for q in cells:
		cs.append("%d,%d" % [q.x - mn.x, q.y - mn.y])
	cs.sort()
	var bs := PackedStringArray()
	for c in room.cols:
		var q := _sym(s, c.x, c.y)
		var ks: String = room.cols[c]
		for i in ks.length():
			var ch: String = ks[i]
			if erase_types and ch != "h":
				ch = "b"
			bs.append("%d,%d,%d,%s" % [q.x - mn.x, i + 1, q.y - mn.y, ch])
	bs.sort()
	var text := "h%d;E%d,%d;X%d,%d;C%s;B%s" % [room.h, en.x - mn.x, en.y - mn.y, ex.x - mn.x, ex.y - mn.y, "|".join(cs), "|".join(bs)]
	return {"text": text, "blocks": bs}


## La sala escrita en forma canónica: se prueban las 8 simetrías (4 giros y sus espejos), se traslada cada una a la esquina y se elige la de texto menor. Una sala, su giro y su espejo dan el mismo texto.
## Con `erase_types` los bloques que no son pesados se tratan como uno solo (la "familia"). {text, sym}.
static func canonical(room: Dictionary, erase_types: bool) -> Dictionary:
	var best := ""
	var best_sym := 0
	for s in 8:
		var text: String = _image(room, s, erase_types).text
		if best == "" or text < best:
			best = text
			best_sym = s
	return {"text": best, "sym": best_sym}


static func _hash(text: String) -> String:
	return text.sha256_text().substr(0, 32)


static func path_string(path: Array) -> String:
	var out := ""
	for a in path:
		out += String(MODE_CHARS.get(a.mode, "m")) + String(DIR_CHARS.get(a.dir, "E"))
	return out


static func parse_path(text: String) -> Array:
	var out: Array = []
	var inv_dir := {}
	for d in DIR_CHARS:
		inv_dir[DIR_CHARS[d]] = d
	var inv_mode := {}
	for m in MODE_CHARS:
		inv_mode[MODE_CHARS[m]] = m
	var i := 0
	while i + 1 < text.length():
		var mc := text[i]
		var dc := text[i + 1]
		if inv_mode.has(mc) and inv_dir.has(dc):
			out.append({"dir": inv_dir[dc], "mode": inv_mode[mc]})
		i += 2
	return out


## Calcula los tres hashes: `id` (exacto: estructura y tipos), `family` (sin tipos de bloque) y `pattern` (la familia más el camino mínimo normalizado: lo que el jugador reconoce al jugarla).
static func finalize(room: Dictionary) -> void:
	var ex := canonical(room, false)
	var fa := canonical(room, true)
	room.id = _hash(ex.text)
	room.family = _hash(fa.text)
	var toks := ""
	for a in room.path:
		var d: Vector3i = a.dir
		var q := _sym(fa.sym, d.x, d.z)
		toks += String(MODE_CHARS.get(a.mode, "m")) + String(DIR_CHARS.get(Vector3i(q.x, 0, q.y), "E"))
	room.pattern = _hash("%s|%s" % [fa.text, toks])
	room.rules = RULES_VERSION


## Los bloques de la sala en forma canónica (para comparar parecidos): un conjunto de textos "x,y,z,tipo".
static func block_set(room: Dictionary) -> Dictionary:
	var ex := canonical(room, false)
	var out := {}
	for p in _image(room, int(ex.sym), false).blocks:
		out[p] = true
	return out


## Los conjuntos de bloques de las 8 orientaciones de la sala. Para comparar una sala (todavía sin forma canónica estable, por ejemplo recién editada) contra otras ya canónicas.
static func block_sets_all(room: Dictionary) -> Array:
	var out: Array = []
	for s in 8:
		var set := {}
		for p in _image(room, s, false).blocks:
			set[p] = true
		out.append(set)
	return out


## Descriptor numérico para la búsqueda de salas parecidas.
static func descriptor(room: Dictionary) -> Array:
	var counts := {"n": 0, "h": 0, "i": 0, "c": 0}
	var n := 0
	for c in room.cols:
		var ks: String = room.cols[c]
		for i in ks.length():
			counts[ks[i]] = int(counts[ks[i]]) + 1
			n += 1
	var o: Dictionary = room.get("opt", {})
	return [float(SHAPES.find(room.shape)), float(room.h), float(o.get("moved", 0)), float(o.get("grabs", 0)), float(o.get("moves", 0)), float(n), float(counts.n), float(counts.h), float(counts.i), float(counts.c)]


## Distancia entre dos salas: mezcla la diferencia de bloques (Jaccard) y la de descriptores. 0 = iguales. `set_a` es un conjunto de bloques o una lista de conjuntos (las orientaciones de la sala: se toma la que mejor coincide).
static func distance(a: Dictionary, b: Dictionary, set_a, set_b: Dictionary) -> float:
	var sets_a: Array = set_a if set_a is Array else [set_a]
	var jac_best := 0.0
	for sa in sets_a:
		var inter := 0
		for k in sa:
			if set_b.has(k):
				inter += 1
		var uni: int = sa.size() + set_b.size() - inter
		var jac_s: float = (float(inter) / float(uni)) if uni > 0 else 1.0
		jac_best = maxf(jac_best, jac_s)
	var jac := 1.0 - jac_best
	var da := descriptor(a)
	var db := descriptor(b)
	var scale := [1.0, 20.0, 12.0, 12.0, 60.0, 80.0, 80.0, 20.0, 20.0, 20.0]
	var dd := 0.0
	var used := 0
	var skip_metrics: bool = bool(a.opt.get("stale", false)) or bool(b.opt.get("stale", false)) or not a.opt.has("moves") or not b.opt.has("moves")   # (una sala recién editada todavía no tiene métricas)
	for i in da.size():
		if skip_metrics and i >= 2 and i <= 4:
			continue
		dd += absf(float(da[i]) - float(db[i])) / float(scale[i])
		used += 1
	dd /= float(maxi(used, 1))
	var shape_pen := 0.0 if a.shape == b.shape else 0.5
	return clampf(0.65 * jac + 0.35 * dd + shape_pen * 0.3, 0.0, 1.0)


# --- archivos -------------------------------------------------------------------------------------------------------------

static func to_dict(room: Dictionary) -> Dictionary:
	var cols: Array = []
	var keys: Array = room.cols.keys()
	keys.sort_custom(func(a, b): return a.y * 100 + a.x < b.y * 100 + b.x)
	for c in keys:
		cols.append([c.x, c.y, room.cols[c]])
	var cells: Array = []
	for c in room.cells:
		cells.append([c.x, c.y])
	var slots := {}
	for k in room.slots:
		slots[k] = room.slots[k]
	return {"format": FORMAT, "rules": room.rules, "id": room.id, "family": room.family, "pattern": room.pattern, "shape": room.shape, "h": room.h, "cells": cells,
		"entry": [room.entry.x, room.entry.y], "exit": [room.exit.x, room.exit.y], "cols": cols, "path": path_string(room.path), "opt": room.opt,
		"origin": room.origin, "parent": room.parent, "variant_of": room.variant_of, "slots": slots, "variants": room.variants, "status": room.status, "note": room.note, "stamp": room.stamp}


## Vuelve a armar la sala desde un Dictionary leído de JSON. {} si no es una sala válida.
static func from_dict(d: Dictionary) -> Dictionary:
	if not (d.has("shape") and d.has("h") and d.has("cols") and d.has("entry") and d.has("exit") and d.has("cells")):
		return {}
	var room := make_room(str(d.shape), int(d.h))
	var cells: Array[Vector2i] = []
	for c in d.cells:
		cells.append(Vector2i(int(c[0]), int(c[1])))
	room.cells = cells
	room.entry = Vector2i(int(d.entry[0]), int(d.entry[1]))
	room.exit = Vector2i(int(d.exit[0]), int(d.exit[1]))
	var cols := {}
	for c in d.cols:
		cols[Vector2i(int(c[0]), int(c[1]))] = str(c[2])
	room.cols = cols
	room.path = parse_path(str(d.get("path", "")))
	var opt: Dictionary = d.get("opt", {})
	room.opt = opt
	room.origin = str(d.get("origin", "minero"))
	room.parent = str(d.get("parent", ""))
	room.variant_of = str(d.get("variant_of", ""))
	room.slots = d.get("slots", {})
	room.variants = d.get("variants", [])
	room.status = str(d.get("status", "nuevo"))
	room.note = str(d.get("note", ""))
	room.stamp = int(d.get("stamp", 0))
	room.rules = int(d.get("rules", 0))
	room.id = str(d.get("id", ""))
	room.family = str(d.get("family", ""))
	room.pattern = str(d.get("pattern", ""))
	return room


static func to_line(room: Dictionary) -> String:
	return JSON.stringify(to_dict(room))


static func from_line(line: String) -> Dictionary:
	var j := JSON.new()
	if j.parse(line) != OK or typeof(j.data) != TYPE_DICTIONARY:
		return {}
	return from_dict(j.data)


## Agrega una sala al final de un archivo .jsonl (se crea si no existe).
static func append_line(path: String, room: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.seek_end()
	f.store_line(to_line(room))
	f.close()
	return true


## Lee un .jsonl: devuelve {rooms, bad} (bad = líneas que no eran una sala).
static func read_file(path: String) -> Dictionary:
	var rooms: Array = []
	var bad := 0
	if not FileAccess.file_exists(path):
		return {"rooms": rooms, "bad": 0}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"rooms": rooms, "bad": 0}
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		var r := from_line(line)
		if r.is_empty():
			bad += 1
		else:
			rooms.append(r)
	f.close()
	return {"rooms": rooms, "bad": bad}


## Reescribe un archivo entero de forma segura (se escribe aparte y se renombra).
static func write_file(path: String, rooms: Array) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	for r in rooms:
		f.store_line(to_line(r))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


## De cada id el registro "mejor": prueba exacta antes que cota antes que sin probar; entre iguales, el más nuevo.
static func better(a: Dictionary, b: Dictionary) -> Dictionary:
	var rank := {"exacta": 3, "cota": 2, "sin_probar": 1}
	var ra := int(rank.get(str(a.opt.get("proof", "")), 0))
	var rb := int(rank.get(str(b.opt.get("proof", "")), 0))
	if ra != rb:
		return a if ra > rb else b
	return a if int(a.stamp) >= int(b.stamp) else b


## Texto de las capas de la sala (para mirar en la consola): una grilla por capa, de arriba hacia abajo. n/h/i/c = bloque, G = salida, A = llegada, . = vacío.
static func ascii(room: Dictionary) -> String:
	var out := "%s de %d pisos\n" % [room.shape, room.h]
	var cells := {}
	for c in room.cells:
		cells[c] = true
	var min_c := Vector2i(1 << 20, 1 << 20)
	var max_c := Vector2i(-(1 << 20), -(1 << 20))
	for c in room.cells:
		min_c = Vector2i(mini(min_c.x, c.x), mini(min_c.y, c.y))
		max_c = Vector2i(maxi(max_c.x, c.x), maxi(max_c.y, c.y))
	min_c = Vector2i(mini(min_c.x, room.entry.x), mini(min_c.y, room.entry.y))
	max_c = Vector2i(maxi(max_c.x, room.entry.x), maxi(max_c.y, room.entry.y))
	var top := 0
	for c in room.cols:
		top = maxi(top, String(room.cols[c]).length())
	for y in range(top, 0, -1):
		out += "capa %d\n" % y
		for z in range(min_c.y, max_c.y + 1):
			var row := "  "
			for x in range(min_c.x, max_c.x + 1):
				var c := Vector2i(x, z)
				var ch := " "
				if c == room.entry:
					ch = "A"
				elif c == room.exit:
					ch = "G"
				elif cells.has(c):
					var ks: String = room.cols.get(c, "")
					ch = ks[y - 1] if ks.length() >= y else "."
				row += ch + " "
			out += row + "\n"
	return out
