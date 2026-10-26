extends RefCounted
## Tragamonedas con "retener" (estilo Balatro): reglas puras, sin interfaz.
##
## Tres rodillos con cinco símbolos (cubo, hielo, bomba, sol y corona; los comunes salen más). Se paga una ficha (la misma de la ruleta)
## y giran los tres. Después se puede, UNA vez, retener los rodillos que se quieran y volver a girar los otros pagando media ficha.
## Pagan dos símbolos iguales (poco) o tres iguales (más; la corona, el premio gordo, además da un boost épico). Los pagos son en claridad,
## múltiplos de la ficha. Jugando bien (reteniendo lo que conviene) rinde ~0,91: cada ficha devuelve un poco menos de lo que cuesta.

const Items := preload("res://scripts/datos/items.gd")
const Roulette := preload("res://scripts/casino/roulette.gd")
const Loc := preload("res://scripts/idioma/loc.gd")
const Rules := preload("res://scripts/casino/casino_visit.gd")
const Showcase := preload("res://scripts/casino/showcase.gd")

const SYMBOLS: Array[String] = ["cubo", "hielo", "bomba", "sol", "corona"]
const NAMES: Array[String] = ["Cubo", "Hielo", "Bomba", "Sol", "Corona"]
const WEIGHTS: Array[int] = [7, 5, 3, 2, 1]
## Pago (en fichas) de tres iguales y de exactamente dos iguales, por símbolo.
const TRIPLE: Array[float] = [2.0, 4.0, 9.0, 20.0, 50.0]
const PAIR: Array[float] = [0.3, 0.5, 0.9, 1.4, 2.5]
const REELS := 3
const RESPIN_FRACTION := 0.5   # lo que cuesta volver a girar, como fracción de la ficha
const CROWN := 4

enum Phase { IDLE, HOLD, DONE }

var run
var rng: RandomNumberGenerator
var phase := Phase.IDLE
var reels: Array[int] = [0, 0, 0]
var price := 0
var respins_left := 1
var result := {}


static func random_symbol(random: RandomNumberGenerator) -> int:
	var total := 0
	for w in WEIGHTS:
		total += w
	var r := random.randi() % total
	for i in WEIGHTS.size():
		r -= WEIGHTS[i]
		if r < 0:
			return i
	return 0


## Lo que paga una combinación: {kind: "triple" | "pair" | "none", symbol, mult (en fichas)}.
static func payout(r: Array) -> Dictionary:
	if r[0] == r[1] and r[1] == r[2]:
		return {"kind": "triple", "symbol": r[0], "mult": TRIPLE[r[0]]}
	for i in 3:
		for j in range(i + 1, 3):
			if r[i] == r[j]:
				return {"kind": "pair", "symbol": r[i], "mult": PAIR[r[i]]}
	return {"kind": "none", "symbol": -1, "mult": 0.0}


static func respin_price(ficha: int) -> int:
	return maxi(int(round(ficha * RESPIN_FRACTION)), 1)


func _init(run_state = null, random: RandomNumberGenerator = null) -> void:
	run = run_state
	rng = random if random != null else RandomNumberGenerator.new()


## Paga la ficha y gira los tres rodillos. {ok, error}.
func start() -> Dictionary:
	if phase == Phase.HOLD:
		return {"ok": false, "error": Loc.t("Ya hay una tirada en curso")}
	price = Roulette.run_price(run)
	if not run.can_afford(price):
		return {"ok": false, "error": Loc.f("No alcanza la claridad (la ficha cuesta %d)", [price])}
	var charge := Roulette.chip_charge(run, price)
	run.spend(charge)
	run.casino_spent += charge
	for i in REELS:
		reels[i] = random_symbol(rng)
	respins_left = 1
	result = {}
	phase = Phase.HOLD
	return {"ok": true, "error": ""}


func can_respin() -> bool:
	return phase == Phase.HOLD and respins_left > 0 and (run.boosts.has("giro_de_cortesia") or run.can_afford(respin_price(price)))


