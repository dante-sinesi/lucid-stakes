extends RefCounted
## Los textos de la historia del tutorial, dichos por el tabernero: la bienvenida en la taberna (el lore de la pesadilla), lo que dice
## en cada lección (ver tutorial.gd) y el cierre en el salón de piedra, donde explica las habilidades, la Luz, los escenarios y las
## pruebas. Una línea es un texto o {text, icon}: con `icon` ("luz" o "claridad") el cuadro de diálogo muestra ese ícono al costado,
## así se habla de la moneda sin escribir su nombre.

const SPEAKER := "Tabernero"

## Etapa de la sala donde pasa cada escena (define cómo es la sala: la taberna y el salón de piedra).
const INTRO_STAGE := 1
const OUTRO_STAGE := 7

const BLOCKED_TABLE := "Primero la puerta de atrás, soñador. Después hablamos de apuestas."


static func intro() -> Array:
	return [
		"Pasá, soñador. Sentate un momento, que allá afuera hace frío. No sos el primero que llega con esa cara: la de quien no recuerda cómo entró.",
		"Esto no es el mundo de los despiertos. Es la pesadilla: una torre interminable hecha con tus propios recuerdos, y los recuerdos se corrompen. Cada piso se desmorona si te quedás quieto.",
		{"text": "Lo único que te mantiene entero es esto: la claridad, lo que queda de vos despierto. Cada bloque que pisás se purifica y te la devuelve.", "icon": "claridad"},
		"Yo también subí, hace mucho. Llegué hasta aquí y me quedé a cuidar la taberna, porque siempre aparece algún soñador perdido. Alguien tiene que recibirlos.",
		"Las torres tienen cima. Arriba de cada una hay un portal dorado, y del otro lado, un lugar donde descansar. Veintisiete torres, y se acaba la pesadilla.",
		"¿Ves esa puerta de atrás, la que brilla? Andá hasta ahí y empujala. Cuando estés del otro lado, te voy a ir enseñando cómo escapar.",
	]


## Lo que dice el tabernero en cada lección del tutorial (en su voz). Si falta, se usa el texto de la lección.
const LESSONS := {
	"moverse": "Empecemos, soñador. Con W A S D te movés; la brújula de arriba a la derecha te dice qué dirección es cada tecla. Girá la cámara con el mouse o las flechas. Llegá al bloque dorado.",
	"trepar": "Los pisos suben de a un nivel. Caminá hacia un bloque más alto y lo trepás solo. Subí la escalera hasta el dorado.",
	"empujar": "Hay un hueco en el piso, y la pesadilla no perdona las caídas. Con Shift y una dirección empujás el bloque de enfrente: tapá el hueco y cruzá por encima. Si te equivocás, apretá R y probás de nuevo.",
	"tirar": "También se puede tirar. Shift y la dirección contraria al bloque: vos caminás hacia atrás y el bloque te sigue. Traelo hasta la casilla dorada.",
	"colgarse": "Estás arriba de una torre alta y no se baja caminando. Espacio y una dirección te cuelgan del borde; para soltarte, andá en la dirección contraria al bloque. Bajá y llegá al dorado.",
	"hielo": "Ese bloque celeste es hielo: te hace resbalar hasta que algo te frene. Cruzá el corredor y trepá al dorado.",
	"pesado": "El bloque de hierro no se empuja ni se tira, pero se trepa. Pasá por encima de él.",
	"agrietado": "Los de arenisca con grietas se rompen en cuanto te bajás de ellos: no hay vuelta atrás. Cruzá el puente de agrietados.",
	"bomba": "La bomba cuenta hacia atrás cada vez que te movés a su altura, y subirte encima la desactiva. Acá te da los movimientos justos: si perdés uno o retrocedés, explota. Andá directo.",
	"fila": "Cuando hay bloques pegados uno detrás del otro, los empujás todos juntos, hasta tres. Este corredor es angosto: empujá la fila hasta tapar el hueco y cruzá por encima.",
	"trampa": "Cuidado con las cruces rojas: esos bloques mienten. Se desarman apenas los pisás y te caés con ellos. Rodealos.",
	"pinchos": "Esas púas plateadas no perdonan: si te parás encima, se acabó. Rodealas, o empujá el bloque lejos del camino.",
	"torre": "Así son las torres de verdad: la fila de abajo cae cada tantos movimientos (contador arriba a la izquierda). Pisar bloques violetas da claridad, y la racha la multiplica. Subí al portal dorado.",
}


static func lesson_say(id: String, fallback := "") -> String:
	return LESSONS.get(id, fallback)


static func outro() -> Array:
	return [
		"¡Lo lograste, soñador! Ya sabés moverte, empujar, tirar, colgarte y no volar por una bomba. Con eso se sube cualquier torre... o casi.",
		"Este salón es más claro que mi taberna, ¿ves? Cuanto más subís, más luminosos se vuelven estos lugares. Después de cada torre te espero en uno distinto, y ahí podés jugarte la claridad en la ruleta.",
		{"text": "Lo que juntás en las torres es claridad. En la ruleta la apostás por boosts, que duran todo el viaje, y por consumibles, que se gastan.", "icon": "claridad"},
		"Cada tres torres la pesadilla te pone una prueba: una regla distinta, como la niebla o la prisa. Sabés desde el principio cuál viene y cuándo. Si la superás, te llevás un boost y, la primera vez, una habilidad.",
		"Las habilidades se quedan con vos para siempre, aunque empieces de nuevo. No se compran: se aprenden superando la prueba que las enseña, y cada prueba enseña la suya.",
		{"text": "Y esto que brilla te lo deja la pesadilla según hasta dónde llegaste. Con esto se paga la entrada a otros escenarios, más difíciles, que dan más.", "icon": "luz"},
		"La pesadilla de siempre es gratis. Los otros escenarios se pagan cada vez que entrás, pero guardan habilidades que no vas a encontrar en ningún otro lado.",
		"Eso es todo. Ahora andá, soñador. Las veintisiete torres te esperan... y yo, acá, con la taberna abierta.",
	]
