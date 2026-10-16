extends SceneTree
## Torres armadas con la biblioteca: dificultad promedio de las salas de cada etapa y, con SHOT=carpeta/prefijo, una captura de la torre entera.
## Uso: GAME_SANDBOX=1 STAGES=1,8,15 [SHOT=capturas/torre] [ZOOM=2.0] godot --path . --rendering-driver opengl3 --resolution 1280x900 -s tests/shot_torres.gd
const Rooms := preload("res://scripts/rooms.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const RunState := preload("res://scripts/run_state.gd")
const RoomPool := preload("res://scripts/room_pool.gd")


func _init() -> void:
	var stages: PackedStringArray = (OS.get_environment("STAGES") if OS.get_environment("STAGES") != "" else "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15").split(",")
	var shot := OS.get_environment("SHOT")
	var by_id := {}
	for e in RoomPool.all():
		by_id[e.room.id] = e
	var main = null
	if shot != "":
		main = load("res://scenes/main.tscn").instantiate()
		main.quit_game_override = true
		main.quick_portal = true
		main.test_mode = true
		root.add_child(main)
		await process_frame
		while main.generating or main.logic == null:
			await process_frame
		main.in_menu = false
		paused = false
		main.main_menu.visible = false
		main.hud_layer.visible = false
		main.dialogue.hide_box()
	for sg in stages:
		var stage := int(sg)
		var prof := Gen.profile_for_stage(stage)
		var res: Dictionary = Rooms.generate_stage(100 + stage, RunState.rows_for(stage), prof.difficulty, {"pace": prof.pace, "combo": prof.combo, "bias": prof.bias, "scenario": ""})
		if not res.ok:
			print("etapa %d: no se generó" % stage)
			continue
		var diffs: Array = []
		var ratings: Array = []
		var others := 0
		var desc: Array = []
		for r in res.rooms:
			if r.idea == "biblioteca" and by_id.has(r.twist):
				var e: Dictionary = by_id[r.twist]
				diffs.append(float(e.room.opt.diff))
				ratings.append(float(e.rating))
				desc.append("%s %dp %d%%" % [e.room.shape, r.h, roundi(100.0 * float(e.room.opt.diff))])
			else:
				others += 1
				desc.append("%s %dp" % [r.idea, r.h])
		var avg := 0.0
		var avr := 0.0
		for v in diffs:
			avg += v / diffs.size()
		for v in ratings:
			avr += v / ratings.size()
		print("etapa %2d (d=%.2f, %d filas): %d salas de la biblioteca + %d de las de siempre · dificultad promedio %.0f %% · calificación %.2f · %s" % [stage, prof.difficulty, RunState.rows_for(stage), diffs.size(), others, 100.0 * avg, avr, " | ".join(desc)])
		if main != null:
			main.stage_number = stage
			main.stage_start = res.logic
			main.solution = res.path
			main.restart()
			main.hud_layer.visible = false
			main.banner.text = ""
			for i in 20:
				await process_frame
			var rows := RunState.rows_for(stage)
			main.cam.size = float(rows) * 1.25   # (la torre entera: se pasa por encima del tope del zoom del juego)
			main.pivot.position = Vector3(4.0, float(rows) * 0.5, 4.0)
			for i in 20:
				await process_frame
			root.get_texture().get_image().save_png("%s_%02d.png" % [shot, stage])
	quit(0)
