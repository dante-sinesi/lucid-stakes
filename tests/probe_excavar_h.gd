extends SceneTree
## ¿Cuánto se parece el solucionador de producción (heurística con déficit, rápido) al exacto (admisible) sobre las salas que propone excavar? Tiempo, resueltas y pasos.
## Variables: LIB, SEEDS (3), NODES (600000), EVAL (40), MAXH (8).
const RoomLib := preload("res://scripts/room_lib.gd")
const Solver := preload("res://scripts/solver.gd")
const NativeSolver := preload("res://scripts/native_solver.gd")


func _env(name: String, def: float) -> float:
	return float(OS.get_environment(name)) if OS.get_environment(name) != "" else def


func _init() -> void:
	var lib := OS.get_environment("LIB") if OS.get_environment("LIB") != "" else "biblioteca_actualizada/biblioteca.jsonl"
	var rooms: Array = RoomLib.read_file(lib).rooms.filter(func(r): return r.h <= int(_env("MAXH", 8)) and r.h >= 5)
	rooms.sort_custom(func(a, b): return int(a.opt.get("grabs", 0)) > int(b.opt.get("grabs", 0)))
	var n := 0
	var same := 0
	var longer := 0
	var p_ok := 0
	var a_ok := 0
	var tp := 0
	var ta := 0
	var worst := 0
	for si in int(_env("SEEDS", 3)):
		var par: Dictionary = rooms[si * 2]
		var t = RoomLib.build_state(par)
		var ex := NativeSolver.excavate(t, Vector2i(par.entry.x, par.entry.y), par.exit, RoomLib.path_string(par.path), int(_env("NODES", 600000)), 60)
		for cd in ex.cands.slice(0, int(_env("EVAL", 40))):
			var room := RoomLib.room_from_layout(par, cd.blocks)
			if RoomLib.validate_structure(room) != "":
				continue
			var t2 = RoomLib.build_state(room)
			var a0 := Time.get_ticks_usec()
			var p: Dictionary = Solver.solve(t2.clone(), room.h + 1, {"max_states": 400000, "goal_ids": t2.goal_ids})
			var a1 := Time.get_ticks_usec()
			var a: Dictionary = Solver.solve(t2.clone(), room.h + 1, {"max_states": 1500000, "goal_ids": t2.goal_ids, "admissible": true})
			var a2 := Time.get_ticks_usec()
			n += 1
			tp += a1 - a0
			ta += a2 - a1
			if p.status == "solved":
				p_ok += 1
			if a.status == "solved":
				a_ok += 1
			if p.status == "solved" and a.status == "solved":
				if p.moves == a.moves:
					same += 1
				else:
					longer += 1
					worst = maxi(worst, p.moves - a.moves)
			var eg := int(RoomLib.path_stats(room, a.path).grabs) if a.status == "solved" else -1
			print("tubo d=%d g=%d | exacto %s %d pasos %d agarres (%d est, %.1fs) | prod %s %d" % [cd.d, cd.g, a.status, a.moves, eg, a.states, (a2 - a1) / 1e6, p.status, p.moves])
	print("candidatas %d: producción resolvió %d en %.1f s, exacto resolvió %d en %.1f s; mismos pasos %d, más largo en producción %d (peor +%d)" % [n, p_ok, tp / 1e6, a_ok, ta / 1e6, same, longer, worst])
	quit(0)
