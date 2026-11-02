extends RefCounted
## Estado del run que viaja entre etapas: claridad, boosts, consumibles y etapa actual.
## Los boosts duran todo el run (hay un máximo de lugares, como los comodines de un roguelike de cartas) y los consumibles se gastan.

const Items := preload("res://scripts/datos/items.gd")
const Trials := preload("res://scripts/datos/trials.gd")
const Scenarios := preload("res://scripts/datos/scenarios.gd")
const Loc := preload("res://scripts/idioma/loc.gd")
## Lugares de base: 5 de boosts y 4 de consumibles. Hay boosts que agrandan los lugares (acumulables): "Bolsillo hondo" suma 1
## de consumibles y "Mente abierta" suma 2 de boosts (ella misma ocupa uno, así que de neto es +1).
const BASE_BOOSTS := 5
const BASE_CONSUMABLES := 4
const BOOST_SLOTS_FROM := {"mente_abierta": 2}
const CONSUMABLE_SLOTS_FROM := {"bolsillo_hondo": 1}

var stage := 1
var claridad := 0
var boosts: Array[String] = []
var consumables: Array[String] = []
var showcase := {}        # la vitrina de esta visita al casino (ver showcase.gd)
var free_chip := false    # Ficha gratis: la próxima apuesta no cuesta la ficha (no se guarda: se usa en la misma visita)
var xray := false         # Rayos X: la próxima mano de blackjack muestra la carta tapada del crupier
var toll_bribe := false   # Soborno: Farolín de este casino cobra menos (se gasta al pagar)
var toll_adelanto := 0    # el peaje por adelantado (evento del casino): lo que Farolín ya cobró de esta salida (ver casino_eventos.gd)
var casino_evento := {}   # el evento sorteado para el casino de esta etapa: {stage, id, solo} (casino_eventos.gd); se guarda
var casino_spent := 0   # estadísticas del run
var casino_won := 0
var retries := 0          # reintentos de torre en todo el run
var tower_retries := 0    # reintentos de la torre actual (cada uno cuesta más que el anterior)
var towers_cleared := 0
var claridad_earned := 0  # claridad juntada en las torres superadas
var moves := 0
var max_stage := 1
var dificultad := "media"          # dificultad de La Pesadilla elegida al empezar: facil, media, dificil o pesadilla (ver `Torre.progreso`)
var scenario_id := "pesadilla"      # escenario del run (ver scenarios.gd)
var trial_schedule := {}          # etapa -> id de la prueba que toca (se sortea al empezar el run; ver trials.gd)
var price_mult := 1.0             # multiplicador del precio de la ficha (lo fija el escenario)
var dice_pending := {"luz": 0, "cosmetics": []}   # la Luz y los cosméticos que dieron los dados: pasan al perfil recién al superar una torre (así no se pueden sacar empezando y cerrando)
var meta_consumable_slots := 0   # mejoras permanentes del Despertar (ver profile.gd)
var restart_discount := 0.0
var movs_extra := 0               # movimientos de más en cada sala (Pies ligeros y la mejora Aire de más)
var trials_cleared := 0   # pruebas (etapas especiales) superadas en este run
var bonus_lives := 0       # corazones de más que dan las habilidades persistentes (Corazón extra)
var buena_letra := false   # habilidad Buena letra: un contrato con fianza fallido por partida devuelve la fianza
var buena_letra_usada := false
var toll_meta_discount := 0.0   # lo que baja el peaje de Farolín la habilidad Buen regateo
var lives := MAX_LIVES    # vidas: cuántas veces se puede reintentar después de morir (3 por partida, sin importar la etapa)
var casino_visit := {}    # estado de la visita al casino actual (casino_visit.gd); no se guarda
var claridad_inicio_torre := 0   # la claridad con la que se empezó la torre actual (la Caja fuerte y la Alcancía cobran un porcentaje de eso al entrar al casino)
var alcancia := false    # Alcancía usada: al entrar al próximo casino se cobra
var dados_por_jugar := false   # se superó la torre y todavía no se jugaron los dados del tabernero (si se sale y se vuelve, se retoman en vez de repetir la torre)
var dados_semilla := 0         # la semilla de esos dados: salir y volver no sirve para tirarlos de nuevo y ver si sale algo mejor
var contratos := {}      # el tablón de contratos y los activos (contratos.gd); se guarda
var sello_oro := false   # Sello de oro usado: el próximo contrato que se cobre paga ×5

