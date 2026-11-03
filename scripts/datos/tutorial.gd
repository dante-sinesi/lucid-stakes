extends RefCounted
## Tutorial: una serie de lecciones, cada una una sala chica armada a mano con el motor de la torre (torre/motor.gd) que enseña una sola cosa; la última es una torre de verdad.
## Cada lección es {id, title, help, mode, zoom, capas: la sala dibujada por capas (ver sala_de_capas), needs?: [modos que exige], complete?: "keys", generated?: salas, dice?}.
## `help` es la frase simple que queda arriba con las teclas (ver key_hint.gd); `mode` qué cuenta como usar esas teclas; `complete: "keys"` la completa al usar todas las teclas (sin meta).
## Se completa al llegar a la salida (el bloque dorado). Las lecciones están pensadas para que la técnica sea imprescindible (tests/unitarios/test_tutorial.gd lo comprueba con el solucionador).

const Loc := preload("res://scripts/idioma/loc.gd")

const MODO_MOVER := 0
const MODO_AGARRAR := 1
const MODO_COLGAR := 2


## Todas las lecciones, en orden. Sólo enseñan mecánicas (nada de tipos de bloque). Moverse con WASD se aprende caminando por la taberna, antes de la primera lección. Lo que dice el tabernero (lore) está en story.gd.
## En todas la salida es el cubo-portal a la altura del personaje: el último paso es subir un escalón hasta el bloque dorado (se entra de costado, como en las torres).
static func lessons() -> Array:
	var wasd := "{mover_adelante} {mover_izquierda} {mover_atras} {mover_derecha}"
	var wasd_opt := "{?mover_adelante} {?mover_izquierda} {?mover_atras} {?mover_derecha}"
	return [
		{"id": "camara", "title": "La cámara", "help": "Gira la vista con {?camara_izquierda} {?camara_derecha}", "mode": "camera", "zoom": 10.0, "capas": CAMARA},
		{"id": "empujar", "title": "Empujar", "help": "Mantén {empujar} y pulsa " + wasd_opt, "mode": "push", "zoom": 10.0, "capas": EMPUJAR, "needs": [MODO_AGARRAR]},
		{"id": "tirar", "title": "Tirar", "help": "Mantén {empujar} y pulsa " + wasd_opt, "mode": "pull", "zoom": 10.0, "capas": TIRAR, "needs": [MODO_AGARRAR]},
		{"id": "colgarse", "title": "Cornisa", "help": "Mantén {colgarse} y pulsa " + wasd_opt, "mode": "hang", "zoom": 11.0, "capas": CORNISA, "needs": [MODO_COLGAR]},
		{"id": "soltarse", "title": "Soltarse", "help": "Cuélgate con {colgarse} y suéltate con {colgarse}", "mode": "hang", "zoom": 12.0, "capas": SOLTARSE, "needs": [MODO_COLGAR]},
		{"id": "torre", "title": "Una torre de verdad", "help": "Sube hasta el portal dorado", "zoom": 14.0, "generated": 2, "dice": true},   # (mientras se arma, el tabernero explica los dados)
	]


static func count() -> int:
	return lessons().size()


## La sala de la lección i, en el formato de las salas de la torre (null en la última lección, la torre de verdad, que se arma con la biblioteca de salas).
static func sala(i: int):
	var l: Dictionary = lessons()[i]
	if l.has("generated"):
		return null
	return sala_de_capas(str(l.capas), 9000 + i)


# --- las salas ------------------------------------------------------------------------------------------------------

## Un camino que rodea un muro alto: el tramo de atrás (con el portal) queda tapado por el muro desde donde se empieza a mirar, y se ve girando la vista.
## Cinco de ancho y seis de fondo; el personaje empieza adelante, a la izquierda, sube por la derecha y vuelve por atrás hasta el portal, que está un escalón más arriba.
const CAMARA := "0,0,1,1,1/0,1,1,1,1/0,1,1,1,1/0,1,1,1,1/0,1,1,1,1/P,1,1,1,1|0,F,0,0,0/0,1,1,1,0/0,1,1,1,0/0,1,1,1,0/0,1,1,1,0/0,0,0,0,0|0,0,0,0,0/0,1,1,1,0/0,1,1,1,0/0,1,1,1,0/0,1,1,1,0/0,0,0,0,0"

