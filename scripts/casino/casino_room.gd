extends RefCounted
## Sala del casino: distribución en celdas (una sola fuente de verdad) y su modelo de minibloques.
##
## La sala crece y se refina con las etapas del run (4 niveles, ver `layout`): una taberna chica y descuidada (etapas 1-6),
## un salón de piedra (4-7), un casino con alfombra, pilastras y más juegos (8-11) y un gran casino de mármol con
## columnas, escalones hasta la mesa de la ruleta y varias mesas (12-15). Cada nivel cambia el tamaño, las paredes, el piso y
## los muebles (no sólo el color): los bloques se van refinando de ladrillo rústico y tablas a mármol pulido.
## Todo está a la escala del personaje (0,7 de alto): una celda son 5 minibloques de 0,2. De la distribución salen a la vez el
## dibujo y las celdas por las que se puede caminar. El casino es una zona segura: no sube el vacío ni hay corrupción
## (la "mugre" violeta es sólo decorado y baja a nada a medida que el run avanza).

const Stages := preload("res://scripts/datos/stages.gd")
const CELL_VOX := 5            # minibloques por celda
const VOXEL := 0.2

# El nivel 3 de la sala (etapas 14 a 20) es la distribución "de siempre"; estas constantes la describen y son la
# distribución por omisión de las funciones de abajo.
const CELLS := Vector2i(11, 9)
const ENTRY := Vector2i(0, 7)                 # donde se aparece al llegar: frente a la puerta de llegada (pared oeste, sólo estética)
const EXIT := Vector2i(7, 0)                  # frente a la puerta de salida (pared norte): empujarla lleva a la torre siguiente
const TABLE := Rect2i(3, 3, 3, 2)             # mesa de la ruleta
const DEALER := Vector2i(4, 2)                # el crupier, detrás de la mesa
const MACHINES: Array[Vector2i] = [Vector2i(0, 2), Vector2i(0, 4), Vector2i(0, 6)]  # tragamonedas (próximamente)
const CARD_TABLE := Rect2i(8, 2, 2, 2)        # mesa de cartas (próximamente)

# Paleta fija (las rueda y las fichas no cambian con la etapa)
const GOLD := Color(0.88, 0.68, 0.26)
const CREAM := Color(1.0, 0.86, 0.5)
const ORANGE := Color(0.95, 0.62, 0.38)
const VIOLET := Color(0.22, 0.07, 0.32)

const WALL_H := [14, 14, 14, 20]              # altura de las paredes por nivel (en minibloques, contando desde el piso)


## Nivel de la sala (0 taberna, 1 salón, 2 casino, 3 gran casino) según la etapa.
static func tier_of(stage: int) -> int:
	return Stages.tier_of(stage)


## Distribución de la sala de una etapa: {tier, cells, entry, exit, table, dealer, machines, card_tables, obstacles, farolin,
## heights, table_h, cam_size}. `farolin` es la celda de Farolín (junto a la puerta de salida, contra su borde izquierdo (x - 1); sólo ocupa lugar si el casino cobra: `farolin_on`). `obstacles` son celdas decorativas que bloquean (barriles, plantas, columnas); `heights` es la
## altura del piso (en minibloques) de las celdas elevadas; `table_h` es la altura a la que está la mesa de la ruleta.
static func layout(stage: int, tier_override := -1) -> Dictionary:
	var machines: Array[Vector2i] = []
	var obstacles: Array[Vector2i] = []
	var heights := {}
	var tier := tier_of(stage) if tier_override < 0 else tier_override
	match tier:
		0:   # taberna: chica, sólo la ruleta y una tragamonedas (y ninguna estación de servicio)
			machines.assign([Vector2i(0, 1)])
			obstacles.assign([Vector2i(0, 0), Vector2i(6, 0), Vector2i(6, 5), Vector2i(0, 2)])
			return {"tier": 0, "cells": Vector2i(7, 6), "entry": Vector2i(0, 4), "exit": Vector2i(5, 0), "table": Rect2i(2, 2, 3, 2),
					"dealer": Vector2i(3, 1), "machines": machines, "card_tables": [] as Array[Rect2i], "obstacles": obstacles, "farolin": Vector2i(4, 0),
					"heights": heights, "table_h": 0, "cam_size": 9.5}
		1:   # salón: más espacio, dos tragamonedas y una mesa de cartas
			machines.assign([Vector2i(0, 1), Vector2i(0, 3)])
			obstacles.assign([Vector2i(8, 0), Vector2i(8, 6)])
			return {"tier": 1, "cells": Vector2i(9, 7), "entry": Vector2i(0, 5), "exit": Vector2i(6, 0), "table": Rect2i(3, 3, 3, 2),
					"dealer": Vector2i(4, 2), "machines": machines, "card_tables": [Rect2i(7, 2, 2, 2)] as Array[Rect2i], "obstacles": obstacles, "station": {"id": "taller", "cell": Vector2i(1, 6)}, "farolin": Vector2i(5, 0),
					"heights": heights, "table_h": 0, "cam_size": 13.0}
		2:   # casino
			machines.assign(MACHINES)
			return {"tier": 2, "cells": CELLS, "entry": ENTRY, "exit": EXIT, "table": TABLE, "dealer": DEALER, "machines": machines,
					"card_tables": [CARD_TABLE] as Array[Rect2i], "obstacles": obstacles, "station": {"id": "caja", "cell": Vector2i(9, 7)}, "farolin": Vector2i(6, 0), "heights": heights, "table_h": 0, "cam_size": 15.0}
		_:   # gran casino: la ruleta está sobre una tarima con dos escalones
			machines.assign([Vector2i(0, 2), Vector2i(0, 4), Vector2i(0, 6)])
			obstacles.assign([Vector2i(2, 2), Vector2i(2, 8), Vector2i(9, 8), Vector2i(11, 1)])   # columnas de mármol
			var table := Rect2i(5, 4, 3, 2)
			for x in range(table.position.x - 2, table.end.x + 2):
				for z in range(table.position.y - 2, table.end.y + 2):
					if table.has_point(Vector2i(x, z)):
						continue
					var dx := maxi(maxi(table.position.x - x, x - (table.end.x - 1)), 0)
					var dz := maxi(maxi(table.position.y - z, z - (table.end.y - 1)), 0)
					heights[Vector2i(x, z)] = 4 if maxi(dx, dz) <= 1 else 2
			return {"tier": 3, "cells": Vector2i(13, 11), "entry": Vector2i(0, 9), "exit": Vector2i(9, 0), "table": table,
					"dealer": Vector2i(6, 3), "machines": machines, "card_tables": [Rect2i(10, 3, 2, 2), Rect2i(10, 6, 2, 2)] as Array[Rect2i],
					"obstacles": obstacles, "farolin": Vector2i(8, 0), "heights": heights, "table_h": 4, "cam_size": 19.0}