## Reintentar la torre cuesta claridad: la mitad de la ficha de la ruleta de la etapa, y un poco más por cada reintento
## que ya hiciste en esta misma torre (el primero cuesta 1 vez, el segundo 2 veces, etc.).
const MAX_LIVES := 3
const RESTART_BASE := 25


func scenario() -> Dictionary:
	return Scenarios.get_scenario(scenario_id)


## La prueba de una etapa de este run ({} si es común).
func trial_at(st: int) -> Dictionary:
	return Trials.for_stage(trial_schedule, st)


const TOLL_DISCOUNT := 0.15   # Descuento de Farolín (por cada uno, hasta 2)
const BRIBE_DISCOUNT := 0.30   # Soborno
const INTEREST := 0.25   # Interés: lo que crece la claridad que queda al salir del casino
const INTEREST_CAP := 500   # (con un tope)


## Lo que cobra de verdad Farolín: el precio de la etapa (`toll_for`) con los descuentos (boosts Descuento de Farolín y el Soborno).
func toll_after_discounts(base: int) -> int:
	if base <= 0:
		return 0
	var cut := TOLL_DISCOUNT * float(boosts.count("descuento_duende")) + (BRIBE_DISCOUNT if toll_bribe else 0.0) + toll_meta_discount
	var priced := float(base) * float(scenario().get("toll_mult", 1.0)) * float(toll_dif.get(dificultad, 1.0)) * toll_scale   # (el Usurero cobra de más antes de los descuentos)
	return maxi(int(round(priced * (1.0 - minf(cut, 0.9)))), 1)


## La dificultad con la que se arman las torres: la elegida, y un escalón (o más) por encima si el escenario las hace más difíciles (Gran Casino). Fácil no se corre.
func dificultad_torre() -> String:
	var orden := ["facil", "media", "dificil", "pesadilla"]
	var i := orden.find(dificultad)
	if i < 0 or dificultad == "facil":
		return dificultad
	return orden[clampi(i + int(scenario().get("escalon", 0)), 0, orden.size() - 1)]


## Lo que dan Ahorro y Bolsillo de luz al empezar una torre: una parte del peaje de esa etapa (con un mínimo), así siguen valiendo en las etapas altas.
const AHORRO_PCT := 0.10
const AHORRO_MIN := 20
const BOLSILLO_PCT := 0.20
const BOLSILLO_MIN := 60


static func ahorro_inicial(etapa: int) -> int:
	return maxi(int(round(float(toll_for(etapa)) * toll_scale * AHORRO_PCT)), AHORRO_MIN)


static func bolsillo_inicial(etapa: int) -> int:
	return maxi(int(round(float(toll_for(etapa)) * toll_scale * BOLSILLO_PCT)), BOLSILLO_MIN)


## Al salir del casino: con el boost Interés, la claridad que queda crece (con tope). Devuelve lo que ganó.
func apply_interest() -> int:
	if not boosts.has("interes") or claridad <= 0:
		return 0
	var g := mini(int(round(float(claridad) * INTEREST)), INTEREST_CAP)
	gain(g)
	return g


