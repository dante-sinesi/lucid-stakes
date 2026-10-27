extends RefCounted
## Las paredes del fondo (oeste y norte) del casino con el doble de resolución (`CasinoRoom.build_detalle`): el material de cada nivel con su relieve (tablas con vetas y ranuras, ladrillos con mezcla, paneles con
## molduras, bloques de mármol con juntas), las cornisas, las puertas con su marco y todo lo que se cuelga (chimenea, cartel, estante, cuadros, apliques y pilastras). Cada pared mide 4 minibloques finos de
## grosor (d = 0..3, el 3 es la cara que mira a la sala); lo que sobresale ocupa d = 4 en adelante y solo donde no hay un mueble (`libre`). La pared oeste corre por z y la norte, por x: `_p` pone cada minibloque
## en su lugar. Las posiciones de las puertas y de las decoraciones vienen de `CasinoRoom.paredes` (en minibloques del modelo base: acá se duplican).

const CELDA := 10
const Y0 := 4      # el primer minibloque sobre el piso
const GROSOR := 4


## Devuelve {west: {solid, glow}, north: {solid, glow}}. `deco`: lo que devuelve `CasinoRoom.paredes`; `alto`: la altura de las paredes del nivel en minibloques del modelo base.
static func armar(lay: Dictionary, L: Dictionary, deco: Dictionary, alto: int, cor: float) -> Dictionary:
	var out := {}
	for lado in ["west", "north"]:
		var oeste: bool = lado == "west"
		var solid := {}
		var glow := {}
		var pared: Dictionary = deco["oeste" if oeste else "norte"]
		var libre := _libres(pared.muebles)
		var largo: int = (lay.cells.y if oeste else lay.cells.x) * CELDA
		_superficie(solid, oeste, largo, 2 * alto, int(lay.tier), L, libre)
		if cor > 0.0:
			_suciedad(solid, cor)
		var puerta: int = (lay.entry.y if oeste else lay.exit.x) * CELDA
		_puerta(solid, glow, oeste, puerta, 2 * alto, int(lay.tier), L)
		for d in pared.decor:
			_decorar(solid, glow, oeste, d, 2 * alto, int(lay.tier), L)
		for p in glow:   # lo que brilla prevalece: un minibloque no puede ser a la vez sólido y luminoso
			solid.erase(p)
		out[lado] = {"solid": solid, "glow": glow}
	return out


# --- auxiliares -------------------------------------------------------------------------------------------------------

