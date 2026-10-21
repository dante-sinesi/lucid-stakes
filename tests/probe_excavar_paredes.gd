extends SceneTree
## EXPERIMENTO: mejora paredes colgantes con el excavador nativo (scripts/step_excavator.gd) a través de scripts/pared_pasos.gd. Parte de las mejores paredes (bibliotecas/p2_elite.rooms) o de paredes nuevas,
## las convierte en pasos, excava y muestra antes y después (pasos, empujes, bloques movidos, dificultad = empujes sobre pasos). Escribe capturas/p2_<ETIQUETA>.jsonl para dibujarlas.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/probe_excavar_paredes.gd -- ETIQUETA SALAS RONDAS NODOS SEMILLA [ELITE=bibliotecas/p2_elite.rooms|no] [ALTURA=6] [BLOQUES=18]
const RoomLib := preload("res://scripts/room_lib.gd")
const Pack := preload("res://scripts/room_pack.gd")
const Base := preload("res://scripts/pared_gen.gd")
const Gen := preload("res://scripts/pared_gen2.gd")
const StepLib := preload("res://scripts/step_lib.gd")
const Pasos := preload("res://scripts/pared_pasos.gd")
const StepExcavator := preload("res://scripts/pared_excavador.gd")


func _cells(list: Array) -> Array:
	var out: Array = []
	for c in list:
		out.append([c.x, c.y])
	return out


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


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var tag: String = a[0]
	var want := int(a[1])
	var rounds := int(a[2])
	var nodes := int(a[3])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(a[4])
	var elite_path: String = a[5] if a.size() > 5 else "bibliotecas/p2_elite.rooms"
	var h := int(a[6]) if a.size() > 6 else 6
	var n := int(a[7]) if a.size() > 7 else 18
	var elite: Array = []
	if elite_path != "no" and FileAccess.file_exists(ProjectSettings.globalize_path(elite_path)):
		for r in Pack.load_library(ProjectSettings.globalize_path(elite_path)):
			if str(r.shape) == "P6":
				elite.append(r)
	var ex := StepExcavator.new(int(a[4]))
	var dump := FileAccess.open(ProjectSettings.globalize_path("capturas/p2_%s.jsonl" % tag), FileAccess.WRITE)
	var out: Array = []
	var guard := 0
	var t0 := Time.get_ticks_msec()
	while out.size() < want and guard < 400:
		guard += 1
		var room: Dictionary
		if not elite.is_empty() and rng.randf() < 0.7:
			room = RoomLib.copy_room(elite[rng.randi_range(0, elite.size() - 1)])
		else:
			room = Gen.make(rng, "pared", h, n, 1)
		room["mass"] = Base.mass("pared")
		if RoomLib.validate_structure(room) != "":
			continue
		var step := Pasos.to_step(room)
		var ev0 := StepLib.evaluate(step, 600000, 8000, true)
		if not bool(ev0.ok):
			continue
		var arena: Array = Base.mass("pared")
		var res: Dictionary = ex.improve(step, arena, rounds, nodes, 800, 40, 24, 5)
		for l in ex.log:
			print("   ", l)
		ex.log.clear()
		var ev1: Dictionary = res.ev
		if not bool(ev1.ok):
			continue
		var best := Pasos.from_step(res.step, room)
		var cp := Base.face_costs(best)
		if Gen.score(best, cp) < 0.0 and false:
			continue
		var main_cost: Dictionary = cp[0] if cp[0].ok else {}
		var col := {"movimientos_que_derrumban": 0, "pasos_con_riesgo": 0}
		var frames: Array = []
		if not main_cost.is_empty():
			var rr := RoomLib.copy_room(best)
			rr["path"] = main_cost.path
			col = Gen.colapsos(rr)
			frames = _frames(best, rr.path)
		out.append(best)
		print("%s %d (h=%d, %d bloques): antes %dp/%de (dif %.2f) -> ahora %dp/%de, %d movidos (dif %.2f) · derrumbes %d · %d rondas · %.0f s" % [tag, out.size(), int(best.h), RoomLib.block_count(best), int(ev0.moves), int(ev0.grabs), float(ev0.diff), int(ev1.moves), int(ev1.grabs), int(ev1.moved), float(ev1.diff), int(col.movimientos_que_derrumban), int(res.rounds), float(Time.get_ticks_msec() - t0) / 1000.0])
		var cols := {}
		for c in best.cols:
			cols["%d,%d" % [c.x, c.y]] = best.cols[c]
		var sp := {}
		for c in best.cols:
			for ch in String(best.cols[c]):
				if ch != "n" and ch != ".":
					sp[ch] = int(sp.get(ch, 0)) + 1
		dump.store_line(JSON.stringify({"etiqueta": tag, "h": int(best.h), "cols": cols, "exits": _cells([best.exit]), "floor": _cells(best.floor_cells), "profundidad": 4, "costos": [[true, int(ev1.moves), int(ev1.grabs)]], "derrumbes": int(col.movimientos_que_derrumban), "especiales": sp, "frames": frames, "camino": RoomLib.path_string(main_cost.get("path", []))}))
	dump.close()
	Pack.write_library(out, ProjectSettings.globalize_path("bibliotecas/p2_%s.rooms" % tag), true)
	print("guardadas %d en %.0f s" % [out.size(), float(Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)
