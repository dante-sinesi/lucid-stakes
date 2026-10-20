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
## Las ideas nuevas (cada una cambia quién resuelve el acertijo o cómo se mueve el jugador):
##  - patinaje:        una pista angosta de hielo con vacío alrededor (el piso sólo está bajo la pista): se resbala de tope en tope y un resbalón de más es una caída.
##  - billar_precision: el pilar sólo se trepa si un bloque de hielo queda parado en su único lado libre: el acertijo es la trayectoria del bloque.
##  - escalada:        una pared alta de hielo (de la que no se puede colgar) con repisas de hielo duro para agarrarse.
##  - tobogan:         una meseta cortada por un canal: hay que tirarse a propósito al piso de abajo, resbalar por debajo y volver a subir del otro lado.
##  - puente:          un puente elevado de nieve (se rompe al pisarlo), hielo y topes sobre el vacío, entre dos plataformas.
##  - embudo:          terrazas que bajan hacia un pozo en el medio: todo te arrastra hacia abajo y la salida está arriba.
const IDEAS: Array[String] = ["patinaje", "billar_precision", "escalada", "tobogan", "puente", "embudo"]
const IDEA_NAMES := {"patinaje": "Patinaje", "billar_precision": "Billar de precisión", "escalada": "Escalada glaciar", "tobogan": "Tobogán a dos niveles", "puente": "Puente de nieve", "embudo": "Embudo"}
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const NAMES := {"meseta": "Meseta con topes", "billar": "Billar de hielo", "pinchos": "Pinchos en la pista", "agrietado": "Pasos agrietados", "terrazas": "Terrazas", "carriles": "Carriles"}


## Las alturas que admite cada familia.
## Las formas de arena que sirven a cada idea (las de 3 filas no dejan lugar para trazar una pista ni para maniobrar un bloque).
static func shapes_for(family: String) -> Array:
	match family:
		"patinaje":
			return ["L", "U"]
		"billar_precision", "tobogan", "puente":
			return ["3x8", "L", "U"]
	return ["3x5", "3x8", "L", "U", "3x3"]


static func heights_for(family: String) -> Array:
	match family:
		"terrazas":
			return [5, 6]
		"patinaje", "billar_precision":
			return [2]
		"escalada":
			return [6, 7, 8]
		"tobogan":
			return [4, 5]
		"puente", "embudo":
			return [5, 6]
	return [4, 5, 6]


static func random_room(rng: RandomNumberGenerator, shape: String, h: int, family: String) -> Dictionary:
	if IDEAS.has(family):
		var r := {}
		match family:
			"patinaje":
				r = _room_patinaje(rng, shape, h)
			"billar_precision":
				r = _room_billar_precision(rng, shape, h)
			"escalada":
				r = _room_escalada(rng, shape, h)
			"tobogan":
				r = _room_tobogan(rng, shape, h)
			"puente":
				r = _room_puente(rng, shape, h)
			"embudo":
				r = _room_embudo(rng, shape, h)
		if not r.is_empty():
			r["floor"] = "i"
			r.note = str(IDEA_NAMES.get(family, family))
		return r
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


# --- ideas nuevas -------------------------------------------------------------------------------------------------------------------

static func _shuffle(rng: RandomNumberGenerator, a: Array) -> Array:
	var out := a.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out


## Patinaje: una pista de hielo que serpentea (el piso sólo existe bajo la pista, los topes y los callejones sin salida; todo lo demás es vacío). Corridas rectas que terminan contra un tope,
## con giros; hacia el final una casilla de hielo antes del pilar. Un callejón sin salida o un resbalón fuera de la pista es una caída.
static func _room_patinaje(rng: RandomNumberGenerator, shape: String, h: int) -> Dictionary:
	if rng.randf() < 0.55:
		return _patinaje_blob(rng, shape, h)
	for _try in 40:   # (el trazado al azar a veces no cierra: se prueba de nuevo)
		var r := _patinaje_once(rng, shape, h)
		if not r.is_empty():
			return r
	return {}


