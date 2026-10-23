extends RefCounted
## Los modelos de minibloques que se hacen con el editor de modelos (model_editor.gd): bloques con variantes, cosméticos y personajes. Es una herramienta de desarrollo:
## los modelos los hace Dante y se integran al juego; no hay nada para que el jugador cree los suyos.
##
## Formato (data/modelos/*.jsonl, una línea JSON por modelo):
##   {"id", "kind": "bloque" | "cosmetico" | "personaje", "name", "voxel": lado de un minibloque en el mundo, "size": [x, y, z] (la caja de edición),
##    "origin": [x, y, z] (el minibloque donde está el origen del modelo: los pies, para personajes y cosméticos), "palette": ["#rrggbb", ...],
##    "parts": [{"name", "pivot": [x, y, z] | null, "voxels": [[x, y, z, índice de la paleta], ...]}],
##    bloques: "block" (normal, hielo, bomba, catapulta, agrietado, pesado, trampa, pinchos, nucleo), "variant" (0, 1, 2...), "state" ("pure" | "defused");
##    cosméticos: "slot" ("gorro" | "prenda"), "rarity" ("comun" | "raro" | "epico")}
## Un modelo con el id de un personaje o cosmético que ya existe reemplaza su diseño hecho en código; uno de bloque reemplaza esa variante (o agrega una nueva).
## Los personajes y cosméticos usan la misma caja de 24 x 32 x 24 minibloques de 0,04 con el origen en los pies (12, 0, 12); los bloques, una de 5 x 5 x 5 (o más).
## Las partes de un personaje que giran al caminar se llaman pata_i, pata_d, brazo_i, brazo_d y cola, y llevan su pivote.

const VoxelMesh := preload("res://scripts/ui/voxel_mesh.gd")

const DIR := "res://data/modelos"
const VOX := 0.04                          # minibloque de personajes y cosméticos
const CHAR_SIZE := Vector3i(24, 32, 24)    # caja de edición de personajes y cosméticos
const CHAR_ORIGIN := Vector3i(12, 0, 12)
const BLOCK_NAMES := {0: "normal", 1: "hielo", 2: "bomba", 3: "catapulta", 4: "agrietado", 5: "pesado", 6: "trampa", 7: "pinchos", 9: "nucleo"}
const MOVING_PARTS := ["pata_i", "pata_d", "brazo_i", "brazo_d", "cola"]

## Carpeta de donde se leen y a donde se guardan los modelos (las pruebas la cambian).
static var dir := DIR
static var _loaded_from := ""
static var _records: Array = []
static var _blocks := {}   # "bloque|variante|estado" -> {Vector3i: Color}
static var _block_max := {}   # nombre del bloque -> cantidad de variantes


static func reload() -> void:
	_loaded_from = dir
	_records = []
	_blocks = {}
	_block_max = {}
	var d := DirAccess.open(dir)
	if d != null:
		var files := d.get_files()
		files.sort()
		for f in files:
			if f.ends_with(".jsonl"):
				_records.append_array(read_file(dir + "/" + f))
	for r in _records:
		if str(r.get("kind", "")) == "bloque":
			var name := str(r.get("block", ""))
			var key := "%s|%d|%s" % [name, int(r.get("variant", 0)), str(r.get("state", "pure"))]
			_blocks[key] = voxel_map(r, 0)
			_block_max[name] = maxi(int(_block_max.get(name, 0)), int(r.get("variant", 0)) + 1)


static func _ensure() -> void:
	if _loaded_from != dir:
		reload()


static func records(kind := "") -> Array:
	_ensure()
	if kind == "":
		return _records
	return _records.filter(func(r): return str(r.get("kind", "")) == kind)


## Los modelos de un archivo .jsonl.
static func read_file(path: String) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		var rec = JSON.parse_string(line)
		if typeof(rec) == TYPE_DICTIONARY and rec.has("id") and rec.has("parts"):
			out.append(rec)
	f.close()
	return out


## Guarda los modelos de `recs` en un archivo (reemplaza todo su contenido).
static func write_file(path: String, recs: Array) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	for r in recs:
		f.store_line(JSON.stringify(r))
	f.close()
	_loaded_from = ""
	return true


## La identidad de un modelo (sirve para reemplazarlo al guardar).
static func key_of(r: Dictionary) -> String:
	if str(r.get("kind", "")) == "bloque":
		return "bloque|%s|%d|%s" % [str(r.get("block", "")), int(r.get("variant", 0)), str(r.get("state", "pure"))]
	return "%s|%s" % [str(r.get("kind", "")), str(r.id)]


## Guarda (o reemplaza) un modelo en un archivo de la carpeta de modelos.
static func save_record(rec: Dictionary, file := "modelos.jsonl") -> bool:
	var path := dir + "/" + file
	var recs := read_file(path)
	var replaced := false
	for i in recs.size():
		if key_of(recs[i]) == key_of(rec):
			recs[i] = rec
			replaced = true
	if not replaced:
		recs.append(rec)
	return write_file(path, recs)


