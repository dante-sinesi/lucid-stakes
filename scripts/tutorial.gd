extends RefCounted
## Tutorial: una serie de lecciones, cada una una torre chica armada a mano que enseña una sola cosa. Reemplaza al modo entrenamiento.
## Cada lección es {id, title, text, zoom, build: Callable -> TowerLogic, marker?: Vector3i, needs?: [modos que exige], generated?: filas}.
## Se completa al llegar al bloque dorado (o, en las lecciones con `marker`, al dejar un bloque sobre la casilla marcada).
## Las lecciones están pensadas para que el mecanismo sea imprescindible (el solucionador lo comprueba en tests/test_tutorial.gd).

const TowerLogic := preload("res://scripts/tower_logic.gd")
const Loc := preload("res://scripts/loc.gd")
const K := TowerLogic.Kind
const UP := Vector3i(0, 1, 0)
const NO_FALL := 100000   # la fila de abajo no cae en las lecciones chicas


## Todas las lecciones, en orden.
static func lessons() -> Array:
	return [
		{"id": "moverse", "title": "Moverse",
		"text": "W A S D mueven al personaje, siempre según la rosa de los vientos de arriba a la derecha.\nGirá la cámara con el mouse (arrastrando) o con las flechas, y fijate cómo cambian las teclas.\nLlegá al bloque dorado.",
		"zoom": 9.0, "build": _moverse},
		{"id": "trepar", "title": "Trepar",
		"text": "Caminá hacia un bloque más alto para treparlo, de a un nivel.\nSube la escalera hasta el bloque dorado.",
		"zoom": 9.0, "build": _trepar},
		{"id": "empujar", "title": "Empujar",
		"text": "Shift + dirección empuja el bloque que tenés enfrente.\nHay un hueco en el piso: empujá el bloque hasta taparlo y cruzá por encima.\n(Si te equivocás, R reintenta.)",
		"zoom": 10.0, "build": _empujar, "needs": [TowerLogic.Mode.GRAB]},
		{"id": "tirar", "title": "Tirar",
		"text": "Shift + la dirección contraria al bloque lo tira hacia vos: caminás hacia atrás y el bloque te sigue.\nTirá el bloque hasta la casilla dorada del piso.",
		"zoom": 9.0, "build": _tirar, "marker": Vector3i(2, 1, 1)},
		{"id": "colgarse", "title": "Colgarse",
		"text": "Estás arriba de una torre alta y no se puede bajar caminando.\nEspacio + dirección te cuelga del borde; para soltarte, andá en la dirección contraria al bloque. (Con el bloque enfrente trepás de vuelta.)\nBajá y llegá al bloque dorado.",
		"zoom": 12.0, "build": _colgarse, "needs": [TowerLogic.Mode.HANG]},
		{"id": "hielo", "title": "Hielo",
		"text": "El bloque celeste es hielo: te hace resbalar hasta que algo te frene.\nCruzá el corredor y trepá al dorado.",
		"zoom": 10.0, "build": _hielo},
		{"id": "pesado", "title": "Bloque pesado",
		"text": "El bloque de hierro no se empuja ni se tira, pero se puede trepar.\nPasá por encima de él.",
		"zoom": 9.0, "build": _pesado},
		{"id": "agrietado", "title": "Bloque agrietado",
		"text": "Los de arenisca con grietas se rompen apenas te bajás de ellos: no hay vuelta atrás.\nCruzá el puente de agrietados.",
		"zoom": 10.0, "build": _agrietado},
		{"id": "bomba", "title": "Bomba",
		"text": "La bomba cuenta hacia atrás cada movimiento que hacés mientras estás a su altura. Subirte encima la desactiva.\nTe da justo los movimientos que necesitás: si perdés uno o retrocedés, explota (R reintenta).",
		"zoom": 9.0, "build": _bomba},
		{"id": "fila", "title": "Fila de bloques",
		"text": "Si hay bloques pegados detrás del que empujás, se mueve toda la fila (hasta 3 bloques).\nEl corredor es angosto: empujá la fila hasta tapar el hueco y cruzá por encima.\n(Si te equivocás, R reintenta.)",
		"zoom": 10.0, "build": _fila, "needs": [TowerLogic.Mode.GRAB]},
		{"id": "trampa", "title": "Trampa",
		"text": "Un bloque con una cruz roja arriba es una trampa: se desarma apenas te parás encima y te caés con él.\nRodealo y llegá al bloque dorado.",
		"zoom": 10.0, "build": _trampa},
		{"id": "pinchos", "title": "Pinchos",
		"text": "Los bloques con púas plateadas son pinchos: pisarlos pierde.\nRodealos (o empujalos fuera del camino) y llegá al bloque dorado.",
		"zoom": 10.0, "build": _pinchos},
		{"id": "torre", "title": "Una torre de verdad",
		"text": "Así son las torres del juego: la fila de abajo cae cada cierto número de movimientos (contador arriba a la izquierda).\nLos bloques violetas se purifican al pisarlos y dan claridad; si encadenás pisadas nuevas, la racha multiplica.\nSubí hasta el portal dorado: te lleva al casino.",
		"zoom": 14.0, "generated": 4},
	]


