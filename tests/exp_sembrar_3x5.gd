extends SceneTree
## Siembra salas 3x5 a partir de las 3x3 difíciles: el dibujo de la 3x3 se corre dos columnas hacia la salida (la 3x5 termina en la columna 4, igual que la 3x3 en la 2). Variables: LIB, OUT (archivo .jsonl), MIN (dificultad mínima de la 3x3, 0.4).
const RoomLib := preload("res://scripts/room_lib.gd")


func _init() -> void:
	var rooms: Array = RoomLib.read_file(OS.get_environment("LIB")).rooms
	var min_d := float(OS.get_environment("MIN")) if OS.get_environment("MIN") != "" else 0.4
	var out: Array = []
	var seen := {}
	for r in rooms:
		if r.shape != "3x3" or float(r.opt.get("diff", 0.0)) < min_d:
			continue
		for shift in [2, 1]:
			var n := RoomLib.make_room("3x5", r.h)
			n.cols = {}
			for c in r.cols:
				n.cols[Vector2i(c.x + shift, c.y)] = r.cols[c]
			if RoomLib.validate_structure(n) != "":
				continue
			RoomLib.finalize(n)
			if seen.has(n.id):
				continue
			seen[n.id] = true
			var ex := RoomLib.exact_room(n, 600000, 8000)
			if ex.is_empty():
				continue
			ex.origin = "minero"
			ex.opt.source = "sembrada"
			out.append(ex)
			print("3x3 %d%% -> 3x5 corrida %d: %d%% (%d de %d)" % [roundi(100.0 * float(r.opt.diff)), shift, roundi(100.0 * float(ex.opt.diff)), int(ex.opt.grabs), int(ex.opt.moves)])
	RoomLib.write_file(OS.get_environment("OUT"), out)
	print("sembradas ", out.size())
	quit(0)
