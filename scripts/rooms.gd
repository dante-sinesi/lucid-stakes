extends RefCounted
## Motor de torres por situaciones: una torre es una pila de salas de 4 pisos alrededor del core, y cada sala es una IDEA escrita a mano (una situación con una premisa, una técnica
## y giros) cuya variante se sortea y se verifica con el solucionador. El orden es el de Spelunky: primero se decide la secuencia de salas y después se arma cada una, con la plataforma
## que necesita (sólo lo que la sala usa, con vacío alrededor: la torre sigue siendo una columna de bloques y plataformas).
##
## Cada escenario trae su catálogo de ideas (SCENARIO_IDEAS); la Pesadilla acumula las de todos (con la escalera de bloques de siempre: hielo en la etapa 2, pesado 3, agrietado 4...).
##
## Cada sala se acepta sólo si cumple el filtro de calidad (ver _commit):
##  - profundidad: se resuelve en el rango de movimientos de la etapa (mínimo que sube con la dificultad);
##  - premisa y técnica: la solución usa lo que la idea promete (no se puede esquivar con una escalera): mover los pinchos, gastar el agrietado, mover el freno y resbalar...;
##  - costo del error: en las ideas que castigan, hay posiciones sin salida alcanzables en pocos movimientos (se mide con muestras al azar);
##  - visibilidad: casi todo el recorrido se ve desde algún ángulo de la cámara (nada de jaulas);
##  - sostén: nada de lo armado cae solo, y todo el camino anterior sigue valiendo.
## Los giros (twists) de cada idea cambian la solución, y no se repite el mismo giro de una idea dos veces seguidas.

