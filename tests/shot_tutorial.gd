extends SceneTree
## Captura de la lección de moverse y la de empujar con las teclas arriba. Correr con GAME_SANDBOX=1.
## Uso: ... --rendering-driver opengl3 --resolution 1280x720 -s tests/shot_tutorial.gd -- SALIDA
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var main = load("res://scenes/main.tscn").instantiate()
	main.quit_game_override = true
	root.add_child(main)
	for i in 20: await process_frame
	main.start_tutorial(0, true)
	for i in 60: await process_frame
	root.get_texture().get_image().save_png(args[0] + "_1.png")
	main.key_hint.note("mover_adelante", 0)
	main.key_hint.note("mover_derecha", 0)
	for i in 30: await process_frame
	root.get_texture().get_image().save_png(args[0] + "_2.png")
	main.start_tutorial(2, true)
	for i in 40: await process_frame
	main.key_hint.note("mover_izquierda", 1)
	for i in 30: await process_frame
	root.get_texture().get_image().save_png(args[0] + "_3.png")
	quit()
