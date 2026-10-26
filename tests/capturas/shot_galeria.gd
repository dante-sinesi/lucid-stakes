extends SceneTree
## Captura de la galería de bloques (scenes/galeria_bloques.tscn). Uso: ... --rendering-driver opengl3 --resolution 1600x900 -s tests/capturas/shot_galeria.gd -- ARCHIVO.png [ZOOM]
func _init() -> void:
	var g = load("res://scenes/galeria_bloques.tscn").instantiate()
	root.add_child(g)
	await create_timer(0.5).timeout
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:   # (más zoom para que entren todas las filas cuando hay muchos tipos)
		g.zoom = float(args[1])
		g._poner_camara()
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit(0)
