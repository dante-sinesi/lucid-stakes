extends RefCounted
## Empaquetador de la biblioteca: junta los .jsonl de todas las copias del minero (y del Estudio), se queda con el mejor registro de cada sala, revalida con las reglas actuales
## (descarta lo que ya no funciona) y escribe un solo archivo. Con `compress` el archivo va comprimido (zstd) y es el que viaja con el juego.
## Uso desde la consola: Godot --headless --path . res://scenes/pack.tscn -- --in=CARPETA --out=ARCHIVO [--compress] [--min-moved=2]

const RoomLib := preload("res://scripts/room_lib.gd")


## Junta los .jsonl de `in_dir` (menos `out_path`). {rooms, read, bad, old_rules, invalid, dup, dropped_weak}.
static func collect(in_dir: String, out_path: String, opts: Dictionary = {}) -> Dictionary:
	var min_moved := int(opts.get("min_moved", 1))
	var res := {"rooms": [], "read": 0, "bad": 0, "old_rules": 0, "invalid": 0, "dup": 0, "weak": 0, "files": 0}
	var d := DirAccess.open(in_dir)
	if d == null:
		return res
	var best := {}
	var files: Array = []
	for f in d.get_files():
		if f.ends_with(".jsonl") and in_dir.path_join(f) != out_path:
			files.append(f)
	files.sort()
	for f in files:
		var got := RoomLib.read_file(in_dir.path_join(f))
		res.files += 1
		res.bad += int(got.bad)
		for r in got.rooms:
			res.read += 1
			if best.has(r.id):
				res.dup += 1
				best[r.id] = RoomLib.better(best[r.id], r)
			else:
				best[r.id] = r
	var ids: Array = best.keys()
	ids.sort()
	for id in ids:
		var r: Dictionary = best[id]
		if int(r.rules) != RoomLib.RULES_VERSION:
			res.old_rules += 1
			continue
		if RoomLib.validate_structure(r) != "" or not RoomLib.replay(r, r.path).ok:
			res.invalid += 1
			continue
		var again := RoomLib.copy_room(r)
		RoomLib.finalize(again)
		if again.id != r.id:
			res.invalid += 1
			continue
		if bool(opts.get("simplify", true)):   # (saca las vueltas de los caminos viejos: es exacto)
			var shorter := RoomLib.simplify_path(r, r.path)
			if shorter.size() < r.path.size():
				var src: String = str(r.opt.get("source", ""))
				var proof: String = str(r.opt.get("proof", "sin_probar"))
				RoomLib.apply_result(r, shorter, "sin_probar" if proof == "exacta" else proof, int(r.opt.get("lower", r.h)), int(r.opt.get("states", 0)))
				if src != "":
					r.opt.source = src
				res["shortened"] = int(res.get("shortened", 0)) + 1
		if int(r.opt.get("moved", 0)) < min_moved and r.origin != "autor":
			res.weak += 1
			continue
		res.rooms.append(r)
	return res


static func write_library(rooms: Array, out_path: String, compress := false) -> bool:
	if not compress:
		return RoomLib.write_file(out_path, rooms)
	var tmp := out_path + ".tmp"
	var f := FileAccess.open_compressed(tmp, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return false
	for r in rooms:
		f.store_line(RoomLib.to_line(r))
	f.close()
	if FileAccess.file_exists(out_path):
		DirAccess.remove_absolute(out_path)
	return DirAccess.rename_absolute(tmp, out_path) == OK


## Lee una biblioteca, comprimida o no (se distingue por la extensión .rooms).
static func load_library(path: String) -> Array:
	var rooms: Array = []
	if not path.ends_with(".rooms"):
		return RoomLib.read_file(path).rooms
	if not FileAccess.file_exists(path):
		return rooms
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return rooms
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		var r := RoomLib.from_line(line)
		if not r.is_empty():
			rooms.append(r)
	f.close()
	return rooms


static func pack(in_dir: String, out_path: String, opts: Dictionary = {}) -> Dictionary:
	var res := collect(in_dir, out_path, opts)
	var ok := write_library(res.rooms, out_path, bool(opts.get("compress", out_path.ends_with(".rooms"))))
	res["written"] = ok
	var per_shape := {}
	for r in res.rooms:
		per_shape[r.shape] = int(per_shape.get(r.shape, 0)) + 1
	res["per_shape"] = per_shape
	res["kept"] = res.rooms.size()
	return res
