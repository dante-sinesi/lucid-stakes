extends SceneTree
## Un primer plano de Farolín sentado en el próximo checkpoint. Uso: ... -s tests/shot_farolin_cerca.gd -- ARCHIVO.png
func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	main.start_game()
	await create_timer(1.2).timeout
	var n = main.nueva
	n.pivot.position = n.farolin.position + Vector3(0, 0.3, 0)
	n.cam.size = 2.2
	main.hud_layer.visible = false
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit(0)