## La curva de Farolín (docs/diseno.md §46). Se construye sobre lo que rinde una torre (`INGRESO_MEDIDO`;
## lo más que se juntó fue 1,5 veces eso) y tiene una pared: **a partir de la etapa WALL_STAGE el precio supera lo que rinde una torre sin boosts**: hace falta un build (o ahorro),
## y después crece `wall_growth` por etapa. La altura de la pared (`wall_frac`) y el crecimiento se calibran con el bot de balance (docs/economia.md): el bot de habilidad media gana el 15 % en Medio.
## Lo que rinde una torre por etapa siguiendo el camino mínimo de cada sala, sin boosts (medido con `tests/sondas/medir_ingresos.gd`, 30 torres de 7 salas por etapa en dificultad media, un poco suavizado; docs/plan_casinos.md).
const INGRESO_MEDIDO: Array[int] = [232, 297, 380, 396, 423, 432, 450, 440, 430, 430, 434, 436, 440, 450, 490]
static var income_scale := 1.0      # (variables, no constantes: el bot las cambia por variable de entorno para probar curvas, tests/sondas/bot_runs.gd)
static var income_ceil := 1.5       # lo máximo que junta una torre sin boosts, sobre la recta
const WALL_STAGE := 8          # desde acá hay que tener boosts que disparen la ganancia
const HILL_START := 3          # hasta esta etapa el precio es el de siempre; de ahí sube de a poco hasta la pared (la colina)
static var hill_power := 1.25        # 1 = geométrico parejo; más: sube más tarde
static var wall_growth := 1.15      # lo que crece el precio cada etapa después de la pared
## Cuánto cambia la dificultad elegida el peaje de Farolín (Medio es la referencia): las torres difíciles dan más claridad (salas más grandes, con más especiales), así que el peaje sube con ellas, y baja en Fácil. Se calibra con el bot (docs/economia.md).
## Todo el peaje se multiplica por esto: con la ficha más chica, el giro de 3 fichas y la tienda barata (docs/economia.md) los boosts llegan antes, y sin esta suba el bot ganaba el doble o el triple.
static var toll_scale := 1.3
static var toll_dif := {"facil": 0.78, "media": 1.0, "dificil": 1.4, "pesadilla": 1.8}
static var wall_margin := 50        # lo que se suma de más al precio de la pared
static var wall_frac := 0.405       # la pared pide esta fracción de lo máximo que se puede juntar sin boosts (con 1,0 sería imposible de pagar sin boosts; más baja, el juego es más generoso: se calibra con el bot)
static var pre_wall_from := 0.267   # antes de la pared el precio es esta fracción de lo que rinde una torre en la etapa 1...
static var pre_wall_to := 0.754     # ...y esta en la etapa anterior a la pared


## Lo que rinde una torre de esa etapa en promedio.
static func income_fit(stage: int) -> float:
	return float(INGRESO_MEDIDO[clampi(stage, 1, INGRESO_MEDIDO.size()) - 1]) * income_scale


## Lo máximo que puede juntar una torre de esa etapa sin boosts (juego perfecto, con un margen sobre lo medido).
static func income_ceiling(stage: int) -> float:
	return income_ceil * income_fit(stage)


## Cuánto puede tener como mucho un jugador sin boosts al llegar a Farolín de la etapa `stage`: todo lo que juntó (al máximo) en las torres hasta ahí, sin gastar nada en el casino,
## menos lo que ya le cobró Farolín en las etapas anteriores (si pudo pagarlas).
static func max_budget_without_boosts(stage: int) -> float:
	var total := 0.0
	for k in range(1, stage + 1):
		total += income_ceiling(k)
		if k < stage:
			total -= float(toll_for(k))
	return total


## Lo que cobra Farolín de la puerta de salida del casino después de la torre `stage` (la que se acaba de superar).
## Antes de la pared: del 45 % de lo que rinde una torre en la etapa 1 al 75 % en la 7. En la pared: más que todo lo que se pudo juntar sin boosts (el presupuesto máximo), y después crece un 15 % por etapa.
static func toll_for(stage: int) -> int:
	var s := maxi(stage, 1)
	if s <= HILL_START:
		return int(round(_linear_toll(s)))
	var t8 := wall_toll()
	if s < WALL_STAGE:   # la colina: del precio de la etapa HILL_START al de la etapa de la pared, geométrico (con hill_power > 1 sube más tarde)
		return int(round(_hill_toll(s, t8)))
	return int(round(t8 * pow(wall_growth, float(s - WALL_STAGE))))


## El precio de las primeras etapas: una fracción de lo que rinde una torre, de pre_wall_from en la etapa 1 a pre_wall_to en la anterior a la pared.
static func _linear_toll(s: int) -> float:
	return income_fit(s) * (pre_wall_from + (pre_wall_to - pre_wall_from) * float(s - 1) / float(WALL_STAGE - 2))


