extends SceneTree
## Captura cada lección del tutorial (con el cuadro del tabernero y las teclas arriba) para revisar cómo se entienden. Correr con GAME_SANDBOX=1.
## Uso: ... --rendering-driver opengl3 --resolution 1280x720 -s tests/shot_tutorial_todas.gd -- CARPETA_SALIDA
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "capturas/tutorial"
	DirAccess.make_dir_recursive_absolute(out)
	var main = load("res://scenes/main.tscn").instantiate()
	main.quit_game_override = true
	root.add_child(main)
	for i in 20:
		await process_frame
	for lesson in 6:
		main.start_tutorial(lesson, true)
		for i in 150:
			await process_frame
		root.get_texture().get_image().save_png("%s/leccion_%d.png" % [out, lesson])
	quit()
