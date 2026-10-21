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


## Fotos del camino (unas 9: el principio, el final y partes del medio): bloques sueltos con su tipo, el jugador y si está colgado.
func _frames(room: Dictionary, path: Array) -> Array:
	var t = RoomLib.build_state(room)
	var out: Array = []
	var every := maxi(int(ceil(float(path.size()) / 8.0)), 1)
	for i in range(0, path.size() + 1):
		if i % every == 0 or i == path.size():
			var bl: Array = []
			for id in t.positions:
				var p: Vector3i = t.positions[id]
				if not t.fixed.has(p):
					bl.append([p.x, p.y, p.z, RoomLib.CHAR_OF_KIND.get(t.kind_at(p), "n")])
			out.append({"paso": i, "bloques": bl, "jugador": [t.player.x, t.player.y, t.player.z], "colgado": t.hang_dir != Vector3i.ZERO, "perdido": t.lost})
		if i < path.size():
			t.try_action(path[i].dir, path[i].mode)
	return out


func kind_of(mode: String) -> String:
	return "pared" if mode == "pared" else "cilindro"


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
	# opciones con nombre (después de los 8 primeros argumentos): esp=i,h,c,s,k,t max=4 muertes=1 podar=1 pb=0 pc=3 T=0 cant=1 elite=ruta caras=0 ancho=6 est=0 pcam=40
	var o := {}
	for i in range(8, a.size()):
		var kv := str(a[i]).split("=", true, 1)
		if kv.size() == 2:
			o[kv[0]] = kv[1]
	var kinds: Array = []
	if str(o.get("esp", "no")) != "no":
		kinds = Array(str(o.esp).split(","))
	var spec_tries := int(o.get("max", 4))
	var deaths := str(o.get("muertes", "0")) == "1"
	var podar := str(o.get("podar", "1")) == "1"
	Gen.peso_bloques = float(o.get("pb", 0.0))
	Gen.peso_cobertura = float(o.get("pc", 3.0))
	Gen.temperatura = float(o.get("T", 0.0))
	Gen.cambiar_cantidad = str(o.get("cant", "1")) == "1"
	Gen.peso_caras = float(o.get("caras", 0.0))
	Base.ancho = int(o.get("ancho", 6))
	Base.espesor = int(o.get("esp_pared", 2))
	Gen.piso_suave = str(o.get("suave", "0")) == "1"
	Gen.peso_estados = float(o.get("est", 0.0))
	Gen.peso_dispersion = float(o.get("disp", 2.0))
	Gen.peso_caminata = float(o.get("pcam", 40.0))
	var elite: Array = []
	if str(o.get("elite", "no")) != "no":
		var ep := ProjectSettings.globalize_path(str(o.elite))
		if FileAccess.file_exists(ep):
			for r in Pack.load_library(ep):
				if (mode == "pared") == (str(r.shape) == "P6"):
					elite.append(r)
	var dump := FileAccess.open(ProjectSettings.globalize_path("capturas/p2_%s.jsonl" % tag), FileAccess.WRITE)
	var out: Array = []
	var guard := 0
	var t0 := Time.get_ticks_msec()
	while out.size() < want and guard < 3000:
		guard += 1
		var h: int = hs[guard % hs.size()]
		var start := Gen.make(rng, mode, h, n, faces)
		if not elite.is_empty() and rng.randf() < 0.8:   # (se parte de una de las mejores, con unos cambios al azar para no repetir)
			start = RoomLib.copy_room(elite[rng.randi_range(0, elite.size() - 1)])
			start["mass"] = Base.mass(kind_of(mode))
			h = int(start.h)
			for k in rng.randi_range(2, 8):
				var mv := Gen.mutate2(rng, start, kinds, spec_tries)
				if not mv.is_empty() and RoomLib.validate_structure(mv) == "":
					start = mv
		if RoomLib.validate_structure(start) != "":
			continue
		var c0 := Base.face_costs(start)
		if Gen.score(start, c0) < 0.0:
			continue
		var best: Dictionary = Gen.climb2(rng, start, kinds, spec_tries, budget)   # (INTENTOS_ESPECIALES es el máximo de especiales)
		if best.is_empty():
			continue
		best = Gen.podar_salidas(best)
		var quitados := 0
		if podar and (best.get("exits_extra", []) as Array).is_empty():   # (con una sola salida: se saca el relleno que el camino más corto no usa)
			var r0 := RoomLib.copy_room(best)
			r0["path"] = best.costs[0].path
			var pr: Dictionary = RoomLib.prune(r0, rng, 40000)
			quitados = int(pr.removed)
			if quitados > 0:
				var pruned: Dictionary = pr.room
				var cp := Base.face_costs(pruned)
				if Gen.score(pruned, cp) >= 0.0:
					pruned["costs"] = cp
					pruned["opt"] = best.opt.duplicate()
					best = pruned
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
		print("%s %d (h=%d, %d bloques, %d salidas): caras [%s] · derrumbes %d en %d pasos%s · especiales %s (necesarios %d) · sacó %d de relleno · puntaje %d · %d pruebas" % [tag, out.size(), h, RoomLib.block_count(best), 1 + (best.get("exits_extra", []) as Array).size(), txt.strip_edges(), int(col.movimientos_que_derrumban), int(col.pasos_con_riesgo), (" · muertes %d en %d pasos" % [int(die.movimientos_mortales), int(die.pasos_con_muerte)]) if deaths else "", str(sp), int(best.opt.get("especiales_necesarios", 0)), quitados, int(best.opt.get("score", 0)), int(best.opt.get("tries", 0))])
		var cols := {}
		for c in best.cols:
			cols["%d,%d" % [c.x, c.y]] = best.cols[c]
		var exits: Array = [best.exit] + Array(best.get("exits_extra", []))
		dump.store_line(JSON.stringify({"etiqueta": tag, "h": h, "cols": cols, "exits": _cells(exits), "floor": _cells(best.floor_cells), "profundidad": (Base.espesor + 2) if mode == "pared" else 8, "costos": best.costs.map(func(c): return [c.ok, c.moves, c.grabs]), "derrumbes": int(col.movimientos_que_derrumban), "especiales": sp, "frames": _frames(best, rr.path), "camino": RoomLib.path_string(rr.path)}))
	dump.close()
	Pack.write_library(out, ProjectSettings.globalize_path("bibliotecas/p2_%s.rooms" % tag), true)
	print("guardadas %d en %.0f s" % [out.size(), float(Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)