## El precio de una etapa de la colina (entre HILL_START y la pared) si la pared cobra `t8`.
static func _hill_toll(s: int, t8: float) -> float:
	var t0 := _linear_toll(HILL_START)
	return t0 * pow(t8 / t0, pow(float(s - HILL_START) / float(WALL_STAGE - HILL_START), hill_power))


## El precio en la etapa de la pared: el que no se puede pagar sin boosts aunque se junte el máximo en cada torre y no se gaste nada. Como lo que se pagó en la colina ya no se tiene,
## el precio de la pared depende de los de la colina, y éstos de aquél: se resuelve por iteración (converge enseguida). `wall_margin` se suma de más.
static func wall_toll() -> float:
	var ceilings := 0.0
	for k in range(1, WALL_STAGE + 1):
		ceilings += income_ceiling(k)
	ceilings *= wall_frac
	var t8 := ceilings * 0.5
	for _i in 30:
		var paid := 0.0
		for k in range(1, WALL_STAGE):
			paid += _linear_toll(k) if k <= HILL_START else _hill_toll(k, t8)
		var next := ceilings - paid + float(wall_margin)
		if absf(next - t8) < 0.5:
			t8 = next
			break
		t8 = 0.5 * (t8 + next)
	return t8


## La próxima prueba desde la etapa `from_stage`: {trial, left} ({} si no quedan); `left` son las etapas que faltan (0 = es la de `from_stage`).
func next_trial_info(from_stage: int) -> Dictionary:
	return Trials.next_from(trial_schedule, from_stage)


## Texto de la próxima prueba desde la etapa `from_stage`: "Próxima prueba: Niebla (en 2 etapas)" o "" si no quedan.
func next_trial_text(from_stage: int) -> String:
	var n := Trials.next_from(trial_schedule, from_stage)
	if n.is_empty():
		return ""
	if n.left == 0:
		return Loc.f("Prueba: %s", [Loc.t(n.trial.name)])
	return Loc.f("Próxima prueba: %s (en %d etapa%s)", [Loc.t(n.trial.name), n.left, "" if n.left == 1 else "s"])


## `dead`: se reintenta después de morir: no cuesta claridad (el costo ya es la vida que se pierde; el Tótem la salva). Reiniciar por voluntad sí cuesta.
func restart_cost(dead := false) -> int:
	if dead:
		return 0
	var base := (RESTART_BASE + 2 * maxi(stage - 1, 0)) * (1 + tower_retries)   # (la mitad de la ficha de la ruleta de esa etapa)
	return maxi(int(round(base * (1.0 - restart_discount))), 1)


## Reintentar la torre desde la pausa (por voluntad): cuesta una vida y no gasta claridad. false si no se puede (sin vidas o sin segundas oportunidades).
func pay_voluntary_retry() -> bool:
	if permadeath() or lives <= 0:
		return false
	else:
		lives -= 1
	retries += 1
	tower_retries += 1
	return true


## Anota un reintento de la torre. Después de morir, el Tótem (si lo tenés) lo hace gratis y sin gastar una vida; si no, cuesta una vida.
func note_retry(dead := false) -> void:
	retries += 1
	tower_retries += 1
	var saved_by_totem := false
	if dead and _totem_works():
		use_consumable("totem")
		saved_by_totem = true
	if dead and not saved_by_totem:
		lives = maxi(lives - 1, 0)


## Cuántas vidas se pueden tener a la vez: 3 más las de las habilidades (Corazón extra); un escenario puede fijarlas (Compromiso: 1).
func max_lives() -> int:
	var fixed := int(scenario().get("lives", -1))
	return fixed if fixed > 0 else MAX_LIVES + bonus_lives


## En este escenario morir es el final (no hay segundas oportunidades).
func permadeath() -> bool:
	return bool(scenario().get("permadeath", false))


## ¿Este consumible no sirve en el escenario? (Compromiso inhabilita los Tótems y las Vidas extra.)
func item_blocked(id: String) -> bool:
	return (id == "totem" and bool(scenario().get("no_totem", false))) or (id == "vida_extra" and bool(scenario().get("no_extra_life", false)))


func _totem_works() -> bool:
	return consumables.has("totem") and not item_blocked("totem")


