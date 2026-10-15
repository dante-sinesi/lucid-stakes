extends SceneTree
## Captura del Estudio con una sala. Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1500x850 -s tests/shot_room.gd -- BIBLIOTECA.jsonl PREFIJO_DEL_ID SALIDA.png
func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var studio = load("res://scenes/studio.tscn").instantiate()
	root.add_child(studio)
	await _frames(5)
	studio.open_library(args[0])
	await _frames(5)
	for r in studio.model.filtered({}):
		if str(r.id).begins_with(args[1]):
			studio.select_room(r.id)
			break
	await _frames(40)
	root.get_texture().get_image().save_png(args[2])
	print("guardada ", args[2])
	quit(0)
