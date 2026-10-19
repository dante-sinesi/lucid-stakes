extends RefCounted
## Reglas de la casa: cada nivel de sala (taberna, salón, casino, gran casino) paga distinto, en las tres mesas (ruleta, tragamonedas, blackjack).
## - Taberna: sin regla (es el primer casino: lo justo para jugar).
## - Salón, "Racha": cada apuesta ganada seguida suma +10 % al pago de la siguiente (hasta +50 %); perder la corta.
## - Casino, "Apuesta libre": en las tragamonedas y el blackjack se puede apostar 1, 2, 3 o 5 fichas juntas (paga proporcional).
## - Gran casino, "Jackpot": parte de lo que se pierde en la sala va a un pozo, y el premio mayor (tres coronas, blackjack, pleno) se lo lleva.
## El estado de la visita vive en `run.casino_visit` (se arma al entrar a la sala, `enter`); si está vacío (pruebas, entrenamiento) no hay reglas.
## Además lleva las estadísticas de la visita (partidas, ganadas, perdidas, gastado y ganado de cada mesa) para el balance que se ve al salir.

const Loc := preload("res://scripts/loc.gd")

const RULES := [
	{"id": "", "name": "", "desc": ""},   # la taberna no tiene regla
	{"id": "racha", "name": "Racha", "desc": "Cada apuesta ganada seguida suma +10 % al pago de la siguiente (hasta +50 %). Perder la corta."},
	{"id": "libre", "name": "Apuesta libre", "desc": "En las tragamonedas y el blackjack puedes apostar 1, 2, 3 o 5 fichas juntas."},
	{"id": "jackpot", "name": "Jackpot", "desc": "Lo que pierdes en la sala va a un pozo, y el premio mayor (tres coronas, blackjack o pleno) se lo lleva."},
]
const GAMES: Array[String] = ["ruleta", "tragamonedas", "blackjack"]
const GAME_NAMES := {"ruleta": "Ruleta", "tragamonedas": "Tragamonedas", "blackjack": "Blackjack"}
const ROOM_NAMES: Array[String] = ["Taberna", "Salón", "Casino", "Gran casino"]
const STAKES: Array[int] = [1, 2, 3, 5]
const STREAK_STEP := 0.1         # lo que suma cada victoria seguida (desde la segunda)
const STREAK_MAX := 5            # tope del extra: 5 pasos de 10 % (+50 %)
const POOL_SHARE := 0.5          # fracción de lo perdido que va al pozo del jackpot


static func rule_of(tier: int) -> Dictionary:
	return RULES[clampi(tier, 0, RULES.size() - 1)]


## Estado nuevo de una visita a la sala de ese nivel.
static func new_visit(tier: int) -> Dictionary:
	return {"tier": tier, "accepted": false, "streak": 0, "max_streak": 0, "pool": 0, "stake": 1, "stats": {}, "claridad_in": 0, "best": 0, "best_game": ""}


## Se entra a la sala: arma el estado de la visita en el run.
static func enter(run, tier: int) -> void:
	run.casino_visit = new_visit(tier)
	run.casino_visit["claridad_in"] = run.claridad


static func _visit(run) -> Dictionary:
	var v = run.get("casino_visit")
	return v if v is Dictionary else {}


static func active(run) -> bool:
	return not _visit(run).is_empty()


## La regla rige sólo si se habló con el tabernero en esta visita (él la cuenta); si no, la visita no tiene regla.
static func accepted(run) -> bool:
	return bool(_visit(run).get("accepted", false))


static func accept(run) -> void:
	if not _visit(run).is_empty():
		run.casino_visit["accepted"] = true


static func rule_id(run) -> String:
	var v := _visit(run)
	return "" if v.is_empty() or not bool(v.get("accepted", false)) else str(rule_of(int(v.tier)).id)


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
static func settle(run, wager: int, reward: int, win: bool, top: bool, game := "") -> Dictionary:
	var out := {"refund": 0, "bonus": 0, "jackpot": 0, "total": 0, "notes": []}
	var v := _visit(run)
	if v.is_empty():
		return out
	var lost := (not win) and reward < wager
	match rule_id(run):
		"racha":
			if win:
				v.streak = int(v.streak) + 1
				v.max_streak = maxi(int(v.max_streak), int(v.streak))
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
				out.notes.append(Loc.f("¡Jackpot! Te llevas el pozo: +%d de claridad.", [out.jackpot]))
	# boosts y consumibles del casino (docs/diseno.md §49)
	if win and reward > 0:
		var extra := 0
		if run.boosts.has("mesa_caliente"):
			extra += int(round(float(reward) * 0.25))
		if bool(v.get("double", false)):   # Doble o nada: lo que se gana el resto de la visita vale el doble
			extra += reward
		if extra > 0:
			out.bonus = int(out.bonus) + extra
			out.notes.append(Loc.f("Casino: +%d de claridad.", [extra]))
	if lost and run.boosts.has("red_de_seguridad"):
		var back := int(round(float(wager - reward) * 0.10))
		if back > 0:
			out.refund = int(out.refund) + back
			out.notes.append(Loc.f("Red de seguridad: te devuelven %d de claridad.", [back]))
	out.total = int(out.refund) + int(out.bonus) + int(out.jackpot)
	if out.total > 0:
		run.gain(out.total)
		run.casino_won += out.total
	_record(v, game, wager, reward + int(out.total), win, lost)
	return out


## Anota una apuesta en las estadísticas de la visita.
static func _record(v: Dictionary, game: String, wager: int, paid: int, win: bool, lost: bool) -> void:
	if game == "":
		return
	var st: Dictionary = v.stats.get(game, {"plays": 0, "wins": 0, "losses": 0, "pushes": 0, "spent": 0, "won": 0})
	st.plays += 1
	if win:
		st.wins += 1
	elif lost:
		st.losses += 1
	else:
		st.pushes += 1
	st.spent += wager
	st.won += paid
	v.stats[game] = st
	if paid - wager > int(v.best):
		v.best = paid - wager
		v.best_game = game


## El balance de la visita: una fila por mesa ({game, name, plays, wins, losses, pushes, spent, won, net}), los totales y datos sueltos.
## Sin visita, todo en cero.
static func balance(run) -> Dictionary:
	var v := _visit(run)
	var rows: Array[Dictionary] = []
	var total := {"plays": 0, "wins": 0, "losses": 0, "pushes": 0, "spent": 0, "won": 0, "net": 0}
	for g in GAMES:
		var st: Dictionary = v.get("stats", {}).get(g, {})
		var row := {"game": g, "name": GAME_NAMES[g], "plays": int(st.get("plays", 0)), "wins": int(st.get("wins", 0)), "losses": int(st.get("losses", 0)),
				"pushes": int(st.get("pushes", 0)), "spent": int(st.get("spent", 0)), "won": int(st.get("won", 0))}
		row["net"] = row.won - row.spent
		rows.append(row)
		for k in total:
			total[k] += int(row[k])
	return {"rows": rows, "total": total, "best": int(v.get("best", 0)), "best_game": str(v.get("best_game", "")),
			"claridad_in": int(v.get("claridad_in", 0)), "claridad_out": run.claridad, "max_streak": int(v.get("max_streak", 0)),
			"pool": int(v.get("pool", 0)), "rule": rule_id(run),
			"room": ROOM_NAMES[clampi(int(v.get("tier", 0)), 0, ROOM_NAMES.size() - 1)] if not v.is_empty() else ""}
