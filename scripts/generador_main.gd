extends Node
## El cierre del generador de salas (una sola pasada, sin pasos extra): junta lo que sacó el generador nativo (herramientas\generador.bat → tools\generador.exe) y, si se pide, las salas del minero viejo
## (que se pasan por la auditoría nativa), comprueba cada sala con las reglas del juego (estructura, repetir el camino, hashes) y escribe la biblioteca que viaja con el juego (data/salas.rooms), mezclada con las
## salas que ya tenía. Las salas del generador ya salen auditadas y medidas: acá sólo se verifica y se arma el archivo.
## Uso: Godot --headless --path . res://scenes/generador.tscn -- [--in=bibliotecas/generador] [--old=bibliotecas/minero] [--lib=data/salas.rooms] [--out=data/salas.rooms] [--min-reach=0.5] [--min-moved=1] [--dry]
##      [--native=tools/generador.exe] [--keep-old]    (--keep-old: las salas que ya estaban en la biblioteca se conservan tal cual; por defecto también)
const RoomLib := preload("res://scripts/room_lib.gd")
const RoomPack := preload("res://scripts/room_pack.gd")


func _ready() -> void:
	var inp := "bibliotecas/generador"
	var old_dir := ""
	var lib := "res://data/salas.rooms"
	var out := ""
	var min_reach := 0.5
	var min_moved := 1
	var dry := false
	var native := ProjectSettings.globalize_path("res://tools/generador.exe")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--in="):
			inp = a.substr(5)
		elif a.begins_with("--old="):
			old_dir = a.substr(6)
		elif a.begins_with("--lib="):
			lib = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--min-reach="):
			min_reach = float(a.substr(12))
		elif a.begins_with("--min-moved="):
			min_moved = int(a.substr(12))
		elif a.begins_with("--native="):
			native = a.substr(9)
		elif a == "--dry":
			dry = true
	if out == "":
		out = lib
	var res := run(inp, old_dir, lib, out, min_reach, min_moved, native, dry)
	print("[generador] ", res.text)
	get_tree().quit(0 if res.ok else 1)


## Una sala desde una línea del generador nativo (R|forma|h|fuse|moves|grabs|reach|especiales|camino|columnas|origen); {} si no pasa las reglas del juego.
static func room_from_line(line: String, min_reach := 0.5, min_moved := 1) -> Dictionary:
	var p := line.strip_edges().split("|")
	if p.size() < 10 or p[0] != "R":
		return {}
	var room := RoomLib.make_room(p[1], int(p[2]))
	var fuse := int(p[3])
	if fuse > 0:
		room["fuse"] = fuse
	for item in p[9].split(";", false):
		var xz := item.split(":")
		if xz.size() != 2:
			return {}
		var c := xz[0].split(",")
		room.cols[Vector2i(int(c[0]), int(c[1]))] = xz[1]
	var path := RoomLib.parse_path("" if p[8] == "-" else p[8])
	if path.is_empty() or RoomLib.validate_structure(room) != "":
		return {}
	if not RoomLib.replay(room, path).ok:
		return {}
	RoomLib.apply_result(room, path, "exacta", path.size(), 0)
	room.opt["specials"] = p[7]
	room.opt["source"] = p[10] if p.size() > 10 else "generador"
	room.origin = "minero"
	room.stamp = int(Time.get_unix_time_from_system())
	if int(room.opt.moved) < min_moved or float(room.opt.reach) < min_reach:
		return {}
	return room


## Escribe una sala como línea para la auditoría nativa (sin camino).
static func line_for_audit(room: Dictionary) -> String:
	var cols := PackedStringArray()
	for c in room.cols:
		cols.append("%d,%d:%s" % [c.x, c.y, room.cols[c]])
	return "R|%s|%d|%d|0|0|0||-|%s" % [room.shape, room.h, int(room.get("fuse", 0)), ";".join(cols)]