## ¿Se puede reintentar después de morir? (queda alguna vida o hay un Tótem que sirva, y el escenario lo permite)
func can_revive() -> bool:
	return not permadeath() and (lives > 0 or _totem_works())


## Suma una vida (hasta el máximo). false si ya están todas o el escenario no deja recuperarlas.
func add_life() -> bool:
	if lives >= max_lives() or item_blocked("vida_extra"):
		return false
	lives += 1
	return true


func can_afford_restart(dead := false) -> bool:
	return can_afford(restart_cost(dead))


func can_afford(n: int) -> bool:
	return n >= 0 and claridad >= n


func spend(n: int) -> bool:
	if not can_afford(n):
		return false
	claridad -= n
	return true


func gain(n: int) -> void:
	claridad += maxi(n, 0)


func has_boost(id: String) -> bool:
	return boosts.has(id)


## Cuántos boosts caben ahora (los casilleros no son fijos: dependen de los boosts que ya tenés).
func boost_capacity() -> int:
	var n := BASE_BOOSTS
	for id in boosts:
		n += int(BOOST_SLOTS_FROM.get(id, 0))
	return n


## Cuántos consumibles caben ahora.
func consumable_capacity() -> int:
	var n := BASE_CONSUMABLES + meta_consumable_slots
	for id in boosts:
		n += int(CONSUMABLE_SLOTS_FROM.get(id, 0))
	return n


## ¿Hay lugar para este premio? Los boosts son únicos (salvo los que dicen `stack`, que se acumulan) y los dos tipos tienen un máximo.
func has_room_for(item: Dictionary) -> bool:
	match item.type:
		Items.Type.BOOST:
			return boosts.size() < boost_capacity() and ((item.get("stack", false) and boosts.count(item.id) < int(item.get("max_stack", 99))) or not boosts.has(item.id))
		Items.Type.CONSUMABLE:
			return consumables.size() < consumable_capacity()
	return false


## Guarda el premio si hay lugar. Devuelve false si no entra (lo resuelve quien llama, ver Roulette.resolve).
func take(item: Dictionary) -> bool:
	if not has_room_for(item):
		return false
	if item.type == Items.Type.BOOST:
		boosts.append(item.id)
	else:
		consumables.append(item.id)
	return true


## Gasta un consumible: devuelve false si no lo tenés.
func use_consumable(id: String) -> bool:
	var i := consumables.find(id)
	if i < 0:
		return false
	consumables.remove_at(i)
	return true


## Por qué no se puede tirar el ítem de ese casillero ("" si se puede). Un boost que agranda las barras no se tira si lo demás ya no entraría.
func discard_error(kind: String, index: int) -> String:
	var list: Array = boosts if kind == "boost" else consumables
	if index < 0 or index >= list.size():
		return "No hay nada en ese lugar"
	if kind == "boost":
		var after: Array = boosts.duplicate()
		after.remove_at(index)
		var cap_b := BASE_BOOSTS
		var cap_c := BASE_CONSUMABLES + meta_consumable_slots
		for id in after:
			cap_b += int(BOOST_SLOTS_FROM.get(id, 0))
			cap_c += int(CONSUMABLE_SLOTS_FROM.get(id, 0))
		if after.size() > cap_b or consumables.size() > cap_c:
			return "Si lo tiras, lo demás no entraría en las barras"
	return ""


## Tira el ítem de ese casillero (sin recuperar nada). Devuelve el id tirado, o "" si no se pudo.
func discard(kind: String, index: int) -> String:
	if discard_error(kind, index) != "":
		return ""
	var list: Array = boosts if kind == "boost" else consumables
	var id := str(list[index])
	list.remove_at(index)
	return id


