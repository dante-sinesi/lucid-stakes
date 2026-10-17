extends RefCounted
## Tutorial: una serie de lecciones, cada una una torre chica armada a mano que enseña una sola cosa. Reemplaza al modo entrenamiento.
## Cada lección es {id, title, text, zoom, build: Callable -> TowerLogic, marker?: Vector3i, needs?: [modos que exige], generated?: filas,
## keys?: las teclas que se muestran arriba, grises hasta que se aprietan ("wasd", "shift_wasd" o "espacio_wasd"; ver key_hint.gd)}.
## Se completa al llegar al bloque dorado (o, en las lecciones con `marker`, al dejar un bloque sobre la casilla marcada).
## Las lecciones están pensadas para que el mecanismo sea imprescindible (el solucionador lo comprueba en tests/test_tutorial.gd).

const TowerLogic := preload("res://scripts/tower_logic.gd")
const Loc := preload("res://scripts/loc.gd")
const K := TowerLogic.Kind
const UP := Vector3i(0, 1, 0)
const NO_FALL := 100000   # la fila de abajo no cae en las lecciones chicas


## Todas las lecciones, en orden. Sólo enseñan mecánicas (nada de tipos de bloque). `say` es lo que dice el tabernero (lore, en story.gd); `help` la frase simple
## que queda arriba con las teclas (ver key_hint.gd); `mode` qué cuenta como usar esas teclas; `complete: "keys"` la completa al usar todas las teclas (sin meta).
static func lessons() -> Array:
	var wasd := "{mover_adelante} {mover_izquierda} {mover_atras} {mover_derecha}"
	var wasd_opt := "{?mover_adelante} {?mover_izquierda} {?mover_atras} {?mover_derecha}"
	return [
		{"id": "moverse", "title": "Moverse", "help": "Pulsá " + wasd, "mode": "move", "zoom": 9.0, "build": _moverse},
		{"id": "camara", "title": "La cámara", "help": "Pulsá {camara_arriba} {camara_izquierda} {camara_abajo} {camara_derecha}", "mode": "camera", "zoom": 9.0, "build": _camara, "complete": "keys"},
		{"id": "empujar", "title": "Empujar", "help": "Mantené {empujar} y pulsá " + wasd_opt, "mode": "push", "zoom": 10.0, "build": _empujar, "needs": [TowerLogic.Mode.GRAB]},
		{"id": "tirar", "title": "Tirar", "help": "Mantené {empujar} y pulsá " + wasd_opt, "mode": "pull", "zoom": 10.0, "build": _tirar, "needs": [TowerLogic.Mode.GRAB]},
		{"id": "colgarse", "title": "Cornisa", "help": "Mantené {colgarse} y pulsá " + wasd_opt, "mode": "hang", "zoom": 11.0, "build": _colgarse_s, "needs": [TowerLogic.Mode.HANG]},
		{"id": "soltarse", "title": "Soltarse", "help": "Colgate con {colgarse} y una dirección, y soltate con {colgarse}", "mode": "hang", "zoom": 12.0, "build": _colgarse, "needs": [TowerLogic.Mode.HANG]},
		{"id": "torre", "title": "Una torre de verdad", "help": "Subí hasta el portal dorado", "zoom": 14.0, "generated": 4, "dice": true},   # (mientras se genera, el tabernero explica los dados)
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


## Un sendero en forma de S sobre el vacío: da vueltas en las cuatro direcciones, así que hay que usar las cuatro teclas.
static func _moverse() -> RefCounted:
	var t := _new(5, 5)
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4),
			Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(3, 3)]:
		t.add_block(Vector3i(c.x, 0, c.y))
	t.player = Vector3i(0, 1, 0)
	_goal(t, Vector3i(3, 0, 3))
	return t


## El personaje parado sobre un solo bloque: no hay adónde ir, sólo se mira alrededor (se completa al usar las cuatro flechas).
static func _camara() -> RefCounted:
	var t := _new(3, 3)
	t.add_block(Vector3i(1, 0, 1))
	t.player = Vector3i(1, 1, 1)
	t.goal_y = 1000
	t.goal_cell = Vector3i(-5, 0, -5)
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