## La otra forma de patinaje: una mancha de pista que crece desde la llegada (más de la mitad de la arena es vacío) con topes pesados repartidos al azar; el pilar queda en la casilla más lejana.
static func _patinaje_blob(rng: RandomNumberGenerator, shape: String, h: int) -> Dictionary:
	var room := RoomLib.make_room(shape, h)
	var canvas := {}
	for c in room.cells:
		canvas[c] = true
	var entry: Vector2i = room.entry
	var starts: Array = []
	for dv in DIRS:
		if canvas.has(entry + dv):
			starts.append(entry + dv)
	if starts.is_empty():
		return {}
	var start: Vector2i = starts[rng.randi_range(0, starts.size() - 1)]
	var track := {start: 0}
	var order: Array[Vector2i] = [start]
	var want := int(float(canvas.size()) * rng.randf_range(0.40, 0.65))
	var frontier: Array[Vector2i] = [start]
	var guard := 0
	while track.size() < want and not frontier.is_empty() and guard < 400:
		guard += 1
		var cur: Vector2i = frontier[rng.randi_range(0, frontier.size() - 1)]
		var d: Vector2i = DIRS[rng.randi_range(0, 3)]
		var n: Vector2i = cur + d
		if canvas.has(n) and not track.has(n):
			track[n] = int(track[cur]) + 1
			order.append(n)
			frontier.append(n)
	if track.size() < 8:
		return {}
	# el pilar: la casilla más lejana (en pasos de la pista) con un vecino de la pista; el escalón de hielo en ese vecino
	var far: Vector2i = start
	for c in order:
		if int(track[c]) > int(track[far]):
			far = c
	var x: Vector2i = far
	var n_cell := Vector2i(-99, -99)
	for dv in DIRS:
		if track.has(x + dv) and (x + dv) != start:
			n_cell = x + dv
	if n_cell.x < -90:
		return {}
	var cols := {}
	cols[n_cell] = "i"
	for c in track:
		if c == x or c == n_cell or c == start or Vector2(c - entry).length() < 1.5:
			continue
		if rng.randf() < 0.30:
			cols[c] = "h" if rng.randf() < 0.85 else "n"
	var list: Array[Vector2i] = []
	for c in track:
		list.append(c)
	room.cells = list
	room.exit = x
	room.cols = cols
	return room


static func _patinaje_once(rng: RandomNumberGenerator, shape: String, h: int) -> Dictionary:
	var room := RoomLib.make_room(shape, h)
	var canvas := {}
	for c in room.cells:
		canvas[c] = true
	var entry: Vector2i = room.entry
	var starts: Array = []
	for dv in DIRS:
		if canvas.has(entry + dv):
			starts.append(entry + dv)
	if starts.is_empty():
		return {}
	var cur: Vector2i = starts[rng.randi_range(0, starts.size() - 1)]
	var first_dir: Vector2i = cur - entry
	var used := {cur: true}
	var cells := {cur: true}
	var cols := {}
	var prev_dir := first_dir
	var stops: Array = []
	var runs := rng.randi_range(3, 7)
	for r in runs:
		var placed := false
		var opts: Array = _shuffle(rng, DIRS.duplicate())
		for d in opts:
			if d == -prev_dir:
				continue
			var best := 0
			for k in range(1, 6):
				var c: Vector2i = cur + d * k
				var stop: Vector2i = cur + d * (k + 1)
				if not canvas.has(c) or used.has(c):
					break
				if canvas.has(stop) and not used.has(stop):
					best = k
			if best < 1:
				continue
			var l := rng.randi_range(1, best)
			for k in range(1, l + 1):
				cells[cur + d * k] = true
				used[cur + d * k] = true
			var st: Vector2i = cur + d * (l + 1)
			cells[st] = true
			used[st] = true
			cols[st] = "h" if rng.randf() < 0.85 else "n"
			cur = cur + d * l
			prev_dir = d
			stops.append(cur)
			placed = true
			break
		if not placed:
			break
	if stops.size() < 2:
		return {}
	# el final: una casilla de hielo (un escalón) y el pilar en línea
	var finished := false
	for d in _shuffle(rng, DIRS.duplicate()):
		var n: Vector2i = cur + d
		var x: Vector2i = n + d
		if d == -prev_dir or not canvas.has(n) or not canvas.has(x) or used.has(n) or used.has(x):
			continue
		cols[n] = "i"
		cells[n] = true
		cells[x] = true
		room.exit = x
		finished = true
		break
	if not finished:
		return {}
	# callejones sin salida: una casilla al costado de un punto donde se frena, con su tope
	for _k in rng.randi_range(0, 2):
		var base: Vector2i = stops[rng.randi_range(0, stops.size() - 1)]
		for d in _shuffle(rng, DIRS.duplicate()):
			var a: Vector2i = base + d
			var b: Vector2i = a + d
			if canvas.has(a) and canvas.has(b) and not used.has(a) and not used.has(b) and a != room.exit and b != room.exit:
				cells[a] = true
				cells[b] = true
				used[a] = true
				used[b] = true
				cols[b] = "h"
				break
	var list: Array[Vector2i] = []
	for c in cells:
		list.append(c)
	room.cells = list
	room.cols = cols
	return room


