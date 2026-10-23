extends SceneTree
func _frames(n: int) -> void:
	for i in n:
		await process_frame
func _init() -> void:
	var e = load("res://torre/estudio.tscn").instantiate()
	root.add_child(e)
	await _frames(6)
	e.filtro["i"] = true
	e.filtro["s"] = true
	e.filtro_modo = 0
	# (los casilleros reflejan el filtro: se marcan a mano)
	for n in e.find_children("*", "CheckBox", true, false):
		if n.text == "Hielo" or n.text == "Pinchos":
			n.button_pressed = true
	e._filtro_cambio()
	await _frames(10)
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit(0)
