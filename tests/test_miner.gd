extends SceneTree
## Pruebas del minero de salas (scripts/room_miner.gd y la escena scenes/miner.tscn). Tarda unos minutos.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_miner.gd

const RoomLib := preload("res://scripts/room_lib.gd")
const RoomMiner := preload("res://scripts/room_miner.gd")
const MinerMain := preload("res://scripts/miner_main.gd")
const Solver := preload("res://scripts/solver.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")

var fails := 0
var dir_test := "user://test_miner"


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _clean_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)


func _init() -> void:
	_clean_dir(dir_test)
	test_args()
	test_seeds_and_changes()
	test_mining_small()
	test_tall()
	test_scene_process()
	print("tests del minero terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_args() -> void:
	var cfg := MinerMain.parse_args(PackedStringArray(["--id=3", "--out=/tmp/x", "--minutes=2.5", "--shapes=L,U", "--hlo=6", "--hhi=9", "--keep=4", "--verify=0.2", "--max-evals=77", "--seed=5", "basura", "--sin_igual"]))
	check(int(cfg.id) == 3 and cfg.out_dir == "/tmp/x" and is_equal_approx(float(cfg.minutes), 2.5), "se leen id, salida y minutos")
	check(cfg.shapes == ["L", "U"] and int(cfg.h_lo) == 6 and int(cfg.h_hi) == 9 and int(cfg.keep) == 4, "se leen formas, alturas y casilleros")
	check(is_equal_approx(float(cfg.verify_p), 0.2) and int(cfg.max_evals) == 77 and int(cfg.seed) == 5, "se leen verificación, tope y semilla")
	var dflt := MinerMain.parse_args(PackedStringArray())
	check(int(dflt.id) == 1 and float(dflt.minutes) == 0.0 and dflt.out_dir == "user://biblioteca", "los valores por defecto")


func test_seeds_and_changes() -> void:
	var m := RoomMiner.new({"seed": 7, "write": false})
	check(m.combos_list.size() == RoomLib.combos().size(), "el minero conoce todas las combinaciones")
	for pair in RoomLib.combos():
		var st := m.staircase(pair[0], pair[1])
		check(not st.is_empty(), "hay escalera para %s de %d pisos" % [pair[0], pair[1]])
		if not st.is_empty():
			var r := RoomLib.make_room(pair[0], pair[1])
			r.cols = st
			check(RoomLib.validate_structure(r) == "", "la escalera de %s de %d pisos es coherente" % [pair[0], pair[1]])
			var t = RoomLib.build_state(r)
			var w: Dictionary = Solver.solve(t, pair[1] + 1, {"max_states": 20000, "goal_ids": t.goal_ids, "no_grab": true, "max_ms": 8000})
			check(w.status == "solved", "la escalera de %s de %d pisos se sube caminando" % [pair[0], pair[1]])
	# semillas chicas
	for sh in RoomLib.SHAPES:
		var got := 0
		for _i in 20:
			var s := m.make_seed(sh, 5)
			if not s.is_empty():
				got += 1
				check(RoomLib.validate_structure(s) == "", "la semilla de %s es coherente" % sh)
		check(got > 10, "salen semillas de %s" % sh)
	# semillas altas con solución plantada
	for pair in [["3x5", 10], ["3x8", 10], ["3x8", 15], ["L", 12], ["L", 20], ["U", 14], ["U", 20]]:
		var ok := 0
		for _i in 60:
			var s := m.make_tall_seed(pair[0], pair[1])
			if s.is_empty():
				continue
			ok += 1
			check(RoomLib.validate_structure(s) == "", "la semilla alta %s %d es coherente" % [pair[0], pair[1]])
			check(RoomLib.replay(s, s.path).ok, "el camino plantado de %s %d resuelve la sala" % [pair[0], pair[1]])
			break
		check(ok > 0, "sale al menos una semilla alta de %s de %d pisos" % [pair[0], pair[1]])
	# los cambios no tocan al padre y dejan salas coherentes
	var parent := RoomLib.make_room("U", 9)
	parent.cols = {Vector2i(1, 1): "nnn", Vector2i(3, 6): "nn", Vector2i(2, 5): "n"}
	RoomLib.finalize(parent)
	var before := RoomLib.to_line(parent)
	var bad := 0
	for _i in 300:
		var c := m.mutate(parent)
		if RoomLib.validate_structure(c) != "":
			bad += 1
	check(bad == 0, "300 cambios dejan salas coherentes (%d no)" % bad)
	check(RoomLib.to_line(parent) == before, "los cambios no tocan al padre")
	var other := RoomLib.make_room("U", 9)
	other.cols = {Vector2i(0, 2): "nnnn", Vector2i(4, 1): "nnn"}
	RoomLib.finalize(other)
	for _i in 50:
		check(RoomLib.validate_structure(m.crossover(parent, other)) == "", "el cruce deja una sala coherente")


func _check_archive(m, label: String) -> void:
	var ids := {}
	for r in m.all_rooms():
		check(not ids.has(r.id), "%s: no hay ids repetidos" % label)
		ids[r.id] = true
		check(RoomLib.validate_structure(r) == "", "%s: la sala es coherente" % label)
		check(RoomLib.replay(r, r.path).ok, "%s: el camino de la sala la resuelve (%s %d)" % [label, r.shape, r.h])
		var again := RoomLib.copy_room(r)
		RoomLib.finalize(again)
		check(again.id == r.id and again.family == r.family, "%s: los hashes se recalculan igual" % label)
	for k in m.archive:
		check(m.archive[k].size() <= m.keep, "%s: el casillero %s no pasa el tope (%d)" % [label, k, m.keep])
		for r in m.archive[k]:
			check(RoomMiner.cell_key(r) == k, "%s: la sala está en su casillero" % label)


func test_mining_small() -> void:
	var cfg := {"out_dir": dir_test, "id": 11, "seed": 21, "shapes": RoomLib.SHAPES, "h_lo": 5, "h_hi": 5, "keep": 4, "verify_p": 0.15}
	var m := RoomMiner.new(cfg)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 75000:
		m.step()
	var n := m.archive_size()
	print("  (minero chico: %d evaluaciones, %d salas, %d casilleros)" % [int(m.stats.evals), n, m.archive.size()])
	check(n > 10, "el minero junta salas (%d)" % n)
	check(int(m.stats.write_errors) == 0, "no hubo errores al escribir")
	_check_archive(m, "chico")
	var shapes_seen := {}
	for r in m.all_rooms():
		shapes_seen[r.shape] = true
	check(shapes_seen.size() == 5, "salieron salas de las 5 formas (%d)" % shapes_seen.size())
	# ninguna se resuelve caminando (la búsqueda de sólo caminar es exacta y chica)
	var sample: Array = m.all_rooms()
	for i in mini(25, sample.size()):
		var r: Dictionary = sample[i]
		var t = RoomLib.build_state(r)
		var pl: Dictionary = Solver.solve(t, r.h + 1, {"max_states": 40000, "goal_ids": t.goal_ids, "no_grab": true})
		check(pl.status == "unsolvable", "la sala %s no se resuelve caminando (%s)" % [r.shape, pl.status])
		check(int(r.opt.moved) >= 1 and int(r.opt.grabs) >= 1, "la sala pide mover bloques")
	# el archivo: cada línea es una sala y las salas del archivo en memoria están
	var f := RoomLib.read_file(m.out_path)
	check(f.bad == 0 and f.rooms.size() >= n, "el .jsonl tiene al menos las salas del archivo (%d de %d, malas %d)" % [f.rooms.size(), n, f.bad])
	var in_file := {}
	for r in f.rooms:
		in_file[r.id] = true
	for r in m.all_rooms():
		check(in_file.has(r.id), "la sala %s está en el .jsonl" % str(r.id).substr(0, 8))
	# verificación exacta
	var exact_before := 0
	for r in m.all_rooms():
		if r.opt.proof == "exacta":
			exact_before += 1
	var tries := 0
	while tries < 40:
		tries += 1
		if not m.verify_one():
			break
	var exact_after := 0
	var cota := 0
	for r in m.all_rooms():
		if r.opt.proof == "exacta":
			exact_after += 1
			check(RoomLib.replay(r, r.path).ok, "el camino exacto resuelve la sala")
			check(int(r.opt.lower) == int(r.opt.moves), "la prueba exacta tiene cota igual al mínimo")
		if r.opt.proof == "cota":
			cota += 1
	check(exact_after > exact_before or exact_before > 0, "se verificaron salas de forma exacta (%d antes, %d después)" % [exact_before, exact_after])
	_check_archive(m, "chico tras verificar")
	# retomar
	var ids_before := {}
	for r in m.all_rooms():
		ids_before[r.id] = true
	var m2 := RoomMiner.new(cfg)
	var resumed := m2.resume()
	check(resumed > 0, "retoma salas del .jsonl (%d)" % resumed)
	_check_archive(m2, "retomado")
	var common := 0
	for r in m2.all_rooms():
		if ids_before.has(r.id):
			common += 1
	check(common >= int(0.6 * float(m2.archive_size())), "casi todo lo retomado ya estaba en el archivo anterior (%d de %d)" % [common, m2.archive_size()])
	var sample_room: Dictionary = m2.all_rooms()[0]
	var again := RoomLib.copy_room(sample_room)
	check(m2.try_child(again) == false, "una sala ya vista no se evalúa dos veces")
	check(int(m2.stats.dup) >= 1, "se cuenta el duplicado")
	m2.write_stats()
	check(FileAccess.file_exists(dir_test.path_join("stats_11.json")), "se escribe el informe")
	var sj = JSON.parse_string(FileAccess.get_file_as_string(dir_test.path_join("stats_11.json")))
	check(typeof(sj) == TYPE_DICTIONARY and sj.has("archive") and sj.has("groups_total"), "el informe se lee de vuelta")


func test_tall() -> void:
	var cfg := {"out_dir": dir_test, "id": 12, "seed": 33, "shapes": ["3x8", "L", "U"], "h_lo": 10, "h_hi": 14, "keep": 3, "verify_p": 0.05}
	var m := RoomMiner.new(cfg)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 60000:
		m.step()
	print("  (minero alto: %d evaluaciones, %d salas, %d/%d grupos)" % [int(m.stats.evals), m.archive_size(), m.by_group.size(), m.combos_list.size()])
	check(m.archive_size() > 5, "el minero junta salas altas (%d)" % m.archive_size())
	_check_archive(m, "alto")
	var planted := 0
	for r in m.all_rooms():
		check(r.h >= 10, "la sala alta mide 10 o más")
		if str(r.opt.get("source", "")) == "plantada":
			planted += 1
		var t = RoomLib.build_state(r)
		var pl: Dictionary = Solver.solve(t, r.h + 1, {"max_states": 40000, "goal_ids": t.goal_ids, "no_grab": true, "max_ms": 8000})
		check(pl.status == "unsolvable", "la sala alta no se resuelve caminando (%s)" % pl.status)
	check(planted > 0, "hay salas con el camino plantado")


func test_scene_process() -> void:
	var out := ProjectSettings.globalize_path(dir_test.path_join("proceso"))
	_clean_dir(dir_test.path_join("proceso"))
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "res://scenes/miner.tscn", "--", "--id=7", "--out=" + out, "--minutes=0.4", "--hlo=5", "--hhi=5", "--shapes=3x3,3x5"])
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	var text := ""
	for o in output:
		text += str(o)
	check(code == 0, "el minero como proceso termina bien (código %d)" % code)
	check(text.find("[minero 7] arranca") != -1 and text.find("[minero 7] fin") != -1, "el minero informa que arranca y que termina")
	check(FileAccess.file_exists(out.path_join("miner_7.jsonl")), "el proceso escribe su .jsonl")
	check(FileAccess.file_exists(out.path_join("stats_7.json")), "el proceso escribe su informe")
	var got := RoomLib.read_file(out.path_join("miner_7.jsonl"))
	check(got.rooms.size() > 0 and got.bad == 0, "el .jsonl del proceso tiene salas válidas (%d)" % got.rooms.size())
	for r in got.rooms:
		if r.shape != "3x3" and r.shape != "3x5":
			check(false, "el filtro de formas se respeta")
			break
	# con STOP, termina enseguida
	var f := FileAccess.open(out.path_join("STOP"), FileAccess.WRITE)
	f.store_string("x")
	f.close()
	var t0 := Time.get_ticks_msec()
	var args2 := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "res://scenes/miner.tscn", "--", "--id=7", "--out=" + out, "--minutes=0", "--hlo=5", "--hhi=5"])
	var out2: Array = []
	var code2 := OS.execute(OS.get_executable_path(), args2, out2, true)
	check(code2 == 0 and Time.get_ticks_msec() - t0 < 40000, "con un archivo STOP el minero termina enseguida (%d ms)" % (Time.get_ticks_msec() - t0))
	# retoma en el mismo directorio
	var text2 := ""
	for o in out2:
		text2 += str(o)
	check(text2.find("retoma") != -1, "al arrancar de nuevo informa que retoma")
