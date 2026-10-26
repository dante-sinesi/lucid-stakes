extends RefCounted
## El arte nuevo de los bloques, de 10 x 10 x 10 minibloques (los modelos de siempre, en block_models.gd, son de 5 x 5 x 5).
## Cada bloque tiene un diseño corrupto y otro purificado. Los dos son puntos de una misma escala de corrupción (`corrupcion`): la **corrupción son las grietas con magma violeta**
## y la piedra oscura y desgastada; al limpiarse la piedra se aclara a lavanda, las grietas se apagan y se cicatrizan, y la forma se alisa. Hay cinco niveles, uno cada tres etapas
## (como las pruebas), y bajan toda la escala: el corrupto de la última etapa parece el purificado de la primera, y el purificado de la última ya casi no tiene huellas.
## Los dos estados salen de la misma semilla: el bloque purificado es el corrupto ya curado (las mismas grietas, apagadas y cicatrizadas).
## El alfa del color de un minibloque marca que brilla (ver voxel_block.gdshader): las vetas corruptas emiten su propio color.
## La cara de arriba se pisa: su centro (8 x 8) queda siempre completo y a la misma altura.

const BlockModels := preload("res://scripts/personajes/block_models.gd")

const N := 10
const NIVELES := 5   # uno cada tres etapas
enum Estado { CORRUPTO, PURIFICADO }

## Los colores (los mismos en todas las etapas).
const PALETA := {
	"corrupta": [Color(0.10, 0.075, 0.14), Color(0.14, 0.105, 0.19), Color(0.19, 0.14, 0.25)],
	"roca_vena": Color(0.17, 0.06, 0.24),
	"vena": Color(0.78, 0.13, 0.95),
	"nucleo": Color(1.0, 0.5, 1.0),
	"halo": Color(0.45, 0.08, 0.60, 0.88),
	"pura": [Color(0.70, 0.66, 0.84), Color(0.75, 0.71, 0.88), Color(0.80, 0.77, 0.92)],
	"pura_limpia": [Color(0.84, 0.81, 0.94), Color(0.88, 0.85, 0.97), Color(0.92, 0.90, 0.99)],   # (la piedra ya casi sin corrupción)
	"pura_arriba": Color(0.88, 0.85, 0.97),
	"cicatriz": Color(0.50, 0.44, 0.67),
	"resto_vena": Color(0.62, 0.18, 0.72),
}

## La corrupción de cada nivel. Los pasos son parejos para que se note el cambio de una etapa a la siguiente; el purificado baja más rápido al principio (el de la primera etapa
## todavía conserva bastante: se ve más corrupto que el de la segunda).
const CORRUPCION_CORRUPTO := [1.0, 0.83, 0.70, 0.60, 0.50]
const CORRUPCION_PURIFICADO := [0.50, 0.33, 0.20, 0.10, 0.0]

static var _cache := {}


## El nivel de corrupción de una etapa (1 a 15): 0 en las etapas 1 a 3 (muy corrupto) y 4 en las etapas 13 a 15 (casi limpio).
static func nivel_de_etapa(etapa: int) -> int:
	return clampi((etapa - 1) / 3, 0, NIVELES - 1)


## Cuánto se limpió el bloque, de 0 (muy corrupto) a 1 (casi limpio).
static func limpieza(nivel: int) -> float:
	return clampf(float(nivel) / float(NIVELES - 1), 0.0, 1.0)


