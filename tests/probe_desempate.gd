extends SceneTree
## ¿Cuántos agarres tiene el camino más corto según cómo se desempate? Compara el camino que devuelve el A* tal cual con el de menos agarres entre los más cortos (prefer_plain), sobre salas de una biblioteca.
## Variables: LIB, N (60), CAP (400000).
const RoomLib := preload("res://scripts/room_lib.gd")
const Solver := preload("res://scripts/solver.gd")


func _env(name: String, def: float) -> float:
	return float(OS.get_environment(name)) if OS.get_environment(name) != "" else def


func _init() -> void:
	var rooms: Array = RoomLib.read_file(OS.get_environment("LIB")).rooms
	var n := 0
	var diffs := {}
	var sum_a := 0
	var sum_b := 0
	var worst := 0
	for r in rooms:
		if n >= int(_env("N", 60)):
			break
		var t = RoomLib.build_state(r)
		var a: Dictionary = Solver.solve(t.clone(), r.h + 1, {"max_states": int(_env("CAP", 400000)), "goal_ids": t.goal_ids, "admissible": true})
		var b: Dictionary = Solver.solve(t.clone(), r.h + 1, {"max_states": int(_env("CAP", 400000)), "goal_ids": t.goal_ids, "admissible": true, "prefer_plain": true})
		if a.status != "solved" or b.status != "solved":
			continue
		n += 1
		var ga := int(RoomLib.path_stats(r, a.path).grabs)
		var gb := int(RoomLib.path_stats(r, b.path).grabs)
		if a.moves != b.moves:
			print("¡los pasos difieren! %d contra %d" % [a.moves, b.moves])
		diffs[ga - gb] = int(diffs.get(ga - gb, 0)) + 1
		sum_a += ga
		sum_b += gb
		worst = maxi(worst, ga - gb)
	print("salas %d: agarres medios %.2f (A* tal cual) contra %.2f (menos agarres); diferencia máxima %d; histograma de diferencias %s" % [n, float(sum_a) / maxf(n, 1), float(sum_b) / maxf(n, 1), worst, str(diffs)])
	quit(0)
