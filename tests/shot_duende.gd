extends SceneTree
## Captura del casino con el duende en la puerta de salida: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1100x800 -s tests/shot_duende.gd -- SALIDA.png [etapa] [claridad]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var main = load("res://scenes/main.tscn").instantiate()
	main.quit_game_override = true
	main.test_mode = true
	main.toll_in_tests = true
	main.quick_portal = true
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	main.in_menu = false
	paused = false
	main.main_menu.visible = false
	main._cancel_jobs()
	main.generating = false
	main.stage_number = int(args[1]) if args.size() > 1 else 3
	main.run.stage = main.stage_number
	main.run.claridad = int(args[2]) if args.size() > 2 else 10
	main.enter_casino(true)
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png(args[0] if args.size() > 0 else "capturas/duende.png")
	print("guardada ", main.casino.toll)
	quit(0)
