extends SceneTree
## Captura de la torre nueva con Farolín esperando en el próximo checkpoint, y otra recién llegado a él (con su frase). Uso: ... -s tests/shot_farolin_checkpoint.gd -- PREFIJO
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
	for i in cam.size() - 3:
		main.nueva.accion(Vector3i(int(cam[i][0]), 0, int(cam[i][1])), int(cam[i][2]))
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(pref + "_1.png")
	for i in range(cam.size() - 3, cam.size()):
		main.nueva.accion(Vector3i(int(cam[i][0]), 0, int(cam[i][1])), int(cam[i][2]))
	await create_timer(1.5).timeout
	root.get_texture().get_image().save_png(pref + "_2.png")
	quit(0)
