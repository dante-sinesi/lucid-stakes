extends RefCounted
## El arte nuevo de los bloques, de 10 x 10 x 10 minibloques (los modelos de siempre, en block_models.gd, son de 5 x 5 x 5).
## Cada bloque tiene un diseño corrupto y otro purificado, y cada tema (un grupo de etapas) cambia su paleta. Los dos estados salen de la misma semilla: el bloque
## purificado es el corrupto ya curado (las mismas grietas, apagadas y cicatrizadas), así que se ve que es el mismo bloque.
## El alfa del color de un minibloque marca que brilla (ver voxel_block.gdshader): las vetas corruptas emiten su propio color.
## La cara de arriba se pisa: su centro (8 x 8) queda siempre completo y a la misma altura.

const BlockModels := preload("res://scripts/personajes/block_models.gd")

const N := 10
enum Estado { CORRUPTO, PURIFICADO }

## Los temas, uno por cada tres etapas (como las pruebas): violeta, musgo, arenisca, brasa y alba. Cada paleta: tonos de la piedra corrupta, vena y núcleo de la vena (emiten), tonos de la piedra
## purificada, cicatriz (la grieta curada) y resto de vena (lo que queda de la corrupción).
const TEMAS := [
	{
		"nombre": "Piedra violeta",
		"corrupta": [Color(0.075, 0.055, 0.105), Color(0.105, 0.075, 0.145), Color(0.14, 0.10, 0.19)],
		"roca_vena": Color(0.17, 0.06, 0.24),
		"vena": Color(0.78, 0.13, 0.95, 0.40),
		"nucleo": Color(1.0, 0.5, 1.0, 0.22),
		"halo": Color(0.45, 0.08, 0.60, 0.88),
		"pura": [Color(0.70, 0.66, 0.84), Color(0.75, 0.71, 0.88), Color(0.80, 0.77, 0.92)],
		"pura_arriba": Color(0.88, 0.85, 0.97),
		"cicatriz": Color(0.50, 0.44, 0.67),
		"resto_vena": Color(0.62, 0.18, 0.72),
	},
	{
		"nombre": "Piedra de musgo",   # etapas 4 a 6
		"corrupta": [Color(0.04, 0.09, 0.09), Color(0.06, 0.12, 0.12), Color(0.09, 0.16, 0.15)],
		"roca_vena": Color(0.05, 0.22, 0.22),
		"vena": Color(0.10, 0.95, 0.80, 0.40),
		"nucleo": Color(0.65, 1.0, 0.95, 0.22),
		"halo": Color(0.05, 0.50, 0.45, 0.88),
		"pura": [Color(0.62, 0.78, 0.70), Color(0.68, 0.83, 0.75), Color(0.74, 0.88, 0.80)],
		"pura_arriba": Color(0.85, 0.96, 0.90),
		"cicatriz": Color(0.42, 0.58, 0.52),
		"resto_vena": Color(0.10, 0.62, 0.52),
	},
	{
		"nombre": "Arenisca",   # etapas 7 a 9
		"corrupta": [Color(0.11, 0.06, 0.04), Color(0.15, 0.08, 0.05), Color(0.20, 0.11, 0.07)],
		"roca_vena": Color(0.30, 0.10, 0.04),
		"vena": Color(1.0, 0.50, 0.08, 0.40),
		"nucleo": Color(1.0, 0.85, 0.45, 0.22),
		"halo": Color(0.65, 0.22, 0.04, 0.88),
		"pura": [Color(0.84, 0.72, 0.56), Color(0.89, 0.77, 0.61), Color(0.93, 0.82, 0.67)],
		"pura_arriba": Color(0.97, 0.90, 0.78),
		"cicatriz": Color(0.62, 0.48, 0.34),
		"resto_vena": Color(0.82, 0.38, 0.10),
	},
	{
		"nombre": "Roca de brasa",   # etapas 10 a 12
		"corrupta": [Color(0.10, 0.04, 0.05), Color(0.14, 0.05, 0.06), Color(0.19, 0.07, 0.08)],
		"roca_vena": Color(0.30, 0.04, 0.06),
		"vena": Color(1.0, 0.16, 0.20, 0.40),
		"nucleo": Color(1.0, 0.62, 0.55, 0.22),
		"halo": Color(0.60, 0.08, 0.10, 0.88),
		"pura": [Color(0.86, 0.68, 0.70), Color(0.91, 0.73, 0.75), Color(0.95, 0.79, 0.80)],
		"pura_arriba": Color(0.98, 0.88, 0.89),
		"cicatriz": Color(0.64, 0.44, 0.47),
		"resto_vena": Color(0.80, 0.18, 0.24),
	},
	{
		"nombre": "Piedra del alba",   # etapas 13 a 15
		"corrupta": [Color(0.07, 0.07, 0.10), Color(0.10, 0.10, 0.14), Color(0.14, 0.14, 0.19)],
		"roca_vena": Color(0.22, 0.20, 0.08),
		"vena": Color(1.0, 0.82, 0.25, 0.40),
		"nucleo": Color(1.0, 0.97, 0.75, 0.22),
		"halo": Color(0.55, 0.42, 0.08, 0.88),
		"pura": [Color(0.88, 0.88, 0.94), Color(0.93, 0.93, 0.98), Color(0.97, 0.97, 1.0)],
		"pura_arriba": Color(1.0, 1.0, 1.0),
		"cicatriz": Color(0.66, 0.66, 0.76),
		"resto_vena": Color(0.86, 0.68, 0.18),
	},
]

