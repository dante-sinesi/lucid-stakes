extends SceneTree
## Captura de las animaciones de Farolín en la galería de bloques: una serie de fotos (la espera con sus pasatiempos y el salto de celebrar con las chispas).
## Uso: ... --rendering-driver opengl3 -s tests/capturas/shot_farolin.gd -- PREFIJO [ZOOM] [GIRO] [FILA]   (guarda PREFIJO_0.png, PREFIJO_1.png...)
func _init() -> void:
	var g = load("res://scenes/galeria_bloques.tscn").instantiate()
	root.add_child(g)
	await create_timer(0.5).timeout
	var args := OS.get_cmdline_user_args()
	g.zoom = float(args[1]) if args.size() > 1 else 3.0
	g.yaw = float(args[2]) if args.size() > 2 else 45.0
	var fila := float(args[3]) if args.size() > 3 else 16.0
	g.pivot.position = g._celda(0, fila) + Vector3(0.0, 0.5, 0.0)
	g._poner_camara()
	var n := 0
	# la espera: cuatro fotos separadas, para ver los pasatiempos
	for i in 4:
		await create_timer(1.3).timeout
		root.get_texture().get_image().save_png("%s_%d.png" % [args[0], n])
		n += 1
	# el salto: al subir, en el aire con los brazos arriba, y las chispas
	for f in g._farolines:
		(f.nodo as Node3D).celebrar(f.punto, f.soplar)
	for t in [0.28, 0.52, 0.75]:
		await create_timer(t if n == 4 else 0.24).timeout
		root.get_texture().get_image().save_png("%s_%d.png" % [args[0], n])
		n += 1
	quit(0)
