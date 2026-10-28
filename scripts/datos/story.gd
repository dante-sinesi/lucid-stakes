extends RefCounted
## Los textos de la historia del tutorial, dichos por el tabernero: la bienvenida en la taberna (el lore de la pesadilla), lo que dice
## en cada lección (ver tutorial.gd) y el cierre en el salón de piedra, donde explica las habilidades, la Luz, los escenarios y las
## pruebas. Una línea es un texto o {text, icon}: con `icon` ("luz" o "claridad") el cuadro de diálogo muestra ese ícono al costado,
## así se habla de la moneda sin escribir su nombre.

const Loc := preload("res://scripts/idioma/loc.gd")

const SPEAKER := "Tabernero"

## Etapa de la sala donde pasa cada escena (define cómo es la sala: la taberna y el salón de piedra).
const INTRO_STAGE := 1
const OUTRO_STAGE := 4

const BLOCKED_TABLE := "Primero el portal de atrás, soñador. Después hablamos de apuestas."


static func intro() -> Array:
	return [
		"Pasa, soñador. Qué cara... ¿es tu primera vez por aquí?",
		"Esto es una pesadilla, la tuya, hecha con tus recuerdos. Y los recuerdos se corrompen.",
		{"text": "Si llegaste hasta aquí es porque te queda claridad: lo que todavía no se corrompió.", "icon": "claridad"},
		"Se sale devolviéndole claridad a tu pesadilla, torre por torre. No es fácil.",
		"¿Ves ese portal de atrás? Cruza y te enseñaré cómo se anda por aquí.",
	]


## Lo que dice el tabernero en cada lección del tutorial (en su voz): sólo lore, sin hablar de teclas (la ayuda de arriba lo hace). Una tecla y se va.
const LESSONS := {
	"moverse": "Los recuerdos se corrompen, pero caminar no se olvida. Llega hasta el bloque dorado.",
	"camara": "Algunas cosas se entienden mejor desde otro ángulo. Gira la vista.",
	"empujar": "Si el camino no alcanza, hay que moverlo. Empuja el bloque de enfrente: será tu primer escalón.",
	"tirar": "Y si un bloque te estorba, también se arrastra: camina alejándote de él y se vendrá contigo.",
	"colgarse": "Un borde no siempre es el final: agárrate de él y rodéalo.",
	"soltarse": "A veces uno ve el precipicio y... tiene que saltar. Cuélgate del borde y suéltate.",
	"torre": "Esta ya es una torre de verdad. Cuidado: si caminas mucho, el suelo empieza a caer. ¿Te animas?",
}


## Lo que dice el tabernero cuando se abren los dados (se explica el juego y sus premios).
static func dice_intro() -> Array:
	return [
		"¡Qué agilidad, soñador! Probemos tu suerte.",
		"Tienes 5 dados. Elige el número que esperas en cada uno y tíralos: los que aciertan se quedan. Puedes tirar hasta 3 veces.",
		{"text": "Con dos aciertos ganas claridad. Con cinco, muchísima, y un cosmético.", "icon": "claridad"},
	]


static func lesson_say(id: String, fallback := "") -> String:
	return LESSONS.get(id, fallback)


static func outro() -> Array:
	return [
		"¡Lo lograste, soñador! Ya sabes moverte, empujar, tirar, colgarte y soltarte. Con eso se sube cualquier torre.",
		"Este salón es más claro que mi taberna, ¿verdad? Cada torre que superes te dará más claridad.",
		"Aquí puedes jugar a la ruleta: si ganas, te doy consumibles o habilidades para las próximas torres. Solo te cobro claridad.",
		"Y mira quién está en la puerta: Farolín.",
		"Fue un soñador como tú. Se quedó cuidando la salida y, de tanto alumbrarla, terminó convertido en farol.",
		"Su llama te muestra el camino a la próxima torre, y se paga con claridad. Fíjate en el precio arriba a la izquierda: se pone verde cuando te alcanza.",
		"Si no te alcanza, puedes volver a subir la torre, pero cuesta una vida. Sin vidas, o pagas o todo se apaga.",
		"Mi vitrina cambia en cada visita: ahí ves los premios de la ruleta, y puedes rotarla pagando. En la tienda compras directo, pero sale más caro que apostar.",
		"Lo que ganes te hace juntar más claridad por torre. Y ojo: Farolín cobra más en cada etapa.",
		"Cada tres torres la pesadilla te pone a prueba y cambia las reglas.",
		"Si superas todos los pisos, te llevas una habilidad para siempre.",
		{"text": "Y esto que brilla también te lo deja la pesadilla. No sé para qué sirve, pero es lindo, ¿no?", "icon": "luz"},
		"Eso es todo, soñador. Acércate a Farolín: te presto la claridad para tu primer peaje. ¡Y después, a despertar!",
	]


## Los saludos del tabernero en los casinos (va rotando).
const GREETINGS := [
	"Siéntate, soñador. Aquí la claridad se juega, no se regala.",
	"Cada ficha es un pedazo de despertar. ¿Cuánto vas a arriesgar?",
	"La casa siempre gana... salvo cuando recuerdas despertar.",
]


## Lo que dice el tabernero cuando le hablás en un casino: el saludo, lo que rindieron tus ahorros al entrar (si hubo) y la próxima prueba.
## `next`: {trial, left} de la próxima prueba ({} si no quedan).
static func keeper(next: Dictionary, greeting: int, ahorro: int) -> Array:
	var out: Array = [GREETINGS[greeting % GREETINGS.size()]]
	if ahorro > 0:
		out.append(Loc.f("Ah, y tus ahorros rindieron: te tocó cobrar %d de claridad.", [ahorro]))
	if not next.is_empty():
		var t: Dictionary = next.trial
		if int(next.left) == 0:
			out.append(Loc.f("Ojo con lo que viene: la próxima torre es una prueba, «%s». %s", [Loc.t(str(t.name)), Loc.t(str(t.desc))]))
		else:
			out.append(Loc.f("Y ojo: dentro de %d torres te espera una prueba, «%s». %s", [int(next.left) + 1, Loc.t(str(t.name)), Loc.t(str(t.desc))]))
	return out