## Saca un modelo (de cualquier archivo de la carpeta).
static func delete_record(rec: Dictionary) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if not f.ends_with(".jsonl"):
			continue
		var recs := read_file(dir + "/" + f)
		var keep := recs.filter(func(r): return key_of(r) != key_of(rec))
		if keep.size() != recs.size():
			write_file(dir + "/" + f, keep)


# --- lectura de un modelo -----------------------------------------------------------------------------------------------------

static func palette_color(rec: Dictionary, i: int) -> Color:
	var pal: Array = rec.get("palette", [])
	if i < 0 or i >= pal.size():
		return Color.MAGENTA
	return Color.html(str(pal[i]))


## Los minibloques de una parte: {Vector3i: Color}.
static func voxel_map(rec: Dictionary, part_index := 0) -> Dictionary:
	var out := {}
	var parts: Array = rec.get("parts", [])
	if part_index < 0 or part_index >= parts.size():
		return out
	var cols := {}
	for v in parts[part_index].get("voxels", []):
		var i := int(v[3])
		if not cols.has(i):
			cols[i] = palette_color(rec, i)
		out[Vector3i(int(v[0]), int(v[1]), int(v[2]))] = cols[i]
	return out


## De un mapa de minibloques {Vector3i: Color} a la lista del formato y su paleta (se agregan los colores nuevos a `palette`).
static func pack_voxels(map: Dictionary, palette: Array) -> Array:
	var out: Array = []
	var index := {}
	for i in palette.size():
		index[str(palette[i]).to_lower()] = i
	var keys := map.keys()
	keys.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and (a.z < b.z or (a.z == b.z and a.x < b.x))))
	for p in keys:
		var h := "#" + (map[p] as Color).to_html(false)
		if not index.has(h):
			index[h] = palette.size()
			palette.append(h)
		out.append([p.x, p.y, p.z, index[h]])
	return out


# --- bloques ------------------------------------------------------------------------------------------------------------------

static func block_name(kind: int) -> String:
	return str(BLOCK_NAMES.get(kind, ""))


## Cuántas variantes de ese tipo hay guardadas con el editor (0 si ninguna).
static func block_variant_count(kind: int) -> int:
	_ensure()
	return int(_block_max.get(block_name(kind), 0))


## El modelo completo de una variante de bloque ({} si el editor no guardó esa): con `defused`, el de la bomba desactivada (o el normal en gris si no hay).
static func block_model(kind: int, variant: int, defused := false) -> Dictionary:
	_ensure()
	var name := block_name(kind)
	if defused:
		var k2 := "%s|%d|defused" % [name, variant]
		if _blocks.has(k2):
			return (_blocks[k2] as Dictionary).duplicate()
	var k := "%s|%d|pure" % [name, variant]
	if not _blocks.has(k):
		return {}
	var m: Dictionary = (_blocks[k] as Dictionary).duplicate()
	if defused:
		for p in m:
			var c: Color = m[p]
			m[p] = c.lerp(Color(0.5, 0.55, 0.5), 0.6)
	return m


# --- personajes y cosméticos ----------------------------------------------------------------------------------------------------

static func find(kind: String, id: String) -> Dictionary:
	_ensure()
	for r in _records:
		if str(r.get("kind", "")) == kind and str(r.id) == id:
			return r
	return {}


static func character(id: String) -> Dictionary:
	return find("personaje", id)


static func cosmetic(id: String) -> Dictionary:
	return find("cosmetico", id)


static func _color_mean(map: Dictionary) -> Color:
	var r := 0.0
	var g := 0.0
	var b := 0.0
	for p in map:
		var c: Color = map[p]
		r += c.r
		g += c.g
		b += c.b
	var n := maxf(float(map.size()), 1.0)
	return Color(r / n, g / n, b / n)


## Una malla con el color por vértice y su material (el de la silueta, `ghost_mat`, tomando el color promedio, si se pide).
static func _part_mesh(map: Dictionary, vox: float, ghost_maker: Callable) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = VoxelMesh.build(map, vox)
	var ghost_mat = ghost_maker.call(_color_mean(map)) if ghost_maker.is_valid() else null   # (el creador devuelve null si no es silueta)
	if ghost_mat != null:
		mi.material_override = ghost_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.9
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS   # (como el resto del personaje: ver Cosmetics.box)
		mat.render_priority = 20
		mi.material_override = mat
	return mi


