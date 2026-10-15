extends SceneTree
## Experimento: salas de ESCALONES SUELTOS (docs/minero_y_estudio.md, propuesta del 14/10). En lugar de columnas macizas, la sala es una rampa de bloques sueltos, uno por piso, cada uno un piso más arriba y
## pegado al anterior (el motor la sostiene por apoyo de arista): h - 1 bloques en total. Se la desordena con movimientos reales del juego que se pueden deshacer, hasta que no se pueda subir caminando, y la
## solución es el desorden al revés (verificada repitiéndola). Se mide cuántos empujes y tirones pide, cuántos pasos, la dificultad (empujes y tirones / pasos), cuántos bloques de la rampa hay que mover, el
## rendimiento y, en las chicas, el mínimo exacto para ver cuánto del camino plantado es de verdad necesario.
## Variables: N (intentos por configuración, 30), SEED (3), CONFIGS ("3x8:8,L:12,U:14,U:18"), GRABS ("6-30": rango de empujes que se busca), EXACT_H (hasta qué altura se calcula el mínimo exacto, 8).
const RoomLib := preload("res://scripts/room_lib.gd")
const RoomMiner := preload("res://scripts/room_miner.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const Solver := preload("res://scripts/solver.gd")

var rng := RandomNumberGenerator.new()
var miner


func _env(name: String, def: String) -> String:
	return OS.get_environment(name) if OS.get_environment(name) != "" else def


# --- la rampa ---------------------------------------------------------------------------------------------------------------

## La sala vacía de la forma y altura dadas con una rampa de bloques sueltos. {state, chain (celdas), room}. {} si la arena no tiene un camino tan largo.
func ramp_state(shape: String, h: int) -> Dictionary:
	var cols: Dictionary = miner.staircase(shape, h)   # (sólo se usa para el recorrido: la celda más alta pegada a la salida, después las demás)
	if cols.is_empty():
		return {}
	var cells: Array = cols.keys()
	cells.sort_custom(func(a, b): return String(cols[a]).length() > String(cols[b]).length())
	var room := RoomLib.make_room(shape, h)
	var t = RoomLib.build_state(room)
	for c in cells:
		var level: int = String(cols[c]).length()
		t.add_block(Vector3i(c.x, level, c.y), false)
	return {"state": t, "chain": cells, "room": room}


func replay(start, path: Array, h: int) -> bool:
	var t = start.clone()
	for a in path:
		if not t.try_action(a.dir, a.mode).ok or t.lost:
			return false
	return RoomLib.at_goal(t, h)


## Saca las vueltas (ciclos de estado) y los tramos caminando innecesarios, sobre un estado inicial cualquiera.
func simplify(start, path: Array, h: int) -> Array:
	var best: Array = path
	for _round in 3:
		var t = start.clone()
		var keys: Array = [Solver.state_key(t)]
		var seen := {keys[0]: 0}
		var out: Array = []
		var okp := true
		for a in best:
			if not t.try_action(a.dir, a.mode).ok or t.lost:
				okp = false
				break
			var k: Vector3i = Solver.state_key(t)
			if seen.has(k):
				var idx: int = seen[k]
				for i in range(idx + 1, keys.size()):
					seen.erase(keys[i])
				keys.resize(idx + 1)
				out.resize(idx)
			else:
				out.append(a)
				keys.append(k)
				seen[k] = out.size()
		if not okp:
			return best
		# tramos caminando
		var t2 = start.clone()
		var out2: Array = []
		var i2 := 0
		while i2 < out.size():
			if out[i2].mode != TowerLogic.Mode.MOVE:
				t2.try_action(out[i2].dir, out[i2].mode)
				out2.append(out[i2])
				i2 += 1
				continue
			var j := i2
			while j < out.size() and out[j].mode == TowerLogic.Mode.MOVE:
				j += 1
			var after = t2.clone()
			var okr := true
			for k2 in range(i2, j):
				if not after.try_action(out[k2].dir, out[k2].mode).ok or after.lost:
					okr = false
					break
			var run: Array = out.slice(i2, j)
			if okr and after.zob == t2.zob and after.hang_dir == Vector3i.ZERO and t2.hang_dir == Vector3i.ZERO:
				var w = RoomLib.walk_path(t2, after.player, 600)
				if w != null and w.size() < run.size():
					run = w
			for a in run:
				t2.try_action(a.dir, a.mode)
				out2.append(a)
			i2 = j
		if out2.size() >= best.size() or not replay(start, out2, h):
			break
		best = out2
	return best


func stats(start, path: Array) -> Dictionary:
	var t = start.clone()
	var moved := {}
	var grabs := 0
	for a in path:
		var before: Dictionary = {}
		if a.mode == TowerLogic.Mode.GRAB:
			before = t.positions.duplicate()
			grabs += 1
		t.try_action(a.dir, a.mode)
		if a.mode == TowerLogic.Mode.GRAB:
			for id in t.positions:
				if before.get(id, t.positions[id]) != t.positions[id]:
					moved[id] = true
	return {"grabs": grabs, "moved": moved.size(), "moves": path.size()}


# --- el desorden -------------------------------------------------------------------------------------------------------------

## Desordena el estado `base_start` (la rampa, resuelta caminando con `base_path`) con movimientos reversibles. Se busca llegar a `want_grabs` empujes o tirones y a una sala que no se pueda
## resolver caminando. {start (el estado final con el jugador en la llegada), path (la solución plantada)} o {} con el motivo en `why`.
var why := ""
var last_grabs := 0
var last_steps := 0
var stuck: Array = []


func scramble(base_start, base_path: Array, shape: String, h: int, want_grabs: int, max_steps: int) -> Dictionary:
	var info := RoomLib.shape_info(shape)
	var arena := {}
	for c in info.cells:
		arena[c] = true
	var sim = base_start.clone()
	var n_blocks: int = sim.blocks.size()
	var invs: Array = []
	var grabs := 0
	var recent: Array = [Solver.state_key(sim)]
	var entry_pos := Vector3i(info.entry.x, 1, info.entry.y)
	var blocked := false
	while invs.size() < max_steps:
		var opts: Array = []
		var weight := 0
		for d in TowerLogic.DIRS:
			for mode in [TowerLogic.Mode.MOVE, TowerLogic.Mode.GRAB]:
				var n = sim.clone()
				var r: Dictionary = n.try_action(d, mode)
				if not r.ok or n.lost or n.hang_dir != Vector3i.ZERO or n.blocks.size() != n_blocks:
					continue
				if mode == TowerLogic.Mode.MOVE and n.player == sim.player:
					continue
				if mode == TowerLogic.Mode.GRAB:   # (los bloques sueltos tienen que quedar sobre la arena)
					var inside := true
					for c in n.blocks:
						if c.y >= 1 and not n.fixed.has(c) and Vector2i(c.x, c.z) != info.exit and not arena.has(Vector2i(c.x, c.z)):
							inside = false
							break
					if not inside:
						continue
				var inv = miner._inverse(sim, n, d, mode)
				if inv == null:
					continue
				var key: Vector3i = Solver.state_key(n)
				var w := 6 if mode == TowerLogic.Mode.GRAB else 1
				opts.append([n, inv, mode, key, w, recent.has(key)])
		if opts.is_empty():
			break
		var fresh: Array = []
		for o in opts:
			if not o[5]:
				fresh.append(o)
		if not fresh.is_empty():
			opts = fresh
		var has_grab := false
		for o in opts:
			weight += int(o[4])
			if o[2] == TowerLogic.Mode.GRAB:
				has_grab = true
		if not has_grab and rng.randf() < 0.6:   # (sin nada que empujar: se camina hacia el bloque suelto más cercano)
			var near := _block_distance(sim)
			var closer: Array = []
			var w2 := 0
			for o in opts:
				if _block_distance(o[0]) < near:
					closer.append(o)
					w2 += int(o[4])
			if not closer.is_empty():
				opts = closer
				weight = w2
		var roll := rng.randi_range(0, weight - 1)
		var pick: Array = opts[0]
		for o in opts:
			roll -= int(o[4])
			if roll < 0:
				pick = o
				break
		sim = pick[0]
		invs.append(pick[1])
		recent.append(pick[3])
		if recent.size() > 3:
			recent.pop_front()
		if pick[2] == TowerLogic.Mode.GRAB:
			grabs += 1
		if grabs >= want_grabs and invs.size() % 2 == 0:
			var c2 = sim.clone()
			c2.player = entry_pos
			c2.hang_dir = Vector3i.ZERO
			var pl: Dictionary = Solver.solve(c2, h + 1, {"max_states": 3000, "goal_ids": c2.goal_ids, "no_grab": true, "max_ms": 3000})
			if pl.status == "unsolvable":
				blocked = true
				break
	if not blocked:
		why = "no_bloquea"
		last_grabs = grabs
		last_steps = invs.size()
		return {}
	var final_start = sim.clone()
	final_start.player = entry_pos
	final_start.hang_dir = Vector3i.ZERO
	var p1 = RoomLib.walk_path(final_start, sim.player)
	if p1 == null:
		why = "sin_camino_a_pie"
		return {}
	var path: Array = p1
	for i in range(invs.size() - 1, -1, -1):
		for a in invs[i]:
			path.append({"dir": a[0], "mode": a[1]})
	path.append_array(base_path)
	if not replay(final_start, path, h):
		why = "camino_roto"
		return {}
	return {"start": final_start, "path": path}


func _block_distance(sim) -> int:
	var best := 1000
	for c in sim.blocks:
		if c.y < 1 or sim.fixed.has(c) or sim.kind_at(c) == TowerLogic.Kind.HEAVY:
			continue
		best = mini(best, absi(c.x - sim.player.x) + absi(c.z - sim.player.z))
	return best


# --- la corrida ------------------------------------------------------------------------------------------------------------------

func _init() -> void:
	rng.seed = int(_env("SEED", "3"))
	miner = RoomMiner.new({"seed": rng.seed, "write": false})
	var n := int(_env("N", "30"))
	var exact_h := int(_env("EXACT_H", "8"))
	var rng_grabs: PackedStringArray = _env("GRABS", "6-30").split("-")
	var g_lo := int(rng_grabs[0])
	var g_hi := int(rng_grabs[1])
	var examples: Array = []
	print("forma  pisos | bloques | intentos válidos (%) | empujes y tirones: media / máx | pasos | dificultad media / máx | bloques de la rampa movidos | tiempo por sala válida")
	for cfg in _env("CONFIGS", "3x8:8,L:12,U:14,U:18").split(","):
		var parts := cfg.split(":")
		var shape: String = parts[0]
		var h := int(parts[1])
		var rs := ramp_state(shape, h)
		if rs.is_empty():
			print("%s %d: no hay rampa" % [shape, h])
			continue
		var base_start = rs.state
		var walk: Dictionary = Solver.solve(base_start.clone(), h + 1, {"max_states": 30000, "goal_ids": base_start.goal_ids, "no_grab": true, "max_ms": 10000})
		if walk.status != "solved":
			print("%s %d: la rampa no se sube caminando (%s)" % [shape, h, walk.status])
			continue
		var valid := 0
		var whys := {}
		var sum_g := 0.0
		var max_g := 0
		var sum_m := 0.0
		var sum_d := 0.0
		var max_d := 0.0
		var sum_moved := 0.0
		var exact_stats := []
		var t0 := Time.get_ticks_msec()
		for _i in n:
			why = ""
			var res := scramble(base_start, walk.path, shape, h, rng.randi_range(g_lo, g_hi), 400)
			if res.is_empty():
				whys[why] = int(whys.get(why, 0)) + 1
				if why == "no_bloquea":
					stuck.append("%d empujes en %d acciones" % [last_grabs, last_steps])
				continue
			var path := simplify(res.start, res.path, h)
			if not replay(res.start, path, h):
				whys["simplify_roto"] = int(whys.get("simplify_roto", 0)) + 1
				continue
			var st := stats(res.start, path)
			valid += 1
			sum_g += st.grabs
			max_g = maxi(max_g, st.grabs)
			sum_m += st.moves
			var d := float(st.grabs) / float(maxi(st.moves, 1))
			sum_d += d
			max_d = maxf(max_d, d)
			sum_moved += float(st.moved) / float(h - 1)
			if h <= exact_h and exact_stats.size() < 4:
				var ex: Dictionary = Solver.solve(res.start.clone(), h + 1, {"max_states": 60000, "goal_ids": res.start.goal_ids, "admissible": true, "max_ms": 20000})
				if ex.status == "solved":
					var sx := stats(res.start, ex.path)
					exact_stats.append("%d/%d -> exacto %d/%d" % [st.grabs, st.moves, sx.grabs, sx.moves])
			if examples.size() < 3 and st.grabs >= 8:
				examples.append({"shape": shape, "h": h, "grabs": st.grabs, "moves": st.moves, "start": res.start})
		var secs := (Time.get_ticks_msec() - t0) / 1000.0
		print("%-5s %2d | %3d | %2d de %d (%.0f %%) | %.1f / %d | %.0f | %.0f %% / %.0f %% | %.0f %% | %.1f s   %s %s" % [shape, h, h - 1, valid, n, 100.0 * valid / n, sum_g / maxi(valid, 1), max_g, sum_m / maxi(valid, 1), 100.0 * sum_d / maxi(valid, 1), 100.0 * max_d, 100.0 * sum_moved / maxi(valid, 1), secs / maxi(valid, 1), str(whys), str(exact_stats)])
	print("lo que llegó a hacer el desorden en los intentos fallidos (empujes o tirones reversibles en N acciones): ", str(stuck.slice(0, 12)))
	for e in examples:
		print("ejemplo: %s %d pisos: %d empujes o tirones de %d pasos" % [e.shape, e.h, e.grabs, e.moves])
	quit()
