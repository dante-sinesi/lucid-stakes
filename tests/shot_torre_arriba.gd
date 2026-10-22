extends SceneTree
## Captura de la torre vista desde arriba (cámara ortogonal mirando hacia abajo). Uso: ... -s tests/shot_torre_arriba.gd -- ARCHIVO.png
func _frames(n: int) -> void:
	for i in n:
		await process_frame
func _init() -> void:
	var escena = load("res://salas_nuevas/torre.tscn").instantiate()
	root.add_child(escena)
	await _frames(6)
	var t = escena.t
	for n in escena.estaticas:
		if n != null and is_instance_valid(n):
			n.visible = true
	escena.vivo.visible = true
	var alto := float(t.total_pisos())
	escena.pitch_node.rotation_degrees.x = -90.0
	escena.pivot.rotation_degrees.y = 0.0
	escena.pivot.position = Vector3(5.5, alto, 5.5)
	escena.cam.size = 15.0
	escena.cam.position = Vector3(0, 0, alto + 40.0)
	escena.cam.far = alto + 120.0
	escena.texto_aviso.text = ""
	await _frames(8)
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	print("listo")
	quit(0)
