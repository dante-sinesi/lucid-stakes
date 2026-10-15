extends SceneTree
## Constructor inverso (scripts/room_reverse.gd): ¿cuántas salas genera, qué tan largas son sus soluciones plantadas contra el mínimo real, y usa los especiales?
## Variables: N (intentos por forma y altura, 6), SEED (1), GRABS (6), HS ("5,6,7"), SHAPES ("3x5,3x8,L,U"), SPECIAL (0.35), RAMP (1: rampa suelta, 0: escalera de columnas).
const RoomLib := preload("res://scripts/room_lib.gd")
const RoomMiner := preload("res://scripts/room_miner.gd")
const RoomReverse := preload("res://scripts/room_reverse.gd")
const Solver := preload("res://scripts/solver.gd")


func _env(name: String, def: String) -> String:
	return OS.get_environment(name) if OS.get_environment(name) != "" else def


func _init() -> void:
	var n := int(_env("N", "6"))
	var seed_v := int(_env("SEED", "1"))
	var grabs := int(_env("GRABS", "6"))
	var sp := float(_env("SPECIAL", "0.35"))
	var miner := RoomMiner.new({"seed": seed_v, "write": false})
	var rev := RoomReverse.new(seed_v)
	var why := {}
	var made := 0
	var solved := 0
	var shorter := 0
	var sum_planted := 0
	var sum_exact := 0
	var sum_gp := 0
	var sum_ge := 0
	var spec_total := {}
	for shape in _env("SHAPES", "3x5,3x8,L,U").split(","):
		for hs in _env("HS", "5,6,7").split(","):
			var h := int(hs)
			if h > RoomLib.max_height(shape):
				continue
			for i in n:
				var cols := miner.staircase(shape, h)
				if cols.is_empty():
					why["sin_escalera"] = int(why.get("sin_escalera", 0)) + 1
					continue
				if _env("RAMP", "1") == "1":   # una rampa de bloques sueltos (uno por piso, sostenidos por la arista del de abajo) en lugar de la escalera de columnas
					for c in cols.keys():
						var ks: String = cols[c]
						cols[c] = ".".repeat(ks.length() - 1) + "n"
				var r := rev.build(shape, h, cols, grabs, int(_env("STEPS", "200")), sp)
				if r.is_empty():
					why[rev.last_why] = int(why.get(rev.last_why, 0)) + 1
					continue
				var room: Dictionary = r.room
				if RoomLib.validate_structure(room) != "":
					why["estructura"] = int(why.get("estructura", 0)) + 1
					continue
				made += 1
				var t = RoomLib.build_state(room)
				var res: Dictionary = Solver.solve(t.clone(), h + 1, {"max_states": 800000, "goal_ids": t.goal_ids, "admissible": true, "prefer_plain": true, "max_ms": 20000})
				var types := ""
				for k in r.specials:
					types += "%s%d " % [k, r.specials[k]]
					spec_total[k] = int(spec_total.get(k, 0)) + 1
				if res.status != "solved":
					print("%s h%d: construida (%d agarres plantados, %d pasos, %s) pero el solucionador dice %s" % [shape, h, r.grabs, r.path.size(), types, res.status])
					continue
				solved += 1
				var st := RoomLib.path_stats(room, res.path)
				sum_planted += r.path.size()
				sum_exact += int(res.moves)
				sum_gp += int(r.grabs)
				sum_ge += int(st.grabs)
				if int(res.moves) < r.path.size():
					shorter += 1
				print("%s h%d: plantado %d pasos / %d agarres -> mínimo real %d pasos / %d agarres (%d bloques; %s)" % [shape, h, r.path.size(), r.grabs, res.moves, st.grabs, RoomLib.block_count(room), types])
	print("construidas %d, resueltas por el exacto %d; pasos plantados %.1f contra reales %.1f; agarres plantados %.1f contra reales %.1f; con atajo %d; especiales %s; fallos %s" % [made, solved, float(sum_planted) / maxf(solved, 1), float(sum_exact) / maxf(solved, 1), float(sum_gp) / maxf(solved, 1), float(sum_ge) / maxf(solved, 1), shorter, str(spec_total), str(why)])
	quit(0)
