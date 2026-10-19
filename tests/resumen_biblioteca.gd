extends SceneTree
## Resumen de una biblioteca .rooms o .jsonl: GAME_SANDBOX=1 godot --headless --path . -s tests/resumen_biblioteca.gd -- ARCHIVO [ARCHIVO_A_COMPARAR]
const Pack := preload("res://scripts/room_pack.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var rooms: Array = Pack.load_library(args[0])
	print("== ", args[0], ": ", rooms.size(), " salas")
	if rooms.size() > 0:
		print("ejemplo de campos: ", rooms[0].keys(), " opt: ", rooms[0].opt)
	_stats(rooms)
	if args.size() > 1:
		var other: Array = Pack.load_library(args[1])
		var ids := {}
		for r in other:
			ids[r.id] = true
		var nuevas := 0
		for r in rooms:
			if not ids.has(r.id):
				nuevas += 1
		print("== comparando con ", args[1], ": ", other.size(), " salas; en la primera y no en la segunda: ", nuevas)
	quit(0)


func _stats(rooms: Array) -> void:
	var by_h := {}
	var by_shape := {}
	var by_origin := {}
	var by_proof := {}
	var kinds := {}
	var seen := {}
	var dup := 0
	var sums := {"moves": 0.0, "grabs": 0.0, "moved": 0.0, "diff": 0.0, "reach": 0.0}
	var diff_bins := [0, 0, 0, 0, 0]
	var mx := {"moves": 0, "grabs": 0, "moved": 0}
	for r in rooms:
		by_h[int(r.h)] = int(by_h.get(int(r.h), 0)) + 1
		by_shape[str(r.shape)] = int(by_shape.get(str(r.shape), 0)) + 1
		by_origin[str(r.origin)] = int(by_origin.get(str(r.origin), 0)) + 1
		var pf := str(r.opt.get("proof", "?"))
		by_proof[pf] = int(by_proof.get(pf, 0)) + 1
		if seen.has(r.id):
			dup += 1
		seen[r.id] = true
		for k in sums:
			sums[k] += float(r.opt.get(k, 0))
		for k in mx:
			mx[k] = maxi(int(mx[k]), int(r.opt.get(k, 0)))
		diff_bins[clampi(int(float(r.opt.get("diff", 0)) * 5.0), 0, 4)] += 1
		for c in r.cols.values():
			for ch in str(c):
				kinds[ch] = int(kinds.get(ch, 0)) + 1
	var n := float(maxi(rooms.size(), 1))
	print("alturas (pisos): ", _sorted(by_h))
	print("formas: ", _sorted(by_shape))
	print("origen: ", _sorted(by_origin))
	print("prueba: ", _sorted(by_proof))
	print("ids repetidos: ", dup)
	print("promedios: pasos %.1f · agarres %.1f · bloques movidos %.1f · dificultad %.0f %% · alcance %.2f" % [sums.moves / n, sums.grabs / n, sums.moved / n, 100.0 * sums.diff / n, sums.reach / n])
	print("máximos: ", mx)
	print("dificultad por quinto (0-20, 20-40, 40-60, 60-80, 80-100): ", diff_bins)
	print("letras de bloques en las columnas (cuántos): ", _sorted(kinds))


func _sorted(d: Dictionary) -> String:
	var keys := d.keys()
	keys.sort()
	var out: Array[String] = []
	for k in keys:
		out.append("%s=%d" % [str(k), int(d[k])])
	return ", ".join(out)