## La distribución por omisión (la del nivel 2) para quien no pasa una.
static func _lay(lay: Dictionary) -> Dictionary:
	return lay if not lay.is_empty() else layout(8)


static func in_room(c: Vector2i, lay := {}) -> bool:
	var cells: Vector2i = _lay(lay).cells
	return c.x >= 0 and c.y >= 0 and c.x < cells.x and c.y < cells.y


## Celdas ocupadas por la decoración y las máquinas (no se camina por ahí).
static func blocked_cells(lay := {}) -> Dictionary:
	var l := _lay(lay)
	var out := {l.dealer: true}
	for x in range(l.table.position.x, l.table.end.x):
		for z in range(l.table.position.y, l.table.end.y):
			out[Vector2i(x, z)] = true
	for m in l.machines:
		out[m] = true
	for ct in l.card_tables:
		for x in range(ct.position.x, ct.end.x):
			for z in range(ct.position.y, ct.end.y):
				out[Vector2i(x, z)] = true
	for o in l.obstacles:
		out[o] = true
	if l.has("station"):
		out[l.station.cell] = true
	if l.get("farolin_on", false) and l.has("farolin"):   # Farolín (el peaje) ocupa una celda junto a la puerta de salida
		out[l.farolin] = true
	return out


static func walkable(c: Vector2i, lay := {}) -> bool:
	return in_room(c, lay) and not blocked_cells(lay).has(c)


## Celdas desde las que se puede jugar a la ruleta: las que tocan la mesa (de lado, no en diagonal).
static func roulette_spots(lay := {}) -> Array[Vector2i]:
	var l := _lay(lay)
	var out: Array[Vector2i] = []
	var blocked := blocked_cells(l)
	for x in range(l.table.position.x, l.table.end.x):
		for z in range(l.table.position.y, l.table.end.y):
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, z) + d
				if in_room(n, l) and not blocked.has(n) and not out.has(n):
					out.append(n)
	return out


## Celdas alcanzables caminando desde `from` (de a una, sin diagonales).
static func reachable(from: Vector2i, lay := {}) -> Dictionary:
	var l := _lay(lay)
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if walkable(n, l) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen


## Altura del piso de una celda en minibloques sobre el piso base (0 salvo en las tarimas del gran casino).
static func height_of(c: Vector2i, lay := {}) -> int:
	return int(_lay(lay).heights.get(c, 0))


# --- aspecto según la etapa -------------------------------------------------------------------------------------

## Colores del casino según la etapa (1..15): de un sótano sucio y casi sin luz a un salón de mármol claro.
## `corruption`: fracción de minibloques sucios o rotos (baja a casi nada).
## Para probar paletas (muestras de diseño): si no está vacío, pisa los colores de `look`.
static var palette_override := {}


## Paleta de la sala. La taberna y el salón (niveles 0 y 1) se aclaran de a poco con las etapas; el casino y el gran casino (niveles 2 y 3) tienen una paleta
## propia, de "mármol cálido": claros de valor medio (arena, marfil, pizarra) con contraste, para que los detalles se lean y la sala no se queme.
static func look(stage: int, tier := -1) -> Dictionary:
	var t := Stages.ratio(stage)
	var e := t * t * (3.0 - 2.0 * t)   # suave: los extremos cambian despacio
	var level := tier_of(stage) if tier < 0 else tier
	var base := _base_look(t, e) if level < 2 else _warm_look(level, stage)
	base.merge(palette_override, true)
	return base