## Billar de precisión: el pilar tiene un solo lado libre; hay que dejar un bloque de hielo parado ahí (se desliza hasta chocar) para poder trepar. Topes pesados repartidos por la arena.
static func _room_billar_precision(rng: RandomNumberGenerator, shape: String, h: int) -> Dictionary:
	var room := RoomLib.make_room(shape, h)
	var x: Vector2i = room.exit
	var entry: Vector2i = room.entry
	var inside := {}
	for c in room.cells:
		inside[c] = true
	var free_sides: Array = []
	for dv in DIRS:
		if inside.has(x + dv):
			free_sides.append(x + dv)
	if free_sides.is_empty():
		return {}
	var f: Vector2i = free_sides[rng.randi_range(0, free_sides.size() - 1)]
	for n in free_sides:
		if n != f:
			inside.erase(n)   # sin piso: no se puede estar ahí
	var cells: Array[Vector2i] = []
	for c in inside:
		cells.append(c)
	var cols := {}
	var spots: Array = []
	for c in cells:
		if c != x and c != f and Vector2(c - entry).length() >= 1.5:
			spots.append(c)
	spots = _shuffle(rng, spots)
	var ice_n := rng.randi_range(1, 2)
	var stop_n := rng.randi_range(3, 8)
	var i := 0
	for _k in ice_n:
		if i < spots.size():
			cols[spots[i]] = "i"
			i += 1
	for _k in stop_n:
		if i < spots.size():
			cols[spots[i]] = "h" if rng.randf() < 0.8 else "n"
			i += 1
	room.cells = cells
	room.cols = cols
	return room


## Escalada glaciar: una pared de hielo cada vez más alta hacia el pilar, con repisas de hielo duro (pesado) para agarrarse y algún bloque suelto.
static func _room_escalada(rng: RandomNumberGenerator, shape: String, h: int) -> Dictionary:
	var room := RoomLib.make_room(shape, h)
	var entry: Vector2i = room.entry
	var x: Vector2i = room.exit
	var maxd := 1
	for c in room.cells:
		maxd = maxi(maxd, absi(c.x - x.x) + absi(c.y - x.y))
	var cols := {}
	for c in room.cells:
		if c == x:
			continue
		var d := Vector2(c - entry).length()
		if d < 1.5:
			continue
		var near_exit: bool = absi(c.x - x.x) + absi(c.y - x.y) == 1
		var along := 1.0 - float(absi(c.x - x.x) + absi(c.y - x.y)) / float(maxd)
		var level := clampi(1 + int(round(along * float(h - 2) + rng.randf_range(-1.6, 1.0))), 1, h - 1)
		if d < 2.5:
			level = 1
		if near_exit:
			level = h - 1
		var col := "i".repeat(level)
		var r := rng.randf()
		if level >= 3 and r < 0.30:
			col = "i".repeat(level - 1) + "h"   # una repisa de hielo duro arriba
		elif level >= 2 and r < 0.38:
			col = "i".repeat(level - 1) + "n"
		cols[c] = col
	room.cols = cols
	return room


## Tobogán: una meseta cortada por un canal (sin columnas: el piso de hielo queda abajo) que separa la llegada del pilar; hay que tirarse al canal, resbalar por abajo y volver a subir por una
## rampa del otro lado.
static func _room_tobogan(rng: RandomNumberGenerator, shape: String, h: int) -> Dictionary:
	var room := RoomLib.make_room(shape, h)
	var entry: Vector2i = room.entry
	var x: Vector2i = room.exit
	var plateau_h := maxi(h - 2, 1)
	var plateau := "i".repeat(plateau_h)
	var maxd := 1
	for c in room.cells:
		maxd = maxi(maxd, absi(c.x - x.x) + absi(c.y - x.y))
	var dc := rng.randi_range(maxi(int(float(maxd) * 0.40), 3), maxi(int(float(maxd) * 0.65), 4))
	var width := rng.randi_range(1, 2)
	var cols := {}
	for c in room.cells:
		if c == x:
			continue
		var d := Vector2(c - entry).length()
		if d < 1.5:
			continue
		var dist := absi(c.x - x.x) + absi(c.y - x.y)
		if dist >= dc and dist < dc + width:
			continue   # el canal
		if d < 2.5:
			cols[c] = "i"
			continue
		var r := rng.randf()
		if dist < dc:   # del lado del pilar: una rampa que sube desde el canal hasta la meseta
			var level := mini(plateau_h, 1 + (dc - 1 - dist))
			var col := "i".repeat(level)
			if dist == 1 or (level == plateau_h and r < 0.25):
				col = "i".repeat(plateau_h) + "h"
			cols[c] = col
		else:   # del lado de la llegada: la meseta, con algún tope
			var col2 := plateau
			if r < 0.15:
				col2 = plateau + "h"
			elif r < 0.20:
				col2 = plateau + "i"
			elif r < 0.26:
				col2 = ""
			if col2 != "":
				cols[c] = col2
	room.cols = cols
	return room


