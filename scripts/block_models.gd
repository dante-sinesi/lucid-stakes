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
const ModelLib := preload("res://scripts/model_lib.gd")

enum State { CORRUPT, PURE, DEFUSED }
const CORE := 9  # tipo extra para el bloque fijo del centro (los demás son los de TowerLogic.Kind)
const N := 5
const VARIANTS := 4   # diseños automáticos por tipo de bloque (el 0 es el de siempre)
const VOXEL := 0.96 / N  # el cubo del juego mide 0.96

static var _cache := {}
## Cantidad de variantes de diseño de un tipo de bloque: las automáticas (VARIANTS: la 0 es el diseño de siempre y las otras son variaciones del
## mismo tipo) o más si el editor de modelos (model_editor.gd, data/modelos/) guardó otras. Cada bloque de la torre usa una según su identidad (variant_for).
static func variant_count(kind: int) -> int:
	return maxi(VARIANTS, ModelLib.block_variant_count(kind))


## La variante que le toca a un bloque (estable: el mismo bloque se ve siempre igual dentro de la misma torre, y cada torre reparte distinto).
static func variant_for(id: int, salt: int, kind: int) -> int:
	var n := variant_count(kind)
	if n <= 1:
		return 0
	return int(absi((id * 73856093) ^ (salt * 19349663) ^ (kind * 83492791)) % n)


static func mesh_for(kind: int, state: int, variant := 0) -> ArrayMesh:
	var key := (variant * 10 + kind) * 10 + state
	if not _cache.has(key):
		_cache[key] = _build(kind, state, variant)
	return _cache[key]


## Se vacía la memoria de modelos (el editor de modelos la usa al guardar un cambio).
static func clear_cache() -> void:
	_cache.clear()


## Cantidad de minibloques de un modelo (para pruebas y para medir lo "roto" que está).
static func voxel_count(kind: int, state: int, variant := 0) -> int:
	return _voxels(kind, state, variant).size()


## Cuántas de las N x N posiciones de la capa de arriba tienen minibloque (la cara que se pisa).
static func top_coverage(kind: int, state: int, variant := 0) -> int:
	var count := 0
	for p in _voxels(kind, state, variant):
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


