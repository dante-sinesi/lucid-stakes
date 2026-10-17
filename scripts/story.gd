extends RefCounted
## Los textos de la historia del tutorial, dichos por el tabernero: la bienvenida en la taberna (el lore de la pesadilla), lo que dice
## en cada lección (ver tutorial.gd) y el cierre en el salón de piedra, donde explica las habilidades, la Luz, los escenarios y las
## pruebas. Una línea es un texto o {text, icon}: con `icon` ("luz" o "claridad") el cuadro de diálogo muestra ese ícono al costado,
## así se habla de la moneda sin escribir su nombre.

const Loc := preload("res://scripts/loc.gd")

const SPEAKER := "Tabernero"

## Etapa de la sala donde pasa cada escena (define cómo es la sala: la taberna y el salón de piedra).
const INTRO_STAGE := 1
const OUTRO_STAGE := 4

const BLOCKED_TABLE := "Primero el portal de atrás, soñador. Después hablamos de apuestas."


static func intro() -> Array:
	return [
		"Pase, soñador. Qué cara... ¿es tu primera vez aquí?",
		"Este no es el mundo de los despiertos. Es una pesadilla, tu pesadilla, hecha con tus propios recuerdos, y los recuerdos se corrompen.",
		{"text": "Si estás acá es porque te queda algo de esto: la claridad, lo que queda de tus recuerdos que aún no están corruptos.", "icon": "claridad"},
		"Salir de aquí no es fácil. Si no, mirame: no estaría aquí, atendiendo una taberna, atendiendo a los soñadores perdidos.",
		"¿Que cómo se sale? Dando claridad a tu pesadilla, y creeme, no es fácil.",
		"¿Ves ese portal de atrás, el que brilla? Ve hasta allí y crúzalo, que te enseñaré cómo abandonar este lugar.",
	]


## Lo que dice el tabernero en cada lección del tutorial (en su voz): sólo lore, sin hablar de teclas (la ayuda de arriba lo hace). Una tecla y se va.
const LESSONS := {
	"moverse": "Si bien los recuerdos pueden ser corrompidos, al parecer no olvidaste cómo caminar, pero repasemos.",
	"camara": "A veces es mejor ver las cosas desde otro ángulo. Prueba verte desde otro punto de vista.",
	"empujar": "A veces caminar no es suficiente, así que debes alterar tu contexto para seguir adelante.",
	"tirar": "Si te arrepientes de cómo alteraste el contexto, siempre puedes devolver las cosas a como estaban... o eso creo.",
	"colgarse": "A veces caminar no es la mejor solución para salir adelante. ¡Pero siempre se puede tomar un atajo!",
	"soltarse": "A veces uno ve el precipicio y... tiene que saltar.",
	"torre": "Una torre de verdad se ve así. Tienes que andar con cuidado, porque si caminas mucho, el suelo comienza a caer. ¿Por qué no intentas superar esta?",
}


## Lo que dice el tabernero cuando se abren los dados (se explica el juego y sus premios).
static func dice_intro() -> Array:
	return [
		"¡Qué habilidad motriz tienes! Ahora probemos tu suerte en el azar.",
		"Tienes 5 dados. Antes de tirarlos, puedes elegir el número que saldrá en cada uno. Después se tiran, y los que aciertes se quedan; se puede tirar hasta 3 veces los dados.",
		{"text": "Con dos aciertos, ganas algo de claridad. Con tres, algo más de claridad y una luz. Con cuatro, aún más claridad, y dos luces.", "icon": "luz"},
		"Pero con cinco... Hay un premio enorme, con cinco luces... ¡Y un cosmético!",
	]


static func lesson_say(id: String, fallback := "") -> String:
	return LESSONS.get(id, fallback)


