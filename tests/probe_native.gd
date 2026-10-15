extends SceneTree
## Salas de la biblioteca resueltas con el solucionador nativo y con el de GDScript: coinciden? cuánto más rápido? cuántas de las que GDScript deja en "limit" se resuelven con más presupuesto?
## Variables: PLAIN (1: prefer_plain), LIB (archivo .jsonl, biblioteca_actualizada/biblioteca.jsonl), N (30), SKIP (0), CAPG (estados de GDScript, 20000), CAPN (estados del nativo, 1500000), ADM (1: admisible).
const RoomLib := preload("res://scripts/room_lib.gd")
const Solver := preload("res://scripts/solver.gd")


func _env(name: String, def: float) -> float:
	return float(OS.get_environment(name)) if OS.get_environment(name) != "" else def


func _init() -> void:
	var lib := OS.get_environment("LIB") if OS.get_environment("LIB") != "" else "biblioteca_actualizada/biblioteca.jsonl"
	var rooms: Array = RoomLib.read_file(lib).rooms
	var n := int(_env("N", 30))
	var skip := int(_env("SKIP", 0))
	var capg := int(_env("CAPG", 20000))
	var capn := int(_env("CAPN", 1500000))
	var adm := _env("ADM", 1) > 0
	var same := 0
	var diff := 0
	var gd_limit := 0
	var solved_after := 0
	var tg := 0
	var tn := 0
	var sg := 0
	var sn := 0
	var done := 0
	var i := skip
	while done < n and i < rooms.size():
		var r: Dictionary = rooms[i]
		i += 1
		if r.h < 5 or (_env("HARD", 0) > 0 and str(r.opt.get("proof", "")) == "exacta"):
			continue
		done += 1
		var t = RoomLib.build_state(r)
		var o := {"goal_ids": t.goal_ids, "admissible": adm, "prefer_plain": _env("PLAIN", 0) > 0}
		var a0 := Time.get_ticks_usec()
		var g: Dictionary = Solver.solve(t.clone(), r.h + 1, o.merged({"max_states": capg, "native": false}))
		var a1 := Time.get_ticks_usec()
		if g.status == "limit":
			gd_limit += 1
			var m: Dictionary = Solver.solve(t.clone(), r.h + 1, o.merged({"max_states": capn}))
			var a2 := Time.get_ticks_usec()
			var grabs := 0
			if m.status == "solved":
				solved_after += 1
				grabs = int(RoomLib.path_stats(r, m.path).grabs)
			print("limit en GDScript (%d estados) -> nativo %s moves=%d grabs=%d estados=%d en %.1f s (%s h%d, mejor conocido %s)" % [g.states, m.status, m.moves, grabs, m.states, (a2 - a1) / 1e6, r.get("id", ""), r.h, str(r.opt.get("moves", "?"))])
			continue
		var m2: Dictionary = Solver.solve(t.clone(), r.h + 1, o.merged({"max_states": capg, "native": true}))
		var a3 := Time.get_ticks_usec()
		tg += a1 - a0
		tn += a3 - a1
		sg += int(g.states)
		sn += int(m2.states)
		if g.status == m2.status and g.moves == m2.moves:
			same += 1
		else:
			diff += 1
			print("DIFERENCIA: GDScript %s %d (%d estados), nativo %s %d (%d estados) en %s" % [g.status, g.moves, g.states, m2.status, m2.moves, m2.states, r.get("id", "")])
	print("iguales %d, distintas %d; GDScript %.1f s (%d estados) contra nativo %.1f s (%d estados); en límite para GDScript: %d, de ellas resueltas con el nativo: %d" % [same, diff, tg / 1e6, sg, tn / 1e6, sn, gd_limit, solved_after])
	quit(0)
