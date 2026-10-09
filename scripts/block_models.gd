extends RefCounted
## Modelos de los bloques hechos con minibloques (voxels) de N x N x N. Es sólo visual: la lógica del juego
## sigue razonando en cubos y cada celda usa uno de estos modelos según el tipo y el estado.
##
## Un modelo se construye una vez (cache) y lo comparten todos los bloques de ese tipo y estado.
## Los colores van en los vértices; el shader los multiplica por un tinte (el bloque normal purificado
## lleva el color de su altura; el resto va con tinte blanco).
##
## Estados: CORRUPT = corrupto (irregular: faltan minibloques sueltos; oscuro y violáceo). PURE = purificado
## (completo y con su color). DEFUSED = bomba desactivada. La bomba activa se dibuja con el estado CORRUPT
## pero conserva su aspecto de bomba (oscura, con mecha), no el de bloque corrupto.

const Loc := preload("res://scripts/loc.gd")

enum State { CORRUPT, PURE, DEFUSED }
const CORE := 9  # tipo extra para el bloque fijo del centro (los demás son los de TowerLogic.Kind)
const N := 5
const VOXEL := 0.96 / N  # el cubo del juego mide 0.96

static var _cache := {}


static func mesh_for(kind: int, state: int) -> ArrayMesh:
	var key := kind * 10 + state
	if not _cache.has(key):
		_cache[key] = _build(kind, state)
	return _cache[key]


## Cantidad de minibloques de un modelo (para pruebas y para medir lo "roto" que está).
static func voxel_count(kind: int, state: int) -> int:
	return _voxels(kind, state).size()


## Cuántas de las N x N posiciones de la capa de arriba tienen minibloque (la cara que se pisa).
static func top_coverage(kind: int, state: int) -> int:
	var count := 0
	for p in _voxels(kind, state):
		if p.y == N - 1:
			count += 1
	return count


