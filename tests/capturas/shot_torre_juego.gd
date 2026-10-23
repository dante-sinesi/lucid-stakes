extends SceneTree
## Capturas del juego real (main.tscn) con la torre: al empezar y a mitad de la primera sala. Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_torre_juego.gd -- PREFIJO
func _init() -> void:
	var pref: String = OS.get_cmdline_user_args()[0]
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	main.start_game()
	await create_timer(0.5).timeout
	main.dice.auto_start = true   # (los dados de la pantalla de carga: se aprieta Empezar para pasar)
	main.dice.set_ready(true)
	await create_timer(1.5).timeout
	root.get_texture().get_image().save_png(pref + "_1.png")
	var cam: Array = main.torre.t.salas[0].d.camino
	for i in mini(7, cam.size() - 1):
		main.torre.accion(Vector3i(int(cam[i][0]), 0, int(cam[i][1])), int(cam[i][2]))
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(pref + "_2.png")
	quit(0)
