extends SceneTree
## Prototipos de salas L y U generadas al revés (scripts/convoy_gen.gd): por cada idea arma salas desordenando una escalera resuelta, las resuelve con el A* exacto, mide cuánto se
## entrelaza el camino y se queda con las N que mejor lo hacen (muchos bloques, muchos cambios de bloque, poca caminata antes del primer agarre y todo el espacio usado).
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/probe_convoy.gd -- CARPETA [N=25] [SEMILLA=1] [IDEAS separadas por comas] [INTENTOS_MAX=400] [PASOS=80]
const RoomLib := preload("res://scripts/room_lib.gd")
const Pack := preload("res://scripts/room_pack.gd")
const Gen := preload("res://scripts/convoy_gen.gd")

var rng := RandomNumberGenerator.new()


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "bibliotecas/convoy_prototipo"
	var want := int(args[1]) if args.size() > 1 else 25
	rng.seed = int(args[2]) if args.size() > 2 else 1
	var ideas: Array = Array(args[3].split(",")) if args.size() > 3 and args[3] != "" else Gen.IDEAS.duplicate()
	var max_attempts := int(args[4]) if args.size() > 4 else 400
	var steps := int(args[5]) if args.size() > 5 else 80
	var out := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(out)
	var all: Array = []
	for idea in ideas:
		var res := _run_idea(idea, want, max_attempts, steps)
		for r in res.picked:
			all.append(r)
		Pack.write_library(res.picked, out.path_join("%s.rooms" % idea), true)
		Pack.write_library(res.solved, out.path_join("%s_todas.rooms" % idea), true)
		print("%s: %d intentos · %d armadas · %d válidas · %d resueltas · %d buenas · %d elegidas · %s" % [idea, res.attempts, res.built, res.valid, res.solved.size(), res.good, res.picked.size(), str(res.why)])
		print("    pasos %s · empujes %s · bloques %s · cambios %s · 1er agarre %s · espacio %s%%" % [_rng(res.picked, "moves"), _rng(res.picked, "grabs"), _rng(res.picked, "blocks"), _rng(res.picked, "switches"), _rng(res.picked, "first_grab"), _rng(res.picked, "spread100")])
		print("    (todas las resueltas) pasos %s · empujes %s · bloques %s · cambios %s · 1er agarre %s · espacio %s%%" % [_rng(res.solved, "moves"), _rng(res.solved, "grabs"), _rng(res.solved, "blocks"), _rng(res.solved, "switches"), _rng(res.solved, "first_grab"), _rng(res.solved, "spread100")])
	Pack.write_library(all, out.path_join("convoy_prototipos.rooms"), true)
	print("total: %d salas en %s" % [all.size(), dir])
	quit(0)


func _run_idea(idea: String, want: int, max_attempts: int, steps: int) -> Dictionary:
	var shapes: Array = Gen.shapes_for(idea)
	var hs: Array = Gen.heights_for(idea)
	var why := {}
	var built := 0
	var valid := 0
	var solved: Array = []
	var attempts := 0
	while attempts < max_attempts and solved.size() < want * 4:
		attempts += 1
		var shape: String = shapes[attempts % shapes.size()]
		var room := Gen.scramble(rng, shape, int(hs[rng.randi_range(0, hs.size() - 1)]), idea, steps + rng.randi_range(-20, 40))
		if room.is_empty():
			why["no_arma"] = int(why.get("no_arma", 0)) + 1
			continue
		built += 1
		var bad := RoomLib.validate_structure(room)
		if bad != "":
			why[bad] = int(why.get(bad, 0)) + 1
			continue
		valid += 1
		var ver := RoomLib.verify_exact(room, 80000, 5000)
		if ver.proof != "exacta":
			why[str(ver.proof)] = int(why.get(str(ver.proof), 0)) + 1
			continue
		room["path"] = ver.path
		RoomLib.apply_result(room, ver.path, "exacta", int(ver.moves), int(ver.states))
		if not RoomLib.outside_cells(room).is_empty():
			why["sale_de_la_arena"] = int(why.get("sale_de_la_arena", 0)) + 1
			continue
		var m := Gen.metrics(room)
		for k in m:
			room.opt[k] = m[k]
		room.opt["spread100"] = int(round(float(m.spread) * 100.0))
		room.opt["source"] = "convoy"
		room.opt["idea"] = idea
		room.note = str(Gen.IDEA_NAMES.get(idea, idea))
		solved.append(room)
	var good: Array = []
	for r in solved:
		if _good(r):
			good.append(r)
	good.sort_custom(func(a, b): return _score(a) > _score(b))
	return {"attempts": attempts, "built": built, "valid": valid, "solved": solved, "good": good.size(), "picked": good.slice(0, want), "why": why}


## Lo que se busca: varios bloques distintos, cambios de bloque, poco camino antes del primer agarre.
func _good(r: Dictionary) -> bool:
	var o: Dictionary = r.opt
	return int(o.moves) >= 14 and int(o.grabs) >= 6 and int(o.blocks) >= 3 and int(o.switches) >= 3 and float(o.walk) <= 0.3


func _score(r: Dictionary) -> float:
	var o: Dictionary = r.opt
	return float(o.switches) * 2.0 + float(o.blocks) * 3.0 + float(o.spread) * 20.0 - float(o.walk) * 20.0 + float(o.grabs) * 0.5


func _rng(list: Array, key: String) -> String:
	if list.is_empty():
		return "-"
	var lo := 9999
	var hi := -9999
	for r in list:
		var v := int(r.opt.get(key, 0))
		lo = mini(lo, v)
		hi = maxi(hi, v)
	return "%d-%d" % [lo, hi]
