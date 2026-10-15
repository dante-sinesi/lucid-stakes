extends SceneTree
## ¿Se puede subir una torre entera sin empujar ni tirar de ningún bloque (sólo caminando, trepando y colgándose)? Si sí, hay un atajo. Variables: STAGE, SEEDS, FROM (primera semilla).
const Rooms := preload("res://scripts/rooms.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
const Solver := preload("res://scripts/solver.gd")
func _init() -> void:
	var stage := int(OS.get_environment("STAGE")) if OS.get_environment("STAGE") != "" else 10
	var seeds := int(OS.get_environment("SEEDS")) if OS.get_environment("SEEDS") != "" else 2
	var first := int(OS.get_environment("FROM")) if OS.get_environment("FROM") != "" else 75456
	var prof := Gen.profile_for_stage(stage, {}, Scenarios.get_scenario("pesadilla"))
	for k in seeds:
		var sd := first + k * 7919
		var res: Dictionary = Rooms.generate_stage(sd, 25, prof.difficulty, {"pace": prof.pace, "scenario": prof.scenario})
		if not res.ok:
			print("semilla %d: falló" % sd)
			continue
		var lg = res.logic.clone()
		var plain: Dictionary = Solver.solve(lg, lg.goal_y, {"max_states": 400000, "no_grab": true, "goal_ids": {lg.goal_block: true}})
		print("semilla %d: camino con %d movimientos | sin tocar bloques: %s (%d movimientos, %d estados)" % [sd, res.path.size(), plain.status, plain.moves, plain.states])
	quit()
