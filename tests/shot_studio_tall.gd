extends SceneTree
## Captura del Estudio con una sala alta de la biblioteca. Uso: ... -s tests/shot_studio_tall.gd -- BIBLIOTECA PREFIJO FORMA ALTURA_MIN
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var studio = load("res://scenes/studio.tscn").instantiate()
	root.add_child(studio)
	for i in 5:
		await process_frame
	studio.open_library(args[0])
	for i in 5:
		await process_frame
	var rooms: Array = studio.model.filtered({"shape": args[2], "h_lo": int(args[3]), "sort": "h"})
	var pick: Dictionary = rooms[rooms.size() - 1]
	studio.select_room(pick.id)
	for i in 60:
		await process_frame
	root.get_texture().get_image().save_png("%s_alta.png" % args[1])
	studio.play_goto(pick.path.size() * 2 / 3)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png("%s_alta_reproduccion.png" % args[1])
	print("sala: ", pick.shape, " ", pick.h, " pisos, ", pick.opt.moved, " bloques, ", pick.path.size(), " pasos")
	quit()