## Una escalera de 3 escalones a la que le falta el primero: el bloque común que está adelante hay que empujarlo un lugar para que sea el primer escalón.
## Más allá hay un muro de hierro: no se puede seguir empujando.
const EMPUJAR := "0,1,0/0,P,0/0,1,0/0,1,0/0,1,0/0,1,0/0,H,0|0,0,0/0,0,0/0,1,0/0,0,0/0,1,0/0,1,0/0,H,0|0,0,0/0,0,0/0,0,0/0,0,0/0,1,0/0,1,0/0,0,0|0,0,0/0,0,0/0,0,0/0,0,0/0,0,0/0,F,0/0,0,0"

## La escalera queda a espaldas del personaje: el bloque de abajo del primer escalón (que lo hace demasiado alto para trepar) se saca tirando de él mientras se camina hacia atrás
## (el de arriba queda colgando y deja un escalón de 1); después se da la vuelta y se sube. El muro de hierro del fondo impide empujar la escalera entera.
const TIRAR := "0,1,0/0,1,0/0,1,0/0,1,0/0,P,0/0,1,0/0,1,0/0,1,0|0,0,0/0,0,0/0,0,0/0,0,0/0,0,0/0,1,0/0,1,0/0,H,0|0,0,0/0,0,0/0,0,0/0,0,0/0,0,0/0,1,0/0,1,0/0,H,0|0,0,0/0,0,0/0,0,0/0,0,0/0,0,0/0,0,0/0,1,0/0,F,0"

## Un muro de hierro de 3 de alto en el camino: no se puede trepar ni empujar. Hay que colgarse del borde del bloque donde se está parado, avanzar por el costado del muro agarrado de su base y trepar del otro lado.
const CORNISA := "0,P,0/0,H,0/0,H,0/0,1,0/0,0,0|0,0,0/0,H,0/0,H,0/0,0,0/0,F,0|0,0,0/0,H,0/0,H,0/0,0,0/0,0,0"

## Una torre de 3 de alto: arriba no se puede bajar caminando (hay que colgarse del borde y soltarse).
const SOLTARSE := "0,1,0/0,1,0/0,1,0/0,1,0/0,0,0|0,1,0/0,0,0/0,0,0/0,0,0/0,F,0|0,P,0/0,0,0/0,0,0/0,0,0/0,0,0"


## Dibuja una sala por capas, de abajo (nivel 1) hacia arriba, separadas por "|"; cada capa son filas separadas por "/" (la fila es z) y cada fila celdas separadas por ","
## (la celda es x). Celdas: 0 vacío · 1 bloque común · H pesado · I hielo · C agrietado · P el bloque de entrada (el personaje queda parado encima) · F el bloque de salida
## (se gana parado sobre él). Devuelve la sala en el formato de las del paquete (tipo, meta, jugador, colgado, bloques...).
static func sala_de_capas(texto: String, id := 0) -> Dictionary:
	var bloques: Array = []
	var jugador := [0, 2, 0]
	var meta := 1
	var capas := texto.split("|")
	for y in capas.size():
		var filas := capas[y].split("/")
		for z in filas.size():
			var celdas := filas[z].split(",")
			for x in celdas.size():
				var c := celdas[x].strip_edges()
				if c == "0" or c == "":
					continue
				var letra := "n"
				match c:
					"P":
						letra = "p"
						jugador = [x, y + 2, z]
					"F":
						letra = "f"
						meta = y + 1
					"H":
						letra = "h"
					"I":
						letra = "i"
					"C":
						letra = "c"
				bloques.append([x, y + 1, z, letra])
	return {"tipo": "tutorial", "meta": meta, "jugador": jugador, "colgado": [0, 0], "bloques": bloques, "pasos": 0, "nivel": "facil", "categoria": "tutorial", "pisos": meta - 1, "id": id}