func to_dict() -> Dictionary:
	return {"stage": stage, "claridad": claridad, "boosts": boosts.duplicate(), "consumables": consumables.duplicate(),
			"casino_spent": casino_spent, "casino_won": casino_won, "retries": retries, "tower_retries": tower_retries,
			"towers_cleared": towers_cleared, "claridad_earned": claridad_earned, "moves": moves, "max_stage": max_stage, "trials_cleared": trials_cleared,
			"meta_consumable_slots": meta_consumable_slots, "restart_discount": restart_discount, "movs_extra": movs_extra,
			"scenario_id": scenario_id, "dificultad": dificultad, "trial_schedule": _schedule_out(), "price_mult": price_mult, "dice_pending": dice_pending.duplicate(true),
			"claridad_inicio_torre": claridad_inicio_torre, "alcancia": alcancia, "dados_por_jugar": dados_por_jugar, "dados_semilla": dados_semilla, "contratos": contratos.duplicate(true), "sello_oro": sello_oro, "lives": lives, "bonus_lives": bonus_lives, "buena_letra": buena_letra, "buena_letra_usada": buena_letra_usada, "toll_meta_discount": toll_meta_discount, "toll_bribe": toll_bribe, "toll_adelanto": toll_adelanto, "casino_evento": casino_evento.duplicate(), "showcase": showcase.duplicate(true)}


func _schedule_out() -> Dictionary:
	var out := {}
	for st in trial_schedule:
		out[str(st)] = trial_schedule[st]
	return out


static func from_dict(d: Dictionary) -> RefCounted:
	var r = load("res://scripts/datos/run_state.gd").new()
	r.stage = int(d.get("stage", 1))
	r.claridad = int(d.get("claridad", 0))
	for id in d.get("boosts", []):
		if not Items.get_item(str(id)).is_empty():   # (un boost que ya no existe se descarta de la partida guardada)
			r.boosts.append(str(id))
	for id in d.get("consumables", []):
		var cid := str(id)
		if Items.get_item(cid).is_empty():
			continue   # (un consumible que ya no existe: se descarta de la partida guardada)
		r.consumables.append(cid)
	r.casino_spent = int(d.get("casino_spent", 0))
	r.casino_won = int(d.get("casino_won", 0))
	r.retries = int(d.get("retries", 0))
	r.tower_retries = int(d.get("tower_retries", 0))
	r.towers_cleared = int(d.get("towers_cleared", 0))
	r.claridad_earned = int(d.get("claridad_earned", 0))
	r.moves = int(d.get("moves", 0))
	r.max_stage = int(d.get("max_stage", 1))
	r.trials_cleared = int(d.get("trials_cleared", 0))
	r.meta_consumable_slots = int(d.get("meta_consumable_slots", 0))
	r.restart_discount = float(d.get("restart_discount", 0.0))
	r.movs_extra = int(d.get("movs_extra", 0))
	r.scenario_id = str(d.get("scenario_id", "pesadilla"))
	r.dificultad = str(d.get("dificultad", "media"))
	r.price_mult = float(d.get("price_mult", 1.0))
	var dp = d.get("dice_pending", {})
	if dp is Dictionary:
		r.dice_pending = {"luz": int(dp.get("luz", 0)), "cosmetics": []}
		for id in dp.get("cosmetics", []):
			r.dice_pending.cosmetics.append(str(id))
	r.claridad_inicio_torre = int(d.get("claridad_inicio_torre", 0))
	r.alcancia = bool(d.get("alcancia", false))
	r.dados_por_jugar = bool(d.get("dados_por_jugar", false))
	r.dados_semilla = int(d.get("dados_semilla", 0))
	r.contratos = d.get("contratos", {}) if d.get("contratos", {}) is Dictionary else {}
	r.sello_oro = bool(d.get("sello_oro", false))
	r.toll_bribe = bool(d.get("toll_bribe", false))
	r.toll_adelanto = int(d.get("toll_adelanto", 0))
	var cev = d.get("casino_evento", {})
	r.casino_evento = (cev as Dictionary).duplicate() if cev is Dictionary else {}
	var sc = d.get("showcase", {})
	r.showcase = sc.duplicate(true) if sc is Dictionary else {}
	for st in d.get("trial_schedule", {}):
		r.trial_schedule[int(st)] = str(d.trial_schedule[st])
	r.bonus_lives = int(d.get("bonus_lives", 0))
	r.buena_letra = bool(d.get("buena_letra", false))
	r.buena_letra_usada = bool(d.get("buena_letra_usada", false))
	r.toll_meta_discount = float(d.get("toll_meta_discount", 0.0))
	r.lives = clampi(int(d.get("lives", r.max_lives())), 0, r.max_lives())
	return r
