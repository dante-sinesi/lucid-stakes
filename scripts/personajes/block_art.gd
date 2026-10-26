extends RefCounted
## El arte nuevo de los bloques, de 10 x 10 x 10 minibloques (los modelos de siempre, en block_models.gd, son de 5 x 5 x 5).
## Cada bloque tiene un diseño corrupto y otro purificado. Los colores y la forma de la piedra son siempre los mismos (piedra oscura y desgastada, piedra lavanda clara): la
## **corrupción son las grietas y el magma violeta de adentro**, y eso es lo que baja con las etapas. Hay cinco niveles, uno cada tres etapas (como las pruebas): en el
## primero el bloque corrupto está surcado de grietas con magma que brilla; en el último quedan pocas grietas finas y tenues, y el purificado casi no guarda huellas.
## Los dos estados salen de la misma semilla: el bloque purificado es el corrupto ya curado (las mismas grietas, apagadas y cicatrizadas).
## El alfa del color de un minibloque marca que brilla (ver voxel_block.gdshader): las vetas corruptas emiten su propio color.
## La cara de arriba se pisa: su centro (8 x 8) queda siempre completo y a la misma altura.

const BlockModels := preload("res://scripts/personajes/block_models.gd")

const N := 10
const NIVELES := 5   # uno cada tres etapas
enum Estado { CORRUPTO, PURIFICADO }

## Los colores (los mismos en todas las etapas).
const PALETA := {
	"corrupta": [Color(0.075, 0.055, 0.105), Color(0.105, 0.075, 0.145), Color(0.14, 0.10, 0.19)],
	"roca_vena": Color(0.17, 0.06, 0.24),
	"vena": Color(0.78, 0.13, 0.95),
	"nucleo": Color(1.0, 0.5, 1.0),
	"halo": Color(0.45, 0.08, 0.60, 0.88),
	"pura": [Color(0.70, 0.66, 0.84), Color(0.75, 0.71, 0.88), Color(0.80, 0.77, 0.92)],
	"pura_arriba": Color(0.88, 0.85, 0.97),
	"cicatriz": Color(0.50, 0.44, 0.67),
	"resto_vena": Color(0.62, 0.18, 0.72),
}

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


## Los minibloques de un bloque de piedra: {Vector3i: Color}.
static func piedra(estado: int, nivel := 0, semilla := 0) -> Dictionary:
	var corrupto := estado == Estado.CORRUPTO
	var lim := limpieza(nivel)
	var sd := semilla * 31 + 7
	var vox := {}
	# 1) la forma (igual en todas las etapas): las esquinas y aristas se desgastan (mucho en el corrupto, poco en el purificado) y hay mordiscos en las esquinas
	var p_arista := 0.38 if corrupto else 0.12
	var p_cara := 0.06 if corrupto else 0.025
	var p_esquina := 1.0 if corrupto else 0.6
	var n_mordiscos := 3 if corrupto else 1
	var radio_mordisco := 2.0 if corrupto else 1.6
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
				vox[p] = _color_base(p, estado, sd)
	# 2) las grietas, que son la corrupción: caminos de un minibloque en cada cara (menos la de abajo), los mismos en los dos estados (el purificado es el corrupto curado);
	# en el corrupto son vetas hundidas con magma que brilla (menos, más cortas y más tenues a medida que se avanza), en el purificado quedan cicatrices con algún resto de vena
	var rng_g := RandomNumberGenerator.new()
	rng_g.seed = sd + 100
	for cara in 5:
		var caminos: Array = [_camino(rng_g, 13 + rng_g.randi() % 8), _camino(rng_g, 12 + rng_g.randi() % 8)]
		var con_segundo := rng_g.randf() < lerpf(0.45, 0.0, lim)
		var largo_max := roundi(lerpf(40.0, 9.0, lim)) if corrupto else 40
		for k in caminos.size():
			if corrupto and k == 1 and not con_segundo:
				continue
			var i := 0
			for uv in caminos[k]:
				if i >= largo_max:
					break
				var p := _de_cara(cara, uv)
				var nucleo := (i % 9 == 4)
				i += 1
				if not vox.has(p):
					continue
				if _h(p.x, p.y, p.z, sd + 13) > lerpf(1.0, 0.45, lim):   # (a medida que se avanza las grietas se cortan en tramos)
					continue
				if corrupto:
					_vena_corrupta(vox, p, cara, nucleo, lim)
				else:
					_cicatriz(vox, p, cara, _h(p.x, p.y, p.z, sd + 5) < lerpf(0.4, 0.06, lim), lim)
	return vox


static func _color_base(p: Vector3i, estado: int, sd: int) -> Color:
	var corrupto := estado == Estado.CORRUPTO
	var tonos: Array = PALETA.corrupta if corrupto else PALETA.pura
	var r := _h(p.x, p.y, p.z, sd + 3)
	var i := 0 if r < 0.4 else (1 if r < 0.8 else 2)
	var c: Color = tonos[i]
	if not corrupto and _centro_arriba(p):
		c = (PALETA.pura_arriba as Color).darkened(_h(p.x, p.y, p.z, sd + 8) * 0.06)
	elif corrupto and _centro_arriba(p):
		c = c.lightened(0.08)   # (la cara de arriba, un poco más clara: se lee dónde se pisa)
	return c


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


## Una veta corrupta: en los costados se hunde un minibloque y el de abajo brilla; arriba (que se pisa) brilla a ras. La roca de alrededor se tiñe de violeta
## (menos cuanto más limpio) y el brillo se apaga a medida que se limpia.
static func _vena_corrupta(vox: Dictionary, p: Vector3i, cara: int, nucleo: bool, lim: float) -> void:
	var color: Color = PALETA.nucleo if nucleo else PALETA.vena
	color.a = lerpf(0.22 if nucleo else 0.40, 0.70 if nucleo else 0.85, lim)   # (cuanto más alfa, menos emite: el magma se apaga)
	var objetivo := p
	if cara != 0:
		var dentro := p + _hacia_adentro(cara)
		if vox.has(dentro):
			vox.erase(p)
			objetivo = dentro
	vox[objetivo] = color
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		var q: Vector3i = objetivo + d
		if vox.has(q) and (vox[q] as Color).a >= 1.0:
			if _h(q.x, q.y, q.z, 77) < lerpf(0.16, 0.0, lim):
				vox[q] = PALETA.halo
			elif (vox[q] as Color).r < 0.3:
				vox[q] = (vox[q] as Color).lerp(PALETA.roca_vena, 0.5 * (1.0 - lim))


## Una grieta ya curada: una cicatriz clara y, a veces, un resto de vena que todavía se ve (apagado, sin brillo; menos cuanto más limpio).
static func _cicatriz(vox: Dictionary, p: Vector3i, cara: int, resto: bool, lim: float) -> void:
	var cicatriz: Color = (PALETA.cicatriz as Color).lerp(Color(0.74, 0.70, 0.86), lim * 0.6)
	var color_resto: Color = (PALETA.resto_vena as Color).lerp(cicatriz, lim * 0.5)
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
