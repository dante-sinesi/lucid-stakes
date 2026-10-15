extends SceneTree
## Barrido de etapas: genera torres de un escenario en varias etapas y muestra tiempo, ideas y cuántas salas cayeron en respiro.
const Rooms := preload("res://scripts/rooms.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
func _init() -> void:
	var scen := OS.get_environment("SCEN") if OS.get_environment("SCEN") != "" else "pesadilla"
	var seeds := int(OS.get_environment("SEEDS")) if OS.get_environment("SEEDS") != "" else 2
	var from := int(OS.get_environment("FROM")) if OS.get_environment("FROM") != "" else 1
	var to := int(OS.get_environment("TO")) if OS.get_environment("TO") != "" else 15
	var step := int(OS.get_environment("STEP")) if OS.get_environment("STEP") != "" else 2
	for stage in range(from, to + 1, step):
		for sd in seeds:
			var prof := Gen.profile_for_stage(stage, {}, Scenarios.get_scenario(scen))
			var t0 := Time.get_ticks_msec()
			var res: Dictionary = Rooms.generate_stage(100 * stage + sd, 25, prof.difficulty, {"pace": prof.pace, "scenario": prof.scenario})
			var ms := Time.get_ticks_msec() - t0
			if not res.ok:
				print("etapa %d semilla %d: FALLÓ (%s) %d ms" % [stage, sd, str(res.get("error", "")), ms])
				continue
			var names: Array = []
			var rests := 0
			for r in res.rooms:
				names.append(r.idea)
				if r.idea == "respiro":
					rests += 1
			print("etapa %d semilla %d: %.1f s, %d movimientos, N=%d, respiros %d, %s" % [stage, sd, ms / 1000.0, res.path.size(), res.collapse_every, rests, ", ".join(names)])
	quit()
