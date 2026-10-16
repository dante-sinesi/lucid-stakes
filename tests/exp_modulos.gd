extends SceneTree
## Salas altas por módulos (scripts/room_modules.gd). Variables: N (6), H (10), SHAPE (3x8), SEED (1), TECH (lista separada por comas; por defecto todas), OUT (archivo .jsonl de pasos donde guardar lo generado).
const RoomModules := preload("res://scripts/room_modules.gd")
const StepLib := preload("res://scripts/step_lib.gd")


func _env(name: String, def: String) -> String:
	return OS.get_environment(name) if OS.get_environment(name) != "" else def


func _init() -> void:
	var n := int(_env("N", "6"))
	var h := int(_env("H", "10"))
	var shape := _env("SHAPE", "3x8")
	var techs: Array = _env("TECH", "").split(",", false) if _env("TECH", "") != "" else []
	var out: Array = []
	var fails := {}
	for i in n:
		var gen := RoomModules.new(int(_env("SEED", "1")) * 1000 + i)
		var t0 := Time.get_ticks_msec()
		var r := gen.build(shape, h, techs)
		var secs := (Time.get_ticks_msec() - t0) / 1000.0
		if r.is_empty():
			fails[gen.last_why] = int(fails.get(gen.last_why, 0)) + 1
			print("sala %d: no salió (%s) en %.0f s" % [i, gen.last_why, secs])
			continue
		print("sala %d: %s, camino %d pasos, %.0f s: %s" % [i, r.step.name, r.path.size(), secs, " | ".join(r.modules.map(func(m): return "%s %d pasos" % [m.kind, m.moves]))])
		out.append(r.step)
	if _env("OUT", "") != "" and not out.is_empty():
		StepLib.write_file(_env("OUT", ""), out)
	print("salieron %d de %d" % [out.size(), n])
	quit(0)
