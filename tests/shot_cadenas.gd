extends SceneTree
## Juega dentro del juego las salas que dejó tests/exp_cadenas.gd (SAVE=archivo.json) y saca capturas: al empezar, a mitad del camino más corto y al terminar.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/shot_cadenas.gd -- ARCHIVO.json PREFIJO [índices separados por coma]
const Rooms := preload("res://scripts/rooms.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const K := TowerLogic.Kind


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var data = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var prefix: String = args[1]
	var pick: Array = []
	if args.size() > 2:
		for t in args[2].split(","):
			pick.append(int(t))
	else:
		for i in data.size():
			pick.append(i)
	var main = load("res://scenes/main.tscn").instantiate()
	main.quit_game_override = true
	main.quick_portal = true
	main.test_mode = true
	main.tower_rows = 4   # (la torre del arranque, chica: no es lo que se mira)
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	main.in_menu = false
	paused = false
	main.main_menu.visible = false
	main.trial = {}
	main.stage_number = 4
	for idx in pick:
		var room: Dictionary = data[idx]
		var cols := {}
		for c in room.cols:
			cols[Vector2i(int(c[0]), int(c[1]))] = {"h": int(c[2]), "kind": K.NORMAL}
		var w := int(room.w)
		var d := int(room.d)
		var ph := int(room.ph)
		var cells: Array[Vector2i] = []
		for x in w:
			for z in d:
				cells.append(Vector2i(2 + x, 2 + z))
		var lg = Rooms._vert_mini(cells, Vector2i(1, 2), Vector2i(2 + w - 1, 2 + d - 1), ph, cols, [])
		var path: Array = []
		for a in room.path:
			path.append({"dir": Vector3i(int(a[0]), 0, int(a[1])), "mode": int(a[2])})
		main._cancel_jobs()
		main.generating = false
		main.stage_start = lg
		main.solution = path
		main.restart()
		main.hud_layer.visible = false
		main.dialogue.hide_box()
		main.banner.text = ""
		for i in 40:
			await process_frame
		main.zoom_view(0.4)
		for i in 10:
			await process_frame
		root.get_texture().get_image().save_png("%s_%d_a.png" % [prefix, idx])
		var n := 0
		var half: int = path.size() / 2
		for a in path:
			main.generating = false
			main._apply(a.dir, a.mode, true)
			var guard := 0
			while main.busy and guard < 600:
				await process_frame
				guard += 1
			n += 1
			if n == half:
				for i in 6:
					await process_frame
				root.get_texture().get_image().save_png("%s_%d_b.png" % [prefix, idx])
			if main.logic.lost:
				print("sala %d: PERDIÓ en el paso %d" % [idx, n])
				break
		for i in 10:
			await process_frame
		root.get_texture().get_image().save_png("%s_%d_c.png" % [prefix, idx])
		print("sala %d (%d bloques distintos, %d agarres, %d pasos): ganó=%s" % [idx, int(room.moved), int(room.grabs), path.size(), str(main.logic.won)])
	quit()
