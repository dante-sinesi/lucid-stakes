extends RefCounted
## Ruleta de la Luz: reglas puras (sin interfaz). Ver docs/diseno.md §6.
##
## 13 casillas, cada una con una rareza (ver `WHEEL`): una épica, dos raras, cuatro comunes y seis de bolsas de claridad. No hay apuestas ni se pierde: pagas el giro, la bola cae
## en una casilla y te llevas un premio de esa rareza, uno de los de la vitrina de la visita (que se puede rotar pagando, ver showcase.gd). El giro cuesta `SPIN_MULT` fichas:
## con todas las casillas premiadas, lo que rinde de media es casi lo que cuesta. Las fichas siguen siendo la unidad de precio del resto del casino (tragamonedas, blackjack, vitrina...).

const Items := preload("res://scripts/datos/items.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Loc := preload("res://scripts/idioma/loc.gd")
const Rules := preload("res://scripts/casino/casino_visit.gd")
const Showcase := preload("res://scripts/casino/showcase.gd")

const POCKETS := 13          # casillas 0..12
## La rareza de cada casilla de la rueda, siempre igual (repartidas parejo para que se vean).
const WHEEL: Array[int] = [Items.Tier.EPICO, Items.Tier.CONSUMIBLE, Items.Tier.COMUN, Items.Tier.CONSUMIBLE, Items.Tier.RARO, Items.Tier.CONSUMIBLE, Items.Tier.COMUN,
		Items.Tier.CONSUMIBLE, Items.Tier.RARO, Items.Tier.COMUN, Items.Tier.CONSUMIBLE, Items.Tier.COMUN, Items.Tier.CONSUMIBLE]
## Cómo se llama cada rareza en la rueda y en qué orden se muestran.
const TIER_NAMES := {Items.Tier.EPICO: "Épico", Items.Tier.RARO: "Raro", Items.Tier.COMUN: "Común", Items.Tier.CONSUMIBLE: "Bolsas"}
const TIER_ORDER: Array[int] = [Items.Tier.EPICO, Items.Tier.RARO, Items.Tier.COMUN, Items.Tier.CONSUMIBLE]
const SECOND_SPIN := 0.2     # Segunda vuelta (boost): chance de que, si cae en una casilla común, la ruleta gire de nuevo sin costo

static var base_price := 75   # (variables: el bot las cambia por variable de entorno)
## La ficha sube PRICE_STEP por etapa. Una torre rinde, siguiendo el camino mínimo (medido con el bot, docs/economia.md), unos 230 de claridad en la etapa 1 y entre 400 y 490 desde la 4:
## la ficha ronda un 20 % de eso desde la etapa 4.
static var price_step := 6
## Las tres primeras etapas (la taberna) tienen la ficha más chica, para que después del peaje alcance para jugar: es esta fracción de la que daría la fórmula.
static var chica_mult: Array = [0.45, 0.70, 0.72]
## Cuántas fichas cuesta un giro de la ruleta (se calibra para que el rendimiento medio ronde el 95 %: ver `expected_ratio`).
static var spin_mult := 3.0


## Precio de la ficha en una etapa (la unidad de precio del casino: también de lo que valen los premios).
static func price(stage: int, mult := 1.0) -> int:
	var s := maxi(stage, 1)
	var chica := float(chica_mult[s - 1]) if s <= chica_mult.size() else 1.0
	return maxi(int(round((base_price + price_step * (s - 1)) * chica * mult)), 1)


## Lo que cuesta la ficha en un run (los escenarios pueden abaratarla).
static func run_price(run) -> int:
	var cheaper: float = minf(0.2 * float(run.boosts.count("ficha_barata")), 0.6)   # (Ficha barata: −20 % cada una)
	return price(run.stage, run.price_mult * (1.0 - cheaper))


## Lo que cuesta un giro de la ruleta en un run.
static func spin_price(run) -> int:
	return maxi(int(round(float(run_price(run)) * spin_mult)), 1)


## Lo que se cobra de verdad por una apuesta: la ficha (o el giro), o nada si se usó una Ficha gratis (que se gasta acá).
static func chip_charge(run, ficha: int) -> int:
	if run.free_chip:
		run.free_chip = false
		return 0
	return ficha


## La rareza de cada casilla en este run: la rueda de siempre, y con Casilla de regalo una de las comunes pasa a ser épica.
static func wheel_tiers(run = null) -> Array[int]:
	var out: Array[int] = WHEEL.duplicate()
	if run != null and run.boosts.has("casilla_de_regalo"):
		var k := out.find(Items.Tier.COMUN)
		if k >= 0:
			out[k] = Items.Tier.EPICO
	return out


## Cuántas casillas de la rueda tiene cada rareza.
static func count_of(tier: int, run = null) -> int:
	return wheel_tiers(run).count(tier)


## Probabilidad de que un giro caiga en una casilla de esa rareza.
static func probability(tier: int, run = null) -> float:
	return float(count_of(tier, run)) / POCKETS


## Rendimiento esperado de un giro en una etapa: lo que valen de media los premios (cada rareza por la cantidad de casillas que tiene) ÷ lo que cuesta el giro (1.0 = justo).
static func expected_ratio(stage: int, run = null) -> float:
	var p := price(stage)
	var total := 0.0
	for tier in [Items.Tier.EPICO, Items.Tier.RARO, Items.Tier.COMUN, Items.Tier.CONSUMIBLE]:
		total += probability(tier, run) * Items.mean_value(tier, p)
	return total / (float(p) * spin_mult)


## "" si se puede girar; si no, el motivo.
static func validate(run) -> String:
	if not run.can_afford(spin_price(run)):
		return Loc.f("No alcanza la claridad (el giro cuesta %d)", [spin_price(run)])
	return ""


## Una vuelta de la bola: la casilla en la que cae y su rareza.
static func _one_spin(run, rng: RandomNumberGenerator, forced_pocket: int) -> Dictionary:
	var pocket := forced_pocket if forced_pocket >= 0 else rng.randi_range(0, POCKETS - 1)
	return {"pocket": pocket, "tier": wheel_tiers(run)[pocket]}


## Gira: cobra el giro, la bola cae en una casilla (con Segunda vuelta, si es común, a veces gira otra vez sin costo) y paga un premio de la vitrina de esa rareza.
## `forced_pocket` (>= 0) fija la casilla que cae (para pruebas; si hay segunda vuelta, la primera).
## Devuelve {ok, error, pocket, tier, price, charge, prize, converted, second_spin, first_pocket, claridad_delta, rules}.
static func resolve(run, rng: RandomNumberGenerator, forced_pocket := -1) -> Dictionary:
	var err := validate(run)
	if err != "":
		return {"ok": false, "error": err}
	var cost := spin_price(run)
	var charge := chip_charge(run, cost)
	run.spend(charge)
	run.casino_spent += charge
	var spin := _one_spin(run, rng, forced_pocket)
	var res := {"ok": true, "error": "", "pocket": spin.pocket, "tier": spin.tier, "price": cost, "charge": charge, "prize": {}, "converted": false,
			"second_spin": false, "first_pocket": spin.pocket, "claridad_delta": -charge}
	if spin.tier == Items.Tier.COMUN and run.boosts.has("segunda_vuelta") and rng.randf() < SECOND_SPIN:
		var again := _one_spin(run, rng, -1)
		res.second_spin = true
		res.pocket = again.pocket
		res.tier = again.tier
	var prize := Showcase.pick(run, int(res.tier), rng)   # (de la vitrina de la visita; no sale lo que ya tienes ni lo que el escenario inhabilita)
	res.prize = prize
	var unit := run_price(run)
	var reward := 0
	if prize.type == Items.Type.CLARITY:
		reward = int(round(prize.mult * unit))
	elif not run.take(prize):
		# Sin lugar (o boost repetido): se convierte en claridad, la mitad de su valor.
		res.converted = true
		reward = int(round(Items.value_of(prize, unit) * 0.5))
	run.gain(reward)
	run.casino_won += reward
	res.claridad_delta = reward - charge
	return _with_rules(run, res, cost, reward, (prize.type != Items.Type.CLARITY and not res.converted) or reward >= cost)


## Aplica lo que valga de la sala (casino_visit.gd) a un giro: los extras que pagan más la claridad ganada (Mesa caliente, Doble o nada...). `win`: se anota como ganado (se llevó un ítem o una bolsa que paga más que el giro). La ruleta nunca pierde: no cuenta para
## la racha, el pozo ni la devolución, que son de las mesas con apuestas.
static func _with_rules(run, res: Dictionary, cost: int, reward: int, win: bool) -> Dictionary:
	var rules: Dictionary = Rules.settle(run, cost, reward, win, false, "ruleta", false)
	res["rules"] = rules
	res.claridad_delta = reward + int(rules.total) - int(res.get("charge", cost))
	return res
