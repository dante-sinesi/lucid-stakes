extends SceneTree
## Pruebas del empaquetador de la biblioteca (scripts/room_pack.gd). Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_pack.gd
const RoomLib := preload("res://scripts/room_lib.gd")
const RoomPack := preload("res://scripts/room_pack.gd")
const RoomMiner := preload("res://scripts/room_miner.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _clean(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)
	var d := DirAccess.open(path)
	for f in d.get_files():
		d.remove(f)


func _init() -> void:
	var dir := "user://test_pack"
	_clean(dir)
	# dos copias del minero con salas chicas, una repite sala de la otra
	var made: Array = []
	for id in [1, 2]:
		var m := RoomMiner.new({"out_dir": dir, "id": id, "seed": 40 + id, "shapes": ["3x3", "3x5"], "h_lo": 5, "h_hi": 5, "keep": 3, "verify_p": 0.0})
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 25000:
			m.step()
		made.append(m.archive_size())
	check(int(made[0]) > 3 and int(made[1]) > 3, "las dos copias juntaron salas (%s)" % str(made))
	# una sala repetida a mano (misma id, con prueba exacta), una con reglas viejas, una inválida y una línea mala
	var first: Dictionary = RoomLib.read_file(dir.path_join("miner_1.jsonl")).rooms[0]
	var better := RoomLib.copy_room(first)
	better.opt = first.opt.duplicate()
	better.opt.proof = "exacta"
	better.stamp = int(first.stamp) + 10
	RoomLib.append_line(dir.path_join("miner_2.jsonl"), better)
	var old := RoomLib.copy_room(first)
	old.cols[Vector2i(1, 0)] = "nnn"
	RoomLib.finalize(old)
	old.rules = 0
	RoomLib.append_line(dir.path_join("manual.jsonl"), old)
	var broken := RoomLib.copy_room(first)
	broken.cols[Vector2i(0, 1)] = "n"
	RoomLib.finalize(broken)   # (la columna pegada a la llegada es incoherente)
	RoomLib.append_line(dir.path_join("manual.jsonl"), broken)
	var wrong_path := RoomLib.copy_room(first)
	wrong_path.cols[Vector2i(1, 0)] = "hhh"
	wrong_path.path = first.path.slice(0, first.path.size() - 1)
	RoomLib.finalize(wrong_path)   # (el camino no llega a la salida)
	RoomLib.append_line(dir.path_join("manual.jsonl"), wrong_path)
	var f := FileAccess.open(dir.path_join("manual.jsonl"), FileAccess.READ_WRITE)
	f.seek_end()
	f.store_line("{esto no es una sala")
	f.close()
	var out := dir.path_join("lib.jsonl")
	var res := RoomPack.pack(dir, out, {"min_moved": 1})
	print("  ", str(res.per_shape), " leídas ", res.read, " malas ", res.bad, " dup ", res.dup, " viejas ", res.old_rules, " inválidas ", res.invalid, " débiles ", res.weak)
	check(res.written, "se escribe la biblioteca")
	check(res.files == 3, "se leen los tres .jsonl (sin el de salida): %d" % res.files)
	check(res.bad == 1, "se cuenta la línea mala")
	check(res.dup >= 1, "se cuentan las repetidas")
	check(res.old_rules == 1, "se descarta la de reglas viejas")
	check(res.invalid >= 2, "se descartan las incoherentes (%d)" % res.invalid)
	var got: Array = RoomLib.read_file(out).rooms
	check(got.size() == res.kept and got.size() > 5, "la biblioteca tiene las salas buenas (%d)" % got.size())
	var ids := {}
	var exact_first := false
	for r in got:
		check(not ids.has(r.id), "no hay ids repetidos en la biblioteca")
		ids[r.id] = true
		check(RoomLib.replay(r, r.path).ok, "cada sala de la biblioteca se resuelve con su camino")
		if r.id == first.id and r.opt.proof == "exacta":
			exact_first = true
	check(exact_first, "de la sala repetida queda el registro con la prueba exacta")
	# comprimida
	var out2 := dir.path_join("lib.rooms")
	var res2 := RoomPack.pack(dir, out2, {"min_moved": 1})
	check(res2.written and res2.kept == res.kept, "la comprimida tiene las mismas salas")
	var back := RoomPack.load_library(out2)
	check(back.size() == res.kept, "la biblioteca comprimida se lee de vuelta (%d)" % back.size())
	var size_plain := FileAccess.get_file_as_bytes(out).size()
	var size_zip := FileAccess.get_file_as_bytes(out2).size()
	check(size_zip < size_plain, "comprimida pesa menos (%d vs %d bytes)" % [size_zip, size_plain])
	for r in back:
		check(RoomLib.replay(r, r.path).ok, "la sala comprimida se resuelve")
	# con un mínimo de bloques movidos se filtran las flojas
	var res3 := RoomPack.pack(dir, dir.path_join("lib3.jsonl"), {"min_moved": 3})
	check(res3.kept <= res.kept and res3.weak >= res.weak, "con un mínimo mayor quedan menos salas (%d)" % res3.kept)
	check(RoomPack.load_library(dir.path_join("no_existe.rooms")).is_empty(), "una biblioteca que no existe se lee vacía")
	# un camino lleno de vueltas se acorta al empaquetar
	var ldir := dir + "/lazy"
	_clean(ldir)
	var lazy := RoomLib.copy_room(first)
	var loop := [{"dir": Vector3i(1, 0, 0), "mode": 0}, {"dir": Vector3i(-1, 0, 0), "mode": 0}]
	var wander: Array = []
	for i in 8:
		wander.append_array(loop)
	wander.append_array(first.path)
	lazy.path = wander
	if RoomLib.replay(lazy, wander).ok:
		RoomLib.apply_result(lazy, wander, "sin_probar", lazy.h, 0)   # (apply_result ya simplifica: se escribe el camino largo a mano)
		lazy.path = wander
		lazy.opt = lazy.opt.duplicate()
		lazy.opt.moves = wander.size()
		RoomLib.append_line(ldir.path_join("a.jsonl"), lazy)
		var lres := RoomPack.collect(ldir, ldir.path_join("out.jsonl"), {})
		check(lres.rooms.size() == 1 and int(lres.get("shortened", 0)) == 1, "el empaquetador acorta el camino con vueltas")
		if lres.rooms.size() == 1:
			check(lres.rooms[0].path.size() < wander.size() and RoomLib.replay(lres.rooms[0], lres.rooms[0].path).ok, "el camino acortado resuelve la sala (%d -> %d)" % [wander.size(), lres.rooms[0].path.size()])
			check(int(lres.rooms[0].opt.moves) == lres.rooms[0].path.size(), "las métricas siguen al camino nuevo")
	# actualizar una biblioteca: caminos sin vueltas, poda y mejora del final del camino, con promedios antes y después
	var up := RoomPack.pack(dir, dir.path_join("lib_up.jsonl"), {"min_moved": 1, "prune": true, "polish": true, "prune_ms": 8000})
	check(up.written and up.kept > 5, "se actualiza la biblioteca (%d salas)" % up.kept)
	check(int(up.after.moves) <= int(up.before.moves) and int(up.after.blocks) <= int(up.before.blocks), "después hay menos o igual pasos y bloques: %s -> %s" % [RoomPack.stats_line(up.before), RoomPack.stats_line(up.after)])
	for r in RoomLib.read_file(dir.path_join("lib_up.jsonl")).rooms:
		check(RoomLib.replay(r, r.path).ok and RoomLib.validate_structure(r) == "", "la sala actualizada se resuelve")
		check(is_equal_approx(float(r.opt.diff), float(r.opt.grabs) / float(r.opt.moves)) and int(r.opt.moves) == r.path.size(), "las métricas de la sala actualizada coinciden con su camino")
	check(RoomPack.stats_line(up.after).find("salas") != -1, "hay una línea de promedios")
	print("tests del empaquetador terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