## El nodo 3D de un modelo de personaje o cosmético (origen en los pies): una malla por parte; las que giran van colgadas de un nodo con su nombre en el pivote.
## `ghost_maker`: función (Color) -> Material de silueta, o una Callable inválida para el material normal.
static func build_node(rec: Dictionary, node_name: String, ghost_maker := Callable()) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	var vox := float(rec.get("voxel", VOX))
	var o: Array = rec.get("origin", [CHAR_ORIGIN.x, CHAR_ORIGIN.y, CHAR_ORIGIN.z])
	var origin := Vector3(float(o[0]), float(o[1]), float(o[2]))
	var parts: Array = rec.get("parts", [])
	for i in parts.size():
		var part: Dictionary = parts[i]
		var map := voxel_map(rec, i)
		if map.is_empty():
			continue
		var mi := _part_mesh(map, vox, ghost_maker)
		var pv = part.get("pivot", null)
		var pname := str(part.get("name", ""))
		if pv != null and pname != "" and MOVING_PARTS.has(pname):
			var pivot := Vector3(float(pv[0]), float(pv[1]), float(pv[2]))
			var holder := Node3D.new()
			holder.name = pname
			holder.position = (pivot - origin) * vox
			mi.position = -pivot * vox
			holder.add_child(mi)
			root.add_child(holder)
		else:
			mi.position = -origin * vox
			mi.name = pname if pname != "" else "parte_%d" % i
			root.add_child(mi)
	return root


# --- pasar un diseño hecho en código a minibloques --------------------------------------------------------------------------------

## Convierte un modelo armado con cajas (Characters.build, Cosmetics.build_hat...) en un registro del formato: cada caja pasa a minibloques de `vox` en la caja de
## edición de personajes (24 x 32 x 24, origen en los pies). Las cajas más finas que un minibloque se vuelven de un minibloque. Devuelve {parts, palette}.
static func voxelize(root: Node3D, vox := VOX) -> Dictionary:
	var palette: Array = []
	var maps := {}     # nombre de parte -> {Vector3i: Color}
	var pivots := {}
	_voxelize_node(root, Transform3D.IDENTITY, root, vox, maps, pivots)
	var parts: Array = []
	var names := maps.keys()
	names.sort_custom(func(a, b): return a == "cuerpo" or (b != "cuerpo" and str(a) < str(b)))
	for n in names:
		var pv = pivots.get(n, null)
		parts.append({"name": n, "pivot": pv, "voxels": pack_voxels(maps[n], palette)})
	return {"parts": parts, "palette": palette}


static func _voxelize_node(node: Node3D, xf: Transform3D, root: Node3D, vox: float, maps: Dictionary, pivots: Dictionary) -> void:
	for ch in node.get_children():
		if not (ch is Node3D):
			continue
		var cx: Transform3D = xf * (ch as Node3D).transform
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh is BoxMesh:
			var part := "cuerpo"
			var anc: Node = ch.get_parent()
			while anc != null and anc != root:
				if MOVING_PARTS.has(str(anc.name)):
					part = str(anc.name)
					break
				anc = anc.get_parent()
			if part != "cuerpo" and not pivots.has(part):
				var n3 := anc as Node3D
				var pos: Vector3 = _node_pos_in_root(n3, root)
				pivots[part] = [pos.x / vox + CHAR_ORIGIN.x, pos.y / vox + CHAR_ORIGIN.y, pos.z / vox + CHAR_ORIGIN.z]
			if not maps.has(part):
				maps[part] = {}
			var bm := (ch as MeshInstance3D).mesh as BoxMesh
			var color := Color.MAGENTA
			var mat := (ch as MeshInstance3D).material_override
			if mat is StandardMaterial3D:
				color = (mat as StandardMaterial3D).albedo_color
				color.a = 1.0
			var c := cx.origin
			var hs := Vector3(maxf(bm.size.x * 0.5, vox * 0.5), maxf(bm.size.y * 0.5, vox * 0.5), maxf(bm.size.z * 0.5, vox * 0.5))
			var lo := Vector3i(floori((c.x - hs.x) / vox) - 1, floori((c.y - hs.y) / vox) - 1, floori((c.z - hs.z) / vox) - 1)
			var hi := Vector3i(ceili((c.x + hs.x) / vox) + 1, ceili((c.y + hs.y) / vox) + 1, ceili((c.z + hs.z) / vox) + 1)
			for ix in range(lo.x, hi.x + 1):
				for iy in range(lo.y, hi.y + 1):
					for iz in range(lo.z, hi.z + 1):
						var vc := Vector3((ix + 0.5) * vox, (iy + 0.5) * vox, (iz + 0.5) * vox)
						if absf(vc.x - c.x) <= hs.x + 0.0001 and absf(vc.y - c.y) <= hs.y + 0.0001 and absf(vc.z - c.z) <= hs.z + 0.0001:
							var idx := Vector3i(ix + CHAR_ORIGIN.x, iy + CHAR_ORIGIN.y, iz + CHAR_ORIGIN.z)
							if idx.x >= 0 and idx.y >= 0 and idx.z >= 0 and idx.x < CHAR_SIZE.x and idx.y < CHAR_SIZE.y and idx.z < CHAR_SIZE.z:
								maps[part][idx] = color
		_voxelize_node(ch as Node3D, cx, root, vox, maps, pivots)


static func _node_pos_in_root(n: Node3D, root: Node3D) -> Vector3:
	var p := Vector3.ZERO
	var cur: Node = n
	while cur != null and cur != root:
		p += (cur as Node3D).position
		cur = cur.get_parent()
	return p
