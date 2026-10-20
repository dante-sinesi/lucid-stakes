extends SceneTree
## Prototipo: salas de deslizamiento del Glaciar (una meseta de hielo con topes, el desafío es resbalar bien). Genera salas al azar, las resuelve con el A* exacto y
## guarda las que tienen mucho hielo y varios resbalones para mirarlas en el Estudio.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/probe_hielo_plano.gd -- SALIDA.rooms [INTENTOS] [SEMILLA] [ALTURAS, por ejemplo 4,5,6]
const RoomLib := preload("res://scripts/room_lib.gd")
const Pack := preload("res://scripts/room_pack.gd")

var rng := RandomNumberGenerator.new()


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "bibliotecas/glaciar_prototipo/plano.rooms"
	var attempts := int(args[1]) if args.size() > 1 else 600
	rng.seed = int(args[2]) if args.size() > 2 else 1
	var heights: Array = []
	for part in (args[3] if args.size() > 3 else "4").split(","):
		heights.append(int(part))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path).get_base_dir())
	var found: Dictionary = {}
	var tried := 0
	var solved := 0
	var shapes := ["3x5", "3x8", "L", "U", "3x3"]
	var why := {}
	for i in attempts:
		var room := random_room(shapes[i % shapes.size()], int(heights[(i / shapes.size()) % heights.size()]))
		if RoomLib.validate_structure(room) != "":
			why["estructura"] = int(why.get("estructura", 0)) + 1
			continue
		tried += 1
		var ver := RoomLib.verify_exact(room, 30000, 3000)
		if ver.proof != "exacta":
			why[str(ver.proof)] = int(why.get(str(ver.proof), 0)) + 1
			continue
		solved += 1
		room["path"] = ver.path
		RoomLib.apply_result(room, ver.path, "exacta", int(ver.moves), int(ver.states))
		room.opt["source"] = "plano"
		var ice := 0
		var total := 0
		for c in room.cols.values():
			for ch in str(c):
				total += 1
				if ch == "i":
					ice += 1
		room.opt["ice_share"] = snappedf(float(ice) / float(maxi(total, 1)), 0.01)
		if int(room.opt.slides) >= 3 and int(room.opt.moves) >= 8 and float(room.opt.ice_share) >= 0.8:
			found[room.id] = room
		if i % 100 == 99:
			print("intento %d · resolubles %d · buenas %d" % [i + 1, solved, found.size()])
	var list: Array = found.values()
	Pack.write_library(list, ProjectSettings.globalize_path(out_path), true)
	print("intentos: %d · válidas: %d · resueltas con prueba exacta: %d · guardadas (≥ 80 %% hielo, ≥ 3 resbalones, ≥ 8 pasos): %d · descartes: %s" % [attempts, tried, solved, list.size(), str(why)])
	var by_slides := {}
	var mv := 0.0
	for r in list:
		by_slides[int(r.opt.slides)] = int(by_slides.get(int(r.opt.slides), 0)) + 1
		mv += float(r.opt.moves)
	print("resbalones: %s · pasos medios: %.1f" % [str(by_slides), mv / maxf(list.size(), 1)])
	quit(0)


## Una meseta de hielo (columnas de 2 de hielo), con algunos topes (hielo con un bloque pesado o común encima), una rampa baja junto a la llegada y huecos al ras del piso.
func random_room(shape: String, h: int) -> Dictionary:
	var room := RoomLib.make_room(shape, h)
	var entry: Vector2i = room.entry
	var exit: Vector2i = room.exit
	var cols := {}
	var plateau := "i".repeat(maxi(h - 2, 1))
	for c in room.cells:
		if c == exit:
			continue
		var d := Vector2(c - entry).length()
		if d < 1.5:
			continue
		if d < 2.5:
			cols[c] = "i"   # la rampa: un escalón de hielo
			continue
		var r := rng.randf()
		if r < 0.10:
			continue   # al ras del piso: se cae un nivel
		elif r < 0.30:
			cols[c] = plateau + "h"
		elif r < 0.42:
			cols[c] = plateau + "n"
		else:
			cols[c] = plateau
	room["cols"] = cols
	return room