## Mármol cálido del casino (nivel 2) y del gran casino (nivel 3). Dentro de cada nivel hay un cambio mínimo de etapa a etapa.
static func _warm_look(level: int, stage: int) -> Dictionary:
	var start := 8 if level == 2 else 12
	var p := clampf(float(stage - start) / 3.0, 0.0, 1.0)
	var k := lerpf(0.96, 1.04, p)
	var d: Dictionary
	if level == 2:
		d = {"floor_a": Color(0.80, 0.72, 0.58), "floor_b": Color(0.42, 0.36, 0.30), "wall": Color(0.70, 0.60, 0.46), "wall_dark": Color(0.52, 0.43, 0.32),
				"gold": Color(0.62, 0.46, 0.19), "wood": Color(0.32, 0.19, 0.11), "plank": Color(0.42, 0.26, 0.15), "stone": Color(0.58, 0.54, 0.48),
				"felt": Color(0.10, 0.36, 0.28), "carpet": Color(0.52, 0.20, 0.20), "lamp": Color(1.0, 0.82, 0.55), "pillar": Color(0.88, 0.82, 0.70)}
	else:
		d = {"floor_a": Color(0.88, 0.82, 0.70), "floor_b": Color(0.36, 0.38, 0.46), "wall": Color(0.76, 0.66, 0.50), "wall_dark": Color(0.58, 0.48, 0.36),
				"gold": Color(0.66, 0.48, 0.19), "wood": Color(0.34, 0.20, 0.12), "plank": Color(0.44, 0.28, 0.17), "stone": Color(0.62, 0.58, 0.52),
				"felt": Color(0.10, 0.40, 0.34), "carpet": Color(0.62, 0.28, 0.22), "lamp": Color(1.0, 0.86, 0.6), "pillar": Color(0.93, 0.88, 0.78)}
	for key in ["floor_a", "floor_b", "wall", "wall_dark", "stone", "pillar"]:
		var c: Color = d[key]
		d[key] = Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0), minf(c.b * k, 1.0))
	d["t"] = Stages.ratio(stage)
	d["corruption"] = 0.0
	return d


static func _base_look(t: float, e: float) -> Dictionary:
	return {
		"t": t,
		"floor_a": Color(0.23, 0.19, 0.19).lerp(Color(0.93, 0.91, 0.87), e),
		"floor_b": Color(0.12, 0.05, 0.09).lerp(Color(0.76, 0.79, 0.88), e),
		"wall": Color(0.14, 0.05, 0.10).lerp(Color(0.89, 0.89, 0.95), e),
		"wall_dark": Color(0.07, 0.03, 0.06).lerp(Color(0.70, 0.73, 0.84), e),
		"gold": Color(0.42, 0.28, 0.13).lerp(Color(1.0, 0.88, 0.52), e),
		"wood": Color(0.24, 0.14, 0.08).lerp(Color(0.46, 0.30, 0.17), e),
		"plank": Color(0.34, 0.21, 0.12).lerp(Color(0.56, 0.40, 0.26), e),
		"stone": Color(0.34, 0.31, 0.33).lerp(Color(0.82, 0.82, 0.87), e),
		"felt": Color(0.05, 0.14, 0.12).lerp(Color(0.14, 0.48, 0.38), e),
		"carpet": Color(0.30, 0.04, 0.07).lerp(Color(0.78, 0.76, 0.90), e),
		"lamp": Color(1.0, 0.52, 0.25).lerp(Color(1.0, 0.95, 0.80), e),
		"pillar": Color(0.17, 0.14, 0.17).lerp(Color(0.97, 0.96, 0.94), e),
		"corruption": 0.13 * pow(1.0 - t, 1.6),
	}


## Color de las puertas según la etapa: cuanto más avanzado el run, más claras. La de salida es algo más clara que la de llegada.
static func portal_color(stage: int, is_exit: bool) -> Color:
	var t := Stages.ratio(stage)
	var c := Color(0.20, 0.08, 0.38).lerp(Color(0.80, 0.88, 1.0), t)
	return c.lerp(Color.WHITE, 0.22) if is_exit else c


# --- modelo de minibloques ----------------------------------------------------------------------------------

static func _box(map: Dictionary, x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, color: Color) -> void:
	for x in range(x0, x1):
		for y in range(y0, y1):
			for z in range(z0, z1):
				map[Vector3i(x, y, z)] = color


