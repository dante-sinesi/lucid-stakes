extends SceneTree
## Capturas de la torre de salas nuevas: el comienzo, a mitad de la primera sala, tras el primer checkpoint, una muerte por tiempo y una vista de toda la torre.
## Uso: GAME_SANDBOX=1 SN_SEMILLA=3 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/shot_torre_salas_nuevas.gd -- PREFIJO


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _foto(nombre: String) -> void:
	await _frames(6)
	root.get_texture().get_image().save_png(nombre)


func _init() -> void:
	var pref: String = OS.get_cmdline_user_args()[0]
	var escena = load("res://salas_nuevas/torre.tscn").instantiate()
	root.add_child(escena)
	await _frames(6)
	await _foto(pref + "_1_inicio.png")
	var t = escena.t
	var cam0: Array = t.salas[0].d.camino
	for i in cam0.size() / 2:
		escena.accion(Vector3i(int(cam0[i][0]), 0, int(cam0[i][1])), int(cam0[i][2]))
	await _foto(pref + "_2_mitad.png")
	for i in range(cam0.size() / 2, cam0.size()):
		escena.accion(Vector3i(int(cam0[i][0]), 0, int(cam0[i][1])), int(cam0[i][2]))
	await _frames(20)
	await _foto(pref + "_3_checkpoint.png")
	# vista de toda la torre (la tecla V del juego)
	escena.panorama = true
	escena._refrescar()
	await _foto(pref + "_4_torre.png")
	print("listo")
	quit(0)
