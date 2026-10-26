extends RefCounted
## El arte nuevo de los bloques, de 10 x 10 x 10 minibloques (los modelos de siempre, en block_models.gd, son de 5 x 5 x 5).
## Cada bloque tiene un diseño corrupto y otro purificado. Los dos son puntos de una misma escala de corrupción (`corrupcion`): la **corrupción son las grietas con magma violeta**
## y la piedra oscura y desgastada; al limpiarse la piedra se aclara a lavanda, las grietas se apagan y se cicatrizan, y la forma se alisa. Hay cinco niveles, uno cada tres etapas
## (como las pruebas), y bajan toda la escala: el corrupto de la última etapa parece el purificado de la primera, y el purificado de la última ya casi no tiene huellas.
## Los dos estados salen de la misma semilla: el bloque purificado es el corrupto ya curado (las mismas grietas, apagadas y cicatrizadas).
## El alfa del color de un minibloque marca que brilla (ver voxel_block.gdshader): las vetas corruptas emiten su propio color.
## La cara de arriba se pisa: su centro (8 x 8) queda completo y a la misma altura; la única excepción son las ranuras finas de magma con mucha corrupción (un minibloque de profundidad,
## con el magma de abajo a la vista).

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
	"pura": [Color(0.62, 0.58, 0.77), Color(0.66, 0.62, 0.81), Color(0.70, 0.66, 0.85)],
	"pura_limpia": [Color(0.68, 0.64, 0.82), Color(0.72, 0.68, 0.86), Color(0.77, 0.73, 0.90)],   # (la piedra ya casi sin corrupción: un poco más clara que la de la etapa 1, pero sin pasarse: con la luz del juego lo claro se quema a blanco)
	"pura_arriba": Color(0.74, 0.71, 0.88),
	"cicatriz": Color(0.50, 0.44, 0.67),
	"resto_vena": Color(0.62, 0.18, 0.72),
}

## La corrupción de cada nivel. Los pasos son parejos para que se note el cambio de una etapa a la siguiente; el purificado baja más rápido al principio (el de la primera etapa
## todavía conserva bastante: se ve más corrupto que el de la segunda).
## El bloque pesado (hierro): acero azulado cuando está limpio y metal azul oscuro (no negro: no se confunde con la obsidiana) cuando está corrupto; marco más oscuro en todas las
## aristas, esquinas y remaches dorados por los bordes, y cuatro tornillos en la cara de arriba.
const PALETA_HIERRO := {
	"acero": [Color(0.50, 0.55, 0.67), Color(0.54, 0.59, 0.71), Color(0.58, 0.63, 0.75)],
	"acero_limpio": [Color(0.55, 0.60, 0.72), Color(0.59, 0.64, 0.76), Color(0.63, 0.68, 0.80)],
	"corrupto": [Color(0.16, 0.20, 0.30), Color(0.19, 0.23, 0.34), Color(0.23, 0.27, 0.38)],
	"remache": Color(0.86, 0.70, 0.30),
	"cicatriz": Color(0.38, 0.41, 0.55),
}

## El hielo: cristal celeste con vetas blancas cuando está limpio; azul verdoso oscuro con destellos fríos cuando está corrupto (no se confunde con la obsidiana violeta ni con el
## metal azul del pesado). Lleva el material brillante (poco rugoso) de los bloques de hielo.
const PALETA_HIELO := {
	"cristal": [Color(0.52, 0.70, 0.82), Color(0.57, 0.75, 0.86), Color(0.62, 0.80, 0.90)],
	"cristal_limpio": [Color(0.57, 0.75, 0.87), Color(0.62, 0.80, 0.91), Color(0.67, 0.85, 0.95)],
	"corrupto": [Color(0.05, 0.14, 0.21), Color(0.07, 0.18, 0.27), Color(0.10, 0.23, 0.33)],
	"veta": Color(0.76, 0.89, 0.98),
	"destello": Color(0.60, 0.95, 1.0),
	"cicatriz": Color(0.50, 0.68, 0.80),
}

