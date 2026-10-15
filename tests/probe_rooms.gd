extends SceneTree
const Rooms := preload("res://scripts/rooms.gd")
const Gen := preload("res://scripts/tower_gen.gd")
func _init() -> void:
	var d := float(OS.get_environment("D")) if OS.get_environment("D") != "" else 0.5
	var rows := int(OS.get_environment("ROWS")) if OS.get_environment("ROWS") != "" else 25
	var sd := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1
	var t0 := Time.get_ticks_msec()
	var res: Dictionary = Rooms.generate_stage(sd, rows, d, {"pace": "normal", "scenario": OS.get_environment("SCEN")})
	print("ok=%s %.1f s" % [str(res.get("ok")), (Time.get_ticks_msec() - t0) / 1000.0])
	if res.ok:
		print("salas ", res.rooms, " filas ", res.rows, " N=", res.collapse_every, " camino ", res.path.size())
		print("gana: ", Gen._replay_wins(res.logic, res.path, res.collapse_every))
	else:
		print(res)
	quit()
