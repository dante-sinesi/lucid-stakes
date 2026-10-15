extends SceneTree
## Genera la torre de una semilla y etapa del juego y muestra sus salas y si el camino gana. Variables: SEED, STAGE, SCEN.
const Rooms := preload("res://scripts/rooms.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
func _init() -> void:
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 42633
	var stage := int(OS.get_environment("STAGE")) if OS.get_environment("STAGE") != "" else 10
	var scen := OS.get_environment("SCEN") if OS.get_environment("SCEN") != "" else "pesadilla"
	var prof := Gen.profile_for_stage(stage, {}, Scenarios.get_scenario(scen))
	var res: Dictionary = Rooms.generate_stage(seed_v, int(OS.get_environment("ROWS")) if OS.get_environment("ROWS") != "" else 25, prof.difficulty, {"pace": prof.pace, "scenario": prof.scenario})
	if not res.ok:
		print("falló: ", res.get("error", ""))
		quit()
		return
	var names: Array = []
	var lg = res.logic.clone()
	var grabs_in := {}
	for a in res.path:
		var room_i := 0
		for i in res.rooms.size():
			if lg.player.y >= int(res.rooms[i].ey):
				room_i = i
		if a.mode == TowerLogic.Mode.GRAB:
			grabs_in[room_i] = int(grabs_in.get(room_i, 0)) + 1
		lg.try_action(a.dir, a.mode)
	for i in res.rooms.size():
		var r = res.rooms[i]
		names.append("%s@%d(h%d,%d agarres)" % [r.idea, r.ey, int(r.h), int(grabs_in.get(i, 0))])
	print("semilla %d etapa %d d=%.2f ritmo %s: %d movimientos  %s" % [seed_v, stage, prof.difficulty, prof.pace, res.path.size(), ", ".join(names)])
	quit()