static func _noise(x: int, y: int, z: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (z * 83492791)
	return float(absi(h) % 1000) / 1000.0


static func _shade(c: Color, n: float, amount: float) -> Color:
	var k := (n - 0.5) * amount
	return Color(clampf(c.r + k, 0.0, 1.0), clampf(c.g + k, 0.0, 1.0), clampf(c.b + k, 0.0, 1.0))


## Piso: el material se afina con el nivel (tablas manchadas, lajas de piedra, damero y damero de mármol con guardas doradas).
static func _floor(solid: Dictionary, lay: Dictionary, L: Dictionary, cor: float) -> void:
	var W: int = lay.cells.x * CELL_VOX
	var D: int = lay.cells.y * CELL_VOX
	var tier: int = lay.tier
	for x in W:
		for z in D:
			var cell := Vector2i(x / CELL_VOX, z / CELL_VOX)
			var n := _noise(x, 0, z)
			var top: Color
			match tier:
				0:   # tablas de madera a lo largo de x, con juntas oscuras y manchas
					var board := z / 2
					var base: Color = (L.plank as Color).darkened(0.1 + 0.18 * _noise(board, 1, x / 7))
					top = _shade(base, n, 0.10)
					if z % 2 == 0 and _noise(x / 3, 2, board) < 0.5:
						top = top.darkened(0.25)   # junta
					if _noise(x / 4, 7, z / 4) < 0.12:
						top = top.darkened(0.35)   # mancha
				1:   # lajas de piedra de 5 x 5 con juntas
					var slab := (cell.x + cell.y) % 2 == 0
					var base: Color = (L.stone as Color).darkened(0.0 if slab else 0.14)
					top = _shade(base, n, 0.07)
					if x % CELL_VOX == 0 or z % CELL_VOX == 0:
						top = (L.stone as Color).darkened(0.42)
				2:
					var base: Color = L.floor_a if (cell.x + cell.y) % 2 == 0 else L.floor_b
					top = _shade(base, n, 0.05)
				_:   # mármol: damero con vetas y una guarda dorada en el borde de cada celda
					var base: Color = L.floor_a if (cell.x + cell.y) % 2 == 0 else L.floor_b
					top = _shade(base, n, 0.04)
					if (x + 2 * z) % 11 == 0 and _noise(x, 4, z) < 0.5:
						top = top.lightened(0.07)   # veta
					if (x % CELL_VOX == 0 or z % CELL_VOX == 0) and (cell.x + cell.y) % 2 == 0:
						top = top.lerp(L.gold, 0.35)
			solid[Vector3i(x, 0, z)] = top.darkened(0.25)
			solid[Vector3i(x, 1, z)] = top
			if cor > 0.0 and _noise(x, 3, z) < cor * 0.7:   # mugre violeta en el piso
				solid[Vector3i(x, 1, z)] = Color(0.20, 0.06, 0.28).lerp(Color(0.40, 0.12, 0.48), _noise(x, 5, z))


## Una pared del fondo. `west`: la del oeste (corre por z) o la del norte (corre por x). Escribe en `wall`.
## Cada nivel cambia el modelado: tablas rústicas con borde irregular, ladrillo con zócalo de madera, paneles con
## franja dorada, o mármol con cornisa escalonada.
static func _wall(wall: Dictionary, lay: Dictionary, L: Dictionary, west: bool, cor: float) -> void:
	var tier: int = lay.tier
	var H: int = WALL_H[tier]
	var span: int = (lay.cells.y if west else lay.cells.x) * CELL_VOX
	var start := 0 if west else 2   # la pared norte arranca después del grosor de la oeste
	for u in range(start, span):
		for y in range(2, H):
			var n := _noise(u, y, 9)
			var col: Color
			match tier:
				0:   # tablas verticales de 3, borde de arriba irregular, vigas
					if y >= H - 3 and _noise(u / 3, 3, 5) < 0.35 + 0.1 * float(y - (H - 3)):
						continue
					var plank: Color = (L.plank as Color).darkened(0.1 + 0.25 * _noise(u / 3, 1, 1))
					col = _shade(plank, n, 0.08)
					if u % 3 == 0:
						col = col.darkened(0.35)
					if y >= 6 and y < 8:
						col = (L.wood as Color).darkened(0.15)   # viga
				1:   # ladrillo (hiladas de 2, juntas desfasadas) sobre un zócalo de tablas, y una cornisa de madera
					if y < 6:
						col = _shade((L.plank as Color).darkened(0.15), n, 0.08)
						if u % 3 == 0:
							col = col.darkened(0.3)
					elif y >= H - 1:
						col = (L.wood as Color)
					else:
						var row := (y - 6) / 2
						var off := (row % 2) * 3
						col = _shade(L.stone, n, 0.10).darkened(0.12)
						if (u + off) % 6 == 0 or y % 2 == 0:
							col = (L.stone as Color).darkened(0.45)
				2:   # paneles oscuros con zócalo y franja dorada
					col = L.wall
					if y < 4:
						col = L.wall_dark
					if y >= H - 2:
						col = L.gold
				_:   # mármol claro con vetas, zócalo, y cornisa que sobresale de a escalones
					col = _shade(L.wall, n, 0.05)
					if (u + y * 2) % 13 == 0 and n < 0.6:
						col = (L.wall as Color).lightened(0.06)
					if y < 5:
						col = (L.wall_dark as Color).lerp(col, 0.4)
					if y == 5:
						col = L.gold
					if y >= H - 3 and y < H - 1:
						col = (L.wall as Color).lightened(0.05)
					if y == H - 1:
						col = L.gold
			wall[Vector3i(0 if west else u, y, u if west else 0)] = col
	# La pared real tiene 2 minibloques de grosor: se completa el segundo.
	for p in wall.keys():
		var q: Vector3i = p + (Vector3i(1, 0, 0) if west else Vector3i(0, 0, 1))
		wall[q] = wall[p]
	if cor > 0.0:   # suciedad: faltan minibloques sueltos y hay chorreras violetas (más cuanto más temprano)
		for pos in wall.keys():
			var h := _noise(pos.x, pos.y, pos.z)
			if pos.y >= 4 and h < cor * 0.45:
				wall.erase(pos)
			elif h < cor * 0.9 + 0.02 * float(14 - pos.y) * cor:
				wall[pos] = Color(0.20, 0.06, 0.28).lerp(Color(0.34, 0.10, 0.42), _noise(pos.z, pos.y, pos.x))


## Pilastra pegada a la pared: fuste, base y capitel. `west`: pared oeste (el fuste crece hacia +x) o norte (hacia +z).
static func _pilaster(wall: Dictionary, u: int, west: bool, H: int, L: Dictionary, fluted: bool) -> void:
	for w in 2:
		for y in range(2, H - 3):
			var col: Color = (L.pillar as Color).darkened(0.07 if (fluted and w == 0) else 0.0)
			wall[Vector3i(2, y, u + w) if west else Vector3i(u + w, y, 2)] = col
	for w in range(-1, 3):
		for y in [2, H - 4]:   # base y capitel
			wall[Vector3i(2, y, u + w) if west else Vector3i(u + w, y, 2)] = L.gold


static func build_voxels(stage := 8, tier_override := -1) -> Dictionary:
	var lay := layout(stage, tier_override)
	var L := look(stage, int(lay.tier))
	var cor: float = L.corruption
	var tier: int = lay.tier
	var cells: Vector2i = lay.cells
	var solid := {}
	var glow := {}
	# Las paredes del fondo van aparte (oeste y norte) para poder ocultar la que queda entre la cámara y la sala.
	var ww := {}   # pared oeste: sólido
	var gw := {}   # pared oeste: luces
	var wn := {}   # pared norte (y el portal de luz): sólido
	var gn := {}   # pared norte: luces
	var W := cells.x * CELL_VOX
	var D := cells.y * CELL_VOX
	var H: int = WALL_H[tier]

	_floor(solid, lay, L, cor)
	_wall(ww, lay, L, true, cor)
	_wall(wn, lay, L, false, cor)
	# La pared oeste arranca en x = 0 y ocupa 2 de grosor; la norte, desde x = 2 y z = 0..1.
	var door_x: int = lay.exit.x * CELL_VOX       # puerta de salida (pared norte)
	var door_z: int = lay.entry.y * CELL_VOX      # puerta de llegada (pared oeste)

	# Decoración de pared según el nivel.
	match tier:
		0:   # taberna: una chimenea con brasas en la pared norte y un cartel torcido
			_box(wn, 12, 2, 2, 20, 9, 4, (L.stone as Color).darkened(0.1))
			_box(wn, 14, 2, 2, 18, 6, 4, Color(0.05, 0.03, 0.03))
			_box(gn, 14, 2, 3, 18, 3, 4, Color(1.0, 0.45, 0.12))
			_box(gn, 15, 3, 3, 17, 4, 4, Color(1.0, 0.7, 0.25))
			_box(ww, 2, 8, 12, 3, 11, 20, (L.wood as Color).lightened(0.1))
			_box(gw, 2, 9, 15, 3, 10, 17, L.lamp)
		1:   # salón: estantes con botellas y apliques
			for x in [8, 20]:
				if x + 6 < door_x - 2 or x > door_x + CELL_VOX + 1:
					_box(wn, x, 6, 2, x + 8, 7, 3, (L.wood as Color).lightened(0.05))
					for b in 4:
						_box(wn, x + 1 + b * 2, 7, 2, x + 2 + b * 2, 9, 3, Color(0.2, 0.45, 0.3).lerp(Color(0.6, 0.2, 0.25), float(b % 2)))
			for z in [10, 24]:
				_box(gw, 2, 9, z, 3, 11, z + 1, L.lamp)
			for x in [6, 34]:
				if x < door_x - 2 or x > door_x + CELL_VOX + 1:
					_box(gn, x, 9, 2, x + 1, 11, 3, L.lamp)
		2:   # casino: cuadros, apliques y pilastras de mármol que aparecen de a poco
			for r in [[10, 18], [24, 32]]:
				_box(wn, r[0] - 1, 6, 2, r[1] + 1, 11, 3, L.gold)
				_box(wn, r[0], 7, 2, r[1], 10, 3, Color(0.12, 0.10, 0.30) if r[0] == 10 else Color(0.30, 0.10, 0.34))
			_box(ww, 2, 6, 11, 3, 11, 21, L.gold)
			_box(ww, 2, 7, 12, 3, 10, 20, Color(0.10, 0.28, 0.30))
			for z in [8, 22, 36]:
				_box(gw, 2, 9, z, 3, 11, z + 1, L.lamp)
			for x in [8, 22, 46]:
				_box(gn, x, 9, 2, x + 1, 11, 3, L.lamp)
			var late: bool = float(L.t) >= 0.7
			for x in ([20, 44, 50] if late else [20]):
				_pilaster(wn, x, false, H, L, true)
			for z in ([3, 24, 30] if late else [24]):
				_pilaster(ww, z, true, H, L, true)
		_:   # gran casino: pilastras acanaladas cada 10, cuadros grandes y apliques de cristal
			for x in range(14, W - 6, 10):
				if x + 3 < door_x - 1 or x > door_x + CELL_VOX + 1:
					_pilaster(wn, x, false, H, L, true)
			for z in range(8, D - 6, 10):
				if z + 3 < door_z - 1 or z > door_z + CELL_VOX + 1:
					_pilaster(ww, z, true, H, L, true)
			for r in [[24, 36], [52, 62]]:
				if r[1] + 1 < door_x or r[0] - 1 > door_x + CELL_VOX:
					_box(wn, r[0] - 1, 7, 2, r[1] + 1, 15, 3, L.gold)
					_box(wn, r[0], 8, 2, r[1], 14, 3, Color(0.12, 0.10, 0.30) if r[0] == 24 else Color(0.30, 0.10, 0.34))
			_box(ww, 2, 7, 22, 3, 15, 34, L.gold)
			_box(ww, 2, 8, 23, 3, 14, 33, Color(0.10, 0.28, 0.30))
			for x in range(9, W - 6, 10):
				if x < door_x - 2 or x > door_x + CELL_VOX + 1:
					_box(gn, x, 12, 2, x + 1, 14, 3, L.lamp)
			for z in range(3, D - 6, 10):
				if z < door_z - 2 or z > door_z + CELL_VOX + 1:
					_box(gw, 2, 12, z, 3, 14, z + 1, L.lamp)

	# Tarima del gran casino: dos escalones alrededor de la mesa de la ruleta.
	for c in lay.heights:
		var h: int = lay.heights[c]
		var step_col: Color = (L.pillar as Color).lerp(L.gold, 0.18 if h == 2 else 0.05)
		_box(solid, c.x * CELL_VOX, 2, c.y * CELL_VOX, c.x * CELL_VOX + CELL_VOX, 2 + h, c.y * CELL_VOX + CELL_VOX, step_col)
		var outer := false   # el borde de afuera de cada escalón lleva un filete dorado
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if int(lay.heights.get(c + d, 0)) < h and not lay.table.has_point(c + d) and c + d != lay.dealer:
				outer = true
		if outer:
			_box(solid, c.x * CELL_VOX, 2 + h - 1, c.y * CELL_VOX, c.x * CELL_VOX + CELL_VOX, 2 + h, c.y * CELL_VOX + CELL_VOX, L.gold)

	# Alfombra roja frente a la mesa (y, en el gran casino, un camino hasta la puerta de salida).
	var dy: int = lay.table_h
	for cx in range(lay.table.position.x, lay.table.end.x):
		var vx := cx * CELL_VOX
		var vz: int = lay.table.end.y * CELL_VOX
		if tier >= 2:
			_box(solid, vx, 2 + dy, vz, vx + CELL_VOX, 3 + dy, vz + CELL_VOX, L.carpet)
			_box(solid, vx, 2 + dy, vz, vx + CELL_VOX, 3 + dy, vz + 1, L.gold)
	if tier == 3:
		var ex: int = lay.exit.x * CELL_VOX
		for z in range(1 * CELL_VOX, (lay.table.position.y - 2) * CELL_VOX):
			_box(solid, ex + 1, 2, z, ex + CELL_VOX - 1, 3, z + 1, L.carpet)

	# Mesa de la ruleta.
	var tx0: int = lay.table.position.x * CELL_VOX
	var tz0: int = lay.table.position.y * CELL_VOX
	var tx1: int = lay.table.end.x * CELL_VOX
	var tz1: int = lay.table.end.y * CELL_VOX
	var wood: Color = L.wood
	for corner in [[tx0, tz0], [tx1 - 2, tz0], [tx0, tz1 - 2], [tx1 - 2, tz1 - 2]]:
		_box(solid, corner[0], 2 + dy, corner[1], corner[0] + 2, 5 + dy, corner[1] + 2, wood.darkened(0.2))
	_box(solid, tx0, 5 + dy, tz0, tx1, 6 + dy, tz1, wood)
	_box(solid, tx0, 6 + dy, tz0, tx1, 7 + dy, tz1, wood.lightened(0.1))  # borde
	_box(solid, tx0 + 1, 6 + dy, tz0 + 1, tx1 - 1, 7 + dy, tz1 - 1, L.felt)  # paño
	if tier == 3:   # patas talladas y filete dorado en el borde
		_box(solid, tx0, 6 + dy, tz0, tx1, 7 + dy, tz0 + 1, L.gold)
	# Rueda: disco de 13 sectores (el 0, violeta, mira al norte).
	var wcx := tx0 + 5.0
	var wcz := tz0 + 5.0
	for x in range(tx0, tx0 + 11):
		for z in range(tz0, tz0 + 11):
			var dx := x + 0.5 - wcx
			var dz := z + 0.5 - wcz
			var dist := sqrt(dx * dx + dz * dz)
			if dist > 4.6:
				continue
			var ang := fposmod(atan2(dx, -dz), TAU)  # 0 = norte, horario
			var pocket := int(round(ang / (TAU / 13.0))) % 13
			var col := VIOLET if pocket == 0 else (CREAM if pocket % 2 == 1 else ORANGE)
			if dist > 4.0:
				col = wood.darkened(0.1)
			solid[Vector3i(x, 7 + dy, z)] = col
			if dist < 1.8:
				glow[Vector3i(x, 8 + dy, z)] = L.gold
	glow[Vector3i(int(wcx), 8 + dy, int(wcz) - 3)] = Color.WHITE  # la bola
	# Cuadro de apuestas y fichas sobre el paño.
	for i in 3:
		for j in 4:
			var bx := tx0 + 11 + i * 1
			var bz := tz0 + 1 + j * 2
			solid[Vector3i(bx, 7 + dy, bz)] = CREAM if (i + j) % 2 == 0 else L.gold
	for k in 3:
		_box(solid, tx1 - 3, 7 + k + dy, tz0 + 1, tx1 - 2, 8 + k + dy, tz0 + 2, Color(0.8, 0.12, 0.15))
	for k in 2:
		_box(solid, tx1 - 3, 7 + k + dy, tz1 - 3, tx1 - 2, 8 + k + dy, tz1 - 2, Color(0.15, 0.25, 0.8))
	if tier == 0:   # en la taberna, una vela chorreada sobre la mesa
		_box(solid, tx0 + 1, 7, tz1 - 2, tx0 + 2, 9, tz1 - 1, Color(0.9, 0.85, 0.7))
		glow[Vector3i(tx0 + 1, 9, tz1 - 2)] = Color(1.0, 0.7, 0.3)

	# Crupier: de pie detrás de la mesa, mirando al sur.
	var dcx: int = lay.dealer.x * CELL_VOX + 2
	var dcz: int = lay.dealer.y * CELL_VOX + 2
	var ddy: int = int(lay.heights.get(lay.dealer, 0))
	_box(solid, dcx - 1, 2 + ddy, dcz, dcx, 4 + ddy, dcz + 2, Color(0.08, 0.08, 0.1))      # piernas
	_box(solid, dcx + 1, 2 + ddy, dcz, dcx + 2, 4 + ddy, dcz + 2, Color(0.08, 0.08, 0.1))
	_box(solid, dcx - 1, 4 + ddy, dcz, dcx + 2, 7 + ddy, dcz + 2, Color(0.95, 0.95, 0.92))  # camisa
	_box(solid, dcx - 1, 4 + ddy, dcz + 1, dcx + 2, 7 + ddy, dcz + 2, Color(0.50, 0.08, 0.14))  # chaleco
	_box(solid, dcx, 6 + ddy, dcz + 1, dcx + 1, 7 + ddy, dcz + 2, Color(0.9, 0.85, 0.8))
	_box(solid, dcx - 2, 4 + ddy, dcz, dcx - 1, 6 + ddy, dcz + 2, Color(0.95, 0.95, 0.92))  # brazos
	_box(solid, dcx + 2, 4 + ddy, dcz, dcx + 3, 6 + ddy, dcz + 2, Color(0.95, 0.95, 0.92))
	_box(solid, dcx - 2, 4 + ddy, dcz, dcx - 1, 5 + ddy, dcz + 2, Color(0.86, 0.68, 0.55))  # manos
	_box(solid, dcx + 2, 4 + ddy, dcz, dcx + 3, 5 + ddy, dcz + 2, Color(0.86, 0.68, 0.55))
	_box(solid, dcx - 1, 7 + ddy, dcz, dcx + 2, 9 + ddy, dcz + 2, Color(0.86, 0.68, 0.55))  # cabeza
	_box(solid, dcx - 2, 9 + ddy, dcz - 1, dcx + 3, 10 + ddy, dcz + 3, Color(0.06, 0.06, 0.08))  # ala del sombrero
	_box(solid, dcx - 1, 10 + ddy, dcz, dcx + 2, 12 + ddy, dcz + 2, Color(0.06, 0.06, 0.08))   # copa
	_box(solid, dcx - 1, 10 + ddy, dcz, dcx + 2, 11 + ddy, dcz + 2, Color(0.7, 0.1, 0.15))      # cinta
	solid[Vector3i(dcx - 1, 8 + ddy, dcz + 1)] = Color(0.1, 0.1, 0.1)                       # ojos
	solid[Vector3i(dcx + 1, 8 + ddy, dcz + 1)] = Color(0.1, 0.1, 0.1)

	# Tragamonedas: cuerpo, tres ventanitas de rodillo que brillan al frente y una lámpara arriba.
	for m in lay.machines:
		var mx: int = m.x * CELL_VOX + 2
		var mz: int = m.y * CELL_VOX + 1
		var body := Color(0.33, 0.28, 0.45)
		_box(solid, mx, 2, mz, mx + 3, 8, mz + 4, body)
		_box(solid, mx, 8, mz + 1, mx + 3, 9, mz + 3, body)
		_box(solid, mx + 2, 4, mz + 1, mx + 3, 6, mz + 3, Color(0.22, 0.18, 0.32))  # pliegue
		glow[Vector3i(mx + 1, 9, mz + 1)] = L.gold  # lámpara
		glow[Vector3i(mx + 1, 10, mz + 1)] = L.gold
		glow[Vector3i(mx + 3, 5, mz + 1)] = Color(1.0, 0.35, 0.3)    # las tres ventanitas de los rodillos
		glow[Vector3i(mx + 3, 5, mz + 2)] = Color(1.0, 0.85, 0.3)
		glow[Vector3i(mx + 3, 5, mz + 3)] = Color(0.5, 0.8, 1.0)

	# Mesas de cartas: fieltro con unas cartas boca arriba y una pila de fichas.
	for ct in lay.card_tables:
		var ccx: float = ct.position.x * CELL_VOX + ct.size.x * CELL_VOX / 2.0
		var ccz: float = ct.position.y * CELL_VOX + ct.size.y * CELL_VOX / 2.0
		for x in range(int(ccx) - 6, int(ccx) + 6):
			for z in range(int(ccz) - 6, int(ccz) + 6):
				var dist := sqrt(pow(x + 0.5 - ccx, 2) + pow(z + 0.5 - ccz, 2))
				if dist <= 4.8:
					solid[Vector3i(x, 5, z)] = wood
					solid[Vector3i(x, 6, z)] = L.felt if dist < 4.0 else wood.lightened(0.1)
				if dist <= 1.5:
					_box(solid, x, 2, z, x + 1, 5, z + 1, wood.darkened(0.2))
		for k in 3:   # cartas
			var kx: int = int(ccx) - 3 + k * 2
			_box(solid, kx, 7, int(ccz) - 2, kx + 2, 8, int(ccz) + 1, Color(0.96, 0.94, 0.88))
			solid[Vector3i(kx, 8, int(ccz) - 1)] = Color(0.7, 0.12, 0.12)
		glow[Vector3i(int(ccx) + 2, 7, int(ccz) + 2)] = L.gold   # fichas
		glow[Vector3i(int(ccx) + 2, 8, int(ccz) + 2)] = L.gold

	# Estación de servicio del nivel (Taller o Caja fuerte): un mueble con su forma propia.
	if lay.has("station"):
		_station(solid, glow, lay.station, L)

	# Obstáculos decorativos: barriles (taberna), plantas (salón) y columnas de mármol (gran casino).
	for o in lay.obstacles:
		var ox: int = o.x * CELL_VOX
		var oz: int = o.y * CELL_VOX
		match tier:
			0:   # barril o pila de cajas
				if (o.x + o.y) % 2 == 0:
					_box(solid, ox + 1, 2, oz + 1, ox + 4, 8, oz + 4, (L.wood as Color).lightened(0.05))
					_box(solid, ox + 1, 4, oz + 1, ox + 4, 5, oz + 4, (L.wood as Color).darkened(0.3))   # aros
					_box(solid, ox + 1, 6, oz + 1, ox + 4, 7, oz + 4, (L.wood as Color).darkened(0.3))
					_box(solid, ox + 2, 8, oz + 2, ox + 3, 9, oz + 3, (L.wood as Color).darkened(0.1))
				else:
					_box(solid, ox + 1, 2, oz + 1, ox + 4, 5, oz + 4, (L.plank as Color).lightened(0.05))
					_box(solid, ox + 1, 5, oz + 2, ox + 3, 8, oz + 4, (L.plank as Color).darkened(0.1))
			1:   # planta en una maceta de piedra
				_box(solid, ox + 1, 2, oz + 1, ox + 4, 5, oz + 4, (L.stone as Color).darkened(0.1))
				_box(solid, ox + 2, 5, oz + 2, ox + 3, 9, oz + 3, Color(0.15, 0.45, 0.2))
				_box(solid, ox + 1, 7, oz + 1, ox + 4, 9, oz + 4, Color(0.18, 0.55, 0.25))
			_:   # columna de mármol: base, fuste de 2 x 2 con acanaladuras y capitel dorado
				var top := H - 1
				_box(solid, ox + 1, 2, oz + 1, ox + 4, 4, oz + 4, L.pillar)
				_box(solid, ox + 2, 4, oz + 2, ox + 4, top - 2, oz + 4, L.pillar)
				for y in range(4, top - 2):
					solid[Vector3i(ox + 2, y, oz + 2)] = (L.pillar as Color).darkened(0.08)
				_box(solid, ox + 1, top - 2, oz + 1, ox + 5, top, oz + 5, L.gold)
				glow[Vector3i(ox + 2, top, oz + 2)] = L.lamp

	# Portales: el de salida en la pared norte (frente a EXIT) y el de llegada en la pared oeste (frente a ENTRY, sólo estético). Acá van sólo los marcos;
	# el interior, de ondas que se mueven, lo arma casino_scene.gd (shaders/portal.gdshader). Cuanto más avanzado el run, más claros; el de salida es algo más claro.
	_box(wn, door_x - 1, 2, 0, door_x, H, 2, L.gold)
	_box(wn, door_x + CELL_VOX, 2, 0, door_x + CELL_VOX + 1, H, 2, L.gold)
	_box(wn, door_x, 12, 0, door_x + CELL_VOX, H, 2, L.gold)
	_box(ww, 0, 2, door_z - 1, 2, H, door_z, L.gold)
	_box(ww, 0, 2, door_z + CELL_VOX, 2, H, door_z + CELL_VOX + 1, L.gold)
	_box(ww, 0, 12, door_z, 2, H, door_z + CELL_VOX, L.gold)

	# Faroles de pie.
	var lamps: Array = [[3, D - 2], [W - 3, 3]]
	if tier == 0:
		lamps = [[W - 3, D - 3]]
	for pos in lamps:
		_box(solid, pos[0], 2, pos[1], pos[0] + 1, 9, pos[1] + 1, (L.gold as Color).darkened(0.3))
		_box(glow, pos[0] - 1, 9, pos[1] - 1, pos[0] + 2, 11, pos[1] + 2, L.lamp)
	for x in range(door_x, door_x + CELL_VOX):   # los vanos de las puertas quedan abiertos (ahí va el portal de ondas)
		for y in range(2, 12):
			for z in 2:
				wn.erase(Vector3i(x, y, z))
	for z in range(door_z, door_z + CELL_VOX):
		for y in range(2, 12):
			for x in 2:
				ww.erase(Vector3i(x, y, z))
	for p in glow:  # lo que brilla prevalece: un minibloque no puede ser a la vez sólido y luminoso
		solid.erase(p)
		ww.erase(p)
		wn.erase(p)
	for g in [gw, gn]:
		for p in g:
			solid.erase(p)
			ww.erase(p)
			wn.erase(p)
	# "solid" y "glow" traen todo junto; "west" y "north" repiten lo que es de cada pared (para ocultarlas).
	var all_solid := solid.duplicate()
	var all_glow := glow.duplicate()
	all_solid.merge(ww)
	all_solid.merge(wn)
	all_glow.merge(gw)
	all_glow.merge(gn)
	return {"solid": all_solid, "glow": all_glow,
			"west": {"solid": ww, "glow": gw}, "north": {"solid": wn, "glow": gn}}


## El mueble de una estación de servicio, en su celda: yunque del taller o caja fuerte.
static func _station(solid: Dictionary, glow: Dictionary, st: Dictionary, L: Dictionary) -> void:
	var ox: int = st.cell.x * CELL_VOX
	var oz: int = st.cell.y * CELL_VOX
	var wood: Color = L.wood
	match str(st.id):
		"taller":   # yunque con un brasero al lado
			_box(solid, ox + 1, 2, oz + 1, ox + 4, 4, oz + 4, Color(0.22, 0.22, 0.26))
			_box(solid, ox + 2, 4, oz + 2, ox + 3, 6, oz + 3, Color(0.28, 0.28, 0.32))
			_box(solid, ox, 6, oz + 1, ox + 5, 8, oz + 4, Color(0.4, 0.4, 0.45))
			_box(solid, ox - 1, 7, oz + 2, ox, 8, oz + 3, Color(0.4, 0.4, 0.45))   # la punta
			glow[Vector3i(ox + 3, 8, oz + 2)] = Color(1.0, 0.5, 0.15)
			glow[Vector3i(ox + 2, 8, oz + 3)] = Color(1.0, 0.7, 0.25)
		"caja":   # caja fuerte de acero con la puerta al frente y un dial dorado
			_box(solid, ox, 2, oz, ox + 5, 10, oz + 5, Color(0.36, 0.38, 0.42))
			_box(solid, ox + 1, 3, oz + 5, ox + 4, 9, oz + 6, Color(0.28, 0.3, 0.34))
			_box(solid, ox + 4, 5, oz + 5, ox + 5, 7, oz + 6, L.gold)   # manija
			glow[Vector3i(ox + 2, 6, oz + 6)] = L.gold
			glow[Vector3i(ox + 2, 7, oz + 6)] = L.gold


## Posición en el mundo del centro de una celda (a la altura del piso de esa celda).
static func world_of_cell(c: Vector2i, lay := {}) -> Vector3:
	return Vector3((c.x + 0.5) * CELL_VOX * VOXEL, (2 + height_of(c, lay)) * VOXEL, (c.y + 0.5) * CELL_VOX * VOXEL)