static func _h(x: int, y: int, z: int, k: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (k * 2654435761)
	return float(absi(h) % 1000) / 1000.0


static func _bordes(p: Vector3i) -> int:
	return int(p.x == 0 or p.x == N - 1) + int(p.y == 0 or p.y == N - 1) + int(p.z == 0 or p.z == N - 1)


## El centro de la cara de arriba (lo que se pisa): siempre completo.
static func _centro_arriba(p: Vector3i) -> bool:
	return p.y == N - 1 and p.x >= 1 and p.x <= N - 2 and p.z >= 1 and p.z <= N - 2


## Cuánta corrupción tiene un bloque, de 0 (limpio) a 1 (muy corrupto). Es una sola escala para los dos estados: el corrupto de la etapa 1 es el más corrupto (1) y el de
## la última etapa ya parece el purificado de la primera (0,5); el purificado de la etapa 1 está "ligeramente purificado" (0,5) y el de la última, muy purificado (0).
static func corrupcion(estado: int, nivel: int) -> float:
	var tabla: Array = CORRUPCION_CORRUPTO if estado == Estado.CORRUPTO else CORRUPCION_PURIFICADO
	return float(tabla[clampi(nivel, 0, NIVELES - 1)])


## Los minibloques de un bloque de piedra: {Vector3i: Color}.
static func piedra(estado: int, nivel := 0, semilla := 0) -> Dictionary:
	return piedra_con(corrupcion(estado, nivel), semilla)


## Un bloque de piedra con esa corrupción (0 a 1): la forma se desgasta, la piedra se oscurece y las grietas se llenan de magma a medida que sube.
static func piedra_con(c: float, semilla := 0) -> Dictionary:
	var sd := semilla * 31 + 7
	var vox := {}
	# 1) la forma: las esquinas y aristas se desgastan y hay mordiscos en las esquinas (más cuanto más corrupto)
	var p_arista := lerpf(0.03, 0.38, c)
	var p_cara := lerpf(0.01, 0.06, c)
	var p_esquina := lerpf(0.15, 1.0, c)
	var n_mordiscos := roundi(lerpf(0.0, 3.0, c))
	var radio_mordisco := lerpf(1.4, 2.0, c)
	var mordiscos: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	for i in n_mordiscos:
		mordiscos.append(Vector3(rng.randi() % 2 * (N - 1), rng.randi() % 2 * (N - 1), rng.randi() % 2 * (N - 1)))
	for x in N:
		for y in N:
			for z in N:
				var p := Vector3i(x, y, z)
				var b := _bordes(p)
				if not _centro_arriba(p):
					var r := _h(x, y, z, sd)
					if b == 3 and r < p_esquina:
						continue
					if b == 2 and r < p_arista:
						continue
					if b == 1 and r < p_cara:
						continue
					var mordido := false
					for m in mordiscos:
						if Vector3(p).distance_to(m) < radio_mordisco:
							mordido = true
					if mordido and p.y < N - 1:
						continue
				vox[p] = _color_base(p, c, sd)
	# 2) las grietas, que son la corrupción: caminos de un minibloque en cada cara (menos la de abajo), siempre los mismos para una semilla (un bloque que se limpia
	# conserva sus grietas, cada vez más cortadas y apagadas); con mucha corrupción son vetas hundidas con magma que brilla, y con poca, cicatrices con algún resto de vena
	var rng_g := RandomNumberGenerator.new()
	rng_g.seed = sd + 100
	var visibles := clampf(c * 1.5, 0.0, 1.0)   # (qué parte de cada grieta se ve)
	for cara in 5:
		var caminos: Array = [_camino(rng_g, 13 + rng_g.randi() % 8), _camino(rng_g, 12 + rng_g.randi() % 8)]
		var con_segundo := rng_g.randf() < 0.45
		for k in caminos.size():
			if k == 1 and not con_segundo and c > 0.7:
				continue
			var i := 0
			for uv in caminos[k]:
				var p := _de_cara(cara, uv)
				var nucleo := (i % 9 == 4)
				i += 1
				if not vox.has(p) or _h(p.x, p.y, p.z, sd + 13) > visibles:
					continue
				_grieta(vox, p, cara, nucleo, c, sd)
	return vox


## El color de la piedra: lavanda cuando está poco corrupta (más clara cuanto más limpia) y obsidiana oscura cuando lo está mucho; el paso es parejo entre 0,5 y 1.
static func _color_base(p: Vector3i, c: float, sd: int) -> Color:
	var r := _h(p.x, p.y, p.z, sd + 3)
	var i := 0 if r < 0.4 else (1 if r < 0.8 else 2)
	var lavanda: Color = (PALETA.pura[i] as Color).lerp(PALETA.pura_limpia[i], clampf(1.0 - c * 2.0, 0.0, 1.0))
	var oscura: Color = PALETA.corrupta[i]
	var col := lavanda.lerp(oscura, clampf((c - 0.5) / 0.5, 0.0, 1.0))   # (parejo: cada paso de corrupción se nota igual)
	if _centro_arriba(p):   # (la cara de arriba, un poco más clara: se lee dónde se pisa)
		col = col.lightened(0.08) if c > 0.75 else col.lerp(PALETA.pura_arriba, 0.5).darkened(_h(p.x, p.y, p.z, sd + 8) * 0.05)
	return col


## Un camino al azar sobre una cara de 10 x 10, en ocho direcciones: sigue derecho casi siempre y gira de a 45 grados, así las grietas hacen curvas.
static func _camino(rng: RandomNumberGenerator, largo: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var pos := Vector2i(1 + rng.randi() % (N - 2), 1 + rng.randi() % (N - 2))
	var dirs := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
	var d := rng.randi() % 8
	for i in largo:
		out.append(pos)
		var r := rng.randf()
		if r < 0.2:
			d = (d + 1) % 8
		elif r < 0.4:
			d = (d + 7) % 8
		elif r < 0.43:
			d = (d + 2) % 8
		elif r < 0.46:
			d = (d + 6) % 8
		pos += dirs[d]
		if pos.x < 0 or pos.x > N - 1 or pos.y < 0 or pos.y > N - 1:
			pos = Vector2i(clampi(pos.x, 0, N - 1), clampi(pos.y, 0, N - 1))
			d = (d + 4 + rng.randi() % 3 - 1) % 8   # (al llegar al borde de la cara, rebota)
	return out


## El minibloque de la superficie de una cara (0 arriba, 1 a 4 los costados) para la posición (u, v) sobre ella.
static func _de_cara(cara: int, uv: Vector2i) -> Vector3i:
	match cara:
		0:
			return Vector3i(uv.x, N - 1, uv.y)
		1:
			return Vector3i(0, uv.y, uv.x)
		2:
			return Vector3i(N - 1, uv.y, uv.x)
		3:
			return Vector3i(uv.x, uv.y, 0)
	return Vector3i(uv.x, uv.y, N - 1)


static func _hacia_adentro(cara: int) -> Vector3i:
	match cara:
		0:
			return Vector3i(0, -1, 0)
		1:
			return Vector3i(1, 0, 0)
		2:
			return Vector3i(-1, 0, 0)
		3:
			return Vector3i(0, 0, 1)
	return Vector3i(0, 0, -1)


## Una grieta en un minibloque. Con corrupción de 0,45 o más es una veta: en los costados se hunde un minibloque y el de abajo se llena de magma (brilla con mucha
## corrupción y se va apagando); arriba (que se pisa) queda a ras. Con menos es una cicatriz clara con algún resto de vena sin brillo.
static func _grieta(vox: Dictionary, p: Vector3i, cara: int, nucleo: bool, c: float, sd: int) -> void:
	if c >= 0.45:
		var color: Color = PALETA.nucleo if nucleo else PALETA.vena
		var apagado := clampf((1.0 - c) / 0.55, 0.0, 1.0)   # (0 con la corrupción al máximo, 1 con 0,45)
		color.a = lerpf(0.22 if nucleo else 0.40, 1.0, apagado)
		var objetivo := p
		if cara != 0:
			var dentro := p + _hacia_adentro(cara)
			if vox.has(dentro):
				vox.erase(p)
				objetivo = dentro
		vox[objetivo] = color
		if c > 0.7:   # (la roca de alrededor se tiñe de violeta y unos pocos minibloques arden más tenues)
			for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				var q: Vector3i = objetivo + d
				if vox.has(q) and (vox[q] as Color).a >= 1.0 and (vox[q] as Color).r < 0.3:
					vox[q] = PALETA.halo if _h(q.x, q.y, q.z, 77) < 0.16 else (vox[q] as Color).lerp(PALETA.roca_vena, 0.5)
		return
	var resto := _h(p.x, p.y, p.z, sd + 5) < lerpf(0.0, 0.5, c / 0.45)
	var cicatriz: Color = (PALETA.cicatriz as Color).lerp(Color(0.74, 0.70, 0.86), clampf(1.0 - c * 2.0, 0.0, 1.0) * 0.6)
	var color_resto: Color = (PALETA.resto_vena as Color).lerp(cicatriz, clampf(1.0 - c * 2.0, 0.0, 1.0) * 0.5)
	if cara != 0 and _h(p.x, p.y, p.z, 41) < 0.22:   # (algunas muescas: la grieta se hundió un minibloque)
		var dentro := p + _hacia_adentro(cara)
		if vox.has(dentro):
			vox.erase(p)
			vox[dentro] = color_resto if resto else cicatriz.darkened(0.12)
			return
	vox[p] = color_resto if resto else cicatriz


## La malla de un bloque de piedra (con la memoria de modelos).
static func malla_piedra(estado: int, nivel := 0, semilla := 0) -> ArrayMesh:
	var key := "piedra|%d|%d|%d" % [estado, nivel, semilla]
	if not _cache.has(key):
		_cache[key] = malla(piedra(estado, nivel, semilla))
	return _cache[key]


## La malla de un modelo de 10 x 10 x 10 minibloques: sólo se dibujan las caras que se ven.
static func malla(vox: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dirs: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	for p in vox:
		for d in dirs:
			if not vox.has(p + d):
				BlockModels._add_face(st, p, d, vox[p], N)
	return st.commit()