static func count() -> int:
	return lessons().size()


## Torre de la lección i (las generadas las arma main.gd con el generador y devuelven null acá).
static func build(i: int):
	var l: Dictionary = lessons()[i]
	if l.has("generated"):
		return null
	return l.build.call()


# --- ayudas para armar torres ---------------------------------------------------------------------------------------

static func _new(w: int, d: int) -> RefCounted:
	var t := TowerLogic.new()
	t.size = Vector2i(w, d)
	t.collapse_every = NO_FALL
	t.moves_to_collapse = NO_FALL
	return t


static func _fill(t, x0: int, x1: int, z0: int, z1: int, y: int, kind: int = K.NORMAL, timer := 0) -> void:
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			t.add_block(Vector3i(x, y, z), false, kind, timer)


## El bloque de la celda es el portal: se gana parado sobre él.
static func _goal(t, cell: Vector3i) -> void:
	t.goal_block = t.blocks[cell]
	t.goal_cell = cell + UP
	t.goal_y = cell.y + 1


# --- lecciones ------------------------------------------------------------------------------------------------------

## Un corredor angosto (muros pesados de 2 de alto) con un hueco de ancho completo en x = 5 y una fila de dos bloques: el único
## modo de cruzar es empujar la fila entera hasta el hueco.
static func _fila() -> RefCounted:
	var t := _new(9, 3)
	for x in 9:
		if x != 5:
			_fill(t, x, x, 0, 2, 0)
	for y in [1, 2]:
		_fill(t, 1, 4, 0, 0, y, K.HEAVY)
		_fill(t, 1, 4, 2, 2, y, K.HEAVY)
	t.add_block(Vector3i(3, 1, 1))
	t.add_block(Vector3i(4, 1, 1))
	t.player = Vector3i(0, 1, 1)
	_goal(t, Vector3i(8, 0, 1))
	return t


## Dos carriles sobre el vacío: el recto (z = 1) tiene una trampa en x = 4; el de al lado es todo de bloques comunes.
static func _trampa() -> RefCounted:
	var t := _new(9, 3)
	_fill(t, 0, 1, 0, 2, 0)
	_fill(t, 2, 3, 0, 1, 0)
	_fill(t, 4, 4, 0, 0, 0)
	t.add_block(Vector3i(4, 0, 1), false, K.TRAP)
	_fill(t, 5, 6, 0, 1, 0)
	_fill(t, 7, 8, 0, 2, 0)
	t.player = Vector3i(0, 1, 1)
	_goal(t, Vector3i(8, 0, 1))
	return t


## Pinchos puestos en zigzag sobre un piso ancho: el camino recto pasa por encima de ellos.
static func _pinchos() -> RefCounted:
	var t := _new(9, 3)
	_fill(t, 0, 8, 0, 2, 0)
	t.add_block(Vector3i(3, 1, 0), false, K.SPIKES)
	t.add_block(Vector3i(3, 1, 1), false, K.SPIKES)
	t.add_block(Vector3i(6, 1, 1), false, K.SPIKES)
	t.add_block(Vector3i(6, 1, 2), false, K.SPIKES)
	t.player = Vector3i(0, 1, 1)
	_goal(t, Vector3i(8, 0, 1))
	return t


