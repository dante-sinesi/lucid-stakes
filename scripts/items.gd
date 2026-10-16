extends RefCounted
## Catálogo de premios del casino: boosts (mejoras que duran el run), consumibles (se gastan) y bolsas de claridad.
## Los efectos están implementados en TowerLogic (apply_perks para los boosts, use_item para los consumibles).
##
## Los premios se agrupan en niveles (Tier): cuanto más difícil la apuesta, mejor el nivel. `value` es el valor de
## cada premio en "claridad equivalente" y sirve para balancear la ruleta (ver Roulette.expected_ratio); las bolsas de
## claridad valen `mult` veces el precio de la ficha.

enum Tier { CONSUMIBLE, COMUN, RARO, EPICO }
enum Type { BOOST, CONSUMABLE, CLARITY }

const ALL: Array[Dictionary] = [
	# ---- épicos: sólo boosts (muy poderosos) ----
	{"id": "segundo_aliento", "name": "Segundo aliento", "type": Type.BOOST, "tier": Tier.EPICO, "weight": 1, "value": 640,
		"desc": "Una vez por etapa, si caés al vacío volvés a la última plataforma firme."},
	{"id": "madrugada", "name": "Madrugada", "type": Type.BOOST, "tier": Tier.EPICO, "weight": 1, "value": 620,
		"desc": "La fila de abajo cae al doble de lento durante toda la etapa."},
	{"id": "luz_propia", "name": "Luz propia", "type": Type.BOOST, "tier": Tier.EPICO, "weight": 1, "value": 600,
		"desc": "Al pisar un bloque también se purifican los vecinos."},
	{"id": "mano_de_oro", "name": "Mano de oro", "type": Type.BOOST, "tier": Tier.EPICO, "weight": 1, "value": 620,
		"desc": "La racha sube el multiplicador de a 1,0 en vez de 0,5."},
	# ---- raros: boosts ----
	{"id": "pies_de_luz", "name": "Pies de luz", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 200,
		"desc": "Purificar un bloque da +1 de claridad."},
	{"id": "paso_firme", "name": "Paso firme", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 220,
		"desc": "Trepar y bajar escalones no cuenta para la caída de la fila base."},
	{"id": "reflejos", "name": "Reflejos", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 200,
		"desc": "Las cuentas de las bombas empiezan 3 movimientos más altas."},
	{"id": "bolsillo_hondo", "name": "Bolsillo hondo", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 200, "stack": true,
		"desc": "Suma 1 lugar de consumibles. Se acumula."},
	{"id": "mente_abierta", "name": "Mente abierta", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 220, "stack": true,
		"desc": "Suma 2 lugares de boosts (ocupa uno). Se acumula."},
	{"id": "racha_larga", "name": "Racha larga", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 220,
		"desc": "El tope del multiplicador de racha sube de ×4 a ×6."},
	# ---- comunes: boosts y consumibles ----
	{"id": "aire_extra", "name": "Aire extra", "type": Type.BOOST, "tier": Tier.COMUN, "weight": 1, "value": 100,
		"desc": "La fila de abajo cae 1 movimiento más tarde."},
	{"id": "ojo_de_hielo", "name": "Ojo de hielo", "type": Type.BOOST, "tier": Tier.COMUN, "weight": 1, "value": 90,
		"desc": "Al resbalar por el hielo te frenás una celda antes."},
	{"id": "ahorro", "name": "Ahorro", "type": Type.BOOST, "tier": Tier.COMUN, "weight": 1, "value": 110,
		"desc": "Cada etapa arrancás con 20 de claridad."},
	{"id": "freno", "name": "Freno", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 100,
		"desc": "Pausa la caída de la fila base durante 5 movimientos."},
	{"id": "desarmar", "name": "Desarmar", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 90,
		"desc": "Desactiva una bomba a la vista."},
	# ---- conversores: uno por tipo de bloque; se elige con el mouse el bloque que se cambia ----
	{"id": "conv_roca", "name": "Polvo de roca", "type": Type.CONSUMABLE, "tier": Tier.CONSUMIBLE, "weight": 0.4, "value": 60, "target": true,
		"desc": "Convierte cualquier bloque en roca (un bloque común). Se elige con el mouse."},
	{"id": "conv_hielo", "name": "Escarcha", "type": Type.CONSUMABLE, "tier": Tier.CONSUMIBLE, "weight": 0.4, "value": 60, "target": true,
		"desc": "Convierte cualquier bloque en hielo. Se elige con el mouse."},
	{"id": "conv_agrietado", "name": "Grieta", "type": Type.CONSUMABLE, "tier": Tier.CONSUMIBLE, "weight": 0.4, "value": 60, "target": true,
		"desc": "Convierte cualquier bloque en uno agrietado (se rompe al bajarte de él). Se elige con el mouse."},
	{"id": "conv_trampa", "name": "Cebo", "type": Type.CONSUMABLE, "tier": Tier.CONSUMIBLE, "weight": 0.4, "value": 60, "target": true,
		"desc": "Convierte cualquier bloque en una trampa (se desarma al pisarla). Se elige con el mouse."},
	{"id": "conv_pinchos", "name": "Espinas", "type": Type.CONSUMABLE, "tier": Tier.CONSUMIBLE, "weight": 0.4, "value": 60, "target": true,
		"desc": "Convierte cualquier bloque en pinchos (no se pueden pisar). Se elige con el mouse."},
	{"id": "conv_pesado", "name": "Plomo", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 90, "target": true,
		"desc": "Convierte cualquier bloque en uno pesado (no se empuja ni se tira). Se elige con el mouse."},
	{"id": "conv_bomba", "name": "Pólvora", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 90, "target": true,
		"desc": "Convierte cualquier bloque en una bomba con cuenta de 6. Se elige con el mouse."},
	{"id": "conv_catapulta", "name": "Resorte", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 100, "target": true,
		"desc": "Convierte cualquier bloque en una catapulta. Se elige con el mouse."},
	# ---- otros consumibles ----
	{"id": "escudo", "name": "Escudo", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 110, "passive": true,
		"desc": "Si explota una bomba, no te afecta; el escudo se rompe. Se gasta solo."},
	{"id": "doble_salto", "name": "Doble salto", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 110,
		"desc": "Tu próximo salto sube 2 bloques en vez de 1."},
	{"id": "totem", "name": "Tótem", "type": Type.CONSUMABLE, "tier": Tier.RARO, "weight": 1, "value": 200, "passive": true,
		"desc": "Si morís, reintentás la torre sin costo (ni claridad ni una vida). Se gasta solo."},
	{"id": "vida_extra", "name": "Vida extra", "type": Type.CONSUMABLE, "tier": Tier.RARO, "weight": 1, "value": 220,
		"desc": "Te da una vida más. Sólo se puede usar si tenés menos de 3."},
	{"id": "teletransporte", "name": "Teletransporte", "type": Type.CONSUMABLE, "tier": Tier.RARO, "weight": 1, "value": 190, "target": true,
		"desc": "Elegí con el mouse un bloque a 5 cubos o menos de vos y aparecés encima."},
	# ---- consumibles baratos y bolsas de claridad ----
	{"id": "bolsa_de_luz", "name": "Bolsa de luz", "type": Type.CLARITY, "tier": Tier.CONSUMIBLE, "weight": 6, "mult": 1.4,
		"desc": "Devuelve 1,4 veces lo que pagaste por la ficha, en claridad."},
	{"id": "ancla_chica", "name": "Ancla chica", "type": Type.CONSUMABLE, "tier": Tier.CONSUMIBLE, "weight": 2, "value": 70,
		"desc": "Un bloque de tu elección no cae aunque pierda sus vecinos (una etapa)."},
	# ---- los que disparan la ganancia (docs/diseno.md §47): sin ellos no se pasa de la etapa 8 (la pared del duende, §46) ----
	# épicos
	{"id": "cosecha_doble", "name": "Cosecha doble", "type": Type.BOOST, "tier": Tier.EPICO, "weight": 1, "value": 650,
		"desc": "Toda la claridad que juntás en la torre vale el doble."},
	{"id": "racha_imparable", "name": "Racha imparable", "type": Type.BOOST, "tier": Tier.EPICO, "weight": 1, "value": 620,
		"desc": "Empujar y tirar no cortan la racha, y el tope del multiplicador sube a ×8."},
	{"id": "midas", "name": "Midas", "type": Type.BOOST, "tier": Tier.EPICO, "weight": 1, "value": 640,
		"desc": "Purificar un bloque da +3 de claridad."},
	# raros
	{"id": "cosecha", "name": "Cosecha", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 230,
		"desc": "La claridad que juntás en la torre vale ×1,5 (se multiplica con Cosecha doble)."},
	{"id": "pies_de_oro", "name": "Pies de oro", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 215,
		"desc": "Purificar un bloque da +2 de claridad (suma con Pies de luz)."},
	{"id": "buen_ojo", "name": "Buen ojo", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 200,
		"desc": "Los bloques especiales dan el doble de claridad al purificarlos."},
	{"id": "escalador", "name": "Escalador", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 210,
		"desc": "Cada piso nuevo que alcanzás por primera vez da claridad de más."},
	{"id": "empuje_rentable", "name": "Empuje rentable", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 190,
		"desc": "Cada bloque que empujás o tirás da +1 de claridad."},
	{"id": "interes", "name": "Interés", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 215,
		"desc": "Al salir del casino, la claridad que te queda crece un 25 % (con un tope)."},
	{"id": "descuento_duende", "name": "Descuento del duende", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 220, "stack": true, "max_stack": 2,
		"desc": "El duende cobra un 15 % menos. Se acumula (hasta 2)."},
	{"id": "lluvia_de_luz", "name": "Lluvia de luz", "type": Type.CONSUMABLE, "tier": Tier.RARO, "weight": 1, "value": 200,
		"desc": "Purifica todos los bloques de tu capa."},
	{"id": "soborno", "name": "Soborno", "type": Type.CONSUMABLE, "tier": Tier.RARO, "weight": 1, "value": 190, "casino": true,
		"desc": "Se usa en el casino: el duende cobra un 30 % menos esta vez."},
	# comunes
	{"id": "bolsillo_de_luz", "name": "Bolsillo de luz", "type": Type.BOOST, "tier": Tier.COMUN, "weight": 1, "value": 100,
		"desc": "Empezás cada torre con claridad de regalo."},
	{"id": "pocion_de_cosecha", "name": "Poción de cosecha", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 100,
		"desc": "La claridad de esta torre vale el doble (se multiplica con los boosts)."},
	{"id": "iman_de_luz", "name": "Imán de luz", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 95,
		"desc": "Purifica de golpe todos los bloques a 2 cubos o menos de vos."},
	{"id": "baraja_de_racha", "name": "Baraja de racha", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 90,
		"desc": "La racha pasa a ×4 ya."},
	{"id": "reloj_de_arena", "name": "Reloj de arena", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 95,
		"desc": "Pausa la caída de la fila base durante 10 movimientos."},
	# bolsas de claridad grandes (la ficha de la etapa por el multiplicador)
	{"id": "bolsa_pesada", "name": "Bolsa pesada", "type": Type.CLARITY, "tier": Tier.COMUN, "weight": 1.5, "mult": 3.0,
		"desc": "Devuelve 3 veces lo que pagaste por la ficha, en claridad."},
	{"id": "saquito_de_oro", "name": "Saquito de oro", "type": Type.CLARITY, "tier": Tier.RARO, "weight": 0.25, "mult": 6.0,
		"desc": "Devuelve 6 veces lo que pagaste por la ficha, en claridad."},
	{"id": "cofre_de_luz", "name": "Cofre de luz", "type": Type.CLARITY, "tier": Tier.EPICO, "weight": 0.25, "mult": 15.0,
		"desc": "Devuelve 15 veces lo que pagaste por la ficha, en claridad."},
	{"id": "tesoro", "name": "Tesoro del soñador", "type": Type.CLARITY, "tier": Tier.EPICO, "weight": 0.05, "mult": 40.0,
		"desc": "Devuelve 40 veces lo que pagaste por la ficha, en claridad."},
]