## Vuelve a girar los rodillos que NO están retenidos (`held`: tres bools). Cobra media ficha y termina la tirada (paga).
func respin(held: Array) -> Dictionary:
	if not can_respin():
		return {"ok": false, "error": Loc.t("No se puede volver a girar")}
	var all_held := true
	for h in held:
		all_held = all_held and h
	if all_held:
		return {"ok": false, "error": Loc.t("Suelta algún rodillo para volver a girar")}
	var cost := 0 if run.boosts.has("giro_de_cortesia") else respin_price(price)   # (Giro de cortesía: volver a girar es gratis)
	run.spend(cost)
	run.casino_spent += cost
	price += cost   # (lo gastado en la tirada, para el resumen)
	respins_left -= 1
	for i in REELS:
		if not held[i]:
			reels[i] = random_symbol(rng)
	return collect()


## Cobra lo que hay y termina la tirada. {ok, kind, symbol, mult, claridad, spent, item, converted}.
func collect() -> Dictionary:
	if phase != Phase.HOLD:
		return result
	phase = Phase.DONE
	var p := payout(reels)
	var ficha := Roulette.run_price(run)
	var reward := int(round(float(p.mult) * ficha))
	var item := {}
	var converted := false
	if p.kind == "triple" and p.symbol == CROWN:   # el premio gordo trae además un boost épico
		item = Showcase.pick(run, Items.Tier.EPICO, rng)
		if item.type == Items.Type.CLARITY:   # (una bolsa grande: va entera como claridad)
			reward += int(round(float(item.mult) * ficha))
		elif not run.take(item):   # sin lugar (o boost repetido): se convierte en claridad, la mitad de su valor
			converted = true
			reward += int(round(Items.value_of(item, ficha) * 0.5))
	run.gain(reward)
	run.casino_won += reward
	var rules: Dictionary = Rules.settle(run, price, reward, reward >= price or not item.is_empty(), p.kind == "triple" and p.symbol == CROWN, "tragamonedas")
	result = {"ok": true, "kind": p.kind, "symbol": p.symbol, "mult": p.mult, "claridad": reward, "spent": price,
			"item": item, "converted": converted, "reels": reels.duplicate(), "rules": rules}
	return result


## Rendimiento de la mejor estrategia (se calcula exacto: para cada primera tirada se elige entre cobrar o retener lo que más conviene).
## Es lo que usan las pruebas para vigilar que la tragamonedas no regale ni robe.
static func optimal_rtp() -> float:
	var total_w := 0.0
	for w in WEIGHTS:
		total_w += w
	var spent := 0.0
	var won := 0.0
	var p_sym: Array[float] = []
	for w in WEIGHTS:
		p_sym.append(float(w) / total_w)
	for a in 5:
		for b in 5:
			for c in 5:
				var pr: float = p_sym[a] * p_sym[b] * p_sym[c]
				var cur := [a, b, c]
				var best_gain: float = payout(cur).mult
				var best_cost := 0.0
				for mask in range(7):   # 0..6: todas las formas de retener salvo "todos"
					var held := [(mask & 1) != 0, (mask & 2) != 0, (mask & 4) != 0]
					var ev := _ev_hold(cur, held, p_sym)
					if ev - RESPIN_FRACTION > best_gain - best_cost:
						best_gain = ev
						best_cost = RESPIN_FRACTION
				won += pr * best_gain
				spent += pr * (1.0 + best_cost)
	return won / spent


static func _ev_hold(cur: Array, held: Array, p_sym: Array[float]) -> float:
	var total := 0.0
	for a in (5 if not held[0] else 1):
		for b in (5 if not held[1] else 1):
			for c in (5 if not held[2] else 1):
				var r := [cur[0] if held[0] else a, cur[1] if held[1] else b, cur[2] if held[2] else c]
				var pr := 1.0
				if not held[0]:
					pr *= p_sym[a]
				if not held[1]:
					pr *= p_sym[b]
				if not held[2]:
					pr *= p_sym[c]
				total += pr * float(payout(r).mult)
	return total
