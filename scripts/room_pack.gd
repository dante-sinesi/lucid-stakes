extends RefCounted
## Empaquetador de la biblioteca: junta los .jsonl de todas las copias del minero (y del Estudio), se queda con el mejor registro de cada sala, revalida con las reglas actuales
## (descarta lo que ya no funciona) y escribe un solo archivo. Con `compress` el archivo va comprimido (zstd) y es el que viaja con el juego.
## Uso desde la consola: Godot --headless --path . res://scenes/pack.tscn -- --in=CARPETA --out=ARCHIVO [--compress] [--min-moved=2]

const RoomLib := preload("res://scripts/room_lib.gd")


## Junta los .jsonl de `in_dir` (menos `out_path`). {rooms, read, bad, old_rules, invalid, dup, dropped_weak}.
static func collect(in_dir: String, out_path: String, opts: Dictionary = {}) -> Dictionary:
	var min_moved := int(opts.get("min_moved", 1))
	var do_prune := bool(opts.get("prune", false))
	var do_polish := bool(opts.get("polish", false))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var res := {"rooms": [], "read": 0, "bad": 0, "old_rules": 0, "invalid": 0, "dup": 0, "weak": 0, "files": 0, "pruned_blocks": 0, "pruned_rooms": 0, "polished": 0, "dup_after": 0,
		"before": _zero_stats(), "after": _zero_stats()}
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
	var shard_i := int(opts.get("shard_i", 0))
	var shard_n := int(opts.get("shard_n", 1))
	for id in ids:
		if shard_n > 1 and int(("0x" + String(id).substr(0, 8)).hex_to_int()) % shard_n != shard_i:
			continue
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
		_add_stats(res.before, r)
		if bool(opts.get("simplify", true)):   # (saca las vueltas de los caminos viejos: es exacto)
			var shorter := RoomLib.simplify_path(r, r.path)
			if shorter.size() < r.path.size():
				var src: String = str(r.opt.get("source", ""))
				var proof: String = str(r.opt.get("proof", "sin_probar"))
				RoomLib.apply_result(r, shorter, "sin_probar" if proof == "exacta" else proof, int(r.opt.get("lower", r.h)), int(r.opt.get("states", 0)))
				if src != "":
					r.opt.source = src
				res["shortened"] = int(res.get("shortened", 0)) + 1
		if bool(opts.get("audit", false)):   # (calidad: los especiales que no hacen falta pasan a comunes y el camino se vuelve a calcular con el verificador exacto)
			var au := RoomLib.audit_specials(r, int(opts.get("rerate_cap", 600000)), 15000)
			if au.is_empty():
				res.invalid += 1
				continue
			var src5: String = str(r.opt.get("source", ""))
			r = au.room
			if src5 != "":
				r.opt.source = src5
			r.opt["specials"] = "".join(au.needed)
			res["audited"] = int(res.get("audited", 0)) + 1
			res["specials_removed"] = int(res.get("specials_removed", 0)) + int(au.changed)
		var min_reach := float(opts.get("min_reach", 0.0))
		if min_reach > 0.0 and float(r.opt.get("reach", 1.0)) < min_reach and r.origin != "autor":
			res["low_reach"] = int(res.get("low_reach", 0)) + 1
			continue
		var rerate_min := int(opts.get("rerate", 0))
		if rerate_min > 0 and int(r.opt.get("grabs", 0)) >= rerate_min:   # (vuelve a calcular el camino más corto, y entre los más cortos el de menos agarres: así se mide la dificultad)
			var ver := RoomLib.verify_exact(r, int(opts.get("rerate_cap", 1500000)), int(opts.get("rerate_ms", 60000)))
			if ver.proof == "exacta":
				var src4: String = str(r.opt.get("source", ""))
				var g_before := int(r.opt.get("grabs", 0))
				RoomLib.apply_result(r, ver.path, "exacta", int(ver.moves), int(ver.states))
				if src4 != "":
					r.opt.source = src4
				res["rerated"] = int(res.get("rerated", 0)) + 1
				res["rerated_grabs_lost"] = int(res.get("rerated_grabs_lost", 0)) + maxi(0, g_before - int(r.opt.grabs))
			elif ver.proof == "imposible":
				res.invalid += 1
				continue
		if do_prune:   # (saca el relleno que no hace falta: la sala cambia de id)
			var pr := RoomLib.prune(r, rng, int(opts.get("prune_ms", 20000)))
			if int(pr.removed) > 0:
				var src2: String = str(r.opt.get("source", ""))
				var proof2: String = str(r.opt.get("proof", "sin_probar"))
				var low2: int = int(r.opt.get("lower", r.h))
				r = pr.room
				RoomLib.apply_result(r, r.path, "sin_probar" if proof2 == "exacta" else proof2, low2, 0)
				if src2 != "":
					r.opt.source = src2
				res.pruned_blocks += int(pr.removed)
				res.pruned_rooms += 1
		if do_polish and r.path.size() <= 90 and str(r.opt.get("proof", "")) != "exacta":   # (mejora el final del camino con el verificador exacto)
			var imp := RoomLib.improve_tail(r, r.path, 8000, 1500)
			if imp.path.size() < r.path.size() or int(imp.proven) >= imp.path.size():
				var src3: String = str(r.opt.get("source", ""))
				var full: bool = int(imp.proven) >= imp.path.size()
				RoomLib.apply_result(r, imp.path, "exacta" if full else str(r.opt.get("proof", "sin_probar")), imp.path.size() if full else int(r.opt.get("lower", r.h)), int(r.opt.get("states", 0)))
				if src3 != "":
					r.opt.source = src3
				res.polished += 1
		if bool(opts.get("verbose", false)) and res.rooms.size() % 100 == 99:
			print("[empaquetador] %d salas procesadas…" % (res.rooms.size() + 1))
		if int(r.opt.get("moved", 0)) < min_moved and r.origin != "autor":
			res.weak += 1
			continue
		res.rooms.append(r)
	# después de podar dos salas pueden haber quedado iguales: se queda la mejor
	var final := {}
	for r in res.rooms:
		if final.has(r.id):
			res.dup_after += 1
			final[r.id] = RoomLib.better(final[r.id], r)
		else:
			final[r.id] = r
	if res.dup_after > 0:
		var ids2: Array = final.keys()
		ids2.sort()
		res.rooms = []
		for id2 in ids2:
			res.rooms.append(final[id2])
	for r in res.rooms:
		_add_stats(res.after, r)
	return res


static func _zero_stats() -> Dictionary:
	return {"rooms": 0, "moves": 0, "grabs": 0, "moved": 0, "blocks": 0, "diff": 0.0, "exact": 0}


static func _add_stats(st: Dictionary, r: Dictionary) -> void:
	st.rooms += 1
	st.moves += int(r.opt.get("moves", 0))
	st.grabs += int(r.opt.get("grabs", 0))
	st.moved += int(r.opt.get("moved", 0))
	st.diff += float(r.opt.get("diff", 0.0))
	st.exact += 1 if str(r.opt.get("proof", "")) == "exacta" else 0
	st.blocks += RoomLib.block_count(r)


## Una línea con los promedios de un grupo de salas.
static func stats_line(st: Dictionary) -> String:
	var n := maxi(int(st.rooms), 1)
	return "%d salas · %.1f pasos · %.1f con desplazamiento · dificultad %.0f %% · %.1f bloques distintos · %.0f bloques en total · %d con prueba exacta" % [int(st.rooms), float(st.moves) / n, float(st.grabs) / n, 100.0 * float(st.diff) / n, float(st.moved) / n, float(st.blocks) / n, int(st.exact)]


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
