extends RefCounted
## El bot que juega el juego para sacar estadísticas de balance (docs/bot.md): sube las torres siguiendo el camino mínimo de cada sala (con titubeos y muertes según su habilidad),
## juega el casino con una política (qué premio busca, cuándo rota la vitrina, cuándo compra en la tienda) y le paga a Farolín. Usa las reglas reales (Torre, RunState, Roulette, Showcase),
## sin ventanas ni animaciones. Las torres se arman con el paquete de salas (armarlas lleva unos 0,3 s cada una).

const RunState := preload("res://scripts/datos/run_state.gd")
const Roulette := preload("res://scripts/casino/roulette.gd")
const Showcase := preload("res://scripts/casino/showcase.gd")
const Items := preload("res://scripts/datos/items.gd")
const Torre := preload("res://torre/torre.gd")   # la torre (salas apiladas): el bot la juega siguiendo el camino mínimo de cada sala

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

# --- la torre ---------------------------------------------------------------------------------------------------------------------

## Qué tan fácil o difícil le sale al bot cada nivel de sala (multiplica la probabilidad de perderla).
const PESO_NIVEL := {"facil": 0.5, "media": 1.0, "dificil": 1.6, "pesadilla": 2.4}


## Un banco de torres (armarlas lleva unos 0,3 s cada una): {etapa: [Torre]}. Cada partida juega una copia (`Torre.copia`).
static func arm_bank(paquete: Array, rng: RandomNumberGenerator, per_stage: int) -> Dictionary:
	var bank := {}
	for s in range(1, FINAL_STAGE + 1):
		bank[s] = []
		for _i in per_stage:
			var t = Torre.armar(paquete, rng.randi(), Torre.salas_de_etapa(s), true, s)
			if t.salas.size() >= 3:
				bank[s].append(t)
	return bank


