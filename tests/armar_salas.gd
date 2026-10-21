extends SceneTree
## Arma la biblioteca por archivos que viaja con el juego (data/salas/): junta las bibliotecas que se le pasan sin repetidas, deja sólo las salas de MENOS de ALTURA pisos y las reparte por
## calificación de a 5 % (r00 a r19; las L y las U van aparte, con g en vez de r) en archivos de TAMANO salas, en un orden mezclado fijo. Escribe también data/salas/indice.json.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/armar_salas.gd -- CARPETA_SALIDA ALTURA TAMANO ENTRADA1.rooms ENTRADA2.rooms ...
const Pack := preload("res://scripts/room_pack.gd")
const RoomPool := preload("res://scripts/room_pool.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := ProjectSettings.globalize_path(args[0])
	var max_h := int(args[1])
	var size := int(args[2])
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):   # (se arma de nuevo: no quedan archivos viejos)
		DirAccess.remove_absolute(dir.path_join(f))
	var seen := {}
	var cells := {}
	var total := 0
	var skipped_h := 0
	for i in range(3, args.size()):
		for r in Pack.load_library(args[i]):
			if seen.has(r.id):
				continue
			seen[r.id] = true
			if int(r.h) >= max_h:
				skipped_h += 1
				continue
			var key := "%s%02d" % ["g" if (r.shape == "L" or r.shape == "U") else "r", clampi(int(RoomPool.rating(r) * 20.0), 0, 19)]
			if not cells.has(key):
				cells[key] = []
			cells[key].append(r)
			total += 1
		print("%s leída, van %d salas" % [args[i].get_file(), total])
	var index := {}
	var files_total := 0
	for key in cells:
		var list: Array = cells[key]
		list.sort_custom(func(a, b): return hash(a.id) < hash(b.id))   # (mezcladas, siempre igual)
		var names: Array = []
		var n := 0
		for from in range(0, list.size(), size):
			var name := "%s_%03d.rooms" % [key, n]
			Pack.write_library(list.slice(from, from + size), dir.path_join(name), true)
			names.append(name)
			n += 1
			files_total += 1
		index[key] = names
	var f := FileAccess.open(dir.path_join("indice.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"formato": 1, "salas": total, "archivos": files_total, "tamano": size, "altura_maxima": max_h - 1, "chunks": index}))
	f.close()
	print("listo: %d salas en %d archivos (%d descartadas por altura >= %d)" % [total, files_total, skipped_h, max_h])
	quit(0)
