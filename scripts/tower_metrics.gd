extends RefCounted
## Métrica de desafío de una torre generada (con Rooms): qué tan exigente es de verdad, no sólo si se puede resolver. Todo se mide sobre el camino óptimo y sobre el resultado de
## equivocarse. Cada subpuntaje va de 0 a 1 contra una meta que sube con la dificultad `d`; `score` es el promedio ponderado (0 a 100).
##   movers   fracción de salas donde el camino tiene que empujar o tirar de algún bloque (meta 0,8)
##   grabs    agarres totales del camino (meta 4 + 12 d)
##   moved    bloques distintos que hay que mover (meta 3 + 7 d)
##   punish   costo medio de equivocarse, en movimientos de más (una acción alternativa en un paso del camino; sin salida = 12; meta 4)
##   pressure titubeos (ida y vuelta, 2 movimientos de más) que aguanta la torre antes de que la caída alcance al jugador (meta: 8 a dificultad 0, 2 a dificultad 1)
##   variety  ideas distintas / min(5, salas)
##   effort   búsqueda que le costó al solucionador, en escala logarítmica (meta 4000 × (0,3 + d) estados por sala)
## Ver docs/plan_generador.md.

const TowerLogic := preload("res://scripts/tower_logic.gd")
const Solver := preload("res://scripts/solver.gd")
const Abort := preload("res://scripts/gen_abort.gd")

const ROOM := 4
const PUNISH_SAMPLES := 24
const DEAD_COST := 12.0
const WEIGHTS := {"movers": 2.0, "grabs": 1.5, "moved": 1.0, "punish": 2.0, "pressure": 1.0, "variety": 1.0, "effort": 1.0}


## Fracción de veces que se gana el camino óptimo con la caída cada `n` movimientos si en lugares al azar se meten `k` titubeos (ir a un lado y volver: 2 movimientos de más).
static func survival(tower, path: Array, n: int, k: int, trials: int, rng: RandomNumberGenerator, grace := 2.0, window := 0) -> float:
	var wins := 0
	for _t in trials:
		if Abort.flag:
			return 0.0
		var lg = tower.clone()
		lg.track_purify = false   # (la claridad no cambia si se gana o no: es lo caro de cada acción)
		lg.collapse_every = n
		lg.moves_to_collapse = maxi(int(round(float(n) * grace)), 1)
		var at := {}
		for _i in k:
			at[rng.randi_range(0, (mini(window, path.size()) if window > 0 else path.size()) - 1)] = true
		var i := 0
		var fine := true
		for a in path:
			if Abort.flag and i % 32 == 0:
				return 0.0
			if at.has(i) and not lg.lost and not lg.won:
				for d in TowerLogic.DIRS:
					var probe = lg.clone()
					var before = probe.player
					if probe.try_action(d, TowerLogic.Mode.MOVE).ok and not probe.lost and probe.hang_dir == Vector3i.ZERO and probe.try_action(-d, TowerLogic.Mode.MOVE).ok and probe.player == before and not probe.lost:
						lg.try_action(d, TowerLogic.Mode.MOVE)
						lg.try_action(-d, TowerLogic.Mode.MOVE)
						break
			if lg.lost or not lg.try_action(a.dir, a.mode).ok:
				fine = false
				break
			i += 1
		if fine and lg.won and not lg.lost:
			wins += 1
	return float(wins) / float(trials)


## Cuántos "titubeos" aguanta la torre (con su ritmo de caída) antes de que la caída alcance al jugador: el mayor k que se gana al menos la mitad de las veces. Es lo que de verdad aprieta a una persona que piensa jugando.
static func tolerance(tower, path: Array, rng: RandomNumberGenerator) -> int:   # (usa la caída que trae la torre)
	var best := 0
	for k in range(1, 17):
		if survival(tower, path, tower.collapse_every, k, 6, rng, float(tower.moves_to_collapse) / float(maxi(tower.collapse_every, 1))) >= 0.5:
			best = k
		else:
			break
	return best


## El ritmo de caída más apretado (n, entre 2 y `n_max`) que todavía deja pasar `k` titubeos con probabilidad `need` (y el camino sin titubeos siempre); la primera caída tarda `grace` veces n.
static func tightest_n(tower, path: Array, n_max: int, k: int, need: float, rng: RandomNumberGenerator, grace := 2.0) -> int:
	var lo := 2
	var hi := n_max
	if survival(tower, path, hi, 0, 1, rng, grace) < 1.0:
		return n_max
	var front := maxi(15, path.size() / 4)   # titubeos metidos todos al principio (lo peor: arriba hay poco colchón): sale caro quedarse mucho en las primeras salas
	var trials := 8 if path.size() < 250 else 5   # (cada intento repasa todo el camino: en una torre larga son menos)
	while lo < hi:   # (con un n más grande se aguanta más: se busca por bisección)
		if Abort.flag:
			return n_max
		var mid := (lo + hi) / 2
		if survival(tower, path, mid, 0, 1, rng, grace) >= 1.0 and survival(tower, path, mid, k, trials, rng, grace) >= need and survival(tower, path, mid, front, trials, rng, grace, maxi(path.size() / 4, 20)) >= need:
			hi = mid
		else:
			lo = mid + 1
	return lo


