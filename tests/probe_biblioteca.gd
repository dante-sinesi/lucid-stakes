extends SceneTree
## (ROWS=filas fija las filas de la torre.) Torres armadas con la biblioteca: para cada etapa (STAGES, "1,5,10,15") y semilla (SEEDS, 2) muestra las salas que entraron y cuánto tardó. Variables: STAGES, SEEDS, SEED0.
const Rooms := preload("res://scripts/rooms.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const RunState := preload("res://scripts/run_state.gd")
const RoomPool := preload("res://scripts/room_pool.gd")


func _init() -> void:
	var stages: PackedStringArray = (OS.get_environment("STAGES") if OS.get_environment("STAGES") != "" else "1,5,10,15").split(",")
	var seeds := int(OS.get_environment("SEEDS")) if OS.get_environment("SEEDS") != "" else 2
	var seed0 := int(OS.get_environment("SEED0")) if OS.get_environment("SEED0") != "" else 1
	var t0 := Time.get_ticks_msec()
	print("biblioteca: %d salas (%d ms)" % [RoomPool.all().size(), Time.get_ticks_msec() - t0])
	var fails := 0
	for sg in stages:
		var stage := int(sg)
		var prof := Gen.profile_for_stage(stage)
		for k in seeds:
			var t1 := Time.get_ticks_msec()
			var res: Dictionary = Rooms.generate_stage(seed0 + k * 7919, (int(OS.get_environment("ROWS")) if OS.get_environment("ROWS") != "" else RunState.rows_for(stage)), prof.difficulty, {"pace": prof.pace, "combo": prof.combo, "bias": prof.bias, "scenario": ""})
			if not res.ok:
				fails += 1
				print("etapa %d semilla %d: FALLA %s" % [stage, k, str(res.get("error", ""))])
				continue
			var parts: Array = []
			for r in res.rooms:
				parts.append("%s%d" % [("L:" + str(r.twist).substr(0, 4)) if r.idea == "biblioteca" else str(r.idea), r.h])
			print("etapa %d (d=%.2f) semilla %d: filas %d, %d movs, %d ms · %s" % [stage, prof.difficulty, k, int(res.logic.goal_y), res.path.size(), Time.get_ticks_msec() - t1, " ".join(parts)])
	print("diagnóstico biblioteca: ", Rooms.lib_stats)
	print("fallos: ", fails)
	quit(1 if fails > 0 else 0)
