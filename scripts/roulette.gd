extends RefCounted
## Ruleta de la Luz: reglas puras (sin interfaz). Ver docs/diseno.md §6.
##
## 13 casillas: la 0 es la Pesadilla (la casa, nunca se puede cubrir) y la 1..12 son de Luz. El jugador elige un tipo
## de apuesta, que fija cuántas casillas cubre, y cuáles. Gira la ruleta: si cae en una casilla cubierta gana un
## premio del nivel de esa apuesta; si no, pierde la ficha (la ruleta es el juego de riesgo: no hay red).
## Cuantas menos casillas se cubren, mejor el nivel del premio. El precio de la ficha es fijo por etapa y es el mismo
## para las cuatro apuestas: así rinden casi igual a la larga y la decisión es cuánto riesgo querés.

const Items := preload("res://scripts/items.gd")
const RunState := preload("res://scripts/run_state.gd")
const Loc := preload("res://scripts/loc.gd")

const POCKETS := 13          # casillas 0..12
const HOUSE := 0             # la casa
enum Bet { PLENO, TERNA, MITAD, RANGO }

const BETS := {
	Bet.PLENO: {"name": "Pleno", "count": 1, "tier": Items.Tier.EPICO},
	Bet.TERNA: {"name": "Terna", "count": 3, "tier": Items.Tier.RARO},
	Bet.MITAD: {"name": "Mitad", "count": 6, "tier": Items.Tier.COMUN},
	Bet.RANGO: {"name": "Rango", "count": 9, "tier": Items.Tier.CONSUMIBLE},
}
const BASE_PRICE := 50
## La ficha sube PRICE_STEP por etapa: 50 en la etapa 1 y 102 en la 27. Una torre da, siguiendo el camino mínimo, entre ~190 de
## claridad (etapa 1) y ~390 (etapas altas), así que cada tirada cuesta alrededor de un cuarto de lo que se junta en la etapa.
const PRICE_STEP := 2


## Precio de la ficha en una etapa (igual para las cuatro apuestas).
static func price(stage: int, mult := 1.0) -> int:
	return maxi(int(round((BASE_PRICE + PRICE_STEP * (maxi(stage, 1) - 1)) * mult)), 1)


## Lo que cuesta la ficha en un run (los escenarios pueden abaratarla).
static func run_price(run) -> int:
	return price(run.stage, run.price_mult)


## Probabilidad de ganar una apuesta.
static func probability(bet: int) -> float:
	return float(BETS[bet].count) / POCKETS


## Rendimiento esperado de una apuesta: valor medio del premio × probabilidad ÷ precio de la ficha (1.0 = justo).
static func expected_ratio(bet: int, stage: int) -> float:
	var p := price(stage)
	return probability(bet) * Items.mean_value(BETS[bet].tier, p) / p


## "" si la apuesta es válida; si no, el motivo. `pockets` son las casillas que se cubren.
static func validate(run, bet: int, pockets: Array) -> String:
	if not BETS.has(bet):
		return Loc.t("Apuesta desconocida")
	if pockets.size() != BETS[bet].count:
		return Loc.f("%s cubre %d casillas", [Loc.t(BETS[bet].name), BETS[bet].count])
	var seen := {}
	for c in pockets:
		if c == HOUSE:
			return Loc.t("La casilla 0 es de la casa: no se puede cubrir")
		if c < 1 or c >= POCKETS:
			return Loc.f("La casilla %d no existe", [c])
		if seen.has(c):
			return Loc.t("No se puede cubrir dos veces la misma casilla")
		seen[c] = true
	if not run.can_afford(run_price(run)):
		return Loc.f("No alcanza la claridad (la ficha cuesta %d)", [run_price(run)])
	return ""


## Juega una apuesta: cobra la ficha, gira y paga. `forced_pocket` (>= 0) fija el resultado (para pruebas).
## Devuelve {ok, error, pocket, won, price, prize, converted, claridad_delta}.
static func resolve(run, bet: int, pockets: Array, rng: RandomNumberGenerator, forced_pocket := -1) -> Dictionary:
	var err := validate(run, bet, pockets)
	if err != "":
		return {"ok": false, "error": err}
	var cost := run_price(run)
	run.spend(cost)
	run.casino_spent += cost
	var pocket := forced_pocket if forced_pocket >= 0 else rng.randi_range(0, POCKETS - 1)
	var res := {"ok": true, "error": "", "pocket": pocket, "won": pockets.has(pocket), "price": cost,
			"prize": {}, "converted": false, "claridad_delta": -cost}
	if not res.won:
		return res
	var prize := Items.pick(BETS[bet].tier, rng)
	res.prize = prize
	var reward := 0
	if prize.type == Items.Type.CLARITY:
		reward = int(round(prize.mult * cost))
	elif not run.take(prize):
		# Sin lugar (o boost repetido): se convierte en claridad, la mitad de su valor.
		res.converted = true
		reward = int(round(Items.value_of(prize, cost) * 0.5))
	run.gain(reward)
	run.casino_won += reward
	res.claridad_delta = reward - cost
	return res
