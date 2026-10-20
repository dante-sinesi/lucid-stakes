extends RefCounted
## Escenarios: como los mazos de Balatro, pero cada vez que querés jugar uno hay que pagar su entrada con Luz. La Pesadilla (el juego
## de siempre) es gratis; el resto cambia las reglas del run: qué bloques abundan, el ritmo, el casino o la economía, qué pruebas
## salen (y con eso, qué habilidades persistentes se pueden ganar) y cuánta Luz paga (más cuanto más difícil).
## Un escenario es {id, name, desc, entry (Luz), luz_mult, pool (pruebas que pueden salir), bias (sesgo del generador),
## pace ("" = el de cada etapa), abilities (las habilidades persistentes que se pueden ganar al escapar en este escenario), diff_offset (se suma a la dificultad), casino_tier (-1 = el de la etapa), price_mult (precio de la ficha)}.

const Trials := preload("res://scripts/trials.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const K := TowerLogic.Kind

const FREE := "pesadilla"

## Los escenarios que se pueden elegir hoy en el selector (el tutorial, La Pesadilla y Sin piedad); el resto está definido pero se muestra como "Próximamente" hasta que se les arme su contenido.
const AVAILABLE: Array[String] = ["tutorial", "pesadilla", "sin_piedad"]

## El tutorial no es un escenario (no hay run): es la primera tarjeta del selector de "Nueva partida". Gratis, no da Luz ni habilidades.
const TUTORIAL := {"id": "tutorial", "name": "Tutorial", "entry": 0, "luz_mult": 1.0, "pool": [],
		"desc": "Aprende a escapar con el tabernero: te cuenta la historia de la pesadilla y te enseña, torre por torre, todo lo que hace falta."}

const ALL: Array[Dictionary] = [
	{"id": "pesadilla", "name": "La Pesadilla", "entry": 0, "luz_mult": 1.0,
		"desc": "El juego de siempre: torres de bloques corruptos que se aclaran etapa a etapa. Gratis.",
		"abilities": ["mente_despejada", "ojos_de_gato", "racha_firme"],
		"pool": ["niebla", "oscuridad", "prisa", "sin_ayudas", "todo_o_nada", "sin_racha", "meteoritos"]},
	{"id": "sin_piedad", "name": "Sin piedad", "entry": 25, "luz_mult": 2.0,
		"desc": "Cada sala sólo permite 2 movimientos en falso: uno que te deja más lejos de la salida de la sala. Al tercero pierdes una vida. No se puede deshacer.",
		"abilities": ["margen_de_error"],
		"pool": ["niebla", "oscuridad", "prisa", "sin_ayudas", "sin_racha", "meteoritos"],
		"mistakes": 2, "no_undo": true},
	{"id": "ruinas", "name": "Ruinas", "entry": 15, "luz_mult": 1.5,
		"desc": "Dominan los bloques agrietados y los pesados: casi nada se puede pisar dos veces.",
		"abilities": ["fuerza_bruta"],
		"pool": ["quebradizo", "oscuridad", "sin_ayudas", "todo_o_nada", "sin_racha"],
		"bias": {"kinds": {K.CRACKED: 0.7, K.HEAVY: 0.5}, "cap_bonus": 1}},
	{"id": "polvorin", "name": "Polvorín", "entry": 20, "luz_mult": 1.6,
		"desc": "Bombas por todos lados. La presión no para.",
		"abilities": ["mecha_larga"],
		"pool": ["polvorin", "prisa", "niebla", "sin_ayudas"],
		"bias": {"kinds": {K.BOMB: 0.8}, "cap_bonus": 1}},
	{"id": "relojeria", "name": "Relojería", "entry": 25, "luz_mult": 1.8,
		"desc": "La fila de abajo siempre cae rápido, pero la ficha de la ruleta es más barata.",
		"abilities": ["pies_ligeros"],
		"pool": ["prisa", "niebla", "oscuridad", "todo_o_nada", "sin_racha", "meteoritos"],
		"pace": "fast", "price_mult": 0.75},
	{"id": "compromiso", "name": "Compromiso", "entry": 35, "luz_mult": 2.2,
		"desc": "Una sola vida, sin segundas oportunidades: morir es el final. Los Tótems y las Vidas extra no funcionan. Hay que pasarlo sin caer ni una vez.",
		"abilities": ["corazon_extra"],
		"pool": ["niebla", "oscuridad", "prisa", "sin_ayudas", "sin_racha", "meteoritos"],
		"lives": 1, "permadeath": true, "no_totem": true, "no_extra_life": true},
	{"id": "gran_casino", "name": "Gran Casino", "entry": 30, "luz_mult": 1.4,
		"desc": "El casino es de lujo desde el principio y la ficha es más barata, pero las torres son más difíciles.",
		"abilities": ["bolsillo_sonador", "segunda_oportunidad"],
		"pool": ["niebla", "oscuridad", "prisa", "sin_ayudas", "todo_o_nada", "sin_racha", "meteoritos"],
		"diff_offset": 0.15, "casino_tier": 3, "price_mult": 0.8},
]


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


## Une los sesgos de generación de un escenario y de una prueba (los pesos extra se suman).
static func merge_bias(a: Dictionary, b: Dictionary) -> Dictionary:
	var kinds := {}
	for src in [a.get("kinds", {}), b.get("kinds", {})]:
		for k in src:
			kinds[k] = float(kinds.get(k, 0.0)) + float(src[k])
	return {"kinds": kinds, "plat_ice": float(a.get("plat_ice", 0.0)) + float(b.get("plat_ice", 0.0)),
			"cap_bonus": int(a.get("cap_bonus", 0)) + int(b.get("cap_bonus", 0))}


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
