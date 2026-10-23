extends SceneTree
## Captura del cubo-portal del final de la torre (se salta a la última sala). Uso: ... -s tests/capturas/shot_portal.gd -- ARCHIVO.png
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	main.start_game()
	await create_timer(0.5).timeout
	main.dice.auto_start = true   # (los dados de la pantalla de carga: se aprieta Empezar para pasar)
	main.dice.set_ready(true)
	await create_timer(1.2).timeout
	var n = main.torre
	# a la última sala: se juegan todos los caminos menos el último
	for k in n.t.salas.size() - 1:
		for a in n.t.salas[k].d.camino:
			n.accion(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
		main.dialogue.hide_box()
	await create_timer(1.0).timeout
	var cam: Array = n.t.salas[n.t.indice].d.camino
	for i in cam.size() - 3:
		n.accion(Vector3i(int(cam[i][0]), 0, int(cam[i][1])), int(cam[i][2]))
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit(0)
