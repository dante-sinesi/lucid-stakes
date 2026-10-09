extends RefCounted
## Escenarios: como los mazos de Balatro, pero cada vez que querés jugar uno hay que pagar su entrada con Luz. La Pesadilla (el juego
## de siempre) es gratis; el resto cambia las reglas del run: qué bloques abundan, el ritmo, el casino o la economía, qué pruebas
## salen (y con eso, qué habilidades persistentes se pueden ganar) y cuánta Luz paga (más cuanto más difícil).
## Un escenario es {id, name, desc, entry (Luz), luz_mult, pool (pruebas que pueden salir), bias (sesgo del generador),
## pace ("" = el de cada etapa), diff_offset (se suma a la dificultad), casino_tier (-1 = el de la etapa), price_mult (precio de la ficha)}.

const Trials := preload("res://scripts/trials.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const K := TowerLogic.Kind

const FREE := "pesadilla"

## El tutorial no es un escenario (no hay run): es la primera tarjeta del selector de "Nueva partida". Gratis, no da Luz ni habilidades.
const TUTORIAL := {"id": "tutorial", "name": "Tutorial", "entry": 0, "luz_mult": 1.0, "pool": [],
		"desc": "Aprendé a escapar con el tabernero: te cuenta la historia de la pesadilla y te enseña, torre por torre, todo lo que hace falta."}

const ALL: Array[Dictionary] = [
	{"id": "pesadilla", "name": "La Pesadilla", "entry": 0, "luz_mult": 1.0,
		"desc": "El juego de siempre: torres de bloques corruptos que se aclaran etapa a etapa. Gratis.",
		"pool": ["niebla", "oscuridad", "prisa", "sin_ayudas", "todo_o_nada", "sin_racha"]},
	{"id": "glaciar", "name": "Glaciar", "entry": 15, "luz_mult": 1.5,
		"desc": "Torres cubiertas de hielo, desde la primera etapa. Leer cada resbalón es todo.",
		"pool": ["hielo_total", "niebla", "prisa", "sin_racha", "todo_o_nada"],
		"bias": {"kinds": {K.ICE: 0.9}, "plat_ice": 0.18, "cap_bonus": 1}},
	{"id": "ruinas", "name": "Ruinas", "entry": 15, "luz_mult": 1.5,
		"desc": "Dominan los bloques agrietados y los pesados: casi nada se puede pisar dos veces.",
		"pool": ["quebradizo", "oscuridad", "sin_ayudas", "todo_o_nada", "sin_racha"],
		"bias": {"kinds": {K.CRACKED: 0.7, K.HEAVY: 0.5}, "cap_bonus": 1}},
	{"id": "polvorin", "name": "Polvorín", "entry": 20, "luz_mult": 1.6,
		"desc": "Bombas por todos lados. La presión no para.",
		"pool": ["polvorin", "prisa", "niebla", "sin_ayudas"],
		"bias": {"kinds": {K.BOMB: 0.8}, "cap_bonus": 1}},
	{"id": "relojeria", "name": "Relojería", "entry": 25, "luz_mult": 1.8,
		"desc": "La fila de abajo siempre cae rápido, pero la ficha de la ruleta es más barata.",
		"pool": ["prisa", "niebla", "oscuridad", "todo_o_nada", "sin_racha"],
		"pace": "fast", "price_mult": 0.75},
	{"id": "gran_casino", "name": "Gran Casino", "entry": 30, "luz_mult": 1.4,
		"desc": "El casino es de lujo desde el principio y la ficha es más barata, pero las torres son más difíciles.",
		"pool": ["niebla", "oscuridad", "prisa", "sin_ayudas", "todo_o_nada", "sin_racha"],
		"diff_offset": 0.15, "casino_tier": 3, "price_mult": 0.8},
]


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


## Los nombres de las habilidades que se pueden ganar en un escenario (las de las pruebas de su sorteo).
static func ability_ids(scn: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id in scn.get("pool", []):
		var a: String = Trials.CATALOG[id].ability
		if not out.has(a):
			out.append(a)
	return out
