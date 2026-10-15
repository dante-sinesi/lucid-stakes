extends SceneTree
## ¿El modo "admisible" del solucionador da el camino MÁS CORTO? Se compara contra la búsqueda sin heurística (exacta por construcción) en salas al azar,
## y se cuenta cuántas veces el solucionador de producción (con la heurística de guía) devuelve un camino más largo que el mínimo.
## Variables: N (salas, 60), SEED (11), CAP (estados, 25000). Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_solver_exact.gd
const RoomLib := preload("res://scripts/room_lib.gd")
const Solver := preload("res://scripts/solver.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _env(name: String, def: float) -> float:
	return float(OS.get_environment(name)) if OS.get_environment(name) != "" else def


func _init() -> void:
	var n := int(_env("N", 100))
	var cap := int(_env("CAP", 15000))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_env("SEED", 11))
	var both := 0
	var prod_longer := 0
	var adm_diff := 0
	var states_adm := 0
	var states_ex := 0
	var worst := 0
	var shapes := ["3x3", "3x5"]
	for i in n:
		var sh: String = shapes[i % 2]
		var h := 4 + (i % 2)
		var r := RoomLib.make_room(sh, h)
		for c in RoomLib.free_cells(sh):
			var hh := rng.randi_range(0, h - 1)
			if hh > 0 and rng.randf() < 0.55:
				r.cols[c] = "h".repeat(hh) if rng.randf() < 0.08 else "n".repeat(hh)
		var t = RoomLib.build_state(r)
		var prod: Dictionary = Solver.solve(t.clone(), h + 1, {"max_states": 2500, "goal_ids": t.goal_ids})
		if prod.status != "solved":
			continue
		var adm: Dictionary = Solver.solve(t.clone(), h + 1, {"max_states": cap, "goal_ids": t.goal_ids, "admissible": true})
		if adm.status != "solved":
			continue
		var ex: Dictionary = Solver.solve(t.clone(), h + 1, {"max_states": mini(60000, 40 * int(adm.states) + 1000), "goal_ids": t.goal_ids, "heuristic": false})
		if adm.status != "solved" or ex.status != "solved":
			continue
		both += 1
		states_adm += adm.states
		states_ex += ex.states
		if adm.moves != ex.moves:
			adm_diff += 1
			print("DIFERENCIA admisible %d, exacto %d en %s" % [adm.moves, ex.moves, str(r.cols)])
		if prod.moves > ex.moves:
			prod_longer += 1
			worst = maxi(worst, prod.moves - ex.moves)
		check(prod.moves >= ex.moves, "el de producción nunca es más corto que el exacto (%d vs %d)" % [prod.moves, ex.moves])
		check(RoomLib.replay(r, adm.path).ok, "el camino del modo admisible resuelve la sala")
	print("%d salas resueltas por los tres. Admisible distinto del exacto: %d. Producción más largo que el mínimo: %d (peor +%d). Estados: admisible %d, exacto %d" % [both, adm_diff, prod_longer, worst, states_adm, states_ex])
	check(both >= 8, "hubo suficientes salas para comparar")
	check(adm_diff == 0, "el modo admisible da siempre el mínimo exacto")
	print("tests del solucionador exacto terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
