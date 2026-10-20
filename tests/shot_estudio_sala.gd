extends SceneTree
## Captura del Estudio con una sala de una biblioteca: GAME_SANDBOX=1 godot --rendering-driver opengl3 --resolution 1500x850 -s tests/shot_estudio_sala.gd -- BIBLIOTECA.rooms PREFIJO [orden=slides] [posicion=0]


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
	var order := args[2] if args.size() > 2 else "slides"
	var pos := int(args[3]) if args.size() > 3 else 0
	var list: Array = studio.model.filtered({"sort": order})
	var room: Dictionary = list[mini(pos, list.size() - 1)]
	studio.select_room(room.id)
	await _frames(40)
	root.get_texture().get_image().save_png("%s.png" % args[1])
	var s := ""
	for c in room.cols:
		s += "%s=%s " % [str(c), room.cols[c]]
	print("sala ", room.shape, " ", room.h, " pisos · ", room.opt.moves, " pasos · ", room.opt.slides, " resbalones · entrada ", room.entry, " salida ", room.exit, " · ", s)
	quit(0)