static func _ruido(x: int, y: int, z: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (z * 83492791)
	return float(absi(h) % 1000) / 1000.0


static func _tono(c: Color, n: float, cantidad: float) -> Color:
	var k := (n - 0.5) * cantidad
	return Color(clampf(c.r + k, 0.0, 1.0), clampf(c.g + k, 0.0, 1.0), clampf(c.b + k, 0.0, 1.0))


static func _p(map: Dictionary, oeste: bool, u: int, y: int, d: int, color: Color) -> void:
	map[Vector3i(d, y, u) if oeste else Vector3i(u, y, d)] = color


## Una caja en el sistema de la pared: u0..u1 a lo largo, y0..y1 de alto y d0..d1 de hondo (máximos exclusivos).
static func _caja(map: Dictionary, oeste: bool, u0: int, u1: int, y0: int, y1: int, d0: int, d1: int, color: Color) -> void:
	for u in range(u0, u1):
		for y in range(y0, y1):
			for d in range(d0, d1):
				_p(map, oeste, u, y, d, _tono(color, _ruido(u, y, d), 0.02))


## Los minibloques de la pared donde no hay un mueble ni una puerta (ahí sí se puede sobresalir).
static func _libres(muebles: Array) -> Dictionary:
	var ocupado := {}
	for m in muebles:
		for u in range(int(m[0]) * 2, int(m[1]) * 2):
			ocupado[u] = true
	return {"ocupado": ocupado}


static func _es_libre(libre: Dictionary, u: int) -> bool:
	return not libre.ocupado.has(u)


# --- la superficie de cada nivel ----------------------------------------------------------------------------------------

static func _superficie(wall: Dictionary, oeste: bool, largo: int, alto: int, tier: int, L: Dictionary, libre: Dictionary) -> void:
	var desde := 0 if oeste else 4   # la pared norte arranca después del grosor de la oeste
	for u in range(desde, largo):
		var sobresale := _es_libre(libre, u)
		for y in range(Y0, alto):
			var c = _color(u, y, alto, tier, L, sobresale)
			if c == null:
				continue
			var hondo: int = c[1]   # cuántas capas llena (3 = a ras de la pared; 2 = una ranura; 5 = sobresale)
			for d in range(0, hondo):
				_p(wall, oeste, u, y, d, c[0])
		if sobresale:
			_relieve(wall, oeste, u, alto, tier, L)


## {color, capas} del minibloque de la pared en (u, y), o null si falta. `capas` 3: ranura (a ras queda hueca la cara), 4: a ras, 5: sobresale.
static func _color(u: int, y: int, alto: int, tier: int, L: Dictionary, sobresale: bool):
	var n := _ruido(u, y, 9)
	var c: Color
	match tier:
		0:   # tablas verticales de 4, con vetas, el borde de arriba irregular y una viga
			var tabla := u / 4
			if y >= alto - 4 and _ruido(tabla, 3, 5) < 0.3 + 0.08 * float(y - (alto - 4)):
				return null
			c = (L.plank as Color).darkened(0.1 + 0.22 * _ruido(tabla, 1, 1))
			c = _tono(c, _ruido(u, y / 3, 4), 0.06)
			if y >= 12 and y < 16:
				c = (L.wood as Color).darkened(0.15)
				if u % 8 == 2 and y == 14:
					c = (L.gold as Color).darkened(0.2)   # un clavo
				return [_tono(c, n, 0.04), 5 if sobresale else 4]
			return [c, 3 if u % 4 == 0 else 4]
		1:   # zócalo de tablas, ladrillo con mezcla y una cornisa de madera
			if y < 14:
				c = _tono((L.plank as Color).darkened(0.15), _ruido(u, y / 4, 6), 0.05)
				return [c, 3 if u % 4 == 0 else 4]
			if y < 16:
				return [(L.wood as Color).lightened(0.05), 5 if sobresale else 4]
			if y >= alto - 3:
				return [L.wood, 5 if sobresale else 4]
			var hilada := (y - 16) / 3
			var corrido := (hilada % 2) * 4
			var ladrillo := (u + corrido) / 8
			c = _tono(L.stone, _ruido(ladrillo, hilada, 8), 0.07).darkened(0.12)
			if (u + corrido) % 8 == 0 or (y - 16) % 3 == 2:
				return [(L.stone as Color).darkened(0.42), 3]   # la mezcla, hundida
			return [c, 4]
		2:   # paneles oscuros con zócalo, un pasamanos y una cornisa dorada
			if y >= alto - 2:
				return [L.gold, 5 if sobresale else 4]
			if y >= alto - 5:
				return [(L.wall as Color).lightened(0.06), 4]
			if y < 18:
				var uu := u % 14
				var panel := uu >= 2 and uu < 12 and y >= 7 and y < 16
				var marco := (uu == 2 or uu == 11 or y == 7 or y == 15) and panel
				c = L.wall_dark
				if marco:
					return [c.darkened(0.25), 3]
				return [c.lightened(0.05) if panel else c, 4]
			if y < 20:
				return [L.gold, 5 if sobresale else 4]
			c = L.wall
			if (u / 3) % 5 == 0:
				c = c.darkened(0.03)
			return [_tono(c, n, 0.02), 4]
		_:   # mármol: zócalo, banda dorada, bloques con juntas, friso y una cornisa de escalones
			if y >= alto - 2:
				return [L.gold, 5 if sobresale else 4]
			if y >= alto - 8:
				if y == alto - 7:
					return [L.gold, 4]   # un filete dorado
				return [(L.wall as Color).lightened(0.05), 4]
			if y < 14:
				c = (L.wall_dark as Color).lerp(L.wall, 0.4)
				if (u % 12) == 0 or y == 13:
					return [c.darkened(0.2), 3]
				return [_tono(c, n, 0.03), 4]
			if y < 16:
				return [L.gold, 5 if sobresale else 4]
			var hilada := (y - 16) / 6
			var corrido := (hilada % 2) * 7
			var bloque := (u + corrido) / 14
			c = _tono(L.wall, _ruido(bloque, hilada, 3), 0.05)
			if (u + y * 2) % 17 == 0 and n < 0.6:
				c = (L.wall as Color).lightened(0.07)   # una veta
			if (u + corrido) % 14 == 0 or (y - 16) % 6 == 5:
				return [(L.wall as Color).darkened(0.2), 3]
			return [c, 4]


## Lo que sobresale de los materiales (cornisa, pasamanos, vigas): una capa más afuera, solo donde no hay un mueble.
static func _relieve(wall: Dictionary, oeste: bool, u: int, alto: int, tier: int, L: Dictionary) -> void:
	for y in range(Y0, alto):
		var c = _color(u, y, alto, tier, L, true)
		if c == null or int(c[1]) != 5:
			continue
		if tier >= 2 and y >= alto - 2:
			_p(wall, oeste, u, y, 5, (c[0] as Color).darkened(0.08))   # el último escalón de la cornisa
		if tier == 3 and y >= alto - 4 and y < alto - 2:
			_p(wall, oeste, u, y, 5, (c[0] as Color).lightened(0.04))


# --- puertas -----------------------------------------------------------------------------------------------------------

## El vano de 10 de ancho y 20 de alto (el portal de ondas lo llena un shader), con su marco: jambas con base y capitel, dintel con moldura y una piedra clave con una gema que brilla, y un umbral.
static func _puerta(wall: Dictionary, glow: Dictionary, oeste: bool, u0: int, alto: int, tier: int, L: Dictionary) -> void:
	var oro: Color = L.gold
	for u in range(u0, u0 + CELDA):   # el vano
		for y in range(Y0, Y0 + 20):
			for d in range(0, GROSOR):
				wall.erase(Vector3i(d, y, u) if oeste else Vector3i(u, y, d))
	for lado in [[u0 - 2, u0], [u0 + CELDA, u0 + CELDA + 2]]:   # las jambas
		_caja(wall, oeste, lado[0], lado[1], Y0, alto, 0, 6, oro.darkened(0.1))
		_caja(wall, oeste, lado[0] - 1 if lado[0] < u0 else lado[0], lado[1] if lado[0] < u0 else lado[1] + 1, Y0, Y0 + 3, 0, 7, oro.lightened(0.05))   # la base, más ancha
		_caja(wall, oeste, lado[0] - 1 if lado[0] < u0 else lado[0], lado[1] if lado[0] < u0 else lado[1] + 1, Y0 + 17, Y0 + 20, 0, 7, oro.lightened(0.08))   # el capitel
		for y in [Y0 + 6, Y0 + 10, Y0 + 14]:   # las gemas de la jamba
			var u: int = lado[0] if lado[0] < u0 else lado[1] - 1
			_p(glow, oeste, u, y, 6, oro.lightened(0.35))
			wall.erase(Vector3i(6, y, u) if oeste else Vector3i(u, y, 6))
	_caja(wall, oeste, u0 - 2, u0 + CELDA + 2, Y0 + 20, Y0 + 24, 0, 6, oro.darkened(0.05))   # el dintel
	_caja(wall, oeste, u0 - 3, u0 + CELDA + 3, Y0 + 23, Y0 + 24, 0, 7, oro.lightened(0.1))   # su moldura
	_caja(wall, oeste, u0 + 3, u0 + 7, Y0 + 19, Y0 + 24, 0, 7, oro.lightened(0.12))   # la piedra clave
	for u in [u0 + 4, u0 + 5]:
		_p(glow, oeste, u, Y0 + 21, 7, L.lamp)
		wall.erase(Vector3i(7, Y0 + 21, u) if oeste else Vector3i(u, Y0 + 21, 7))
	_caja(wall, oeste, u0, u0 + CELDA, Y0, Y0 + 1, 0, 4, (L.stone as Color).lightened(0.1))   # el umbral


# --- lo que se cuelga ---------------------------------------------------------------------------------------------------

static func _decorar(wall: Dictionary, glow: Dictionary, oeste: bool, d: Dictionary, alto: int, tier: int, L: Dictionary) -> void:
	var a: int = int(d.desde) * 2
	var b: int = int(d.hasta) * 2
	match str(d.tipo):
		"chimenea":
			var piedra: Color = (L.stone as Color).darkened(0.1)
			for u in range(a, b):   # el cuerpo de ladrillo
				for y in range(Y0, Y0 + 18):
					var hilada := (y - Y0) / 3
					var corrido := (hilada % 2) * 4
					var junta := (u + corrido) % 8 == 0 or (y - Y0) % 3 == 2
					for dd in range(4, 8):
						_p(wall, oeste, u, y, dd, piedra.darkened(0.25) if junta else _tono(piedra, _ruido((u + corrido) / 8, hilada, 2), 0.07))
			for u in range(a + 4, b - 4):   # la boca, hueca y con hollín
				for y in range(Y0, Y0 + 11):
					for dd in range(4, 8):
						wall.erase(Vector3i(dd, y, u) if oeste else Vector3i(u, y, dd))
					_p(wall, oeste, u, y, 4, Color(0.05, 0.03, 0.03))
			for u in range(a + 4, b - 4):   # las brasas y las llamas
				_p(glow, oeste, u, Y0, 5, Color(1.0, 0.45, 0.12))
				_p(glow, oeste, u, Y0 + 1, 5, Color(1.0, 0.6, 0.18) if u % 2 == 0 else Color(1.0, 0.45, 0.12))
				if (u - a) % 3 != 0:
					_p(glow, oeste, u, Y0 + 2, 5, Color(1.0, 0.75, 0.3))
				if (u - a) % 4 == 1:
					_p(glow, oeste, u, Y0 + 3, 5, Color(1.0, 0.85, 0.4))
			_caja(wall, oeste, a - 1, b + 1, Y0 + 18, Y0 + 20, 3, 9, (L.wood as Color).lightened(0.05))   # la repisa
			_caja(wall, oeste, a + 6, b - 6, Y0 + 20, alto - 2, 4, 6, piedra.darkened(0.15))   # el cañón hacia el techo
		"cartel":   # un cartel torcido con su letrero luminoso, colgado de dos cadenas
			var mad: Color = (L.wood as Color).lightened(0.1)
			_caja(wall, oeste, a, b, Y0 + 12, Y0 + 20, 4, 6, mad)
			_caja(wall, oeste, a + 1, b - 1, Y0 + 13, Y0 + 19, 4, 5, mad.darkened(0.2))
			var medio := (a + b) / 2
			_caja(glow, oeste, a + 2, medio, Y0 + 14, Y0 + 18, 5, 6, L.lamp)
			_caja(glow, oeste, medio, b - 2, Y0 + 13, Y0 + 17, 5, 6, L.lamp)   # (la mitad de la derecha, un minibloque más abajo: torcido)
			for u in [a + 1, b - 2]:
				_caja(wall, oeste, u, u + 1, Y0 + 20, Y0 + 24, 4, 5, Color(0.2, 0.18, 0.2))
		"estante":   # dos estantes: botellas abajo, libros arriba
			var mad: Color = (L.wood as Color).lightened(0.05)
			for nivel in [[Y0 + 10, 0], [Y0 + 18, 1]]:
				var ys: int = nivel[0]
				_caja(wall, oeste, a, b, ys, ys + 2, 4, 9, mad)
				for u in range(a + 1, b - 1, 4):
					_caja(wall, oeste, u, u + 1, ys - 2, ys, 4, 7, mad.darkened(0.2))   # las ménsulas
				var u := a + 2
				var k := 0
				while u < b - 3:
					if nivel[1] == 0:   # una botella: panza, cuello y corcho
						var col := [Color(0.2, 0.45, 0.3), Color(0.6, 0.2, 0.25), Color(0.65, 0.45, 0.15)][k % 3] as Color
						_caja(wall, oeste, u, u + 2, ys + 2, ys + 6, 5, 7, col)
						_caja(wall, oeste, u, u + 1, ys + 6, ys + 8, 5, 6, col.lightened(0.1))
						_caja(wall, oeste, u, u + 1, ys + 8, ys + 9, 5, 6, Color(0.75, 0.6, 0.4))
						u += 4
					else:   # un libro: lomo de color y altura distinta
						var h := 5 + (k * 7) % 3
						var col2 := [Color(0.5, 0.15, 0.18), Color(0.2, 0.3, 0.5), Color(0.55, 0.45, 0.2), Color(0.25, 0.4, 0.3)][k % 4] as Color
						_caja(wall, oeste, u, u + 2, ys + 2, ys + 2 + h, 5, 8, col2)
						_caja(wall, oeste, u, u + 2, ys + 2 + h - 1, ys + 2 + h, 5, 8, col2.lightened(0.15))
						u += 2
					k += 1
		"cuadro":   # el marco dorado con moldura y un lienzo con su luna
			var y0 := 12 if tier == 2 else 14
			var y1 := 22 if tier == 2 else 30
			_caja(wall, oeste, a, b, y0, y0 + 2, 4, 6, L.gold)   # el marco: cuatro tiras
			_caja(wall, oeste, a, b, y1 - 2, y1, 4, 6, L.gold)
			_caja(wall, oeste, a, a + 2, y0 + 2, y1 - 2, 4, 6, L.gold)
			_caja(wall, oeste, b - 2, b, y0 + 2, y1 - 2, 4, 6, L.gold)
			_caja(wall, oeste, a + 2, b - 2, y0 + 2, y0 + 3, 4, 5, (L.gold as Color).darkened(0.35))   # el borde de adentro, más hondo
			_caja(wall, oeste, a + 2, b - 2, y1 - 3, y1 - 2, 4, 5, (L.gold as Color).darkened(0.35))
			_caja(wall, oeste, a + 2, a + 3, y0 + 3, y1 - 3, 4, 5, (L.gold as Color).darkened(0.35))
			_caja(wall, oeste, b - 3, b - 2, y0 + 3, y1 - 3, 4, 5, (L.gold as Color).darkened(0.35))
			var base := Color(0.12, 0.10, 0.30) if int(d.indice) % 2 == 0 else Color(0.30, 0.10, 0.34)
			var luna_u := a + (b - a) * 3 / 4
			var luna_y := y1 - 5
			for u in range(a + 3, b - 3):
				for y in range(y0 + 3, y1 - 3):
					var t := float(y - y0) / float(y1 - y0)
					var c := base.lerp(base.lightened(0.25), 1.0 - t)
					if absf(float(u - luna_u)) + absf(float(y - luna_y)) <= 2.0:
						c = Color(0.95, 0.9, 0.7)
					_p(wall, oeste, u, y, 4, c)
		"aplique":   # una chapa dorada con una llama de vidrio
			var y0 := 18 if tier < 3 else 24
			_caja(wall, oeste, a, a + 2, y0, y0 + 4, 4, 5, (L.gold as Color).darkened(0.2))
			_caja(wall, oeste, a, a + 2, y0 + 1, y0 + 3, 5, 6, (L.gold as Color).darkened(0.1))
			_caja(glow, oeste, a, a + 2, y0 + 3, y0 + 6, 5, 7, L.lamp)
		"pilastra":   # fuste de 4 con acanaladuras, base con escalón y capitel
			var u0 := (int(d.desde) + 1) * 2
			var fuste: Color = L.pillar
			for u in range(u0, u0 + 4):
				for y in range(Y0 + 4, alto - 8):
					var canal := u == u0 + 1 or u == u0 + 2
					for dd in range(4, 6 if canal else 7):
						_p(wall, oeste, u, y, dd, fuste.darkened(0.08) if canal else fuste)
			_caja(wall, oeste, u0 - 1, u0 + 5, Y0, Y0 + 2, 4, 8, (L.gold as Color))
			_caja(wall, oeste, u0, u0 + 4, Y0 + 2, Y0 + 4, 4, 7, fuste.darkened(0.05))
			_caja(wall, oeste, u0, u0 + 4, alto - 8, alto - 6, 4, 7, fuste.darkened(0.05))
			_caja(wall, oeste, u0 - 1, u0 + 5, alto - 6, alto - 4, 4, 8, L.gold)
			if tier == 3:   # el farol arriba de la pilastra
				_caja(glow, oeste, u0, u0 + 4, alto - 4, alto - 2, 4, 6, L.lamp)


## Suciedad de las paredes viejas: faltan trocitos y hay chorreras violetas (más cuanto más temprano), por grupos de 2x2x2 como en el modelo base.
static func _suciedad(wall: Dictionary, cor: float) -> void:
	for pos in wall.keys():
		var h := _ruido(pos.x / 2, pos.y / 2, pos.z / 2)
		if pos.y >= 8 and h < cor * 0.45:
			wall.erase(pos)
		elif h < cor * 0.9 + 0.02 * float(28 - pos.y) * cor:
			wall[pos] = Color(0.20, 0.06, 0.28).lerp(Color(0.34, 0.10, 0.42), _ruido(pos.z, pos.y, pos.x))
