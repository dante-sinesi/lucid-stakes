extends SceneTree
## Comprueba a fondo una biblioteca de salas (.jsonl o .rooms) y muestra un informe: cada sala se repite con su camino, se recalculan sus hashes, se revisa que no se resuelva caminando y que sus métricas coincidan.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/check_library.gd -- ARCHIVO [muestra_de_la_prueba_de_caminar (80)]
const RoomLib := preload("res://scripts/room_lib.gd")
const RoomPack := preload("res://scripts/room_pack.gd")
const Solver := preload("res://scripts/solver.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var rooms: Array = RoomPack.load_library(args[0])
	var sample := int(args[1]) if args.size() > 1 else 80
	print("biblioteca: %d salas" % rooms.size())
	check(rooms.size() > 0, "la biblioteca tiene salas")
	var ids := {}
	var fams := {}
	var pats := {}
	var per := {}
	var proofs := {"exacta": 0, "cota": 0, "sin_probar": 0}
	var moved_hist := {}
	var tall_planted := 0
	var t0 := Time.get_ticks_msec()
	for r in rooms:
		check(not ids.has(r.id), "id repetido %s" % str(r.id).substr(0, 8))
		ids[r.id] = true
		fams[r.family] = int(fams.get(r.family, 0)) + 1
		pats[r.pattern] = int(pats.get(r.pattern, 0)) + 1
		check(RoomLib.validate_structure(r) == "", "estructura de %s %d" % [r.shape, r.h])
		check(int(r.rules) == RoomLib.RULES_VERSION, "versión de reglas")
		var rp := RoomLib.replay(r, r.path)
		check(rp.ok, "el camino de %s %d (%s) resuelve la sala: %s" % [r.shape, r.h, str(r.id).substr(0, 8), str(rp.get("msg", ""))])
		var again := RoomLib.copy_room(r)
		RoomLib.finalize(again)
		check(again.id == r.id and again.family == r.family and again.pattern == r.pattern, "hashes de %s" % str(r.id).substr(0, 8))
		var st := RoomLib.path_stats(r, r.path)
		check(int(r.opt.moved) == int(st.moved) and int(r.opt.grabs) == int(st.grabs) and int(r.opt.moves) == r.path.size(), "las métricas coinciden con el camino (%s %d: moved %d/%d grabs %d/%d moves %d/%d)" % [r.shape, r.h, int(r.opt.moved), int(st.moved), int(r.opt.grabs), int(st.grabs), int(r.opt.moves), r.path.size()])
		check(int(r.opt.moved) >= 1 and int(r.opt.grabs) >= 1, "pide mover bloques")
		var pr := str(r.opt.get("proof", "sin_probar"))
		proofs[pr] = int(proofs.get(pr, 0)) + 1
		if pr == "exacta":
			check(int(r.opt.lower) == int(r.opt.moves), "la prueba exacta tiene la cota igual al mínimo")
		per["%s|%d" % [r.shape, r.h]] = int(per.get("%s|%d" % [r.shape, r.h], 0)) + 1
		moved_hist[int(r.opt.moved)] = int(moved_hist.get(int(r.opt.moved), 0)) + 1
		if str(r.opt.get("source", "")) == "plantada":
			tall_planted += 1
	print("  estructura, caminos, hashes y métricas de todas: %.0f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	# ninguna se resuelve caminando (muestra repartida)
	var step := maxi(rooms.size() / maxi(sample, 1), 1)
	var checked := 0
	for i in range(0, rooms.size(), step):
		var r: Dictionary = rooms[i]
		var t = RoomLib.build_state(r)
		var pl: Dictionary = Solver.solve(t, r.h + 1, {"max_states": 40000, "goal_ids": t.goal_ids, "no_grab": true, "max_ms": 8000})
		check(pl.status == "unsolvable", "la sala %s %d no se resuelve caminando (%s)" % [r.shape, r.h, pl.status])
		checked += 1
	print("  sin atajo caminando: %d salas comprobadas" % checked)
	var keys: Array = per.keys()
	keys.sort()
	var by_shape := {}
	for k in keys:
		var parts: PackedStringArray = k.split("|")
		if not by_shape.has(parts[0]):
			by_shape[parts[0]] = []
		by_shape[parts[0]].append("%s:%d" % [parts[1], per[k]])
	print("salas por forma y altura (altura:cantidad):")
	for sh in RoomLib.SHAPES:
		print("  %-4s %s" % [sh, " ".join(by_shape.get(sh, []))])
	var missing: Array = []
	for pair in RoomLib.combos():
		if not per.has("%s|%d" % [pair[0], pair[1]]):
			missing.append("%s %d" % [pair[0], pair[1]])
	print("combinaciones forma-altura sin salas (%d de %d): %s" % [missing.size(), RoomLib.combos().size(), ", ".join(missing)])
	var mk: Array = moved_hist.keys()
	mk.sort()
	var mh := []
	for k in mk:
		mh.append("%d:%d" % [k, moved_hist[k]])
	print("bloques distintos que hay que mover (cantidad:salas): ", " ".join(mh))
	print("pruebas: ", proofs, "  con camino plantado: ", tall_planted)
	print("familias distintas: %d, patrones distintos: %d" % [fams.size(), pats.size()])
	print("check_library terminado, fallos: ", fails)
	quit(1 if fails > 0 else 0)
