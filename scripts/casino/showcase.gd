extends RefCounted
## La vitrina del casino (docs/diseno.md §47): en cada visita la ruleta no sortea entre todo el catálogo, sino entre unos pocos premios por nivel que se ven (y se pueden rotar pagando).
## Además el sorteo ya no incluye lo que no sirve (un boost que ya tenés, o lo que el escenario bloquea). El estado vive en `run.showcase`:
##   {stage, tiers: {"<nivel>": [ids]}, rotations, shop: [ids], sold: [ids]}   (se sortea una vez por visita; `shop` son las ofertas de la tienda)

const Items := preload("res://scripts/datos/items.gd")
const Roulette := preload("res://scripts/casino/roulette.gd")

## Cuántos premios muestra la vitrina por nivel.
const COUNTS := {Items.Tier.EPICO: 3, Items.Tier.RARO: 4, Items.Tier.COMUN: 4, Items.Tier.CONSUMIBLE: 4}
## Lo que cuesta en la tienda un premio medio de cada nivel, en fichas (con la ficha de la etapa 4: unos 140, 280 y 560): el común entra siempre, el raro con algo de ahorro y el épico es una meta de dos o tres visitas.
const SHOP_FICHAS := {Items.Tier.COMUN: 2.25, Items.Tier.RARO: 4.5, Items.Tier.EPICO: 9.0}
const SHOP_REL_MIN := 0.75   # cuánto se corre el precio de cada premio según lo que vale respecto del medio de su nivel
const SHOP_REL_MAX := 1.35
const SHOP_TIERS: Array = [Items.Tier.EPICO, Items.Tier.RARO, Items.Tier.COMUN]   # una oferta de cada nivel (sólo boosts y consumibles, no bolsas)


## ¿Se puede ganar este premio? (un boost que ya tenés y no se acumula, o que el escenario bloquea, no)
static func valid(run, it: Dictionary) -> bool:
	if run.item_blocked(str(it.id)):
		return false
	if it.type == Items.Type.BOOST:
		if not run.boosts.has(it.id):
			return true
		return it.get("stack", false) and run.boosts.count(it.id) < int(it.get("max_stack", 99))
	return true


