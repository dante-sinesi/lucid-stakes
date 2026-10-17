extends RefCounted
## La lógica del editor de modelos (model_editor.gd): el modelo que se está editando, sus partes, la paleta, pintar, borrar, rellenar una capa, simetría, deshacer y rehacer,
## y la verificación. Sin pantalla: se prueba en tests/test_modelos.gd. El formato está en model_lib.gd.

const ModelLib := preload("res://scripts/model_lib.gd")
const BlockModels := preload("res://scripts/block_models.gd")

const KINDS := ["bloque", "cosmetico", "personaje"]
const SLOTS := ["gorro", "prenda"]
const RARITIES := ["comun", "raro", "epico"]
const REQUIRED_PARTS := ["cuerpo", "pata_i", "pata_d", "brazo_i", "brazo_d"]
const MAX_UNDO := 100
const MAX_BLOCK_VOXELS := 1000   # (para vigilar el costo de dibujo: un bloque normal tiene unos 100)
const MAX_CHAR_VOXELS := 8000

var id := ""
var kind := "bloque"
var model_name := ""
var block := "normal"
var variant := 0
var state := "pure"
var slot := "gorro"
var rarity := "comun"
var voxel := 0.04
var size := Vector3i(5, 5, 5)
var origin := Vector3i.ZERO
var palette: Array = []
var parts: Array = []        # [{"name": String, "pivot": Vector3 | null, "map": {Vector3i: int}}]
var part := 0                # la parte que se está editando
var color_index := 0
var mirror_x := false
var mirror_z := false
var only_layer := -1         # >= 0: sólo se ve y se pinta esa capa (y)
var dirty := false
var _undo: Array = []
var _redo: Array = []


# --- modelos nuevos -----------------------------------------------------------------------------------------------------

static func new_model(model_kind: String, model_id: String) -> RefCounted:
	var m = load("res://scripts/model_editor_model.gd").new()
	m.kind = model_kind
	m.id = model_id
	m.model_name = model_id
	match model_kind:
		"bloque":
			m.voxel = BlockModels.VOXEL
			m.size = Vector3i(BlockModels.N, BlockModels.N, BlockModels.N)
			m.origin = Vector3i.ZERO
			m.parts = [{"name": "bloque", "pivot": null, "map": {}}]
		"cosmetico":
			m.voxel = ModelLib.VOX
			m.size = ModelLib.CHAR_SIZE
			m.origin = ModelLib.CHAR_ORIGIN
			m.parts = [{"name": "pieza", "pivot": null, "map": {}}]
		_:
			m.voxel = ModelLib.VOX
			m.size = ModelLib.CHAR_SIZE
			m.origin = ModelLib.CHAR_ORIGIN
			m.parts = []
			for n in REQUIRED_PARTS:
				m.parts.append({"name": n, "pivot": null, "map": {}})
			m.parts.append({"name": "cola", "pivot": null, "map": {}})
	m.palette = [Color(0.9, 0.9, 0.9), Color(0.6, 0.6, 0.65), Color(0.3, 0.3, 0.35), Color(1.0, 0.8, 0.25), Color(0.85, 0.2, 0.2), Color(0.25, 0.65, 0.35), Color(0.25, 0.45, 0.9), Color(0.1, 0.08, 0.12)]
	return m


## Desde un registro del formato de model_lib.gd.
static func from_record(rec: Dictionary) -> RefCounted:
	var m = load("res://scripts/model_editor_model.gd").new()
	m.id = str(rec.get("id", ""))
	m.kind = str(rec.get("kind", "bloque"))
	m.model_name = str(rec.get("name", m.id))
	m.block = str(rec.get("block", "normal"))
	m.variant = int(rec.get("variant", 0))
	m.state = str(rec.get("state", "pure"))
	m.slot = str(rec.get("slot", "gorro"))
	m.rarity = str(rec.get("rarity", "comun"))
	m.voxel = float(rec.get("voxel", ModelLib.VOX))
	var s: Array = rec.get("size", [5, 5, 5])
	m.size = Vector3i(int(s[0]), int(s[1]), int(s[2]))
	var o: Array = rec.get("origin", [0, 0, 0])
	m.origin = Vector3i(int(o[0]), int(o[1]), int(o[2]))
	m.palette = []
	for h in rec.get("palette", []):
		m.palette.append(Color.html(str(h)))
	m.parts = []
	for p in rec.get("parts", []):
		var pv = p.get("pivot", null)
		var map := {}
		for v in p.get("voxels", []):
			map[Vector3i(int(v[0]), int(v[1]), int(v[2]))] = int(v[3])
		m.parts.append({"name": str(p.get("name", "")), "pivot": Vector3(float(pv[0]), float(pv[1]), float(pv[2])) if pv != null else null, "map": map})
	if m.parts.is_empty():
		m.parts = [{"name": "pieza", "pivot": null, "map": {}}]
	return m


