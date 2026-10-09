extends RefCounted
## El laboratorio (SOLO modo dev): una "estación" armada a mano por cada bloque o mecánica, para probar cada comportamiento sin recorrer
## torres. Se entra con el comando `lab` de la consola (`lab 4`, `lab catapulta`); `labs` las lista. Se carga UNA estación a la vez (las
## bombas cuentan en todo el mundo cuando estás a su altura: con varias estaciones juntas se pisarían). La tecla R reinicia la estación
## (gratis). No hay meta: se juega y se mira qué pasa.
## Una estación mide 10 de ancho (X0..X0+9) y 5 de fondo (z 2..6) sobre un piso en y = 0; se arranca en (X0+1, 1, 4).

const TowerLogic := preload("res://scripts/tower_logic.gd")
const K := TowerLogic.Kind

const X0 := 2
const ZC := 4

## {id, name, desc}: lo que se prueba en cada estación (el cartel 3D la muestra).
const STATIONS: Array[Dictionary] = [
	{"id": "comun", "name": "Común", "desc": "Shift+dir empuja el bloque del frente; Shift+dir contraria tira. Las filas de 2 y 3 se empujan juntas; la de 4 no entra. Escalera al fondo."},
	{"id": "hielo", "name": "Hielo", "desc": "El carril de hielo te hace resbalar hasta el vacío. Empujá el hielo suelto (resbala hasta chocar). Hielo pegado a un normal: se empuja en fila, sin resbalar."},
	{"id": "bomba", "name": "Bomba", "desc": "Cuenta cada movimiento a su altura. La cercana tiene 3 (justo: dos pasos y subirte; perder uno la hace explotar). La del fondo tiene 8. Con `spawn bomba 2` ponés una que no llegás a desactivar."},
	{"id": "catapulta", "name": "Catapulta", "desc": "Pisá la catapulta de cada carril. Paredes de 5, 7 y 10 de alto: el borde está al alcance, una celda más arriba, o fuera de alcance (caés)."},
	{"id": "agrietado", "name": "Agrietado", "desc": "El puente de agrietados se rompe apenas te bajás de cada uno: no hay vuelta atrás. Otro agrietado suelto en el piso."},
	{"id": "pesado", "name": "Pesado", "desc": "No se empuja ni se tira (se trepa). Probalo con `perk fuerza_bruta`. Un pilar de dos de alto no se trepa; la fila pesada tampoco se empuja."},
	{"id": "trampa", "name": "Trampa", "desc": "Dos carriles sobre el vacío: el de la cruz roja cede al pisarlo (caés con él); el otro es seguro. Otra trampa en el piso de adelante."},
	{"id": "pinchos", "name": "Pinchos", "desc": "Subirte a los pinchos pierde. Se empujan como un bloque común: la fila [normal + pinchos] se mueve junta. Pinchos al nivel del piso al fondo."},
	{"id": "fila", "name": "Fila de bloques", "desc": "Corredor angosto con un hueco: la fila de 2 se empuja entera hasta taparlo. Los muros pesados no dejan esquivarla."},
	{"id": "colgarse", "name": "Colgarse", "desc": "Torre de 3 de alto para trepar; arriba, Espacio+dirección te cuelga del borde y soltarte (dirección contraria) te baja. Repisa suelta sobre el vacío."},
	{"id": "fijo", "name": "Bloque fijo (core)", "desc": "Los bloques fijos no se empujan ni se tiran ni caen (como el core de las torres). Columna y fila fijas para probarlo."},
	{"id": "combos", "name": "Combinaciones", "desc": "Hielo que termina en pinchos; fila que se empuja sobre una trampa; bomba al final de un carril de hielo; catapulta junto a pinchos."},
]


static func count() -> int:
	return STATIONS.size()


static func station_x(_i := 0) -> int:
	return X0


## Dónde arranca el jugador en la estación `i`.
static func station_start(_i := 0) -> Vector3i:
	return Vector3i(X0 + 1, 1, ZC)


## Índice de una estación a partir de un número (1..n) o de su id; -1 si no existe.
static func index_of(arg: String) -> int:
	if arg.is_valid_int():
		var n := int(arg) - 1
		return n if n >= 0 and n < count() else -1
	for i in count():
		if STATIONS[i].id == arg.to_lower():
			return i
	return -1


