extends SceneTree
## Captura de la sala sola (sin la interfaz), vista desde atrás del personaje. Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1400x900 -s tests/shot_sala.gd -- BIBLIOTECA.jsonl PREFIJO_ID SALIDA.png [diagonal]
func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var studio = load("res://scenes/studio.tscn").instantiate()
	root.add_child(studio)
	await _frames(5)
	studio.open_library(args[0])
	await _frames(3)
	for r in studio.model.filtered({}):
		if str(r.id).begins_with(args[1]):
			studio.select_room(r.id)
			break
	studio.set_view_only(true)
	if args.size() > 3 and args[3] == "diagonal":
		studio.view_default()
	else:
		studio.view_from_behind()
	studio.dist *= 0.62
	studio._place_cam()
	await _frames(40)
	studio.viewport.get_texture().get_image().save_png(args[2])
	print("guardada ", args[2], " ", studio.viewport.size)
	quit(0)