static func _moverse() -> RefCounted:
	var t := _new(6, 6)
	_fill(t, 0, 5, 0, 5, 0)
	t.player = Vector3i(0, 1, 0)
	_goal(t, Vector3i(5, 0, 5))
	return t


static func _trepar() -> RefCounted:
	var t := _new(6, 3)
	_fill(t, 0, 5, 0, 2, 0)
	_fill(t, 2, 5, 0, 2, 1)
	_fill(t, 3, 5, 0, 2, 2)
	_fill(t, 4, 5, 0, 2, 3)
	t.player = Vector3i(0, 1, 1)
	_goal(t, Vector3i(5, 3, 1))
	return t


## Piso de 9 x 3 con un hueco de ancho completo en x = 4 y un bloque suelto: hay que empujarlo hasta el hueco.
static func _empujar() -> RefCounted:
	var t := _new(9, 3)
	for x in 9:
		if x != 4:
			_fill(t, x, x, 0, 2, 0)
	t.add_block(Vector3i(2, 1, 1))
	t.player = Vector3i(0, 1, 1)
	_goal(t, Vector3i(8, 0, 1))
	return t


## Un bloque suelto a dos casillas de la casilla marcada (la lección se completa al dejarlo ahí).
static func _tirar() -> RefCounted:
	var t := _new(7, 3)
	_fill(t, 0, 6, 0, 2, 0)
	t.add_block(Vector3i(4, 1, 1))
	t.player = Vector3i(3, 1, 1)
	t.goal_y = 1000   # la lección no se gana llegando a ningún lado
	t.goal_cell = Vector3i(2, 1, 1)
	return t


## Una torre de 3 de alto en un piso de 8 x 3: arriba no se puede bajar caminando (hay que colgarse y soltarse).
static func _colgarse() -> RefCounted:
	var t := _new(8, 3)
	_fill(t, 0, 7, 0, 2, 0)
	_fill(t, 0, 2, 0, 2, 1)
	_fill(t, 0, 2, 0, 2, 2)
	_fill(t, 0, 2, 0, 2, 3)
	t.player = Vector3i(0, 4, 1)
	_goal(t, Vector3i(7, 0, 1))
	return t


static func _hielo() -> RefCounted:
	var t := _new(10, 3)
	_fill(t, 0, 1, 1, 1, 0)
	_fill(t, 2, 7, 1, 1, 0, K.ICE)
	t.add_block(Vector3i(8, 1, 1))
	t.add_block(Vector3i(8, 0, 1))
	t.player = Vector3i(0, 1, 1)
	_goal(t, Vector3i(8, 1, 1))
	return t


## Un muro de hierro de 1 de alto atraviesa el corredor: se trepa.
static func _pesado() -> RefCounted:
	var t := _new(7, 3)
	_fill(t, 0, 6, 0, 2, 0)
	_fill(t, 3, 3, 0, 2, 1, K.HEAVY)
	t.player = Vector3i(0, 1, 1)
	_goal(t, Vector3i(6, 0, 1))
	return t


## Un puente de tres agrietados sobre el vacío.
static func _agrietado() -> RefCounted:
	var t := _new(9, 3)
	_fill(t, 0, 2, 1, 1, 0)
	_fill(t, 3, 5, 1, 1, 0, K.CRACKED)
	_fill(t, 6, 8, 1, 1, 0)
	t.player = Vector3i(0, 1, 1)
	_goal(t, Vector3i(8, 0, 1))
	return t


## La bomba está sobre el piso, a la altura del jugador (por eso cuenta), a 3 movimientos exactos: dos pasos y subirse encima.
## Con 3 de cuenta hay que ir directo: perder un solo movimiento (o retroceder) hace que explote.
static func _bomba() -> RefCounted:
	var t := _new(7, 3)
	_fill(t, 0, 6, 1, 1, 0)
	t.add_block(Vector3i(3, 1, 1), false, K.BOMB, 3)
	t.player = Vector3i(0, 1, 1)
	_goal(t, Vector3i(6, 0, 1))
	return t
