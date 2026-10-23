extends SceneTree
## Capturas del Estudio de salas nuevas, desde detrás del jugador. Uso:
##   GAME_SANDBOX=1 SALAS_ARCHIVO=archivo.jsonl godot --path . --rendering-driver opengl3 --resolution 1600x900 -s tests/capturas/shot_estudio.gd -- PREFIJO [SALA=0] [CUADROS=5]
## Escribe PREFIJO_<sala>_<cuadro>_vista.png (la vista 3D sola, desde atrás del jugador) y PREFIJO_<sala>_ui.png (el estudio entero en el cuadro 0).


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var prefijo: String = args[0]
	var estudio = load("res://torre/estudio.tscn").instantiate()
	estudio.encuadre_sala = OS.get_environment("SALAS_SALA") == "1"   # SALAS_SALA=1: cámara fija que encuadra toda la sala
	root.add_child(estudio)
	await _frames(6)
	var indices: Array = []
	for s in (args[1] if args.size() > 1 else "0").split(","):
		indices.append(int(s))
	var n_cuadros := int(args[2]) if args.size() > 2 else 5
	for idx in indices:
		if idx >= estudio.salas.size():
			continue
		estudio.elegir(idx)
		await _frames(8)
		root.get_texture().get_image().save_png("%s_%d_ui.png" % [prefijo, idx])
		estudio.contenedor.stretch = false
		estudio.vp.size = Vector2i(1280, 720)
		await _frames(3)
		var total: int = estudio.cuadros.size() - 1
		for k in n_cuadros:
			estudio.ir_a(int(round(float(k) * float(total) / float(maxi(n_cuadros - 1, 1)))))
			await _frames(6)
			estudio.vp.get_texture().get_image().save_png("%s_%d_%d_vista.png" % [prefijo, idx, k])
	print("listo")
	quit(0)