## Puente de nieve: dos plataformas de hielo (la de la llegada y la del pilar) unidas por senderos elevados con huecos debajo: nieve que se rompe, hielo que resbala y topes. Los senderos
## son continuos (si no, los bloques sueltos no se sostienen).
static func _room_puente(rng: RandomNumberGenerator, shape: String, h: int) -> Dictionary:
	var room := RoomLib.make_room(shape, h)
	var entry: Vector2i = room.entry
	var x: Vector2i = room.exit
	var bridge_y := maxi(h - 3, 2)   # altura del puente (en bloques): sus columnas llevan huecos debajo
	var cells_set := {}
	for c in room.cells:
		cells_set[c] = true
	var total := 0.0
	for c in room.cells:
		total = maxf(total, Vector2(c - entry).length())
	var cols := {}
	var start_plat: Array[Vector2i] = []
	var end_plat: Array[Vector2i] = []
	for c in room.cells:
		if c == x:
			continue
		var d := Vector2(c - entry).length()
		if d < 1.5:
			continue
		var near_exit: bool = absi(c.x - x.x) + absi(c.y - x.y) == 1
		if near_exit:
			cols[c] = "i".repeat(h - 1)
			end_plat.append(c)
			continue
		if d < 2.5:
			cols[c] = "i"
			continue
		if d / total < 0.34:
			cols[c] = "i".repeat(bridge_y)
			start_plat.append(c)
		elif absi(c.x - x.x) + absi(c.y - x.y) <= 2:
			cols[c] = "i".repeat(bridge_y)
			end_plat.append(c)
	if start_plat.is_empty() or end_plat.is_empty():
		return {}
	# senderos: de una casilla de la plataforma de la llegada hacia el pilar, casi siempre acercándose
	var bridge := {}
	for _k in rng.randi_range(1, 3):
		var cur: Vector2i = start_plat[rng.randi_range(0, start_plat.size() - 1)]
		for _step in 20:
			var options: Array = []
			for dv in DIRS:
				var n: Vector2i = cur + dv
				if cells_set.has(n) and n != x and (not cols.has(n) or bridge.has(n) or end_plat.has(n)):
					var closer: bool = absi(n.x - x.x) + absi(n.y - x.y) < absi(cur.x - x.x) + absi(cur.y - x.y)
					options.append([n, 3 if closer else 1])
			if options.is_empty():
				break
			var tot := 0
			for o in options:
				tot += int(o[1])
			var pick := rng.randi_range(1, tot)
			for o in options:
				pick -= int(o[1])
				if pick <= 0:
					cur = o[0]
					break
			if end_plat.has(cur):
				break   # llegó a la plataforma del pilar
			bridge[cur] = true
	for c in bridge:
		var r := rng.randf()
		var top := "c"
		if r > 0.55:
			top = "i"
		if r > 0.78:
			top = "h"
		cols[c] = ".".repeat(bridge_y - 1) + top
	room.cols = cols
	return room


## Embudo: terrazas que suben hacia el pilar, con un pozo en el medio: todo resbala hacia abajo y hay que salir trepando.
static func _room_embudo(rng: RandomNumberGenerator, shape: String, h: int) -> Dictionary:
	var room := RoomLib.make_room(shape, h)
	var entry: Vector2i = room.entry
	var x: Vector2i = room.exit
	var maxd := 1
	var cx := 0.0
	var cz := 0.0
	for c in room.cells:
		maxd = maxi(maxd, absi(c.x - x.x) + absi(c.y - x.y))
		cx += c.x
		cz += c.y
	cx /= float(room.cells.size())
	cz /= float(room.cells.size())
	var pit := Vector2i(roundi(cx + rng.randf_range(-1.0, 1.0)), roundi(cz + rng.randf_range(-0.6, 0.6)))
	var radius := rng.randi_range(1, 2)
	var cols := {}
	for c in room.cells:
		if c == x:
			continue
		var d := Vector2(c - entry).length()
		if d < 1.5:
			continue
		var near_exit: bool = absi(c.x - x.x) + absi(c.y - x.y) == 1
		var along := 1.0 - float(absi(c.x - x.x) + absi(c.y - x.y)) / float(maxd)
		var level := clampi(1 + int(round(along * float(h - 2) + rng.randf_range(-0.7, 0.7))), 1, h - 1)
		if d < 2.5:
			level = 1
		if near_exit:
			level = h - 1
		elif maxi(absi(c.x - pit.x), absi(c.y - pit.y)) < radius:
			level = maxi(level - 2, 0)   # el pozo
		if level > 0:
			var col := "i".repeat(level)
			if level >= 2 and not near_exit and rng.randf() < 0.1:
				col = "i".repeat(level - 1) + "h"
			cols[c] = col
	room.cols = cols
	return room
