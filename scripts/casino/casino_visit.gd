extends RefCounted
## La visita a un casino: lo que pasa mientras estás en la sala (la racha, el pozo, "Doble o nada" y las estadísticas de cada mesa para el balance de la salida) y los efectos de los boosts y
## consumibles del casino sobre cada apuesta (`settle`). Ya no hay reglas de la casa por sala: la racha y el pozo del jackpot son premios (docs/plan_casinos.md).
## - Racha: cada apuesta ganada seguida suma +10 % al pago de la siguiente (hasta +50 %); perder la corta. Con el boost "Racha de la casa" o, esta visita, con el consumible "Racha de visita".
## - Pozo del jackpot (boost): parte de lo que se pierde va a un pozo, y el premio mayor (tres coronas, blackjack, pleno) se lo lleva.
## El estado de la visita vive en `run.casino_visit` (se arma al entrar a la sala, `enter`); si está vacío (pruebas, entrenamiento) no hay efectos.

const Loc := preload("res://scripts/idioma/loc.gd")

const GAMES: Array[String] = ["ruleta", "tragamonedas", "blackjack"]
const GAME_NAMES := {"ruleta": "Ruleta", "tragamonedas": "Tragamonedas", "blackjack": "Blackjack"}
const ROOM_NAMES: Array[String] = ["Taberna", "Salón", "Casino", "Gran casino"]
const STREAK_STEP := 0.1         # lo que suma cada victoria seguida (desde la segunda)
const STREAK_MAX := 5            # tope del extra: 5 pasos de 10 % (+50 %)
const POOL_SHARE := 0.5          # fracción de lo perdido que va al pozo del jackpot


## Estado nuevo de una visita a la sala de ese nivel.
static func new_visit(tier: int) -> Dictionary:
	return {"tier": tier, "streak": 0, "max_streak": 0, "pool": 0, "racha": false, "stats": {}, "claridad_in": 0, "best": 0, "best_game": ""}


## Se entra a la sala: arma el estado de la visita en el run.
static func enter(run, tier: int) -> void:
	run.casino_visit = new_visit(tier)
	run.casino_visit["claridad_in"] = run.claridad


static func _visit(run) -> Dictionary:
	var v = run.get("casino_visit")
	return v if v is Dictionary else {}


static func active(run) -> bool:
	return not _visit(run).is_empty()


## ¿Rige la racha? Con el boost, siempre; con el consumible, el resto de la visita.
static func racha_activa(run) -> bool:
	return not _visit(run).is_empty() and (run.boosts.has("racha_de_la_casa") or bool(_visit(run).get("racha", false)))


## Enciende la racha para esta visita (el consumible "Racha de visita"). false si no hay visita o ya estaba encendida.
static func encender_racha(run) -> bool:
	var v := _visit(run)
	if v.is_empty() or bool(v.get("racha", false)):
		return false
	run.casino_visit["racha"] = true
	return true


static func streak_bonus(streak: int) -> float:
	return STREAK_STEP * float(clampi(streak - 1, 0, STREAK_MAX))


static func pool(run) -> int:
	return int(_visit(run).get("pool", 0))


## Los avisos de una apuesta ya resuelta (devolución, racha, jackpot), listos para sumar a un texto. "" si no hubo.
static func notes(res: Dictionary) -> String:
	var rules: Dictionary = res.get("rules", {})
	var list: Array = rules.get("notes", [])
	return "" if list.is_empty() else "  " + "  ".join(list)


## Cierra una apuesta aplicando lo que hagan los boosts y consumibles del casino. `wager`: lo apostado; `reward`: la claridad que ya se pagó; `win`: se considera una
## victoria (aunque el premio no sea claridad); `top`: salió el premio mayor del juego. Paga lo que corresponda (devolución, extra de racha o pozo)
## y devuelve {refund, bonus, jackpot, total, notes}; `notes` son frases ya traducidas para mostrar.
static func settle(run, wager: int, reward: int, win: bool, top: bool, game := "") -> Dictionary:
	var out := {"refund": 0, "bonus": 0, "jackpot": 0, "total": 0, "notes": []}
	var v := _visit(run)
	if v.is_empty():
		return out
	var lost := (not win) and reward < wager
	if racha_activa(run):
		if win:
			v.streak = int(v.streak) + 1
			v.max_streak = maxi(int(v.max_streak), int(v.streak))
			var pct := streak_bonus(int(v.streak))
			if pct > 0.0 and reward > 0:
				out.bonus = int(round(float(reward) * pct))
				out.notes.append(Loc.f("Racha de %d: +%d de claridad.", [v.streak, out.bonus]))
		elif lost:
			v.streak = 0
	if run.boosts.has("pozo_del_jackpot"):
		if lost:
			v.pool = int(v.pool) + int(round(float(wager - reward) * POOL_SHARE))
		if top and int(v.pool) > 0:
			out.jackpot = int(v.pool)
			v.pool = 0
			out.notes.append(Loc.f("¡Jackpot! Te llevas el pozo: +%d de claridad.", [out.jackpot]))
	# más boosts y consumibles del casino (docs/diseno.md §49)
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
			"pool": int(v.get("pool", 0)), "racha": racha_activa(run), "pozo": run.boosts.has("pozo_del_jackpot"),
			"room": ROOM_NAMES[clampi(int(v.get("tier", 0)), 0, ROOM_NAMES.size() - 1)] if not v.is_empty() else ""}