static var _cache := {}


static func tema(i: int) -> Dictionary:
	return TEMAS[clampi(i, 0, TEMAS.size() - 1)]


static func _h(x: int, y: int, z: int, k: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (k * 2654435761)
	return float(absi(h) % 1000) / 1000.0


static func _bordes(p: Vector3i) -> int:
	return int(p.x == 0 or p.x == N - 1) + int(p.y == 0 or p.y == N - 1) + int(p.z == 0 or p.z == N - 1)


## El centro de la cara de arriba (lo que se pisa): siempre completo.
static func _centro_arriba(p: Vector3i) -> bool:
	return p.y == N - 1 and p.x >= 1 and p.x <= N - 2 and p.z >= 1 and p.z <= N - 2


## Los minibloques de un bloque de piedra: {Vector3i: Color}.
static func piedra(estado: int, tema_i := 0, semilla := 0) -> Dictionary:
	var th := tema(tema_i)
	var corrupto := estado == Estado.CORRUPTO
	var sd := semilla * 31 + 7
	var vox := {}
	# 1) la forma: las esquinas y aristas se desgastan (mucho en el corrupto, poco en el purificado) y hay mordiscos en las esquinas
	var p_arista := 0.38 if corrupto else 0.12
	var p_cara := 0.06 if corrupto else 0.025
	var p_esquina := 1.0 if corrupto else 0.6
	var mordiscos: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	for i in (3 if corrupto else 1):
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
						if Vector3(p).distance_to(m) < (2.0 if corrupto else 1.6):
							mordido = true
					if mordido and p.y < N - 1:
						continue
				vox[p] = _color_base(p, estado, th, sd)
	# 2) las grietas: caminos de un minibloque en cada cara (menos la de abajo), los mismos en los dos estados (el purificado es el corrupto curado);
	# en el corrupto son vetas hundidas que brillan, en el purificado quedan cicatrices con algún resto de vena
	var rng_g := RandomNumberGenerator.new()
	rng_g.seed = sd + 100
	for cara in 5:
		var caminos: Array = [_camino(rng_g, 13 + rng_g.randi() % 8), _camino(rng_g, 12 + rng_g.randi() % 8)]
		var con_segundo := rng_g.randf() < 0.45
		for k in caminos.size():
			if corrupto and k == 1 and not con_segundo:
				continue
			var i := 0
			for uv in caminos[k]:
				var p := _de_cara(cara, uv)
				var nucleo := (i % 9 == 4)
				i += 1
				if not vox.has(p):
					continue
				if corrupto:
					_vena_corrupta(vox, p, cara, nucleo, th)
				else:
					_cicatriz(vox, p, cara, _h(p.x, p.y, p.z, sd + 5) < 0.4, th)
	return vox


static func _color_base(p: Vector3i, estado: int, th: Dictionary, sd: int) -> Color:
	var tonos: Array = th.corrupta if estado == Estado.CORRUPTO else th.pura
	var r := _h(p.x, p.y, p.z, sd + 3)
	var c: Color = tonos[0] if r < 0.4 else (tonos[1] if r < 0.8 else tonos[2])
	if estado == Estado.PURIFICADO and _centro_arriba(p):
		c = (th.pura_arriba as Color).darkened(_h(p.x, p.y, p.z, sd + 8) * 0.06)
	elif estado == Estado.CORRUPTO and _centro_arriba(p):
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


## Una veta corrupta: en los costados se hunde un minibloque y el de abajo brilla; arriba (que se pisa) brilla a ras. La roca de alrededor se tiñe de violeta.
static func _vena_corrupta(vox: Dictionary, p: Vector3i, cara: int, nucleo: bool, th: Dictionary) -> void:
	var color: Color = th.nucleo if nucleo else th.vena
	var objetivo := p
	if cara != 0:
		var dentro := p + _hacia_adentro(cara)
		if vox.has(dentro):
			vox.erase(p)
			objetivo = dentro
	vox[objetivo] = color
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		var q: Vector3i = objetivo + d
		if vox.has(q) and (vox[q] as Color).a >= 1.0 and (vox[q] as Color).r < 0.3:
			vox[q] = th.halo if _h(q.x, q.y, q.z, 77) < 0.16 else (vox[q] as Color).lerp(th.roca_vena, 0.5)


## Una grieta ya curada: una cicatriz clara y, a veces, un resto de vena que todavía se ve (apagado, sin brillo).
static func _cicatriz(vox: Dictionary, p: Vector3i, cara: int, resto: bool, th: Dictionary) -> void:
	if cara != 0 and _h(p.x, p.y, p.z, 41) < 0.22:   # (algunas muescas: la grieta se hundió un minibloque)
		var dentro := p + _hacia_adentro(cara)
		if vox.has(dentro):
			vox.erase(p)
			vox[dentro] = th.resto_vena if resto else th.cicatriz.darkened(0.12)
			return
	vox[p] = th.resto_vena if resto else th.cicatriz


## La malla de un bloque de piedra (con la memoria de modelos).
static func malla_piedra(estado: int, tema_i := 0, semilla := 0) -> ArrayMesh:
	var key := "piedra|%d|%d|%d" % [estado, tema_i, semilla]
	if not _cache.has(key):
		_cache[key] = malla(piedra(estado, tema_i, semilla))
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
