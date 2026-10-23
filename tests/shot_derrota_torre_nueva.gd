extends SceneTree
## Captura de la pantalla de derrota de la torre nueva. Uso: ... -s tests/shot_derrota_torre_nueva.gd -- PREFIJO
func _init() -> void:
	var pref: String = OS.get_cmdline_user_args()[0]
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	main.start_game()
	await create_timer(0.5).timeout
	main.dice.auto_start = true   # (los dados de la pantalla de carga: se aprieta Empezar para pasar)
	main.dice.set_ready(true)
	await create_timer(1.2).timeout
	var cam: Array = main.nueva.t.salas[0].d.camino
	main.nueva.t.salas[0].max_mov = 4
	for i in 4:
		main.nueva.accion(Vector3i(int(cam[i][0]), 0, int(cam[i][1])), int(cam[i][2]))
	await create_timer(0.7).timeout
	root.get_texture().get_image().save_png(pref + "_1.png")
	await create_timer(2.6).timeout
	root.get_texture().get_image().save_png(pref + "_2.png")
	quit(0)
