extends SceneTree
## Un bloque de hielo de cerca desde varios giros de cámara (para revisar que el cristal no cambie ni parpadee al girar). Uso: ... -s tests/capturas/shot_hielo_giro.gd -- CARPETA
func _init() -> void:
	var carpeta: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(carpeta)
	var g = load("res://scenes/galeria_bloques.tscn").instantiate()
	root.add_child(g)
	await create_timer(0.5).timeout
	g.pivot.position = g._celda(2, 5)
	g.zoom = 2.6
	var i := 0
	for yaw in [45, 90, 135, 180, 225, 270, 315, 20]:
		g.yaw = yaw
		g._poner_camara()
		await create_timer(0.35).timeout
		var img := root.get_texture().get_image()
		img.save_png("%s/g_%d.png" % [carpeta, i])
		i += 1
	quit(0)
