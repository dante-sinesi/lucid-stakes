extends RefCounted
## Catálogo de premios del casino: boosts (mejoras que duran el run), consumibles (se gastan) y bolsas de claridad.
## Los efectos están implementados en torre/torre.gd (los movimientos, los consumibles) y torre/cosecha.gd (la claridad).
##
## Los premios se agrupan en niveles (Tier): cuanto más difícil la apuesta, mejor el nivel. `value` es el valor de
## cada premio en "claridad equivalente" y sirve para balancear la ruleta (ver Roulette.expected_ratio); las bolsas de
## claridad valen `mult` veces el precio de la ficha.

const Demo := preload("res://scripts/datos/demo.gd")

## Premios que en la demo no sirven (el blackjack, las tragamonedas y las bombas son del juego completo): no salen en la ruleta, la vitrina ni los premios de las pruebas.
const DEMO_SIN_USO: Array[String] = ["mano_23", "blackjack_de_oro", "rayos_x", "giro_de_cortesia", "reflejos", "desarmar"]

enum Tier { CONSUMIBLE, COMUN, RARO, EPICO }
enum Type { BOOST, CONSUMABLE, CLARITY }

const ALL: Array[Dictionary] = [
	# ---- épicos: sólo boosts (muy poderosos) ----
	{"id": "segundo_aliento", "name": "Segundo aliento", "type": Type.BOOST, "tier": Tier.EPICO, "weight": 1, "value": 640,
		"desc": "Una vez por torre, si pierdes una sala la repites sin perder la vida."},
	{"id": "madrugada", "name": "Madrugada", "type": Type.BOOST, "tier": Tier.EPICO, "weight": 1, "value": 620,
		"desc": "+25 % de movimientos en cada sala."},
	{"id": "luz_propia", "name": "Luz propia", "type": Type.BOOST, "tier": Tier.EPICO, "weight": 1, "value": 600,
		"desc": "Al pisar un bloque también se purifican los vecinos."},
	{"id": "mano_de_oro", "name": "Mano de oro", "type": Type.BOOST, "tier": Tier.EPICO, "weight": 1, "value": 620,
		"desc": "La racha sube de a 1,0 en vez de 0,5."},
	# ---- raros: boosts ----
	{"id": "pies_de_luz", "name": "Pies de luz", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 200,
		"desc": "Purificar un bloque da +1 de claridad."},
	{"id": "paso_firme", "name": "Paso firme", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 220,
		"desc": "Subir y bajar un piso no cuenta como movimiento."},
	{"id": "reflejos", "name": "Reflejos", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 200,
		"desc": "Las bombas empiezan con 3 movimientos más."},
	{"id": "bolsillo_hondo", "name": "Bolsillo hondo", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 200, "stack": true,
		"desc": "+1 lugar de consumibles. Se acumula."},
	{"id": "mente_abierta", "name": "Mente abierta", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 220, "stack": true,
		"desc": "+2 lugares de boosts (ocupa uno). Se acumula."},
	{"id": "racha_larga", "name": "Racha larga", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 220,
		"desc": "El tope de la racha sube de ×4 a ×6."},
	# ---- comunes: boosts y consumibles ----
	{"id": "aire_extra", "name": "Aire extra", "type": Type.BOOST, "tier": Tier.COMUN, "weight": 1, "value": 100,
		"desc": "+4 movimientos en cada sala."},
	{"id": "ahorro", "name": "Ahorro", "type": Type.BOOST, "tier": Tier.COMUN, "weight": 1, "value": 110,
		"desc": "Cada etapa empiezas con 20 de claridad."},
	{"id": "freno", "name": "Freno", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 100,
		"desc": "+5 movimientos en la sala actual."},
	{"id": "desarmar", "name": "Desarmar", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 90,
		"desc": "Desactiva una bomba a la vista."},
	# ---- otros consumibles ----
	{"id": "totem", "name": "Tótem", "type": Type.CONSUMABLE, "tier": Tier.RARO, "weight": 1, "value": 200, "passive": true,
		"desc": "Si mueres, reintentas la torre sin gastar una vida. Se gasta solo."},
	{"id": "vida_extra", "name": "Vida extra", "type": Type.CONSUMABLE, "tier": Tier.RARO, "weight": 1, "value": 220,
		"desc": "+1 vida (solo si tienes menos de 3)."},
	# ---- consumibles baratos y bolsas de claridad ----
	{"id": "bolsa_de_luz", "name": "Bolsa de luz", "type": Type.CLARITY, "tier": Tier.CONSUMIBLE, "weight": 6, "mult": 1.4,
		"desc": "Devuelve 1,4 veces la ficha, en claridad."},
	# ---- los que disparan la ganancia (docs/diseno.md §47): sin ellos no se pasa de la etapa 8 (la pared de Farolín, §46) ----
	# épicos
	{"id": "cosecha_doble", "name": "Cosecha doble", "type": Type.BOOST, "tier": Tier.EPICO, "weight": 1, "value": 650,
		"desc": "La claridad de la torre vale el doble."},
	{"id": "racha_imparable", "name": "Racha imparable", "type": Type.BOOST, "tier": Tier.EPICO, "weight": 1, "value": 620,
		"desc": "Empujar y tirar no cortan la racha. Tope: ×8."},
	{"id": "midas", "name": "Midas", "type": Type.BOOST, "tier": Tier.EPICO, "weight": 1, "value": 640,
		"desc": "Purificar un bloque da +3 de claridad."},
	# raros
	{"id": "cosecha", "name": "Cosecha", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 230,
		"desc": "La claridad de la torre vale ×1,5."},
	{"id": "pies_de_oro", "name": "Pies de oro", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 215,
		"desc": "Purificar un bloque da +2 de claridad."},
	{"id": "buen_ojo", "name": "Buen ojo", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 200,
		"desc": "Los bloques especiales dan el doble de claridad."},
	{"id": "escalador", "name": "Escalador", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 210,
		"desc": "Cada piso nuevo que alcanzas da claridad de más."},
	{"id": "empuje_rentable", "name": "Empuje rentable", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 190,
		"desc": "Cada bloque que empujas o tiras da +1 de claridad."},
	{"id": "interes", "name": "Interés", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 215,
		"desc": "Al salir del casino, tu claridad crece un 25 % (con tope)."},
	{"id": "descuento_duende", "name": "Descuento de Farolín", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 220, "stack": true, "max_stack": 2,
		"desc": "Farolín cobra un 15 % menos. Se acumula (hasta 2)."},
	{"id": "lluvia_de_luz", "name": "Lluvia de luz", "type": Type.CONSUMABLE, "tier": Tier.RARO, "weight": 1, "value": 200,
		"desc": "Purifica todos los bloques de tu capa."},
	{"id": "soborno", "name": "Soborno", "type": Type.CONSUMABLE, "tier": Tier.RARO, "weight": 1, "value": 190, "casino": true,
		"desc": "En el casino: Farolín cobra un 30 % menos esta vez."},
	# comunes
	{"id": "bolsillo_de_luz", "name": "Bolsillo de luz", "type": Type.BOOST, "tier": Tier.COMUN, "weight": 1, "value": 100,
		"desc": "Empiezas cada torre con claridad de regalo."},
	{"id": "pocion_de_cosecha", "name": "Poción de cosecha", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 100,
		"desc": "La claridad de esta torre vale el doble."},
	{"id": "iman_de_luz", "name": "Imán de luz", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 95,
		"desc": "Purifica los bloques a 2 cubos o menos de ti."},
	{"id": "baraja_de_racha", "name": "Baraja de racha", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 90,
		"desc": "La racha pasa a ×4 ya."},
	{"id": "reloj_de_arena", "name": "Reloj de arena", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 95,
		"desc": "+10 movimientos en la sala actual."},
	# del casino (docs/diseno.md §49): sirven en las mesas, no en la torre
	{"id": "mano_23", "name": "Mano de 23", "type": Type.BOOST, "tier": Tier.EPICO, "weight": 1, "value": 640,
		"desc": "En el blackjack el tope es 23 en vez de 21."},
	{"id": "mesa_caliente", "name": "Mesa caliente", "type": Type.BOOST, "tier": Tier.EPICO, "weight": 1, "value": 640,
		"desc": "Todo lo que ganas en el casino paga un 25 % más."},
	{"id": "blackjack_de_oro", "name": "Blackjack de oro", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 210,
		"desc": "El blackjack natural paga 3 a 1 en vez de 3 a 2."},
	{"id": "ficha_barata", "name": "Ficha barata", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 220, "stack": true, "max_stack": 2,
		"desc": "La ficha de todas las mesas cuesta un 20 % menos. Se acumula (hasta 2)."},
	{"id": "casilla_de_regalo", "name": "Casilla de regalo", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 210,
		"desc": "En la ruleta, cada apuesta cubre una casilla más gratis."},
	{"id": "red_de_seguridad", "name": "Red de seguridad", "type": Type.BOOST, "tier": Tier.COMUN, "weight": 1, "value": 100,
		"desc": "Recuperas el 10 % de cada apuesta perdida."},
	{"id": "giro_de_cortesia", "name": "Giro de cortesía", "type": Type.BOOST, "tier": Tier.COMUN, "weight": 1, "value": 90,
		"desc": "En las tragamonedas, volver a girar es gratis."},
	{"id": "llave_de_la_vitrina", "name": "Llave de la vitrina", "type": Type.BOOST, "tier": Tier.COMUN, "weight": 1, "value": 95,
		"desc": "La primera rotación de la vitrina es gratis en cada visita."},
	{"id": "doble_o_nada", "name": "Doble o nada", "type": Type.CONSUMABLE, "tier": Tier.RARO, "weight": 1, "value": 200, "casino": true,
		"desc": "En el casino: lo que ganes en las mesas esta visita vale el doble."},
	{"id": "ficha_gratis", "name": "Ficha gratis", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 95, "casino": true,
		"desc": "En el casino: tu próxima apuesta es gratis."},
	{"id": "rayos_x", "name": "Rayos X", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 90, "casino": true,
		"desc": "En el casino: ves la carta tapada del crupier en tu próxima mano."},
	# los de la visita al casino que antes eran reglas de la casa, y los ahorros que antes eran la Caja fuerte (docs/plan_casinos.md)
	{"id": "racha_de_la_casa", "name": "Racha de la casa", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 210,
		"desc": "En el casino, cada apuesta ganada seguida suma +10 % al pago de la siguiente (hasta +50 %)."},
	{"id": "racha_de_visita", "name": "Racha de visita", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 95, "casino": true,
		"desc": "En el casino: esta visita, cada apuesta ganada seguida suma +10 % al pago de la siguiente (hasta +50 %)."},
	{"id": "pozo_del_jackpot", "name": "Pozo del jackpot", "type": Type.BOOST, "tier": Tier.EPICO, "weight": 1, "value": 600,
		"desc": "Parte de lo que pierdes en el casino va a un pozo; el premio mayor se lo lleva."},
	{"id": "caja_fuerte", "name": "Caja fuerte", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 210,
		"desc": "Al entrar al casino cobras el 15 % de la claridad con que empezaste la torre."},
	{"id": "alcancia", "name": "Alcancía", "type": Type.CONSUMABLE, "tier": Tier.COMUN, "weight": 1, "value": 90, "casino": true,
		"desc": "En el casino: cobras el 30 % de la claridad con que empezaste la torre."},
	# los contratos (docs/plan_casinos.md)
	{"id": "caza_recompensas", "name": "Caza recompensas", "type": Type.BOOST, "tier": Tier.RARO, "weight": 1, "value": 220, "stack": true, "max_stack": 2,
		"desc": "Un contrato activo más. Se acumula (hasta 2)."},
	{"id": "contratista", "name": "Contratista", "type": Type.BOOST, "tier": Tier.EPICO, "weight": 1, "value": 620,
		"desc": "Cada contrato paga el doble."},
	{"id": "sello_de_oro", "name": "Sello de oro", "type": Type.CONSUMABLE, "tier": Tier.RARO, "weight": 1, "value": 200, "casino": true,
		"desc": "En el casino: el próximo contrato que cobres paga ×5."},
	# bolsas de claridad grandes (la ficha de la etapa por el multiplicador)
	{"id": "bolsa_pesada", "name": "Bolsa pesada", "type": Type.CLARITY, "tier": Tier.COMUN, "weight": 1.5, "mult": 3.0,
		"desc": "Devuelve 3 veces la ficha, en claridad."},
	{"id": "saquito_de_oro", "name": "Saquito de oro", "type": Type.CLARITY, "tier": Tier.RARO, "weight": 0.25, "mult": 6.0,
		"desc": "Devuelve 6 veces la ficha, en claridad."},
	{"id": "cofre_de_luz", "name": "Cofre de luz", "type": Type.CLARITY, "tier": Tier.EPICO, "weight": 0.25, "mult": 15.0,
		"desc": "Devuelve 15 veces la ficha, en claridad."},
	{"id": "tesoro", "name": "Tesoro del soñador", "type": Type.CLARITY, "tier": Tier.EPICO, "weight": 0.05, "mult": 40.0,
		"desc": "Devuelve 40 veces la ficha, en claridad."},
]

## Consumibles que se pueden usar dentro del casino (los demás sólo en la torre).
const CASINO_USABLE: Array[String] = ["vida_extra", "soborno", "doble_o_nada", "ficha_gratis", "rayos_x", "racha_de_visita", "alcancia", "sello_de_oro"]


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
	if Demo.on() and DEMO_SIN_USO.has(it.id):
		return false
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
