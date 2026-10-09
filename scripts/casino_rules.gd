extends RefCounted
## Reglas de la casa: cada nivel de sala (taberna, salón, casino, gran casino) paga distinto, en las tres mesas (ruleta, tragamonedas, blackjack).
## - Taberna, "Fiado": la primera apuesta que perdés en cada visita te devuelve la mitad de lo perdido.
## - Salón, "Racha": cada apuesta ganada seguida suma +10 % al pago de la siguiente (hasta +50 %); perder la corta.
## - Casino, "Apuesta libre": en las tragamonedas y el blackjack se puede apostar 1, 2, 3 o 5 fichas juntas (paga proporcional).
## - Gran casino, "Jackpot": parte de lo que se pierde en la sala va a un pozo, y el premio mayor (tres coronas, blackjack, pleno) se lo lleva.
## El estado de la visita vive en `run.casino_visit` (se arma al entrar a la sala, `enter`); si está vacío (pruebas, entrenamiento) no hay reglas.

const Loc := preload("res://scripts/loc.gd")

const RULES := [
	{"id": "fiado", "name": "Fiado", "desc": "La primera apuesta que perdés en cada visita te devuelve la mitad de lo perdido."},
	{"id": "racha", "name": "Racha", "desc": "Cada apuesta ganada seguida suma +10 % al pago de la siguiente (hasta +50 %). Perder la corta."},
	{"id": "libre", "name": "Apuesta libre", "desc": "En las tragamonedas y el blackjack podés apostar 1, 2, 3 o 5 fichas juntas."},
	{"id": "jackpot", "name": "Jackpot", "desc": "Lo que perdés en la sala va a un pozo, y el premio mayor (tres coronas, blackjack o pleno) se lo lleva."},
]
const STAKES: Array[int] = [1, 2, 3, 5]
const FIADO_REFUND := 0.5        # fracción de lo perdido que devuelve el fiado
const STREAK_STEP := 0.1         # lo que suma cada victoria seguida (desde la segunda)
const STREAK_MAX := 5            # tope del extra: 5 pasos de 10 % (+50 %)
const POOL_SHARE := 0.5          # fracción de lo perdido que va al pozo del jackpot


static func rule_of(tier: int) -> Dictionary:
	return RULES[clampi(tier, 0, RULES.size() - 1)]


## Estado nuevo de una visita a la sala de ese nivel.
static func new_visit(tier: int) -> Dictionary:
	return {"tier": tier, "fiado_used": false, "streak": 0, "pool": 0, "stake": 1}


## Se entra a la sala: arma el estado de la visita en el run.
static func enter(run, tier: int) -> void:
	run.casino_visit = new_visit(tier)


static func _visit(run) -> Dictionary:
	var v = run.get("casino_visit")
	return v if v is Dictionary else {}


static func active(run) -> bool:
	return not _visit(run).is_empty()


static func rule_id(run) -> String:
	var v := _visit(run)
	return "" if v.is_empty() else str(rule_of(int(v.tier)).id)


## Cuántas fichas se apuestan (sólo cambia con "Apuesta libre").
static func stake(run) -> int:
	var v := _visit(run)
	return int(v.get("stake", 1)) if rule_id(run) == "libre" else 1


## Elige cuántas fichas apostar en las tragamonedas y el blackjack. false si la sala no lo permite o el valor no es una opción.
static func set_stake(run, n: int) -> bool:
	if rule_id(run) != "libre" or not STAKES.has(n):
		return false
	run.casino_visit["stake"] = n
	return true


static func streak_bonus(streak: int) -> float:
	return STREAK_STEP * float(clampi(streak - 1, 0, STREAK_MAX))


static func pool(run) -> int:
	return int(_visit(run).get("pool", 0))


## Cierra una apuesta aplicando la regla de la sala. `wager`: lo apostado; `reward`: la claridad que ya se pagó; `win`: se considera una
## victoria (aunque el premio no sea claridad); `top`: salió el premio mayor del juego. Paga lo que corresponda (devolución, extra de racha o pozo)
## y devuelve {refund, bonus, jackpot, total, notes}; `notes` son frases ya traducidas para mostrar.
static func settle(run, wager: int, reward: int, win: bool, top: bool) -> Dictionary:
	var out := {"refund": 0, "bonus": 0, "jackpot": 0, "total": 0, "notes": []}
	var v := _visit(run)
	if v.is_empty():
		return out
	var lost := (not win) and reward < wager
	match str(rule_of(int(v.tier)).id):
		"fiado":
			if lost and not v.fiado_used:
				v.fiado_used = true
				out.refund = int(round(float(wager - reward) * FIADO_REFUND))
				out.notes.append(Loc.f("Fiado: te devuelven %d de claridad.", [out.refund]))
		"racha":
			if win:
				v.streak = int(v.streak) + 1
				var pct := streak_bonus(int(v.streak))
				if pct > 0.0 and reward > 0:
					out.bonus = int(round(float(reward) * pct))
					out.notes.append(Loc.f("Racha de %d: +%d de claridad.", [v.streak, out.bonus]))
			elif lost:
				v.streak = 0
		"jackpot":
			if lost:
				v.pool = int(v.pool) + int(round(float(wager - reward) * POOL_SHARE))
			if top and int(v.pool) > 0:
				out.jackpot = int(v.pool)
				v.pool = 0
				out.notes.append(Loc.f("¡Jackpot! Te llevás el pozo: +%d de claridad.", [out.jackpot]))
	out.total = int(out.refund) + int(out.bonus) + int(out.jackpot)
	if out.total > 0:
		run.gain(out.total)
		run.casino_won += out.total
	return out
