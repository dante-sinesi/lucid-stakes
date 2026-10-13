extends SceneTree
## Genera torres completas como en el juego y comprueba que el camino guardado GANA sobre la torre tal cual sale (con su caída, sin rearmarla). Variables: STAGES ("3,7,11"), SEEDS, SCEN.
const Rooms := preload("res://scripts/rooms.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")


func _init() -> void:
	var scen := OS.get_environment("SCEN") if OS.get_environment("SCEN") != "" else "pesadilla"
	var seeds := int(OS.get_environment("SEEDS")) if OS.get_environment("SEEDS") != "" else 2
	var stages: Array = []
	for s in (OS.get_environment("STAGES") if OS.get_environment("STAGES") != "" else "3,7,11,15").split(","):
		stages.append(int(s))
	var bad := 0
	var total := 0
	for stage in stages:
		var prof := Gen.profile_for_stage(stage, {}, Scenarios.get_scenario(scen))
		for sd in seeds:
			var t0 := Time.get_ticks_msec()
			var res: Dictionary = Rooms.generate_stage(777 * stage + sd, 25, prof.difficulty, {"pace": prof.pace, "scenario": prof.scenario})
			var ms := Time.get_ticks_msec() - t0
			total += 1
			if not res.ok:
				bad += 1
				print("etapa %2d s%d: FALLÓ GENERAR (%s)  %.0f s" % [stage, sd, str(res.get("error", "")), ms / 1000.0])
				continue
			var lg = res.logic.clone()
			var fail := ""
			var grabs := 0
			var i := 0
			for a in res.path:
				if a.mode == TowerLogic.Mode.GRAB:
					grabs += 1
				var r: Dictionary = lg.try_action(a.dir, a.mode)
				i += 1
				if not r.ok or lg.lost:
					fail = "paso %d: %s" % [i, lg.lost_reason if lg.lost else str(r.get("msg", ""))]
					break
			if fail == "" and not lg.won:
				fail = "terminó sin ganar"
			var names: Array = []
			for r in res.rooms:
				names.append(str(r.idea))
			if fail != "":
				bad += 1
			print("etapa %2d s%d: %s  %d mov, %d agarres, N=%d primera=%d, %.0f s  [%s]" % [stage, sd, "OK " if fail == "" else "MAL (" + fail + ")", res.path.size(), grabs, lg.collapse_every if fail != "" else res.logic.collapse_every, res.logic.moves_to_collapse, ms / 1000.0, ",".join(names)])
	print("RESUMEN: %d torres, %d con problemas" % [total, bad])
	quit()
