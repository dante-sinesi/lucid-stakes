extends RefCounted
## Los muebles del casino con el doble de resolución (`CasinoRoom.build_detalle`): cada uno se arma directo en minibloques finos (10 por celda, `VOXEL_FINO` = 0,1), con más piezas y más detalle que
## los del modelo base: la mesa de la ruleta con su rueda y su cuadro de apuestas, el crupier, las tragamonedas, las mesas de cartas, el taller, los barriles y cajas, las plantas, las columnas y
## los faroles. El piso fino termina en y = 3, así que todo se apoya en y = 4 (`Y0`). Las funciones reciben los diccionarios {Vector3i: Color} de lo sólido y de lo que brilla.

const CELDA := 10      # minibloques finos por celda
const Y0 := 4          # el primer minibloque sobre el piso
const CREMA := Color(1.0, 0.86, 0.5)
const NARANJA := Color(0.95, 0.62, 0.38)
const VIOLETA := Color(0.22, 0.07, 0.32)
const PIEL := Color(0.86, 0.68, 0.55)
const NEGRO := Color(0.06, 0.06, 0.08)
const BLANCO := Color(0.95, 0.95, 0.92)
const ROJO := Color(0.78, 0.12, 0.15)
const AZUL := Color(0.15, 0.25, 0.8)
const BOTONES := [Color(1.0, 0.35, 0.3), Color(1.0, 0.85, 0.3), Color(0.5, 0.8, 1.0)]


static func armar(solid: Dictionary, glow: Dictionary, lay: Dictionary, L: Dictionary) -> void:
	_ruleta(solid, glow, lay, L)
	_crupier(solid, lay)
	for m in lay.machines:
		_tragamonedas(solid, glow, m, L)
	for ct in lay.card_tables:
		_mesa_de_cartas(solid, glow, ct, L)
	if lay.has("station"):
		_taller(solid, glow, lay.station, int(lay.tier))
	for o in lay.obstacles:
		_obstaculo(solid, glow, o, L, int(lay.tier))
	for lamp in lay.get("lamps", []):
		_farol(solid, glow, lamp, L)
	for p in glow:   # lo que brilla prevalece: un minibloque no puede ser a la vez sólido y luminoso
		solid.erase(p)


# --- piezas ------------------------------------------------------------------------------------------------------------

