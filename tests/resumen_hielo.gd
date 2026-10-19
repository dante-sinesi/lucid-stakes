extends SceneTree
## Cuántas salas de la biblioteca tienen hielo: GAME_SANDBOX=1 godot --headless --path . -s tests/resumen_hielo.gd -- ARCHIVO.rooms
const Pack := preload("res://scripts/room_pack.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var rooms: Array = Pack.load_library(args[0])
	var with_ice := 0
	var dense := 0
	var only_ice := 0
	var by_h := {}
	var diff_sum := 0.0
	var good := 0
	var blocks_ice := 0
	var ice_in_path := 0
	for r in rooms:
		var n := 0
		var other := false
		for c in r.cols.values():
			for ch in str(c):
				if ch == "i":
					n += 1
				elif ch != "n" and ch != ".":
					other = true
		if n > 0:
			with_ice += 1
			blocks_ice += n
			if n >= 3:
				dense += 1
			if not other:
				only_ice += 1
			by_h[int(r.h)] = int(by_h.get(int(r.h), 0)) + 1
			diff_sum += float(r.opt.get("diff", 0))
			if float(r.opt.get("diff", 0)) >= 0.35 and float(r.opt.get("reach", 0)) >= 0.5:
				good += 1
	print("salas: ", rooms.size(), " con hielo: ", with_ice, " con 3 o más bloques de hielo: ", dense, " sólo hielo (sin otro especial): ", only_ice, " buenas (dif>=35 % y alcance>=0.5): ", good)
	print("bloques de hielo por sala: %.1f · dificultad media %.0f %%" % [float(blocks_ice) / maxf(with_ice, 1), 100.0 * diff_sum / maxf(with_ice, 1)])
	var keys := by_h.keys()
	keys.sort()
	var out := []
	for k in keys:
		out.append("%d pisos=%d" % [k, by_h[k]])
	print("por altura: ", ", ".join(out))
	quit(0)
