extends RefCounted
## Pasa al formato del editor de modelos (model_lib.gd) los diseños que hoy están hechos en código: las variantes de cada bloque (BlockModels), los personajes (Characters)
## y los cosméticos (Cosmetics). Sirve de punto de partida: se abre el modelo en el editor y se retoca. Los personajes y cosméticos se convierten con
## ModelLib.voxelize (cada caja pasa a minibloques de 0,04).

const ModelLib := preload("res://scripts/personajes/model_lib.gd")
const BlockModels := preload("res://scripts/personajes/block_models.gd")
const Characters := preload("res://scripts/personajes/characters.gd")
const Cosmetics := preload("res://scripts/personajes/cosmetics.gd")
const Tipos := preload("res://torre/tipos.gd")

const BLOCK_KINDS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 9]


## Un registro de bloque desde un mapa {Vector3i: Color}.
static func block_record(kind: int, variant: int, state: String, map: Dictionary) -> Dictionary:
	var palette: Array = []
	var name := ModelLib.block_name(kind)
	return {"id": "%s_%d%s" % [name, variant, "_desactivada" if state == "defused" else ""], "kind": "bloque", "name": "%s (variante %d)" % [name, variant], "block": name, "variant": variant, "state": state,
			"voxel": BlockModels.VOXEL, "size": [BlockModels.N, BlockModels.N, BlockModels.N], "origin": [0, 0, 0],
			"parts": [{"name": "bloque", "pivot": null, "voxels": ModelLib.pack_voxels(map, palette)}], "palette": palette}


## Todas las variantes de bloque del código (con la bomba desactivada aparte).
static func blocks() -> Array:
	var out: Array = []
	for kind in BLOCK_KINDS:
		for v in BlockModels.VARIANTS:
			out.append(block_record(kind, v, "pure", BlockModels._voxels(kind, BlockModels.State.PURE, v)))
			if kind == Tipos.Kind.BOMB:
				out.append(block_record(kind, v, "defused", BlockModels._voxels(kind, BlockModels.State.DEFUSED, v)))
	return out


static func _record_from_node(node: Node3D, kind: String, id: String, name: String) -> Dictionary:
	var vox := ModelLib.voxelize(node)
	var rec := {"id": id, "kind": kind, "name": name, "voxel": ModelLib.VOX, "size": [ModelLib.CHAR_SIZE.x, ModelLib.CHAR_SIZE.y, ModelLib.CHAR_SIZE.z],
			"origin": [ModelLib.CHAR_ORIGIN.x, ModelLib.CHAR_ORIGIN.y, ModelLib.CHAR_ORIGIN.z], "palette": vox.palette, "parts": vox.parts}
	return rec


## Los personajes del código (sin ropa).
static func characters() -> Array:
	var out: Array = []
	for c in Characters.ALL:
		var n := _build_code_character(str(c.id))
		out.append(_record_from_node(n, "personaje", str(c.id), str(c.name)))
		n.free()
	return out


static func _build_code_character(id: String) -> Node3D:
	return Characters.build_from_code(id, "", "", false)


## Los cosméticos del código, cada uno como una pieza en la caja de personajes.
static func cosmetics() -> Array:
	var out: Array = []
	for c in Cosmetics.ALL:
		var n: Node3D = Cosmetics.build_hat_from_code(str(c.id)) if c.slot == "gorro" else Cosmetics.build_outfit_from_code(str(c.id))
		if n == null:
			continue
		var wrapper := Node3D.new()
		wrapper.add_child(n)
		var rec := _record_from_node(wrapper, "cosmetico", str(c.id), str(c.name))
		rec["slot"] = c.slot
		rec["rarity"] = c.rarity
		# (las piezas son una sola parte, sin pivote)
		var merged: Array = []
		for p in rec.parts:
			merged.append_array(p.voxels)
		rec["parts"] = [{"name": "pieza", "pivot": null, "voxels": merged}]
		out.append(rec)
		wrapper.free()
	return out
