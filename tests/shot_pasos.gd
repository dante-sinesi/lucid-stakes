extends SceneTree
## Capturas del Estudio de pasos. Uso: GAME_SANDBOX=1 STEP_LIB=archivo godot --path . --rendering-driver opengl3 --resolution 1700x950 -s tests/shot_pasos.gd -- PREFIJO [indice_del_paso] [largo]
func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var studio = load("res://scenes/step_studio.tscn").instantiate()
	root.add_child(studio)
	await _frames(5)
	studio.select_step(int(args[1]) if args.size() > 1 else 0)
	studio.set_view_r(int(args[2]) if args.size() > 2 else 1)
	studio.run_all_lengths()
	studio.solve_current()
	await _frames(30)
	root.get_texture().get_image().save_png(args[0] + "_ui.png")
	studio.set_view_only(true)
	studio.view_from_behind()
	studio.dist *= 0.7
	studio._place_cam()
	await _frames(30)
	studio.viewport.get_texture().get_image().save_png(args[0] + "_sola.png")
	print("listo")
	quit(0)