const Gen := preload("res://scripts/tower_gen.gd")
const Solver := preload("res://scripts/solver.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const Metrics := preload("res://scripts/tower_metrics.gd")
const K := TowerLogic.Kind

const SIZE := 8
const ROOM := 4                       # pisos de una sala
const CORE := Rect2i(3, 3, 2, 2)      # el core: fijo, de arriba a abajo, sostiene lo que toca
const START := Vector2i(2, 3)         # donde empieza el jugador (a la izquierda del core)
const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const TRIES := 30                     # candidatos que se resuelven (lo caro) por idea y por lugar
const MAX_CANDIDATES := 800           # candidatos que se arman (barato) por idea y por lugar
const MAX_MS := 40000                 # (sólo una emergencia: los topes son de trabajo —resoluciones y candidatos—, no de tiempo, para que la misma semilla dé siempre la misma torre)
const ROOM_MS := 120000               # (emergencia)
const ROOM_SOLVES := 90               # resoluciones máximas por sala (después, sólo un respiro)
const STATES := 3500                  # tope del solucionador por candidato
const MIN_VISIBLE := 0.5              # fracción mínima del recorrido que tiene que verse desde algún ángulo de la cámara
const MIN_GRABS := 4.5               # agarres mínimos que pide el camino a dificultad 1 (a menos, se resuelve moviendo uno o dos bloques)
const MIN_STATES := 300               # estados mínimos que tiene que explorar el solucionador a dificultad 1 (a menos, la sala se resuelve a ojo)
const ERROR_SAMPLES := 8              # pasos de la solución donde se mide el costo del error
const ERROR_FROM := 0.2               # desde esta dificultad, las ideas que castigan tienen que castigar de verdad

## El catálogo: tier (1 fácil a 3 difícil: cuándo puede aparecer en la torre), unlock (el bloque que tiene que estar desbloqueado), base (movimientos mínimos pedidos), grab (la
## solución tiene que empujar o tirar de bloques), punish (tiene que haber errores sin salida) y twists (los giros).
const IDEAS := {
	"muro_simple": {"tier": 1, "unlock": "none", "base": 8, "grab": true, "punish": false, "twists": ["chico", "grande"]},
	"hielo_freno": {"tier": 1, "unlock": "ice", "base": 11, "grab": true, "punish": false, "twists": ["simple", "doble"]},
	"hielo_pista": {"tier": 2, "unlock": "ice", "base": 7, "grab": false, "punish": true, "twists": ["chica", "grande", "alargada"]},
	"hielo_billar": {"tier": 2, "unlock": "ice", "base": 8, "grab": true, "punish": true, "twists": ["un_tope", "dos_topes"]},
	"pared_pesada": {"tier": 1, "unlock": "heavy", "base": 9, "grab": true, "punish": true, "twists": ["un_suelto", "dos_sueltos"]},
	"cruce_agrietado": {"tier": 2, "unlock": "cracked", "base": 9, "grab": true, "punish": true, "twists": ["simple", "con_pesados"]},
	"pared_pinchos": {"tier": 2, "unlock": "spikes", "base": 9, "grab": true, "punish": true, "twists": ["simple", "con_senuelos"]},
	"campo_trampas": {"tier": 2, "unlock": "trap", "base": 8, "grab": false, "punish": true, "twists": ["fino", "ancho"]},
	"cuenta_bomba": {"tier": 3, "unlock": "bomb", "base": 8, "grab": false, "punish": true, "twists": ["justa", "holgada"]},
	"chica": {"h": 5, "tier": 1, "unlock": "none", "base": 14, "grab": true, "punish": false, "twists": ["baja", "alta"]},
	"mediana": {"h": 8, "tier": 1, "unlock": "none", "base": 16, "grab": true, "punish": false, "twists": ["baja", "media", "alta"]},
	"taller": {"h": 2, "tier": 1, "unlock": "none", "base": 12, "grab": true, "punish": false, "twists": ["una_caja", "dos_cajas", "tres_cajas"]},
	"reja": {"tier": 1, "unlock": "none", "base": 20, "grab": true, "punish": false, "twists": ["baja", "alta", "pesados", "pinchos"]},
	"trampolin": {"tier": 3, "unlock": "catapult", "base": 8, "grab": true, "punish": false, "twists": ["simple", "con_topes"]},
}
## Las ideas propias de cada escenario (se pueden usar desde la primera etapa: son su identidad). Los escenarios que no están acá usan todas, con la escalera de bloques.
const SCENARIO_IDEAS := {
	"glaciar": ["hielo_freno", "hielo_pista", "hielo_billar"],
}



static func names() -> Array:
	var out: Array = IDEAS.keys()
	out.erase("reja")   # (la reja quedó de experimento: el solucionador la resuelve en pocos pasos; no sale en las torres)
	return out


## Dificultad desde la que está desbloqueado cada tipo de bloque (la escalera de bloques de tower_gen.gd).
static func unlock_at(key: String) -> float:
	match key:
		"ice":
			return Gen.ICE_FROM
		"heavy":
			return Gen.HEAVY_FROM
		"cracked":
			return Gen.CRACKED_FROM
		"trap":
			return Gen.TRAP_FROM
		"spikes":
			return Gen.SPIKES_FROM
		"bomb":
			return Gen.BOMB_FROM
		"catapult":
			return Gen.CATAPULT_FROM
	return 0.0


## Las ideas que pueden salir en una torre de ese escenario y esa dificultad.
static func catalog(scenario_id: String, difficulty: float) -> Array:
	if SCENARIO_IDEAS.has(scenario_id):
		return SCENARIO_IDEAS[scenario_id].duplicate()
	var out: Array = []
	for name in IDEAS:
		if difficulty >= unlock_at(IDEAS[name].unlock) and (name != "reja" or OS.get_environment("REJA") != "") and (not _puzzle(name) or difficulty >= REJA_FROM):
			out.append(name)
	return out


## La secuencia de salas: [{idea, twist}]. La primera es de respiro; ahí en más, una idea por sala (de respiro sólo a veces y nunca dos seguidas), sin repetir la idea de la sala
## anterior ni el mismo giro de esa idea dos veces seguidas, y cuanto más arriba y más difícil, más difíciles las ideas (tier).
static func plan(rng: RandomNumberGenerator, rooms: int, difficulty: float, ideas: Array) -> Array[Dictionary]:
	var only: String = OS.get_environment("IDEA_ONLY")
	var out: Array[Dictionary] = []
	var last_twist := {}
	var plain_rooms := 0
	var rest_share := lerpf(0.2, 0.0, clampf(difficulty * 3.0, 0.0, 1.0))
	for i in rooms:
		var rest: bool = (i == 0 and difficulty < 0.3) or (i > 0 and rest_share > 0.0 and rng.randf() < rest_share and out[out.size() - 1].idea != "respiro")
		if only != "" and i > 0:
			rest = false
		if rest or ideas.is_empty():
			out.append({"idea": "respiro", "twist": ""})
			continue
		var boost := 0.35 if ideas.size() <= 3 else 0.0   # (un escenario con pocas ideas no puede esperar: son su identidad)
		var max_tier := 1 + int(clampf(difficulty * 1.5 + float(i) / float(maxi(rooms, 1)) * 0.8 + boost, 0.0, 1.0) * 2.0)
		var pool: Array = []
		for name in ideas:
			if IDEAS[name].tier <= max_tier:
				pool.append(name)
		if pool.is_empty():
			pool = ideas.duplicate()
		if only != "" and IDEAS.has(only):
			pool = [only]
		var run := 0   # salas de cajas seguidas y en total: una torre de sólo acertijos cansa (hasta 3 seguidas y 7 en total; en el medio, lo de antes de respiro)
		var total := 0
		for r in out:
			total += 1 if _puzzle(r.idea) else 0
		for j in range(out.size() - 1, -1, -1):
			if not _puzzle(out[j].idea):
				break
			run += 1
		if (run >= 3 or total >= 7) and pool.size() > 1:
			for pz in ["taller", "chica", "mediana"]:
				pool.erase(pz)
		if pool.size() > 1 and not out.is_empty() and not _puzzle(out[out.size() - 1].idea):   # (los acertijos de cajas pueden ir seguidos: cada uno es distinto)
			pool.erase(out[out.size() - 1].idea)
		if difficulty > 0.2 and plain_rooms >= 1 and ideas.size() > 3:   # las ideas que se resuelven caminando salen a lo sumo una vez por torre (el resto, salas donde hay que mover bloques)
			var movers: Array = []
			for name in pool:
				if _grabby(name, difficulty):
					movers.append(name)
			if not movers.is_empty():
				pool = movers
		var weighted: Array = []   # las ideas que piden mover bloques salen más (3 a 1) a medida que sube la dificultad: las que se resuelven caminando son el respiro de la torre
		for name in pool:
			for _w in ((1 + int(maxf(difficulty - 0.2, 0.0) * 120.0)) if _puzzle(name) else ((1 + int(clampf(difficulty * 6.0, 0.0, 2.0))) if _grabby(name, difficulty) else 1)):
				weighted.append(name)
		var idea: String = weighted[rng.randi_range(0, weighted.size() - 1)]
		var twists: Array = IDEAS[idea].twists.duplicate()
		if twists.size() > 1 and last_twist.has(idea):
			twists.erase(last_twist[idea])
		var twist: String = twists[rng.randi_range(0, twists.size() - 1)]
		last_twist[idea] = twist
		if not _grabby(idea, difficulty):
			plain_rooms += 1
		out.append({"idea": idea, "twist": twist})
	return out


## ¿Es una sala de acertijo de bloques (las que traen su solución ya calculada)?
static func _puzzle(name: String) -> bool:
	return name == "taller" or name == "chica" or name == "mediana"


## Pisos de la sala de una idea (2 las de pared, trampas y agrietado; 4 las de hielo, bomba y catapulta).
static func _room_h(name: String, twist := "") -> int:
	if name == "chica":
		return 4 if twist == "baja" else 5   # (las salas chicas con altura: 4 o 5 pisos)
	if name == "mediana":
		return {"baja": 8, "media": 9}.get(twist, 10)   # (dos salas verticales una encima de la otra)
	return int(IDEAS[name].get("h", ROOM))


## ¿La idea obliga a mover bloques con esta dificultad? (El campo de trampas, desde 0,25, termina en una puerta de bloque que hay que empujar.)
static func _grabby(name: String, difficulty: float) -> bool:
	return bool(IDEAS[name].grab) or (name == "campo_trampas" and difficulty >= 0.25)


static func generate_stage(seed_value: int, rows: int, difficulty: float, opts: Dictionary = {}) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var token = opts.get("cancel_token", null)
	var last := "cancelado"
	for a in 3:
		if Gen._stopped(token):
			break
		var res := _generate_once(seed_value + a * 100003, rows, difficulty, opts)
		if res.ok:
			res["attempts"] = a + 1
			res["ms"] = Time.get_ticks_msec() - t0
			return res
		last = str(res.get("error", ""))
	return {"ok": false, "error": last}


static func _generate_once(seed_value: int, rows: int, difficulty: float, opts: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var token = opts.get("cancel_token", null)
	var ideas := catalog(str(opts.get("scenario", "")), difficulty)
	var order := plan(rng, 16, difficulty, ideas)
	var base := _new_base(rows)
	var st := {"tower": base.tower, "sim": base.sim, "path": [], "row_moves": [] as Array[int], "shapes": [] as Array[String],
			"infos": [], "reserved": {Vector3i(START.x, 1, START.y): true}, "states": 0, "solves": 0, "used": {}, "last_twist": {}, "last_idea": ""}
	var snaps: Array = []   # el estado antes de cada sala: si una no entra, se vuelve atrás y se rehace la anterior de otra manera
	var eys: Array[int] = []   # el piso donde empieza cada sala (las ideas de pared son de 2 pisos; las de hielo, bomba y catapulta, de 4)
	var rooms_done: Array = []
	var backtracks := 0
	var i := 0
	var ey := 1
	while true:
		if Gen._stopped(token):
			return {"ok": false, "error": "cancelado"}
		var remaining := rows + 1 - ey
		var spec: Dictionary = order[mini(i, order.size() - 1)]
		var h := 2 if spec.idea == "respiro" else _room_h(spec.idea, str(spec.get("twist", "")))
		if remaining - h < 1 or remaining <= 2:   # lo que queda es el tramo hasta el portal
			if remaining > ROOM:
				spec = {"idea": "muro_simple", "twist": "chico"} if ideas.has("muro_simple") else {"idea": "respiro", "twist": ""}
				h = 2
			else:
				break
		if snaps.size() <= i:
			snaps.append(_snapshot(st))
			eys.append(ey)
		var res := place_room(st, ey, h, rng, i, 8, spec, difficulty, ideas, false, token)
		if not res.ok:
			if i == 0 or backtracks >= 4:
				return {"ok": false, "error": "no entró la sala %d (%s)" % [i + 1, spec.idea]}
			backtracks += 1
			i -= 1
			st = _snapshot(snaps[i])
			ey = eys[i]
			rooms_done.resize(i)
			continue
		var done := {"idea": res.idea, "twist": res.twist, "h": h, "ey": ey}
		rooms_done.append(done)
		order[mini(i, order.size() - 1)]["idea"] = res.idea
		ey += h
		i += 1
		if i >= order.size() + 8:
			break
	var fin := place_room(st, ey, rows + 1 - ey, rng, i, i + 1, {"idea": "respiro", "twist": ""}, difficulty, ideas, true, token)
	if not fin.ok:
		return {"ok": false, "error": "no entró el tramo del portal"}
	var pace: Dictionary = Gen.PACES[opts.get("pace", "normal")]
	var band := Gen.band_for(difficulty)
	var close_opts: Dictionary = opts.duplicate()
	close_opts["slack"] = 3.0   # (de acá se baja: el ritmo final lo elige tightest_n con holgura para equivocarse)
	var res: Dictionary = Gen._close_tower(st.tower, st.sim, st.path, st.row_moves, st.shapes, st.infos, st.states, [], close_opts, difficulty, pace, band, rows)
	if res.ok:
		res["rooms"] = rooms_done
		if difficulty >= 0.1:   # la caída se aprieta hasta que sólo se aguanten unos pocos titubeos (cuanto más difícil, menos: 12 a 4 titubeos, o sea 24 a 8 movimientos de más)
			var k := maxi(int(round(lerpf(14.0, 8.0, clampf((difficulty - 0.1) / 0.9, 0.0, 1.0)))), res.path.size() / 3)   # (y en una torre de acertijos largos se titubea mucho: se aguanta como mínimo un 40 % de movimientos de más)
			var trng := RandomNumberGenerator.new()
			trng.seed = seed_value + 99
			var grace := 2.0   # (la primera caída tarda el doble: tiempo para explorar)
			var n_orig: int = int(res.collapse_every)
			var n := Metrics.tightest_n(res.logic, res.path, n_orig, k, 0.9, trng, grace)
			if Metrics.survival(res.logic, res.path, n, 0, 1, trng, grace) < 1.0:   # (si ninguno sirve con esta gracia, queda el ritmo de antes, que se comprobó con el doble)
				n = n_orig
				grace = 2.0
			res.logic.collapse_every = n
			res.logic.moves_to_collapse = maxi(int(round(float(n) * grace)), 1)
			res["collapse_every"] = n
	return res


## Copia independiente del estado de generación.
static func _snapshot(st: Dictionary) -> Dictionary:
	var t = st.tower.clone()
	t.row_platforms = t.row_platforms.duplicate()
	t.platform_row = t.platform_row.duplicate()
	var rm: Array[int] = []
	rm.append_array(st.row_moves)
	var sh: Array[String] = []
	sh.append_array(st.shapes)
	return {"tower": t, "sim": st.sim.clone(), "path": st.path.duplicate(), "row_moves": rm, "shapes": sh, "infos": st.infos.duplicate(true),
			"reserved": st.reserved.duplicate(), "states": st.states, "solves": st.solves, "used": st.used.duplicate(), "last_twist": st.last_twist.duplicate(), "last_idea": st.last_idea}


## La torre vacía: el core (fijo, de arriba a abajo) y el bloque donde empieza el jugador; el resto del piso lo agrega la primera sala.
static func _new_base(rows: int) -> Dictionary:
	var tower := TowerLogic.new()
	tower.size = Vector2i(SIZE, SIZE)
	tower.collapse_every = Gen.BIG
	tower.moves_to_collapse = Gen.BIG
	for y in range(0, rows + 2):
		for z in range(CORE.position.y, CORE.end.y):
			for x in range(CORE.position.x, CORE.end.x):
				tower.add_block(Vector3i(x, y, z), true)
	tower.add_block(Vector3i(START.x, 0, START.y))
	tower.goal_y = rows + 1
	tower.player = Vector3i(START.x, 1, START.y)
	var sim0 = tower.clone()
	sim0.lazy_settle = true   # (sólo se tocan bloques con add_block y con las acciones: ver TowerLogic._settle_blocks)
	sim0._blocks_dirty = true
	sim0.goal_y = Gen.BIG
	return {"tower": tower, "sim": sim0}


# --- una sala ----------------------------------------------------------------------------------------------------------------------------------

## Arma la sala de `h` pisos que empieza en el piso `ey` (donde está parado el jugador) con la idea del plan; si no entra, prueba con las otras del catálogo y, al final, con un respiro.
static func place_room(st: Dictionary, ey: int, h: int, rng: RandomNumberGenerator, index: int, total: int, spec: Dictionary, difficulty: float, ideas: Array, final: bool, token = null) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var solves0: int = st.solves
	var order: Array = [spec]
	if spec.idea != "respiro":
		# si la idea del plan no entra, se prueban las otras: primero las que menos salieron en la torre y no la de la sala anterior
		var others := ideas.duplicate()
		others.erase(spec.idea)
		others = others.filter(func(o): return _room_h(o) <= h)
		if difficulty > 0.2 and ideas.size() > 3:   # (de reemplazo, las que se resuelven caminando sólo si no salió ninguna antes)
			var plain_used := 0
			for u in st.used:
				if u != "respiro" and not _grabby(u, difficulty):
					plain_used += int(st.used[u])
			if plain_used >= 1:
				others = others.filter(func(o): return _grabby(o, difficulty))
		var ranked: Array = []
		while not others.is_empty():
			var o: String = others.pop_at(rng.randi_range(0, others.size() - 1))
			ranked.append([int(st.used.get(o, 0)) + (100 if o == st.last_idea else 0), o])
		ranked.sort_custom(func(a, b): return a[0] < b[0])
		if difficulty >= REJA_FROM and int(st.used.get("taller", 0)) < 7:   # (de reemplazo, primero la reja: es la que más se arma y la que más pide; un respiro sólo si nada entra)
			for r in ranked:
				if r[1] == "taller":
					ranked.erase(r)
					ranked.push_front(r)
					break
		for pair in ranked:
			var o: String = pair[1]
			var tw: Array = IDEAS[o].twists.duplicate()
			if tw.size() > 1 and st.last_twist.has(o):
				tw.erase(st.last_twist[o])
			order.append({"idea": o, "twist": tw[rng.randi_range(0, tw.size() - 1)]})
		order.append({"idea": "respiro", "twist": ""})
	if OS.get_environment("NO_FALLBACK") != "":   # (desarrollo) para medir una idea sola
		order = [spec]
	var res := {"ok": false}
	var arr := Vector2i(st.sim.player.x, st.sim.player.z)
	var around := 0   # ¿hay dónde apoyar piso al lado de la llegada? Si no, ninguna sala entra: se falla enseguida (y se rehace la anterior)
	for d in DIRS4:
		if _ok(arr + d) and _floor_ok(st, arr + d, ey) and _free(st, arr + d, ey, ey):
			around += 1
	if around == 0:
		return res
	for k in order.size():
		if Gen._stopped(token):
			break
		if k > 0 and k < order.size() - 1 and (Time.get_ticks_msec() - t0 > ROOM_MS or st.solves - solves0 > ROOM_SOLVES):
			continue   # (se gastó el tiempo de esta sala: se salta directo al respiro)
		var name: String = order[k].idea
		var lo := 2
		var hi := 14
		if name != "respiro":
			lo = maxi(int(float(int(IDEAS[name].base) + int(difficulty * 2.0) + index / 5) * (0.5 + 0.5 * float(h) / float(ROOM))), 5)
			hi = lo + 16
		res = _attempt(st, ey, h, rng, name, str(order[k].twist), lo, hi, difficulty, final, 1.0 if k == 0 else 0.4)   # (las ideas de reemplazo piden menos: mejor una sala más fácil que un respiro)
		if res.ok:
			res["idea"] = name
			st.used[name] = int(st.used.get(name, 0)) + 1
			st.last_idea = name
			st.last_twist[name] = str(order[k].twist)
			break
	if OS.get_environment("IDEA_LOG") != "":
		print("  sala %d (%s/%s) ey=%d -> %s %d ms" % [index, spec.idea, spec.twist, ey, str(res.get("idea", "NADA")), Time.get_ticks_msec() - t0])
	return res


static func _attempt(st: Dictionary, ey: int, h: int, rng: RandomNumberGenerator, name: String, twist: String, lo: int, hi: int, difficulty: float, final: bool, strict := 1.0) -> Dictionary:
	var sim = st.sim
	if sim.player.y != ey or sim.hang_dir != Vector3i.ZERO or sim.lost:
		return {"ok": false}
	var cells: Array[Vector2i] = []
	var cellset := {}
	for x in SIZE:
		for z in SIZE:
			var c := Vector2i(x, z)
			if _ok(c) and _floor_ok(st, c, ey):
				cells.append(c)
				cellset[c] = true
	var ctx := {"idea": name, "rng": rng, "st": st, "ey": ey, "h": h, "arrival": Vector2i(sim.player.x, sim.player.z), "cells": cells, "cellset": cellset, "twist": twist, "d": difficulty, "strict": strict}
	var t0 := Time.get_ticks_msec()
	var start_calls: int = st.solves
	var want := 1 if (name == "respiro" or name == "reja" or _puzzle(name) or final or difficulty < 0.3) else (2 if difficulty < 0.7 else 3)   # cuanto más difícil, entre más salas válidas se elige la más exigente
	ctx["pick"] = want
	var base: Dictionary = _snapshot(st) if want > 1 else {}
	var best: Dictionary = {}
	var best_state: Dictionary = {}
	var found := 0
	for i in (TALLER_CANDIDATES if (name == "taller" or name == "reja") else MAX_CANDIDATES):   # armar candidatos es barato; lo caro es resolverlos: el tope es de resoluciones y de tiempo
		if st.solves - start_calls >= (TRIES * (1 if want == 1 else 3 / 2)) * (3 if name == "reja" else 1) or Time.get_ticks_msec() - t0 > MAX_MS:
			break
		var cand := _candidate(name, ctx)
		if cand.is_empty():
			continue
		var done := _commit(ctx, cand, name, lo, hi, final)
		if not done.ok:
			continue
		if want == 1:
			return done
		found += 1
		if best.is_empty() or float(done.score) > float(best.score):
			best = done
			best_state = _snapshot(st)
		_restore(st, base)
		if found >= want:
			break
	if not best.is_empty():
		_restore(st, best_state)
		return best
	return {"ok": false}


## Vuelve el estado de generación a una copia (la de `_snapshot`); el contador de resoluciones sigue contando todo lo que se trabajó.
static func _restore(st: Dictionary, snap: Dictionary) -> void:
	var solves: int = st.solves
	var c := _snapshot(snap)
	for k in c:
		st[k] = c[k]
	st.solves = solves


static func _ok(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < SIZE and c.y < SIZE and not CORE.has_point(c)


## ¿Puede haber piso en esa celda (en la capa donde está parado el jugador, una más abajo)? Sí si ya hay un bloque o si el camino anterior no pasa por ahí.
static func _floor_ok(st: Dictionary, c: Vector2i, ey: int) -> bool:
	var cell := Vector3i(c.x, ey - 1, c.y)
	return st.tower.blocks.has(cell) or not st.reserved.has(cell)


## ¿Se puede agregar un piso propio (por ejemplo, de hielo) en esa celda?
static func _addable(st: Dictionary, c: Vector2i, ey: int) -> bool:
	var cell := Vector3i(c.x, ey - 1, c.y)
	return not st.tower.blocks.has(cell) and not st.sim.blocks.has(cell) and not st.reserved.has(cell)


static func _free(st: Dictionary, c: Vector2i, y0: int, y1: int) -> bool:
	for y in range(y0, y1 + 1):
		var cell := Vector3i(c.x, y, c.y)
		if st.tower.blocks.has(cell) or st.sim.blocks.has(cell) or st.reserved.has(cell):
			return false
	return true


static func _pick(ctx: Dictionary) -> Vector2i:
	var cells: Array[Vector2i] = ctx.cells
	return cells[ctx.rng.randi_range(0, cells.size() - 1)]


## La escalera de salida: `h` columnas pegadas entre sí, de alturas 1 a h (la última lleva el tope: el piso de la sala siguiente o el portal).
static func _chain(ctx: Dictionary, h: int, avoid := {}, min_dist := 2) -> Array[Vector2i]:
	var rng: RandomNumberGenerator = ctx.rng
	var arrival: Vector2i = ctx.arrival
	var options: Array[Vector2i] = []
	for c in ctx.cells:
		if absi(c.x - arrival.x) + absi(c.y - arrival.y) >= min_dist and not avoid.has(c) and _free(ctx.st, c, ctx.ey, ctx.ey):
			options.append(c)
	if options.is_empty():
		return []
	var chain: Array[Vector2i] = [options[rng.randi_range(0, options.size() - 1)]]
	for k in range(1, h):
		var next := Vector2i(-9, -9)
		for t in 30:
			var n: Vector2i = chain[chain.size() - 1] + DIRS4[rng.randi_range(0, 3)]
			if ctx.cellset.has(n) and not chain.has(n) and not avoid.has(n) and n != arrival and _free(ctx.st, n, ctx.ey, ctx.ey + k):
				next = n
				break
		if next.x < 0:
			return []
		chain.append(next)
	return chain


static func _add_chain(cols: Dictionary, chain: Array[Vector2i]) -> void:
	for k in chain.size():
		cols[chain[k]] = {"h": k + 1, "kind": K.NORMAL}


## Celdas vecinas de la escalera (que no son de ella) donde puede haber pared de `hgt` de alto.
static func _ring(ctx: Dictionary, chain: Array[Vector2i], cols: Dictionary, hgt: int, skip := {}) -> Array[Vector2i]:
	var ring: Array[Vector2i] = []
	for cc in chain:
		for d in DIRS4:
			var n: Vector2i = cc + d
			if ctx.cellset.has(n) and not cols.has(n) and n != ctx.arrival and not skip.has(n) and not ring.has(n) and _free(ctx.st, n, ctx.ey, ctx.ey + hgt - 1):
				ring.append(n)
	return ring


static func _near(ctx: Dictionary, center: Vector2i, r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in ctx.cells:
		if absi(c.x - center.x) + absi(c.y - center.y) <= r:
			out.append(c)
	return out


## Celdas a las que se llega a pie desde la llegada sin pasar por los bloques ya puestos.
static func _walk_reach(ctx: Dictionary, cols: Dictionary) -> Dictionary:
	var seen := {ctx.arrival: true}
	var queue: Array[Vector2i] = [ctx.arrival]
	var i := 0
	while i < queue.size():
		var c := queue[i]
		i += 1
		for d in DIRS4:
			var n: Vector2i = c + d
			if ctx.cellset.has(n) and not seen.has(n) and not cols.has(n):
				seen[n] = true
				queue.append(n)
	return seen


## ¿Se puede parar a pie de un lado de la celda y empujar lo que haya hacia el lado opuesto?
static func _pushable(ctx: Dictionary, c: Vector2i, cols: Dictionary, reach: Dictionary) -> bool:
	for d in DIRS4:
		var a: Vector2i = c - d
		var b: Vector2i = c + d
		if reach.has(a) and ctx.cellset.has(b) and not cols.has(b):
			return true
	return false


static func _decoys(ctx: Dictionary, cols: Dictionary, kind: int, count: int, hmax := 2, pool: Array = []) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var cells: Array = pool if not pool.is_empty() else ctx.cells
	for i in count + (int(ctx.d * 3.0) if kind == K.HEAVY else 0):
		var c: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		if not cols.has(c) and c != ctx.arrival and (c - ctx.arrival).length() >= 1.5 and _free(ctx.st, c, ctx.ey, ctx.ey + hmax - 1):
			cols[c] = {"h": rng.randi_range(1, hmax) if kind != K.NORMAL else 1, "kind": kind}


## Rectángulos de w x d celdas (con el core en el medio, los que entran son tiras de 2 o 3 de ancho) donde se puede poner un piso propio: [origen, ...].
static func _rect_origins(ctx: Dictionary, w: int, d: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for ox in range(0, SIZE - w + 1):
		for oz in range(0, SIZE - d + 1):
			var ok := true
			for x in w:
				for z in d:
					var c := Vector2i(ox + x, oz + z)
					if not (ctx.cellset.has(c) and c != ctx.arrival and _addable(ctx.st, c, ctx.ey) and _free(ctx.st, c, ctx.ey, ctx.ey + 1)):
						ok = false
						break
				if not ok:
					break
			if ok:
				out.append(Vector2i(ox, oz))
	return out


static func _candidate(name: String, ctx: Dictionary) -> Dictionary:
	match name:
		"respiro":
			return _c_respiro(ctx)
		"hielo_freno":
			return _c_freno(ctx)
		"hielo_pista":
			return _c_pista(ctx)
		"hielo_billar":
			return _c_billar(ctx)
		"pared_pesada", "muro_simple":
			return _c_pesada(ctx)
		"cruce_agrietado":
			return _c_cruce(ctx)
		"pared_pinchos":
			return _c_pinchos(ctx)
		"campo_trampas":
			return _c_trampas(ctx)
		"cuenta_bomba":
			return _c_bomba(ctx)
		"trampolin":
			return _c_trampolin(ctx)
		"reja":
			return _c_reja(ctx)
		"taller":
			return _c_taller(ctx)
		"chica":
			return _c_chica(ctx)
		"mediana":
			return _c_mediana(ctx)
	return {}


# --- las ideas ---------------------------------------------------------------------------------------------------------------------------------

## Taller (un puzzle de cajas, como Sokoban): una arena chica con muros pesados de 3 de alto (no se trepan ni se mueven) y cajas comunes. El pilar de la salida mide 2: sólo se sube
## si hay una caja de escalón en su única celda libre. La disposición se busca con el solucionador (hill-climbing): se parte de una al azar que se pueda resolver y se la va cambiando
## (mover una caja, un muro) mientras el camino más corto crezca. Lo que sale es exactamente lo que cuesta de verdad, no una estimación.
const TALLER_CANDIDATES := 40   # intentos de armar una sala de cajas (se cuentan, no se miden en tiempo: así la misma semilla da la misma torre)
const TALLER_WORK := 110000   # estados del solucionador en total por sala antes de rendirse
const TALLER_CLIMB := 14   # cambios de muro o caja que se prueban sobre la mejor disposición
const TALLER_CHECK_STATES := 15000   # estados del solucionador completo (con colgarse y todo) que comprueba que no haya atajos
const TALLER_S0 := 4   # salas chicas resueltas de las que se parte (cada una se explora entera)
const TALLER_STATES := 9000   # estados que se exploran por sala resuelta
const TALLER_LAYOUTS := 16   # disposiciones que se miran enteras (se queda la que deja el acertijo más largo)
const VERT_CAP := 12000   # estados del solucionador por disposición de una sala chica con altura
const TALLER_CAP := 9000   # estados del solucionador por disposición (si no la resuelve en eso, no sirve)   # estados del solucionador por evaluación


## La arena sola, en una torre chica: piso fijo, el pilar (la salida), los muros, las cajas, y el jugador en la llegada. La capa 1 es la de la sala.
static func _taller_mini(cells: Array[Vector2i], arrival: Vector2i, pillar: Vector2i, walls: Array, boxes: Array, env: Array = []):
	var t := TowerLogic.new()
	t.size = Vector2i(SIZE, SIZE)
	t.collapse_every = Gen.BIG
	t.moves_to_collapse = Gen.BIG
	for c in cells:
		t.add_block(Vector3i(c.x, 0, c.y), true)
	t.add_block(Vector3i(arrival.x, 0, arrival.y), true)
	for e in env:   # lo que ya hay alrededor en la torre (el core, lo de las salas de abajo) cuenta como pared fija: si no, el acertijo se arma sobre un mundo que no es el real
		if not t.blocks.has(e):
			t.add_block(e, true)
	t.add_block(Vector3i(pillar.x, 1, pillar.y), false, K.HEAVY)
	t.add_block(Vector3i(pillar.x, 2, pillar.y), true, K.NORMAL)   # (el tope de la salida es fijo: no se puede sacar del pilar)
	var goal_id: int = t.blocks[Vector3i(pillar.x, 2, pillar.y)]
	for c in walls:
		for y in range(1, 4):
			t.add_block(Vector3i(c.x, y, c.y), false, K.HEAVY)
	for c in boxes:
		t.add_block(Vector3i(c.x, 1, c.y), false, K.NORMAL)
	t.player = Vector3i(arrival.x, 1, arrival.y)
	t.goal_y = 3
	t.goal_ids = {goal_id: true}
	return t


## Todo lo que se puede alcanzar de la arena resuelta (el jugador arriba del pilar, una caja de escalón) con movimientos que se pueden deshacer, y qué tan lejos queda cada estado de poder
## subir (el camino más corto, exacto dentro de esos estados). Devuelve el estado más lejano con el jugador en la llegada: {boxes, dist, path, states} o {}.
## Es la forma de armar los acertijos de cajas más largos que admite una arena (como los generadores de Sokoban): no se sortea y se espera, se mira todo.
static func _taller_far(cells: Array[Vector2i], arrival: Vector2i, pillar: Vector2i, walls: Array, boxes: Array, rng: RandomNumberGenerator, cap: int, max_dist := 999, work_ctx: Dictionary = {}, env: Array = []) -> Dictionary:
	var t0 = _taller_mini(cells, arrival, pillar, walls, boxes, env)
	t0.player = Vector3i(pillar.x, 3, pillar.y)
	var goal_id: int = t0.goal_ids.keys()[0]
	var count0: int = t0.blocks.size()
	var allowed := {arrival: true}   # las cajas sólo pueden estar donde hay piso (en una torre real, fuera de ahí no hay nada: ni hay cómo quedar colgada)
	for c in cells:
		allowed[c] = true
	var box_ids: Array[int] = []
	for c in boxes:
		box_ids.append(t0.blocks[Vector3i(c.x, 1, c.y)])
	var actions: Array = []
	for d in TowerLogic.DIRS:
		for mode in [TowerLogic.Mode.MOVE, TowerLogic.Mode.GRAB]:
			actions.append([d, mode])
	var key0: Vector3i = Solver.state_key(t0)
	var nodes := {key0: t0}
	var order: Array = [key0]
	var inn := {}   # y -> [[x, costo, acciones]]: desde x, esas acciones llevan a y
	var goals: Array = []
	var qi := 0
	while qi < order.size() and order.size() < cap:
		var k: Vector3i = order[qi]
		qi += 1
		var st = nodes[k]
		if st.player.y >= 3 and st.blocks.get(st.player + Vector3i.DOWN, -2) == goal_id:
			goals.append(k)
		for o in actions:
			var n = st.clone()
			if not n.try_action(o[0], o[1]).ok or n.lost or n.hang_dir != Vector3i.ZERO or n.blocks.size() != count0:
				continue
			var misplaced := false
			for bid in box_ids:
				var bp: Vector3i = n.positions[bid]
				if bp.y != 1 or not allowed.has(Vector2i(bp.x, bp.z)):
					misplaced = true
					break
			if misplaced:
				continue
			var nk: Vector3i = Solver.state_key(n)
			if nk == k:
				continue
			var od: Vector3i = o[0]
			var tries: Array = []
			if o[1] == TowerLogic.Mode.MOVE:
				tries = [[[-od, TowerLogic.Mode.MOVE]]]
			else:
				tries = [[[od, TowerLogic.Mode.MOVE], [-od, TowerLogic.Mode.GRAB]], [[-od, TowerLogic.Mode.GRAB], [-od, TowerLogic.Mode.MOVE]]]
			var inv = null
			for seq in tries:
				var b = n.clone()
				var okseq := true
				for a1 in seq:
					if not b.try_action(a1[0], a1[1]).ok or b.lost:
						okseq = false
						break
				if okseq and b.player == st.player and Solver.state_key(b) == k:
					inv = seq
					break
			if inv == null:
				continue
			if not inn.has(nk):
				inn[nk] = []
			inn[nk].append([k, 1, [o]])   # desde k, la acción o lleva a nk
			if not inn.has(k):
				inn[k] = []
			inn[k].append([nk, inv.size(), inv])   # desde nk, `inv` vuelve a k
			if not nodes.has(nk):
				nodes[nk] = n
				order.append(nk)
	if qi < order.size():   # (la búsqueda quedó a medias: los estados del borde tendrían caminos más cortos que no se ven; sólo sirve si se miró todo)
		if not work_ctx.is_empty():
			work_ctx["work"] = int(work_ctx.get("work", 0)) + order.size()
		_why("taller: demasiados estados (%d)" % order.size())
		return {}
	if not work_ctx.is_empty():
		work_ctx["work"] = int(work_ctx.get("work", 0)) + order.size()   # (el trabajo total de una sala se limita: así una sala imposible no se come minutos)
	if goals.is_empty():
		_why("taller: sin metas (%d estados)" % order.size())
		return {}
	# camino más corto hacia las metas (Dijkstra por niveles, costos 1 y 2)
	var dist := {}
	var nxt := {}
	var gr := {}   # agarres del camino más corto de cada estado
	var levels: Array = [[]]
	for g in goals:
		dist[g] = 0
		gr[g] = 0
		levels[0].append(g)
	var lv := 0
	while lv < levels.size():
		for k in levels[lv]:
			if int(dist[k]) != lv:
				continue
			for e in inn.get(k, []):
				var x: Vector3i = e[0]
				var nd: int = lv + int(e[1])
				var eg := 0
				for a in e[2]:
					if a[1] == TowerLogic.Mode.GRAB:
						eg += 1
				if not dist.has(x) or nd < int(dist[x]) or (nd == int(dist[x]) and int(gr[k]) + eg > int(gr[x])):
					dist[x] = nd
					gr[x] = int(gr[k]) + eg
					nxt[x] = [k, e[2]]
					while levels.size() <= nd:
						levels.append([])
					levels[nd].append(x)
		lv += 1
	var best_k := Vector3i.ZERO
	var best_d := -1
	var best_s := -1
	var arrival_pos := Vector3i(arrival.x, 1, arrival.y)
	var ties: Array = []
	for k in order:
		var st = nodes[k]
		if st.player != arrival_pos or not dist.has(k) or int(dist[k]) == 0:
			continue
		if not _open_start(st, 4, 1):
			continue
		var dk: int = dist[k]
		if dk > max_dist:
			continue   # (a dificultad baja no se pide el acertijo más largo posible, sino uno de tamaño acorde)
		var sk: int = dk + 6 * int(gr[k])   # (lo que mide el acertijo son los bloques que hay que mover —cada agarre—; los pasos a pie casi no cuentan)
		if sk > best_s:
			best_s = sk
			best_d = dk
			ties = [k]
		elif sk == best_s:
			ties.append(k)
	if best_d < 0:
		var at_arrival := 0
		for k in order:
			if nodes[k].player == arrival_pos:
				at_arrival += 1
		_why("taller: ningún estado sirve de comienzo (%d estados, %d metas, %d con el jugador en la llegada)" % [order.size(), goals.size(), at_arrival])
		if OS.get_environment("DEBUG_TALLER") != "":
			for zz in 8:
				var row := ""
				for xx in 8:
					var c := Vector2i(xx, zz)
					row += "A " if c == arrival else ("G " if c == pillar else ("# " if walls.has(c) else ("n " if boxes.has(c) else (". " if cells.has(c) else "  "))))
				print("        " + row)
		return {}
	best_k = ties[rng.randi_range(0, ties.size() - 1)]
	var path: Array = []
	var cur: Vector3i = best_k
	var guard := 0
	while int(dist[cur]) > 0 and guard < 400:
		var step: Array = nxt[cur]
		for a in step[1]:
			path.append({"dir": a[0], "mode": a[1]})
		cur = step[0]
		guard += 1
	var st_end = nodes[best_k]
	var boxes_end: Array = []
	for bid in box_ids:   # (sólo las cajas: lo demás —el core, lo de las salas de abajo— ya está en la torre)
		var bp: Vector3i = st_end.positions[bid]
		boxes_end.append(Vector2i(bp.x, bp.z))
	if OS.get_environment("DEBUG_BFS") != "":
		var sv: Dictionary = Solver.solve(st_end.clone(), 3, {"max_states": 5000, "goal_ids": st_end.goal_ids})
		print("     BFS: estados %d, dist %d, agarres %d | solucionador sobre ese estado: %s %d mov | camino BFS %d acciones" % [order.size(), best_d, int(gr[best_k]), sv.status, sv.moves, path.size()])
		if sv.status == "solved" and sv.moves < best_d - 3:
			var tr = st_end.clone()
			for a in sv.path:
				tr.try_action(a.dir, a.mode)
				print("          solucionador: %s %s -> %s hang %s" % [str(a.dir), str(a.mode), str(tr.player), str(tr.hang_dir)])
	var path_grabs := 0
	for a in path:
		if a.mode == TowerLogic.Mode.GRAB:
			path_grabs += 1
	return {"boxes": boxes_end, "dist": best_d, "grabs": path_grabs, "path": path, "states": order.size(), "score": best_s}


## El pasillo más corto de celdas de piso desde la llegada hasta tocar la arena `cs` (las celdas de la arena no cuentan): [] si la llegada ya la toca; [(-99, -99)] si no hay.
static func _taller_corridor(ctx: Dictionary, cs: Dictionary) -> Array[Vector2i]:
	var none: Array[Vector2i] = [Vector2i(-99, -99)]
	for d in DIRS4:
		if cs.has(ctx.arrival + d):
			var empty: Array[Vector2i] = []
			return empty
	var prev := {ctx.arrival: ctx.arrival}
	var queue: Array[Vector2i] = [ctx.arrival]
	var qi := 0
	while qi < queue.size():
		var c := queue[qi]
		qi += 1
		for d in DIRS4:
			var n: Vector2i = c + d
			if prev.has(n) or cs.has(n) or not ctx.cellset.has(n) or not _addable(ctx.st, n, ctx.ey) or not _free(ctx.st, n, ctx.ey, ctx.ey + 2):
				continue
			prev[n] = c
			var touches := false
			for d2 in DIRS4:
				if cs.has(n + d2):
					touches = true
			if touches:
				var out: Array[Vector2i] = []
				var cur := n
				while cur != ctx.arrival:
					out.push_front(cur)
					cur = prev[cur]
				return out
			queue.append(n)
	return none


## ¿Sin mover nada, desde la llegada se llega a T y a todo lo libre? Si no, la arena resuelta es una celda sin salida.
static func _taller_connected(ctx: Dictionary, cset: Dictionary, walls: Array, pillar: Vector2i, tcell: Vector2i, total_cells: int) -> bool:
	var wset := {}
	for c in walls:
		wset[c] = true
	var seen := {ctx.arrival: true}
	var fq: Array[Vector2i] = [ctx.arrival]
	var fi := 0
	while fi < fq.size():
		var fc := fq[fi]
		fi += 1
		for d in DIRS4:
			var fnb: Vector2i = fc + d
			if (cset.has(fnb) or fnb == ctx.arrival) and not wset.has(fnb) and fnb != pillar and not seen.has(fnb):
				seen[fnb] = true
				fq.append(fnb)
	return seen.has(tcell) and seen.size() >= total_cells - walls.size() - 1


## Evalúa una disposición: el solucionador completo, con tope, desde la llegada. {ok, dist, grabs, path, states, score}; `ctx.work` suma los estados mirados (el trabajo de la sala es limitado).
static func _taller_eval(cells: Array[Vector2i], arrival: Vector2i, pillar: Vector2i, walls: Array, boxes: Array, env: Array, work_ctx: Dictionary) -> Dictionary:
	var t = _taller_mini(cells, arrival, pillar, walls, boxes, env)
	var res: Dictionary = Solver.solve(t, 3, {"max_states": TALLER_CAP, "goal_ids": t.goal_ids})
	work_ctx["work"] = int(work_ctx.get("work", 0)) + int(res.states)
	if res.status != "solved":
		return {"ok": false}
	var plain: Dictionary = Solver.solve(_taller_mini(cells, arrival, pillar, walls, boxes, env), 3, {"max_states": TALLER_CAP, "goal_ids": t.goal_ids, "no_grab": true})
	work_ctx["work"] = int(work_ctx.get("work", 0)) + int(plain.states)
	if plain.status == "solved":   # (sin tocar ninguna caja: atajo)
		return {"ok": false, "atajo": true}
	var grabs := 0
	for a in res.path:
		if a.mode == TowerLogic.Mode.GRAB:
			grabs += 1
	var moved := _moved_blocks(_taller_mini(cells, arrival, pillar, walls, boxes, env), res.path)
	return {"ok": true, "dist": res.moves, "grabs": grabs, "moved": moved, "path": res.path, "states": res.states, "score": 10 * moved + 4 * grabs + res.moves}


static func _c_taller(ctx: Dictionary) -> Dictionary:
	if ctx.h != 2:   # (el pilar mide 2: la sala es de 2 pisos; si el hueco es de 4 —una idea de hielo que no entró— no sirve)
		return {}
	if int(ctx.get("work", 0)) > TALLER_WORK:
		return {}
	var rng: RandomNumberGenerator = ctx.rng
	var env: Array = []   # los bloques que ya hay alrededor, en las coordenadas de la arena sola (la capa 0 es el piso de la sala)
	for c in ctx.st.sim.blocks:
		if c.y >= ctx.ey - 1 and c.y <= ctx.ey + 2:
			env.append(Vector3i(c.x, c.y - ctx.ey + 1, c.z))
	if OS.get_environment("DEBUG_TALLER") != "":
		print("      entorno: %d bloques, sim %d, ey %d, núcleo en (3,%d,3)? %s" % [env.size(), ctx.st.sim.blocks.size(), ctx.ey, ctx.ey, str(ctx.st.sim.blocks.has(Vector3i(3, ctx.ey, 3)))])
	var shapes: Array = [[3, 3], [4, 3], [3, 4], [5, 3], [3, 5], [4, 4], [6, 3], [3, 6]]
	if ctx.d > 0.35:   # (las tiras de 3 de ancho alrededor del core: salen arenas largas, donde caben acertijos más profundos)
		shapes.append_array([[6, 3], [3, 6], [7, 3], [3, 7], [8, 3], [3, 8], [6, 3], [3, 6], [7, 3], [3, 7]])
	var w := 0
	var dp := 0
	var origins: Array[Vector2i] = []
	while not shapes.is_empty():   # (se prueba cada forma, en orden al azar, hasta que alguna entre: así cada intento arma de verdad una sala)
		var sh: Array = shapes.pop_at(rng.randi_range(0, shapes.size() - 1))
		origins = _rect_origins(ctx, sh[0], sh[1])
		if not origins.is_empty():
			w = sh[0]
			dp = sh[1]
			break
	if origins.is_empty():
		_why("taller: sin lugar 1")
		return {}
	# la arena puede estar lejos de la llegada: se une con un pasillo de piso (de hasta 4 celdas) que se camina de uno al otro (el pasillo también es parte del acertijo: las cajas pueden ir ahí)
	var o := Vector2i(-9, -9)
	var cells: Array[Vector2i] = []
	var cset := {}
	var corridor: Array[Vector2i] = []
	for _try in mini(6, origins.size()):
		var cand_o: Vector2i = origins.pop_at(rng.randi_range(0, origins.size() - 1))
		var cs := {}
		for x in w:
			for z in dp:
				cs[cand_o + Vector2i(x, z)] = true
		var path: Array[Vector2i] = _taller_corridor(ctx, cs)
		if path.size() > 4 or (path.size() == 1 and path[0] == Vector2i(-99, -99)):
			continue
		o = cand_o
		cset = cs
		corridor = path
		break
	if o.x < -1:
		_why("taller: sin lugar 5")
		return {}
	for x in w:
		for z in dp:
			cells.append(o + Vector2i(x, z))
	var all_cells: Array[Vector2i] = cells.duplicate()
	for c in corridor:
		all_cells.append(c)
		cset[c] = true
	# el pilar en una esquina de la arena lejos de la llegada; T (libre) y el otro vecino, que es muro
	var corners: Array[Vector2i] = [o, o + Vector2i(w - 1, 0), o + Vector2i(0, dp - 1), o + Vector2i(w - 1, dp - 1)]
	var open_corners: Array[Vector2i] = []   # la sala que sigue arranca desde la cima del pilar: tiene que tener a dónde (al menos dos vecinos de afuera de la arena, libres y dentro de la torre)
	for c in corners:
		var outs := 0
		for d in DIRS4:
			var n: Vector2i = c + d
			if not cset.has(n) and n != ctx.arrival and ctx.cellset.has(n) and _free(ctx.st, n, ctx.ey, ctx.ey + 1):
				outs += 1
		if outs >= 1:
			open_corners.append(c)
	if open_corners.is_empty():
		_why("taller: sin lugar 2")
		return {}
	open_corners.sort_custom(func(a, b): return (a - ctx.arrival).length_squared() > (b - ctx.arrival).length_squared())
	var pillar: Vector2i = open_corners[rng.randi_range(0, mini(1, open_corners.size() - 1))]
	var inside: Array[Vector2i] = []
	for d in DIRS4:
		if cells.has(pillar + d):
			inside.append(pillar + d)
	if inside.size() != 2:
		_why("taller: sin lugar 3")
		return {}
	var t_idx := rng.randi_range(0, 1)
	if (inside[t_idx] - ctx.arrival).length() < 2.0:   # (T no pegada a la llegada: si no, el jugador arranca contra la caja de escalón)
		t_idx = 1 - t_idx
	var tcell: Vector2i = inside[t_idx]
	var wcell: Vector2i = inside[1 - t_idx]
	if (tcell - ctx.arrival).length() < 2.0:
		_why("taller: sin lugar 4")
		return {}
	var n_boxes: int = 2 if ctx.twist == "una_caja" else (3 if ctx.twist == "dos_cajas" else 4)
	n_boxes = mini(n_boxes + (1 if ctx.d > 0.6 else 0), maxi(cells.size() / 3, 2))
	var n_walls := 2 + int(float(cells.size()) * (0.1 + 0.2 * ctx.d))
	var free: Array[Vector2i] = []
	for c in cells:
		if c != pillar and c != wcell and c != tcell and (c - ctx.arrival).length() >= 1.5 and _free(ctx.st, c, ctx.ey, ctx.ey + 2):   # (los muros miden 3: la tercera capa tiene que estar libre)
			free.append(c)
	if not _free(ctx.st, wcell, ctx.ey, ctx.ey + 2) or not _free(ctx.st, pillar, ctx.ey, ctx.ey + 2):
		_why("taller: sin lugar 6")
		return {}
	if free.size() < n_boxes + n_walls:
		n_walls = maxi(free.size() - n_boxes - 1, 1)
	# Se busca con el solucionador completo (todas las acciones: empujar, tirar, colgarse): lo que mide es lo que cuesta de verdad, no una estimación. Se parte de varias disposiciones al azar
	# (muros y cajas, con el jugador en la llegada) y se mejora la mejor moviendo una caja o un muro mientras el acertijo pida más bloques movidos.
	var best := {}
	var best_walls: Array = []
	var best_boxes: Array = []
	var target := 6 + int(ctx.d * 7.0)   # en agarres: lo que importa son los bloques movidos
	var min_grabs := 4 + int(ctx.d * 2.0)
	var min_moved := 2 + int(ctx.d * 2.0)   # y bloques distintos
	if OS.get_environment("TALLER_MIN") != "":
		min_grabs = int(OS.get_environment("TALLER_MIN"))
	var tries := 0
	for _try in TALLER_LAYOUTS:
		if int(ctx.get("work", 0)) > TALLER_WORK:
			break
		var pool := free.duplicate()
		var walls: Array = [wcell]
		for _i in n_walls:
			walls.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
		if not _taller_connected(ctx, cset, walls, pillar, tcell, all_cells.size()):
			continue
		var boxes: Array = []
		for _i in n_boxes:
			if pool.is_empty():
				break
			boxes.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
		var ev := _taller_eval(all_cells, ctx.arrival, pillar, walls, boxes, env, ctx)
		tries += 1
		if ev.ok and (best.is_empty() or ev.score > best.score):
			best = ev
			best_walls = walls
			best_boxes = boxes
	if best.is_empty() or best.grabs < min_grabs - 2:   # (con lo que salió al azar no hay por dónde: no se gasta más en esta arena)
		_why("taller: sin lugar 8")
		return {}
	for _it in TALLER_CLIMB:
		if best.is_empty() or best.grabs >= target or int(ctx.get("work", 0)) > TALLER_WORK:
			break
		var nw: Array = best_walls.duplicate()
		var nb: Array = best_boxes.duplicate()
		var taken := {}
		for c in nw:
			taken[c] = true
		for c in nb:
			taken[c] = true
		var spots: Array[Vector2i] = []
		for c in free:
			if not taken.has(c):
				spots.append(c)
		if spots.is_empty():
			break
		var spot: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
		if rng.randf() < 0.4 and nw.size() > 1:
			nw[rng.randi_range(1, nw.size() - 1)] = spot   # (el muro 0 es el del pilar: no se toca)
		elif not nb.is_empty():
			nb[rng.randi_range(0, nb.size() - 1)] = spot
		else:
			continue
		if not _taller_connected(ctx, cset, nw, pillar, tcell, all_cells.size()):
			continue
		var ev2 := _taller_eval(all_cells, ctx.arrival, pillar, nw, nb, env, ctx)
		if ev2.ok and ev2.score >= best.score:
			best = ev2
			best_walls = nw
			best_boxes = nb
	if best.is_empty() or best.grabs < min_grabs or best.moved < min_moved:
		if OS.get_environment("IDEA_LOG") != "":
			print("     taller fácil: %s agarres, %s bloques (pide %d y %d)" % [str(best.get("grabs", -1)), str(best.get("moved", -1)), min_grabs, min_moved])
		_why("taller: sin lugar 5")
		return {}
	best["boxes"] = best_boxes
	var cols := {pillar: {"h": 2, "kind": K.HEAVY}}
	for c in best_walls:
		cols[c] = {"h": 3, "kind": K.HEAVY}
	for c in best.boxes:
		cols[c] = {"h": 1, "kind": K.NORMAL}
	var grabs: int = best.grabs
	if OS.get_environment("IDEA_LOG") != "":
		print("     taller: %d movimientos (%d agarres), %d estados, %d cajas, %d muros, %dx%d" % [best.dist, grabs, best.states, best.boxes.size(), best_walls.size(), w, dp])
	if OS.get_environment("IDEA_LOG") != "":
		print("     arena %s llegada %s pilar %s muros %s cajas %s" % [str(cells), str(ctx.arrival), str(pillar), str(best_walls), str(best.boxes)])
	if OS.get_environment("SHOW_TALLER") != "":
		print("   acertijo de cajas: %d movimientos, %d agarres  (A = llegada, G = pilar, T = única casilla desde donde se sube, # = muro de 3, n = caja)" % [best.dist, grabs])
		for zz in 8:
			var row := ""
			for xx in 8:
				var c := Vector2i(xx, zz)
				row += "A " if c == ctx.arrival else ("G " if c == pillar else ("# " if best_walls.has(c) else ("n " if best.boxes.has(c) else ("T " if c == tcell else (". " if all_cells.has(c) else "  ")))))
			print("      " + row)
	var floors := {}   # (el piso de toda la arena y el pasillo, de bloques comunes)
	for c in all_cells:
		floors[c] = K.NORMAL
	return {"cols": cols, "goal": pillar, "floor_kinds": floors, "margin": 0, "taller": true, "solution": best.path, "mini": [all_cells, ctx.arrival, pillar, best_walls, best.boxes, env]}


## La arena vertical sola, en una torre chica: piso fijo, el pilar de `ph` (el tope es fijo), las columnas de `cols` ({celda: {h, kind}}) y el jugador en la llegada. La capa 1 es la de la sala.
static func _vert_mini(cells: Array[Vector2i], arrival: Vector2i, pillar: Vector2i, ph: int, cols: Dictionary, env: Array = []):
	var t := TowerLogic.new()
	t.size = Vector2i(SIZE, SIZE)
	t.collapse_every = Gen.BIG
	t.moves_to_collapse = Gen.BIG
	for c in cells:
		t.add_block(Vector3i(c.x, 0, c.y), true)
	t.add_block(Vector3i(arrival.x, 0, arrival.y), true)
	for e in env:
		if not t.blocks.has(e):
			t.add_block(e, true)
	for y in range(1, ph):
		t.add_block(Vector3i(pillar.x, y, pillar.y), false, K.HEAVY)
	t.add_block(Vector3i(pillar.x, ph, pillar.y), true, K.NORMAL)
	var goal_id: int = t.blocks[Vector3i(pillar.x, ph, pillar.y)]
	for c in cols:
		var col: Dictionary = cols[c]
		for y in range(1, int(col.h) + 1):
			t.add_block(Vector3i(c.x, y, c.y), false, int(col.kind))
	t.player = Vector3i(arrival.x, 1, arrival.y)
	t.goal_y = ph + 1
	t.goal_ids = {goal_id: true}
	return t


## Cuántos bloques DISTINTOS hay que mover siguiendo `path` desde el estado `start` (un bloque empujado cuatro veces cuenta uno): lo que pide el acertijo de verdad.
static func _moved_blocks(start, path: Array) -> int:
	var lg = start.clone()
	var moved := {}
	for a in path:
		var before: Dictionary = lg.positions.duplicate() if a.mode == TowerLogic.Mode.GRAB else {}
		lg.try_action(a.dir, a.mode)
		if a.mode == TowerLogic.Mode.GRAB:
			for id in lg.positions:
				if before.get(id, lg.positions[id]) != lg.positions[id]:
					moved[id] = true
	return moved.size()


static func _vert_eval(cells: Array[Vector2i], arrival: Vector2i, pillar: Vector2i, ph: int, cols: Dictionary, env: Array, work_ctx: Dictionary) -> Dictionary:
	var t = _vert_mini(cells, arrival, pillar, ph, cols, env)
	var res: Dictionary = Solver.solve(t, ph + 1, {"max_states": VERT_CAP, "goal_ids": t.goal_ids})
	work_ctx["work"] = int(work_ctx.get("work", 0)) + int(res.states)
	if res.status != "solved":
		return {"ok": false}
	# ¿se resuelve sin empujar ni tirar de ningún bloque (sólo caminando, trepando y colgándose)? Entonces es un atajo: el jugador lo encuentra aunque el camino más corto mueva bloques.
	var plain: Dictionary = Solver.solve(_vert_mini(cells, arrival, pillar, ph, cols, env), ph + 1, {"max_states": VERT_CAP, "goal_ids": t.goal_ids, "no_grab": true})
	work_ctx["work"] = int(work_ctx.get("work", 0)) + int(plain.states)
	if plain.status != "limit" and plain.status != "unsolvable" and plain.status == "solved":
		return {"ok": false, "atajo": true}
	var grabs := 0
	for a in res.path:
		if a.mode == TowerLogic.Mode.GRAB:
			grabs += 1
	var moved := _moved_blocks(_vert_mini(cells, arrival, pillar, ph, cols, env), res.path)
	return {"ok": true, "dist": res.moves, "grabs": grabs, "moved": moved, "path": res.path, "states": res.states, "score": 10 * moved + 4 * grabs + res.moves}


## Los estados más lejanos de la sala resuelta `t0` (el jugador en la cima de la salida): se exploran TODOS los que se alcanzan con movimientos que se pueden deshacer (hasta `cap`: las distancias de lo descubierto son exactas) y de los que dejan al jugador en la llegada, con por dónde moverse, se devuelven los `keep` de mayor puntaje (pasos + 6 por agarre).
## Todos son resolubles (se llega a la sala resuelta deshaciendo): lo que falta comprobar, con el solucionador completo, es cuánto cuestan de verdad (hay atajos que no se deshacen).
static func _far_states(t0, arrival: Vector2i, allowed: Dictionary, goal_stand_y: int, movable_ids: Array, rng: RandomNumberGenerator, cap: int, keep: int, work_ctx: Dictionary) -> Array:
	var goal_id: int = t0.goal_ids.keys()[0]
	var count0: int = t0.blocks.size()
	var actions: Array = []
	for d in TowerLogic.DIRS:
		for mode in [TowerLogic.Mode.MOVE, TowerLogic.Mode.GRAB]:
			actions.append([d, mode])
	var key0: Vector3i = Solver.state_key(t0)
	var nodes := {key0: t0}
	var order: Array = [key0]
	var inn := {}
	var goals: Array = []
	var qi := 0
	while qi < order.size() and order.size() < cap:
		var k: Vector3i = order[qi]
		qi += 1
		var st = nodes[k]
		if k == key0:
			goals.append(k)   # (la sala resuelta: desde acá se sube caminando)
		for o in actions:
			var n = st.clone()
			if not n.try_action(o[0], o[1]).ok or n.lost or n.hang_dir != Vector3i.ZERO or n.blocks.size() != count0:
				continue
			var misplaced := false
			for bid in movable_ids:
				var bp: Vector3i = n.positions[bid]
				if bp.y < 1 or not allowed.has(Vector2i(bp.x, bp.z)):
					misplaced = true
					break
			if misplaced:
				continue
			var nk: Vector3i = Solver.state_key(n)
			if nk == k:
				continue
			var od: Vector3i = o[0]
			var tries: Array = []
			if o[1] == TowerLogic.Mode.MOVE:
				tries = [[[-od, TowerLogic.Mode.MOVE]]]
			else:
				tries = [[[od, TowerLogic.Mode.MOVE], [-od, TowerLogic.Mode.GRAB]], [[-od, TowerLogic.Mode.GRAB], [-od, TowerLogic.Mode.MOVE]]]
			var inv = null
			for seq in tries:
				var b = n.clone()
				var okseq := true
				for a1 in seq:
					if not b.try_action(a1[0], a1[1]).ok or b.lost:
						okseq = false
						break
				if okseq and b.player == st.player and Solver.state_key(b) == k:
					inv = seq
					break
			if inv == null:
				continue
			if not inn.has(nk):
				inn[nk] = []
			inn[nk].append([k, 1, [o]])
			if not inn.has(k):
				inn[k] = []
			inn[k].append([nk, inv.size(), inv])
			if not nodes.has(nk):
				nodes[nk] = n
				order.append(nk)
	work_ctx["work"] = int(work_ctx.get("work", 0)) + order.size()
	if goals.is_empty():
		return []
	var dist := {}
	var nxt := {}
	var gr := {}
	var levels: Array = [[]]
	for g in goals:
		dist[g] = 0
		gr[g] = 0
		levels[0].append(g)
	var lv := 0
	while lv < levels.size():
		for k in levels[lv]:
			if int(dist[k]) != lv:
				continue
			for e in inn.get(k, []):
				var x: Vector3i = e[0]
				var nd: int = lv + int(e[1])
				var eg := 0
				for a in e[2]:
					if a[1] == TowerLogic.Mode.GRAB:
						eg += 1
				if not dist.has(x) or nd < int(dist[x]) or (nd == int(dist[x]) and int(gr[k]) + eg > int(gr[x])):
					dist[x] = nd
					gr[x] = int(gr[k]) + eg
					nxt[x] = [k, e[2]]
					while levels.size() <= nd:
						levels.append([])
					levels[nd].append(x)
		lv += 1
	var arrival_pos := Vector3i(arrival.x, 1, arrival.y)
	var scored: Array = []
	for k in order:
		var st = nodes[k]
		if st.player != arrival_pos or not dist.has(k) or int(dist[k]) == 0:
			continue
		if not _open_start(st, 4, 1):
			continue
		scored.append([int(dist[k]) + 6 * int(gr[k]), k])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var out: Array = []
	for i in mini(keep, scored.size()):
		var k: Vector3i = scored[i][1]
		var path: Array = []
		var cur: Vector3i = k
		var guard := 0
		while int(dist[cur]) > 0 and guard < 600:
			var step: Array = nxt[cur]
			for a in step[1]:
				path.append({"dir": a[0], "mode": a[1]})
			cur = step[0]
			guard += 1
		out.append({"state": nodes[k], "path": path, "dist": int(dist[k]), "grabs": int(gr[k])})
	return out


## La sala chica resuelta: una escalera de columnas pegada al pilar (alturas ph-1, ph-2... por celdas contiguas), unos bloques de sobra repartidos y a veces columnas pesadas. {} si no entra.
static func _vert_s0(free: Array[Vector2i], pillar: Vector2i, ph: int, rng: RandomNumberGenerator, n_heavy: int) -> Dictionary:
	var cols := {}
	var cur := pillar
	var chain: Array[Vector2i] = []
	for k in range(ph - 1, 0, -1):
		var opts: Array[Vector2i] = []
		for d in DIRS4:
			var nb: Vector2i = cur + d
			if free.has(nb) and not cols.has(nb):
				opts.append(nb)
		if opts.is_empty():
			return {}
		cur = opts[rng.randi_range(0, opts.size() - 1)]
		cols[cur] = {"h": k, "kind": K.NORMAL}
		chain.append(cur)
	var extra := 2 + rng.randi_range(0, 3)
	for _e in extra:
		var c: Vector2i = free[rng.randi_range(0, free.size() - 1)]
		if cols.has(c):
			if int(cols[c].h) < ph - 1 and cols[c].kind == K.NORMAL:
				cols[c].h = int(cols[c].h) + 1
		else:
			cols[c] = {"h": 1, "kind": K.NORMAL}
	for _e in n_heavy:
		var c2: Vector2i = free[rng.randi_range(0, free.size() - 1)]
		if not cols.has(c2):
			cols[c2] = {"h": rng.randi_range(1, ph - 2), "kind": K.HEAVY}
	return cols


## Dónde cabe una sala vertical: una arena de un tamaño de `shapes` ({w, dp}) con el camino que la une a la llegada. {} si no hay lugar. {w, dp, all_cells (arena y camino), cset}.
static func _vert_site(ctx: Dictionary, shapes: Array) -> Dictionary:
	var rng: RandomNumberGenerator = ctx.rng
	shapes = shapes.duplicate()
	var w := 0
	var dp := 0
	var origins: Array[Vector2i] = []
	while not shapes.is_empty():
		var sh: Array = shapes.pop_at(rng.randi_range(0, shapes.size() - 1))
		origins = _rect_origins(ctx, sh[0], sh[1])
		if not origins.is_empty():
			w = sh[0]
			dp = sh[1]
			break
	if origins.is_empty():
		_why("vertical: sin lugar 1")
		return {}
	var o := Vector2i(-9, -9)
	var cset := {}
	var corridor: Array[Vector2i] = []
	for _try in mini(6, origins.size()):
		var cand_o: Vector2i = origins.pop_at(rng.randi_range(0, origins.size() - 1))
		var cs := {}
		for x in w:
			for z in dp:
				cs[cand_o + Vector2i(x, z)] = true
		var path: Array[Vector2i] = _taller_corridor(ctx, cs)
		if path.size() > 4 or (path.size() == 1 and path[0] == Vector2i(-99, -99)):
			continue
		o = cand_o
		cset = cs
		corridor = path
		break
	if o.x < -1:
		_why("vertical: sin lugar 2")
		return {}
	var all_cells: Array[Vector2i] = []
	for x in w:
		for z in dp:
			all_cells.append(o + Vector2i(x, z))
	for c in corridor:
		all_cells.append(c)
		cset[c] = true
	return {"w": w, "dp": dp, "o": o, "all_cells": all_cells, "cset": cset}


## Los bloques de un estado de una arena vertical (coordenadas de la arena sola, la capa 1 es la de la sala): la salida primero, después las columnas y los pilares. Lo fijo (piso, entorno) no va.
static func _module_blocks(t) -> Array:
	var out: Array = []
	var goal: Vector3i = t.positions[t.goal_ids.keys()[0]]
	out.append({"p": goal, "kind": K.NORMAL, "fixed": true})
	for id in t.positions:
		var pos: Vector3i = t.positions[id]
		if pos.y < 1 or t.fixed.has(pos):
			continue
		out.append({"p": pos, "kind": int(t.kind_of.get(id, K.NORMAL)), "fixed": false})
	return out


## Una sala vertical resuelta por separado: la arena `cells` (con el piso), la `arrival` de donde se sale, el `pillar` de `ph` pisos y las columnas. Se parte de la sala resuelta, se exploran los estados que se alcanzan
## con movimientos que se pueden deshacer y se comprueba con el solucionador completo cuánto cuestan de verdad (sin atajos que no muevan bloques); si no sale nada bueno, se prueban disposiciones al azar y se mejora la mejor.
## {path, dist, grabs, moved, blocks (ver `_module_blocks`)} o {} si no salió una que pida lo suficiente.
static func _vert_module(cells: Array[Vector2i], arrival: Vector2i, pillar: Vector2i, free: Array[Vector2i], ph: int, env: Array, ctx: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = ctx.rng
	var maxh := ph - 1
	var n_heavy := 0 if ctx.d < 0.4 else (1 if ctx.d < 0.75 else 2)
	var best := {}
	var best_t = null
	var target := 6 + int(ctx.d * 6.0)
	var min_grabs := 4 + int(ctx.d * 2.0)
	var min_moved := 2 + int(ctx.d * 2.0)
	if ctx.has("mod_less"):   # (las salas medianas piden menos a cada módulo: lo que importa es el total)
		min_grabs -= int(ctx.mod_less)
		min_moved -= int(ctx.mod_less)
	if OS.get_environment("TALLER_MIN") != "":
		min_grabs = int(OS.get_environment("TALLER_MIN"))
	var allowed := {arrival: true}
	for c in cells:
		allowed[c] = true
	for _try in TALLER_S0:
		if int(ctx.get("work", 0)) > TALLER_WORK:
			break
		var s0 := _vert_s0(free, pillar, ph, rng, n_heavy)
		if s0.is_empty():
			continue
		var t0 = _vert_mini(cells, arrival, pillar, ph, s0, env)
		var walk: Dictionary = Solver.solve(t0.clone(), ph + 1, {"max_states": 3000, "goal_ids": t0.goal_ids, "no_grab": true})
		ctx["work"] = int(ctx.get("work", 0)) + int(walk.states)
		if walk.status != "solved":
			continue   # (la escalera no se alcanza caminando desde la llegada)
		var movable: Array = []
		for c in s0:
			if s0[c].kind == K.NORMAL:
				for y in range(1, int(s0[c].h) + 1):
					movable.append(t0.blocks[Vector3i(c.x, y, c.y)])
		var cands: Array = _far_states(t0, arrival, allowed, ph + 1, movable, rng, TALLER_STATES, 30, ctx)
		for cd in cands:
			var st = cd.state
			var tt = st.clone()
			tt.hang_dir = Vector3i.ZERO
			var res: Dictionary = Solver.solve(tt, ph + 1, {"max_states": VERT_CAP, "goal_ids": tt.goal_ids})
			ctx["work"] = int(ctx.get("work", 0)) + int(res.states)
			if res.status != "solved":
				continue
			var plain: Dictionary = Solver.solve(st.clone(), ph + 1, {"max_states": VERT_CAP, "goal_ids": tt.goal_ids, "no_grab": true})
			ctx["work"] = int(ctx.get("work", 0)) + int(plain.states)
			if plain.status == "solved":
				continue   # (atajo sin tocar bloques)
			var grabs := 0
			for a in res.path:
				if a.mode == TowerLogic.Mode.GRAB:
					grabs += 1
			var moved := _moved_blocks(st, res.path)
			var score := 10 * moved + 4 * grabs + int(res.moves)
			if best.is_empty() or score > best.score:
				best = {"dist": res.moves, "grabs": grabs, "moved": moved, "path": res.path, "score": score}
				best_t = st
		if not best.is_empty() and best.grabs >= target:
			break
	if not best.is_empty() and best.grabs >= min_grabs and best.moved >= min_moved:
		best["blocks"] = _module_blocks(best_t)
		best["start"] = best_t
		return best
	# si no salió nada bueno, la búsqueda al azar de antes (más corta)
	best = {}
	var best_cols := {}
	for _try in 8:
		if int(ctx.get("work", 0)) > TALLER_WORK:
			break
		var cols := {}
		var heavies := 0
		for c in free:
			var hh := rng.randi_range(0, maxh)
			if hh == 0:
				continue
			var heavy := heavies < n_heavy and rng.randf() < 0.15
			if heavy:
				heavies += 1
			cols[c] = {"h": hh, "kind": K.HEAVY if heavy else K.NORMAL}
		var ev := _vert_eval(cells, arrival, pillar, ph, cols, env, ctx)
		if ev.ok and (best.is_empty() or ev.score > best.score):
			best = ev
			best_cols = cols
	if best.is_empty():
		_why("vertical: sin lugar 5")
		return {}
	for _it in TALLER_CLIMB:
		if best.grabs >= target or int(ctx.get("work", 0)) > TALLER_WORK:
			break
		var nc: Dictionary = best_cols.duplicate(true)
		var movers: Array = []
		for c in nc:
			if nc[c].kind == K.NORMAL and int(nc[c].h) > 0:
				movers.append(c)
		if movers.is_empty():
			break
		var a: Vector2i = movers[rng.randi_range(0, movers.size() - 1)]
		var b: Vector2i = free[rng.randi_range(0, free.size() - 1)]
		if a == b or (nc.has(b) and (nc[b].kind != K.NORMAL or int(nc[b].h) >= maxh)):
			continue
		nc[a].h = int(nc[a].h) - 1   # un bloque pasa de una columna a otra
		if int(nc[a].h) == 0:
			nc.erase(a)
		if nc.has(b):
			nc[b].h = int(nc[b].h) + 1
		else:
			nc[b] = {"h": 1, "kind": K.NORMAL}
		var ev2 := _vert_eval(cells, arrival, pillar, ph, nc, env, ctx)
		if ev2.ok and ev2.score >= best.score:
			best = ev2
			best_cols = nc
	if best.grabs < min_grabs or best.moved < min_moved:
		if OS.get_environment("IDEA_LOG") != "":
			print("     vertical fácil: %d agarres, %d bloques (pide %d y %d)" % [best.grabs, best.moved, min_grabs, min_moved])
		_why("vertical: sin lugar 6")
		return {}
	var start_t = _vert_mini(cells, arrival, pillar, ph, best_cols, env)
	best["blocks"] = _module_blocks(start_t)
	best["start"] = start_t
	return best


## ¿El camino de una sala vertical sigue valiendo si en la capa `y` de la arena hay bloques fijos en `cells` (el piso de la sala de arriba)?
static func _path_ok(start, path: Array, cells: Array[Vector2i], y: int) -> bool:
	var t = start.clone()
	for c in cells:
		var cell := Vector3i(c.x, y, c.y)
		if not t.blocks.has(cell):
			t.add_block(cell, true)
	for a in path:
		if not t.try_action(a.dir, a.mode).ok or t.lost:
			return false
	return true


## Las celdas con bloques de la arena sola, en coordenadas de la torre: la capa 1 de la arena es `ey` (la sala). Primero la salida. `lift` sube todo (para una sala que arranca encima de otra).
static func _module_explicit(blocks: Array, ey: int) -> Array:
	var out: Array = []
	for b in blocks:
		var p: Vector3i = b.p
		out.append({"c": Vector3i(p.x, p.y - 1 + ey, p.z), "kind": int(b.kind), "fixed": bool(b.fixed), "timer": 0})
	return out


## El entorno de la torre que toca una arena vertical, en coordenadas de la arena sola (la capa 1 es `ey`).
static func _module_env(ctx: Dictionary, ey: int, ph: int) -> Array:
	var env: Array = []
	for c in ctx.st.sim.blocks:
		if c.y >= ey - 1 and c.y <= ey + ph:
			env.append(Vector3i(c.x, c.y - ey + 1, c.z))
	return env


## Sala chica con altura (4 o 5 pisos, arena de 3x3 a 3x5): cada celda es una columna de bloques de altura distinta (más algún pilar pesado) y la salida es una columna fija alta en una esquina. Para subir hay que
## armar una escalera redistribuyendo bloques (uno de arriba que se empuja sobre una columna más baja la sube), o tirarlos desde arriba. Ver `_vert_module`.
static func _c_chica(ctx: Dictionary) -> Dictionary:
	var ph: int = ctx.h
	if ph != (4 if ctx.twist == "baja" else 5) or int(ctx.get("work", 0)) > TALLER_WORK:
		return {}
	var rng: RandomNumberGenerator = ctx.rng
	var site := _vert_site(ctx, [[3, 3], [3, 4], [4, 3], [3, 5], [5, 3], [3, 3], [3, 4], [4, 3]])
	if site.is_empty():
		return {}
	var w: int = site.w
	var dp: int = site.dp
	var o: Vector2i = site.o
	var all_cells: Array[Vector2i] = site.all_cells
	var cset: Dictionary = site.cset
	var corners: Array[Vector2i] = [o, o + Vector2i(w - 1, 0), o + Vector2i(0, dp - 1), o + Vector2i(w - 1, dp - 1)]
	var open_corners: Array[Vector2i] = []   # (la sala que sigue arranca desde la cima de la salida: tiene que tener a dónde)
	for c in corners:
		var outs := 0
		for d in DIRS4:
			var n: Vector2i = c + d
			if not cset.has(n) and n != ctx.arrival and ctx.cellset.has(n) and _free(ctx.st, n, ctx.ey, ctx.ey + 1):
				outs += 1
		if outs >= 1 and _free(ctx.st, c, ctx.ey, ctx.ey + ph):
			open_corners.append(c)
	if open_corners.is_empty():
		_why("chica: sin lugar 3")
		return {}
	var pillar: Vector2i = open_corners[rng.randi_range(0, open_corners.size() - 1)]
	var free: Array[Vector2i] = []   # celdas donde puede haber columnas (libres en toda la altura y no pegadas a la llegada)
	for c in all_cells:
		if c != pillar and (c - ctx.arrival).length() >= 1.5 and _free(ctx.st, c, ctx.ey, ctx.ey + ph - 1):
			free.append(c)
	if free.size() < 4:
		_why("chica: sin lugar 4")
		return {}
	var mod := _vert_module(all_cells, ctx.arrival, pillar, free, ph, _module_env(ctx, ctx.ey, ph), ctx)
	if mod.is_empty():
		return {}
	if OS.get_environment("IDEA_LOG") != "":
		print("     chica %dx%d de %d pisos: %d movimientos, %d agarres, %d bloques distintos" % [w, dp, ph, mod.dist, mod.grabs, mod.moved])
	var floors := {}
	for c in all_cells:
		floors[c] = K.NORMAL
	return {"cols": {pillar: {"h": ph, "kind": K.HEAVY}}, "goal": pillar, "floor_kinds": floors, "margin": 0, "taller": true, "solution": mod.path, "explicit": _module_explicit(mod.blocks, ctx.ey)}


## Sala mediana (8 a 10 pisos): dos salas verticales una encima de la otra, cada una resuelta y comprobada por separado. La segunda arranca en la cima de la salida de la primera (su piso, fijo, está a esa altura)
## y se extiende a un costado. La solución es la de la primera seguida de la de la segunda.
static func _c_mediana(ctx: Dictionary) -> Dictionary:
	var hh: int = ctx.h
	if hh < 8 or hh > 10 or int(ctx.get("work", 0)) > TALLER_WORK:
		return {}
	var rng: RandomNumberGenerator = ctx.rng
	var ey: int = ctx.ey
	var pa := 4
	if hh == 10 or (hh == 9 and rng.randf() < 0.5):
		pa = 5
	var pb := hh - pa
	var site := _vert_site(ctx, [[3, 3], [3, 4], [4, 3], [3, 3], [3, 4], [4, 3]])
	if site.is_empty():
		return {}
	var w: int = site.w
	var dp: int = site.dp
	var o: Vector2i = site.o
	var all_a: Array[Vector2i] = site.all_cells
	var cset: Dictionary = site.cset
	var corners: Array[Vector2i] = [o, o + Vector2i(w - 1, 0), o + Vector2i(0, dp - 1), o + Vector2i(w - 1, dp - 1)]
	var pillars: Array[Vector2i] = []
	for c in corners:
		if _free(ctx.st, c, ey, ey + hh):
			pillars.append(c)
	for c in all_a:
		if not _free(ctx.st, c, ey, ey + hh):
			_why("mediana: sin lugar 1")
			return {}
	if pillars.is_empty():
		_why("mediana: sin lugar 2")
		return {}
	var pill_a: Vector2i = pillars[rng.randi_range(0, pillars.size() - 1)]
	# el sitio de la segunda: pegado a la columna de salida de la primera 
	var near_a := {ctx.arrival: true}
	for c in all_a:
		near_a[c] = true
	var shapes_b: Array = [[3, 3], [3, 4], [4, 3], [3, 5], [5, 3]]
	var spots: Array = []
	for sh in shapes_b:
		for ox in range(0, SIZE - sh[0] + 1):
			for oz in range(0, SIZE - sh[1] + 1):
				var cells_b: Array[Vector2i] = []
				var ok := true
				var touch := false
				for x in sh[0]:
					for z in sh[1]:
						var c := Vector2i(ox + x, oz + z)
						if near_a.has(c) or not ctx.cellset.has(c) or not _addable(ctx.st, c, ey) or not _free(ctx.st, c, ey, ey + hh):
							ok = false
						cells_b.append(c)
				if not ok:
					continue
				for c in cells_b:
					for d in DIRS4:
						var n: Vector2i = c + d
						if n == pill_a:
							touch = true
				if ok and touch:
					spots.append(cells_b)
	if spots.is_empty():
		_why("mediana: sin lugar 3")
		return {}
	var first_spot: Array[Vector2i] = spots.pop_at(rng.randi_range(0, spots.size() - 1))
	var env_a := _module_env(ctx, ey, pa)
	for c in first_spot:   # (el piso fijo de la segunda sala está a la altura de la cima de la primera: la primera tiene que saberlo)
		env_a.append(Vector3i(c.x, pa, c.y))
	# primera sala
	var free_a: Array[Vector2i] = []
	for c in all_a:
		if c != pill_a and (c - ctx.arrival).length() >= 1.5:
			free_a.append(c)
	if free_a.size() < 4:
		_why("mediana: sin lugar 5")
		return {}
	ctx["mod_less"] = 1
	var mod_a := _vert_module(all_a, ctx.arrival, pill_a, free_a, pa, env_a, ctx)
	if mod_a.is_empty():
		ctx.erase("mod_less")
		return {}
	# segunda sala: su piso es la capa de la cima de la primera; si el primer lugar no da, se prueba otro
	var ey_b := ey + pa
	var mod_b := {}
	var cells_b: Array[Vector2i] = []
	var pill_b := Vector2i(-9, -9)
	var all_cells := {}
	for _tb in 2:
		if _tb == 0:
			cells_b = first_spot
		else:
			if spots.is_empty():
				break
			cells_b = spots.pop_at(rng.randi_range(0, spots.size() - 1))
			if not _path_ok(mod_a.start, mod_a.path, cells_b, pa):
				continue
		all_cells = {}
		for c in all_a:
			all_cells[c] = true
		for c in cells_b:
			all_cells[c] = true
		var opts: Array[Vector2i] = []   # la salida de la segunda: una esquina con a dónde ir
		for c in cells_b:
			var cn := 0
			for d in DIRS4:
				if cells_b.has(c + d):
					cn += 1
			if cn > 2 or (c - pill_a).length() < 1.5:
				continue   # (esquinas de la arena, lejos de la entrada)
			var outs := 0
			for d in DIRS4:
				var n: Vector2i = c + d
				if not all_cells.has(n) and ctx.cellset.has(n) and _free(ctx.st, n, ey, ey + 1):
					outs += 1
			if outs >= 1:
				opts.append(c)
		if opts.is_empty():
			continue
		pill_b = opts[rng.randi_range(0, opts.size() - 1)]
		var free_b: Array[Vector2i] = []
		for c in cells_b:
			if c != pill_b and (c - pill_a).length() >= 1.5:
				free_b.append(c)
		if free_b.size() < 4:
			continue
		ctx["work"] = 0   # (cada sala tiene su propio presupuesto de trabajo)
		var env_b := _module_env(ctx, ey_b, pb)
		for c in all_a:   # (debajo de la primera hay columnas que se mueven: la segunda no puede contar con que ahí no haya nada, así que se verifica con algo siempre abajo)
			env_b.append(Vector3i(c.x, -1, c.y))
		mod_b = _vert_module(cells_b, pill_a, pill_b, free_b, pb, env_b, ctx)
		if not mod_b.is_empty():
			break
	ctx.erase("mod_less")
	if mod_b.is_empty():
		_why("mediana: sin lugar 6")
		return {}
	if int(mod_a.grabs) + int(mod_b.grabs) < 7 + int(ctx.d * 3.0):
		_why("mediana: fácil")
		return {}
	if OS.get_environment("IDEA_LOG") != "":
		print("     mediana de %d pisos (%d + %d): %d + %d agarres, %d + %d bloques distintos" % [hh, pa, pb, mod_a.grabs, mod_b.grabs, mod_a.moved, mod_b.moved])
	var blocks_b := _module_explicit(mod_b.blocks, ey_b)   # (la salida de la segunda va primero: es la de la sala)
	var explicit: Array = blocks_b
	for c in cells_b:   # el piso de la segunda: fijo, a la altura de la cima de la primera
		explicit.append({"c": Vector3i(c.x, ey_b - 1, c.y), "kind": K.NORMAL, "fixed": true, "timer": 0})
	for b in _module_explicit(mod_a.blocks, ey):
		explicit.append(b)
	var floors := {}
	for c in all_cells:
		floors[c] = K.NORMAL
	var path: Array = mod_a.path.duplicate()
	path.append_array(mod_b.path)
	return {"cols": {pill_b: {"h": hh, "kind": K.HEAVY}}, "goal": pill_b, "floor_kinds": floors, "margin": 0, "taller": true, "solution": path, "explicit": explicit}


## Reja: un muro denso de cubos comunes (como las paredes de Catherine) alrededor de la escalera de salida. Se arma la sala ya resuelta y se desordena con movimientos reales
## del juego (empujar y tirar) que se pueden deshacer; la solución es el desorden al revés, así que hay que mover muchos bloques. Ver `_scramble`.
static func _c_reja(ctx: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = ctx.rng
	var chain := _chain(ctx, ctx.h)
	if chain.is_empty():
		return {}
	var cols := {}
	_add_chain(cols, chain)
	var p := 0.85 if ctx.twist == "baja" else 0.97
	for c in _near(ctx, chain[chain.size() / 2], 4):
		if cols.has(c) or c == ctx.arrival or not _free(ctx.st, c, ctx.ey, ctx.ey + 2):
			continue
		if rng.randf() < p:
			var r := rng.randf()
			cols[c] = {"h": 1 if r < 0.3 else (2 if r < 0.7 else 3), "kind": K.NORMAL}
	var extra: Array[Vector2i] = []   # los que no son parte de la escalera
	for c in cols:
		if not chain.has(c):
			extra.append(c)
	if ctx.twist == "pesados" and ctx.d >= 0.3:   # pesados: no se mueven; arman el muro y obligan a rodearlos (los bloques de abajo no se pueden usar)
		for _i in mini(extra.size() / 4 + 1, 5):
			var c: Vector2i = extra[rng.randi_range(0, extra.size() - 1)]
			cols[c] = {"h": rng.randi_range(2, 3), "kind": K.HEAVY}
	elif ctx.twist == "pinchos" and ctx.d >= 0.4:   # pinchos: se pueden mover, pero pisarlos o caer encima termina la partida
		for _i in mini(extra.size() / 5 + 1, 3):
			var c: Vector2i = extra[rng.randi_range(0, extra.size() - 1)]
			cols[c] = {"h": rng.randi_range(1, 2), "kind": K.SPIKES}
	var free_next := 0   # la llegada tiene que tener por dónde moverse
	for d in DIRS4:
		var n: Vector2i = ctx.arrival + d
		if ctx.cellset.has(n) and not cols.has(n):
			free_next += 1
	if free_next == 0 or cols.size() < 8:
		return {}
	return {"cols": cols, "goal": chain[chain.size() - 1], "rect": true, "scramble": true}


## ¿Desde donde está el jugador se puede caminar a por lo menos `need` posiciones distintas (sin mover bloques)? Un comienzo encerrado no sirve: el jugador tiene que poder moverse desde el primer paso.
static func _open_start(cur, need: int, min_free := 2) -> bool:
	var free := 0   # al menos dos lados libres a la altura del jugador (con piso): si no, arranca en un pozo
	for d in TowerLogic.DIRS:
		var n: Vector3i = cur.player + d
		if not cur.blocks.has(n) and cur.blocks.has(n + Vector3i.DOWN):
			free += 1
	if free < min_free:
		return false
	var queue: Array = [cur]
	var seen := {cur.player: true}
	var qi := 0
	while qi < queue.size() and seen.size() < need:
		var node = queue[qi]
		qi += 1
		for d in TowerLogic.DIRS:
			var n = node.clone()
			if not n.try_action(d, TowerLogic.Mode.MOVE).ok or n.lost or n.hang_dir != Vector3i.ZERO or seen.has(n.player):
				continue
			seen[n.player] = true
			queue.append(n)
	return seen.size() >= need


## El camino más corto a pie (sin mover bloques) desde el estado `cur` hasta que el jugador esté en `target`; [] si no hay.
static func _walk_home(cur, target: Vector3i) -> Array:
	var queue: Array = [[cur, []]]
	var seen := {cur.player: true}
	var qi := 0
	while qi < queue.size() and queue.size() < 700:
		var node: Array = queue[qi]
		qi += 1
		for d in TowerLogic.DIRS:
			var n = node[0].clone()
			if not n.try_action(d, TowerLogic.Mode.MOVE).ok or n.lost or n.hang_dir != Vector3i.ZERO or seen.has(n.player):
				continue
			seen[n.player] = true
			var acts: Array = node[1].duplicate()
			acts.append([d, TowerLogic.Mode.MOVE])
			if n.player == target:
				return acts
			queue.append([n, acts])
	return []


const REJA_FROM := 0.25   # desde esta dificultad salen las salas denso-desordenadas (las primeras etapas enseñan con salas simples)
const REJA_SCRAMBLE_MAX := 220   # (el desorden puede dar un camino larguísimo: lo que cuenta es el que quede al final)
const REJA_MAX_MOVES := 80   # una sala larga cansa: la torre entera tiene que andar por los 250 a 350 movimientos
const REJA_SOLVER_STATES := 30000
const REJA_MIN_MOVES := 12   # si el solucionador la resuelve en menos, es fácil por más que cueste encontrarla
const SCRAMBLE_STEPS := 160
const SCRAMBLE_MIN := 20


## Desordena la sala resuelta `win` (el jugador arriba, en la salida) con acciones reales que se pueden deshacer exactamente, hasta volver a la llegada habiendo movido muchos bloques.
## Devuelve {blocks (el estado desordenado, la salida primero), path (la solución: las acciones inversas en orden contrario), states} o {} si no se pudo.
static func _scramble(ctx: Dictionary, cand: Dictionary, win, built_blocks: Array) -> Dictionary:
	var rng: RandomNumberGenerator = ctx.rng
	var ey: int = ctx.ey
	var goal: Vector2i = cand.goal
	var arrival: Vector2i = ctx.arrival
	var want_grabs := 3 + int(ctx.d * 9.0) + rng.randi_range(0, 2)
	var want_disp := 8 + int(ctx.d * 14.0) + rng.randi_range(0, 3)   # cuánto se alejan los bloques de donde estaban (en celdas, sumado): es lo que mide qué tan largo es el camino más corto de vuelta
	var want_moved := 3 + int(ctx.d * 3.0)
	var gid: int = win.goal_ids.keys()[0]
	var cur = win.clone()
	cur.goal_ids = {}
	cur.goal_y = 99999
	cur.won = false
	cur.hang_dir = Vector3i.ZERO
	cur.player = Vector3i(goal.x, ey + ctx.h, goal.y)
	if not cur.blocks.has(cur.player + Vector3i.DOWN):
		_why("la salida no tiene el bloque de arriba")
		return {}
	cur._own_fixed()   # lo que quedó de las salas de abajo es el suelo: fijo (la ventana corta lo que lo sostenía, y si no se caería)
	for c in cur.blocks.keys():
		if c.y < ey:
			cur.fixed[c] = true
	cur._blocks_dirty = true
	var count0: int = cur.blocks.size()
	var min_y0 := 999
	for pos in cur.positions.values():
		min_y0 = mini(min_y0, pos.y)
	var key0: Vector3i = Solver.state_key(cur)
	var ids: Array[int] = []
	for b in built_blocks:
		var bid: int = cur.blocks.get(b.c, -1)
		if bid >= 0:
			ids.append(bid)
	var start_pos := {}
	for bid in ids:
		start_pos[bid] = cur.positions[bid]
	var cur_disp := 0
	var cur_moved := 0
	var hist: Array = []
	var seen_keys := {key0: 0}   # estado -> cuántos pasos llevaba al verlo: si se vuelve a un estado ya visto, se borra el rulo (la solución no da vueltas)
	var forced: Array = []
	var backs := 0
	var low := false
	var cooldown := 0   # pasos que se sigue desordenando porque se llegó a un comienzo encerrado
	var grabs := 0
	var all_actions: Array = []
	for d in TowerLogic.DIRS:
		for mode in [TowerLogic.Mode.MOVE, TowerLogic.Mode.GRAB]:
			all_actions.append([d, mode])
	var done := false
	forced = _walk_home(cur, Vector3i(arrival.x, ey, arrival.y))   # lo primero: bajar a pie desde la salida hasta la llegada (es el final de la solución: la subida)
	if forced.is_empty():
		_why("desde la salida no se baja a pie hasta la llegada")
		return {}
	for step in SCRAMBLE_STEPS:
		cooldown -= 1
		var homing := grabs >= want_grabs and cur_disp >= want_disp and cur_moved >= want_moved and step >= SCRAMBLE_MIN and cooldown <= 0 and hist.size() > 8
		if homing and forced.is_empty() and step % 4 == 0:   # ya se movieron suficientes bloques: se vuelve a la llegada caminando por el camino más corto (sin mover bloques)
			forced = _walk_home(cur, Vector3i(arrival.x, ey, arrival.y))
		var opts := all_actions.duplicate()
		for i in opts.size():
			var j := rng.randi_range(0, opts.size() - 1)
			var t = opts[i]
			opts[i] = opts[j]
			opts[j] = t
		if forced.is_empty() and rng.randf() < 0.8:   # (casi siempre se prueba primero empujar o tirar: lo que importa es mover bloques, no pasear)
			var grabby: Array = []
			var walky: Array = []
			for o in opts:
				if o[1] == TowerLogic.Mode.GRAB:
					grabby.append(o)
				else:
					walky.append(o)
			opts = grabby + walky
		if not forced.is_empty():
			opts = [forced[0]]
		var best_n = null
		var best_inv = null
		var cands: Array = []
		var kcur: Vector3i = Solver.state_key(cur)
		for o in opts:
			var n = cur.clone()
			var r: Dictionary = n.try_action(o[0], o[1])
			if hist.is_empty() and OS.get_environment("DEBUG_DESORDEN") != "":
				print("      acción %s %s -> ok=%s lost=%s hang=%s bloques %d/%d jugador %s msg=%s" % [str(o[0]), str(o[1]), str(r.ok), str(n.lost), str(n.hang_dir), n.blocks.size(), count0, str(n.player), str(r.get("msg", ""))])
			if r.ok and n.blocks.size() != count0 and hist.is_empty() and OS.get_environment("DEBUG_DESORDEN") != "":
				for c in cur.blocks:
					if not n.blocks.has(c) and not n.positions.values().has(c):
						print("      desapareció/movió: %s (tipo %s, fijo %s) player %s ey=%d" % [str(c), str(cur.kind_of.get(cur.blocks[c], 0)), str(cur.fixed.has(c)), str(cur.player), ey])
			if not r.ok or n.lost or n.hang_dir != Vector3i.ZERO or n.blocks.size() != count0:
				continue
			var fell := false
			if o[1] == TowerLogic.Mode.GRAB:   # (sólo mover bloques puede hacer caer alguno)
				for pos in n.positions.values():
					if pos.y < min_y0:
						fell = true
						break
			if fell:
				continue
			var inv = null   # cómo se deshace: caminar, con el paso contrario; empujar, caminando hacia adelante y tirando; tirar, empujando y caminando hacia atrás
			var od: Vector3i = o[0]
			var tries: Array = []
			if o[1] == TowerLogic.Mode.MOVE:
				tries = [[[-od, TowerLogic.Mode.MOVE]]]
			else:
				tries = [[[od, TowerLogic.Mode.MOVE], [-od, TowerLogic.Mode.GRAB]], [[-od, TowerLogic.Mode.GRAB], [-od, TowerLogic.Mode.MOVE]]]
			for seq in tries:
				var b = n.clone()
				var okseq := true
				for a1 in seq:
					if not b.try_action(a1[0], a1[1]).ok or b.lost:
						okseq = false
						break
				if okseq and b.player == cur.player and Solver.state_key(b) == kcur:
					inv = seq
					break
			if inv == null:
				if hist.is_empty() and OS.get_environment("DEBUG_DESORDEN") != "":
					print("      sin inversa: de %s a %s; llaves %s vs %s" % [str(cur.player), str(n.player), str(Solver.state_key(n)), str(kcur)])
					for a1 in all_actions:
						var bb = n.clone()
						var rr: Dictionary = bb.try_action(a1[0], a1[1])
						print("         prueba %s %s ok=%s -> %s llave %s" % [str(a1[0]), str(a1[1]), str(rr.ok), str(bb.player), str(Solver.state_key(bb))])
					return {}
				continue
			if forced.is_empty() and seen_keys.has(Solver.state_key(n)):
				continue   # (un estado ya visitado: es dar vueltas; se prefiere algo nuevo)
			if low and n.player.y > ey + 1:
				continue   # (una vez abajo no se vuelve a trepar al muro: si no, cuesta volver a la llegada)
			cands.append([n, [o, inv]])
			if not forced.is_empty():
				break
		if not cands.is_empty():   # entre lo posible: casi siempre lo que más aleja a los bloques de su lugar (así no se puede deshacer en pocos pasos); a veces cualquiera
			var pick = cands[rng.randi_range(0, cands.size() - 1)]
			if forced.is_empty() and not homing and rng.randf() < 0.85:
				var top := -1
				var tops: Array = []
				for cd in cands:
					var dd := 0
					for bid in ids:
						var q: Vector3i = cd[0].positions[bid] - start_pos[bid]
						dd += absi(q.x) + absi(q.y) + absi(q.z)
					if dd > top:
						top = dd
						tops = [cd]
					elif dd == top:
						tops.append(cd)
				pick = tops[rng.randi_range(0, tops.size() - 1)]
			best_n = pick[0]
			best_inv = pick[1]
		if best_n == null:
			if forced.is_empty():
				# sin salida: se deshacen unos pasos (con sus inversas, que son exactas) y se sigue por otro lado
				if backs >= 14 or hist.size() < 3:
					break
				backs += 1
				for _u in mini(4, hist.size()):
					var last: Array = hist.pop_back()
					for a in last[1]:
						cur.try_action(a[0], a[1])
				for k in seen_keys.keys():
					if seen_keys[k] > hist.size():
						seen_keys.erase(k)
				grabs = 0
				for hh in hist:
					if hh[0][1] == TowerLogic.Mode.GRAB:
						grabs += 1
				cooldown = 4
				continue
			forced.clear()   # (el camino a pie no se pudo deshacer: se sigue desordenando)
			continue
		if not forced.is_empty():
			forced.remove_at(0)
		cur = best_n
		if cur.player.y <= ey + 1:
			low = true
		cur_disp = 0
		cur_moved = 0
		for bid in ids:
			var q2: Vector3i = cur.positions[bid] - start_pos[bid]
			var dsum := absi(q2.x) + absi(q2.y) + absi(q2.z)
			cur_disp += dsum
			if dsum > 0:
				cur_moved += 1
		hist.append(best_inv)
		var kn: Vector3i = Solver.state_key(cur)
		if seen_keys.has(kn):
			var keep: int = seen_keys[kn]
			hist.resize(keep)
			for k in seen_keys.keys():
				if seen_keys[k] > keep:
					seen_keys.erase(k)
			forced.clear()
		else:
			seen_keys[kn] = hist.size()
		grabs = 0
		for hh in hist:
			if hh[0][1] == TowerLogic.Mode.GRAB:
				grabs += 1
		if homing and cur.player == Vector3i(arrival.x, ey, arrival.y):
			if _open_start(cur, 12):
				done = true
				break
			cooldown = 6   # (el comienzo quedó encerrado: no se puede empezar así, se sigue desordenando)
			forced.clear()
	if not done:
		if OS.get_environment("IDEA_LOG") != "":
			print("     desorden sin llegar: %d pasos, %d agarres, jugador %s, llegada %s, retrocesos %d, cooldown %d, ocupado %s" % [hist.size(), grabs, str(cur.player), str(arrival), backs, cooldown, str(forced.size())])
		return {}
	var path: Array = []
	for i in range(hist.size() - 1, -1, -1):
		for a in hist[i][1]:
			path.append({"dir": a[0], "mode": a[1]})
	var check = cur.clone()
	var ci := 0
	for a in path:
		if not check.try_action(a.dir, a.mode).ok:
			_why("la vuelta falla en la acción %d de %d (%s %d)" % [ci, path.size(), str(a.dir), a.mode])
			return {}
		ci += 1
	if Solver.state_key(check) != key0:
		if OS.get_environment("IDEA_LOG") != "":
			print("     la vuelta no reproduce la sala resuelta")
		return {}
	if path.size() > REJA_SCRAMBLE_MAX:
		_why("la solución es demasiado larga (%d)" % path.size())
		return {}
	var blocks: Array = []
	var gpos: Vector3i = cur.positions[gid]
	blocks.append({"c": gpos, "kind": K.NORMAL, "fixed": ctx.get("final", false), "timer": 0})
	var rest: Array = []
	for bid in ids:
		if bid == gid:
			continue
		var pos: Vector3i = cur.positions[bid]
		if pos.y < ey:
			_why("un bloque quedó debajo del piso de la sala")
			return {}
		rest.append({"c": pos, "kind": int(cur.kind_of.get(bid, K.NORMAL)), "fixed": false, "timer": 0})
	rest.sort_custom(func(a, b): return a.c.y * 4096 + a.c.z * 64 + a.c.x < b.c.y * 4096 + b.c.z * 64 + b.c.x)
	blocks.append_array(rest)
	return {"blocks": blocks, "path": path, "states": hist.size() * 40}


## Respiro: una escalera corta y fácil, con algún pesado de estorbo.
static func _c_respiro(ctx: Dictionary) -> Dictionary:
	var chain := _chain(ctx, ctx.h)
	if chain.is_empty():
		return {}
	var cols := {}
	_add_chain(cols, chain)
	_decoys(ctx, cols, K.HEAVY, ctx.rng.randi_range(0, 2), 2, _near(ctx, chain[0], 3))
	return {"cols": cols, "goal": chain[chain.size() - 1], "rect": true}


## Pared de pinchos: la escalera arranca encerrada por pinchos de 2 de alto (no se trepan ni se pisan): hay que abrir un hueco empujando o tirando de las columnas.
static func _c_pinchos(ctx: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = ctx.rng
	var chain := _chain(ctx, ctx.h)
	if chain.is_empty():
		return {}
	var cols := {}
	_add_chain(cols, chain)
	for d in DIRS4:
		var c: Vector2i = chain[0] + d
		if ctx.cellset.has(c) and not cols.has(c) and c != ctx.arrival and _free(ctx.st, c, ctx.ey, ctx.ey + 1):
			cols[c] = {"h": 2, "kind": K.SPIKES}
	var near := _near(ctx, chain[0], 3)
	_decoys(ctx, cols, K.HEAVY, rng.randi_range(0, 2), 2, near)
	if ctx.twist == "con_senuelos":
		_decoys(ctx, cols, K.NORMAL, rng.randi_range(1, 3), 2, near)
		_decoys(ctx, cols, K.SPIKES, rng.randi_range(1, 2), 2, near)
	return {"cols": cols, "goal": chain[chain.size() - 1], "rect": true}


## Cuanto más difícil, más capas de pared rodean la escalera: hay que abrir un hueco en cada una, de afuera hacia adentro (una capa más desde 0.25 y otra desde 0.6).
## `heavy`: la capa es de pesados con algún suelto; si no, todo común (se abre empujando).
static func _outer_wall(ctx: Dictionary, ring: Array[Vector2i], cols: Dictionary, loose: Array[Vector2i], heavy: bool) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var layers := (1 if ctx.d > 0.3 and (not heavy or ctx.twist != "un_suelto") else 0) + (1 if ctx.d > 0.6 and not heavy else 0)
	var inner := ring
	for _l in layers:
		var outer := _ring(ctx, inner, cols, 2)
		if outer.size() < 3:
			return
		var pick := outer.duplicate()
		var mine: Array[Vector2i] = []
		var want := 1 if heavy else 0
		while mine.size() < want and not pick.is_empty():
			mine.append(pick.pop_at(rng.randi_range(0, pick.size() - 1)))
		for n in outer:
			var is_loose: bool = mine.has(n) or not heavy
			cols[n] = {"h": 2, "kind": K.NORMAL if is_loose else K.HEAVY}
			if is_loose:
				loose.append(n)
		inner = outer


## Pared pesada: la escalera está rodeada de pesados de 2 de alto (no se mueven), pero hay algún bloque común mezclado: hay que descubrir cuál se puede sacar y desde dónde.
static func _c_pesada(ctx: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = ctx.rng
	var chain := _chain(ctx, ctx.h)
	if chain.is_empty():
		return {}
	var cols := {}
	_add_chain(cols, chain)
	var ring := _ring(ctx, chain, cols, 2)
	if ring.size() < 3:
		return {}
	var loose: Array[Vector2i] = []
	if ctx.idea == "muro_simple":   # (para las primeras etapas, sin pesados todavía) todo el muro es de bloques comunes: hay que abrir un hueco empujando
		loose = ring.duplicate()
		for n in ring:
			cols[n] = {"h": 2, "kind": K.NORMAL}
		_decoys(ctx, cols, K.NORMAL, rng.randi_range(0, 1) if ctx.twist == "chico" else rng.randi_range(2, 3), 1, _near(ctx, chain[0], 3))
		_outer_wall(ctx, ring, cols, loose, false)
		return {"cols": cols, "goal": chain[chain.size() - 1], "rect": true, "loose": loose}
	var want := 1 if ctx.twist == "un_suelto" else 2
	var shuffled := ring.duplicate()
	while loose.size() < want and not shuffled.is_empty():
		loose.append(shuffled.pop_at(rng.randi_range(0, shuffled.size() - 1)))
	for n in ring:
		cols[n] = {"h": 2, "kind": K.NORMAL if loose.has(n) else K.HEAVY}
	_outer_wall(ctx, ring, cols, loose, true)
	_decoys(ctx, cols, K.HEAVY, rng.randi_range(0, 2), 2, _near(ctx, chain[0], 3))
	return {"cols": cols, "goal": chain[chain.size() - 1], "rect": true, "loose": loose}


## Cruce agrietado: la escalera es una isla de pesados de 2 de alto y hay un solo escalón agrietado suelto, lejos de la pared: se acomoda, se pisa para cruzar y se rompe (no se vuelve).
static func _c_cruce(ctx: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = ctx.rng
	var chain := _chain(ctx, ctx.h)
	if chain.is_empty():
		return {}
	var cols := {}
	_add_chain(cols, chain)
	var ring := _ring(ctx, chain, cols, 2)
	if ring.is_empty():
		return {}
	for n in ring:
		cols[n] = {"h": 2, "kind": K.HEAVY}
	var near_cells := _near(ctx, chain[0], 4)
	_decoys(ctx, cols, K.HEAVY, rng.randi_range(0, 1) if ctx.twist == "simple" else rng.randi_range(2, 3), 2, near_cells)
	var steps: Array[Vector2i] = []
	var reach := _walk_reach(ctx, cols)
	for c in near_cells:
		if cols.has(c) or c == ctx.arrival or not _free(ctx.st, c, ctx.ey, ctx.ey):
			continue
		var near := 99
		for n in ring:
			near = mini(near, absi(c.x - n.x) + absi(c.y - n.y))
		if near >= 2 and _pushable(ctx, c, cols, reach):
			steps.append(c)
	if steps.is_empty():
		return {}
	var first: Vector2i = steps.pop_at(rng.randi_range(0, steps.size() - 1))
	cols[first] = {"h": 1, "kind": K.CRACKED}
	if not steps.is_empty():   # un repuesto: un clic de más que rompa el escalón no tira abajo toda la partida
		cols[steps[rng.randi_range(0, steps.size() - 1)]] = {"h": 1, "kind": K.CRACKED}
	return {"cols": cols, "goal": chain[chain.size() - 1], "rect": true}


## Hielo y freno: un pasillo de hielo (5 o 6 celdas de piso) entre paredes de 3; al pisarlo resbalás hasta chocar. La escalera de salida sólo se alcanza desde la celda `k` del pasillo.
## Hay un bloque (el freno) en la segunda celda: se empuja hacia adelante y hace que frenes justo antes de él. El final del pasillo es pared. Con el giro "doble" hay dos frenos juntos.
static func _c_freno(ctx: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = ctx.rng
	var st: Dictionary = ctx.st
	var ey: int = ctx.ey
	var h: int = ctx.h
	if h < ROOM:
		return {}
	var d := DIRS4[rng.randi_range(0, 3)]
	var perp := Vector2i(-d.y, d.x)
	var double: bool = ctx.twist == "doble"
	var length := 6 if double else rng.randi_range(5, 6)
	var s0 := _pick(ctx)
	var entry := s0 - d
	if not (ctx.cellset.has(entry) or entry == ctx.arrival):
		return {}
	var lane: Array[Vector2i] = []
	var floor_kinds := {}
	for i in length:
		var c := s0 + d * i
		if not (ctx.cellset.has(c) and c != ctx.arrival and _addable(st, c, ey) and _free(st, c, ey, ey + 2)):
			return {}
		lane.append(c)
		floor_kinds[c] = K.ICE
	var cols := {lane[1]: {"h": 1, "kind": K.NORMAL}}   # el freno
	if double:
		cols[lane[2]] = {"h": 1, "kind": K.NORMAL}
	var k := 4 if double else rng.randi_range(3, length - 2)   # (con k = 2 se llega sin mover nada: resbalando desde el final contra el freno)
	var c1: Vector2i = lane[k] + perp * (1 if rng.randf() < 0.5 else -1)
	var side := {}   # las celdas de al lado del pasillo: paredes (salvo la de la escalera)
	for c in lane:
		side[c + perp] = true
		side[c - perp] = true
	side.erase(c1)
	var avoid := {entry: true}
	for c in lane:
		avoid[c] = true
	for n in side:
		avoid[n] = true
	if not ctx.cellset.has(c1) or c1 == ctx.arrival or c1 == entry or floor_kinds.has(c1) or not _free(st, c1, ey, ey):
		return {}
	var chain: Array[Vector2i] = [c1]
	for q in range(1, h):
		var next := Vector2i(-9, -9)
		for t in 30:
			var n: Vector2i = chain[chain.size() - 1] + DIRS4[rng.randi_range(0, 3)]
			if ctx.cellset.has(n) and not chain.has(n) and not avoid.has(n) and n != ctx.arrival and _free(st, n, ey, ey + q):
				next = n
				break
		if next.x < 0:
			return {}
		chain.append(next)
	_add_chain(cols, chain)
	var walls := {}   # celda -> alto. Las del pasillo son de 3: parado arriba del freno no se puede subir a ellas (si no, se esquivaría el pasillo)
	for n in side:
		walls[n] = 3
	walls[lane[length - 1] + d] = 3
	for cc in chain:
		for dd in DIRS4:
			if not walls.has(cc + dd):
				walls[cc + dd] = 2
	for n in walls:
		if cols.has(n) or floor_kinds.has(n) or not ctx.cellset.has(n):
			continue   # (lo que no es piso ya es vacío)
		if n == ctx.arrival or n == entry or not _free(st, n, ey, ey + int(walls[n]) - 1):
			return {}
		cols[n] = {"h": int(walls[n]), "kind": K.HEAVY}
	return {"cols": cols, "goal": chain[chain.size() - 1], "brake": lane[1], "floor_kinds": floor_kinds, "extra": [entry], "margin_from": [entry, ctx.arrival]}


## Dónde frena (o se cae) un resbalón que parte de `pos` en la dirección `d` sobre la pista: la celda donde frena, o (-9, -9) si se cae por el borde.
static func _slide_sim(pos: Vector2i, d: Vector2i, rset: Dictionary, blockers: Dictionary) -> Vector2i:
	var p := pos
	for i in 20:
		var n := p + d
		if blockers.has(n):
			return p
		if not rset.has(n):
			return Vector2i(-9, -9)
		p = n
	return p


## Una pista de hielo: un piso de hielo (de 3 x 4 a 2 x 7 celdas) con topes (pesados) adentro y vacío alrededor. Al pisarlo resbalás en línea recta hasta chocar con algo; si lo que hay
## adelante es el borde, te caés. La escalera de salida está pegada a un costado de la pista: hay que frenar justo ahí. Se arma siguiendo una secuencia de resbalones (con los topes que la
## hacen posible), así siempre tiene solución; el solucionador dice si hay una más corta.
static func _c_pista(ctx: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = ctx.rng
	var st: Dictionary = ctx.st
	var ey: int = ctx.ey
	var w := 3
	var dp := 4
	var want := rng.randi_range(2, 3) + int(ctx.d * 2.0)
	match ctx.twist:
		"grande":
			w = 3
			dp = 6
			want = rng.randi_range(3, 5)
		"alargada":
			w = 2
			dp = 7
			want = rng.randi_range(2, 4)
	if rng.randf() < 0.5:
		var t := w
		w = dp
		dp = t
	var origins := _rect_origins(ctx, w, dp)
	if origins.is_empty():
		return _ce(1)
	var o: Vector2i = origins[rng.randi_range(0, origins.size() - 1)]
	var region: Array[Vector2i] = []
	var rset := {}
	for x in w:
		for z in dp:
			var c := o + Vector2i(x, z)
			region.append(c)
			rset[c] = true
	# la entrada: una celda de afuera pegada a la pista (por donde se pisa el hielo)
	var near_region := {}   # las celdas pegadas a la pista no tienen piso (salvo la entrada): por ahí no se camina
	for c in region:
		for d in DIRS4:
			if not rset.has(c + d):
				near_region[c + d] = true
	var walk := {ctx.arrival: true}   # por dónde se llega a pie desde la llegada
	var wq: Array[Vector2i] = [ctx.arrival]
	var wi := 0
	while wi < wq.size():
		var wc := wq[wi]
		wi += 1
		for d in DIRS4:
			var wn: Vector2i = wc + d
			if ctx.cellset.has(wn) and not walk.has(wn) and not rset.has(wn) and not near_region.has(wn) and _free(st, wn, ey, ey):
				walk[wn] = true
				wq.append(wn)
	var pairs: Array = []   # [celda de la pista, dirección con la que se entra, celda de afuera]
	for c in region:
		for d in DIRS4:
			var n: Vector2i = c - d
			if not rset.has(n) and ctx.cellset.has(n) and n != ctx.arrival and _free(st, n, ey, ey):
				var reachable := false   # la entrada tiene que tener un vecino (que no sea de la pista) al que se llegue a pie
				for d2 in DIRS4:
					if walk.has(n + d2):
						reachable = true
				if reachable:
					pairs.append([c, d, n])
	if pairs.is_empty():
		return _ce(2)
	var pr: Array = pairs[rng.randi_range(0, pairs.size() - 1)]
	var entry_in: Vector2i = pr[0]
	var d0: Vector2i = pr[1]
	var entry: Vector2i = pr[2]
	# la secuencia de resbalones
	var blockers := {}
	var visited := {entry_in: true}
	var dirs: Array[Vector2i] = [d0]
	var pos := entry_in
	var stop := _extend(pos, d0, true, rset, blockers, rng, visited)
	if stop.x < 0:
		return _ce(3)
	var stops: Array[Vector2i] = [stop]
	visited[stop] = true
	var count := 1
	# la salida: el último resbalón va en línea recta hasta el borde, donde lo frena la escalera (afuera de la pista); se elige apenas hay una dirección que lo permite
	var exit_in := Vector2i(-9, -9)
	var exit_dir := Vector2i.ZERO
	var c1 := Vector2i(-9, -9)
	var done := false
	for it in 40:
		pos = stops[stops.size() - 1]
		if count >= want:
			var qs: Array[Vector2i] = DIRS4.duplicate()
			while not qs.is_empty() and not done:
				var q: Vector2i = qs.pop_at(rng.randi_range(0, qs.size() - 1))
				var e := pos
				while rset.has(e + q) and not blockers.has(e + q):
					e += q
				var out_cell := e + q
				if e != pos and not rset.has(out_cell) and not blockers.has(out_cell) and ctx.cellset.has(out_cell) and out_cell != entry and out_cell != ctx.arrival and _free(st, out_cell, ey, ey) and not visited.has(e) and e != entry_in:
					stops.append(e)
					dirs.append(q)
					visited[e] = true
					count += 1
					exit_in = e
					exit_dir = q
					c1 = out_cell
					done = true
			if done:
				break
			# o ya se frenó en un borde de la pista con la celda de afuera libre: se sale caminando hacia la escalera
			var outs: Array[Vector2i] = []
			for d in DIRS4:
				var n: Vector2i = pos + d
				if not rset.has(n) and ctx.cellset.has(n) and not blockers.has(n) and n != entry and n != ctx.arrival and _free(st, n, ey, ey) and pos != entry_in:
					outs.append(d)
			if not outs.is_empty() and rng.randf() < 0.6:
				exit_in = pos
				exit_dir = outs[rng.randi_range(0, outs.size() - 1)]
				c1 = pos + exit_dir
				done = true
				break
		var nd := DIRS4[rng.randi_range(0, 3)]
		if nd == dirs[dirs.size() - 1] or blockers.has(pos + nd) or not rset.has(pos + nd):
			continue
		var saved := blockers.duplicate()
		var nstop := _extend(pos, nd, false, rset, blockers, rng, visited)
		if nstop.x < 0 or visited.has(nstop):
			blockers = saved   # ese resbalón no sirve: se prueba otra dirección
			continue
		stops.append(nstop)
		visited[nstop] = true
		dirs.append(nd)
		count += 1
	if not done:
		return _ce(8)
	# la escalera y su pared
	var avoid := {entry: true}
	for c in region:
		avoid[c] = true
	var chain: Array[Vector2i] = [c1]
	for q in range(1, ctx.h):
		var next := Vector2i(-9, -9)
		for t in 30:
			var n: Vector2i = chain[chain.size() - 1] + DIRS4[rng.randi_range(0, 3)]
			if ctx.cellset.has(n) and not chain.has(n) and not avoid.has(n) and n != ctx.arrival and _free(st, n, ey, ey + q):
				next = n
				break
		if next.x < 0:
			return _ce(6)
		chain.append(next)
	var cols := {}
	_add_chain(cols, chain)
	var ring := _ring(ctx, chain, cols, 2, avoid)
	for n in ring:
		cols[n] = {"h": 2, "kind": K.HEAVY}
	# los topes que hacen posible la secuencia (más algún señuelo que no la rompe)
	var inside: Array[Vector2i] = []
	for c in region:
		if not blockers.has(c) and not visited.has(c):
			inside.append(c)
	for i in rng.randi_range(0, 2):
		if inside.is_empty():
			break
		var extra: Vector2i = inside.pop_at(rng.randi_range(0, inside.size() - 1))
		blockers[extra] = true
		if not _replay_slides(entry_in, dirs, stops, rset, blockers, cols):
			blockers.erase(extra)
	if not _replay_slides(entry_in, dirs, stops, rset, blockers, cols):
		return _ce(7)
	for b in blockers:
		cols[b] = {"h": 2, "kind": K.HEAVY}
	var floor_kinds := {}
	for c in region:
		floor_kinds[c] = K.ICE
	var voids := {}   # alrededor de la pista no hay piso (salvo la entrada y la salida): resbalar de más es caerse
	for c in region:
		for d in DIRS4:
			var n: Vector2i = c + d
			if not rset.has(n) and n != entry and not cols.has(n):
				voids[n] = true
	return {"cols": cols, "goal": chain[chain.size() - 1], "floor_kinds": floor_kinds, "extra": [entry], "margin_from": [entry, ctx.arrival], "voids": voids, "slides": 1, "dbg": "entrada %s -> %s dir %s, paradas %s, salida %s -> %s, entrada en cols %s, region %s" % [str(entry), str(entry_in), str(d0), str(stops), str(exit_in), str(c1), str(cols.has(entry)), str(region)]}


## Los últimos resbalones hacia la salida: desde `pos`, o bien ya se está en la línea de la salida (se resbala hacia la escalera, que frena), o bien un resbalón más lleva a esa línea
## (con un tope que lo frena ahí) y después se resbala hacia la escalera. Devuelve {stops, dirs, blockers} o {} si no se puede.
static func _finish(pos: Vector2i, exit_in: Vector2i, exit_dir: Vector2i, c1: Vector2i, rset: Dictionary, blockers: Dictionary, visited: Dictionary) -> Dictionary:
	var with_exit := blockers.duplicate()
	with_exit[c1] = true
	if pos == exit_in:
		return {"stops": [], "dirs": [], "blockers": blockers}
	if _slide_sim(pos, exit_dir, rset, with_exit) == exit_in and rset.has(pos + exit_dir) and not blockers.has(pos + exit_dir) and not visited.has(exit_in):
		return {"stops": [exit_in], "dirs": [exit_dir], "blockers": blockers}
	for m in range(1, 8):
		var sp: Vector2i = exit_in - exit_dir * m
		if not rset.has(sp):
			break
		if blockers.has(sp) or visited.has(sp):
			continue
		for q in DIRS4:
			if q == exit_dir or q == -exit_dir:
				continue
			var delta: Vector2i = sp - pos
			var k := 0
			if q.x != 0 and delta.y == 0 and delta.x * q.x > 0:
				k = absi(delta.x)
			elif q.y != 0 and delta.x == 0 and delta.y * q.y > 0:
				k = absi(delta.y)
			if k == 0:
				continue
			var clear := true
			for i in range(1, k + 1):
				if blockers.has(pos + q * i) or not rset.has(pos + q * i):
					clear = false
			var bcell: Vector2i = sp + q
			if not clear or not rset.has(bcell) or visited.has(bcell):
				continue
			var nb := blockers.duplicate()
			nb[bcell] = true
			var nbx := nb.duplicate()
			nbx[c1] = true
			if _slide_sim(pos, q, rset, nb) != sp:
				continue
			if _slide_sim(sp, exit_dir, rset, nbx) == exit_in:
				return {"stops": [sp, exit_in], "dirs": [q, exit_dir], "blockers": nb}
	return {}


## Un resbalón de la secuencia: parte de `pos`; elige dónde frena y, si hace falta, pone el tope que lo frena ahí. Devuelve la celda donde frena ((-9, -9) si no se puede).
static func _extend(pos: Vector2i, d: Vector2i, first: bool, rset: Dictionary, blockers: Dictionary, rng: RandomNumberGenerator, forbid := {}) -> Vector2i:
	var line: Array[Vector2i] = []
	var p := pos if first else pos + d
	while rset.has(p) and not blockers.has(p):
		line.append(p)
		p += d
	if line.is_empty():
		return Vector2i(-9, -9)
	var idx := line.size() - 1
	var options: Array[int] = []   # dónde se puede frenar poniendo un tope justo después (no sobre una celda por la que ya se pasó o se frenó)
	for i in range(0, line.size() - 1):
		if not forbid.has(line[i + 1]):
			options.append(i)
	if not blockers.has(p):   # sin nada adelante se cae: hay que poner un tope antes del final
		if options.is_empty():
			return Vector2i(-9, -9)
		idx = options[rng.randi_range(0, options.size() - 1)]
		blockers[line[idx + 1]] = true
	elif not options.is_empty() and rng.randf() < 0.5:
		idx = options[rng.randi_range(0, options.size() - 1)]
		blockers[line[idx + 1]] = true
	return line[idx]


## Con todos los topes puestos (y la pared y la escalera, que también frenan), ¿la secuencia de resbalones frena donde se pensó?
static func _replay_slides(entry_in: Vector2i, dirs: Array[Vector2i], stops: Array[Vector2i], rset: Dictionary, blockers: Dictionary, cols: Dictionary) -> bool:
	var all := blockers.duplicate()
	for c in cols:
		all[c] = true
	var pos := entry_in
	for i in dirs.size():
		var p := _slide_sim(pos, dirs[i], rset, all) if i == 0 else _slide_sim(pos, dirs[i], rset, all)
		if p != stops[i]:
			return false
		pos = p
	return true


## Hielo y billar: la escalera es una isla de pesados de 2 de alto y el único escalón es un bloque de hielo suelto: resbala hasta chocar con algo, así que hay que usar los topes (pesados)
## para dejarlo justo contra la pared. Si se resbala fuera de la plataforma, se pierde el escalón.
static func _c_billar(ctx: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = ctx.rng
	var chain := _chain(ctx, ctx.h)
	if chain.is_empty():
		return {}
	var cols := {}
	_add_chain(cols, chain)
	var ring := _ring(ctx, chain, cols, 2)
	if ring.is_empty():
		return {}
	for n in ring:
		cols[n] = {"h": 2, "kind": K.HEAVY}
	var near_cells := _near(ctx, chain[0], 4)
	_decoys(ctx, cols, K.HEAVY, rng.randi_range(1, 2) if ctx.twist == "un_tope" else rng.randi_range(3, 4), 2, near_cells)
	var steps: Array[Vector2i] = []
	var reach := _walk_reach(ctx, cols)
	for c in near_cells:
		if cols.has(c) or c == ctx.arrival or not _free(ctx.st, c, ctx.ey, ctx.ey):
			continue
		var near := 99
		for n in ring:
			near = mini(near, absi(c.x - n.x) + absi(c.y - n.y))
		if near >= 2 and _pushable(ctx, c, cols, reach):
			steps.append(c)
	if steps.is_empty():
		return {}
	var s: Vector2i = steps[rng.randi_range(0, steps.size() - 1)]
	cols[s] = {"h": 1, "kind": K.ICE}
	return {"cols": cols, "goal": chain[chain.size() - 1], "rect": true, "ice_block": s}


## Campo de trampas: un piso donde casi todas las celdas son trampas (se desarman al pisarlas y te caés) y hay un solo camino firme, que serpentea hasta la escalera. Vacío alrededor.
static func _c_trampas(ctx: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = ctx.rng
	var st: Dictionary = ctx.st
	var ey: int = ctx.ey
	var w := 3
	var dp := 4 if ctx.twist == "fino" else 6
	if rng.randf() < 0.5:
		var t := w
		w = dp
		dp = t
	var origins := _rect_origins(ctx, w, dp)
	if origins.is_empty():
		return {}
	var o: Vector2i = origins[rng.randi_range(0, origins.size() - 1)]
	var region: Array[Vector2i] = []
	var rset := {}
	for x in w:
		for z in dp:
			var c := o + Vector2i(x, z)
			region.append(c)
			rset[c] = true
	# el camino firme: un recorrido sin repetir celdas de borde a borde
	var start: Vector2i = region[rng.randi_range(0, region.size() - 1)]
	var path: Array[Vector2i] = [start]
	var seen := {start: true}
	for step in 60:
		var opts: Array[Vector2i] = []
		for d in DIRS4:
			var n: Vector2i = path[path.size() - 1] + d
			if rset.has(n) and not seen.has(n):
				opts.append(n)
		if opts.is_empty():
			break
		var nx: Vector2i = opts[rng.randi_range(0, opts.size() - 1)]
		path.append(nx)
		seen[nx] = true
	if path.size() < 7:
		return {}
	var safe := {}
	for c in path:
		safe[c] = true
	var entry_in: Vector2i = path[0]
	var exit_in: Vector2i = path[path.size() - 1]
	var entry := Vector2i(-9, -9)
	for d in DIRS4:
		var n: Vector2i = entry_in + d
		if not rset.has(n) and ctx.cellset.has(n) and n != ctx.arrival and _free(st, n, ey, ey):
			entry = n
			break
	var c1 := Vector2i(-9, -9)
	var gate_cell := Vector2i(-9, -9)   # con puerta: al salir del campo hay un bloque común de 2 de alto; se empuja hacia adelante y recién ahí se llega al primer escalón (al costado)
	var gate: bool = ctx.d >= 0.25
	if gate:
		var dirs: Array[Vector2i] = DIRS4.duplicate()
		for i in dirs.size():
			var j := rng.randi_range(0, dirs.size() - 1)
			var tmp := dirs[i]
			dirs[i] = dirs[j]
			dirs[j] = tmp
		for d in dirs:
			var g: Vector2i = exit_in + d
			var beyond: Vector2i = g + d
			if rset.has(g) or not ctx.cellset.has(g) or g == entry or g == ctx.arrival or not _free(st, g, ey, ey + 1):
				continue
			if not ctx.cellset.has(beyond) or rset.has(beyond) or beyond == ctx.arrival or beyond == entry or not _free(st, beyond, ey, ey):
				continue
			for d2 in [Vector2i(-d.y, d.x), Vector2i(d.y, -d.x)]:
				var m: Vector2i = g + d2
				var touches := false   # el primer escalón no puede tocar el campo: si no, se llega sin pasar por la puerta
				for dd in DIRS4:
					var nb: Vector2i = m + dd
					if nb != g and (rset.has(nb) or nb == entry or nb == ctx.arrival):
						touches = true
				if not touches and ctx.cellset.has(m) and not rset.has(m) and m != entry and m != ctx.arrival and _free(st, m, ey, ey):
					gate_cell = g
					c1 = m
					break
			if c1.x >= 0:
				break
	else:
		for d in DIRS4:
			var n: Vector2i = exit_in + d
			if not rset.has(n) and ctx.cellset.has(n) and n != entry and n != ctx.arrival and _free(st, n, ey, ey):
				c1 = n
				break
	if entry.x < 0 or c1.x < 0:
		return {}
	var avoid := {entry: true}
	if gate_cell.x >= 0:
		avoid[gate_cell] = true
		avoid[gate_cell + (gate_cell - exit_in)] = true
	for c in region:
		avoid[c] = true
	var chain: Array[Vector2i] = [c1]
	for q in range(1, ctx.h):
		var next := Vector2i(-9, -9)
		for t in 30:
			var n: Vector2i = chain[chain.size() - 1] + DIRS4[rng.randi_range(0, 3)]
			if ctx.cellset.has(n) and not chain.has(n) and not avoid.has(n) and n != ctx.arrival and _free(st, n, ey, ey + q):
				next = n
				break
		if next.x < 0:
			return {}
		chain.append(next)
	var cols := {}
	_add_chain(cols, chain)
	if gate_cell.x >= 0:
		cols[gate_cell] = {"h": 2, "kind": K.NORMAL}
	var ring := _ring(ctx, chain, cols, 2, avoid)
	for n in ring:
		cols[n] = {"h": 2, "kind": K.HEAVY}
	var floor_kinds := {}
	var trap_share := 0.9 if ctx.twist == "fino" else 0.75
	for c in region:
		floor_kinds[c] = K.NORMAL if (safe.has(c) or rng.randf() > trap_share) else K.TRAP
	var voids := {}
	for c in region:
		for d in DIRS4:
			var n: Vector2i = c + d
			if not rset.has(n) and n != entry and not cols.has(n):
				voids[n] = true
	var out := {"cols": cols, "goal": chain[chain.size() - 1], "floor_kinds": floor_kinds, "extra": [entry], "margin_from": [entry, ctx.arrival], "voids": voids, "min_path": path.size() - 3}
	if gate_cell.x >= 0:
		out["gate"] = true
		out["loose"] = [gate_cell]
	return out


## Camino más corto (por celdas) de `from` a `to` sin pasar por las celdas bloqueadas; [] si no hay.
static func _bfs_path(pool: Dictionary, from: Vector2i, to: Vector2i, blocked: Dictionary) -> Array[Vector2i]:
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	var i := 0
	while i < queue.size() and not prev.has(to):
		var c := queue[i]
		i += 1
		for d in DIRS4:
			var n: Vector2i = c + d
			if pool.has(n) and not prev.has(n) and not blocked.has(n):
				prev[n] = c
				queue.append(n)
	var out: Array[Vector2i] = []
	if not prev.has(to):
		return out
	var cur := to
	while cur != from:
		out.append(cur)
		cur = prev[cur]
	out.append(from)
	out.reverse()
	return out


## Cuenta de bomba: la escalera está encerrada por pesados y la única entrada es una bomba (pisarla la desactiva), a la que hay que llegar por un laberinto de pesados antes de que la
## cuenta (que corre con cada movimiento a ras del piso) llegue a cero. La cuenta se fija justo con lo que tarda el camino más corto: un paso en falso y explota.
## El laberinto se arma alargando de a poco el camino más corto (se tapa una celda del camino mientras siga habiendo otro).
static func _c_bomba(ctx: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = ctx.rng
	var chain := _chain(ctx, ctx.h, {}, 3)
	if chain.is_empty():
		return {}
	var cols := {}
	_add_chain(cols, chain)
	var ring := _ring(ctx, chain, cols, 2)
	if ring.size() < 2:
		return {}
	var gate: Vector2i = ring[rng.randi_range(0, ring.size() - 1)]
	for n in ring:
		cols[n] = {"h": 2, "kind": K.HEAVY}
	cols[gate] = {"h": 1, "kind": K.BOMB, "timer": 99}
	# la zona del laberinto: el rectángulo que une la llegada con la escalera
	var lo := Vector2i(ctx.arrival.x, ctx.arrival.y)
	var hi := lo
	for c in cols:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var pool := {}
	for x in range(lo.x - 1, hi.x + 2):
		for z in range(lo.y - 1, hi.y + 2):
			var c := Vector2i(x, z)
			if ctx.cellset.has(c) and _free(ctx.st, c, ctx.ey, ctx.ey + 1):
				pool[c] = true
	pool[ctx.arrival] = true
	var stands: Array[Vector2i] = []
	for d in DIRS4:
		var n: Vector2i = gate + d
		if pool.has(n) and not cols.has(n):
			stands.append(n)
	if stands.is_empty():
		return {}
	var stand: Vector2i = stands[rng.randi_range(0, stands.size() - 1)]
	var blocked := {}
	for c in cols:
		blocked[c] = true
	var path := _bfs_path(pool, ctx.arrival, stand, blocked)
	if path.is_empty():
		return {}
	var want := (rng.randi_range(7, 10) if ctx.twist == "justa" else rng.randi_range(6, 8)) + int(ctx.d * 4.0)
	for it in 60:
		if path.size() - 1 >= want or path.size() < 3:
			break
		var cell: Vector2i = path[rng.randi_range(1, path.size() - 2)]
		var try_block := blocked.duplicate()
		try_block[cell] = true
		var p2 := _bfs_path(pool, ctx.arrival, stand, try_block)
		if not p2.is_empty():
			blocked = try_block
			path = p2
			cols[cell] = {"h": 2, "kind": K.HEAVY}
	if path.size() - 1 < 5:
		return {}
	return {"cols": cols, "goal": chain[chain.size() - 1], "rect": true, "rect_cells": [ctx.arrival], "bomb": gate, "slack": 2 if ctx.twist == "justa" else 3}   # (la acción con que se llega a la sala ya cuenta una vez)


## Trampolín: la salida es una columna alta de pesados (no se trepa) y hay una catapulta suelta: hay que llevarla pegada a la columna y pisarla para salir disparado hacia arriba y
## agarrarse del borde de arriba. Los topes (pesados) cambian por dónde se la puede empujar.
static func _c_trampolin(ctx: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = ctx.rng
	if ctx.h < ROOM:
		return {}
	var arrival: Vector2i = ctx.arrival
	var options: Array[Vector2i] = []
	for c in ctx.cells:
		if absi(c.x - arrival.x) + absi(c.y - arrival.y) >= 3 and _free(ctx.st, c, ctx.ey, ctx.ey + ctx.h - 1):
			options.append(c)
	if options.is_empty():
		return {}
	var g: Vector2i = options[rng.randi_range(0, options.size() - 1)]
	var cols := {g: {"h": ctx.h, "kind": K.HEAVY}}
	var cats: Array[Vector2i] = []
	var around := _near(ctx, g, 4)
	_decoys(ctx, cols, K.HEAVY, rng.randi_range(1, 2) if ctx.twist == "simple" else rng.randi_range(3, 4), 2, around)
	var reach := _walk_reach(ctx, cols)
	for c in around:
		if not cols.has(c) and c != arrival and _free(ctx.st, c, ctx.ey, ctx.ey + 1) and absi(c.x - g.x) + absi(c.y - g.y) >= 2 and _pushable(ctx, c, cols, reach):
			cats.append(c)
	if cats.is_empty():
		return {}
	cols[cats[rng.randi_range(0, cats.size() - 1)]] = {"h": 1, "kind": K.CATAPULT}
	return {"cols": cols, "goal": g, "rect": true}


# --- footprint (la plataforma de la sala) -------------------------------------------------------------------------------------------------------

static func _flood_walk(fp: Dictionary, start: Vector2i, solid: Dictionary) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var i := 0
	while i < queue.size():
		var c := queue[i]
		i += 1
		for d in DIRS4:
			var n: Vector2i = c + d
			if fp.has(n) and not seen.has(n) and not solid.has(n):
				seen[n] = true
				queue.append(n)
	return seen


static func _flood(fp: Dictionary, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var i := 0
	while i < queue.size():
		var c := queue[i]
		i += 1
		for d in DIRS4:
			var n: Vector2i = c + d
			if fp.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen


## Las celdas de piso de la sala: lo que la idea necesita (más un margen para pararse y empujar), unido por un camino a la llegada. Afuera no hay piso: es vacío.
static func _footprint(ctx: Dictionary, cand: Dictionary) -> Dictionary:
	var st: Dictionary = ctx.st
	var ey: int = ctx.ey
	var arrival: Vector2i = ctx.arrival
	var need := {arrival: true}
	for c in cand.cols:
		need[c] = true
	for c in cand.get("floor_kinds", {}):
		need[c] = true
	for c in cand.get("extra", []):
		need[c] = true
	var fp := need.duplicate()
	var voids: Dictionary = cand.get("voids", {})
	var m := int(cand.get("margin", 1))
	if cand.get("rect", false):
		var lo := Vector2i(99, 99)
		var hi := Vector2i(-1, -1)
		for c in cand.cols:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		for c in cand.get("rect_cells", []):
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		for x in range(lo.x - m, hi.x + m + 1):
			for z in range(lo.y - m, hi.y + m + 1):
				var c := Vector2i(x, z)
				if _ok(c) and not voids.has(c):
					fp[c] = true
	else:
		for c in cand.get("margin_from", []):
			for dx in range(-m, m + 1):
				for dz in range(-m, m + 1):
					var n: Vector2i = c + Vector2i(dx, dz)
					if _ok(n) and not voids.has(n):
						fp[n] = true
	for c in fp.keys():
		var cell := Vector3i(c.x, ey - 1, c.y)
		if not st.tower.blocks.has(cell) and (st.reserved.has(cell) or not _ok(c)):
			if need.has(c) and c != arrival:
				return _fe(1)
			fp.erase(c)
	# unir todo con la llegada
	var blocked := {}
	for c in cand.cols:
		blocked[c] = true
	for c in cand.get("floor_kinds", {}):
		blocked[c] = true
	for it in 10:
		var reach := _flood(fp, arrival)
		var missing := Vector2i(-9, -9)
		for c in need:
			if fp.has(c) and not reach.has(c):
				missing = c
				break
		if missing.x < 0:
			break
		var comp := _flood(fp, missing)
		# camino más corto desde lo que ya está unido hasta tocar el otro pedazo
		var prev := {}
		var queue: Array[Vector2i] = []
		for c in reach:
			queue.append(c)
			prev[c] = c
		var found := Vector2i(-9, -9)
		var qi := 0
		while qi < queue.size() and found.x < 0:
			var c := queue[qi]
			qi += 1
			for d in DIRS4:
				var n: Vector2i = c + d
				if prev.has(n):
					continue
				if comp.has(n):
					found = c
					break
				if _ok(n) and not voids.has(n) and not blocked.has(n) and not fp.has(n) and _floor_ok(st, n, ey):
					prev[n] = c
					queue.append(n)
		if found.x < 0:
			if OS.get_environment("IDEA_LOG") != "":
				for d in DIRS4:
					var q: Vector2i = arrival + d
					print("       vecino %s ok=%s piso=%s reservado=%s col=%s" % [str(q), str(_ok(q)), str(st.tower.blocks.has(Vector3i(q.x, ey - 1, q.y))), str(st.reserved.has(Vector3i(q.x, ey - 1, q.y))), str(cand.cols.has(q))])
				print("     sin camino: llegada %s, falta %s, unido %d, otro %d, piso %d, vacios %d" % [str(arrival), str(missing), reach.size(), comp.size(), fp.size(), voids.size()])
			return _fe(2)
		var cur := found
		while not reach.has(cur):
			fp[cur] = true
			cur = prev[cur]
	var reach_all := _flood(fp, arrival)
	for c in need:
		if fp.has(c) and not reach_all.has(c):
			return _fe(3)
	# lo que hay que pisar (la entrada) tiene que poder alcanzarse a pie desde la llegada, sin pasar por encima de paredes
	var solid := {}
	for c in cand.cols:
		if int(cand.cols[c].h) >= 2 or int(cand.cols[c].kind) == K.HEAVY or int(cand.cols[c].kind) == K.SPIKES:
			solid[c] = true
	for e in cand.get("extra", []):
		for it in 6:
			var wreach := _flood_walk(fp, arrival, solid)
			if wreach.has(e):
				break
			var comp := _flood_walk(fp, e, solid)
			var prev := {}
			var queue: Array[Vector2i] = []
			for c in wreach:
				queue.append(c)
				prev[c] = c
			var found := Vector2i(-9, -9)
			var qi := 0
			while qi < queue.size() and found.x < 0:
				var c := queue[qi]
				qi += 1
				for d in DIRS4:
					var n: Vector2i = c + d
					if prev.has(n):
						continue
					if comp.has(n):
						found = c
						break
					if _ok(n) and not voids.has(n) and not solid.has(n) and not blocked.has(n) and not fp.has(n) and _floor_ok(st, n, ey):
						prev[n] = c
						queue.append(n)
			if found.x < 0:
				return _fe(4)
			var cur := found
			while not wreach.has(cur):
				fp[cur] = true
				cur = prev[cur]
		if not _flood_walk(fp, arrival, solid).has(e):
			return _fe(4)
	return fp


# --- verificación ---------------------------------------------------------------------------------------------------------------------------------

## Desplazamiento (en celdas, x y z) más grande que tuvo un movimiento a lo largo de la solución, de un bloque dado.
static func _block_slide(lg, path: Array, id: int) -> int:
	var replay = lg.clone()
	var best := 0
	for a in path:
		var before: Vector3i = replay.positions.get(id, Vector3i.ZERO)
		replay.try_action(a.dir, a.mode)
		if replay.positions.has(id):
			var after: Vector3i = replay.positions[id]
			best = maxi(best, absi(after.x - before.x) + absi(after.z - before.z))
	return best


## ¿La solución usa lo que promete la idea? Devuelve cuántas veces (0 = no la usa; el respiro y el campo de trampas no prometen nada más que el recorrido).
static func _uses_idea(name: String, lg, path: Array, ey: int, cand: Dictionary) -> int:
	if name == "respiro":
		return 1
	var replay = lg.clone()
	var slides := 0
	var launches := 0
	for a in path:
		var before: Vector3i = replay.player
		replay.try_action(a.dir, a.mode)
		if absi(replay.player.x - before.x) + absi(replay.player.z - before.z) >= 2:
			slides += 1
		if replay.player.y - before.y >= 3:
			launches += 1
	match name:
		"reja", "taller", "chica", "mediana":
			return 1
		"campo_trampas":
			if cand.get("gate", false):   # la puerta tiene que haberse movido
				var gid: int = lg.blocks.get(Vector3i(cand.loose[0].x, ey, cand.loose[0].y), -1)
				if gid < 0 or replay.positions.get(gid) == lg.positions[gid]:
					return 0
			return 1 if path.size() >= int(cand.get("min_path", 6)) else 0
		"hielo_pista":
			return slides if slides >= int(cand.get("slides", 3)) else 0
		"trampolin":
			return launches
		"hielo_billar":
			var id: int = lg.blocks.get(Vector3i(cand.ice_block.x, ey, cand.ice_block.y), -1)
			return 1 if id >= 0 and _block_slide(lg, path, id) >= 2 else 0
		"hielo_freno":
			var bid: int = lg.blocks.get(Vector3i(cand.brake.x, ey, cand.brake.y), -1)
			return 1 if slides >= 1 and bid >= 0 and replay.positions.get(bid) != lg.positions[bid] else 0
		"cuenta_bomba":
			var bomb: int = lg.blocks.get(Vector3i(cand.bomb.x, ey, cand.bomb.y), -1)
			return 1 if bomb >= 0 and not replay.bomb_timer.has(bomb) else 0
		"pared_pesada", "muro_simple":
			var moved := 0
			for c in cand.loose:
				var lid: int = lg.blocks.get(Vector3i(c.x, ey, c.y), -1)
				if lid >= 0 and replay.positions.get(lid) != lg.positions[lid]:
					moved += 1
			return moved
	var key := K.CRACKED if name == "cruce_agrietado" else K.SPIKES
	var start := {}
	for id in lg.kind_of:
		if lg.kind_of[id] == key:
			start[id] = lg.positions[id]
	var changed := 0
	for id in start:
		if replay.positions.get(id) != start[id]:
			changed += 1
	return changed


## Qué parte del recorrido se ve desde alguna de las 4 diagonales de la cámara: desde cada una, el rayo hacia la cámara sube una capa por celda; si lo cruza un bloque de la sala, el
## lugar queda tapado. (Los bloques de más arriba no cuentan: desde arriba se ocultan las capas que tapan.)
static func _visible_fraction(lg, path: Array, ey: int, h: int) -> float:
	var replay = lg.clone()
	var seen := 0
	var total := 0
	for a in path:
		replay.try_action(a.dir, a.mode)
		var p: Vector3i = replay.player
		total += 1
		var any := false
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				var clear := true
				for t in range(1, 4):
					if p.y + t > ey + h - 2:
						break
					if lg.blocks.has(Vector3i(p.x + sx * t, p.y + t, p.z + sz * t)):
						clear = false
						break
				if clear:
					any = true
		if any:
			seen += 1
	return float(seen) / float(maxi(total, 1))


## Costo del error: a lo largo de la solución, de las otras cosas que se podían hacer en cada paso, qué fracción lleva a perder o a una posición sin salida (se miden unos pocos pasos
## repartidos y, en cada uno, hasta 6 alternativas). Un puzzle donde cualquier paso en falso se arregla tiene costo 0.
static func _error_cost(win, path: Array, ey: int, h: int, rng: RandomNumberGenerator) -> float:
	var lg = win.clone()
	var states: Array = []
	for a in path:
		states.append([lg.clone(), a])
		lg.try_action(a.dir, a.mode)
	if states.is_empty():
		return 0.0
	var picks: Array = []
	var steps := mini(ERROR_SAMPLES, states.size())
	for i in steps:
		picks.append(states[(i * states.size()) / steps])
	var tested := 0
	var dead := 0
	for pk in picks:
		var base = pk[0]
		var good: Dictionary = pk[1]
		var alts: Array = []
		for di in TowerLogic.DIRS.size():
			for mode in [TowerLogic.Mode.MOVE, TowerLogic.Mode.GRAB]:
				if TowerLogic.DIRS[di] == good.dir and mode == good.mode:
					continue
				alts.append([TowerLogic.DIRS[di], mode])
		for k in mini(6, alts.size()):
			var alt: Array = alts.pop_at(rng.randi_range(0, alts.size() - 1))
			var n = base.clone()
			if not n.try_action(alt[0], alt[1]).ok:
				continue
			tested += 1
			if n.lost:
				dead += 1
			elif Solver.solve(n, ey + h, {"max_states": 500, "goal_ids": win.goal_ids, "no_grab": false}).status == "unsolvable":
				dead += 1
	return float(dead) / float(maxi(tested, 1))


## Cuántos movimientos a ras del piso (donde corre la cuenta de la bomba) hace falta dar antes de pisar la bomba.
static func _floor_ticks(lg, path: Array, ey: int, bomb_cell: Vector2i) -> int:
	var replay = lg.clone()
	var ticks := 0
	for a in path:
		replay.try_action(a.dir, a.mode)
		if replay.player.y == ey:
			ticks += 1
		var id: int = lg.blocks.get(Vector3i(bomb_cell.x, ey, bomb_cell.y), -1)
		if id >= 0 and not replay.bomb_timer.has(id):
			break
	return ticks


static func _build(ctx: Dictionary, cand: Dictionary, floor_blocks: Array, final: bool, explicit: Array = []) -> Dictionary:
	var ey: int = ctx.ey
	var h: int = ctx.h
	var goal: Vector2i = cand.goal
	var blocks: Array = [{"c": Vector3i(goal.x, ey + h - 1, goal.y), "kind": K.NORMAL, "fixed": final or bool(cand.get("taller", false)), "timer": 0}]   # el tope de la salida primero (así su id es el primero)
	var cells: Array = cand.cols.keys()
	cells.sort_custom(func(a, b): return a.y * SIZE + a.x < b.y * SIZE + b.x)
	for c in cells:
		var col: Dictionary = cand.cols[c]
		for y in range(0, int(col.h)):
			if c == goal and y == h - 1:
				continue
			blocks.append({"c": Vector3i(c.x, ey + y, c.y), "kind": int(col.kind), "fixed": false, "timer": int(col.get("timer", 0))})
	if not explicit.is_empty():   # (la reja: ya viene desordenada, bloque por bloque)
		blocks = explicit
	var trial = ctx.st.sim.clone()
	for f in floor_blocks:
		trial.add_block(f.c, false, f.kind, 0)
	var base_id: int = trial._next_id
	for b in blocks:
		trial.add_block(b.c, b.fixed, b.kind, b.timer)
	var win = Gen._window(trial, ey, {base_id: true}, ey + h + (1 if cand.get("taller", false) else -1))
	if cand.get("taller", false):   # (lo de abajo es el suelo: la ventana corta lo que lo sostiene, y sin esto se cae al mover cajas)
		win._own_fixed()
		for c in win.blocks.keys():
			if c.y < ey:
				win.fixed[c] = true
		win._blocks_dirty = true
	win.goal_y = ey + h
	return {"blocks": blocks, "win": win}


## Prueba el candidato sobre el estado: arma la plataforma, resuelve la sala en una ventana, aplica el filtro de calidad y, si cumple, la agrega al estado.
static func _commit(ctx: Dictionary, cand: Dictionary, name: String, lo: int, hi: int, final: bool) -> Dictionary:
	var st: Dictionary = ctx.st
	var ey: int = ctx.ey
	var h: int = ctx.h
	var rng: RandomNumberGenerator = ctx.rng
	var fp := _footprint(ctx, cand)
	if fp.is_empty():
		return _no(0, name)
	var floor_blocks: Array = []
	var kinds: Dictionary = cand.get("floor_kinds", {})
	for c in fp:
		var cell := Vector3i(c.x, ey - 1, c.y)
		if st.tower.blocks.has(cell) or st.sim.blocks.has(cell):
			if kinds.has(c):
				return _no(0, name)
			continue
		floor_blocks.append({"c": cell, "kind": int(kinds.get(c, K.NORMAL))})
	var built := _build(ctx, cand, floor_blocks, final, cand.get("explicit", []))
	var win = built.win
	st.solves += 1
	var mover: bool = name != "respiro" and (IDEAS[name].grab or bool(cand.get("gate", false)))
	var plain: bool = name != "respiro" and not mover   # (las ideas que no empujan se resuelven sin empujar ni tirar: el espacio de búsqueda es mucho más chico)
	var preset: bool = cand.has("solution")   # (el taller ya trae su camino: lo calculó el solucionador sobre la arena sola)
	var reja: bool = cand.get("scramble", false) or preset
	var solved: Dictionary
	if preset:
		var chk = win.clone()
		var ci := 0
		var fail_msg := ""
		for a in cand.solution:
			var rr: Dictionary = chk.try_action(a.dir, a.mode)
			if not rr.ok:
				fail_msg = "%s %s: %s" % [str(a.dir), str(a.mode), str(rr.get("msg", ""))]
				break
			ci += 1
		if not _on_goal_ids(chk, win):
			if OS.get_environment("IDEA_LOG") != "":
				print("     el camino del taller no llega en la ventana: falla en %d de %d (%s), jugador %s, meta y %d, llegada %s, piso %s" % [ci, cand.solution.size(), fail_msg, str(chk.player), win.goal_y, str(ctx.arrival), str(fp.keys())])
			if OS.get_environment("IDEA_LOG") != "" and cand.has("mini"):
				var m = cand.mini
				print("      mini: entorno %d bloques, arena %d celdas, llegada %s, pilar %s, ey %d" % [m[5].size(), m[0].size(), str(m[1]), str(m[2]), ey])
				var mm = _taller_mini(m[0], m[1], m[2], m[3], m[4], m[5])
				var ww = win.clone()
				var di := 0
				for a in cand.solution:
					var r1: Dictionary = mm.try_action(a.dir, a.mode)
					var r2: Dictionary = ww.try_action(a.dir, a.mode)
					if r1.ok != r2.ok or mm.player != ww.player - Vector3i(0, ey - 1, 0):
						print("      diverge en %d (%s %s): mini ok=%s jugador %s msg %s | ventana ok=%s jugador %s msg %s" % [di, str(a.dir), str(a.mode), str(r1.ok), str(mm.player), str(r1.get("msg", "")), str(r2.ok), str(ww.player), str(r2.get("msg", ""))])
						for yy in range(-1, 3):
							for zz in 8:
								var row1 := ""
								var row2 := ""
								for xx in 8:
									var cc := Vector3i(xx, yy, zz)
									var cw := Vector3i(xx, yy + ey - 1, zz)
									row1 += ("H" if mm.kind_at(cc) == K.HEAVY else "n") if mm.blocks.has(cc) else "."
									row2 += ("H" if ww.kind_at(cw) == K.HEAVY else "n") if ww.blocks.has(cw) else "."
								print("        capa %d z%d mini %s  ventana %s" % [yy, zz, row1, row2])
						break
					di += 1
				print("      final: mini %s (goal en mini? %s), ventana %s, ey=%d" % [str(mm.player), str(mm.blocks.get(mm.player + Vector3i.DOWN, -2) in mm.goal_ids), str(ww.player), ey])
			if OS.get_environment("IDEA_LOG") != "" and false:
				for yy in range(0, 4):
					print("      capa %d:" % yy)
					for zz in 8:
						var row := ""
						for xx in 8:
							var cc := Vector3i(xx, yy, zz)
							row += ("F" if win.fixed.has(cc) else ("H" if win.kind_at(cc) == K.HEAVY else "n")) if win.blocks.has(cc) else "."
						print("        " + row)
			return _no(20, name)
		solved = {"status": "solved", "moves": cand.solution.size(), "path": cand.solution, "states": 1}
	elif reja:   # la solución es el desorden al revés (no hace falta que el solucionador la encuentre)
		ctx["final"] = final
		var sc := _scramble(ctx, cand, win, built.blocks)
		if sc.is_empty():
			return _no(17, name)
		built = _build(ctx, cand, floor_blocks, final, sc.blocks)
		win = built.win
		solved = {"status": "solved", "moves": sc.path.size(), "path": sc.path, "states": sc.states}
		# ¿qué tan difícil es de verdad? El solucionador (con tope) la resuelve o no: lo que le cuesta (estados) es lo que cuesta encontrar el camino entre muchos tentadores.
		# Si no llega a resolverla en el tope, queda la solución del desorden (válida): es lo más difícil.
		var opt: Dictionary = Solver.solve(win, ey + h, {"max_states": REJA_SOLVER_STATES, "goal_ids": win.goal_ids})
		var min_effort := int(2000.0 + 12000.0 * ctx.d)
		var min_moves := REJA_MIN_MOVES
		if cand.get("taller", false):   # (los acertijos de cajas son chicos: el solucionador los resuelve; lo que pido es que el camino más corto sea largo)
			min_effort = 0
			min_moves = 8 + int(ctx.d * 9.0)
		if OS.get_environment("REJA_STATES") != "":
			min_effort = int(OS.get_environment("REJA_STATES"))
		var effort: int = opt.states
		if OS.get_environment("IDEA_LOG") != "":
			print("     reja medida: solucionador %s en %d mov (%d estados); desorden %d mov" % [opt.status, opt.moves, opt.states, sc.path.size()])
		if opt.status == "solved":
			if opt.moves < min_moves:
				if OS.get_environment("IDEA_LOG") != "":
					print("     reja fácil: el solucionador la resuelve en %d" % opt.moves)
				return _no(18, name)
			solved = {"status": "solved", "moves": opt.moves, "path": opt.path, "states": opt.states}
		if solved.path.size() > REJA_MAX_MOVES:
			if OS.get_environment("IDEA_LOG") != "":
				print("     reja larga: %d movimientos" % solved.path.size())
			return _no(19, name)
		if effort < min_effort:
			if OS.get_environment("IDEA_LOG") != "":
				print("     reja fácil: el solucionador la resuelve con %d estados (pide %d)" % [effort, min_effort])
			return _no(18, name)
	else:
		solved = Solver.solve(win, ey + h, {"max_states": STATES, "goal_ids": win.goal_ids, "no_grab": plain})
	if solved.status != "solved":
		_dump(ctx, cand, fp, "no se resuelve: %s (%d estados)" % [solved.status, solved.states], win)
		return _no(1, name)
	if cand.has("bomb"):   # la cuenta se fija con lo que tarda el camino más corto
		var ticks := _floor_ticks(win, solved.path, ey, cand.bomb)
		if ticks < 4:
			return _no(2, name)
		cand.cols[cand.bomb].timer = ticks + int(cand.slack)
		built = _build(ctx, cand, floor_blocks, final)
		win = built.win
		solved = Solver.solve(win, ey + h, {"max_states": STATES, "goal_ids": win.goal_ids, "no_grab": plain})
		if solved.status != "solved":
			return _no(2, name)
	if not reja and (solved.moves < lo or solved.moves > hi):
		if OS.get_environment("IDEA_LOG") != "":
			print("     movimientos %d fuera de %d..%d (%s)" % [solved.moves, lo, hi, name])
		return _no(3, name)
	if mover and not reja and Solver.solve(win, ey + h, {"max_states": STATES, "goal_ids": win.goal_ids, "no_grab": true}).status == "solved":
		return _no(4, name)
	var grabs_needed := 0
	for a in solved.path:
		if a.mode == TowerLogic.Mode.GRAB:
			grabs_needed += 1
	if name != "respiro" and not plain and not reja and not cand.get("gate", false) and ctx.d > 0.3 and solved.states < int(ctx.d * ctx.strict * MIN_STATES):   # cuanto más difícil, más búsqueda tiene que costarle al solucionador (más caminos tentadores sin salida)
		return _no(15, name)
	if mover and not reja and grabs_needed < mini(ceili(ctx.d * ctx.strict * MIN_GRABS), 3 if name in ["muro_simple", "pared_pesada", "pared_pinchos"] else (1 if cand.get("gate", false) else 2)):   # cuanto más difícil, más bloques hay que mover
		return _no(16, name)
	if _uses_idea(name, win, solved.path, ey, cand) == 0:
		return _no(5, name)
	if not reja and _visible_fraction(win, solved.path, ey, h) < MIN_VISIBLE:
		return _no(6, name)
	if name != "respiro" and IDEAS[name].punish and ctx.d >= ERROR_FROM and _error_cost(win, solved.path, ey, h, rng) <= lerpf(0.0, 0.05, clampf((ctx.d - 0.2) * 2.5, 0.0, 1.0)):
		return _no(7, name)
	var grabs := 0
	for a in solved.path:
		if a.mode == TowerLogic.Mode.GRAB:
			grabs += 1
	if OS.get_environment("METRICS") != "":
		print("     métricas %s/%s: %d agarres, %d movimientos, %d estados, costo del error %.2f, visible %.2f" % [name, ctx.twist, grabs, solved.moves, solved.states, _error_cost(win, solved.path, ey, h, rng), _visible_fraction(win, solved.path, ey, h)])
	var blocks: Array = built.blocks
	# se agrega al estado y se comprueba que todo el camino (el anterior y el de la sala) siga llegando
	var tower = st.tower.clone()
	tower.row_platforms = tower.row_platforms.duplicate()
	tower.platform_row = tower.platform_row.duplicate()
	var sim = st.sim.clone()
	for f in floor_blocks:
		tower.add_block(f.c, false, f.kind, 0)
		sim.add_block(f.c, false, f.kind, 0)
	for b in blocks:
		tower.add_block(b.c, b.fixed, b.kind, b.timer)
		sim.add_block(b.c, b.fixed, b.kind, b.timer)
	var firm = sim.clone()   # nada de lo armado puede caerse solo
	firm.lazy_settle = false
	firm._blocks_dirty = true
	if firm._settle_blocks() or firm.blocks.size() != sim.blocks.size():
		return _no(8, name)
	var plat_id: int = tower.blocks[blocks[0].c]
	var per_row: Array[int] = []
	per_row.resize(h)
	per_row.fill(0)
	var reached := 0
	for a in solved.path:
		if not sim.try_action(a.dir, a.mode).ok or sim.lost:
			return _no(9, name)
		reached = maxi(reached, clampi(sim.player.y - ey - 1, 0, h - 1))
		per_row[reached] += 1
	if sim.player.y != ey + h or sim.blocks.get(sim.player + Vector3i.DOWN, -2) != plat_id:
		return _no(10, name)
	var chk = tower.clone()
	chk.goal_y = Gen.BIG
	var qi := 0
	for a in st.path:
		qi += 1
		if not chk.try_action(a.dir, a.mode).ok or chk.lost:
			if OS.get_environment("IDEA_LOG") != "":
				print("     replay falla en la acción %d de %d (%s), jugador %s" % [qi, st.path.size(), str(a), str(chk.player)])
			return _no(11, name)
	for a in solved.path:
		if not chk.try_action(a.dir, a.mode).ok or chk.lost:
			return _no(12, name)
	if chk.player != sim.player:
		return _no(13, name)
	tower.row_platforms[ey + h - 1] = [plat_id]
	tower.platform_row[plat_id] = ey + h - 1
	var walk = tower.clone()   # las celdas del camino quedan reservadas: nada de lo que sigue las puede tapar (ni cortar un salto)
	var added := {}
	for a in st.path:
		walk.try_action(a.dir, a.mode)
		for c in walk.trail:
			added[c] = true
			added[c + Vector3i(0, 1, 0)] = true
	for a in solved.path:
		walk.try_action(a.dir, a.mode)
		for c in walk.trail:
			added[c] = true
			added[c + Vector3i(0, 1, 0)] = true
	# la salida tiene que dejar lugar: la sala que sigue arranca desde ahí y necesita piso al lado
	var exits := 0
	var goal: Vector2i = cand.goal
	for d in DIRS4:
		var n: Vector2i = goal + d
		var cell := Vector3i(n.x, ey + h - 1, n.y)
		if _ok(n) and n.x >= 0 and not added.has(cell) and not st.reserved.has(cell) and not tower.blocks.has(cell):
			exits += 1
	if exits < (1 if (name == "respiro" or cand.get("taller", false)) else 2) and not final:
		return _no(14, name)
	for c in added:
		st.reserved[c] = true
	st.tower = tower
	st.sim = sim
	st.path.append_array(solved.path)
	st.states += solved.states
	for r in h:
		st.row_moves.append(per_row[r])
		st.shapes.append(name)
		st.infos.append({"featured": -1, "matters": true, "needs_grab": mover, "effort": solved.states, "kinds_n": 1})
	var score := 0.0   # qué tan exigente es esta sala (para quedarse con la mejor de varias válidas): búsqueda, agarres y lo que cuesta equivocarse
	if int(ctx.get("pick", 1)) > 1:
		score = log(float(solved.states) + 1.0) * 10.0 + float(grabs_needed) * 6.0 + (_error_cost(win, solved.path, ey, h, rng) * 40.0 if name != "respiro" else 0.0) + float(solved.moves) * 0.5
	return {"ok": true, "rows": h, "moves": solved.path.size(), "twist": ctx.twist, "score": score}


static func _why(msg: String) -> void:
	if OS.get_environment("IDEA_LOG") != "":
		print("     (desorden) " + msg)


## ¿El jugador quedó parado sobre el bloque meta de la ventana `win`?
static func _on_goal_ids(lg, win) -> bool:
	if lg.lost:
		return false
	var below: int = lg.blocks.get(lg.player + Vector3i.DOWN, -2)
	return win.goal_ids.has(below) and lg.player.y >= win.goal_y


static func _no(code: int, idea := "") -> Dictionary:
	if OS.get_environment("IDEA_LOG") != "":
		print("     rechazo %d %s" % [code, idea])
	return {"ok": false}


static func _fe(code: int) -> Dictionary:
	if OS.get_environment("IDEA_LOG") != "":
		print("     pisos ", code)
	return {}


static var dumps := 0


## (desarrollo) Dibuja un candidato: el piso y cada capa de la sala (. piso, i hielo, t trampa, n común, H pesado, ^ pinchos, x agrietado, B bomba, C catapulta, o llegada, G salida).
static func _dump(ctx: Dictionary, cand: Dictionary, fp: Dictionary, why: String, win = null) -> void:
	if OS.get_environment("DUMP") == "" or dumps >= int(OS.get_environment("DUMP")):
		return
	dumps += 1
	print("   ---- ", why, " ", cand.get("dbg", ""), " llegada ", ctx.arrival)
	var kinds: Dictionary = cand.get("floor_kinds", {})
	var reach := {}   # dónde puede estar parado el jugador sólo caminando y resbalando (sin empujar)
	if win != null:
		var seen := {}
		var queue: Array = [win.clone()]
		var qi := 0
		while qi < queue.size() and qi < 400:
			var s0 = queue[qi]
			qi += 1
			reach[Vector2i(s0.player.x, s0.player.z)] = true
			for d in TowerLogic.DIRS:
				var n = s0.clone()
				if n.try_action(d, TowerLogic.Mode.MOVE).ok and not n.lost:
					var key := str(n.player) + str(n.hang_dir)
					if not seen.has(key):
						seen[key] = true
						queue.append(n)
	print("      suelo/capa0      capa1   capa2   capa3")
	for z in SIZE:
		var line := ""
		for layer in range(0, ctx.h):
			for x in SIZE:
				var c := Vector2i(x, z)
				var ch := " "
				if CORE.has_point(c):
					ch = "#"
				else:
					if layer == 0 and fp.has(c):
						ch = "."
						match int(kinds.get(c, K.NORMAL)):
							K.ICE:
								ch = ","
							K.TRAP:
								ch = "t"
						if reach.has(c):
							ch = "r"
					if cand.cols.has(c) and int(cand.cols[c].h) > layer:
						match int(cand.cols[c].kind):
							K.HEAVY:
								ch = "H"
							K.SPIKES:
								ch = "^"
							K.CRACKED:
								ch = "x"
							K.BOMB:
								ch = "B"
							K.CATAPULT:
								ch = "C"
							K.ICE:
								ch = "i"
							_:
								ch = "n"
					if layer == 0 and c == ctx.arrival:
						ch = "o"
					if c == cand.goal and layer == ctx.h - 1:
						ch = "G"
				line += ch
			line += "  "
		print("   ", line)


static func _ce(code: int) -> Dictionary:
	if OS.get_environment("IDEA_LOG") != "":
		print("     candidato descartado ", code)
	return {}
