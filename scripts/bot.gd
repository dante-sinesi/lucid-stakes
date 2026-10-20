extends RefCounted
## El bot que juega el juego para sacar estadísticas de balance (docs/bot.md): sube las torres siguiendo el camino mínimo que trae el generador (con titubeos y muertes según su habilidad),
## juega el casino con una política (qué premio busca, cuándo rota la vitrina, cuándo compra en la tienda) y le paga a Farolín. Usa las reglas reales (TowerLogic, RunState, Roulette, Showcase),
## sin ventanas ni animaciones. Las torres salen de un banco (tests/bot_banco.gd) porque generarlas lleva de 10 a 45 segundos cada una.

const TowerLogic := preload("res://scripts/tower_logic.gd")
const RunState := preload("res://scripts/run_state.gd")
const RoomLib := preload("res://scripts/room_lib.gd")
const Roulette := preload("res://scripts/roulette.gd")
const Showcase := preload("res://scripts/showcase.gd")
const Items := preload("res://scripts/items.gd")

const FINAL_STAGE := 15
## Los premios que busca el bot, de más a menos querido (la política de las partidas "con build").
const WISHLIST: Array = ["cosecha_doble", "midas", "pies_de_oro", "cosecha", "racha_imparable", "pies_de_luz", "buen_ojo", "escalador", "descuento_duende",
		"empuje_rentable", "interes", "bolsillo_de_luz", "mente_abierta", "pocion_de_cosecha", "lluvia_de_luz", "iman_de_luz", "baraja_de_racha", "soborno", "vida_extra",
		"tesoro", "cofre_de_luz", "saquito_de_oro"]
const BET_OF_TIER := {Items.Tier.EPICO: Roulette.Bet.PLENO, Items.Tier.RARO: Roulette.Bet.TERNA, Items.Tier.COMUN: Roulette.Bet.MITAD, Items.Tier.CONSUMIBLE: Roulette.Bet.RANGO}


## Parámetros por omisión de una partida del bot.
static func default_config() -> Dictionary:
	return {
		"skill": 1.0,            # habilidad: 1,0 = el jugador medio; más: titubea y muere menos
		"hesitate": 0.04,        # probabilidad de titubear (ir y volver) en cada paso, para un jugador de habilidad 1,0
		"die_first": 0.03,       # probabilidad de morir en una torre de la etapa 1 (sube hasta die_last en la 15), para habilidad 1,0
		"die_last": 0.20,
		"spend": 0.8,            # fracción de lo que sobra (después de apartar el precio de Farolín) que se juega en el casino
		"max_rotations": 3,      # cuántas veces rota la vitrina buscando un premio de la lista
		"play_blind": true,      # si no hay nada de la lista en la vitrina y no se puede rotar: juega igual una apuesta común
		"mistakes": 0,           # Sin piedad: movimientos en falso que permite cada sala (0 = el escenario común); cada titubeo del bot cuenta como uno
		"free_plays": 0,         # jugadas gratis por visita (el diseño de las monedas; el juego todavía no las tiene)
		"max_casino_actions": 60,
	}


# --- una torre -----------------------------------------------------------------------------------------------------------------

## Titubeo: una ida y vuelta que no cambia nada pero gasta tiempo de la caída (como en Metrics.survival).
static func _hesitate(lg) -> void:
	lg.trail.clear()   # (dos movimientos de ida y vuelta: no cambian nada pero gastan tiempo de la caída y cortan la racha; se simulan sin clonar la torre)
	lg.last_grab = ""
	lg._after_action()
	lg._after_action()


## La sala (por posición en la lista) donde está parado el jugador.
static func _room_of(rooms: Array, y: int) -> int:
	var idx := 0
	for i in rooms.size():
		if int(rooms[i].ey) <= y:
			idx = i
	return idx


