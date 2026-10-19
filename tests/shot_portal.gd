extends SceneTree
## Captura del portal de salida de la torre (la losa) desde arriba y desde abajo del horizonte: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 900x700 -s tests/shot_portal.gd -- PREFIJO
const TowerLogic := preload("res://scripts/tower_logic.gd")


func _init() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "capturas/portal"
	var t = TowerLogic.new()
	t.size = Vector2i(8, 8)
	t.collapse_every = 1 << 30
	t.moves_to_collapse = 1 << 30
	for x in range(1, 8):
		for z in range(1, 8):
			t.add_block(Vector3i(x, 0, z), true)
	for y in range(1, 5):
		t.add_block(Vector3i(6, y, 6))
	t.add_block(Vector3i(3, 1, 4))
	t.add_block(Vector3i(5, 3, 3))
	t.player = Vector3i(2, 1, 5)
	t.goal_block = t.blocks[Vector3i(6, 4, 6)]
	t.goal_cell = Vector3i(6, 5, 6)
	t.goal_y = 5
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
	main.zoom_view(0.6)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(out + "_arriba.png")
	main.cam_pitch = 40.0   # mirando desde abajo del horizonte
	main.pitch_node.rotation_degrees.x = main.cam_pitch
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(out + "_abajo.png")
	print("guardadas")
	quit(0)
