extends SceneTree
## Comprueba la cámara libre del Estudio de salas nuevas: gira a un lado y sigue al personaje en dos cuadros del camino.
## GAME_SANDBOX=1 SN_LIB=archivo.jsonl godot --path . --rendering-driver opengl3 --resolution 1600x900 -s tests/shot_camara_libre.gd -- PREFIJO


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var prefijo: String = OS.get_cmdline_user_args()[0]
	var estudio = load("res://salas_nuevas/estudio.tscn").instantiate()
	root.add_child(estudio)
	await _frames(6)
	estudio.elegir(0)
	estudio._pasar_a_libre()
	estudio.yaw += 140.0
	estudio.pitch = 40.0
	estudio.dist = 8.0
	estudio.contenedor.stretch = false
	estudio.vp.size = Vector2i(1280, 720)
	for k in 3:
		estudio.ir_a(int(round(float(k) * float(estudio.cuadros.size() - 1) / 2.0)))
		await _frames(6)
		estudio.vp.get_texture().get_image().save_png("%s_%d.png" % [prefijo, k])
	print("listo")
	quit(0)
