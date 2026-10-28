extends SceneTree
## La última fila de la galería de bloques: el checkpoint con Farolín y Ama. Uso (con yaw 225 se ve a Ama de frente): GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1500x700 -s tests/capturas/shot_galeria_checkpoint.gd -- ARCHIVO.png


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var g = load("res://scenes/galeria_bloques.tscn").instantiate()
	root.add_child(g)
	await create_timer(0.5).timeout
	var fila: float = 0.0
	for tipo in g.TIPOS:
		fila += 2.0
	g.pivot.position = g._celda((g.Art.NIVELES - 1) * 0.5, fila)   # (la fila nueva está después de las de cada tipo)
	g.zoom = 3.4
	g.yaw = 225.0
	g._poner_camara()
	await create_timer(1.0).timeout
	root.get_viewport().get_texture().get_image().save_png(args[0])
	quit()