## Sube una torre una vez. {won, died, claridad (la que juntó en este intento), moves, used (consumibles gastados)}.
static func play_tower(entry: Dictionary, run, rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
	var lg = TowerLogic.from_dict(entry.tower)
	lg.track_purify = true
	lg.apply_perks(run.boosts)
	lg.collapse_every = int(entry.tower.collapse_every)
	lg.moves_to_collapse = int(entry.tower.moves_to_collapse)
	var skill: float = maxf(float(cfg.skill), 0.05)
	var stage: int = run.stage
	var die_p: float = clampf(lerpf(float(cfg.die_first), float(cfg.die_last), float(stage - 1) / float(FINAL_STAGE - 1)) / skill, 0.0, 0.95)
	var path: Array = entry.path
	var n := path.size()
	var died_at := -1
	if rng.randf() < die_p:   # se muere en algún punto del camino (más probable cerca del final de cada sala: acá, al azar)
		died_at = rng.randi_range(int(n * 0.2), n - 1)
	var hes_p: float = float(cfg.hesitate) / skill
	var used := 0
	var rooms: Array = entry.get("rooms", [])   # (las salas de la torre: Sin piedad cuenta los falsos por sala)
	var allowed := int(cfg.get("mistakes", 0)) if not rooms.is_empty() else 0
	var false_counts := {}
	for i in n:
		if i == died_at:
			return {"won": false, "died": true, "claridad": int(lg.claridad * 0.4), "moves": i, "used": used}
		if i == 0 and run.consumables.has("pocion_de_cosecha"):
			if lg.use_item("pocion_de_cosecha").ok:
				run.use_consumable("pocion_de_cosecha")
				used += 1
		if i == n / 2:   # a la mitad se tiran los que dan claridad de golpe
			for id in ["baraja_de_racha", "lluvia_de_luz", "iman_de_luz"]:
				if run.consumables.has(id) and lg.use_item(id).ok:
					run.use_consumable(id)
					used += 1
		if lg.moves_to_collapse <= 2:
			for id in ["reloj_de_arena", "freno"]:
				if run.consumables.has(id) and lg.use_item(id).ok:
					run.use_consumable(id)
					used += 1
					break
		if rng.randf() < hes_p:
			_hesitate(lg)
			if allowed > 0:   # (en Sin piedad cada titubeo es un movimiento en falso de la sala donde está: al pasar el límite se pierde la torre)
				var room := _room_of(rooms, lg.player.y)
				false_counts[room] = int(false_counts.get(room, 0)) + 1
				if int(false_counts[room]) > allowed:
					return {"won": false, "died": true, "false_death": true, "claridad": int(lg.claridad * 0.4), "moves": i, "used": used}
		if lg.lost:
			return {"won": false, "died": true, "claridad": int(lg.claridad * 0.4), "moves": i, "used": used}
		var r: Dictionary = lg.try_action(path[i].dir, path[i].mode)
		if lg.lost or not r.ok:
			return {"won": false, "died": true, "claridad": int(lg.claridad * 0.4), "moves": i, "used": used}
	return {"won": lg.won, "died": not lg.won, "claridad": lg.claridad, "moves": n, "used": used}


# --- el casino ------------------------------------------------------------------------------------------------------------------

## El mejor premio de la lista que se puede conseguir ahora: {id, tier, where ("vitrina" | "tienda")} o {}.
static func _wanted(run) -> Dictionary:
	var shop_ids: Array = []
	for it in Showcase.shop_offers(run):
		shop_ids.append(str(it.id))
	for id in WISHLIST:
		var it := Items.get_item(str(id))
		if it.is_empty() or not Showcase.valid(run, it):
			continue
		if it.type != Items.Type.CLARITY and not run.has_room_for(it):
			continue
		if shop_ids.has(id):
			return {"id": id, "tier": int(it.tier), "where": "tienda"}
		for t in Showcase.COUNTS:
			if run.showcase.get("tiers", {}).get(str(t), []).has(id):
				return {"id": id, "tier": int(t), "where": "vitrina"}
	return {}


## Una visita al casino: usa lo que sirve, compra, juega la ruleta buscando premios de la lista y deja apartado lo de Farolín. Devuelve estadísticas de la visita.
static func casino(run, rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
	var stats := {"plays": 0, "spent": 0, "bought": 0, "rotations": 0, "won_items": []}
	Showcase.enter(run, rng)
	if run.consumables.has("vida_extra") and run.lives < run.max_lives() and run.add_life():
		run.use_consumable("vida_extra")
	if run.consumables.has("soborno") and not run.toll_bribe:
		run.toll_bribe = true
		run.use_consumable("soborno")
	var base_toll := RunState.toll_for(run.stage)
	var free_left := int(cfg.free_plays)
	for _i in int(cfg.max_casino_actions):
		var reserve: int = run.toll_after_discounts(base_toll)
		var budget := int(float(run.claridad - reserve) * float(cfg.spend))
		var ficha := Roulette.run_price(run)
		var want := _wanted(run)
		if not want.is_empty() and want.where == "tienda":
			var price := Showcase.shop_price(run, Items.get_item(str(want.id)))
			if price <= budget:
				var res := Showcase.buy(run, str(want.id))
				if res.ok:
					stats.bought += 1
					stats.spent += int(res.price)
					continue
			want = {}
		if want.is_empty():
			var rot_cost := Showcase.rotate_cost(run)
			if stats.rotations < int(cfg.max_rotations) and budget >= rot_cost + ficha:
				Showcase.rotate(run, rng)
				stats.rotations += 1
				stats.spent += rot_cost
				continue
			if not bool(cfg.play_blind):
				break
		var bet: int = Roulette.Bet.TERNA
		if not want.is_empty():
			bet = int(BET_OF_TIER[want.tier])
		elif run.showcase.is_empty():
			bet = Roulette.Bet.MITAD
		var free: bool = free_left > 0
		if not free and budget < ficha:
			break
		var pockets: Array = range(1, int(Roulette.BETS[bet].count) + 1)
		var before: int = run.claridad
		if free:
			run.claridad += ficha   # (la jugada gratis: se paga con una moneda de la torre, no con claridad)
			free_left -= 1
		var res2: Dictionary = Roulette.resolve(run, bet, pockets, rng)
		if not res2.ok:
			break
		stats.plays += 1
		stats.spent += (0 if free else int(res2.price))
		if res2.won and not res2.prize.is_empty():
			stats.won_items.append(str(res2.prize.id))
	return stats


## Le paga a Farolín. true si alcanzó (y entonces se cobra, se gasta el Soborno y se suma el Interés).
static func pay_toll(run) -> bool:
	var price: int = run.toll_after_discounts(RunState.toll_for(run.stage))
	if run.claridad < price:
		return false
	run.spend(price)
	run.toll_bribe = false
	run.apply_interest()
	return true


# --- un run ----------------------------------------------------------------------------------------------------------------------

## Juega un run entero con las torres del banco (`bank`: {etapa: [entradas]}). Devuelve el resumen: {stage, won, lives_lost, towers, build, per_stage: [...]}.
static func run_one(bank: Dictionary, rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
	var run = RunState.new()
	var per_stage: Array = []
	var lives_lost := 0
	var reached := 0
	var ended := false
	for s in range(1, FINAL_STAGE + 1):
		run.stage = s
		var pool: Array = bank.get(s, [])
		if pool.is_empty():
			break
		var entry: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var rec := {"stage": s, "income": 0, "attempts": 0, "toll": run.toll_after_discounts(RunState.toll_for(s)), "claridad_before": run.claridad, "boosts": run.boosts.size()}
		var cleared := false
		while not cleared:
			rec.attempts += 1
			var res := play_tower(entry, run, rng, cfg)
			if res.get("false_death", false):
				rec["false_deaths"] = int(rec.get("false_deaths", 0)) + 1
			if res.died:
				run.gain(int(res.claridad))
				if not run.can_revive():
					ended = true
					break
				run.note_retry(true)
				lives_lost += 1
				continue
			run.gain(int(res.claridad))
			rec.income += int(res.claridad)
			var cs := casino(run, rng, cfg)
			rec["plays"] = int(rec.get("plays", 0)) + int(cs.plays)
			rec["bought"] = int(rec.get("bought", 0)) + int(cs.bought)
			if pay_toll(run):
				cleared = true
			else:
				if not run.can_revive():
					ended = true
					break
				run.note_retry(true)
				lives_lost += 1
		rec["claridad_after"] = run.claridad
		per_stage.append(rec)
		if ended:
			break
		reached = s
	return {"stage": reached, "won": reached >= FINAL_STAGE and not ended, "lives_lost": lives_lost, "build": run.boosts.duplicate(), "per_stage": per_stage}


# --- el banco de torres ----------------------------------------------------------------------------------------------------

## Una línea del banco: la torre y su camino.
static func entry_line(stage: int, seed_value: int, res: Dictionary) -> String:
	return JSON.stringify({"stage": stage, "seed": seed_value, "tower": res.logic.to_dict(), "path": RoomLib.path_string(res.path), "rooms": res.get("rooms", [])})


static func load_bank(dir: String) -> Dictionary:
	var bank := {}
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".jsonl"):
			continue
		var fa := FileAccess.open(dir.path_join(f), FileAccess.READ)
		if fa == null:
			continue
		while not fa.eof_reached():
			var line := fa.get_line().strip_edges()
			if line == "":
				continue
			var j := JSON.new()
			if j.parse(line) != OK or typeof(j.data) != TYPE_DICTIONARY:
				continue
			var d: Dictionary = j.data
			var st := int(d.stage)
			if not bank.has(st):
				bank[st] = []
			bank[st].append({"stage": st, "seed": int(d.seed), "tower": d.tower, "path": RoomLib.parse_path(str(d.path)), "rooms": d.get("rooms", [])})
		fa.close()
	return bank
