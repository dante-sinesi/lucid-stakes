extends RefCounted
## Servicios del casino: cada nivel de sala tiene una estación propia que no es un juego (reglas puras, sin interfaz; las pantallas están en
## casino_service_screens.gd). Rompen a propósito la regla de que todo es apuesta: son decisiones con precio fijo.
## - Taberna: ninguno (es el primer casino: lo justo para jugar).
## - Salón, "Taller": se vende un boost o consumible por claridad, o se cambia por otro del mismo nivel (se libera lugar en las barras).
## - Casino, "Caja fuerte": se guarda claridad y se cobra con interés en el casino siguiente; mientras tanto no sirve para reintentar.
## - Gran casino, "Seguro": por un precio fijo, el primer reintento de la torre siguiente sale gratis.

const Items := preload("res://scripts/items.gd")
const Roulette := preload("res://scripts/roulette.gd")
const RunState := preload("res://scripts/run_state.gd")
const Loc := preload("res://scripts/loc.gd")

const BY_TIER: Array[String] = ["", "taller", "caja", "seguro"]
const INFO := {
	"taller": {"name": "Taller", "desc": "Vendé un boost o un consumible por claridad, o cambialo por otro del mismo nivel."},
	"caja": {"name": "Caja fuerte", "desc": "Guardá claridad y cobrala con interés en el próximo casino. Mientras tanto no podés usarla."},
	"seguro": {"name": "Seguro", "desc": "Pagá ahora y el primer reintento de la próxima torre sale gratis."},
}
const SELL_FRACTION := 0.4      # el taller paga esta fracción del valor del ítem
const SWAP_FRACTION := 0.3      # cambiar un ítem cuesta esta fracción de la ficha
const VAULT_INTEREST := 0.15    # interés de la caja fuerte por pasar un casino
const INSURANCE_FRACTION := 0.6 # el seguro cuesta esta fracción de lo que costaría ese primer reintento



## El servicio de un nivel de sala ("" si no tiene: la taberna).
static func service_for_tier(tier: int) -> String:
	return BY_TIER[clampi(tier, 0, BY_TIER.size() - 1)]


## Se entra al casino: expira el seguro que quedara sin usar y se paga la caja fuerte de un casino anterior (con interés).
## Devuelve la claridad cobrada de la caja (0 si no había nada que cobrar).
static func enter(run) -> int:
	run.insurance = false
	if run.vault > 0 and run.stage > run.vault_stage:
		var paid := int(round(float(run.vault) * (1.0 + VAULT_INTEREST)))
		run.vault = 0
		run.gain(paid)
		return paid
	return 0


# --- Taller ----------------------------------------------------------------------------------------------------------------

## Lo que paga el taller por un ítem.
static func sell_price(run, id: String) -> int:
	return maxi(int(round(Items.value_of(Items.get_item(id), Roulette.run_price(run)) * SELL_FRACTION)), 1)


static func swap_price(run) -> int:
	return maxi(int(round(Roulette.run_price(run) * SWAP_FRACTION)), 1)


static func _list(run, kind: String) -> Array:
	return run.boosts if kind == "boost" else run.consumables


## ¿Entran los ítems que quedarían? (algunos boosts agrandan las barras: no se puede vender uno si los demás ya no caben)
static func _fits(run, boosts_after: Array, consumables_after: Array) -> bool:
	var slots := RunState.new()
	slots.meta_consumable_slots = run.meta_consumable_slots
	slots.boosts.assign(boosts_after)
	return boosts_after.size() <= slots.boost_capacity() and consumables_after.size() <= slots.consumable_capacity()


## Vende un ítem ("boost" o "consumable", por su lugar en la barra). {ok, error, claridad}.
static func sell(run, kind: String, index: int) -> Dictionary:
	var list := _list(run, kind)
	if index < 0 or index >= list.size():
		return {"ok": false, "error": Loc.t("No hay nada en ese lugar")}
	var id := str(list[index])
	var after: Array = list.duplicate()
	after.remove_at(index)
	if not _fits(run, after if kind == "boost" else run.boosts, after if kind != "boost" else run.consumables):
		return {"ok": false, "error": Loc.t("Si lo vendés, lo demás no entraría en las barras")}
	var price := sell_price(run, id)
	list.remove_at(index)
	run.gain(price)
	return {"ok": true, "error": "", "claridad": price, "id": id}


