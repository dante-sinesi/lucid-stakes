extends SceneTree
## ¿Qué salas de la biblioteca usan de verdad el hielo? Repite el camino de cada sala con hielo y cuenta las acciones donde el jugador patina (se mueve 2 celdas o más de un solo paso). LIB, N (máximo de salas, 100000).
const RoomLib := preload("res://scripts/room_lib.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")


func _init() -> void:
	var rooms: Array = RoomLib.read_file(OS.get_environment("LIB")).rooms
	var by_shape := {}
	var used := {}
	var best := {}
	for r in rooms:
		var has_ice := false
		for c in r.cols:
			if String(r.cols[c]).contains("i"):
				has_ice = true
		if not has_ice:
			continue
		by_shape[r.shape] = int(by_shape.get(r.shape, 0)) + 1
		var t = RoomLib.build_state(r)
		var slides := 0
		for a in r.path:
			var before: Vector3i = t.player
			t.try_action(a.dir, a.mode)
			if a.mode == TowerLogic.Mode.MOVE and absi(t.player.x - before.x) + absi(t.player.z - before.z) >= 2:
				slides += 1
		if slides > 0:
			used[r.shape] = int(used.get(r.shape, 0)) + 1
			if not best.has(r.shape) or slides > int(best[r.shape].slides) or (slides == int(best[r.shape].slides) and int(r.opt.grabs) > int(best[r.shape].grabs)):
				best[r.shape] = {"id": str(r.id).substr(0, 8), "slides": slides, "grabs": int(r.opt.grabs), "moves": int(r.opt.moves), "h": r.h}
	print("salas con hielo por forma: ", by_shape)
	print("salas donde el camino patina: ", used)
	for k in best:
		print("  ", k, ": ", best[k])
	quit(0)
