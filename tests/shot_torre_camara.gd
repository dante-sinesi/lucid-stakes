extends SceneTree
## Prueba del movimiento de cámara de la torre: orbitar, inclinar, acercar y la vista desde arriba. Uso: ... -s tests/shot_torre_camara.gd -- PREFIJO
func _init() -> void:
	var pref: String = OS.get_cmdline_user_args()[0]
	var escena = load("res://salas_nuevas/torre.tscn").instantiate()
	root.add_child(escena)
	await create_timer(0.5).timeout
	var c0: Array = escena.t.salas[0].d.camino
	for i in 6:
		escena.accion(Vector3i(int(c0[i][0]), 0, int(c0[i][1])), int(c0[i][2]))
	await create_timer(0.6).timeout
	escena.orbitar(Vector2(220, -60))   # gira (derecha) e inclina (hacia abajo)
	escena.acercar(0.8)
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(pref + "_orbita.png")
	print("yaw ", escena.yaw_target, " pitch ", escena.cam_pitch, " zoom ", escena.zoom)
	escena.orbitar(Vector2(0, 400))   # mucho hacia arriba: vista desde arriba
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(pref + "_arriba.png")
	print("yaw ", escena.yaw_target, " pitch ", escena.cam_pitch)
	quit(0)
