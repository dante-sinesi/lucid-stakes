extends SceneTree
## Calidad de las salas reja: agarres, bloques distintos movidos y si el solucionador (con tope) encuentra un camino bastante más corto que el nuestro. Variables: D, SEEDS.
const Rooms := preload("res://scripts/rooms.gd")
const Solver := preload("res://scripts/solver.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")


func _init() -> void:
	OS.set_environment("IDEA_ONLY", "reja")
	OS.set_environment("NO_FALLBACK", "1")
	var d := float(OS.get_environment("D")) if OS.get_environment("D") != "" else 0.7
	var seeds := int(OS.get_environment("SEEDS")) if OS.get_environment("SEEDS") != "" else 6
	for sd in seeds:
		var res: Dictionary = Rooms.generate_stage(2000 + sd, 5, d, {"pace": "normal", "scenario": "pesadilla"})
		if not res.ok:
			print("s%d: falló" % sd)
			continue
		var lg = res.logic.clone()
		var grabs := 0
		var moved := {}
		for a in res.path:
			var before: Dictionary = lg.positions.duplicate() if a.mode == TowerLogic.Mode.GRAB else {}
			lg.try_action(a.dir, a.mode)
			if a.mode == TowerLogic.Mode.GRAB:
				grabs += 1
				for id in lg.positions:
					if before.get(id, lg.positions[id]) != lg.positions[id]:
						moved[id] = true
		var t0 := Time.get_ticks_msec()
		var sol: Dictionary = Solver.solve(res.logic.clone(), res.logic.goal_y, {"max_states": 40000, "goal_ids": {res.logic.goal_block: true}})
		var ms := Time.get_ticks_msec() - t0
		var short := "no la encontró (%d estados)" % sol.states if sol.status != "solved" else "halló %d movimientos (%d estados)" % [sol.moves, sol.states]
		print("s%d: nuestro %d mov, %d agarres, %d bloques distintos | solucionador: %s, %.1f s" % [sd, res.path.size(), grabs, moved.size(), short, ms / 1000.0])
	quit()
