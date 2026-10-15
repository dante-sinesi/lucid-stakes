extends SceneTree
## Experimento: ¿una búsqueda voraz (A* con la heurística muy pesada) resuelve las salas que el A* normal no alcanza a resolver con su tope? Se toman cambios de salas del archivo del minero que terminan "limit"
## con el tope normal y se prueban con distintos pesos. Mide cuántas resuelve, cuántos empujes y pasos tienen sus caminos (ya sin vueltas) y cuánto tarda.
## Variables: N (cambios a probar, 150), SEED (5), POP (segundos de minería para tener un archivo, 40), WEIGHTS ("2,5,20"), CAPMULT (tope para las voraces respecto del normal, 4).
const RoomLib := preload("res://scripts/room_lib.gd")
const RoomMiner := preload("res://scripts/room_miner.gd")
const Solver := preload("res://scripts/solver.gd")


func _env(name: String, def: String) -> String:
	return OS.get_environment(name) if OS.get_environment(name) != "" else def


## Condición necesaria para poder subir h pisos: en cada nivel L de 1 a h - 1 tiene que haber al menos (h - L) bloques de ese nivel o de más arriba (un bloque no sube nunca: sólo cae o se mueve de costado,
## y para pararse en el nivel L hace falta un bloque en ese nivel). Los del pilar no cuentan.
func material_ok(room: Dictionary) -> bool:
	var h: int = room.h
	var counts: Array = []
	counts.resize(h + 2)
	counts.fill(0)
	for c in room.cols:
		var ks: String = room.cols[c]
		for i in ks.length():
			counts[i + 1] += 1
	var acc := 0
	for L in range(h - 1, 0, -1):
		acc += int(counts[L])
		if acc < h - L:
			return false
	return true


func _init() -> void:
	var m := RoomMiner.new({"seed": int(_env("SEED", "5")), "write": false, "shapes": RoomLib.SHAPES, "h_lo": 5, "h_hi": 8, "verify_p": 0.0, "prune": false})
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(_env("POP", "40")) * 1000:
		m.step()
	print("archivo de partida: %d salas" % m.archive_size())
	var weights: Array = []
	for w in _env("WEIGHTS", "").split(",", false):
		weights.append(float(w))
	var capmult := float(_env("CAPMULT", "4"))
	var n := int(_env("N", "150"))
	var normal_ok := 0
	var limit_cases: Array = []
	var other := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var normal_grabs: Array = []
	var mat_total := 0
	var mat_bad := 0
	var mat_bad_but_solved := 0
	var mat_bad_limit := 0
	for _i in n:
		var combo := m.pick_combo()
		var par := m.pick_parent(combo[0], combo[1])
		if par.is_empty():
			continue
		var child := m.mutate(par)
		if RoomLib.validate_structure(child) != "":
			continue
		RoomLib.finalize(child)
		var ev := RoomLib.evaluate(child, m.eval_opts(child.h))
		var mok := material_ok(child)
		mat_total += 1
		if not mok:
			mat_bad += 1
			if ev.ok:
				mat_bad_but_solved += 1
			elif str(ev.why) == "limit":
				mat_bad_limit += 1
		if ev.ok:
			normal_ok += 1
			normal_grabs.append(int(ev.grabs))
		elif str(ev.why) == "limit":
			limit_cases.append(child)
		else:
			other[str(ev.why)] = int(other.get(str(ev.why), 0)) + 1
	print("cambios probados: %d | el A* normal resuelve %d (empujes medios %.1f, máx %d) | terminan en límite %d | otros %s" % [n, normal_ok, float(normal_grabs.reduce(func(a, b): return a + b, 0)) / maxf(normal_grabs.size(), 1), (normal_grabs.max() if not normal_grabs.is_empty() else 0), limit_cases.size(), str(other)])
	var big := int(_env("BIG", "0"))
	for i in mini(big, limit_cases.size()):
		var room: Dictionary = limit_cases[i]
		var t = RoomLib.build_state(room)
		var tb := Time.get_ticks_msec()
		var res: Dictionary = Solver.solve(t, room.h + 1, {"max_states": 400000, "goal_ids": t.goal_ids, "max_ms": 100000})
		print("  sala en límite %d (%s %d pisos): con 400 000 estados y 100 s -> %s, %d estados, %s pasos, %.0f s" % [i, room.shape, room.h, str(res.status), int(res.states), str(res.get("moves", -1)), (Time.get_ticks_msec() - tb) / 1000.0])
	var lim_bad := 0
	for room in limit_cases:
		if not material_ok(room):
			lim_bad += 1
	print("condición de material por nivel: no la cumplen %d de %d cambios; de ésos %d salieron resueltos (si fuera cierta la condición deberían ser 0) y %d terminaron en límite. De las %d en límite, %d no la cumplen." % [mat_bad, mat_total, mat_bad_but_solved, mat_bad_limit, limit_cases.size(), lim_bad])
	for w in weights:
		var solved := 0
		var grabs_sum := 0
		var grabs_max := 0
		var moves_sum := 0
		var secs := 0.0
		var hist := {}
		var t1 := Time.get_ticks_msec()
		for room in limit_cases:
			var o := m.eval_opts(room.h)
			o["cap"] = int(o.cap * capmult)
			o["max_ms"] = int(o.max_ms * capmult)
			o["h_weight"] = w
			var ev := RoomLib.evaluate(room, o)
			if ev.ok:
				var p := RoomLib.simplify_path(room, ev.path)
				var st := RoomLib.path_stats(room, p)
				solved += 1
				grabs_sum += int(st.grabs)
				grabs_max = maxi(grabs_max, int(st.grabs))
				moves_sum += p.size()
				hist[int(st.grabs)] = int(hist.get(int(st.grabs), 0)) + 1
		secs = (Time.get_ticks_msec() - t1) / 1000.0
		print("peso %.0f, tope x%.0f: resuelve %d de %d de los que el normal no alcanzó | empujes medios %.1f, máx %d | pasos medios %.0f | %.1f s por sala | empujes (cantidad:salas) %s" % [w, capmult, solved, limit_cases.size(), float(grabs_sum) / maxf(solved, 1), grabs_max, float(moves_sum) / maxf(solved, 1), secs / maxf(limit_cases.size(), 1), str(hist)])
	quit()
