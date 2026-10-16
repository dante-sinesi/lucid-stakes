extends SceneTree
## Salas por módulos + excavación: arma una sala con todas las técnicas y le sube la dificultad excavando. Variables: N (4), H (7), SHAPE (3x8), SEED (1), ROUNDS (6), TR (transporte: razón mínima), OUT.
const RoomModules := preload("res://scripts/room_modules.gd")
const StepExcavator := preload("res://scripts/step_excavator.gd")
const StepLib := preload("res://scripts/step_lib.gd")
const RoomLib := preload("res://scripts/room_lib.gd")


func _env(name: String, def: String) -> String:
	return OS.get_environment(name) if OS.get_environment(name) != "" else def


func _init() -> void:
	var n := int(_env("N", "4"))
	var shape := _env("SHAPE", "3x8")
	var out: Array = []
	var arena: Array = RoomLib.shape_info(shape).cells
	for i in n:
		var gen := RoomModules.new(int(_env("SEED", "1")) * 1000 + i)
		gen.transport_min_ratio = float(_env("TR", "0.0"))
		var r := gen.build(shape, int(_env("H", "7")), [])
		if r.is_empty():
			print("sala %d: no salió (%s)" % [i, gen.last_why])
			continue
		var ex := StepExcavator.new(i)
		var t0 := Time.get_ticks_msec()
		var res := ex.improve(r.step, arena, int(_env("ROUNDS", "6")))
		var ev: Dictionary = res.ev
		var kinds := " ".join(r.modules.map(func(m): return str(m.kind)))
		print("sala %d [%s]: %s -> %s (%d rondas, %.0f s)" % [i, kinds, "?" , StepLib.describe(ev), res.rounds, (Time.get_ticks_msec() - t0) / 1000.0])
		for l in ex.log:
			print("   ", l)
		res.step.name = "Torre %s (excavada)" % shape
		out.append(res.step)
	if _env("OUT", "") != "" and not out.is_empty():
		StepLib.write_file(_env("OUT", ""), out)
	quit(0)