## Los ítems por los que se puede cambiar uno: mismo tipo y mismo nivel, otro distinto, y (los boosts) que no tengas ya.
static func swap_options(run, kind: String, index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var list := _list(run, kind)
	if index < 0 or index >= list.size():
		return out
	var cur := Items.get_item(str(list[index]))
	for it in Items.ALL:
		if it.type != cur.type or it.tier != cur.tier or it.id == cur.id or not Items.is_available(it):
			continue
		if it.type == Items.Type.BOOST and list.has(it.id) and not it.get("stack", false):
			continue
		out.append(it)
	return out


## Cambia un ítem por otro al azar de su mismo nivel (cobra SWAP_FRACTION de la ficha). {ok, error, old, new}.
static func swap(run, kind: String, index: int, rng: RandomNumberGenerator) -> Dictionary:
	var list := _list(run, kind)
	if index < 0 or index >= list.size():
		return {"ok": false, "error": Loc.t("No hay nada en ese lugar")}
	var options := swap_options(run, kind, index)
	if options.is_empty():
		return {"ok": false, "error": Loc.t("No hay otro del mismo nivel para cambiar")}
	var price := swap_price(run)
	if not run.can_afford(price):
		return {"ok": false, "error": Loc.f("No alcanza la claridad (cambiar cuesta %d)", [price])}
	var pick: Dictionary = options[rng.randi() % options.size()]
	var after: Array = list.duplicate()
	after[index] = pick.id
	if not _fits(run, after if kind == "boost" else run.boosts, after if kind != "boost" else run.consumables):
		return {"ok": false, "error": Loc.t("Si lo cambiás, lo demás no entraría en las barras")}
	run.spend(price)
	var old := str(list[index])
	list[index] = pick.id
	return {"ok": true, "error": "", "old": old, "new": pick.id, "price": price}


# --- Caja fuerte -----------------------------------------------------------------------------------------------------------

## Guarda claridad en la caja. {ok, error}. Se cobra, con interés, en el casino siguiente.
static func deposit(run, amount: int) -> Dictionary:
	if amount <= 0:
		return {"ok": false, "error": Loc.t("No hay nada para guardar")}
	if not run.can_afford(amount):
		return {"ok": false, "error": Loc.t("No tenés tanta claridad")}
	run.spend(amount)
	run.vault += amount
	run.vault_stage = run.stage
	return {"ok": true, "error": ""}


## Lo que se cobraría al pasar un casino (con el interés).
static func vault_payout(run) -> int:
	return int(round(float(run.vault) * (1.0 + VAULT_INTEREST)))


## Saca lo guardado ahora mismo, sin interés. Devuelve lo retirado.
static func withdraw(run) -> int:
	var n: int = run.vault
	run.vault = 0
	run.gain(n)
	return n


# --- Seguro ----------------------------------------------------------------------------------------------------------------

## Cuánto costaría el primer reintento de la próxima torre (sin seguro).
static func first_retry_cost(run) -> int:
	return maxi(int(round(float(RunState.RESTART_BASE + 2 * run.stage) * (1.0 - run.restart_discount))), 1)


static func insurance_price(run) -> int:
	return maxi(int(round(float(first_retry_cost(run)) * INSURANCE_FRACTION)), 1)


## Contrata el seguro. {ok, error}.
static func buy_insurance(run) -> Dictionary:
	if run.insurance:
		return {"ok": false, "error": Loc.t("Ya tenés seguro para la próxima torre")}
	var price := insurance_price(run)
	if not run.can_afford(price):
		return {"ok": false, "error": Loc.f("No alcanza la claridad (el seguro cuesta %d)", [price])}
	run.spend(price)
	run.insurance = true
	return {"ok": true, "error": "", "price": price}