## Las salas se dibujan como capas, de abajo hacia arriba: "[capa],[capa]"; cada capa son filas separadas por ";" (la fila es z) y cada fila celdas separadas por "," (la celda es x).
## Celdas: 0 vacío · 1 bloque común · H hierro · I hielo · C agrietado · p el jugador (parado en esa celda) · portal el bloque del portal (se gana parado sobre él).
static func _from_layers(text: String, size_hint := Vector2i(0, 0)) -> RefCounted:
	var layers := text.split("],[")
	var cells: Array = []   # [Vector3i, token]
	var w := 0
	var d := 0
	for y in layers.size():
		var rows := layers[y].replace("[", "").replace("]", "").replace("
", "").replace("", "").replace(" ", "").split(";", false)
		d = maxi(d, rows.size())
		for z in rows.size():
			var cols := rows[z].split(",")
			w = maxi(w, cols.size())
			for x in cols.size():
				if cols[x] != "0":
					cells.append([Vector3i(x, y, z), cols[x]])
	var t := _new(maxi(w, size_hint.x), maxi(d, size_hint.y))
	var portal := Vector3i(-1, -1, -1)
	for c in cells:
		var pos: Vector3i = c[0]
		match str(c[1]):
			"p":
				t.player = pos
			"portal":
				t.add_block(pos)
				portal = pos
			"H":
				t.add_block(pos, false, K.HEAVY)
			"I":
				t.add_block(pos, false, K.ICE)
			"C":
				t.add_block(pos, false, K.CRACKED)
			_:
				t.add_block(pos)
	if portal.y >= 0:
		_goal(t, portal)
	return t


## Una escalera de 3 escalones (1, 2 y 3 de alto, con el portal arriba) a la que le falta el primero: el bloque común pegado al personaje, al pie del segundo escalón, hay que
## empujarlo un lugar para que sea el primer escalón. Más allá hay una pared de hierro: no se puede seguir empujando.
static func _empujar() -> RefCounted:
	return _from_layers("[0,1,0;0,1,0;0,1,0;0,1,0;0,1,0;0,1,0;0,1,0;],[0,0,0;0,p,0;0,1,0;0,0,0;0,1,0;0,1,0;0,H,0;],[0,0,0;0,0,0;0,0,0;0,0,0;0,1,0;0,1,0;0,0,0;],[0,0,0;0,0,0;0,0,0;0,0,0;0,0,0;0,portal,0;0,0,0;]")


## La escalera queda a espaldas del personaje: el bloque de abajo del primer escalón (que lo hace demasiado alto para trepar) se saca tirando de él mientras se camina hacia atrás
## (el de arriba cae y queda un escalón de 1); después se da la vuelta y se sube. La pared de hierro del fondo impide empujar la escalera entera.
static func _tirar() -> RefCounted:
	return _from_layers("[0,1,0;0,1,0;0,1,0;0,1,0;0,1,0;0,1,0;0,1,0;0,1,0;],[0,0,0;0,0,0;0,0,0;0,p,0;0,1,0;0,1,0;0,1,0;0,H,0;],[0,0,0;0,0,0;0,0,0;0,0,0;0,1,0;0,1,0;0,1,0;0,H,0;],[0,0,0;0,0,0;0,0,0;0,0,0;0,0,0;0,0,0;0,portal,0;0,H,0;]")


## Una S de columnas de hierro de 2 de alto que se tocan sólo en diagonal: caminando no se pasa de una a otra; hay que colgarse del borde y rodear la esquina.
static func _colgarse_s() -> RefCounted:
	var t := _new(7, 4)
	var cells: Array[Vector2i] = [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 2), Vector2i(6, 1), Vector2i(5, 0), Vector2i(4, 0)]
	for x in 3:   # la plataforma de salida es ancha: desde cualquiera de sus bordes se puede colgar (Espacio + cualquier dirección)
		for z in 3:
			cells.append(Vector2i(x, z))
	for c in cells:
		for y in 2:
			t.add_block(Vector3i(c.x, y, c.y), false, K.HEAVY)
	t.player = Vector3i(1, 2, 1)
	_goal(t, Vector3i(4, 1, 0))
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
