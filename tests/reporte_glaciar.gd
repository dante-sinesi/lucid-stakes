extends SceneTree
## Reporte de una biblioteca de salas del Glaciar (.rooms): cuántas, cómo se reparten, resbalones, compañeros del hielo y las mejores.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/reporte_glaciar.gd -- ARCHIVO.rooms [SALIDA.txt]
const Pack := preload("res://scripts/room_pack.gd")

var lines: Array[String] = []


func say(t: String) -> void:
	lines.append(t)
	print(t)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var rooms: Array = Pack.load_library(args[0])
	say("REPORTE DE SALAS DEL GLACIAR · %s" % args[0])
	say("Salas: %d" % rooms.size())
	if rooms.is_empty():
		_finish(args)
		return
	var by_h := {}
	var by_shape := {}
	var proofs := {}
	var ids := {}
	var dup := 0
	var slides_hist := {}
	var ice_moved_hist := {}
	var ice_blocks_hist := {}
	var combos := {}
	var companion := {"i": 0, "h": 0, "c": 0, "s": 0}
	var pure_ice := 0
	var sums := {"moves": 0.0, "grabs": 0.0, "moved": 0.0, "diff": 0.0, "reach": 0.0, "slides": 0.0}
	var mx := {"moves": 0, "grabs": 0, "moved": 0, "slides": 0}
	var bins := [0, 0, 0, 0, 0]
	var candidates := 0
	var strong := 0
	for r in rooms:
		by_h[int(r.h)] = int(by_h.get(int(r.h), 0)) + 1
		by_shape[str(r.shape)] = int(by_shape.get(str(r.shape), 0)) + 1
		var pf := str(r.opt.get("proof", "?"))
		proofs[pf] = int(proofs.get(pf, 0)) + 1
		if ids.has(r.id):
			dup += 1
		ids[r.id] = true
		var sl := int(r.opt.get("slides", 0))
		slides_hist[mini(sl, 8)] = int(slides_hist.get(mini(sl, 8), 0)) + 1
		var im := int(r.opt.get("ice_moved", 0))
		ice_moved_hist[mini(im, 6)] = int(ice_moved_hist.get(mini(im, 6), 0)) + 1
		var n_ice := 0
		for c in r.cols.values():
			for ch in str(c):
				if ch == "i":
					n_ice += 1
		ice_blocks_hist[mini(n_ice, 8)] = int(ice_blocks_hist.get(mini(n_ice, 8), 0)) + 1
		var sp := str(r.opt.get("specials", ""))
		var key := "".join(Array(sp.split("")).filter(func(x): return x != ""))
		combos[key] = int(combos.get(key, 0)) + 1
		for ch in companion:
			if sp.contains(ch):
				companion[ch] += 1
		if sp == "i":
			pure_ice += 1
		for k in sums:
			sums[k] += float(r.opt.get(k, 0))
		for k in mx:
			mx[k] = maxi(int(mx[k]), int(r.opt.get(k, 0)))
		var d := float(r.opt.get("diff", 0))
		bins[clampi(int(d * 5.0), 0, 4)] += 1
		if sl >= 3 and d >= 0.3 and float(r.opt.get("reach", 0)) >= 0.5:
			candidates += 1
		if sl >= 4 and d >= 0.35 and float(r.opt.get("reach", 0)) >= 0.6:
			strong += 1
	var n := float(rooms.size())
	say("Ids repetidos: %d · prueba: %s" % [dup, _fmt(proofs)])
	say("Alturas (pisos): %s" % _fmt(by_h))
	say("Formas: %s" % _fmt(by_shape))
	say("Promedios: %.1f pasos · %.1f agarres · %.1f bloques distintos movidos · dificultad %.0f %% · alcance %.2f · %.1f resbalones" % [sums.moves / n, sums.grabs / n, sums.moved / n, 100.0 * sums.diff / n, sums.reach / n, sums.slides / n])
	say("Máximos: %s" % str(mx))
	say("Dificultad por quinto (0-20, 20-40, 40-60, 60-80, 80-100 %%): %s" % str(bins))
	say("Resbalones en el camino (8 = 8 o más): %s" % _fmt(slides_hist))
	say("Bloques de hielo movidos (6 = 6 o más): %s" % _fmt(ice_moved_hist))
	say("Bloques de hielo por sala (8 = 8 o más): %s" % _fmt(ice_blocks_hist))
	say("Con otros especiales además del hielo: %d de %d (%.0f %%) · hielo puro: %d" % [rooms.size() - pure_ice, rooms.size(), 100.0 * float(rooms.size() - pure_ice) / n, pure_ice])
	say("Especiales que quedaron en la sala (por tipo): hielo %d · pesado %d · agrietado %d · pinchos %d" % [companion.i, companion.h, companion.c, companion.s])
	say("Combinaciones: %s" % _fmt(combos))
	say("Candidatas a aprobar (3 o más resbalones, dificultad 30 %% o más, alcance 0.5 o más): %d" % candidates)
	say("Muy buenas (4 o más resbalones, dificultad 35 %% o más, alcance 0.6 o más): %d" % strong)
	var sorted := rooms.duplicate()
	sorted.sort_custom(func(a, b):
		var sa := int(a.opt.get("slides", 0))
		var sb := int(b.opt.get("slides", 0))
		if sa != sb:
			return sa > sb
		return float(a.opt.get("diff", 0)) > float(b.opt.get("diff", 0)))
	say("Las 12 con más resbalones (id · forma · pisos · pasos · agarres · distintos movidos · resbalones · dificultad · especiales):")
	for i in mini(12, sorted.size()):
		var r: Dictionary = sorted[i]
		say("  %s · %s · %d · %d · %d · %d · %d · %.0f %% · %s" % [str(r.id).substr(0, 10), r.shape, r.h, int(r.opt.get("moves", 0)), int(r.opt.get("grabs", 0)), int(r.opt.get("moved", 0)), int(r.opt.get("slides", 0)), 100.0 * float(r.opt.get("diff", 0)), str(r.opt.get("specials", ""))])
	_finish(args)


func _fmt(d: Dictionary) -> String:
	var keys := d.keys()
	keys.sort()
	var out: Array[String] = []
	for k in keys:
		out.append("%s=%d" % [str(k), int(d[k])])
	return ", ".join(out)


func _finish(args: PackedStringArray) -> void:
	if args.size() > 1:
		var f := FileAccess.open(args[1], FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(lines) + "\n")
			f.close()
	quit(0)
