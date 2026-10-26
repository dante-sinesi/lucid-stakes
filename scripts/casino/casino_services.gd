extends RefCounted
## Servicios del casino: cada nivel de sala tiene una estación propia que no es un juego (reglas puras, sin interfaz; las pantallas están en
## casino_service_screens.gd). Rompen a propósito la regla de que todo es apuesta: son decisiones con precio fijo.
## - Taberna: ninguno (es el primer casino: lo justo para jugar).
## - Salón, "Taller": se vende un boost o consumible por claridad, o se cambia por otro del mismo nivel (se libera lugar en las barras).
## - Casino y gran casino: ninguno (el ahorro ahora son un boost y un consumible: Caja fuerte y Alcancía; ver `enter`).

const Items := preload("res://scripts/datos/items.gd")
const Roulette := preload("res://scripts/casino/roulette.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Loc := preload("res://scripts/idioma/loc.gd")

const BY_TIER: Array[String] = ["", "taller", "", ""]
const INFO := {
	"taller": {"name": "Taller", "desc": "Vende un boost o un consumible por claridad, o cámbialo por otro del mismo nivel."},
	"tablon": {"name": "Tablón de contratos", "desc": "Papeles con tareas para la próxima torre. Acéptalos gratis: se cobran en cuanto los cumples. Puedes tener pocos a la vez."},
	"tienda": {"name": "Tienda", "desc": "Tres premios de esta visita, a la venta: caro, pero seguro (sin tirar la ruleta)."},
}
const SELL_FRACTION := 0.4      # el taller paga esta fracción del valor del ítem
const SWAP_FRACTION := 0.3      # cambiar un ítem cuesta esta fracción de la ficha
const CAJA_FUERTE := 0.15       # lo que cobra el boost Caja fuerte al entrar al casino: esta parte de la claridad con la que empezaste la torre
const ALCANCIA := 0.30          # y el consumible Alcancía, una vez



## El servicio de un nivel de sala ("" si no tiene: la taberna).
static func service_for_tier(tier: int) -> String:
	return BY_TIER[clampi(tier, 0, BY_TIER.size() - 1)]


## Se entra al casino: se cobra la Caja fuerte (boost: un porcentaje de la claridad con la que empezaste la torre que acabas de subir) y la Alcancía (consumible ya usado: otro porcentaje,
## una sola vez). Devuelve la claridad cobrada (0 si no había nada que cobrar).
static func enter(run) -> int:
	var parte := 0.0
	if run.boosts.has("caja_fuerte"):
		parte += CAJA_FUERTE
	if run.alcancia:
		parte += ALCANCIA
		run.alcancia = false
	var paid := int(round(float(run.claridad_inicio_torre) * parte))
	if paid > 0:
		run.gain(paid)
	return paid


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
		return {"ok": false, "error": Loc.t("Si lo vendes, lo demás no entraría en las barras")}
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
		return {"ok": false, "error": Loc.t("Si lo cambias, lo demás no entraría en las barras")}
	run.spend(price)
	var old := str(list[index])
	list[index] = pick.id
	return {"ok": true, "error": "", "old": old, "new": pick.id, "price": price}