func to_record() -> Dictionary:
	var rec := {"id": id, "kind": kind, "name": model_name, "voxel": voxel, "size": [size.x, size.y, size.z], "origin": [origin.x, origin.y, origin.z]}
	match kind:
		"bloque":
			rec["block"] = block
			rec["variant"] = variant
			rec["state"] = state
		"cosmetico":
			rec["slot"] = slot
			rec["rarity"] = rarity
	var pal: Array = []
	for c in palette:
		pal.append("#" + c.to_html(false))
	rec["palette"] = pal
	var out_parts: Array = []
	for p in parts:
		var vox: Array = []
		var keys: Array = (p.map as Dictionary).keys()
		keys.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and (a.z < b.z or (a.z == b.z and a.x < b.x))))
		for k in keys:
			vox.append([k.x, k.y, k.z, int(p.map[k])])
		var pv = p.pivot
		out_parts.append({"name": p.name, "pivot": [pv.x, pv.y, pv.z] if pv != null else null, "voxels": vox})
	rec["parts"] = out_parts
	return rec


# --- consultas ----------------------------------------------------------------------------------------------------------------

func current_map() -> Dictionary:
	return parts[part].map


func in_box(c: Vector3i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.z >= 0 and c.x < size.x and c.y < size.y and c.z < size.z


func voxel_total() -> int:
	var n := 0
	for p in parts:
		n += (p.map as Dictionary).size()
	return n


## Todos los minibloques visibles como {Vector3i: Color} (todas las partes; con `only_layer`, sólo esa capa).
func color_map(include_all_parts := true) -> Dictionary:
	var out := {}
	for i in parts.size():
		if not include_all_parts and i != part:
			continue
		for c in parts[i].map:
			if only_layer >= 0 and c.y != only_layer:
				continue
			out[c] = palette[clampi(int(parts[i].map[c]), 0, palette.size() - 1)] if not palette.is_empty() else Color.MAGENTA
	return out


# --- cambios (con deshacer) -----------------------------------------------------------------------------------------------

func _snapshot() -> Dictionary:
	var ms: Array = []
	for p in parts:
		ms.append((p.map as Dictionary).duplicate())
	return {"maps": ms, "palette": palette.duplicate(), "pivots": parts.map(func(p): return p.pivot)}


func _restore(s: Dictionary) -> void:
	for i in parts.size():
		parts[i].map = (s.maps[i] as Dictionary).duplicate()
		parts[i].pivot = s.pivots[i]
	palette = (s.palette as Array).duplicate()


func _push_undo() -> void:
	_undo.append(_snapshot())
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()
	_redo.clear()
	dirty = true


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(_snapshot())
	_restore(_undo.pop_back())
	dirty = true


func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(_snapshot())
	_restore(_redo.pop_back())
	dirty = true


## Las celdas que se pintan o borran con una pincelada en `c`: la celda y sus espejos (según la simetría).
func brush_cells(c: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = [c]
	if mirror_x:
		out.append(Vector3i(size.x - 1 - c.x, c.y, c.z))
	if mirror_z:
		out.append(Vector3i(c.x, c.y, size.z - 1 - c.z))
	if mirror_x and mirror_z:
		out.append(Vector3i(size.x - 1 - c.x, c.y, size.z - 1 - c.z))
	var uniq: Array[Vector3i] = []
	for o in out:
		if not uniq.has(o):
			uniq.append(o)
	return uniq


## Pone un minibloque del color elegido en `c` (y en sus espejos). false si cae fuera de la caja o de la capa visible.
func paint(c: Vector3i) -> bool:
	var did := false
	var snap_taken := false
	for cell in brush_cells(c):
		if not in_box(cell) or (only_layer >= 0 and cell.y != only_layer):
			continue
		if int(current_map().get(cell, -1)) == color_index:
			continue
		if not snap_taken:
			_push_undo()
			snap_taken = true
		current_map()[cell] = color_index
		did = true
	return did


func erase(c: Vector3i) -> bool:
	var did := false
	var snap_taken := false
	for cell in brush_cells(c):
		if current_map().has(cell):
			if not snap_taken:
				_push_undo()
				snap_taken = true
			current_map().erase(cell)
			did = true
	return did


## El color de la celda (cuentagotas): lo deja elegido y devuelve true si había algo.
func pick(c: Vector3i) -> bool:
	for i in range(parts.size() - 1, -1, -1):
		if parts[i].map.has(c):
			color_index = int(parts[i].map[c])
			return true
	return false


## Rellena una capa entera de la parte actual con el color elegido (donde todavía no hay nada, o todo si `overwrite`).
func fill_layer(y: int, overwrite := false) -> int:
	if y < 0 or y >= size.y:
		return 0
	_push_undo()
	var n := 0
	for x in size.x:
		for z in size.z:
			var c := Vector3i(x, y, z)
			if overwrite or not current_map().has(c):
				current_map()[c] = color_index
				n += 1
	return n


## Vacía una capa de la parte actual.
func clear_layer(y: int) -> void:
	_push_undo()
	for x in size.x:
		for z in size.z:
			current_map().erase(Vector3i(x, y, z))


## Cambia un color de la paleta: todos los minibloques que lo usan cambian con él.
func set_palette_color(i: int, c: Color) -> void:
	if i < 0 or i >= palette.size():
		return
	_push_undo()
	palette[i] = c


func add_palette_color(c: Color) -> int:
	_push_undo()
	palette.append(c)
	return palette.size() - 1


func set_pivot(p: Vector3) -> void:
	_push_undo()
	parts[part].pivot = p


## Espeja la parte actual en x (reflejo exacto dentro de la caja).
func flip_x() -> void:
	_push_undo()
	var out := {}
	for c in current_map():
		out[Vector3i(size.x - 1 - c.x, c.y, c.z)] = current_map()[c]
	parts[part].map = out


## Mueve toda la parte actual (para acomodarla en la caja).
func shift_part(d: Vector3i) -> void:
	_push_undo()
	var out := {}
	for c in current_map():
		var n: Vector3i = c + d
		if in_box(n):
			out[n] = current_map()[c]
	parts[part].map = out


## Cambia el tamaño de la caja de edición (lo que queda fuera se pierde).
func resize(new_size: Vector3i) -> void:
	_push_undo()
	size = new_size
	for p in parts:
		var out := {}
		for c in p.map:
			if in_box(c):
				out[c] = p.map[c]
		p.map = out


# --- verificación -------------------------------------------------------------------------------------------------------------

## Los problemas del modelo (vacío = está bien).
func verify() -> Array[String]:
	var out: Array[String] = []
	if id.strip_edges() == "":
		out.append("Falta el id.")
	if voxel_total() == 0:
		out.append("El modelo está vacío.")
	match kind:
		"bloque":
			if not ModelLib.BLOCK_NAMES.values().has(block):
				out.append("El tipo de bloque «%s» no existe." % block)
			if voxel_total() > MAX_BLOCK_VOXELS:
				out.append("Tiene %d minibloques: demasiados para dibujar miles de bloques (máximo %d)." % [voxel_total(), MAX_BLOCK_VOXELS])
			if block != "bomba" and block != "pinchos" and voxel_total() > 0:
				var map: Dictionary = parts[0].map
				var cx := size.x
				var top := size.y - 1
				var center_missing := 0
				for x in range(1, cx - 1):
					for z in range(1, size.z - 1):
						if not map.has(Vector3i(x, top, z)):
							center_missing += 1
				if center_missing > 0:
					out.append("La cara de arriba tiene huecos en el centro (%d): el jugador tiene que ver dónde pisa." % center_missing)
		"cosmetico":
			if not SLOTS.has(slot):
				out.append("El hueco «%s» no existe (gorro o prenda)." % slot)
			if not RARITIES.has(rarity):
				out.append("La rareza «%s» no existe." % rarity)
			if voxel_total() > MAX_CHAR_VOXELS / 2:
				out.append("Tiene %d minibloques: demasiados para una pieza de ropa." % voxel_total())
		"personaje":
			var have := {}
			for p in parts:
				have[p.name] = (p.map as Dictionary).size() > 0
			for n in REQUIRED_PARTS:
				if not have.get(n, false):
					out.append("Falta la parte «%s»." % n)
			for p in parts:
				if ModelLib.MOVING_PARTS.has(str(p.name)) and (p.map as Dictionary).size() > 0 and p.pivot == null:
					out.append("La parte «%s» necesita su pivote (de donde gira al caminar)." % p.name)
			if voxel_total() > MAX_CHAR_VOXELS:
				out.append("Tiene %d minibloques (máximo %d)." % [voxel_total(), MAX_CHAR_VOXELS])
	return out