static func _ruido(x: int, y: int, z: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (z * 83492791)
	return float(absi(h) % 1000) / 1000.0


## Una caja (máximo exclusivo) con la misma textura suave de la sala.
static func _caja(map: Dictionary, x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, color: Color) -> void:
	for x in range(x0, x1):
		for y in range(y0, y1):
			for z in range(z0, z1):
				var k := (_ruido(x, y, z) - 0.5) * 0.02
				map[Vector3i(x, y, z)] = Color(clampf(color.r + k, 0.0, 1.0), clampf(color.g + k, 0.0, 1.0), clampf(color.b + k, 0.0, 1.0))


## Un disco horizontal (de radio `r` alrededor de (cx, cz), en las capas y0..y1 sin incluir y1); con `hueco` > 0 queda un anillo.
static func _disco(map: Dictionary, cx: float, cz: float, y0: int, y1: int, r: float, color: Color, hueco := 0.0) -> void:
	for x in range(int(floor(cx - r)) - 1, int(ceil(cx + r)) + 1):
		for z in range(int(floor(cz - r)) - 1, int(ceil(cz + r)) + 1):
			var d := sqrt(pow(x + 0.5 - cx, 2) + pow(z + 0.5 - cz, 2))
			if d <= r and d >= hueco:
				_caja(map, x, y0, z, x + 1, y1, z + 1, color)


static func _esfera(map: Dictionary, cx: float, cy: float, cz: float, r: float, color: Color) -> void:
	for x in range(int(floor(cx - r)), int(ceil(cx + r)) + 1):
		for y in range(int(floor(cy - r)), int(ceil(cy + r)) + 1):
			for z in range(int(floor(cz - r)), int(ceil(cz + r)) + 1):
				if pow(x + 0.5 - cx, 2) + pow(y + 0.5 - cy, 2) + pow(z + 0.5 - cz, 2) <= r * r:
					_caja(map, x, y, z, x + 1, y + 1, z + 1, color.lerp(Color.WHITE, 0.12 if y > cy else 0.0))


static func _luz(map: Dictionary, x: int, y: int, z: int, color: Color) -> void:
	map[Vector3i(x, y, z)] = color


# --- la mesa de la ruleta ------------------------------------------------------------------------------------------------

static func _ruleta(solid: Dictionary, glow: Dictionary, lay: Dictionary, L: Dictionary) -> void:
	var tier: int = lay.tier
	var madera: Color = L.wood
	var oro: Color = L.gold
	var dy: int = int(lay.table_h) * 2
	var x0: int = lay.table.position.x * CELDA
	var z0: int = lay.table.position.y * CELDA
	var x1: int = lay.table.end.x * CELDA
	var z1: int = lay.table.end.y * CELDA
	var y := Y0 + dy
	for esquina in [[x0 + 1, z0 + 1], [x1 - 5, z0 + 1], [x0 + 1, z1 - 5], [x1 - 5, z1 - 5]]:   # patas: pie, fuste y capitel
		_caja(solid, esquina[0], y, esquina[1], esquina[0] + 4, y + 1, esquina[1] + 4, madera.darkened(0.35))
		_caja(solid, esquina[0] + 1, y + 1, esquina[1] + 1, esquina[0] + 3, y + 7, esquina[1] + 3, madera.darkened(0.15))
		_caja(solid, esquina[0], y + 7, esquina[1], esquina[0] + 4, y + 9, esquina[1] + 4, oro.darkened(0.2) if tier >= 2 else madera.darkened(0.3))
	_caja(solid, x0 + 3, y + 6, z0 + 3, x1 - 3, y + 9, z0 + 5, madera.darkened(0.25))   # el faldón entre las patas
	_caja(solid, x0 + 3, y + 6, z1 - 5, x1 - 3, y + 9, z1 - 3, madera.darkened(0.25))
	_caja(solid, x0 + 3, y + 6, z0 + 3, x0 + 5, y + 9, z1 - 3, madera.darkened(0.25))
	_caja(solid, x1 - 5, y + 6, z0 + 3, x1 - 3, y + 9, z1 - 3, madera.darkened(0.25))
	_caja(solid, x0, y + 9, z0, x1, y + 11, z1, madera)   # el tablero
	_caja(solid, x0, y + 11, z0, x1, y + 13, z0 + 2, madera.lightened(0.12))   # el borde acolchado
	_caja(solid, x0, y + 11, z1 - 2, x1, y + 13, z1, madera.lightened(0.12))
	_caja(solid, x0, y + 11, z0 + 2, x0 + 2, y + 13, z1 - 2, madera.lightened(0.12))
	_caja(solid, x1 - 2, y + 11, z0 + 2, x1, y + 13, z1 - 2, madera.lightened(0.12))
	_caja(solid, x0 + 2, y + 11, z0 + 2, x1 - 2, y + 12, z1 - 2, L.felt)   # el paño
	if tier >= 2:   # un filete dorado en el borde de afuera
		_caja(solid, x0, y + 13, z0, x1, y + 14, z0 + 1, oro)
		_caja(solid, x0, y + 13, z1 - 1, x1, y + 14, z1, oro)
		_caja(solid, x0, y + 13, z0 + 1, x0 + 1, y + 14, z1 - 1, oro)
		_caja(solid, x1 - 1, y + 13, z0 + 1, x1, y + 14, z1 - 1, oro)
	# la rueda: bandeja, pista de la bola, 13 casilleros (el 0, violeta, mira al norte), cono central con su perilla
	var cx := x0 + 10.0
	var cz := z0 + 10.0
	var yr := y + 12
	_disco(solid, cx, cz, yr, yr + 1, 8.8, madera.darkened(0.15))
	_disco(solid, cx, cz, yr + 1, yr + 2, 8.8, madera.lightened(0.2), 7.8)   # el aro de la bandeja
	_disco(solid, cx, cz, yr + 1, yr + 2, 7.7, Color(0.62, 0.5, 0.34), 6.4)   # la pista de la bola
	for x in range(int(cx) - 7, int(cx) + 7):
		for z in range(int(cz) - 7, int(cz) + 7):
			var dx := x + 0.5 - cx
			var dz := z + 0.5 - cz
			var d := sqrt(dx * dx + dz * dz)
			if d > 6.3 or d < 3.6:
				continue
			var ang := fposmod(atan2(dx, -dz), TAU)
			var sector := ang / (TAU / 13.0)
			var casillero := int(round(sector)) % 13
			var borde := absf(sector - round(sector)) > 0.42   # la separación entre casilleros
			var color := VIOLETA if casillero == 0 else (CREMA if casillero % 2 == 1 else NARANJA)
			solid[Vector3i(x, yr + 1, z)] = oro.darkened(0.15) if borde else color
	_disco(solid, cx, cz, yr + 1, yr + 2, 3.5, madera.darkened(0.2))
	_disco(solid, cx, cz, yr + 2, yr + 3, 2.8, oro)
	_disco(solid, cx, cz, yr + 3, yr + 4, 1.6, oro.lightened(0.15))
	for brazo in [[1, 0], [-1, 0], [0, 1], [0, -1]]:   # los cuatro rayos del cono
		for k in range(2, 5):
			solid[Vector3i(int(cx) + brazo[0] * k - (1 if brazo[0] < 0 else 0), yr + 2, int(cz) + brazo[1] * k - (1 if brazo[1] < 0 else 0))] = oro.lightened(0.1)
	_luz(glow, int(cx), yr + 4, int(cz), L.lamp)
	_luz(glow, int(cx), yr + 2, int(cz) - 7, Color.WHITE)   # la bola
	# el cuadro de apuestas (rojo, negro y el cero) y las fichas
	for i in 3:
		for j in 5:
			var bx := x0 + 22 + i * 3
			var bz := z0 + 3 + j * 3
			_caja(solid, bx, y + 12, bz, bx + 2, y + 13, bz + 2, ROJO if (i + j) % 2 == 0 else Color(0.09, 0.09, 0.11))
	_caja(solid, x0 + 20, y + 12, z0 + 3, x0 + 21, y + 13, z1 - 3, VIOLETA)
	for k in 3:   # las pilas de fichas
		_caja(solid, x1 - 5, y + 12 + k, z0 + 3, x1 - 3, y + 13 + k, z0 + 5, ROJO.lightened(0.05 * k))
	for k in 2:
		_caja(solid, x1 - 5, y + 12 + k, z1 - 7, x1 - 3, y + 13 + k, z1 - 5, AZUL)
	_luz(glow, x1 - 5, y + 15, z0 + 3, oro.lightened(0.3))
	if tier == 0:   # en la taberna, una vela chorreada
		_caja(solid, x0 + 3, y + 12, z1 - 5, x0 + 5, y + 17, z1 - 3, Color(0.9, 0.85, 0.7))
		_caja(solid, x0 + 3, y + 12, z1 - 6, x0 + 4, y + 14, z1 - 5, Color(0.8, 0.75, 0.6))
		_luz(glow, x0 + 3, y + 17, z1 - 5, Color(1.0, 0.7, 0.3))
		_luz(glow, x0 + 3, y + 18, z1 - 5, Color(1.0, 0.85, 0.45))


# --- el crupier ---------------------------------------------------------------------------------------------------------

static func _crupier(solid: Dictionary, lay: Dictionary) -> void:
	var cx: int = lay.dealer.x * CELDA + 5
	var cz: int = lay.dealer.y * CELDA + 5
	var y := Y0 + int(lay.heights.get(lay.dealer, 0)) * 2
	_caja(solid, cx - 3, y, cz - 2, cx, y + 1, cz + 3, NEGRO)   # zapatos
	_caja(solid, cx, y, cz - 2, cx + 3, y + 1, cz + 3, NEGRO)
	_caja(solid, cx - 3, y + 1, cz - 2, cx, y + 5, cz + 2, Color(0.1, 0.1, 0.13))   # piernas
	_caja(solid, cx, y + 1, cz - 2, cx + 3, y + 5, cz + 2, Color(0.08, 0.08, 0.1))
	_caja(solid, cx - 3, y + 5, cz - 2, cx + 3, y + 6, cz + 2, Color(0.25, 0.14, 0.08))   # cinturón con hebilla
	_caja(solid, cx - 1, y + 5, cz + 2, cx + 1, y + 6, cz + 3, Color(0.88, 0.7, 0.28))
	_caja(solid, cx - 3, y + 6, cz - 2, cx + 3, y + 12, cz + 2, BLANCO)   # camisa
	_caja(solid, cx - 3, y + 6, cz + 1, cx - 1, y + 12, cz + 2, Color(0.5, 0.08, 0.14))   # chaleco (dos solapas)
	_caja(solid, cx + 1, y + 6, cz + 1, cx + 3, y + 12, cz + 2, Color(0.5, 0.08, 0.14))
	for by in [7, 9, 11]:
		solid[Vector3i(cx, y + by, cz + 2)] = Color(0.88, 0.7, 0.28)   # botones
	_caja(solid, cx - 1, y + 11, cz + 1, cx + 1, y + 12, cz + 3, Color(0.7, 0.1, 0.15))   # moño
	_caja(solid, cx - 5, y + 7, cz - 1, cx - 3, y + 12, cz + 2, BLANCO)   # brazos
	_caja(solid, cx + 3, y + 7, cz - 1, cx + 5, y + 12, cz + 2, BLANCO)
	_caja(solid, cx - 5, y + 5, cz - 1, cx - 3, y + 7, cz + 2, PIEL)   # manos
	_caja(solid, cx + 3, y + 5, cz - 1, cx + 5, y + 7, cz + 2, PIEL)
	_caja(solid, cx - 3, y + 12, cz - 2, cx + 3, y + 16, cz + 2, PIEL)   # cabeza
	_caja(solid, cx - 3, y + 14, cz - 2, cx + 3, y + 16, cz - 1, Color(0.12, 0.08, 0.06))   # el pelo de atrás
	solid[Vector3i(cx - 2, y + 14, cz + 2)] = Color(0.1, 0.1, 0.1)   # ojos
	solid[Vector3i(cx + 1, y + 14, cz + 2)] = Color(0.1, 0.1, 0.1)
	_caja(solid, cx - 1, y + 13, cz + 2, cx + 1, y + 14, cz + 3, Color(0.78, 0.6, 0.48))   # nariz
	_caja(solid, cx - 2, y + 12, cz + 2, cx + 2, y + 13, cz + 3, Color(0.12, 0.08, 0.06))   # bigote
	_caja(solid, cx - 5, y + 16, cz - 4, cx + 5, y + 17, cz + 4, NEGRO)   # ala del sombrero
	_caja(solid, cx - 3, y + 17, cz - 2, cx + 3, y + 20, cz + 2, NEGRO)   # copa
	_caja(solid, cx - 3, y + 17, cz - 2, cx + 3, y + 18, cz + 2, Color(0.7, 0.1, 0.15))   # cinta
	solid[Vector3i(cx, y + 17, cz + 2)] = Color(0.88, 0.7, 0.28)


# --- tragamonedas -------------------------------------------------------------------------------------------------------

## Una tragamonedas armada mirando al este (contra la pared oeste); las de la pared norte (y = 0) se giran (x y z cambian de lugar) para mirar al sur.
static func _tragamonedas(solid: Dictionary, glow: Dictionary, celda: Vector2i, L: Dictionary) -> void:
	var norte := celda.x != 0
	var cuerpo := Color(0.33, 0.28, 0.45)
	var oscuro := Color(0.2, 0.16, 0.3)
	var oro: Color = (L.gold as Color).lightened(0.1)
	var ms := {}
	var mg := {}
	var y := Y0
	_caja(ms, 4, y, 1, 10, y + 2, 9, oscuro.darkened(0.2))   # zócalo
	_caja(ms, 4, y + 2, 1, 9, y + 8, 9, cuerpo)   # gabinete de abajo
	_caja(ms, 4, y + 2, 1, 9, y + 3, 2, oscuro)   # sombra de los costados
	_caja(ms, 4, y + 2, 8, 9, y + 3, 9, oscuro)
	_caja(ms, 9, y + 7, 1, 10, y + 8, 9, oscuro)   # el borde del panel de mando
	for k in 3:
		_luz(mg, 9, y + 8, 3 + k * 2, BOTONES[k])   # tres botones
	_caja(ms, 9, y + 3, 3, 10, y + 5, 7, Color(0.08, 0.07, 0.12))   # la bandeja de las monedas
	_luz(mg, 9, y + 3, 4, oro)
	_luz(mg, 9, y + 3, 6, oro)
	_caja(ms, 4, y + 8, 1, 9, y + 14, 9, cuerpo.lightened(0.05))   # gabinete de arriba con la ventana de los rodillos
	for yy in range(y + 9, y + 13):   # la ventana: marco dorado y tres rodillos al fondo
		for z in range(2, 8):
			ms.erase(Vector3i(8, yy, z))
	for z in range(2, 8):
		_luz(mg, 8, y + 9, z, oro.darkened(0.2))
		_luz(mg, 8, y + 12, z, oro.darkened(0.2))
	for k in 3:
		_caja(mg, 7, y + 10, 2 + k * 2, 8, y + 12, 4 + k * 2, BOTONES[k])
	_caja(ms, 4, y + 14, 1, 8, y + 17, 9, oro.darkened(0.25))   # el cartel de arriba
	for z in [2, 4, 6, 8]:
		_luz(mg, 8, y + 15, z, Color(1.0, 0.9, 0.55))   # las bombitas
	_caja(mg, 5, y + 17, 3, 7, y + 19, 7, L.gold)   # la lámpara
	_luz(mg, 6, y + 19, 5, Color(1.0, 0.95, 0.7))
	_caja(ms, 6, y + 5, 9, 7, y + 10, 10, Color(0.7, 0.7, 0.75))   # la palanca
	_caja(ms, 5, y + 10, 9, 8, y + 12, 10, Color(0.82, 0.1, 0.12))
	for q: Vector3i in ms:
		var w := Vector3i(q.z, q.y, q.x) if norte else q
		solid[Vector3i(celda.x * CELDA + w.x, w.y, celda.y * CELDA + w.z)] = ms[q]
	for q: Vector3i in mg:
		var w2 := Vector3i(q.z, q.y, q.x) if norte else q
		glow[Vector3i(celda.x * CELDA + w2.x, w2.y, celda.y * CELDA + w2.z)] = mg[q]


# --- la mesa de cartas --------------------------------------------------------------------------------------------------

static func _mesa_de_cartas(solid: Dictionary, glow: Dictionary, ct: Rect2i, L: Dictionary) -> void:
	var madera: Color = L.wood
	var oro: Color = L.gold
	var cx: float = ct.position.x * CELDA + ct.size.x * CELDA / 2.0
	var cz: float = ct.position.y * CELDA + ct.size.y * CELDA / 2.0
	var y := Y0
	_disco(solid, cx, cz, y, y + 1, 5.0, madera.darkened(0.35))   # base
	_disco(solid, cx, cz, y + 1, y + 2, 4.0, madera.darkened(0.3))
	_disco(solid, cx, cz, y + 2, y + 8, 2.2, madera.darkened(0.15))   # pie
	_disco(solid, cx, cz, y + 7, y + 8, 3.0, oro.darkened(0.2))
	_disco(solid, cx, cz, y + 8, y + 10, 9.6, madera)   # tablero
	_disco(solid, cx, cz, y + 10, y + 12, 9.6, madera.lightened(0.12), 8.4)   # borde acolchado
	_disco(solid, cx, cz, y + 10, y + 11, 8.4, L.felt)   # paño
	_disco(solid, cx, cz, y + 10, y + 11, 6.6, oro, 5.8)   # el arco de apuestas, dorado
	for k in 3:   # cartas
		var kx := int(cx) - 5 + k * 3
		_caja(solid, kx, y + 11, int(cz) - 3, kx + 2, y + 12, int(cz), CREMA.lightened(0.5))
		solid[Vector3i(kx, y + 11, int(cz) - 2)] = ROJO if k != 1 else Color(0.1, 0.1, 0.12)
	_caja(solid, int(cx) + 3, y + 11, int(cz) + 3, int(cx) + 5, y + 14, int(cz) + 5, ROJO)   # fichas
	_caja(solid, int(cx) + 5, y + 11, int(cz) + 2, int(cx) + 7, y + 13, int(cz) + 4, AZUL)
	_luz(glow, int(cx) + 3, y + 14, int(cz) + 3, oro.lightened(0.3))
	_caja(solid, int(cx) + 3, y + 11, int(cz) - 7, int(cx) + 7, y + 13, int(cz) - 4, Color(0.1, 0.09, 0.12))   # la caja de cartas del crupier
	_caja(solid, int(cx) + 4, y + 13, int(cz) - 6, int(cx) + 6, y + 14, int(cz) - 5, CREMA.lightened(0.5))


# --- el taller ----------------------------------------------------------------------------------------------------------

## Una fragua de verdad contra la pared oeste: un cuerpo de chimenea de ladrillo que ocupa toda la celda y sube hasta el techo, con la boca del horno encendida (el piso de enfrente se ilumina), el yunque sobre un tocón con
## una pieza al rojo y chispas, un balde con agua y las herramientas colgadas sobre la boca.
static func _taller(solid: Dictionary, glow: Dictionary, st: Dictionary, tier: int) -> void:
	var ox: int = st.cell.x * CELDA
	var oz: int = st.cell.y * CELDA
	var y := Y0
	var techo := 2 * (14 if tier < 3 else 20) - 2
	var ladrillo := Color(0.42, 0.22, 0.2)
	for yy in range(y, techo):   # el cuerpo de la chimenea, con hiladas de ladrillo (se angosta arriba)
		var fondo := 7 if yy < y + 10 else 6
		for z in range(oz, oz + CELDA):
			for x in range(ox + 4, ox + fondo):
				_caja(solid, x, yy, z, x + 1, yy + 1, z + 1, ladrillo.darkened(0.14) if (yy + (z + x) / 3) % 2 == 0 else ladrillo)
	_caja(solid, ox + 4, y + 9, oz, ox + 8, y + 10, oz + CELDA, Color(0.3, 0.3, 0.34))   # la repisa de piedra
	for yy in range(y + 1, y + 7):   # la boca del horno: un hueco hondo con brasas y llamas
		for z in range(oz + 4, oz + 9):
			for x in range(ox + 4, ox + 7):
				solid.erase(Vector3i(x, yy, z))
			var llama := Color(1.0, 0.8, 0.3) if (yy + z) % 3 == 0 else (Color(1.0, 0.55, 0.12) if (yy + z) % 3 == 1 else Color(0.95, 0.35, 0.08))
			if yy < y + 4 or (z + yy) % 2 == 0:
				_luz(glow, ox + 4, yy, z, llama)
	for z in range(oz + 4, oz + 9):
		_caja(solid, ox + 4, y, z, ox + 7, y + 1, z + 1, Color(0.18, 0.16, 0.18))   # el piso del horno
		_luz(glow, ox + 5, y + 1, z, Color(1.0, 0.45, 0.1))
	_caja(solid, ox + 6, y + 7, oz + 3, ox + 7, y + 8, oz + 10, Color(0.2, 0.18, 0.2))   # el dintel de hierro
	for z in range(oz + 4, oz + 9):   # la luz del fuego sobre el piso de enfrente
		for x in range(ox + 7, ox + 9):
			_luz(glow, x, 3, z, Color(0.62, 0.24, 0.08) if (x + z) % 2 == 0 else Color(0.5, 0.2, 0.07))
	_disco(solid, ox + 8.5, oz + 2.0, y, y + 4, 1.9, Color(0.4, 0.27, 0.15))   # el tocón
	_disco(solid, ox + 8.5, oz + 2.0, y + 3, y + 4, 1.2, Color(0.55, 0.4, 0.24))
	var hierro := Color(0.34, 0.34, 0.38)
	_caja(solid, ox + 7, y + 4, oz, ox + 10, y + 5, oz + 3, hierro.darkened(0.2))   # la base del yunque
	_caja(solid, ox + 8, y + 5, oz + 1, ox + 9, y + 6, oz + 2, hierro.darkened(0.1))   # la cintura
	_caja(solid, ox + 7, y + 6, oz, ox + 10, y + 7, oz + 4, hierro.lightened(0.1))   # la mesa
	_caja(solid, ox + 8, y + 6, oz + 4, ox + 9, y + 7, oz + 5, hierro.lightened(0.1))   # la cuerna, hacia el horno
	for z in range(oz, oz + 3):   # la pieza al rojo
		_luz(glow, ox + 8, y + 7, z, [Color(1.0, 0.5, 0.12), Color(1.0, 0.65, 0.2), Color(1.0, 0.8, 0.35)][z - oz])
	_luz(glow, ox + 7, y + 9, oz + 3, Color(1.0, 0.85, 0.4))   # chispas
	_luz(glow, ox + 9, y + 10, oz + 1, Color(1.0, 0.7, 0.25))
	_luz(glow, ox + 8, y + 12, oz + 2, Color(1.0, 0.85, 0.4))
	_luz(glow, ox + 7, y + 11, oz + 0, Color(1.0, 0.6, 0.2))
	_disco(solid, ox + 9.0, oz + 9.0, y, y + 3, 1.0, Color(0.4, 0.27, 0.15))   # el balde con agua
	_disco(glow, ox + 9.0, oz + 9.0, y + 3, y + 4, 0.7, Color(0.15, 0.35, 0.6))
	_caja(solid, ox + 7, y + 11, oz + 1, ox + 8, y + 12, oz + 9, Color(0.4, 0.27, 0.15))   # el travesaño con las herramientas, sobre la repisa
	_caja(solid, ox + 7, y + 12, oz + 2, ox + 8, y + 17, oz + 3, Color(0.45, 0.3, 0.17))   # el martillo: mango y cabeza
	_caja(solid, ox + 7, y + 17, oz + 1, ox + 8, y + 19, oz + 5, hierro.lightened(0.05))
	_caja(solid, ox + 7, y + 12, oz + 7, ox + 8, y + 18, oz + 8, hierro)   # las tenazas
	_caja(solid, ox + 7, y + 14, oz + 8, ox + 8, y + 18, oz + 9, hierro.darkened(0.1))
	for k in 6:   # una herradura sobre la boca
		var a := PI + k * PI / 5.0
		solid[Vector3i(ox + 7, y + 14 + int(round(2.0 * sin(a) * -1.0)), oz + 5 + int(round(2.5 * cos(a))))] = hierro.lightened(0.15)


# --- obstáculos y faroles -------------------------------------------------------------------------------------------------

static func _obstaculo(solid: Dictionary, glow: Dictionary, o: Vector2i, L: Dictionary, tier: int) -> void:
	var ox: int = o.x * CELDA
	var oz: int = o.y * CELDA
	var y := Y0
	var cx := ox + 5.0
	var cz := oz + 5.0
	match tier:
		0:
			if (o.x + o.y) % 2 == 0:   # un barril: panza, aros, tapa y una canilla
				var madera: Color = (L.wood as Color).lightened(0.05)
				var radios := [2.2, 2.7, 2.7, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 2.7, 2.7, 2.2]
				for i in radios.size():
					var aro := i == 2 or i == 9
					_disco(solid, cx, cz, y + i, y + i + 1, radios[i], (L.wood as Color).darkened(0.4) if aro else (madera if i % 3 != 0 else madera.darkened(0.08)))
				_disco(solid, cx, cz, y + 12, y + 13, 2.2, madera.lightened(0.1))
				_caja(solid, ox + 5, y + 4, oz + 8, ox + 6, y + 5, oz + 9, Color(0.5, 0.45, 0.3))
			else:   # una pila de cajas
				var tabla: Color = (L.plank as Color).lightened(0.05)
				_caja(solid, ox + 1, y, oz + 1, ox + 9, y + 8, oz + 9, tabla)
				for yy in [y + 2, y + 5]:
					_caja(solid, ox + 1, yy, oz + 1, ox + 9, yy + 1, oz + 9, tabla.darkened(0.18))
				for esquina in [[1, 1], [8, 1], [1, 8], [8, 8]]:
					_caja(solid, ox + esquina[0], y, oz + esquina[1], ox + esquina[0] + 1, y + 8, oz + esquina[1] + 1, tabla.darkened(0.35))
				_caja(solid, ox + 3, y + 8, oz + 3, ox + 7, y + 12, oz + 7, tabla.lightened(0.05))
				_caja(solid, ox + 3, y + 10, oz + 3, ox + 7, y + 11, oz + 7, tabla.darkened(0.18))
		1:   # una planta en su maceta
			var piedra: Color = L.stone
			_disco(solid, cx, cz, y, y + 3, 2.6, piedra.darkened(0.15))
			_disco(solid, cx, cz, y + 3, y + 6, 3.2, piedra.darkened(0.05))
			_disco(solid, cx, cz, y + 6, y + 7, 3.6, piedra.lightened(0.1))
			_disco(solid, cx, cz, y + 7, y + 8, 2.8, Color(0.2, 0.12, 0.08))
			_caja(solid, ox + 5, y + 8, oz + 5, ox + 6, y + 13, oz + 6, Color(0.12, 0.35, 0.15))
			_esfera(solid, cx, y + 15.0, cz, 2.8, Color(0.16, 0.5, 0.22))
			_esfera(solid, cx - 2.4, y + 12.0, cz + 1.0, 2.0, Color(0.14, 0.45, 0.2))
			_esfera(solid, cx + 2.4, y + 13.0, cz - 1.2, 2.0, Color(0.2, 0.58, 0.26))
			_esfera(solid, cx + 0.5, y + 12.0, cz + 2.6, 1.6, Color(0.18, 0.52, 0.24))
			for f in [[cx - 1.0, y + 17.0, cz + 2.0], [cx + 2.0, y + 15.0, cz + 2.5], [cx - 3.0, y + 13.0, cz + 2.0]]:   # flores
				solid[Vector3i(int(f[0]), int(f[1]), int(f[2]))] = Color(0.92, 0.35, 0.45)
		_:   # una columna de mármol: base, fuste con estrías, capitel y remate dorado
			var marmol: Color = L.pillar
			var oro: Color = L.gold
			var tope := 2 * 20 - 2 if tier == 3 else 2 * 14 - 2
			_caja(solid, ox + 1, y, oz + 1, ox + 9, y + 2, oz + 9, marmol.darkened(0.06))
			_caja(solid, ox + 2, y + 2, oz + 2, ox + 8, y + 4, oz + 8, marmol)
			_caja(solid, ox + 2, y + 3, oz + 2, ox + 8, y + 4, oz + 8, oro)
			for yy in range(y + 4, tope - 5):
				for x in range(ox + 2, ox + 8):
					for z in range(oz + 2, oz + 8):
						var borde := x == ox + 2 or x == ox + 7 or z == oz + 2 or z == oz + 7
						var esquina := (x == ox + 2 or x == ox + 7) and (z == oz + 2 or z == oz + 7)
						if not borde or esquina:
							continue
						_caja(solid, x, yy, z, x + 1, yy + 1, z + 1, marmol.darkened(0.09) if (x + z) % 2 == 0 else marmol)
				_caja(solid, ox + 3, yy, oz + 3, ox + 7, yy + 1, oz + 7, marmol.darkened(0.04))
			_caja(solid, ox + 2, tope - 5, oz + 2, ox + 8, tope - 4, oz + 8, oro)
			_caja(solid, ox + 1, tope - 4, oz + 1, ox + 9, tope - 2, oz + 9, marmol.lightened(0.03))
			_caja(solid, ox, tope - 2, oz, ox + 10, tope, oz + 10, oro)
			_luz(glow, ox + 4, tope, oz + 4, L.lamp)
			_luz(glow, ox + 5, tope, oz + 5, L.lamp)


static func _farol(solid: Dictionary, glow: Dictionary, celda: Vector2i, L: Dictionary) -> void:
	var cx: int = celda.x * CELDA + 5
	var cz: int = celda.y * CELDA + 5
	var y := Y0
	var oro: Color = (L.gold as Color).darkened(0.3)
	_disco(solid, cx, cz, y, y + 1, 2.6, oro.darkened(0.15))
	_caja(solid, cx - 1, y + 1, cz - 1, cx + 1, y + 14, cz + 1, oro)   # el poste
	_caja(solid, cx - 1, y + 3, cz - 1, cx + 2, y + 4, cz + 2, oro.lightened(0.15))   # collares
	_caja(solid, cx - 1, y + 10, cz - 1, cx + 2, y + 11, cz + 2, oro.lightened(0.15))
	_caja(glow, cx - 2, y + 14, cz - 2, cx + 2, y + 18, cz + 2, L.lamp)   # el vidrio
	for esquina in [[-3, -3], [2, -3], [-3, 2], [2, 2]]:   # el marco
		_caja(solid, cx + esquina[0], y + 14, cz + esquina[1], cx + esquina[0] + 1, y + 18, cz + esquina[1] + 1, oro.lightened(0.1))
	_caja(solid, cx - 3, y + 13, cz - 3, cx + 3, y + 14, cz + 3, oro)
	_caja(solid, cx - 3, y + 18, cz - 3, cx + 3, y + 19, cz + 3, oro)
	_caja(solid, cx - 2, y + 19, cz - 2, cx + 2, y + 20, cz + 2, oro.lightened(0.1))
	_caja(solid, cx - 1, y + 20, cz - 1, cx + 1, y + 21, cz + 1, oro.lightened(0.2))
