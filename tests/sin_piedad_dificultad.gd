extends SceneTree
## Qué tan difícil es "Sin piedad" según qué tan seguido se equivoca el jugador: con las salas de cada torre del banco (bibliotecas/torres_salas, armado con tests/bot_banco.gd) y una probabilidad `q` de movimiento en falso por paso,
## la probabilidad de superar una sala es P(falsos <= permitidos) (binomial sobre los pasos del camino más corto de la sala) y la de superar la torre es el producto por sala.
## Con las vidas del run se calcula además cuántos runs completarían las 15 torres (sólo por los falsos: sin la economía, el peaje ni las demás muertes).
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/sin_piedad_dificultad.gd -- [BANCO] [PERMITIDOS=2] [VIDAS=3]
const Bot := preload("res://scripts/bot.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")

const RATES := [0.005, 0.01, 0.02, 0.04, 0.08]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "bibliotecas/torres_salas"
	var allowed := int(args[1]) if args.size() > 1 else 2
	var lives := int(args[2]) if args.size() > 2 else 3
	var bank := Bot.load_bank(dir)
	var total := 0
	for s in bank:
		total += bank[s].size()
	print("banco %s: %d torres" % [dir, total])
	# pasos de cada sala (camino guardado de la torre)
	var per_stage := {}   # etapa -> [ [pasos de cada sala de cada torre] ]
	for s in bank:
		per_stage[s] = []
		for entry in bank[s]:
			var rooms: Array = entry.get("rooms", [])
			if rooms.is_empty():
				continue
			var lg = TowerLogic.from_dict(entry.tower)
			var steps := []
			steps.resize(rooms.size())
			steps.fill(0)
			for a in entry.path:
				var idx := Bot._room_of(rooms, lg.player.y)
				steps[idx] += 1
				lg.try_action(a.dir, a.mode)
			per_stage[s].append(steps)
	print("salas por torre: media %.1f · pasos por sala: media %.1f" % [_mean_rooms(per_stage), _mean_steps(per_stage)])
	for q in RATES:
		var surv := {}   # etapa -> probabilidad media de superar la torre
		for s in per_stage:
			var acc := 0.0
			for steps in per_stage[s]:
				var p := 1.0
				for n in steps:
					p *= _p_ok(int(n), q, allowed)
				acc += p
			surv[s] = acc / float(maxi(per_stage[s].size(), 1))
		var line := "q=%.3f (un paso en falso cada %d): superar la torre:" % [q, int(round(1.0 / q))]
		for s in [1, 3, 5, 8, 11, 15]:
			if surv.has(s):
				line += "  etapa %d: %3.0f %%" % [s, 100.0 * surv[s]]
		print(line)
		# runs que completan las 15 torres con `lives` reintentos (4ª muerte termina el run): suma de geométricas por etapa
		var dist := PackedFloat64Array()
		dist.resize(lives + 2)
		dist[0] = 1.0
		for s in range(1, 16):
			if not surv.has(s):
				continue
			var ps: float = clampf(surv[s], 0.0001, 1.0)
			var nxt := PackedFloat64Array()
			nxt.resize(dist.size())
			for d in dist.size():
				for k in range(0, dist.size() - d):
					nxt[d + k] += dist[d] * pow(1.0 - ps, k) * ps   # k muertes antes de superarla
			dist = nxt
		var win := 0.0
		for d in range(0, lives + 1):
			win += dist[d]
		var exp_deaths := 0.0
		for s in surv:
			exp_deaths += (1.0 - surv[s]) / maxf(surv[s], 0.0001)
		print("      muertes esperadas por falsos en un run de 15 torres: %.1f · runs que llegan al final con %d reintentos: %.1f %%" % [exp_deaths, lives, 100.0 * win])
	quit(0)


## Probabilidad de cometer a lo sumo `allowed` falsos en `n` pasos si cada uno es falso con probabilidad q.
func _p_ok(n: int, q: float, allowed: int) -> float:
	var total := 0.0
	for k in range(0, allowed + 1):
		total += _binom(n, k) * pow(q, k) * pow(1.0 - q, n - k)
	return minf(total, 1.0)


func _binom(n: int, k: int) -> float:
	if k < 0 or k > n:
		return 0.0
	var r := 1.0
	for i in k:
		r *= float(n - i) / float(i + 1)
	return r


func _mean_rooms(per_stage: Dictionary) -> float:
	var n := 0
	var t := 0
	for s in per_stage:
		for steps in per_stage[s]:
			n += 1
			t += steps.size()
	return float(t) / float(maxi(n, 1))


func _mean_steps(per_stage: Dictionary) -> float:
	var n := 0
	var t := 0
	for s in per_stage:
		for steps in per_stage[s]:
			for v in steps:
				n += 1
				t += int(v)
	return float(t) / float(maxi(n, 1))