static func run(inp: String, old_dir: String, lib: String, out: String, min_reach: float, min_moved: int, native: String, dry: bool) -> Dictionary:
	var rooms := {}
	var stats := {"lib": 0, "nativas": 0, "viejas": 0, "viejas_auditadas": 0, "rechazadas": 0, "repetidas": 0}
	# 1. lo que ya tiene la biblioteca
	if lib != "" and FileAccess.file_exists(lib):
		for r in RoomPack.load_library(lib):
			if not rooms.has(r.id):
				rooms[r.id] = r
				stats.lib += 1
	# 2. lo que sacó el generador nativo
	var files: Array = []
	var d := DirAccess.open(inp)
	if d != null:
		for f in d.get_files():
			if f.ends_with(".txt"):
				files.append(inp.path_join(f))
	files.sort()
	for path in files:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		while not f.eof_reached():
			var line := f.get_line()
			if line.begins_with("R|"):
				var r := room_from_line(line, min_reach, min_moved)
				if r.is_empty():
					stats.rechazadas += 1
				elif rooms.has(r.id):
					stats.repetidas += 1
					rooms[r.id] = RoomLib.better(rooms[r.id], r) if str(rooms[r.id].origin) != "autor" else rooms[r.id]
				else:
					rooms[r.id] = r
					stats.nativas += 1
		f.close()
	# 3. las salas del minero viejo (GDScript): pasan por la auditoría nativa
	if old_dir != "" and DirAccess.dir_exists_absolute(old_dir) and FileAccess.file_exists(native):
		var tmp_in := OS.get_user_data_dir().path_join("auditar_entrada.txt")
		var tmp_out := OS.get_user_data_dir().path_join("auditar_salida.txt")
		var fin := FileAccess.open(tmp_in, FileAccess.WRITE)
		var queued := 0
		var seen := {}
		var od := DirAccess.open(old_dir)
		for fn in od.get_files():
			if not fn.ends_with(".jsonl"):
				continue
			for r in RoomLib.read_file(old_dir.path_join(fn)).rooms:
				if rooms.has(r.id) or seen.has(r.id) or int(r.rules) != RoomLib.RULES_VERSION:
					continue
				seen[r.id] = true
				fin.store_line(line_for_audit(r))
				queued += 1
		fin.close()
		stats.viejas = queued
		if queued > 0:
			var output: Array = []
			OS.execute(native, ["auditar", "--in=" + tmp_in, "--out=" + tmp_out, "--min-reach=%f" % min_reach], output, true)
			if FileAccess.file_exists(tmp_out):
				var fo := FileAccess.open(tmp_out, FileAccess.READ)
				while not fo.eof_reached():
					var line2 := fo.get_line()
					if line2.begins_with("R|"):
						var r2 := room_from_line(line2, min_reach, min_moved)
						if r2.is_empty():
							stats.rechazadas += 1
						elif rooms.has(r2.id):
							stats.repetidas += 1
						else:
							rooms[r2.id] = r2
							stats.viejas_auditadas += 1
				fo.close()
	var list: Array = rooms.values()
	list.sort_custom(func(a, b): return str(a.id) < str(b.id))
	var text := "%d salas (%d ya estaban, %d nuevas del generador, %d del minero viejo auditadas; %d rechazadas, %d repetidas)" % [list.size(), stats.lib, stats.nativas, stats.viejas_auditadas, stats.rechazadas, stats.repetidas]
	text += "\n" + summary(list)
	var ok := true
	if not dry:
		if FileAccess.file_exists(out):
			DirAccess.copy_absolute(out, out + ".bak")
		ok = RoomPack.write_library(list, out, out.ends_with(".rooms"))
		text += "\nescrita en %s" % out if ok else "\nNO se pudo escribir %s" % out
	return {"ok": ok, "rooms": list, "stats": stats, "text": text}


## Cuántas salas hay de cada forma, de cada dificultad y de cada tipo de especial.
static func summary(list: Array) -> String:
	var shapes := {}
	var diffs := {"<30 %": 0, "30-49 %": 0, ">=50 %": 0}
	var kinds := {}
	for r in list:
		shapes[r.shape] = int(shapes.get(r.shape, 0)) + 1
		var dd := float(r.opt.get("diff", 0.0))
		diffs["<30 %" if dd < 0.3 else ("30-49 %" if dd < 0.5 else ">=50 %")] += 1
		for ch in str(r.opt.get("specials", "")):
			kinds[ch] = int(kinds.get(ch, 0)) + 1
	return "por forma %s · por dificultad %s · con especiales que hacen falta %s" % [str(shapes), str(diffs), str(kinds)]
