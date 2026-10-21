extends SceneTree
## Captura del Estudio de salas nuevas en modo de jugar. GAME_SANDBOX=1 SN_LIB=archivo.jsonl godot --path . --rendering-driver opengl3 --resolution 1600x900 -s tests/shot_juego_salas_nuevas.gd -- SALIDA.png [SALA=0] [MOVIMIENTOS=8]


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var estudio = load("res://salas_nuevas/estudio.tscn").instantiate()
	root.add_child(estudio)
	await _frames(6)
	estudio.elegir(int(args[1]) if args.size() > 1 else 0)
	estudio.alternar_juego()
	var d: Dictionary = estudio.salas[estudio.actual]
	var n := int(args[2]) if args.size() > 2 else 8
	for i in mini(n, d.camino.size()):
		var a: Array = d.camino[i]
		estudio._accion_juego(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
	await _frames(8)
	root.get_texture().get_image().save_png(args[0])
	print("listo")
	quit(0)
