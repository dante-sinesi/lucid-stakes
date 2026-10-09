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
	{"id": "catapulta_de_bolsillo", "name": "Catapulta de bolsillo", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 110,
		"desc": "Convierte el bloque que tenés enfrente en una catapulta."},
	{"id": "desarmar", "name": "Desarmar", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 90,
		"desc": "Desactiva una bomba a la vista."},
	# ---- consumibles baratos y bolsas de claridad ----
	{"id": "bolsa_de_luz", "name": "Bolsa de luz", "type": Type.CLARITY, "tier": Tier.CONSUMIBLE, "weight": 6, "mult": 1.4,
		"desc": "Devuelve 1,4 veces lo que pagaste por la ficha, en claridad."},
	{"id": "hielo_a_roca", "name": "Hielo a roca", "type": Type.CONSUMABLE, "tier": Tier.CONSUMIBLE, "weight": 2, "value": 70,
		"desc": "Convierte un bloque de hielo cercano en un bloque normal."},
	{"id": "ancla_chica", "name": "Ancla chica", "type": Type.CONSUMABLE, "tier": Tier.CONSUMIBLE, "weight": 2, "value": 70,
		"desc": "Un bloque de tu elección no cae aunque pierda sus vecinos (una etapa)."},
]


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
