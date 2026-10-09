extends SceneTree
## Pruebas de los modelos de bloque hechos con minibloques.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_models.gd

const BM := preload("res://scripts/block_models.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const NORMAL := TowerLogic.Kind.NORMAL
const ICE := TowerLogic.Kind.ICE
const BOMB := TowerLogic.Kind.BOMB
const CAT := TowerLogic.Kind.CATAPULT

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


## Los (tipo, estado) que existen: todos tienen corrupto y purificado; la bomba tiene activa (CORRUPT) y desactivada.
func models() -> Array:
	var res: Array = []
	for k in [NORMAL, ICE, CAT, 4, 5, 6, 7, BM.CORE]:
		res.append([k, BM.State.CORRUPT])
		res.append([k, BM.State.PURE])
	res.append([BOMB, BM.State.CORRUPT])
	res.append([BOMB, BM.State.DEFUSED])
	return res


func signature(mesh: ArrayMesh) -> int:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var h := verts.size()
	for i in verts.size():
		h = (h * 31 + int(verts[i].x * 1000.0) * 7 + int(verts[i].y * 1000.0) * 13 + int(verts[i].z * 1000.0) * 17
				+ int(cols[i].r * 255.0) + int(cols[i].g * 255.0) * 3 + int(cols[i].b * 255.0) * 5) % 2147483647
	return h


func _init() -> void:
	var seen := {}
	for m in models():
		var kind: int = m[0]
		var state: int = m[1]
		var label := "tipo %d estado %d" % [kind, state]
		var mesh := BM.mesh_for(kind, state)
		check(mesh != null and mesh.get_surface_count() == 1, "%s: tiene una superficie" % label)
		var arrays := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		check(verts.size() >= 36 and verts.size() % 3 == 0, "%s: tiene caras (%d vertices)" % [label, verts.size()])

		# Cabe en la celda del juego (0.96) y no es una miniatura.
		var size := mesh.get_aabb().size
		check(size.x <= 0.961 and size.y <= 0.961 and size.z <= 0.961, "%s: cabe en el cubo de 0.96 (%s)" % [label, str(size)])
		check(size.x >= 0.5 and size.z >= 0.5 and size.y >= 0.5, "%s: ocupa buena parte de la celda" % label)

		# Todas las caras miran hacia afuera (Godot dibuja de frente las que van en sentido horario).
		var outward := true
		var i := 0
		while i + 2 < verts.size():
			var cross := (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i])
			outward = outward and cross.dot(norms[i]) < 0.0
			i += 3
		check(outward, "%s: todas las caras estan orientadas hacia afuera" % label)

		# Cache: es la misma instancia; y cada modelo es distinto de los demas.
		check(BM.mesh_for(kind, state) == mesh, "%s: el modelo se construye una sola vez" % label)
		var sig := signature(mesh)
		check(not seen.has(sig), "%s: es distinto de los demas modelos" % label)
		seen[sig] = label

	# Determinismo: reconstruir da exactamente lo mismo.
	var before := signature(BM.mesh_for(ICE, BM.State.CORRUPT))
	BM._cache.clear()
	check(signature(BM.mesh_for(ICE, BM.State.CORRUPT)) == before, "construir el mismo modelo dos veces da lo mismo")

	# Corrupto = irregular: menos minibloques que el purificado (salvo la bomba activa, que conserva su forma).
	for k in [NORMAL, ICE, CAT, 4, 5, 6, 7, BM.CORE]:
		check(BM.voxel_count(k, BM.State.CORRUPT) < BM.voxel_count(k, BM.State.PURE), "tipo %d: el corrupto tiene menos minibloques que el purificado" % k)
	check(BM.voxel_count(BOMB, BM.State.CORRUPT) == BM.voxel_count(BOMB, BM.State.DEFUSED), "la bomba activa y la desactivada tienen la misma forma")
	check(signature(BM.mesh_for(BOMB, BM.State.CORRUPT)) != signature(BM.mesh_for(BOMB, BM.State.DEFUSED)), "pero la desactivada tiene otros colores")

	# La cara de arriba se tiene que poder pisar: casi completa en los bloques que se usan de piso.
	var area := BM.N * BM.N
	for k in [NORMAL, ICE, CAT, 4, 5, 6, BM.CORE]:   # (los pinchos no se pisan: no se pide cara de arriba)
		check(BM.top_coverage(k, BM.State.PURE) >= area * 2 / 3, "tipo %d purificado: la cara de arriba esta casi completa (%d de %d)" % [k, BM.top_coverage(k, BM.State.PURE), area])
		check(BM.top_coverage(k, BM.State.CORRUPT) >= 9, "tipo %d corrupto: el centro de la cara de arriba se conserva (%d)" % [k, BM.top_coverage(k, BM.State.CORRUPT)])

	# Un bloque normal purificado es casi blanco (el tinte le pone el color de su altura); el corrupto es oscuro.
	var pure_cols: PackedColorArray = BM.mesh_for(NORMAL, BM.State.PURE).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var corr_cols: PackedColorArray = BM.mesh_for(NORMAL, BM.State.CORRUPT).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var pure_v := 0.0
	for c in pure_cols:
		pure_v += c.v
	var corr_v := 0.0
	for c in corr_cols:
		corr_v += c.v
	check(pure_v / pure_cols.size() > 0.7 and corr_v / corr_cols.size() < 0.35, "el normal purificado es claro (%.2f) y el corrupto oscuro (%.2f)" % [pure_v / pure_cols.size(), corr_v / corr_cols.size()])

	# La bomba activa es oscura con una mecha amarilla; la catapulta tiene plata y naranja.
	var bomb_cols: PackedColorArray = BM.mesh_for(BOMB, BM.State.CORRUPT).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var has_spark := false
	for c in bomb_cols:
		has_spark = has_spark or (c.r > 0.9 and c.g > 0.7 and c.b < 0.4)
	check(has_spark, "la bomba activa tiene una chispa amarilla")

	print("tests de los modelos terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
