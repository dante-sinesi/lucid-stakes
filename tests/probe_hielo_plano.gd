extends SceneTree
## Prototipo de las salas del Glaciar (ver scripts/glaciar_gen.gd): arma salas de hielo de varias familias al azar, las resuelve con el A* exacto y guarda las que tienen mucho hielo y
## varios resbalones para mirarlas en el Estudio. Imprime cuántas salen de cada familia.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/probe_hielo_plano.gd -- SALIDA.rooms [INTENTOS] [SEMILLA] [FAMILIAS separadas por comas, por defecto todas]
const RoomLib := preload("res://scripts/room_lib.gd")
const Pack := preload("res://scripts/room_pack.gd")
const Gen := preload("res://scripts/glaciar_gen.gd")

var rng := RandomNumberGenerator.new()


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "bibliotecas/glaciar_prototipo/variado.rooms"
	var attempts := int(args[1]) if args.size() > 1 else 600
	rng.seed = int(args[2]) if args.size() > 2 else 1
	var families: Array = Array(args[3].split(",")) if args.size() > 3 else Gen.FAMILIES.duplicate()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path).get_base_dir())
	var found: Dictionary = {}
	var shapes := ["3x5", "3x8", "L", "U", "3x3"]
	var why := {}
	var per := {}
	for fam in families:
		per[fam] = {"intentos": 0, "resueltas": 0, "buenas": 0}
	for i in attempts:
		var fam: String = families[i % families.size()]
		var hs: Array = Gen.heights_for(fam)
		var room := Gen.random_room(rng, shapes[(i / families.size()) % shapes.size()], int(hs[rng.randi_range(0, hs.size() - 1)]), fam)
		per[fam].intentos += 1
		if RoomLib.validate_structure(room) != "":
			why["estructura"] = int(why.get("estructura", 0)) + 1
			continue
		var ver := RoomLib.verify_exact(room, 30000, 3000)
		if ver.proof != "exacta":
			why[str(ver.proof)] = int(why.get(str(ver.proof), 0)) + 1
			continue
		per[fam].resueltas += 1
		room["path"] = ver.path
		RoomLib.apply_result(room, ver.path, "exacta", int(ver.moves), int(ver.states))
		room.opt["source"] = "glaciar"
		room.opt["familia"] = fam
		var ice := 0
		var total := 0
		for c in room.cols.values():
			for ch in str(c):
				total += 1
				if ch == "i":
					ice += 1
		room.opt["ice_share"] = snappedf(float(ice) / float(maxi(total, 1)), 0.01)
		var ok := int(room.opt.slides) >= 3 and int(room.opt.moves) >= 8 and float(room.opt.ice_share) >= 0.8
		if fam == "terrazas":
			ok = int(room.opt.slides) >= 2 and int(room.opt.moves) >= 10 and float(room.opt.ice_share) >= 0.8
		if ok:
			found[room.id] = room
			per[fam].buenas += 1
		if i % 300 == 299:
			print("intento %d · buenas %d" % [i + 1, found.size()])
	var list: Array = found.values()
	Pack.write_library(list, ProjectSettings.globalize_path(out_path), true)
	print("intentos: %d · guardadas: %d · descartes: %s" % [attempts, list.size(), str(why)])
	for fam in families:
		print("  %s: %d intentos · %d resueltas · %d buenas" % [fam, per[fam].intentos, per[fam].resueltas, per[fam].buenas])
	quit(0)
