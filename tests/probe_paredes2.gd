extends SceneTree
## EXPERIMENTO de paredes colgantes, versión 2 (scripts/pared_gen2.gd): cantidad de salidas, riesgo, bloques especiales.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/probe_paredes2.gd -- ETIQUETA MODO SALAS MS_POR_SALA ALTURAS BLOQUES CARAS SEMILLA [ESPECIALES=no|i,h,c,s,k,t] [INTENTOS_ESPECIALES=150] [MUERTES=0|1]
const RoomLib := preload("res://scripts/room_lib.gd")
const Pack := preload("res://scripts/room_pack.gd")
const Base := preload("res://scripts/pared_gen.gd")
const Gen := preload("res://scripts/pared_gen2.gd")


func _cells(list: Array) -> Array:
	var out: Array = []
	for c in list:
		out.append([c.x, c.y])
	return out


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var tag: String = a[0]
	var mode: String = a[1]
	var want := int(a[2])
	var budget := int(a[3])
	var hs: Array = []
	for t in str(a[4]).split(","):
		hs.append(int(t))
	var n := int(a[5])
	var faces := int(a[6])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(a[7])
	var kinds: Array = []
	if a.size() > 8 and a[8] != "no":
		kinds = Array(str(a[8]).split(","))
	var spec_tries := int(a[9]) if a.size() > 9 else 150
	var deaths := a.size() > 10 and a[10] == "1"
	var dump := FileAccess.open(ProjectSettings.globalize_path("capturas/p2_%s.jsonl" % tag), FileAccess.WRITE)
	var out: Array = []
	var guard := 0
	var t0 := Time.get_ticks_msec()
	while out.size() < want and guard < 800:
		guard += 1
		var h: int = hs[guard % hs.size()]
		var start := Gen.make(rng, mode, h, n, faces)
		if RoomLib.validate_structure(start) != "":
			continue
		var c0 := Base.face_costs(start)
		if Gen.score(start, c0) < 0.0:
			continue
		var best: Dictionary
		if kinds.is_empty():
			best = Gen.climb(rng, start, budget)
		else:
			best = Gen.climb2(rng, start, kinds, spec_tries, budget)   # (con especiales: INTENTOS_ESPECIALES pasa a ser el máximo de especiales)
		if best.is_empty():
			continue
		best = Gen.podar_salidas(best)
		var tb = RoomLib.build_state(best)
		var risk := {}
		var main_cost: Dictionary = {}
		for c in best.costs:
			if c.ok:
				main_cost = c
				break
		# el riesgo se mide sobre el camino de la primera salida que se resuelve
		var rr := RoomLib.copy_room(best)
		rr["path"] = main_cost.get("path", [])
		var col := Gen.colapsos(rr)
		var die := {}
		if deaths:
			die = Gen.muertes(rr)
		var txt := ""
		for c in best.costs:
			txt += ("%dp/%de " % [c.moves, c.grabs]) if c.ok else "x "
		var sp: Dictionary = best.opt.get("especiales", {})
		out.append(best)
		print("%s %d (h=%d, %d bloques, %d salidas): caras [%s] · derrumbes %d en %d pasos%s · especiales %s (probados %d) · puntaje %d · %d pruebas" % [tag, out.size(), h, RoomLib.block_count(best), 1 + (best.get("exits_extra", []) as Array).size(), txt.strip_edges(), int(col.movimientos_que_derrumban), int(col.pasos_con_riesgo), (" · muertes %d en %d pasos" % [int(die.movimientos_mortales), int(die.pasos_con_muerte)]) if deaths else "", str(sp), int(best.opt.get("especiales_necesarios", 0)), int(best.opt.get("score", 0)), int(best.opt.get("tries", 0))])
		var cols := {}
		for c in best.cols:
			cols["%d,%d" % [c.x, c.y]] = best.cols[c]
		var exits: Array = [best.exit] + Array(best.get("exits_extra", []))
		dump.store_line(JSON.stringify({"etiqueta": tag, "h": h, "cols": cols, "exits": _cells(exits), "floor": _cells(best.floor_cells), "profundidad": 4 if mode == "pared" else 8, "costos": best.costs.map(func(c): return [c.ok, c.moves, c.grabs]), "derrumbes": int(col.movimientos_que_derrumban), "especiales": sp}))
	dump.close()
	Pack.write_library(out, ProjectSettings.globalize_path("bibliotecas/p2_%s.rooms" % tag), true)
	print("guardadas %d en %.0f s" % [out.size(), float(Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)
