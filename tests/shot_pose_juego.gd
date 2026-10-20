extends SceneTree
## Captura del personaje del juego con una pose (para ver cómo queda en la cámara real): GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/shot_pose_juego.gd -- SALIDA.png [pose] [zoom]
const Poses := preload("res://scripts/poses.gd")
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var main = load("res://scenes/main.tscn").instantiate()
	main.quit_game_override = true
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	main.in_menu = false
	paused = false
	main.main_menu.visible = false
	for i in 3:
		await process_frame
	main.cam_zoom = float(args[2]) if args.size() > 2 else 3.0
	main._apply_camera(0.0)
	var pose: String = args[1] if args.size() > 1 else "colgarse"
	for n in [main._model, main._ghost]:
		Poses.play(n, pose, 0.3)
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png(args[0] if args.size() > 0 else "capturas/pose_juego.png")
	quit(0)
