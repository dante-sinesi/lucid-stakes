extends SceneTree
## El generador nativo de salas (native/generador.cpp → tools/generador.exe) y su cierre (scripts/generador_main.gd): lo que saca el generador cumple las reglas del juego (estructura, camino que repite,
## no se resuelve caminando), la auditoría nativa coincide con la de GDScript (RoomLib.audit_specials) y la misma semilla da las mismas salas.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_generador.gd

const RoomLib := preload("res://scripts/room_lib.gd")
const RoomPack := preload("res://scripts/room_pack.gd")
const Main := preload("res://scripts/generador_main.gd")
const Solver := preload("res://scripts/solver.gd")

var fails := 0
var exe := ProjectSettings.globalize_path("res://tools/generador.exe")


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	if not FileAccess.file_exists(exe):
		print("(no está tools/generador.exe: se arma con native/construir.bat; se salta la prueba)")
		quit(0)
		return
	test_mine()
	test_ice()
	test_audit()
	test_final()
	print("tests del generador terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func _run(args: Array) -> void:
	var out: Array = []
	OS.execute(exe, args, out, true)


func _lines(path: String) -> Array:
	var res: Array = []
	if not FileAccess.file_exists(path):
		return res
	var f := FileAccess.open(path, FileAccess.READ)
	while not f.eof_reached():
		var l := f.get_line()
		if l.begins_with("R|"):
			res.append(l)
	return res


func test_mine() -> void:
	var dir := OS.get_user_data_dir().path_join("test_generador")
	DirAccess.make_dir_recursive_absolute(dir)
	var a := dir.path_join("a.txt")
	var b := dir.path_join("b.txt")
	for p in [a, b]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_run(["mina", "--out=" + a, "--steps=14", "--shapes=3x3,3x5", "--hlo=5", "--hhi=6", "--seed=21", "--nodes=60000", "--eval=8"])
	_run(["mina", "--out=" + b, "--steps=14", "--shapes=3x3,3x5", "--hlo=5", "--hhi=6", "--seed=21", "--nodes=60000", "--eval=8"])
	var la := _lines(a)
	var lb := _lines(b)
	check(la.size() >= 3, "el generador saca salas en pocos pasos (%d)" % la.size())
	check(la == lb, "la misma semilla da las mismas salas (%d y %d)" % [la.size(), lb.size()])
	var good := 0
	var ids := {}
	for l in la:
		var r := Main.room_from_line(l, 0.5, 1)
		if not r.is_empty():
			good += 1
			ids[r.id] = true
			check(RoomLib.replay(r, r.path).ok and RoomLib.validate_structure(r) == "" and str(r.opt.proof) == "exacta", "la sala sale válida y con prueba exacta")
			var t = RoomLib.build_state(r)
			var plain: Dictionary = Solver.solve(t, int(r.h) + 1, {"max_states": 60000, "goal_ids": t.goal_ids, "no_grab": true, "native": false})
			check(plain.status == "unsolvable", "no se resuelve caminando (la comprobó GDScript)")
	check(good == la.size(), "todas las salas del generador pasan las reglas del juego (%d de %d)" % [good, la.size()])
	check(ids.size() >= good - 1, "casi no hay repetidas (%d distintas de %d)" % [ids.size(), good])


## El modo hielo: --types=i,h,c,s --p-ice --min-ice --min-slides. Sólo salen salas con hielo que hace falta y con resbalones en el camino, y las métricas
## (slides, ice_moved) que guarda el cierre las mide GDScript con las reglas del juego y coinciden con las del generador.
func test_ice() -> void:
	var dir := OS.get_user_data_dir().path_join("test_generador")
	DirAccess.make_dir_recursive_absolute(dir)
	var a := dir.path_join("hielo_a.txt")
	var b := dir.path_join("hielo_b.txt")
	for p in [a, b]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	var args := ["--steps=40", "--shapes=3x3,3x5", "--hlo=5", "--hhi=6", "--seed=5", "--types=i,h,c,s", "--p-ice=1", "--p-type=0.9", "--min-ice=1", "--min-slides=1", "--nodes=60000", "--eval=8"]
	_run(["mina", "--out=" + a] + args)
	_run(["mina", "--out=" + b] + args)
	var la := _lines(a)
	check(la.size() >= 3 and la == _lines(b), "el modo hielo saca salas y es determinista (%d)" % la.size())
	var ok := 0
	for l in la:
		var r := Main.room_from_line(l, 0.5, 1)
		if r.is_empty():
			continue
		ok += 1
		var native_slides := int(str(l).split("|")[11])
		check(int(r.opt.get("slides", 0)) >= 1 and int(r.opt.get("ice_moved", 0)) >= 0, "la sala trae resbalones medidos por el juego")
		check(int(r.opt.slides) == native_slides, "los resbalones del generador coinciden con los del juego (%d y %d)" % [native_slides, int(r.opt.slides)])
		var has_ice := false
		for c in r.cols.values():
			has_ice = has_ice or str(c).contains("i")
		check(has_ice, "la sala tiene hielo")
		for ch in str(r.opt.get("specials", "")):
			check(ch in ["i", "h", "c", "s"], "los compañeros del hielo son sólo pesado, agrietado y pinchos")
	check(ok == la.size(), "todas pasan las reglas del juego (%d de %d)" % [ok, la.size()])


func test_audit() -> void:
	var lib := RoomPack.load_library("res://data/salas.rooms")
	var picks: Array = []
	var with_special := 0
	for r in lib:
		if str(r.opt.get("specials", "")) != "" and with_special < 3 and int(r.h) <= 8:
			picks.append(r)
			with_special += 1
		elif picks.size() < 6 and with_special >= 3 and int(r.h) <= 7 and str(r.opt.get("specials", "")) == "":
			picks.append(r)
	check(picks.size() >= 4, "hay salas de la biblioteca para comparar (%d)" % picks.size())
	var dir := OS.get_user_data_dir().path_join("test_generador")
	var fin := dir.path_join("auditar_in.txt")
	var fout := dir.path_join("auditar_out.txt")
	var f := FileAccess.open(fin, FileAccess.WRITE)
	for r in picks:
		f.store_line(Main.line_for_audit(r))
	f.close()
	if FileAccess.file_exists(fout):
		DirAccess.remove_absolute(fout)
	_run(["auditar", "--in=" + fin, "--out=" + fout, "--min-reach=0.0"])
	var native := {}
	for l in _lines(fout):
		var r := Main.room_from_line(l, 0.0, 0)
		if not r.is_empty():
			native[r.id] = r
	var same := 0
	var compared := 0
	for r in picks:
		var au := RoomLib.audit_specials(r)
		if au.is_empty():
			continue
		compared += 1
		var n: Dictionary = native.get(au.room.id, {})
		if not n.is_empty() and int(n.opt.moves) == int(au.room.opt.moves) and int(n.opt.grabs) == int(au.room.opt.grabs) and str(n.opt.specials) == "".join(au.needed):
			same += 1
		else:
			print("   diferencia en una sala %s h%d: GDScript %s, nativo %s" % [r.shape, int(r.h), "%d pasos" % int(au.room.opt.moves), "%d pasos" % int(n.opt.moves) if not n.is_empty() else "sin resultado"])
	check(compared >= 3 and same == compared, "la auditoría nativa coincide con la de GDScript (%d de %d)" % [same, compared])


func test_final() -> void:
	var dir := OS.get_user_data_dir().path_join("test_generador")
	var out := dir.path_join("lib_prueba.rooms")
	if FileAccess.file_exists(out):
		DirAccess.remove_absolute(out)
	var res := Main.run(dir, "", "", out, 0.5, 1, exe, false)
	check(res.ok and FileAccess.file_exists(out), "el cierre escribe la biblioteca")
	var back := RoomPack.load_library(out)
	check(back.size() == res.rooms.size() and back.size() >= 3, "y se lee de vuelta con las mismas salas (%d)" % back.size())
	var uniq := {}
	for r in back:
		uniq[r.id] = true
	check(uniq.size() == back.size(), "sin repetidas en la biblioteca final")