## El cartel 3D de la estación `i`: {pos, text}.
static func sign_for(i: int) -> Dictionary:
	return {"pos": Vector3(X0 + 4.5, 2.9, 0.6), "text": "%d. %s
%s" % [i + 1, STATIONS[i].name.to_upper(), _wrap(str(STATIONS[i].desc), 46)]}


static func _wrap(text: String, width: int) -> String:
	var lines: Array[String] = []
	var cur := ""
	for w in text.split(" "):
		if cur != "" and cur.length() + w.length() + 1 > width:
			lines.append(cur)
			cur = w
		else:
			cur = w if cur == "" else cur + " " + w
	if cur != "":
		lines.append(cur)
	return "\n".join(lines)


## Arma el mundo con la estación `i` (sin caída de la fila de abajo y sin meta).
static func build(i: int) -> RefCounted:
	var t := TowerLogic.new()
	t.size = Vector2i(X0 + 12, 9)
	t.collapse_every = 100000
	t.moves_to_collapse = 100000
	t.goal_y = 90
	t.goal_cell = Vector3i(0, 90, 0)
	var x0 := X0
	match str(STATIONS[i].id):
		"comun": _comun(t, x0)
		"hielo": _hielo(t, x0)
		"bomba": _bomba(t, x0)
		"catapulta": _catapulta(t, x0)
		"agrietado": _agrietado(t, x0)
		"pesado": _pesado(t, x0)
		"trampa": _trampa(t, x0)
		"pinchos": _pinchos(t, x0)
		"fila": _fila(t, x0)
		"colgarse": _colgarse(t, x0)
		"fijo": _fijo(t, x0)
		"combos": _combos(t, x0)
	t.removed_ids.clear()   # (reemplazar bloques deja anotados los viejos como "caídos": no hay nada que animar)
	t.player = station_start(i)
	t.last_safe = t.player
	return t


# --- ayudas ---------------------------------------------------------------------------------------------------------------

## Piso (y = 0) de dx0 a dx1 y de z0 a z1.
static func _floor(t, x0: int, dx0: int, dx1: int, z0 := 2, z1 := 6, kind: int = K.NORMAL) -> void:
	for dx in range(dx0, dx1 + 1):
		for z in range(z0, z1 + 1):
			t.add_block(Vector3i(x0 + dx, 0, z), false, kind)


static func _b(t, x0: int, dx: int, y: int, z: int, kind: int = K.NORMAL, timer := 0, fixed := false) -> void:
	t.add_block(Vector3i(x0 + dx, y, z), fixed, kind, timer)


## Cambia el bloque de la celda `c` por uno de otro tipo (se saca bien el viejo: la lógica lleva la cuenta de cada bloque).
static func _replace(t, c: Vector3i, kind: int, timer := 0) -> void:
	if t.blocks.has(c):
		t._remove_block(c)
	t.add_block(c, false, kind, timer)


## Piso con un hueco: se llena todo menos las celdas (dx, z) de `holes`.
static func _floor_except(t, x0: int, dx0: int, dx1: int, holes: Array, z0 := 2, z1 := 6) -> void:
	for dx in range(dx0, dx1 + 1):
		for z in range(z0, z1 + 1):
			if not holes.has(Vector2i(dx, z)):
				t.add_block(Vector3i(x0 + dx, 0, z), false)


# --- las estaciones ---------------------------------------------------------------------------------------------------------

static func _comun(t, x0: int) -> void:
	_floor(t, x0, 0, 9)
	_b(t, x0, 3, 1, 4)                       # un bloque suelto para empujar y tirar
	for dx in [5, 6, 7]:
		_b(t, x0, dx, 1, 2)                  # fila de 3 (entra)
	for dx in [3, 4, 5, 6]:
		_b(t, x0, dx, 1, 6)                  # fila de 4 (no entra)
	_b(t, x0, 8, 1, 4)                       # escalera
	_b(t, x0, 9, 1, 4)
	_b(t, x0, 9, 2, 4)


static func _hielo(t, x0: int) -> void:
	_floor_except(t, x0, 0, 9, [Vector2i(9, 4)])      # el carril z = 4 termina en el vacío
	for dx in range(2, 9):
		_replace(t, Vector3i(x0 + dx, 0, 4), K.ICE)
	_b(t, x0, 3, 1, 2, K.ICE)                         # hielo suelto
	_b(t, x0, 6, 1, 6, K.ICE)                         # hielo pegado a un normal
	_b(t, x0, 7, 1, 6)


static func _bomba(t, x0: int) -> void:
	_floor(t, x0, 0, 9)
	_b(t, x0, 4, 1, 4, K.BOMB, 3)    # justo
	_b(t, x0, 8, 1, 2, K.BOMB, 8)    # con margen


static func _catapulta(t, x0: int) -> void:
	_floor(t, x0, 0, 9)
	for lane in [[2, 5], [4, 7], [6, 10]]:   # [z, alto de la pared]
		_replace(t, Vector3i(x0 + 2, 0, lane[0]), K.CATAPULT)
		for y in range(1, lane[1] + 1):
			_b(t, x0, 3, y, lane[0])


static func _agrietado(t, x0: int) -> void:
	_floor(t, x0, 0, 2)
	_floor(t, x0, 6, 9)
	for dx in [3, 4, 5]:
		_b(t, x0, dx, 0, 4, K.CRACKED)
	_b(t, x0, 7, 1, 2, K.CRACKED)


static func _pesado(t, x0: int) -> void:
	_floor(t, x0, 0, 9)
	_b(t, x0, 3, 1, 4, K.HEAVY)
	_b(t, x0, 5, 1, 4, K.HEAVY)
	_b(t, x0, 5, 2, 4, K.HEAVY)
	_b(t, x0, 7, 1, 3, K.HEAVY)
	_b(t, x0, 7, 1, 4, K.HEAVY)
	_b(t, x0, 2, 1, 6)                   # un normal, para comparar


static func _trampa(t, x0: int) -> void:
	_floor(t, x0, 0, 1)
	_floor(t, x0, 8, 9)
	for dx in range(2, 8):
		_b(t, x0, dx, 0, 3)               # carril seguro
		_b(t, x0, dx, 0, 4, K.TRAP if dx == 4 else K.NORMAL)   # carril con una trampa
	_replace(t, Vector3i(x0 + 9, 0, 6), K.TRAP)


static func _pinchos(t, x0: int) -> void:
	_floor(t, x0, 0, 9)
	_b(t, x0, 5, 1, 4, K.SPIKES)
	_b(t, x0, 4, 1, 4)                    # [normal, pinchos]
	_b(t, x0, 7, 1, 2, K.SPIKES)
	_replace(t, Vector3i(x0 + 9, 0, 6), K.SPIKES)


static func _fila(t, x0: int) -> void:
	for dx in 10:
		if dx != 5:
			_floor(t, x0, dx, dx)
	for y in [1, 2]:
		for dx in range(1, 5):
			_b(t, x0, dx, y, 3, K.HEAVY)
			_b(t, x0, dx, y, 5, K.HEAVY)
	_b(t, x0, 3, 1, 4)
	_b(t, x0, 4, 1, 4)


static func _colgarse(t, x0: int) -> void:
	_floor_except(t, x0, 0, 9, [Vector2i(9, 3), Vector2i(9, 4), Vector2i(9, 5)])
	_b(t, x0, 3, 1, 4)                    # escalera hasta la plataforma
	_b(t, x0, 4, 1, 4)
	_b(t, x0, 4, 2, 4)
	for dx in range(5, 8):
		for z in range(3, 6):
			for y in range(1, 4):
				_b(t, x0, dx, y, z)


static func _fijo(t, x0: int) -> void:
	_floor(t, x0, 0, 9)
	for y in range(1, 5):
		_b(t, x0, 4, y, 4, K.NORMAL, 0, true)
	for z in range(3, 6):
		_b(t, x0, 6, 1, z, K.NORMAL, 0, true)


static func _combos(t, x0: int) -> void:
	_floor(t, x0, 0, 9)
	for dx in range(1, 7):                               # hielo que termina en pinchos
		_replace(t, Vector3i(x0 + dx, 0, 2), K.ICE)
	_b(t, x0, 7, 1, 2, K.SPIKES)
	_b(t, x0, 3, 1, 4)                                   # fila que se empuja sobre una trampa
	_b(t, x0, 4, 1, 4)
	_replace(t, Vector3i(x0 + 6, 0, 4), K.TRAP)
	for dx in range(1, 8):                               # carril de hielo con una bomba al final
		_replace(t, Vector3i(x0 + dx, 0, 6), K.ICE)
	_b(t, x0, 8, 1, 6, K.BOMB, 5)
	_replace(t, Vector3i(x0 + 9, 0, 3), K.CATAPULT)
	_b(t, x0, 9, 1, 2, K.SPIKES)