## Los premios del nivel que se pueden ganar ahora (si no queda ninguno, todos los del nivel).
static func valid_pool(run, tier: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it in Items.by_tier(tier):
		if valid(run, it):
			out.append(it)
	return out if not out.is_empty() else Items.by_tier(tier)


static func _sample(pool: Array[Dictionary], n: int, rng: RandomNumberGenerator) -> Array:
	var left := pool.duplicate()
	var out: Array = []
	while out.size() < n and not left.is_empty():
		var wsum := 0.0
		for it in left:
			wsum += float(it.weight)
		var r := rng.randf() * wsum
		var k := left.size() - 1
		for i in left.size():
			r -= float(left[i].weight)
			if r <= 0.0:
				k = i
				break
		out.append(left[k].id)
		left.remove_at(k)
	return out


## Sortea la vitrina de esta visita (y las ofertas de la tienda). `keep_rotations`: se rota dentro de la misma visita.
static func generate(run, rng: RandomNumberGenerator, keep_rotations := false) -> void:
	var tiers := {}
	for tier in COUNTS:
		tiers[str(tier)] = _sample(valid_pool(run, tier), int(COUNTS[tier]), rng)
	var sc: Dictionary = run.showcase if keep_rotations else {}
	var shop: Array = sc.get("shop", []) if keep_rotations else []
	var sold: Array = sc.get("sold", []) if keep_rotations else []
	if shop.is_empty():
		for tier in SHOP_TIERS:
			var offered: Array[Dictionary] = []
			for it in valid_pool(run, tier):
				if it.type != Items.Type.CLARITY:
					offered.append(it)
			shop.append_array(_sample(offered, 1, rng))
	run.showcase = {"stage": run.stage, "tiers": tiers, "rotations": int(sc.get("rotations", 0)) if keep_rotations else 0, "shop": shop, "sold": sold}


## Se entra al casino: si la vitrina no es de esta etapa, se sortea una nueva.
static func enter(run, rng: RandomNumberGenerator) -> void:
	if run.showcase.is_empty() or int(run.showcase.get("stage", -1)) != run.stage:
		generate(run, rng)


static func rotations(run) -> int:
	return int(run.showcase.get("rotations", 0))


## Lo que cuesta rotar la vitrina: una ficha, y una más por cada rotación que ya se hizo en esta visita.
static func rotate_cost(run) -> int:
	if rotations(run) == 0 and run.boosts.has("llave_de_la_vitrina"):   # (Llave de la vitrina: la primera rotación de la visita es gratis)
		return 0
	return Roulette.run_price(run) * (1 + rotations(run))


## Rota la vitrina pagando. false si no alcanza.
static func rotate(run, rng: RandomNumberGenerator) -> bool:
	var cost := rotate_cost(run)
	if not run.spend(cost):
		return false
	var n := rotations(run) + 1
	generate(run, rng, true)
	run.showcase["rotations"] = n
	return true


## Los premios de la vitrina para ese nivel (los que todavía se pueden ganar). Sin vitrina (pruebas, entrenamiento) es el catálogo del nivel.
static func pool(run, tier: int) -> Array[Dictionary]:
	if run.showcase.is_empty():
		return valid_pool(run, tier)
	var out: Array[Dictionary] = []
	for id in run.showcase.get("tiers", {}).get(str(tier), []):
		var it := Items.get_item(str(id))
		if not it.is_empty() and valid(run, it):
			out.append(it)
	return out if not out.is_empty() else valid_pool(run, tier)


## Sortea un premio de la vitrina para ese nivel, ponderado por el peso de cada uno.
static func pick(run, tier: int, rng: RandomNumberGenerator) -> Dictionary:
	var p := pool(run, tier)
	var wsum := 0.0
	for it in p:
		wsum += float(it.weight)
	var r := rng.randf() * wsum
	for it in p:
		r -= float(it.weight)
		if r <= 0.0:
			return it
	return p[p.size() - 1]


## Lo que cuesta un premio en la tienda: las fichas de su nivel, algo más o menos según lo que vale ese premio respecto del medio de su nivel.
static func shop_price(run, it: Dictionary) -> int:
	var ficha := Roulette.run_price(run)
	var tier := int(it.tier)
	var base: float = float(SHOP_FICHAS.get(tier, 3.0)) * ficha
	var medio := Items.mean_value(tier, ficha)
	var rel := clampf(Items.value_of(it, ficha) / medio, SHOP_REL_MIN, SHOP_REL_MAX) if medio > 0.0 else 1.0
	return maxi(int(round(base * rel)), 1)


## Las ofertas de la tienda de esta visita que no se compraron: [premio, ...].
static func shop_offers(run) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sold: Array = run.showcase.get("sold", [])
	for id in run.showcase.get("shop", []):
		var it := Items.get_item(str(id))
		if not it.is_empty() and not sold.has(id):
			out.append(it)
	return out


## Compra una oferta: {ok, error}. Hace falta claridad y lugar (si no entra, se vende algo en el taller).
static func buy(run, id: String) -> Dictionary:
	var it := Items.get_item(id)
	if it.is_empty() or not run.showcase.get("shop", []).has(id) or run.showcase.get("sold", []).has(id):
		return {"ok": false, "error": "Ese premio ya no está"}
	var price := shop_price(run, it)
	if not run.can_afford(price):
		return {"ok": false, "error": "No alcanza la claridad"}
	if not run.has_room_for(it):
		return {"ok": false, "error": "No tienes lugar: vende algo en el taller"}
	run.spend(price)
	run.take(it)
	run.showcase["sold"].append(id)
	return {"ok": true, "error": "", "price": price}