## El bloque agrietado (arenisca): arena cálida en capas (sedimentos), con grietas hondas que se ven siempre (es lo que lo hace frágil: se rompe al bajarse de él); corrupto es
## marrón oscuro con magma en las grietas. Se desmorona más que la piedra en esquinas y aristas.
const PALETA_ARENA := {
	"arena": [Color(0.66, 0.54, 0.39), Color(0.70, 0.58, 0.43), Color(0.74, 0.62, 0.47)],
	"arena_limpia": [Color(0.72, 0.60, 0.44), Color(0.76, 0.64, 0.48), Color(0.80, 0.68, 0.52)],
	"corrupto": [Color(0.30, 0.20, 0.12), Color(0.36, 0.24, 0.15), Color(0.42, 0.29, 0.18)],   # (marrón tierra: no se confunde con la obsidiana violeta)
	"grieta": Color(0.20, 0.10, 0.05),
	"cicatriz": Color(0.50, 0.38, 0.26),
}

## La trampa: piedra gris azulada (más neutra que la piedra común) con una X por todos lados: arriba y en cada costado, una X de juntas finas y oscuras de esquina a esquina (las tapas de la trampa, y el aviso de que
## se desarma al pisarla).
const PALETA_TRAMPA := {
	"piedra": [Color(0.56, 0.58, 0.70), Color(0.60, 0.62, 0.74), Color(0.64, 0.66, 0.78)],
	"piedra_limpia": [Color(0.62, 0.64, 0.76), Color(0.66, 0.68, 0.80), Color(0.70, 0.72, 0.84)],
	"corrupto": [Color(0.09, 0.09, 0.14), Color(0.12, 0.12, 0.18), Color(0.16, 0.16, 0.23)],
	"cicatriz": Color(0.42, 0.44, 0.58),
}

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


## Los minibloques de un bloque pesado (hierro): {Vector3i: Color}.
static func hierro(estado: int, nivel := 0, semilla := 0) -> Dictionary:
	return piedra_con(corrupcion(estado, nivel), semilla, "hierro")


## Los minibloques de un bloque de hielo: {Vector3i: Color}.
static func hielo(estado: int, nivel := 0, semilla := 0) -> Dictionary:
	return piedra_con(corrupcion(estado, nivel), semilla, "hielo")


## Los minibloques de un bloque agrietado (arenisca): {Vector3i: Color}.
static func arenisca(estado: int, nivel := 0, semilla := 0) -> Dictionary:
	return piedra_con(corrupcion(estado, nivel), semilla, "arenisca")


## Los minibloques de una trampa: {Vector3i: Color}.
static func trampa(estado: int, nivel := 0, semilla := 0) -> Dictionary:
	return piedra_con(corrupcion(estado, nivel), semilla, "trampa")


## Los minibloques de un tipo de bloque ("piedra", "hierro", "hielo", "arenisca" o "trampa") en un estado y nivel.
static func bloque(tipo: String, estado: int, nivel := 0, semilla := 0) -> Dictionary:
	return piedra_con(corrupcion(estado, nivel), semilla, tipo)


