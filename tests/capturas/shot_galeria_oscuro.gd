extends SceneTree
## La fila del bloque oscuro (prueba A oscuras) de la galería de bloques. Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1500x700 -s tests/capturas/shot_galeria_oscuro.gd -- ARCHIVO.png


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var g = load("res://scenes/galeria_bloques.tscn").instantiate()
	root.add_child(g)
	await create_timer(0.5).timeout
	var fila := 2.0 * float(g.TIPOS.size() - 1)   # (cada tipo ocupa dos filas, corrupto y purificado; el oscuro, una)
	g.pivot.position = g._celda((g.Art.NIVELES - 1) * 0.5, fila)
	g.zoom = 4.0
	g._poner_camara()
	await create_timer(1.0).timeout
	root.get_viewport().get_texture().get_image().save_png(args[0])
	quit()
