extends RefCounted
## Salas del Glaciar (prototipo de generación): en vez de buscar escaleras, se arman al azar mesetas y terrazas de hielo con distintos tipos de desafío y después se
## las resuelve con el A* exacto (ver tests/probe_hielo_plano.gd). El piso de la arena también es de hielo (`floor = "i"`). Todas terminan en el pilar de siempre.
##
## Familias (cada una pide algo distinto al jugador):
##  - meseta:    una meseta de hielo con topes pesados o comunes para frenar (lo básico: resbalar bien).
##  - billar:    los topes son bloques de hielo que se empujan y se deslizan: hay que fabricarse el tope.
##  - pinchos:   algunas casillas de la meseta tienen pinchos: ningún resbalón puede terminar ahí.
##  - agrietado: casillas agrietadas, de un solo uso: frenan un resbalón y después se rompen.
##  - terrazas:  mesetas a distintas alturas: un resbalón frena en el escalón y hay que trepar para seguir; resbalar para el lado equivocado baja de nivel.
##  - carriles:  senderos angostos de hielo con el piso (también de hielo) más abajo: un error te deja en el nivel de abajo, resbalando.

const RoomLib := preload("res://scripts/room_lib.gd")

const FAMILIES: Array[String] = ["meseta", "billar", "pinchos", "agrietado", "terrazas", "carriles"]
const NAMES := {"meseta": "Meseta con topes", "billar": "Billar de hielo", "pinchos": "Pinchos en la pista", "agrietado": "Pasos agrietados", "terrazas": "Terrazas", "carriles": "Carriles"}


## Las alturas que admite cada familia.
static func heights_for(family: String) -> Array:
	return [5, 6] if family == "terrazas" else [4, 5, 6]


static func random_room(rng: RandomNumberGenerator, shape: String, h: int, family: String) -> Dictionary:
	var room := RoomLib.make_room(shape, h)
	room["floor"] = "i"
	room.note = str(NAMES.get(family, family))
	var entry: Vector2i = room.entry
	var exit: Vector2i = room.exit
	var cells: Array = room.cells
	var cols := {}
	var plateau := "i".repeat(maxi(h - 2, 1))
	var lane := {}
	if family == "carriles":
		lane = _lanes(rng, cells, entry, exit)
	var maxd := 1
	for c in cells:
		maxd = maxi(maxd, absi(c.x - exit.x) + absi(c.y - exit.y))
	for c in cells:
		if c == exit:
			continue
		var d := Vector2(c - entry).length()
		if d < 1.5:
			continue
		var near_exit: bool = absi(c.x - exit.x) + absi(c.y - exit.y) == 1
		var r := rng.randf()
		match family:
			"terrazas":
				var level := 1
				if d >= 2.5:
					var along := 1.0 - float(absi(c.x - exit.x) + absi(c.y - exit.y)) / float(maxd)
					level = clampi(1 + int(round(along * float(h - 2) + rng.randf_range(-0.9, 0.6))), 1, h - 1)
				if near_exit:
					level = h - 1
				cols[c] = "i".repeat(level)
			"carriles":
				if d < 2.5:
					cols[c] = "i"
				elif lane.has(c):
					cols[c] = plateau + ("h" if near_exit or r < 0.15 else "")
				# fuera del sendero: sin columna (se baja al piso de hielo)
			_:
				if d < 2.5:
					cols[c] = "i"   # la rampa: un escalón de hielo
					continue
				cols[c] = _plateau_cell(rng, family, plateau, r, near_exit)
	room["cols"] = cols
	return room


static func _plateau_cell(rng: RandomNumberGenerator, family: String, plateau: String, r: float, near_exit: bool) -> String:
	var stop := 0.6 if near_exit else 0.0   # (junto al pilar suele haber un tope donde terminar)
	match family:
		"billar":
			if r < 0.08:
				return ""
			elif r < 0.30 + stop:
				return plateau + "i"   # un bloque de hielo suelto arriba: se empuja y se desliza
			elif r < 0.40 + stop:
				return plateau + "h"
			return plateau
		"pinchos":
			if r < 0.06:
				return ""
			elif r < 0.18:
				return plateau.substr(1) + "s" if plateau.length() > 1 else "s"   # el escalón de la meseta con pinchos arriba
			elif r < 0.40 + stop:
				return plateau + "h"
			elif r < 0.48 + stop:
				return plateau + "n"
			return plateau
		"agrietado":
			if r < 0.06:
				return ""
			elif r < 0.21:
				return plateau.substr(1) + "c" if plateau.length() > 1 else "c"
			elif r < 0.45 + stop:
				return plateau + "h"
			elif r < 0.50 + stop:
				return plateau + "n"
			return plateau
		_:   # meseta
			if r < 0.10:
				return ""
			elif r < 0.30 + stop:
				return plateau + "h"
			elif r < 0.42 + stop:
				return plateau + "n"
			return plateau


## Senderos de la arena: de la rampa hacia el pilar, avanzando casi siempre hacia él y a veces de costado.
static func _lanes(rng: RandomNumberGenerator, cells: Array, entry: Vector2i, exit: Vector2i) -> Dictionary:
	var inside := {}
	for c in cells:
		inside[c] = true
	var lane := {}
	var starts: Array = []
	for c in cells:
		var d := Vector2(c - entry).length()
		if d >= 1.5 and d < 2.5:
			starts.append(c)
	if starts.is_empty():
		return lane
	for _k in rng.randi_range(2, 3):
		var cur: Vector2i = starts[rng.randi_range(0, starts.size() - 1)]
		for _step in 14:
			lane[cur] = true
			if absi(cur.x - exit.x) + absi(cur.y - exit.y) <= 1:
				break
			var options: Array = []
			for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = cur + dv
				if inside.has(n) and n != exit:
					var closer: bool = absi(n.x - exit.x) + absi(n.y - exit.y) < absi(cur.x - exit.x) + absi(cur.y - exit.y)
					options.append([n, 3 if closer else 1])
			if options.is_empty():
				break
			var total := 0
			for o in options:
				total += int(o[1])
			var pick := rng.randi_range(1, total)
			for o in options:
				pick -= int(o[1])
				if pick <= 0:
					cur = o[0]
					break
	return lane
