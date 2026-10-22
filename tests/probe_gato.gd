extends SceneTree
func _frames(n: int) -> void:
	for i in n:
		await process_frame
func _init() -> void:
	var escena = load("res://salas_nuevas/torre.tscn").instantiate()
	root.add_child(escena)
	await _frames(6)
	var t = escena.t
	var c0: Array = t.salas[0].d.camino
	for i in 6:
		escena.accion(Vector3i(int(c0[i][0]), 0, int(c0[i][1])), int(c0[i][2]))
	await _frames(60)
	print("jugador ", t.motor.jugador, " gato ", escena.gato_nodo.global_position, " pivot ", escena.pivot.position, " pantalla ", escena.cam.unproject_position(escena.gato_nodo.global_position), " size ", escena.cam.size)
	quit(0)