## Consumibles que se pueden usar dentro del casino (los demás sólo en la torre).
const CASINO_USABLE: Array[String] = ["vida_extra", "soborno"]


## ¿El consumible se usa eligiendo un bloque con el mouse?
static func needs_target(id: String) -> bool:
	return bool(get_item(id).get("target", false))


## ¿Se usa solo (no se aprieta su tecla)?
static func is_passive(id: String) -> bool:
	return bool(get_item(id).get("passive", false))


static func get_item(id: String) -> Dictionary:
	for it in ALL:
		if it.id == id:
			return it
	return {}


## Premios que hay que desbloquear (en el Despertar, con Luz) no salen en la ruleta hasta tenerlos. `restrict` lo prende el juego
## (profile.gd); las pruebas lo dejan apagado y ven el catálogo completo.
static var restrict := false
static var unlocked := {}


static func is_available(it: Dictionary) -> bool:
	return not restrict or not it.get("locked", false) or unlocked.has(it.id)


## Los premios de un nivel que están disponibles. (Si todos estuvieran bloqueados, salen los del nivel de abajo.)
static func by_tier(tier: int) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for it in ALL:
		if it.tier == tier and is_available(it):
			res.append(it)
	if res.is_empty() and tier > Tier.CONSUMIBLE:
		return by_tier(tier - 1)
	return res


## Valor de un premio en claridad equivalente para una ficha de ese precio.
static func value_of(item: Dictionary, price: int) -> float:
	if item.type == Type.CLARITY:
		return item.mult * price
	return float(item.value) * price / 50.0  # `value` está dado para una ficha de 50: con fichas más caras (etapas altas) todo vale proporcionalmente más


## Valor medio de un nivel, ponderado por el peso de cada premio.
static func mean_value(tier: int, price: int) -> float:
	var total := 0.0
	var wsum := 0.0
	for it in by_tier(tier):
		total += value_of(it, price) * it.weight
		wsum += it.weight
	return total / maxf(wsum, 1.0)


## Sorteo ponderado de un premio del nivel dado.
static func pick(tier: int, rng: RandomNumberGenerator) -> Dictionary:
	var pool := by_tier(tier)
	var wsum := 0.0
	for it in pool:
		wsum += it.weight
	var r := rng.randf() * wsum
	for it in pool:
		r -= it.weight
		if r <= 0.0:
			return it
	return pool[pool.size() - 1]
