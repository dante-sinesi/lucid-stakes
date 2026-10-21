extends SceneTree
## EXPERIMENTO de paredes colgantes (scripts/pared_gen.gd), aislado del juego: arma paredes que cuelgan de la salida, las resuelve con el A* exacto y las mejora con escalada guiada por el solucionador.
## Modos: pared (plana, 6 de ancho, 2 de espesor), cilindro (anillo 6x6 con pozo, una salida), cilindro4 (cuatro salidas, una por cara, con el costo de cada cara).
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/probe_paredes.gd -- MODO [SALAS=4] [MS_POR_SALA=90000] [ALTURAS=5,6] [BLOQUES=14] [SEMILLA=1]
const RoomLib := preload("res://scripts/room_lib.gd")
const Pack := preload("res://scripts/room_pack.gd")
const Gen := preload("res://scripts/pared_gen.gd")


func _cells(list: Array) -> Array:
	var out: Array = []
	for c in list:
		out.append([c.x, c.y])
	return out


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "pared"
	var want := int(args[1]) if args.size() > 1 else 4
	var budget := int(args[2]) if args.size() > 2 else 90000
	var hs: Array = []
	for t in (args[3] if args.size() > 3 else "5,6").split(","):
		hs.append(int(t))
	var n := int(args[4]) if args.size() > 4 else 14
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args[5]) if args.size() > 5 else 1
	var kind := "pared" if mode == "pared" else "cilindro"
	var faces := 4 if mode == "cilindro4" else 1
	var out: Array = []
	var dump := FileAccess.open(ProjectSettings.globalize_path("capturas/paredes_%s.jsonl" % mode), FileAccess.WRITE)
	var guard := 0
	var t0 := Time.get_ticks_msec()
	while out.size() < want and guard < 600:
		guard += 1
		var h: int = hs[guard % hs.size()]
		var start := Gen.make(rng, kind, h, n + (4 if faces > 1 else 0), faces)
		if RoomLib.validate_structure(start) != "":
			continue
		var costs0 := Gen.face_costs(start)
		if Gen.score(start, costs0) < 0.0:
			continue
		var best := Gen.climb(rng, start, budget)
		if best.is_empty():
			continue
		var c1: Array = best.costs
		var txt0 := ""
		for c in costs0:
			txt0 += ("%d/%d " % [c.moves, c.grabs]) if c.ok else "x "
		var txt1 := ""
		for c in c1:
			txt1 += ("%d pasos/%d empujes " % [c.moves, c.grabs]) if c.ok else "sin solución "
		out.append(best)
		print("%s %d (h=%d, %d bloques): antes [%s] -> ahora [%s]· %d pruebas, %d mejoras" % [mode, out.size(), h, RoomLib.block_count(best), txt0.strip_edges(), txt1.strip_edges(), int(best.opt.tries), int(best.opt.accepted)])
		var cols := {}
		for c in best.cols:
			cols["%d,%d" % [c.x, c.y]] = best.cols[c]
		var exits: Array = [best.exit] + Array(best.get("exits_extra", []))
		dump.store_line(JSON.stringify({"modo": mode, "h": h, "cols": cols, "exits": _cells(exits), "floor": _cells(best.floor_cells), "profundidad": 4 if kind == "pared" else 8, "costos": c1.map(func(c): return [c.ok, c.moves, c.grabs])}))
	dump.close()
	Pack.write_library(out, ProjectSettings.globalize_path("bibliotecas/paredes_%s.rooms" % mode), true)
	print("guardadas %d en %.0f s" % [out.size(), float(Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)