## Un bloque de piedra con esa corrupción (0 a 1): la forma se desgasta, la piedra se oscurece y las grietas se llenan de magma a medida que sube.
static func piedra_con(c: float, semilla := 0, tipo := "piedra") -> Dictionary:
	var sd := semilla * 31 + 7
	var vox := {}
	var hierro := tipo == "hierro"   # (el hierro se desgasta mucho menos: es un cubo de placas)
	var es_hielo := tipo == "hielo"   # (el hielo se astilla en las aristas)
	var arena := tipo == "arenisca"   # (la arenisca se desmorona: más que la piedra)
	var trampa := tipo == "trampa"   # (la trampa conserva su forma de cubo: las X se tienen que leer)
	# 1) la forma: las esquinas y aristas se desgastan y hay mordiscos en las esquinas (más cuanto más corrupto)
	var p_arista := 0.0 if hierro else (lerpf(0.0, 0.30, c) if es_hielo else (lerpf(0.18, 0.45, c) if arena else (lerpf(0.0, 0.2, c) if trampa else lerpf(0.03, 0.38, c))))   # (el hierro conserva su marco, sus esquinas y sus remaches enteros)
	var p_cara := lerpf(0.0, 0.04, c) if hierro else (lerpf(0.0, 0.03, c) if es_hielo else lerpf(0.01, 0.06, c))
	var p_esquina := 0.0 if hierro else (1.0 if es_hielo else (lerpf(0.55, 1.0, c) if arena else (lerpf(0.0, 0.5, c) if trampa else lerpf(0.15, 1.0, c))))
	var n_mordiscos := 0 if (hierro or es_hielo or trampa) else (roundi(lerpf(1.0, 3.0, c)) if arena else roundi(lerpf(0.0, 3.0, c)))
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
				vox[p] = _color_hierro(p, c, sd) if hierro else (_color_hielo(p, c, sd) if es_hielo else (_color_arena(p, c, sd) if arena else (_color_trampa(p, c, sd) if trampa else _color_base(p, c, sd))))
	if arena:
		_fisuras(vox, sd)
	# 2) las grietas, que son la corrupción: caminos de un minibloque en cada cara (menos la de abajo), siempre los mismos para una semilla (un bloque que se limpia
	# conserva sus grietas, cada vez más cortadas y apagadas); con mucha corrupción son vetas hundidas con magma que brilla, y con poca, cicatrices con algún resto de vena
	var rng_g := RandomNumberGenerator.new()
	rng_g.seed = sd + 100
	var visibles := maxf(clampf(c * 1.5, 0.0, 1.0), 0.8) if arena else clampf(c * 1.5, 0.0, 1.0)   # (qué parte de cada grieta se ve; en la arenisca las grietas hondas se ven siempre)
	for cara in 5:
		var caminos: Array = [_camino(rng_g, 13 + rng_g.randi() % 8), _camino(rng_g, 12 + rng_g.randi() % 8)]
		var con_segundo := rng_g.randf() < 0.45
		for k in caminos.size():
			if k == 1 and not con_segundo and c > 0.7 and not arena:
				continue
			var i := 0
			for uv in caminos[k]:
				var p := _de_cara(cara, uv)
				var nucleo := (i % 9 == 4)
				i += 1
				if not vox.has(p) or _h(p.x, p.y, p.z, sd + 13) > visibles or (hierro and _bordes(p) >= 2) or (trampa and _es_cruz(p)):   # (las grietas del hierro no tocan el marco ni los remaches; las de la trampa, su cruz)
					continue
				_grieta(vox, p, cara, nucleo, c, sd, tipo)
	if trampa:   # (la cruz roja se ve siempre entera, pase lo que pase con las grietas)
		for x in range(1, N - 1):
			for z in range(1, N - 1):
				if _es_cruz(Vector3i(x, N - 1, z)):
					vox[Vector3i(x, N - 1, z)] = _color_cruz(c)
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


## El color del hierro en un minibloque: acero azulado o metal azul oscuro según la corrupción (rampa entre 0,5 y 1). Las aristas forman un marco más oscuro, las esquinas
## y dos remaches por arista son dorados, y la cara de arriba lleva cuatro tornillos (todo se oscurece un poco con la corrupción, pero se sigue leyendo).
static func _color_hierro(p: Vector3i, c: float, sd: int) -> Color:
	var r := _h(p.x, p.y, p.z, sd + 3)
	var i := 0 if r < 0.4 else (1 if r < 0.8 else 2)
	var oscuro := clampf((c - 0.5) / 0.5, 0.0, 1.0)
	var acero: Color = (PALETA_HIERRO.acero[i] as Color).lerp(PALETA_HIERRO.acero_limpio[i], clampf(1.0 - c * 2.0, 0.0, 1.0))
	var col := acero.lerp(PALETA_HIERRO.corrupto[i], oscuro)
	var remache: Color = (PALETA_HIERRO.remache as Color).lerp(col, oscuro * 0.45)
	var b := _bordes(p)
	if b == 3:
		return remache   # (las esquinas)
	if b == 2:
		# a lo largo de la arista, dos remaches (en 3 y 6); el resto es el marco oscuro
		var largo := p.x if (p.y == 0 or p.y == N - 1) and (p.z == 0 or p.z == N - 1) else (p.y if (p.x == 0 or p.x == N - 1) and (p.z == 0 or p.z == N - 1) else p.z)
		if largo == 3 or largo == 6:
			return remache
		return col.darkened(0.38)
	if p.y == N - 1 and (p.x == 2 or p.x == 7) and (p.z == 2 or p.z == 7):
		return remache.darkened(0.15)   # (los tornillos de arriba)
	if _centro_arriba(p) and oscuro < 0.5:
		return col.lightened(0.05)
	return col