## Juega una sala siguiendo su camino (con titubeos, un posible tropiezo al azar y los consumibles). true si llegó a la salida; si no, la sala quedó perdida (`t.muerta` o el motivo).
static func _jugar_sala(t, run, rng: RandomNumberGenerator, cfg: Dictionary, p_sala: float, hes_p: float, estado: Dictionary) -> bool:
	var cam: Array = t.sala_actual().d.camino
	var n := cam.size()
	var died_at := -1
	if rng.randf() < p_sala:   # se pierde en algún punto de la sala (al azar entre el 20 % y el final)
		died_at = rng.randi_range(int(n * 0.2), n - 1)
	var allowed := int(cfg.get("mistakes", 0))
	var falsos := 0
	for i in n:
		if i == died_at:
			t.forzar_muerte("tropiezo")
			return false
		if i == 0 and t.indice == 0 and run.consumables.has("pocion_de_cosecha"):
			if t.usar_item("pocion_de_cosecha").ok:
				run.use_consumable("pocion_de_cosecha")
				estado.used += 1
		if i == n / 2:   # a la mitad se tiran los que dan claridad de golpe
			for id in ["baraja_de_racha", "lluvia_de_luz", "iman_de_luz"]:
				if run.consumables.has(id) and t.usar_item(id).ok:
					run.use_consumable(id)
					estado.used += 1
		if t.max_mov() - t.movs <= 2:
			for id in ["reloj_de_arena", "freno"]:
				if run.consumables.has(id) and t.usar_item(id).ok:
					run.use_consumable(id)
					estado.used += 1
					break
		if rng.randf() < hes_p:   # un titubeo: dos movimientos que no cambian nada pero gastan el temporizador y cortan la racha
			t.movs += 2
			t.cosecha.streak = 0
			if allowed > 0:   # (en Sin piedad cada titubeo es un movimiento en falso de la sala)
				falsos += 1
				if falsos > allowed:
					estado["false_death"] = true
					t.forzar_muerte("falso")
					return false
			if t.movs >= t.max_mov():
				t.forzar_muerte("tiempo")
				return false
		var a = cam[i]
		var r: Dictionary = t.actuar(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
		if not r.ok:
			t.forzar_muerte("camino")
			return false
		var ev := str(r.evento)
		if ev == "checkpoint" or ev == "torre":
			return true
		if ev == "muerte" or ev == "fin":
			return false
	return false


## Sube una torre entera. Una sala perdida se reintenta (cuesta una vida del run). {won, died, ended, claridad, moves, lives_lost, room_deaths, attempts, rooms: [...], used}.
static func play_tower(entry, run, rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
	var t = Torre.copia(entry)
	t.externo = true
	t.aplicar_boosts(run.boosts)
	t.mov_run = run.movs_extra
	var skill: float = maxf(float(cfg.skill), 0.05)
	var stage: int = run.stage
	var p_torre: float = lerpf(float(cfg.die_first), float(cfg.die_last), float(stage - 1) / float(FINAL_STAGE - 1)) / skill
	var peso_total := 0.0
	for sala in t.salas:
		peso_total += float(PESO_NIVEL.get(str(sala.d.nivel), 1.0))
	var hes_p: float = float(cfg.hesitate) / skill
	var estado := {"used": 0}
	var lives_lost := 0
	var room_deaths := 0
	var rooms: Array = []
	while not t.terminada:
		var sala: Dictionary = t.sala_actual()
		var p_sala := clampf(p_torre * float(PESO_NIVEL.get(str(sala.d.nivel), 1.0)) / maxf(peso_total, 0.1), 0.0, 0.95)
		var ok := _jugar_sala(t, run, rng, cfg, p_sala, hes_p, estado)
		var info: Dictionary = t.ultima_sala
		if ok:
			rooms.append({"nivel": str(info.get("nivel", "")), "movs": int(info.get("movs", 0)), "max_mov": int(info.get("max_mov", 0)), "pasos": int(info.get("pasos_minimos", 0)), "ok": true})
			continue
		rooms.append({"nivel": str(info.get("nivel", "")), "movs": int(info.get("movs", 0)), "max_mov": int(info.get("max_mov", 0)), "pasos": int(info.get("pasos_minimos", 0)), "ok": false})
		room_deaths += 1
		if not run.can_revive():
			return {"won": false, "died": true, "ended": true, "claridad": 0, "moves": t.movs_total, "lives_lost": lives_lost, "room_deaths": room_deaths, "attempts": 1 + room_deaths,
					"rooms": rooms, "used": estado.used, "false_death": estado.get("false_death", false)}
		run.note_retry(true)
		lives_lost += 1
		t.reintentar_sala()
	return {"won": true, "died": false, "ended": false, "claridad": t.cosecha.claridad(), "moves": t.movs_total, "lives_lost": lives_lost, "room_deaths": room_deaths,
			"attempts": 1 + room_deaths, "rooms": rooms, "used": estado.used, "false_death": estado.get("false_death", false)}


## Un run entero (`bank`: {etapa: [Torre]}, ver arm_bank). Devuelve el resumen: etapa alcanzada, si ganó, vidas perdidas, lo que armó y, por etapa, lo que pasó (incluidas las salas).
static func run_one(bank: Dictionary, rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
	var run = RunState.new()
	var per_stage: Array = []
	var lives_lost := 0
	var reached := 0
	var ended := false
	for st in range(1, FINAL_STAGE + 1):
		run.stage = st
		var pool: Array = bank.get(st, [])
		if pool.is_empty():
			break
		var entry = pool[rng.randi_range(0, pool.size() - 1)]
		var rec := {"stage": st, "income": 0, "attempts": 0, "toll": run.toll_after_discounts(RunState.toll_for(st)), "claridad_before": run.claridad, "boosts": run.boosts.size(), "rooms": []}
		var cleared := false
		while not cleared:
			var res := play_tower(entry, run, rng, cfg)
			rec.attempts += int(res.attempts)
			rec.rooms.append_array(res.rooms)
			lives_lost += int(res.lives_lost)
			if res.get("false_death", false):
				rec["false_deaths"] = int(rec.get("false_deaths", 0)) + 1
			if res.ended:
				ended = true
				break
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
				run.note_retry(true)   # (no alcanzó para Farolín: se rehace la torre y cuesta una vida)
				lives_lost += 1
		rec["claridad_after"] = run.claridad
		per_stage.append(rec)
		if ended:
			break
		reached = st
	return {"stage": reached, "won": reached >= FINAL_STAGE and not ended, "lives_lost": lives_lost, "build": run.boosts.duplicate(), "per_stage": per_stage}


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

# --- el banco de torres ----------------------------------------------------------------------------------------------------
