extends SceneTree
## Cuenta cuántos agarres (empujar/tirar) pide el camino de cada torre generada, por etapa.
const Rooms := preload("res://scripts/rooms.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
func _init() -> void:
	var scen := OS.get_environment("SCEN") if OS.get_environment("SCEN") != "" else "pesadilla"
	for stage in [2, 5, 8, 12, 15]:
		var prof := Gen.profile_for_stage(stage, {}, Scenarios.get_scenario(scen))
		for sd in 2:
			var res: Dictionary = Rooms.generate_stage(100 * stage + sd, 25, prof.difficulty, {"pace": prof.pace, "scenario": prof.scenario})
			if not res.ok:
				print("etapa %d: falló" % stage)
				continue
			var g := 0
			for a in res.path:
				if a.mode == 1:
					g += 1
			print("etapa %d (d=%.2f) semilla %d: %d agarres de %d movimientos" % [stage, prof.difficulty, sd, g, res.path.size()])
	quit()