## El color del hielo en un minibloque. A diferencia de la piedra (ruidosa, minibloque a minibloque) el hielo es liso y brillante: un degradado suave de arriba hacia abajo, un borde más
## claro (el canto del cristal), una franja blanca en diagonal en cada cara (el reflejo) y un destello en una esquina de cada cara. Corrupto es azul verdoso oscuro y conserva
## el reflejo, el canto frío y los destellos, que son lo que lo distingue de la piedra y del hierro.
static func _color_hielo(p: Vector3i, c: float, sd: int) -> Color:
	var oscuro := clampf((c - 0.5) / 0.5, 0.0, 1.0)
	var t := float(p.y) / float(N - 1)   # (0 abajo, 1 arriba)
	var limpieza_c := clampf(1.0 - c * 2.0, 0.0, 1.0)
	var claro: Color = (PALETA_HIELO.cristal[2] as Color).lerp(PALETA_HIELO.cristal_limpio[2], limpieza_c)
	var hondo: Color = (PALETA_HIELO.cristal[0] as Color).lerp(PALETA_HIELO.cristal_limpio[0], limpieza_c)
	var col: Color = hondo.lerp(claro, t).lerp((PALETA_HIELO.corrupto[0] as Color).lerp(PALETA_HIELO.corrupto[2], t), oscuro)
	col = col.darkened(_h(p.x, p.y, p.z, sd + 3) * 0.03)   # (casi sin ruido)
	# las coordenadas sobre la cara que se ve
	var u := p.x
	var v := p.z
	if p.y != N - 1:
		if p.x == 0 or p.x == N - 1:
			u = p.z
			v = p.y
		else:
			u = p.x
			v = p.y
	var b := _bordes(p)
	if b >= 2:
		return col.lerp(PALETA_HIELO.veta, 0.55 - 0.25 * oscuro)   # (el canto del cristal, más claro)
	var reflejo := (u - v + N * 2) % N
	if reflejo == 2 or reflejo == 3:
		col = col.lerp(PALETA_HIELO.veta, 0.55 - 0.30 * oscuro)   # (la franja de reflejo en diagonal)
	if u >= 2 and u <= 3 and v >= 6 and v <= 7 and (u + v) % 2 == 0:
		col = PALETA_HIELO.destello   # (el destello en una esquina de cada cara)
	if _escarchado(p, sd) and oscuro < 0.6:   # (el hielo escarchado: más blanquecino y con grano, como el cristal con aire adentro)
		col = col.lerp(Color(0.86, 0.94, 0.99), 0.42 * (1.0 - oscuro)).darkened(_h(p.x, p.y, p.z, sd + 9) * 0.10)
	elif oscuro < 0.6:
		col = col.darkened(0.10)   # (el hielo claro, un poco más hondo: se nota la diferencia con el escarchado)
	return col


