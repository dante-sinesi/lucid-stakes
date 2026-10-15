extends SceneTree
## Experimento "excavar": a partir de salas de la biblioteca, el solucionador nativo explora el grafo de estados cerca de la sala y propone la sala más difícil que se alcanza (distancia exacta); se repite desde la mejor.
## Variables: BEAM (3), EVAL (candidatos que se evalúan por sala, 30), LIB (biblioteca_actualizada/biblioteca.jsonl), SEEDS (6), SKIP (0), NODES (800000), TOPK (30), ITER (8), MINH (5), MAXH (20), SHAPE (todas), EXACT_CAP (3000000), OUT (archivo .jsonl donde se guardan las mejores).
const RoomLib := preload("res://scripts/room_lib.gd")
const Solver := preload("res://scripts/solver.gd")
const NativeSolver := preload("res://scripts/native_solver.gd")


func _env(name: String, def: float) -> float:
	return float(OS.get_environment(name)) if OS.get_environment(name) != "" else def


## La sala que corresponde a un candidato (mismas formas, otras columnas).
func _room_of(base: Dictionary, blocks: Array) -> Dictionary:
	var r := RoomLib.copy_room(base)
	r.cols = {}
	r.path = []
	r.opt = {}
	r.parent = str(base.get("id", ""))
	var by_col := {}
	for b in blocks:
		var c := Vector2i(b[0], b[2])
		if not by_col.has(c):
			by_col[c] = {}
		by_col[c][int(b[1])] = RoomLib.CHAR_OF_KIND.get(int(b[3]), "n")
	for c in by_col:
		var s := ""
		var y := 1
		while by_col[c].has(y):
			s += by_col[c][y]
			y += 1
		r.cols[c] = s
	return r


## Evalúa con el solucionador exacto. {} si no sirve.
func _score(room: Dictionary, cap: int) -> Dictionary:
	if RoomLib.validate_structure(room) != "":
		return {}
	var t = RoomLib.build_state(room)
	var res: Dictionary = Solver.solve(t.clone(), room.h + 1, {"max_states": cap, "goal_ids": t.goal_ids, "admissible": true, "max_ms": 25000})
	if res.status != "solved":
		return {}
	var plain: Dictionary = Solver.solve(t.clone(), room.h + 1, {"max_states": 60000, "goal_ids": t.goal_ids, "no_grab": true, "max_ms": 8000})
	if plain.status != "unsolvable":
		return {}
	var r := RoomLib.copy_room(room)
	RoomLib.apply_result(r, res.path, "exacta", int(res.moves), int(res.states))
	return r


func _better(a: Dictionary, b: Dictionary) -> bool:
	if int(a.opt.grabs) != int(b.opt.grabs):
		return int(a.opt.grabs) > int(b.opt.grabs)
	if int(a.opt.moved) != int(b.opt.moved):
		return int(a.opt.moved) > int(b.opt.moved)
	return int(a.opt.moves) > int(b.opt.moves)


func _init() -> void:
	var lib := OS.get_environment("LIB") if OS.get_environment("LIB") != "" else "biblioteca_actualizada/biblioteca.jsonl"
	var rooms: Array = RoomLib.read_file(lib).rooms
	var seeds := int(_env("SEEDS", 6))
	var skip := int(_env("SKIP", 0))
	var nodes := int(_env("NODES", 800000))
	var topk := int(_env("TOPK", 30))
	var iters := int(_env("ITER", 8))
	var beam_w := int(_env("BEAM", 3))
	var minh := int(_env("MINH", 5))
	var maxh := int(_env("MAXH", 20))
	var cap := int(_env("EXACT_CAP", 1500000))
	var patience := int(_env("PATIENCE", 3))
	var shape := OS.get_environment("SHAPE")
	var out_path := OS.get_environment("OUT")
	rooms = rooms.filter(func(r): return r.h >= minh and r.h <= maxh and (shape == "" or r.shape == shape))
	rooms.sort_custom(func(a, b): return float(a.opt.get("grabs", 0)) * 100.0 + float(a.opt.get("moves", 0)) > float(b.opt.get("grabs", 0)) * 100.0 + float(b.opt.get("moves", 0)))
	var best_overall := 0
	for si in seeds:
		if skip + si >= rooms.size():
			break
		var t0 := Time.get_ticks_msec()
		var first := _score(rooms[skip + si], cap)
		if first.is_empty():
			print("semilla %d (%s h%d): no se puede puntuar" % [si, rooms[skip + si].shape, rooms[skip + si].h])
			continue
		print("=== semilla %d: %s h%d, pasos %d, agarres %d, bloques movidos %d" % [si, first.shape, first.h, first.opt.moves, first.opt.grabs, first.opt.moved])
		var seen := {first.id: true}
		var beam: Array = [first]
		var champion: Dictionary = first
		var stale := 0
		for it in iters:
			var pool: Array = []
			var info := ""
			for cur in beam:
				var t = RoomLib.build_state(cur)
				var ex := NativeSolver.excavate(t, Vector2i(cur.entry.x, cur.entry.y), cur.exit, RoomLib.path_string(cur.path), nodes, topk)
				if ex.is_empty():
					continue
				var tried := 0
				for cd in ex.cands.slice(0, int(_env("EVAL", 30))):
					var room := _room_of(cur, cd.blocks)
					RoomLib.finalize(room)
					if seen.has(room.id):
						continue
					seen[room.id] = true
					tried += 1
					var sc := _score(room, cap)
					if sc.is_empty():
						continue
					sc.origin = "excavada"
					pool.append(sc)
					if out_path != "" and int(sc.opt.grabs) >= 6:
						RoomLib.append_line(out_path, sc)
				info += " [%d nodos %d ganadores %.1fs, %d evaluados]" % [ex.nodes, ex.wins, ex.ms / 1000.0, tried]
			if pool.is_empty():
				print("  iteración %d:%s sin candidatos" % [it, info])
				break
			pool.sort_custom(_better)
			var nb: Array = []
			var fams := {}
			for r in pool:
				if fams.has(r.family):
					continue
				fams[r.family] = true
				nb.append(r)
				if nb.size() >= beam_w:
					break
			beam = nb
			print("  iteración %d:%s mejores: %s" % [it, info, ", ".join(beam.map(func(r): return "%dg/%dp/%dm" % [r.opt.grabs, r.opt.moves, r.opt.moved]))])
			if _better(beam[0], champion):
				champion = beam[0]
				stale = 0
			else:
				stale += 1
				if stale >= patience:
					break
		best_overall = maxi(best_overall, int(champion.opt.grabs))
		print("  final: pasos %d, agarres %d, movidos %d, dificultad %.0f %% (%.1f s)" % [champion.opt.moves, champion.opt.grabs, champion.opt.moved, 100.0 * float(champion.opt.diff), (Time.get_ticks_msec() - t0) / 1000.0])
		print(RoomLib.ascii(champion))
	print("máximo de agarres: ", best_overall)
	quit(0)