## `res`: el resultado de Rooms.generate_stage. Devuelve {score, parts: {...}, grabs, moved, rooms, ...}.
static func measure(res: Dictionary, d: float, rng: RandomNumberGenerator) -> Dictionary:
	var path: Array = res.path
	var tower = res.logic
	var lg = tower.clone()
	var rooms: int = maxi((tower.goal_y - 1) / ROOM, 1)
	var grabs_in: Array[int] = []
	grabs_in.resize(rooms)
	grabs_in.fill(0)
	var grabs := 0
	var moved := {}
	var snaps: Array = []
	for a in path:
		snaps.append(lg.clone())
		var before := {}
		if a.mode == TowerLogic.Mode.GRAB:
			before = lg.positions.duplicate()
		var room := clampi((lg.player.y - 1) / ROOM, 0, rooms - 1)
		lg.try_action(a.dir, a.mode)
		if a.mode == TowerLogic.Mode.GRAB:
			grabs += 1
			grabs_in[room] += 1
			for id in lg.positions:
				if before.get(id, lg.positions[id]) != lg.positions[id]:
					moved[id] = true
	var rooms_with := 0
	for g in grabs_in:
		if g > 0:
			rooms_with += 1
	# equivocarse: una acción alternativa en pasos repartidos del camino; se cuenta cuántas dejan la torre sin salida
	var tested := 0
	var dead := 0
	var cost_sum := 0.0   # lo que cuesta equivocarse, en movimientos de más (una equivocación sin salida vale DEAD_COST)
	var steps := mini(PUNISH_SAMPLES, snaps.size())
	for i in steps:
		var k := (i * snaps.size()) / steps
		var base = snaps[k]
		var good: Dictionary = path[k]
		var target_k := mini(base.player.y + ROOM, tower.goal_y)
		var ref: Dictionary = Solver.solve(base, target_k, {"max_states": 4000})
		var alts: Array = []
		for di in TowerLogic.DIRS.size():
			for mode in [TowerLogic.Mode.MOVE, TowerLogic.Mode.GRAB]:
				if not (TowerLogic.DIRS[di] == good.dir and mode == good.mode):
					alts.append([TowerLogic.DIRS[di], mode])
		for _j in mini(5, alts.size()):
			var alt: Array = alts.pop_at(rng.randi_range(0, alts.size() - 1))
			var n = base.clone()
			if not n.try_action(alt[0], alt[1]).ok:
				continue
			tested += 1
			if n.lost:
				dead += 1
				cost_sum += DEAD_COST
			else:
				var after: Dictionary = Solver.solve(n, target_k, {"max_states": 4000})
				if after.status == "unsolvable":
					dead += 1
					cost_sum += DEAD_COST
				elif after.status == "solved" and ref.status == "solved":
					cost_sum += clampf(float(after.moves + 1 - ref.moves), 0.0, DEAD_COST)
	var punish := cost_sum / float(maxi(tested, 1))   # costo medio de una equivocación, en movimientos
	var ideas := {}
	var order: Array = res.get("rooms", [])
	for r in order:
		if r.idea != "respiro":
			ideas[r.idea] = true
	var tol := tolerance(tower, path, rng)
	var effort := float(res.get("states", 1)) / float(rooms)
	var parts := {
		"movers": clampf(float(rooms_with) / float(rooms) / 0.8, 0.0, 1.0),
		"grabs": clampf(float(grabs) / (4.0 + 12.0 * d), 0.0, 1.0),
		"moved": clampf(float(moved.size()) / (3.0 + 7.0 * d), 0.0, 1.0),
		"punish": clampf(punish / 4.0, 0.0, 1.0),
		"pressure": clampf(lerpf(12.0, 4.0, d) / maxf(float(tol), 1.0), 0.0, 1.0),
		"variety": clampf(float(ideas.size()) / float(mini(5, rooms)), 0.0, 1.0),
		"effort": clampf(log(maxf(effort, 1.0)) / log(4000.0 * (0.3 + d)), 0.0, 1.0),
	}
	var total := 0.0
	var wsum := 0.0
	for k in parts:
		total += parts[k] * WEIGHTS[k]
		wsum += WEIGHTS[k]
	return {"score": 100.0 * total / wsum, "parts": parts, "grabs": grabs, "moved": moved.size(), "rooms_with": rooms_with, "rooms": rooms, "punish": punish,
			"tolerance": tol, "tested": tested, "grabs_in": grabs_in, "moves": path.size()}
