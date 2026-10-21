extends RefCounted
## EXPERIMENTO (aislado del juego): el "cilindro". Una masa de 6x6 bloques de base y altura h con el core de 2x2 en el medio (queda un anillo de espesor 2, como el muro de Catherine enrollado), apoyada en un
## piso de un bloque de espesor que la rodea. El jugador llega por afuera (sobre el piso) y sube moviendo los bloques de la masa; la meta es la cima de un pilar fijo que está en el anillo.
## Se arma como una sala común de la biblioteca (forma "C6", arena de 8x8 menos el core) para usar el mismo simulador, el mismo A* exacto y las mismas métricas.
##
## Variantes de masa (cómo se arman las alturas de las columnas):
##  - muro:   casi todas las columnas llenas (h - 1) con unos pocos huecos: hay que sacar bloques para abrirse paso.
##  - mixto:  columnas llenas con probabilidad `p` y el resto de alturas al azar.
##  - capas:  una cara baja, otras altas: la cara baja es el "camino fácil" y las otras obligan a mover más.

const RoomLib := preload("res://scripts/room_lib.gd")

const IDEAS: Array[String] = ["muro", "mixto", "capas"]
const SIDE := 8   # el piso incluido


static func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in SIDE:
		for z in SIDE:
			if x >= 3 and x <= 4 and z >= 3 and z <= 4:
				continue   # el core
			out.append(Vector2i(x, z))
	return out


## Las columnas de la masa: las celdas de 1 a 6 sin el core.
static func mass_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells():
		if c.x >= 1 and c.x <= 6 and c.y >= 1 and c.y <= 6:
			out.append(c)
	return out


static func make(rng: RandomNumberGenerator, h: int, idea: String) -> Dictionary:
	var room := RoomLib.make_room("3x3", h)   # (se parte de una sala común y se cambia la forma)
	room.shape = "C6"
	room.cells = cells()
	room.entry = Vector2i(-1, 3)
	var mass := mass_cells()
	var ring: Array[Vector2i] = []   # celdas de la masa donde puede estar el pilar de salida: la capa de afuera (no pegadas a la llegada)
	for c in mass:
		if c.x == 1 or c.x == 6 or c.y == 1 or c.y == 6:
			ring.append(c)
	room.exit = ring[rng.randi_range(0, ring.size() - 1)]
	var low_face := rng.randi_range(0, 3)
	var cols := {}
	for c in mass:
		if c == room.exit or (c - room.entry).length() < 1.5:
			continue
		var k := h - 1
		match idea:
			"muro":
				if rng.randf() < 0.12:
					k = rng.randi_range(0, h - 2)
			"mixto":
				if rng.randf() > 0.6:
					k = rng.randi_range(0, h - 2)
			"capas":
				var face := 0 if c.x == 1 else (1 if c.x == 6 else (2 if c.y == 1 else 3))
				if face == low_face:
					k = clampi(h - 1 - (absi(c.x - room.exit.x) + absi(c.y - room.exit.y)) / 2 - rng.randi_range(0, 2), 0, h - 1)
				elif rng.randf() < 0.15:
					k = rng.randi_range(0, h - 2)
		if k > 0:
			cols[c] = "n".repeat(k)
	room["cols"] = cols
	room.origin = "cilindro"
	return room


## Una vista de arriba de las alturas (para mirar la masa de un vistazo).
static func top_view(room: Dictionary) -> String:
	var lines: Array = []
	for z in SIDE:
		var line := ""
		for x in SIDE:
			var c := Vector2i(x, z)
			if x >= 3 and x <= 4 and z >= 3 and z <= 4:
				line += " # "
			elif c == room.exit:
				line += " E "
			elif room.cols.has(c):
				line += " %d " % String(room.cols[c]).length()
			else:
				line += " . "
		lines.append(line)
	return "\n".join(lines)