static func outro() -> Array:
	return [
		"¡Lo lograste, soñador! Ya sabes moverte, empujar, tirar, colgarte y tirarte al precipicio. Con eso podrás subir cualquier torre. O al menos eso fue necesario para que yo llegue aquí.",
		"Este salón es más claro y espacioso que mi taberna, ¿no crees?",
		"Cada vez que superes una torre, tendrás más claridad, lo que hará que todo lo que recuerdes sea más luminoso y pintoresco. ¡Como este salón y yo!",
		"Al parecer, en tus sueños te gusta jugar con azar, así que, ¿por qué no? Conmigo podrás jugar a la ruleta, y si ganas te daré consumibles o habilidades que te permitan superar las próximas torres que están por venir.",
		"¡Y mira si te estoy haciendo un favor! Solo voy a cobrarte claridad. ¡Sí, la misma que consigues superando la torre!",
		"Ah, y no te olvides de quien cuida la puerta de salida: Farolín. Es un farol con patas, y te cobra claridad por cada torre que dejás atrás. Fijate el precio arriba a la izquierda: se pone verde cuando te alcanza.",
		"Si no te alcanza, Farolín te ofrece volver a subir la torre, y eso te cuesta una vida: morir en la torre ya no te quita claridad, te quita una vida. Si no te quedan vidas, o pagás o dejás que todo se apague.",
		"Mi vitrina cambia en cada visita: ahí ves qué premios dan las fichas de la ruleta, y si no te gustan, la podés rotar pagando. En la tienda podés comprar directo lo que ya viste, aunque sale más caro que apostar.",
		"Lo que ganes —boosts, consumibles— se queda con vos y hace que juntes más claridad en cada torre. Y ojo: el precio de Farolín sube con cada etapa, así que más te vale crecer rápido.",
		"Cada tres torres, la pesadilla te pone a prueba, cambiando las reglas del juego. Ten cuidado con eso, nunca se sabe qué nuevo desafío puede aparecer...",
		"Cuando superes todos los pisos de la pesadilla, conseguirás una habilidad especial, que se quedará contigo por siempre. ¡Sí, por siempre, aun si vuelves a tener una pesadilla!",
		{"text": "Y una cosa más, esto que brilla también te lo deja la pesadilla según hasta dónde llegues. Con esto... no sé qué podrías hacer, pero se ve brillante, ¿no?", "icon": "luz"},
		"Creo que eso es todo. Ahora ve, soñador. ¡A despertar!",
	]


## Los saludos del tabernero en los casinos (va rotando).
const GREETINGS := [
	"Sentate, soñador. Acá la claridad se juega, no se regala.",
	"Cada ficha es un pedazo de despertar. ¿Cuánto vas a arriesgar?",
	"La casa siempre gana... salvo cuando te acordás de despertar.",
]


## Lo que dice el tabernero cuando le hablás en un casino: el saludo, lo que rindió la caja fuerte (si hubo), la regla de la casa de esta sala y la próxima prueba.
## `rule`: {name, desc} de casino_rules.gd; `known`: ya la habías escuchado en esta visita; `next`: {trial, left} de la próxima prueba ({} si no quedan).
static func keeper(rule: Dictionary, known: bool, next: Dictionary, greeting: int, vault: int) -> Array:
	var out: Array = [GREETINGS[greeting % GREETINGS.size()]]
	if vault > 0:
		out.append(Loc.f("Ah, y tu caja fuerte rindió: te toca cobrar %d de claridad, con interés.", [vault]))
	var name := Loc.t(str(rule.name))
	var desc := Loc.t(str(rule.desc))
	out.append(Loc.f("Te lo repito: en esta sala rige «%s». %s", [name, desc]) if known else Loc.f("En esta sala rige «%s». %s Mientras estés acá, vale.", [name, desc]))
	if not next.is_empty():
		var t: Dictionary = next.trial
		if int(next.left) == 0:
			out.append(Loc.f("Ojo con lo que viene: la próxima torre es una prueba, «%s». %s", [Loc.t(str(t.name)), Loc.t(str(t.desc))]))
		else:
			out.append(Loc.f("Y ojo: dentro de %d torres te espera una prueba, «%s». %s", [int(next.left) + 1, Loc.t(str(t.name)), Loc.t(str(t.desc))]))
	return out
