extends RefCounted
## Estado del run que viaja entre etapas: claridad, boosts, consumibles y etapa actual.
## Los boosts duran todo el run (hay un máximo de lugares, como los jokers de Balatro) y los consumibles se gastan.

const Items := preload("res://scripts/items.gd")
const Trials := preload("res://scripts/trials.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
const Loc := preload("res://scripts/loc.gd")
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
var casino_spent := 0   # estadísticas del run
var casino_won := 0
var retries := 0          # reintentos de torre en todo el run
var tower_retries := 0    # reintentos de la torre actual (cada uno cuesta más que el anterior)
var towers_cleared := 0
var claridad_earned := 0  # claridad juntada en las torres superadas
var moves := 0
var max_stage := 1
var scenario_id := "pesadilla"      # escenario del run (ver scenarios.gd)
var trial_schedule := {}          # etapa -> id de la prueba que toca (se sortea al empezar el run; ver trials.gd)
var price_mult := 1.0             # multiplicador del precio de la ficha (lo fija el escenario)
var dice_claridad := 0          # claridad ganada con los dados de la pantalla de carga (tiene tope por partida)
var meta_consumable_slots := 0   # mejoras permanentes del Despertar (ver profile.gd)
var restart_discount := 0.0
var collapse_bonus := 0
var trials_cleared := 0   # pruebas (etapas especiales) superadas en este run
var casino_visit := {}    # estado de la visita al casino actual (casino_rules.gd); no se guarda

## Reintentar la torre cuesta claridad: la mitad de la ficha de la ruleta de la etapa, y un poco más por cada reintento
## que ya hiciste en esta misma torre (el primero cuesta 1 vez, el segundo 2 veces, etc.).
const RESTART_BASE := 25
const DICE_CAP := 150   # tope de claridad que se puede ganar con los dados en una partida


func scenario() -> Dictionary:
	return Scenarios.get_scenario(scenario_id)


## La prueba de una etapa de este run ({} si es común).
func trial_at(st: int) -> Dictionary:
	return Trials.for_stage(trial_schedule, st)


## Texto de la próxima prueba desde la etapa `from_stage`: "Próxima prueba: Niebla (en 2 etapas)" o "" si no quedan.
func next_trial_text(from_stage: int) -> String:
	var n := Trials.next_from(trial_schedule, from_stage)
	if n.is_empty():
		return ""
	if n.left == 0:
		return Loc.f("Prueba: %s", [Loc.t(n.trial.name)])
	return Loc.f("Próxima prueba: %s (en %d etapa%s)", [Loc.t(n.trial.name), n.left, "" if n.left == 1 else "s"])


func restart_cost() -> int:
	var base := (RESTART_BASE + maxi(stage - 1, 0)) * (1 + tower_retries)
	return maxi(int(round(base * (1.0 - restart_discount))), 1)


func can_afford_restart() -> bool:
	return can_afford(restart_cost())


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
			return boosts.size() < boost_capacity() and (item.get("stack", false) or not boosts.has(item.id))
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


func to_dict() -> Dictionary:
	return {"stage": stage, "claridad": claridad, "boosts": boosts.duplicate(), "consumables": consumables.duplicate(),
			"casino_spent": casino_spent, "casino_won": casino_won, "retries": retries, "tower_retries": tower_retries,
			"towers_cleared": towers_cleared, "claridad_earned": claridad_earned, "moves": moves, "max_stage": max_stage, "trials_cleared": trials_cleared,
			"meta_consumable_slots": meta_consumable_slots, "restart_discount": restart_discount, "collapse_bonus": collapse_bonus,
			"scenario_id": scenario_id, "trial_schedule": _schedule_out(), "price_mult": price_mult, "dice_claridad": dice_claridad}


func _schedule_out() -> Dictionary:
	var out := {}
	for st in trial_schedule:
		out[str(st)] = trial_schedule[st]
	return out


static func from_dict(d: Dictionary) -> RefCounted:
	var r = load("res://scripts/run_state.gd").new()
	r.stage = int(d.get("stage", 1))
	r.claridad = int(d.get("claridad", 0))
	for id in d.get("boosts", []):
		r.boosts.append(str(id))
	for id in d.get("consumables", []):
		r.consumables.append(str(id))
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
	r.collapse_bonus = int(d.get("collapse_bonus", 0))
	r.scenario_id = str(d.get("scenario_id", "pesadilla"))
	r.price_mult = float(d.get("price_mult", 1.0))
	r.dice_claridad = int(d.get("dice_claridad", 0))
	for st in d.get("trial_schedule", {}):
		r.trial_schedule[int(st)] = str(d.trial_schedule[st])
	return r
