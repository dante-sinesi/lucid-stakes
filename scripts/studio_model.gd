extends RefCounted
## Modelo del Estudio de salas: toda la lógica del editor, sin interfaz (así se puede probar sola). Abre una biblioteca (.jsonl o .rooms), muestra y filtra sus salas, edita una sala
## (poner, sacar, mover o cambiar de tipo un bloque, con deshacer y rehacer), la vuelve a verificar con el solucionador cada vez, marca variantes de tipo por bloque, busca las salas más
## parecidas, reproduce el camino más corto y guarda. La interfaz es scripts/studio.gd.

const RoomLib := preload("res://scripts/room_lib.gd")
const RoomPack := preload("res://scripts/room_pack.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const Solver := preload("res://scripts/solver.gd")

const KINDS := ["n", "h", "i", "c"]
const KIND_NAMES := {"n": "común", "h": "pesado", "i": "hielo", "c": "agrietado"}
const UNDO_LIMIT := 100

var path := ""
var rooms: Array = []
var index := {}                 # id -> sala de la biblioteca
var current: Dictionary = {}    # la sala que se está mirando o editando (una copia)
var original_id := ""           # id de la sala de la biblioteca de la que sale `current` ("" si es nueva)
var dirty := false              # ¿hay cambios sin guardar?
var verified := false           # ¿se verificó la sala tal como está?
var undo_stack: Array = []
var redo_stack: Array = []
var message := ""               # el último aviso para mostrar
var _sets := {}                 # id -> conjunto de bloques canónico (caché de parecidos)
var play_state = null           # simulador de la reproducción
var play_index := 0


# --- biblioteca -----------------------------------------------------------------------------------------------------------------

func load_file(p: String) -> int:
	path = p
	rooms = RoomPack.load_library(p)
	reindex()
	current = {}
	original_id = ""
	dirty = false
	verified = false
	undo_stack.clear()
	redo_stack.clear()
	play_state = null
	return rooms.size()


func reindex() -> void:
	index.clear()
	for r in rooms:
		index[r.id] = r
	_sets.clear()


func _write() -> bool:
	if path == "":
		message = "no hay archivo abierto"
		return false
	var ok := RoomPack.write_library(rooms, path, path.ends_with(".rooms"))
	if not ok:
		message = "no se pudo escribir " + path
	return ok


## Las salas que cumplen los filtros, ordenadas. filters: shape, min_grabs, min_diff (0 a 1), min_moved, status, origin, proof, text (prefijo de id, familia o patrón), h_lo, h_hi,
## sort ("diff" = dificultad, "grabs" = empujes y tirones, "moved", "moves", "h", "reciente").
func filtered(filters: Dictionary = {}) -> Array:
	var out: Array = []
	var text := str(filters.get("text", "")).strip_edges().to_lower()
	for r in rooms:
		if filters.get("shape", "") != "" and r.shape != filters.shape:
			continue
		if int(r.opt.get("moved", 0)) < int(filters.get("min_moved", 0)):
			continue
		if int(r.opt.get("grabs", 0)) < int(filters.get("min_grabs", 0)) or float(r.opt.get("diff", 0.0)) < float(filters.get("min_diff", 0.0)) - 0.0001:
			continue
		if filters.get("status", "") != "" and r.status != filters.status:
			continue
		if filters.get("origin", "") != "" and r.origin != filters.origin:
			continue
		if filters.get("proof", "") != "" and str(r.opt.get("proof", "")) != filters.proof:
			continue
		if r.h < int(filters.get("h_lo", 0)) or r.h > int(filters.get("h_hi", 99)):
			continue
		if text != "" and not (str(r.id).begins_with(text) or str(r.family).begins_with(text) or str(r.pattern).begins_with(text)):
			continue
		out.append(r)
	var key := str(filters.get("sort", "diff"))
	out.sort_custom(func(a, b):
		match key:
			"diff":
				var da := float(a.opt.get("diff", 0.0))
				var db := float(b.opt.get("diff", 0.0))
				if absf(da - db) > 0.0001:
					return da > db
				return int(a.opt.get("grabs", 0)) > int(b.opt.get("grabs", 0)) or (int(a.opt.get("grabs", 0)) == int(b.opt.get("grabs", 0)) and str(a.id) < str(b.id))
			"grabs":
				if int(a.opt.get("grabs", 0)) != int(b.opt.get("grabs", 0)):
					return int(a.opt.get("grabs", 0)) > int(b.opt.get("grabs", 0))
				return float(a.opt.get("diff", 0.0)) > float(b.opt.get("diff", 0.0))
			"moves":
				return int(a.opt.get("moves", 0)) > int(b.opt.get("moves", 0))
			"h":
				return a.h < b.h or (a.h == b.h and int(a.opt.get("moved", 0)) > int(b.opt.get("moved", 0)))
			"reciente":
				return int(a.stamp) > int(b.stamp)
		return int(a.opt.get("moved", 0)) > int(b.opt.get("moved", 0)) or (int(a.opt.get("moved", 0)) == int(b.opt.get("moved", 0)) and str(a.id) < str(b.id)))
	return out


func stats() -> Dictionary:
	var per_shape := {}
	var per_status := {}
	for r in rooms:
		per_shape[r.shape] = int(per_shape.get(r.shape, 0)) + 1
		per_status[r.status] = int(per_status.get(r.status, 0)) + 1
	return {"total": rooms.size(), "per_shape": per_shape, "per_status": per_status}


# --- abrir y crear --------------------------------------------------------------------------------------------------------------

func open(id: String) -> bool:
	if not index.has(id):
		message = "esa sala no está en la biblioteca"
		return false
	current = RoomLib.copy_room(index[id])
	original_id = id
	dirty = false
	verified = false
	undo_stack.clear()
	redo_stack.clear()
	play_state = null
	message = ""
	return true


func new_room(shape: String, h: int) -> bool:
	if not RoomLib.SHAPES.has(shape) or h < RoomLib.MIN_H or h > RoomLib.max_height(shape):
		message = "forma o altura fuera de rango"
		return false
	current = RoomLib.make_room(shape, h)
	current.origin = "manual"
	RoomLib.finalize(current)
	original_id = ""
	dirty = true
	verified = false
	undo_stack.clear()
	redo_stack.clear()
	play_state = null
	message = ""
	return true


func has_current() -> bool:
	return not current.is_empty()


# --- edición --------------------------------------------------------------------------------------------------------------------

func _push_undo() -> void:
	undo_stack.append(RoomLib.copy_room(current))
	if undo_stack.size() > UNDO_LIMIT:
		undo_stack.pop_front()
	redo_stack.clear()


func _edited() -> void:
	dirty = true
	verified = false
	play_state = null
	current.origin = "manual" if current.origin != "autor" else "autor"
	if original_id != "":
		current.parent = original_id
	# lo que ya no existe se saca de las marcas de variantes; el camino viejo queda para probar si todavía sirve
	var slots: Dictionary = {}
	for k in current.slots:
		var parts: PackedStringArray = str(k).split(",")
		if parts.size() == 3:
			var c := Vector2i(int(parts[0]), int(parts[2]))
			if current.cols.has(c) and String(current.cols[c]).length() >= int(parts[1]):
				slots[k] = current.slots[k]
	current.slots = slots
	current.variants = []
	current.opt = {"proof": "sin_probar", "stale": true}
	RoomLib.finalize(current)


func column(cell: Vector2i) -> String:
	return current.cols.get(cell, "")


func can_add(cell: Vector2i) -> String:
	if not RoomLib.free_cells(current.shape).has(cell):
		return "ahí no puede haber columnas"
	if column(cell).length() >= int(current.h) - 1:
		return "la columna ya llega a la altura máxima"
	return ""


func add_block(cell: Vector2i, kind: String) -> bool:
	var err := can_add(cell)
	if err != "" or not KINDS.has(kind):
		message = err if err != "" else "tipo desconocido"
		return false
	_push_undo()
	current.cols[cell] = column(cell) + kind
	_edited()
	return true


func delete_block(cell: Vector2i, y: int) -> bool:
	var ks := column(cell)
	if y < 1 or y > ks.length():
		message = "no hay un bloque ahí"
		return false
	_push_undo()
	var nk := ks.substr(0, y - 1) + ks.substr(y)
	if nk == "":
		current.cols.erase(cell)
	else:
		current.cols[cell] = nk
	_edited()
	return true


func set_kind(cell: Vector2i, y: int, kind: String) -> bool:
	var ks := column(cell)
	if y < 1 or y > ks.length() or not KINDS.has(kind):
		message = "no hay un bloque ahí"
		return false
	if ks[y - 1] == kind:
		return true
	_push_undo()
	current.cols[cell] = ks.substr(0, y - 1) + kind + ks.substr(y)
	_edited()
	return true


## Saca el bloque de (`src`, `y`) y lo pone arriba de la columna `dst`.
func move_block(src: Vector2i, y: int, dst: Vector2i) -> bool:
	if src == dst:
		message = "es la misma columna"
		return false
	var ks := column(src)
	if y < 1 or y > ks.length():
		message = "no hay un bloque ahí"
		return false
	var err := can_add(dst)
	if err != "":
		message = err
		return false
	_push_undo()
	var kind := ks[y - 1]
	var nk := ks.substr(0, y - 1) + ks.substr(y)
	if nk == "":
		current.cols.erase(src)
	else:
		current.cols[src] = nk
	current.cols[dst] = column(dst) + kind
	_edited()
	return true


func undo() -> bool:
	if undo_stack.is_empty():
		return false
	redo_stack.append(RoomLib.copy_room(current))
	current = undo_stack.pop_back()
	dirty = true
	verified = false
	play_state = null
	return true


func redo() -> bool:
	if redo_stack.is_empty():
		return false
	undo_stack.append(RoomLib.copy_room(current))
	current = redo_stack.pop_back()
	dirty = true
	verified = false
	play_state = null
	return true


## Deshace todos los cambios: la sala vuelve a ser la de la biblioteca (una sala nueva se descarta entera).
func revert() -> void:
	if original_id != "" and index.has(original_id):
		open(original_id)
	else:
		current = {}
		original_id = ""
		dirty = false
		verified = false
		undo_stack.clear()
		redo_stack.clear()
		play_state = null


# --- verificación ---------------------------------------------------------------------------------------------------------------

func block_count() -> int:
	var n := 0
	for c in current.cols:
		n += String(current.cols[c]).length()
	return n


## Vuelve a verificar la sala con el solucionador. Si el camino que tenía todavía la resuelve (y no se puede resolver caminando) se lo conserva; si no, se busca uno.
## {ok, why, moves, moved, grabs, reused}. Si no se resuelve queda sin camino.
func verify(max_ms := 5000) -> Dictionary:
	if current.is_empty():
		return {"ok": false, "why": "no hay sala"}
	var err := RoomLib.validate_structure(current)
	if err != "":
		current.path = []
		current.opt = {"proof": "sin_probar", "error": err}
		verified = false
		return {"ok": false, "why": err}
	var h: int = current.h
	if not current.path.is_empty() and RoomLib.replay(current, current.path).ok:
		var t = RoomLib.build_state(current)
		var plain: Dictionary = Solver.solve(t, h + 1, {"max_states": 40000, "goal_ids": t.goal_ids, "no_grab": true, "max_ms": max_ms})
		if plain.status == "unsolvable":
			var st := RoomLib.path_stats(current, current.path)
			if int(st.moved) >= 1:
				var proof := "sin_probar"
				var lower: int = int(current.opt.get("lower", h)) if not current.opt.is_empty() else h
				RoomLib.apply_result(current, current.path, proof, maxi(lower, h), 0)   # (saca las vueltas del camino)
				verified = true
				return {"ok": true, "why": "", "moves": current.path.size(), "moved": st.moved, "grabs": st.grabs, "reused": true}
	var ev := RoomLib.evaluate(current, {"cap": 6000 + 200 * h, "max_ms": max_ms, "h_weight": 1.0 if h <= 8 else 1.6})
	if not ev.ok:
		current.path = []
		current.opt = {"proof": "sin_probar", "error": str(ev.why)}
		verified = false
		return {"ok": false, "why": str(ev.why)}
	RoomLib.apply_result(current, ev.path, "sin_probar", h, int(ev.states))
	verified = true
	return {"ok": true, "why": "", "moves": ev.moves, "moved": ev.moved, "grabs": ev.grabs, "reused": false}


## Verificación exacta: el camino más corto garantizado (si el presupuesto alcanza). {proof, moves, lower}.
func verify_exact(cap := 80000, max_ms := 60000) -> Dictionary:
	if current.is_empty():
		return {"proof": "", "moves": -1, "lower": 0}
	if not verified:
		var v := verify()
		if not v.ok:
			return {"proof": "sin_resolver", "moves": -1, "lower": 0, "why": v.why}
	var res := RoomLib.verify_exact(current, cap, max_ms)
	if res.proof == "exacta":
		RoomLib.apply_result(current, res.path, "exacta", int(res.moves), int(res.states))
	elif res.proof == "cota":
		var before: int = current.path.size()
		var o := optimize_path()   # (no se probó todo: al menos se mejora el tramo final y se sacan las vueltas)
		current.opt = current.opt.duplicate()
		current.opt.proof = "exacta" if o.exact else "cota"
		current.opt.lower = maxi(int(current.opt.get("lower", 0)), int(res.lower))
		if o.exact:
			current.opt.lower = current.path.size()
			return {"proof": "exacta", "moves": current.path.size(), "lower": current.path.size()}
		return {"proof": "cota", "moves": -1, "lower": res.lower, "improved": before - current.path.size()}
	return {"proof": res.proof, "moves": res.moves, "lower": res.lower}


## Saca las vueltas del camino y mejora su tramo final con el verificador exacto. {before, after, proven, exact}. No cambia la sala, sólo su camino.
func optimize_path() -> Dictionary:
	if current.is_empty() or current.path.is_empty():
		return {"before": 0, "after": 0, "proven": 0, "exact": false}
	var before: int = current.path.size()
	var p := RoomLib.simplify_path(current, current.path)
	var imp := RoomLib.improve_tail(current, p, 20000, 4000)
	var best: Array = imp.path
	var exact: bool = int(imp.proven) >= best.size()
	if best.size() < before or exact:
		var proof := "exacta" if exact else str(current.opt.get("proof", "sin_probar"))
		var src: String = str(current.opt.get("source", ""))
		RoomLib.apply_result(current, best, proof, best.size() if exact else int(current.opt.get("lower", current.h)), int(current.opt.get("states", 0)))
		if src != "":
			current.opt.source = src
		verified = true
		dirty = true
	return {"before": before, "after": current.path.size(), "proven": imp.proven, "exact": exact}


## Poda el relleno de la sala actual (lo que no hace falta para su camino ni para que no se pueda resolver caminando). Devuelve cuántos bloques sacó.
func prune_current() -> int:
	if current.is_empty():
		return 0
	if not verified:
		var v := verify()
		if not v.ok:
			message = "la sala no se resuelve: no se puede podar"
			return 0
	var res := RoomLib.prune(current, null, 40000)
	if int(res.removed) <= 0:
		message = "no hay nada que sacar"
		return 0
	_push_undo()
	var src: String = str(current.opt.get("source", ""))
	var proof: String = str(current.opt.get("proof", "sin_probar"))
	var lower: int = int(current.opt.get("lower", current.h))
	current = res.room
	current.origin = "manual" if current.origin != "autor" else "autor"
	if original_id != "":
		current.parent = original_id
	RoomLib.apply_result(current, current.path, "sin_probar" if proof == "exacta" else proof, lower, 0)
	if src != "":
		current.opt.source = src
	dirty = true
	verified = true
	play_state = null
	return int(res.removed)


# --- guardar --------------------------------------------------------------------------------------------------------------------

## Guarda la sala en la biblioteca. `replace`: si viene de otra de la biblioteca, la reemplaza (si no, se agrega como una nueva). {ok, msg}.
func save(replace := true) -> Dictionary:
	if current.is_empty():
		return {"ok": false, "msg": "no hay sala"}
	var err := RoomLib.validate_structure(current)
	if err != "":
		return {"ok": false, "msg": err}
	if current.path.is_empty() or not RoomLib.replay(current, current.path).ok:
		var v := verify()
		if not v.ok:
			return {"ok": false, "msg": "la sala no se resuelve (%s): no se guarda" % str(v.why)}
	RoomLib.finalize(current)
	var clash: bool = index.has(current.id) and not (replace and current.id == original_id)
	if clash:
		return {"ok": false, "msg": "ya hay una sala igual en la biblioteca"}
	current.stamp = int(Time.get_unix_time_from_system())
	if current.origin == "minero" and dirty:
		current.origin = "manual"
	var rec := RoomLib.copy_room(current)
	if replace and original_id != "" and index.has(original_id):
		rooms[rooms.find(index[original_id])] = rec
	else:
		rooms.append(rec)
	reindex()
	if not _write():
		return {"ok": false, "msg": message}
	original_id = rec.id
	dirty = false
	message = "guardada"
	return {"ok": true, "msg": "guardada"}


func delete_room(id: String) -> bool:
	if not index.has(id):
		return false
	rooms.erase(index[id])
	reindex()
	if original_id == id:
		current = {}
		original_id = ""
		dirty = false
	return _write()


## Cambia el estado (nuevo, buena, mala, mejorable) y la nota de una sala de la biblioteca y guarda. No cambia la estructura ni los hashes.
func annotate(id: String, status: String, note: String) -> bool:
	if not index.has(id) or not RoomLib.STATUSES.has(status):
		return false
	var r: Dictionary = index[id]
	r.status = status
	r.note = note
	if not current.is_empty() and current.id == id:
		current.status = status
		current.note = note
	return _write()


# --- parecidos ------------------------------------------------------------------------------------------------------------------

func _set_of(r: Dictionary) -> Dictionary:
	if not _sets.has(r.id):
		_sets[r.id] = RoomLib.block_set(r)
	return _sets[r.id]


## Las `n` salas más parecidas a la actual: [{room, dist}], de la más cercana a la más lejana. La sala actual (y su versión de la biblioteca) no figuran.
func similar(n := 5) -> Array:
	if current.is_empty():
		return []
	var mine := RoomLib.block_sets_all(current)
	var out: Array = []
	for r in rooms:
		if r.id == current.id or r.id == original_id:
			continue
		out.append({"room": r, "dist": RoomLib.distance(current, r, mine, _set_of(r))})
	out.sort_custom(func(a, b): return a.dist < b.dist)
	return out.slice(0, n)


# --- variantes de tipo ----------------------------------------------------------------------------------------------------------

static func slot_key(cell: Vector2i, y: int) -> String:
	return "%d,%d,%d" % [cell.x, y, cell.y]


## Marca qué otros tipos puede tener el bloque (cell, y): `kinds` son los caracteres permitidos además del actual ("" = ninguno).
func set_slot(cell: Vector2i, y: int, kinds: String) -> bool:
	var ks := column(cell)
	if y < 1 or y > ks.length():
		return false
	var clean := ""
	for ch in kinds:
		if KINDS.has(ch) and ch != ks[y - 1] and clean.find(ch) == -1:
			clean += ch
	var key := slot_key(cell, y)
	if clean == "":
		current.slots.erase(key)
	else:
		current.slots[key] = clean
	dirty = true
	return true


func slot_of(cell: Vector2i, y: int) -> String:
	return str(current.slots.get(slot_key(cell, y), ""))


func _variant_room(cell: Vector2i, y: int, kind: String) -> Dictionary:
	var v := RoomLib.copy_room(current)
	var ks: String = v.cols[cell]
	v.cols[cell] = ks.substr(0, y - 1) + kind + ks.substr(y)
	v.slots = {}
	v.variants = []
	v.variant_of = current.id
	v.origin = "manual"
	v.parent = current.id
	RoomLib.finalize(v)
	return v


## Prueba cada variante marcada: cambia el tipo del bloque, vuelve a resolver la sala y dice si sigue sirviendo. [{key, kind, ok, moves, why}].
func check_variants() -> Array:
	var out: Array = []
	if current.is_empty():
		return out
	for key in current.slots:
		var parts: PackedStringArray = str(key).split(",")
		var cell := Vector2i(int(parts[0]), int(parts[2]))
		var y := int(parts[1])
		for kind in str(current.slots[key]):
			var v := _variant_room(cell, y, kind)
			var res := {"key": key, "kind": kind, "ok": false, "moves": -1, "why": ""}
			if index.has(v.id) and v.id != current.id:
				res.why = "ya está en la biblioteca"
			else:
				var ev := RoomLib.evaluate(v, {"cap": 6000 + 200 * v.h, "max_ms": 6000, "h_weight": 1.0 if v.h <= 8 else 1.6})
				if ev.ok:
					res.ok = true
					res.moves = ev.moves
				else:
					res.why = str(ev.why)
			out.append(res)
	current.variants = out
	return out


## Crea una sala nueva en la biblioteca por cada variante válida marcada. Devuelve cuántas.
func create_variants() -> int:
	if current.is_empty():
		return 0
	var results := check_variants()
	var n := 0
	for r in results:
		if not r.ok:
			continue
		var parts: PackedStringArray = str(r.key).split(",")
		var v := _variant_room(Vector2i(int(parts[0]), int(parts[2])), int(parts[1]), str(r.kind))
		if index.has(v.id):
			continue
		var ev := RoomLib.evaluate(v, {"cap": 6000 + 200 * v.h, "max_ms": 6000, "h_weight": 1.0 if v.h <= 8 else 1.6})
		if not ev.ok:
			continue
		RoomLib.apply_result(v, ev.path, "sin_probar", v.h, int(ev.states))
		v.stamp = int(Time.get_unix_time_from_system())
		rooms.append(v)
		index[v.id] = v
		n += 1
	if n > 0:
		reindex()
		_write()
	return n


# --- reproducción ---------------------------------------------------------------------------------------------------------------

func play_reset() -> void:
	play_state = RoomLib.build_state(current) if not current.is_empty() else null
	play_index = 0


## Aplica el próximo paso del camino. {ok, done, i}.
func play_step() -> Dictionary:
	if play_state == null:
		play_reset()
	if play_state == null or current.path.is_empty():
		return {"ok": false, "done": true, "i": 0}
	if play_index >= current.path.size():
		return {"ok": true, "done": true, "i": play_index}
	var a: Dictionary = current.path[play_index]
	var r: Dictionary = play_state.try_action(a.dir, a.mode)
	if not r.ok or play_state.lost:
		return {"ok": false, "done": true, "i": play_index}
	play_index += 1
	return {"ok": true, "done": play_index >= current.path.size(), "i": play_index}


## Vuelve un paso atrás: rearma la sala y repite hasta el paso anterior.
func play_back() -> void:
	var target := maxi(play_index - 1, 0)
	play_reset()
	for _i in target:
		play_step()


func play_to(i: int) -> void:
	play_reset()
	for _k in mini(i, current.path.size()):
		play_step()


## El simulador que se dibuja: el de la reproducción si hay, y si no el de la sala quieta.
func view_state():
	if play_state != null:
		return play_state
	if current.is_empty():
		return null
	return RoomLib.build_state(current)