## Color del minibloque (x, y, z) del modelo "completo" de un tipo, o null si ahí no hay minibloque. `variant` (0 a VARIANTS - 1) cambia detalles
## del diseño (otro ruido, otras esquinas, otras vetas...) sin cambiar lo que el jugador tiene que leer: la cara de arriba se pisa igual.
static func _full_color(kind: int, x: int, y: int, z: int, defused: bool, variant := 0):
	var edges := _edges(x, y, z)
	var vr := variant % VARIANTS
	var sd := kind + variant * 131   # (semilla del ruido: cada variante lo reparte distinto)
	var n := (_h(x, y, z, sd) - 0.5) * 0.08
	match kind:
		0:  # normal: cubo con las esquinas cortadas, aristas más oscuras y el panel de arriba más claro
			if edges == 3 and not (vr == 1 and y == N - 1):   # (la variante 1 conserva las esquinas de arriba)
				return null
			var v := 0.9
			if edges == 2:
				v = 0.76
			elif _top_center(x, y, z):
				v = 1.0
				if vr == 3 and (x + z) % 2 == 0:   # (variante 3: la cara de arriba, a cuadritos)
					v = 0.94
			if vr == 2 and y == 2 and edges == 1:   # (variante 2: una ranura que da la vuelta)
				v -= 0.18
			v = clampf(v + n, 0.0, 1.0)
			return Color(v, v, v)
		1:  # hielo: cristal con esquinas y aristas astilladas (arriba queda plano), vetas blancas y azules
			if edges == 3:
				return null
			if edges == 2 and y != N - 1 and _h(x, y, z, 9 + variant) < (0.5 if vr == 1 else 0.35):
				return null
			var r := _h(x, y, z, 5 + variant * 37)
			if vr == 3 and (x + y + z) % 4 == 0:   # (variante 3: una veta blanca en diagonal)
				return Color(1.0, 1.0, 1.0)
			if r < (0.2 if vr == 2 else 0.28):
				return Color(1.0, 1.0, 1.0)
			if r < (0.5 if vr == 2 else 0.4):
				return Color(0.62, 0.85, 1.0)
			return Color(0.8, 0.95, 1.0)
		2:  # bomba: bola oscura con mecha y chispa (gris verdoso y sin chispa viva si está desactivada)
			if x == 2 and z == 2 and y == 3:
				return Color(0.5, 0.55, 0.5) if defused else Color(0.55, 0.25, 0.1)
			if x == 2 and z == 2 and y == N - 1:
				return Color(0.3, 0.85, 0.4) if defused else Color(1.0, 0.8, 0.2)
			if Vector3(x - 2, y - 2, z - 2).length() > (2.5 if vr == 1 else 2.3):
				return null
			if x == 1 and y == 3 and z == 1:
				return Color(0.55, 0.62, 0.55) if defused else Color(0.5, 0.5, 0.56)
			if vr == 2 and y == 2 and not defused:   # (variante 2: una franja clara en el medio)
				return Color(0.42, 0.42, 0.5)
			if vr == 3 and y == 1 and not defused:   # (variante 3: una franja roja abajo)
				return Color(0.5, 0.12, 0.1)
			var v := clampf((0.45 if defused else 0.18) + n, 0.0, 1.0)
			return Color(v, v + (0.05 if defused else 0.0), v + 0.04)
		3:  # catapulta: placa de abajo, cuatro resortes plateados, plato de arriba
			var orange := Color(1.0, 0.6, 0.15)
			if vr == 3:
				orange = Color(0.95, 0.5, 0.1)
			if y == 0:
				return null if edges == 3 else orange.darkened(0.2)
			if y == N - 1:
				if edges == 3:
					return null
				if vr == 2 and (x == 2 or z == 2):   # (variante 2: una ranura en cruz en el plato)
					return orange.darkened(0.12)
				return orange.lightened(0.25 if _top_center(x, y, z) else 0.1)
			var post := (x == 1 or x == N - 2) and (z == 1 or z == N - 2)
			if post or (x == 2 and z == 2 and y == 2) or (vr == 1 and x == 2 and z == 2):
				return Color(0.82, 0.82, 0.88).lightened(n)
			return null
		4:  # agrietado: arenisca clara con grietas oscuras en zigzag y hendiduras que atraviesan el bloque
			if edges == 3:
				return null
			var pat: int = [(x + 2 * z + y) % 5, (2 * x + z + y) % 5, (x + z + 2 * y) % 5, (x + 3 * z + y) % 5][vr]
			var crack: bool = pat == 0 and _h(x, y, z, 21 + variant) < 0.8
			if crack and not _top_center(x, y, z):
				return null if _h(x, y, z, 22 + variant) < 0.35 else Color(0.22, 0.14, 0.08)
			if crack:
				return Color(0.28, 0.18, 0.10)
			var s := 0.84 + n * 2.0 - (0.1 if edges == 2 else 0.0) + (0.06 if _top_center(x, y, z) else 0.0)
			return Color(s, s * 0.82, s * 0.58)
		5:  # pesado: hierro azulado con marco más oscuro, remaches dorados en las esquinas y cuatro tornillos arriba
			if edges == 3:
				return Color(0.95, 0.78, 0.3)   # remache dorado
			var frame := edges == 2
			var v := 0.36 if frame else (0.56 if vr == 3 else 0.5)
			var screws: bool = (x == 1 or x == N - 2) and (z == 1 or z == N - 2)
			if vr == 1:   # (variante 1: un solo tornillo en el medio)
				screws = x == 2 and z == 2
			if _top_center(x, y, z) and screws:
				return Color(0.8, 0.65, 0.25)
			if vr == 2 and not frame and x == z and y != N - 1:   # (variante 2: refuerzos en diagonal)
				v -= 0.1
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
			if vr == 1:
				v -= 0.05
			elif vr == 2 and (x + z) % 2 == 0 and y != N - 1:
				v -= 0.06
			elif vr == 3 and y == 2:
				v -= 0.12
			v = clampf(v + n, 0.0, 1.0)
			return Color(v, v * 0.94, v * 0.92)
		7:  # pinchos: base de acero oscuro y cinco púas plateadas arriba (la cara de arriba no se pisa)
			var spike := (x == 1 or x == 3) and (z == 1 or z == 3) or (x == 2 and z == 2)
			if vr == 1:   # (variante 1: sólo las cuatro de las esquinas)
				spike = (x == 1 or x == 3) and (z == 1 or z == 3)
			elif vr == 2:   # (variante 2: tres en diagonal)
				spike = (x == z and x >= 1 and x <= 3)
			if y == N - 1:
				return Color(0.95, 0.96, 1.0) if spike else null
			if y == N - 2:
				return Color(0.7, 0.72, 0.8) if spike else Color(0.28, 0.28, 0.34)
			if edges == 3:
				return null
			var s := 0.3 + n + (0.0 if edges < 2 else -0.08) - (0.06 if vr == 3 else 0.0)
			return Color(s, s, s + 0.08)
		_:  # core: piedra gris con esquinas rotas
			if edges == 3 and _h(x, y, z, 7 + variant) < 0.6:
				return null
			var v := 0.36 + (_h(x, y, z, 3 + variant * 37) - 0.4) * 0.3 - (0.06 if edges == 2 else 0.0)
			return Color(v, v, v + 0.06)


## Los minibloques de un modelo: {Vector3i: Color}.
static func _voxels(kind: int, state: int, variant := 0) -> Dictionary:
	var defused := state == State.DEFUSED
	var full: Dictionary = ModelLib.block_model(kind, variant, defused)   # (si el editor guardó un diseño para esta variante, se usa ese)
	var out := {}
	if full.is_empty():
		for x in N:
			for y in N:
				for z in N:
					var c = _full_color(kind, x, y, z, defused, variant)
					if c != null:
						full[Vector3i(x, y, z)] = c
	return state_view(full, kind, variant, state)


## El aspecto de un modelo completo en un estado: PURE y DEFUSED son el modelo tal cual; CORRUPT pierde minibloques sueltos (salvo el centro de la cara de arriba) y se
## oscurece hacia el violeta (la bomba activa no se corrompe). Lo usa el editor de modelos para mostrar cómo queda cada estado.
static func state_view(full: Dictionary, kind: int, variant: int, state: int) -> Dictionary:
	var corrupt := state == State.CORRUPT and kind != 2
	var out := {}
	for p in full:
		var c: Color = full[p]
		if corrupt:
			# Irregular: se pierden minibloques sueltos (no los del centro de la cara de arriba, que se pisa).
			if _edges(p.x, p.y, p.z) >= 1 and not _top_center(p.x, p.y, p.z) and _h(p.x, p.y, p.z, 11 + kind + variant * 7) < 0.16:
				continue
			if kind == 6 and c.r > 0.9 and c.g < 0.3:
				pass   # la cruz roja de la trampa se ve siempre: es la pista para no pisarla
			else:
				c = c.darkened(0.68).lerp(Color(0.3, 0.08, 0.4), 0.2)  # oscuro y violáceo, pero conserva algo del tono de su tipo
		out[p] = c
	return out


static func _build(kind: int, state: int, variant := 0) -> ArrayMesh:
	var vox := _voxels(kind, state, variant)
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
