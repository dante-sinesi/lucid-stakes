extends RefCounted
## Escenarios: como los mazos de Balatro, pero cada vez que querés jugar uno hay que pagar su entrada con Luz. La Pesadilla (el juego
## de siempre) es gratis; el resto cambia las reglas del run: qué bloques abundan, el casino o la economía, qué pruebas
## salen (y con eso, qué habilidades persistentes se pueden ganar) y cuánta Luz paga (más cuanto más difícil).
## Un escenario es {id, name, desc, entry (Luz), luz_mult, pool (pruebas que pueden salir), abilities (las habilidades persistentes que se pueden ganar al escapar en este escenario),
## casino_tier (-1 = el de la etapa), price_mult (precio de la ficha), lives, permadeath, no_totem, no_extra_life, mistakes, no_undo,
## y las reglas propias: escalon (la dificultad de las torres sube tantos escalones), margen_mov (multiplica el margen de movimientos de cada sala), contratos {activos_extra, nuevos_extra, premio_mult},
## especiales_desde (la etapa desde la que se habilitan todos los bloques especiales), peso_especiales (la fracción de las salas que tienen especiales), toll_mult (lo que cobra Farolín) y premio_mult (los premios de las mesas)}.

const Trials := preload("res://scripts/datos/trials.gd")

const FREE := "pesadilla"

## Los escenarios que se pueden elegir hoy en el selector (el tutorial, La Pesadilla y los seis que cambian las reglas del juego).
const AVAILABLE: Array[String] = ["tutorial", "pesadilla", "sin_piedad", "compromiso", "gran_casino", "relojeria", "contratista", "mundo_abierto", "usurero"]

## Las dificultades que se pueden elegir en cada escenario: La Pesadilla tiene las cuatro; los demás, sin Fácil (el modo de práctica con movimientos ilimitados y pista les quitaría sentido a sus reglas).
const DIFICULTADES_PESADILLA: Array[String] = ["facil", "media", "dificil", "pesadilla"]
const DIFICULTADES_ESCENARIO: Array[String] = ["media", "dificil", "pesadilla"]

## El tutorial no es un escenario (no hay run): es la primera tarjeta del selector de "Nueva partida". Gratis, no da Luz ni habilidades.
const TUTORIAL := {"id": "tutorial", "name": "Tutorial", "entry": 0, "luz_mult": 1.0, "pool": [],
		"desc": "Aprende a escapar con el tabernero: te cuenta la historia de la pesadilla y te enseña, torre por torre, todo lo que hace falta."}

## Los escenarios cambian las reglas del juego y no qué salas salen (la biblioteca no alcanza para torres de un solo tema sin que dejen de parecer aleatorias; docs/escenarios_propuestas.md).
const ALL: Array[Dictionary] = [
	{"id": "pesadilla", "name": "La Pesadilla", "entry": 0, "luz_mult": 1.0,
		"desc": "El juego de siempre: torres de bloques corruptos que se aclaran etapa a etapa. Gratis.",
		"abilities": ["mente_despejada", "ojos_de_gato", "racha_firme"],
		"pool": ["sin_ayudas", "todo_o_nada", "sin_racha", "travesuras"]},
	{"id": "sin_piedad", "name": "El camino corto", "entry": 25, "luz_mult": 2.0,
		"desc": "Cada sala sólo permite 2 movimientos en falso: uno que te deja más lejos de la salida de la sala. Al tercero pierdes una vida. No se puede deshacer.",
		"abilities": ["margen_de_error"],
		"pool": ["sin_ayudas", "sin_racha", "travesuras"],
		"mistakes": 2, "no_undo": true},
	{"id": "compromiso", "name": "Compromiso", "entry": 35, "luz_mult": 2.2,
		"desc": "Una sola vida, sin segundas oportunidades: morir es el final. Los Tótems y las Vidas extra no funcionan. Hay que pasarlo sin caer ni una vez.",
		"abilities": ["corazon_extra"],
		"pool": ["sin_ayudas", "sin_racha", "travesuras"],
		"lives": 1, "permadeath": true, "no_totem": true, "no_extra_life": true},
	{"id": "gran_casino", "name": "Gran Casino", "entry": 30, "luz_mult": 1.4,
		"desc": "El casino es de lujo desde el principio y la ficha es más barata, pero las torres son un escalón más difíciles.",
		"abilities": ["bolsillo_sonador", "segunda_oportunidad"],
		"pool": ["sin_ayudas", "todo_o_nada", "sin_racha", "travesuras"],
		"casino_tier": 3, "price_mult": 0.8, "escalon": 1},
	{"id": "relojeria", "name": "Relojería", "entry": 25, "luz_mult": 1.8,
		"desc": "Cada sala da menos movimientos, pero la ficha de la ruleta es más barata.",
		"abilities": ["pies_ligeros"],
		"pool": ["todo_o_nada", "sin_racha", "travesuras"],
		"price_mult": 0.75, "margen_mov": 0.5},
	{"id": "contratista", "name": "Contratista", "entry": 20, "luz_mult": 1.5,
		"desc": "El tablón manda: cuatro contratos activos a la vez, más papeles nuevos en cada visita y recompensas y fianzas un 50 % mayores.",
		"abilities": ["buena_letra"],
		"pool": ["sin_ayudas", "sin_racha", "travesuras"],
		"contratos": {"activos_extra": 2, "nuevos_extra": 2, "premio_mult": 1.5}},
	{"id": "mundo_abierto", "name": "Mundo abierto", "entry": 30, "luz_mult": 2.0,
		"desc": "Todos los bloques especiales aparecen desde la primera etapa y las salas con especiales salen mucho más seguido.",
		"abilities": ["mecha_larga"],
		"pool": ["sin_ayudas", "todo_o_nada", "travesuras"],
		"especiales_desde": 1, "peso_especiales": 0.6},
	{"id": "usurero", "name": "Usurero", "entry": 20, "luz_mult": 1.5,
		"desc": "Farolín cobra un 40 % más en cada peaje, pero el casino paga más: la ficha cuesta un 30 % menos y los premios valen un 25 % más.",
		"abilities": ["buen_regateo"],
		"pool": ["sin_ayudas", "todo_o_nada", "travesuras"],
		"price_mult": 0.7, "toll_mult": 1.4, "premio_mult": 1.25},
]


## Las dificultades que se pueden elegir al empezar este escenario ([] = ninguna: el tutorial).
static func difficulties(id: String) -> Array[String]:
	if id == FREE:
		return DIFICULTADES_PESADILLA
	if id == TUTORIAL.id:
		return []
	return DIFICULTADES_ESCENARIO


## Una regla propia del escenario (o el valor por omisión si no la tiene).
static func rule(id: String, key: String, default = null):
	return get_scenario(id).get(key, default)


## ¿Se puede jugar este escenario desde el selector? (los demás dicen "Próximamente")
static func playable(id: String) -> bool:
	return AVAILABLE.has(id)


static func get_scenario(id: String) -> Dictionary:
	if id == TUTORIAL.id:
		return TUTORIAL
	for s in ALL:
		if s.id == id:
			return s
	return get_scenario(FREE) if id != FREE else {}


## Las habilidades persistentes que se pueden ganar en un escenario (al escapar de la pesadilla en él).
static func ability_ids(scn: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id in scn.get("abilities", []):
		out.append(str(id))
	return out


## Los escenarios donde se puede ganar una habilidad.
static func scenarios_for_ability(ability_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in ALL:
		if ability_ids(s).has(ability_id):
			out.append(s)
	return out
