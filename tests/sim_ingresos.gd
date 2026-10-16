extends SceneTree
## Cuánta claridad rinde una torre siguiendo su camino más corto (y cuántos movimientos tiene) en cada etapa: la base de la simulación de la economía (tests/sim_economia.gd).
## Variables: STAGES ("1,3,5,8,10,12,15"), SEEDS (2). Escribe una línea por torre: etapa, claridad, movimientos, bloques purificados.
const Rooms := preload("res://scripts/rooms.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const RunState := preload("res://scripts/run_state.gd")


func _init() -> void:
	var stages: PackedStringArray = (OS.get_environment("STAGES") if OS.get_environment("STAGES") != "" else "1,3,5,8,10,12,15").split(",")
	var seeds := int(OS.get_environment("SEEDS")) if OS.get_environment("SEEDS") != "" else 2
	for sg in stages:
		var stage := int(sg)
		var prof := Gen.profile_for_stage(stage)
		for k in seeds:
			var t0 := Time.get_ticks_msec()
			var res: Dictionary = Rooms.generate_stage(500 + stage * 31 + k * 7919, RunState.rows_for(stage), prof.difficulty, {"pace": prof.pace, "combo": prof.combo, "bias": prof.bias, "scenario": ""})
			if not res.ok:
				print("INGRESO etapa %d: no se generó" % stage)
				continue
			var lg = res.logic.clone()
			lg.track_purify = true
			for a in res.path:
				lg.try_action(a.dir, a.mode)
			print("INGRESO etapa=%d semilla=%d claridad=%d movimientos=%d purificados=%d filas=%d pisos=%d ms=%d" % [stage, k, lg.claridad, res.path.size(), lg.purified_count, RunState.rows_for(stage), int(res.logic.goal_y), Time.get_ticks_msec() - t0])
	quit(0)