## Las fisuras de la arenisca (siempre las mismas para una semilla, en cualquier nivel de corrupción): en cada cara, de cuatro a seis grietas al azar, cortas o largas, casi todas en
## diagonal, que nacen y mueren en cualquier lado (no cruzan la cara entera); cada una tiene su profundidad (de uno a tres minibloques) y algunas son el doble de anchas.
## En los costados se hunden de verdad (con el fondo muy oscuro); arriba, que se pisa, queda una línea oscura a ras.
static func _fisuras(vox: Dictionary, sd: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd + 500
	for cara in 5:
		for k in 4 + rng.randi() % 3:
			var camino := _camino_diagonal(rng, 4 + rng.randi() % 11)
			var prof := 1 + rng.randi() % 3
			var ancha := rng.randf() < 0.35
			var celdas: Array[Vector2i] = []
			for uv in camino:
				celdas.append(uv)
				if ancha:
					celdas.append(uv + Vector2i(1, 0))
			for uv in celdas:
				if uv.x < 0 or uv.x > N - 1 or uv.y < 0 or uv.y > N - 1:
					continue
				var p := _de_cara(cara, uv)
				if not vox.has(p):
					continue
				if cara == 0:
					vox[p] = (PALETA_ARENA.grieta as Color).lerp(PALETA_ARENA.cicatriz, 0.15)   # (arriba: una línea a ras)
					continue
				var adentro := _hacia_adentro(cara)
				var fondo := p
				for d in prof + 1:
					var q: Vector3i = p + adentro * d
					if not vox.has(q) or _centro_arriba(q):
						break
					fondo = q
					if d < prof:
						vox.erase(q)
				if fondo != p and vox.has(fondo):
					vox[fondo] = (PALETA_ARENA.grieta as Color).darkened(0.15)


## Un camino de grieta sobre una cara de 10 x 10: empieza en cualquier celda, va casi siempre en diagonal y gira poco.
static func _camino_diagonal(rng: RandomNumberGenerator, largo: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var pos := Vector2i(rng.randi() % N, rng.randi() % N)
	var dirs := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
	var d := (1 + 2 * (rng.randi() % 4)) if rng.randf() < 0.7 else (2 * (rng.randi() % 4))   # (índices impares: diagonales)
	for i in largo:
		out.append(pos)
		if rng.randf() < 0.12:
			d = (d + (1 if rng.randf() < 0.5 else 7)) % 8
		pos += dirs[d]
		if pos.x < 0 or pos.x > N - 1 or pos.y < 0 or pos.y > N - 1:
			break
	return out


## El color de la arenisca en un minibloque: arena cálida (más clara cuanto más limpia) o marrón oscuro con la corrupción (rampa entre 0,5 y 1), en capas horizontales
## (cada tres minibloques una franja un poco más oscura, como los sedimentos).
static func _color_arena(p: Vector3i, c: float, sd: int) -> Color:
	var r := _h(p.x, p.y, p.z, sd + 3)
	var i := 0 if r < 0.4 else (1 if r < 0.8 else 2)
	var oscuro := clampf((c - 0.5) / 0.5, 0.0, 1.0)
	var arena: Color = (PALETA_ARENA.arena[i] as Color).lerp(PALETA_ARENA.arena_limpia[i], clampf(1.0 - c * 2.0, 0.0, 1.0))
	var col := arena.lerp(PALETA_ARENA.corrupto[i], oscuro)
	if p.y % 3 == 0:
		col = col.darkened(0.14)   # (la capa)
	elif p.y % 3 == 1:
		col = col.lightened(0.05)
	if _centro_arriba(p):
		col = col.lightened(0.05)
	return col


## El color de la cruz de la trampa: las mismas juntas oscuras de los costados (la piedra de la trampa, más oscura), finas y discretas, para que arriba no llame la atención.
static func _color_cruz(c: float) -> Color:
	var oscuro := clampf((c - 0.5) / 0.5, 0.0, 1.0)
	var piedra: Color = (PALETA_TRAMPA.piedra[1] as Color).lerp(PALETA_TRAMPA.piedra_limpia[1], clampf(1.0 - c * 2.0, 0.0, 1.0))
	return piedra.lerp(PALETA_TRAMPA.corrupto[1], oscuro).darkened(0.34)


## ¿Es un minibloque de la cruz de la trampa (las dos diagonales de la cara de arriba, de un minibloque de ancho)?
static func _es_cruz(p: Vector3i) -> bool:
	return p.y == N - 1 and p.x >= 1 and p.x <= N - 2 and p.z >= 1 and p.z <= N - 2 and (p.x == p.z or p.x + p.z == N - 1)


## El color de la trampa en un minibloque: gris azulado (o gris muy oscuro con corrupción, rampa entre 0,5 y 1); arriba, una X de juntas finas y oscuras en diagonal de lado a lado (siempre visible, pero discreta: es la advertencia);
## en cada costado, una X de juntas oscuras de esquina a esquina.
static func _color_trampa(p: Vector3i, c: float, sd: int) -> Color:
	var r := _h(p.x, p.y, p.z, sd + 3)
	var i := 0 if r < 0.4 else (1 if r < 0.8 else 2)
	var oscuro := clampf((c - 0.5) / 0.5, 0.0, 1.0)
	var piedra: Color = (PALETA_TRAMPA.piedra[i] as Color).lerp(PALETA_TRAMPA.piedra_limpia[i], clampf(1.0 - c * 2.0, 0.0, 1.0))
	var col := piedra.lerp(PALETA_TRAMPA.corrupto[i], oscuro)
	if _es_cruz(p):
		return _color_cruz(c)
	if _centro_arriba(p):
		return col.lightened(0.04)
	if p.y != N - 1:
		var u := p.z if (p.x == 0 or p.x == N - 1) else p.x
		if p.y == u or p.y + u == N - 1:
			return col.darkened(0.38)   # (la X de juntas del costado)
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
static func _grieta(vox: Dictionary, p: Vector3i, cara: int, nucleo: bool, c: float, sd: int, tipo := "piedra") -> void:
	if c >= 0.45:
		var color: Color = PALETA.nucleo if nucleo else PALETA.vena
		var apagado := clampf((1.0 - c) / 0.55, 0.0, 1.0)   # (0 con la corrupción al máximo, 1 con 0,45)
		color.a = lerpf(0.22 if nucleo else 0.40, 1.0, apagado)
		var objetivo := p
		if cara != 0 or c > 0.7:   # (arriba también se hunde un minibloque, pero sólo con mucha corrupción: una ranura fina de magma; el plano que se pisa sigue siendo el de siempre)
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
	if tipo == "arenisca":
		return   # (la arenisca ya tiene sus fisuras hondas, en `_fisuras`)
	var resto := _h(p.x, p.y, p.z, sd + 5) < lerpf(0.0, 0.5, c / 0.45)
	var cicatriz: Color = (((PALETA_HIERRO.cicatriz if tipo == "hierro" else (PALETA_HIELO.cicatriz if tipo == "hielo" else PALETA.cicatriz))) as Color).lerp(Color(0.74, 0.70, 0.86), clampf(1.0 - c * 2.0, 0.0, 1.0) * 0.6)
	var color_resto: Color = (PALETA.resto_vena as Color).lerp(cicatriz, clampf(1.0 - c * 2.0, 0.0, 1.0) * 0.5)
	if cara != 0 and _h(p.x, p.y, p.z, 41) < 0.22:   # (algunas muescas: la grieta se hundió un minibloque)
		var dentro := p + _hacia_adentro(cara)
		if vox.has(dentro):
			vox.erase(p)
			vox[dentro] = color_resto if resto else cicatriz.darkened(0.12)
			return
	vox[p] = color_resto if resto else cicatriz


## La malla de un bloque ("piedra" o "hierro"), con la memoria de modelos.
static func malla_bloque(tipo: String, estado: int, nivel := 0, semilla := 0) -> ArrayMesh:
	var key := "%s|%d|%d|%d" % [tipo, estado, nivel, semilla]
	if not _cache.has(key):
		_cache[key] = malla(bloque(tipo, estado, nivel, semilla), _opacidad_hielo.bind(semilla * 31 + 7) if tipo == "hielo" else Callable())
	return _cache[key]


## Ruido de valor en 3D (suave), de 0 a 1: manchas del tamaño de unos 3 minibloques.
static func _ruido3(p: Vector3i, sd: int) -> float:
	var q := Vector3(p) / 3.0
	var i := Vector3i(floori(q.x), floori(q.y), floori(q.z))
	var f := q - Vector3(i)
	f = f * f * (Vector3(3, 3, 3) - 2.0 * f)
	var v := 0.0
	for dx in 2:
		for dy in 2:
			for dz in 2:
				var w := (f.x if dx == 1 else 1.0 - f.x) * (f.y if dy == 1 else 1.0 - f.y) * (f.z if dz == 1 else 1.0 - f.z)
				v += w * _h(i.x + dx, i.y + dy, i.z + dz, sd + 55)
	return v


## ¿Este minibloque de hielo es escarchado (opaco, blanquecino y con grano) o claro (translúcido)? Se alternan en manchas: el hielo es una fusión de las dos cosas.
static func _escarchado(p: Vector3i, sd: int) -> bool:
	return _ruido3(p, sd) > 0.42


## La opacidad de un minibloque de hielo: el magma y lo muy oscuro (corrupción) son casi opacos; el hielo escarchado es opaco y el claro es translúcido (se ve lo de atrás),
## en manchas; el canto y los reflejos se ven más.
static func _opacidad_hielo(p: Vector3i, color: Color, sd: int) -> float:
	if color.a < 1.0:
		return 1.0   # (el magma)
	var lum := color.get_luminance()
	if lum < 0.35:
		return 0.92
	if _escarchado(p, sd):
		return 1.0
	return 0.90 if lum >= 0.8 else 0.52


## La malla de un bloque de piedra.
static func malla_piedra(estado: int, nivel := 0, semilla := 0) -> ArrayMesh:
	return malla_bloque("piedra", estado, nivel, semilla)


## La malla de un modelo de 10 x 10 x 10 minibloques: sólo se dibujan las caras que se ven.
static func malla(vox: Dictionary, opacidad := Callable()) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dirs: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	for p in vox:
		for d in dirs:
			if not vox.has(p + d):
				BlockModels._add_face(st, p, d, vox[p], N, float(opacidad.call(p, vox[p])) if opacidad.is_valid() else 1.0)
	return st.commit()
