extends SceneTree
## Repite el camino de TODAS las salas de una biblioteca y cuenta las que no llegan a la salida. LIB (archivo .jsonl), N (máximo, 100000), SHOW (cuántas mostrar, 10).
const RoomLib := preload("res://scripts/room_lib.gd")


func _init() -> void:
	var rooms: Array = RoomLib.read_file(OS.get_environment("LIB")).rooms
	var bad := 0
	var by_src := {}
	var shown := 0
	var n := 0
	var maxn := int(OS.get_environment("N")) if OS.get_environment("N") != "" else 100000
	for r in rooms:
		n += 1
		if n > maxn:
			break
		var rp := RoomLib.replay(r, r.path)
		if not rp.ok:
			bad += 1
			var src := str(r.opt.get("source", "?"))
			by_src[src] = int(by_src.get(src, 0)) + 1
			if shown < int(OS.get_environment("SHOW") if OS.get_environment("SHOW") != "" else "10"):
				shown += 1
				var types := ""
				for c in r.cols:
					for ch in String(r.cols[c]):
						if ch != "n" and ch != "." and types.find(ch) == -1:
							types += ch
				print("MAL %s %dp id %s fuente %s tipos %s: %s" % [r.shape, r.h, str(r.id).substr(0, 8), src, types, str(rp.msg)])
	print("salas %d, con camino que no resuelve: %d, por fuente %s" % [mini(n, rooms.size()), bad, str(by_src)])
	quit(0)
