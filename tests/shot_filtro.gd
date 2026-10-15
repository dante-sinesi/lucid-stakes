extends SceneTree
## Captura del Estudio con el filtro de bloque. Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1700x950 -s tests/shot_filtro.gd -- BIBLIOTECA.jsonl CARACTER SALIDA.png [necesaria]
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
	studio.f_kind.select(1 + studio.KIND_FILTERS.find(args[1]))
	studio.f_kind_needed.button_pressed = args.size() > 3
	studio.refresh_list()
	await _frames(5)
	var rooms: Array = studio.model.filtered(studio.filters())
	if not rooms.is_empty():
		studio.select_room(rooms[0].id)
	studio.view_from_behind()
	await _frames(30)
	root.get_texture().get_image().save_png(args[2])
	print("salas con el filtro: ", rooms.size())
	quit(0)