static func _h(x: int, y: int, z: int, k: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (k * 2654435761)
	return float(absi(h) % 1000) / 1000.0


static func _edges(x: int, y: int, z: int) -> int:
	return int(x == 0 or x == N - 1) + int(y == 0 or y == N - 1) + int(z == 0 or z == N - 1)


static func _top_center(x: int, y: int, z: int) -> bool:
	return y == N - 1 and x >= 1 and x <= N - 2 and z >= 1 and z <= N - 2


## Color del minibloque (x, y, z) del modelo "completo" de un tipo, o null si ahí no hay minibloque.
static func _full_color(kind: int, x: int, y: int, z: int, defused: bool):
	var edges := _edges(x, y, z)
	var n := (_h(x, y, z, kind) - 0.5) * 0.08
	match kind:
		0:  # normal: cubo con las esquinas cortadas, aristas más oscuras y el panel de arriba más claro
			if edges == 3:
				return null
			var v := 0.9
			if edges == 2:
				v = 0.76
			elif _top_center(x, y, z):
				v = 1.0
			v = clampf(v + n, 0.0, 1.0)
			return Color(v, v, v)
		1:  # hielo: cristal con esquinas y aristas astilladas (arriba queda plano), vetas blancas y azules
			if edges == 3:
				return null
			if edges == 2 and y != N - 1 and _h(x, y, z, 9) < 0.35:
				return null
			var r := _h(x, y, z, 5)
			if r < 0.28:
				return Color(1.0, 1.0, 1.0)
			if r < 0.4:
				return Color(0.62, 0.85, 1.0)
			return Color(0.8, 0.95, 1.0)
		2:  # bomba: bola oscura con mecha y chispa (gris verdoso y sin chispa viva si está desactivada)
			if x == 2 and z == 2 and y == 3:
				return Color(0.5, 0.55, 0.5) if defused else Color(0.55, 0.25, 0.1)
			if x == 2 and z == 2 and y == N - 1:
				return Color(0.3, 0.85, 0.4) if defused else Color(1.0, 0.8, 0.2)
			if Vector3(x - 2, y - 2, z - 2).length() > 2.3:
				return null
			if x == 1 and y == 3 and z == 1:
				return Color(0.55, 0.62, 0.55) if defused else Color(0.5, 0.5, 0.56)
			var v := clampf((0.45 if defused else 0.18) + n, 0.0, 1.0)
			return Color(v, v + (0.05 if defused else 0.0), v + 0.04)
		3:  # catapulta: placa de abajo, cuatro resortes plateados, plato de arriba
			var orange := Color(1.0, 0.6, 0.15)
			if y == 0:
				return null if edges == 3 else orange.darkened(0.2)
			if y == N - 1:
				if edges == 3:
					return null
				return orange.lightened(0.25 if _top_center(x, y, z) else 0.1)
			var post := (x == 1 or x == N - 2) and (z == 1 or z == N - 2)
			if post or (x == 2 and z == 2 and y == 2):
				return Color(0.82, 0.82, 0.88).lightened(n)
			return null
		4:  # agrietado: arenisca clara con grietas oscuras en zigzag y hendiduras que atraviesan el bloque
			if edges == 3:
				return null
			var crack := (x + 2 * z + y) % 5 == 0 and _h(x, y, z, 21) < 0.8
			if crack and not _top_center(x, y, z):
				return null if _h(x, y, z, 22) < 0.35 else Color(0.22, 0.14, 0.08)
			if crack:
				return Color(0.28, 0.18, 0.10)
			var s := 0.84 + n * 2.0 - (0.1 if edges == 2 else 0.0) + (0.06 if _top_center(x, y, z) else 0.0)
			return Color(s, s * 0.82, s * 0.58)
		5:  # pesado: hierro azulado con marco más oscuro, remaches dorados en las esquinas y cuatro tornillos arriba
			if edges == 3:
				return Color(0.95, 0.78, 0.3)   # remache dorado
			var frame := edges == 2
			var v := 0.36 if frame else 0.5
			if _top_center(x, y, z) and (x == 1 or x == N - 2) and (z == 1 or z == N - 2):
				return Color(0.8, 0.65, 0.25)
			v = clampf(v + n, 0.0, 1.0)
			return Color(v * 0.85, v * 0.92, v * 1.15)
		6:  # trampa: igual que un bloque común pero con una cruz roja hundida en la cara de arriba y las esquinas de arriba rojizas
			if edges == 3:
				return null
			if y == N - 1 and ((x == z) or (x + z == N - 1)) and x >= 1 and x <= N - 2:
				return Color(1.0, 0.25, 0.18)
			var v := 0.9
			if edges == 2:
				v = 0.76
			elif _top_center(x, y, z):
				v = 1.0
			v = clampf(v + n, 0.0, 1.0)
			return Color(v, v * 0.94, v * 0.92)
		7:  # pinchos: base de acero oscuro y cinco púas plateadas arriba (la cara de arriba no se pisa)
			var spike := (x == 1 or x == 3) and (z == 1 or z == 3) or (x == 2 and z == 2)
			if y == N - 1:
				return Color(0.95, 0.96, 1.0) if spike else null
			if y == N - 2:
				return Color(0.7, 0.72, 0.8) if spike else Color(0.28, 0.28, 0.34)
			if edges == 3:
				return null
			var s := 0.3 + n + (0.0 if edges < 2 else -0.08)
			return Color(s, s, s + 0.08)
		_:  # core: piedra gris con esquinas rotas
			if edges == 3 and _h(x, y, z, 7) < 0.6:
				return null
			var v := 0.36 + (_h(x, y, z, 3) - 0.4) * 0.3 - (0.06 if edges == 2 else 0.0)
			return Color(v, v, v + 0.06)


## Los minibloques de un modelo: {Vector3i: Color}.
static func _voxels(kind: int, state: int) -> Dictionary:
	var out := {}
	var defused := state == State.DEFUSED
	var corrupt := state == State.CORRUPT and kind != 2  # la bomba activa conserva su aspecto
	for x in N:
		for y in N:
			for z in N:
				var c = _full_color(kind, x, y, z, defused)
				if c == null:
					continue
				if corrupt:
					# Irregular: se pierden minibloques sueltos (no los del centro de la cara de arriba, que se pisa).
					if _edges(x, y, z) >= 1 and not _top_center(x, y, z) and _h(x, y, z, 11 + kind) < 0.16:
						continue
					if kind == 6 and (c as Color).r > 0.9 and (c as Color).g < 0.3:
						pass   # la cruz roja de la trampa se ve siempre: es la pista para no pisarla
					else:
						c = (c as Color).darkened(0.68).lerp(Color(0.3, 0.08, 0.4), 0.2)  # oscuro y violáceo, pero conserva algo del tono de su tipo
				out[Vector3i(x, y, z)] = c
	return out


static func _build(kind: int, state: int) -> ArrayMesh:
	var vox := _voxels(kind, state)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dirs: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
			Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	for p in vox:
		for d in dirs:
			if not vox.has(p + d):  # sólo las caras que se ven
				_add_face(st, p, d, vox[p])
	return st.commit()


static func _add_face(st: SurfaceTool, p: Vector3i, d: Vector3i, c: Color) -> void:
	var n := Vector3(d)
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	if d.x != 0:
		a = Vector3(0, 1, 0)
		b = Vector3(0, 0, 1)
	elif d.y != 0:
		a = Vector3(1, 0, 0)
		b = Vector3(0, 0, 1)
	else:
		a = Vector3(1, 0, 0)
		b = Vector3(0, 1, 0)
	var center := (Vector3(p) + Vector3(0.5, 0.5, 0.5) + n * 0.5 - Vector3(N, N, N) * 0.5) * VOXEL
	var h := VOXEL * 0.5
	var v0 := center - a * h - b * h
	var v1 := center + a * h - b * h
	var v2 := center + a * h + b * h
	var v3 := center - a * h + b * h
	# Godot dibuja de frente las caras en sentido horario vistas desde afuera: el producto vectorial del
	# triángulo tiene que apuntar hacia adentro (contra la normal). Si no, se invierte el orden.
	if (v1 - v0).cross(v2 - v0).dot(n) > 0.0:
		var t := v1
		v1 = v3
		v3 = t
	for v in [v0, v1, v2, v0, v2, v3]:
		st.set_color(c)
		st.set_normal(n)
		st.add_vertex(v)
