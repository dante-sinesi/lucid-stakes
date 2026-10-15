extends SceneTree
## Velocidad y alcance del solucionador nativo sobre salas al azar (densas, con hielo, pesados y agrietados): cuántas se resuelven según el presupuesto, y cuántos estados por segundo.
## Variables: N (40), SEED (3), CAP (2000000), H (alto, 7), ADM (0/1), GDS (1: también corre GDScript con tope GCAP, 20000, para comparar).
const RoomLib := preload("res://scripts/room_lib.gd")
const Solver := preload("res://scripts/solver.gd")


func _env(name: String, def: float) -> float:
	return float(OS.get_environment(name)) if OS.get_environment(name) != "" else def


func _init() -> void:
	var n := int(_env("N", 40))
	var cap := int(_env("CAP", 2000000))
	var h := int(_env("H", 7))
	var adm := _env("ADM", 0) > 0
	var gds := _env("GDS", 1) > 0
	var gcap := int(_env("GCAP", 20000))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_env("SEED", 3))
	var shapes := ["3x5", "3x8", "L", "U"]
	var solved := 0
	var limit := 0
	var unsolv := 0
	var total_states := 0
	var total_us := 0
	var diffs := 0
	var best_grabs := 0
	for i in n:
		var sh: String = shapes[i % shapes.size()]
		var r := RoomLib.make_room(sh, h)
		var dens := 0.4 + 0.4 * rng.randf()
		for c in RoomLib.free_cells(sh):
			var hh := rng.randi_range(0, h - 1)
			if hh > 0 and rng.randf() < dens:
				r.cols[c] = "n".repeat(hh)
		var t = RoomLib.build_state(r)
		var o := {"goal_ids": t.goal_ids, "admissible": adm, "max_states": cap}
		var a0 := Time.get_ticks_usec()
		var m: Dictionary = Solver.solve(t.clone(), h + 1, o)
		var us := Time.get_ticks_usec() - a0
		total_states += int(m.states)
		total_us += us
		var extra := ""
		if m.status == "solved":
			solved += 1
			var g := int(RoomLib.path_stats(r, m.path).grabs)
			best_grabs = maxi(best_grabs, g)
			extra = " moves=%d grabs=%d" % [m.moves, g]
		elif m.status == "limit":
			limit += 1
		else:
			unsolv += 1
		if gds:
			var g2: Dictionary = Solver.solve(t.clone(), h + 1, {"goal_ids": t.goal_ids, "admissible": adm, "max_states": gcap, "native": false})
			if g2.status != "limit" and (g2.status != m.status or (m.status == "solved" and g2.moves != m.moves)):
				diffs += 1
				print("DIFERENCIA: GDScript %s %d, nativo %s %d" % [g2.status, g2.moves, m.status, m.moves])
		print("%s h%d: %s en %d estados, %.2f s%s" % [sh, h, m.status, m.states, us / 1e6, extra])
	print("resueltas %d, límite %d, sin solución %d; %d estados en %.1f s (%.0f por segundo); máximo de empujes %d; diferencias con GDScript %d" % [solved, limit, unsolv, total_states, total_us / 1e6, total_states / maxf(total_us / 1e6, 0.001), best_grabs, diffs])
	quit(0)
