extends SceneTree
## Cuánta claridad junta el camino óptimo de una torre generada (para fijar el peaje del duende).
const Rooms := preload("res://scripts/rooms.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
func _init() -> void:
	for stage in [1, 3, 5, 8, 11, 15]:
		var vals: Array = []
		for sd in 3:
			var prof := Gen.profile_for_stage(stage, {}, Scenarios.get_scenario("pesadilla"))
			var res: Dictionary = Rooms.generate_stage(50 * stage + sd, 25, prof.difficulty, {"pace": prof.pace, "scenario": "pesadilla"})
			if not res.ok:
				continue
			var lg = res.logic.clone()
			for a in res.path:
				lg.try_action(a.dir, a.mode)
			vals.append(lg.claridad)
		print("etapa %d: claridad del camino óptimo %s" % [stage, str(vals)])
	quit()
