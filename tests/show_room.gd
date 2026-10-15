extends SceneTree
## Muestra en texto las salas de un archivo .jsonl: LIB, ID (prefijo del id; por defecto las N con más agarres), N (3).
const RoomLib := preload("res://scripts/room_lib.gd")


func _init() -> void:
	var lib := OS.get_environment("LIB")
	var want := OS.get_environment("ID")
	var n := int(OS.get_environment("N")) if OS.get_environment("N") != "" else 3
	var rooms: Array = RoomLib.read_file(lib).rooms
	rooms.sort_custom(func(a, b): return int(a.opt.get("grabs", 0)) * 1000 + int(a.opt.get("moves", 0)) > int(b.opt.get("grabs", 0)) * 1000 + int(b.opt.get("moves", 0)))
	var shown := 0
	for r in rooms:
		if want != "" and not str(r.id).begins_with(want):
			continue
		print("%s h%d id %s: %d pasos, %d agarres, %d bloques distintos movidos, %d bloques, dificultad %.0f %%, prueba %s" % [r.shape, r.h, str(r.id).substr(0, 8), r.opt.moves, r.opt.grabs, r.opt.moved, RoomLib.block_count(r), 100.0 * float(r.opt.diff), r.opt.proof])
		print(RoomLib.ascii(r))
		print("camino: ", RoomLib.path_string(r.path))
		shown += 1
		if shown >= n:
			break
	quit(0)
