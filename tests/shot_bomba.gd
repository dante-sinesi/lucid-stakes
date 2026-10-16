extends SceneTree
## Captura de una bomba con su zona: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1000x800 -s tests/shot_bomba.gd -- SALIDA.png
const TowerLogic := preload("res://scripts/tower_logic.gd")


func _init() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "capturas/bomba.png"
	var t = TowerLogic.new()
	t.size = Vector2i(8, 8)
	t.collapse_every = 1 << 30
	t.moves_to_collapse = 1 << 30
	for x in range(1, 8):
		for z in range(1, 8):
			t.add_block(Vector3i(x, 0, z), true)
	for y in range(1, 5):
		t.add_block(Vector3i(6, y, 6), false, TowerLogic.Kind.NORMAL)
	t.add_block(Vector3i(4, 1, 4), false, TowerLogic.Kind.BOMB, 6)
	t.add_block(Vector3i(3, 1, 4), false)
	t.add_block(Vector3i(4, 2, 4), false)
	t.add_block(Vector3i(5, 3, 3), false)
	t.add_block(Vector3i(2, 1, 2), false)
	t.player = Vector3i(2, 1, 5)
	t.goal_y = 6
	var main = load("res://scenes/main.tscn").instantiate()
	main.quit_game_override = true
	main.test_mode = true
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	main.in_menu = false
	paused = false
	main.main_menu.visible = false
	main._cancel_jobs()
	main.generating = false
	main.stage_start = t
	main.restart()
	main.hud_layer.visible = false
	main.banner.text = ""
	for i in 30:
		await process_frame
	main.zoom_view(0.6)
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("guardada ", out)
	quit(0)
