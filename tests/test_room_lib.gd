extends SceneTree
## Pruebas de la biblioteca de salas (scripts/room_lib.gd). Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_room_lib.gd

const RoomLib := preload("res://scripts/room_lib.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_shapes()
	test_state_and_replay()
	test_hashes()
	test_serialization()
	test_validate()
	test_evaluate_and_exact()
	test_files()
	print("tests de la biblioteca de salas terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


## La sala de las pruebas: 3x3 de 4 pisos que hay que resolver moviendo bloques (salió del experimento de evolución).
func sample_room() -> Dictionary:
	var r := RoomLib.make_room("3x3", 4)
	r.cols = {Vector2i(0, 2): "n", Vector2i(1, 1): "nnn", Vector2i(1, 2): "n", Vector2i(2, 0): "nnn", Vector2i(2, 1): "nn"}
	return r


func test_shapes() -> void:
	var sizes := {"3x3": 9, "3x5": 15, "3x8": 24, "L": 30, "U": 36}
	for sh in RoomLib.SHAPES:
		var info := RoomLib.shape_info(sh)
		check(info.cells.size() == sizes[sh], "la forma %s tiene %d celdas" % [sh, sizes[sh]])
		var set := {}
		for c in info.cells:
			set[c] = true
		check(set.size() == info.cells.size(), "la forma %s no repite celdas" % sh)
		check(set.has(info.exit), "la salida de %s está en la arena" % sh)
		check(not set.has(info.entry), "la llegada de %s está afuera" % sh)
		var touches := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if set.has(info.entry + d):
				touches = true
		check(touches, "la llegada de %s toca la arena" % sh)
		for c in info.cells:
			check(c.x >= 0 and c.x < 8 and c.y >= 0 and c.y < 8, "la celda %s de %s cabe en la torre de 8x8" % [str(c), sh])
		check(RoomLib.free_cells(sh).size() >= 4, "%s tiene lugar para columnas" % sh)
		check(RoomLib.max_height(sh) >= RoomLib.MIN_H and RoomLib.max_height(sh) <= RoomLib.MAX_H, "la altura máxima de %s está en rango" % sh)
	check(RoomLib.max_height("3x8") == 20 and RoomLib.max_height("L") == 20 and RoomLib.max_height("U") == 20, "las formas grandes llegan a 20 pisos")
	check(RoomLib.max_height("3x3") < 20, "la 3x3 no llega a 20 (no hay escalera posible)")
	check(RoomLib.combos().size() > 40, "hay muchas combinaciones forma-altura")
	var l_cells: Array = RoomLib.shape_info("L").cells
	var has_arm := false
	for c in l_cells:
		if c.y >= 3:
			has_arm = true
	check(has_arm, "la L tiene su tramo perpendicular")


func test_state_and_replay() -> void:
	var r := sample_room()
	check(RoomLib.validate_structure(r) == "", "la sala de prueba es coherente")
	var t = RoomLib.build_state(r)
	check(t.goal_y == 5 and t.goal_ids.size() == 1, "la torre de la sala tiene la meta a h + 1")
	check(t.player == Vector3i(-1, 1, 0), "el jugador empieza en la llegada")
	var gid: int = t.goal_ids.keys()[0]
	check(t.positions[gid] == Vector3i(2, 4, 2) and t.fixed.has(Vector3i(2, 4, 2)), "el tope de la salida es fijo y está a h")
	for y in range(1, 4):
		check(t.kind_at(Vector3i(2, y, 2)) == TowerLogic.Kind.HEAVY, "el pilar es pesado en la capa %d" % y)
	check(RoomLib.replay(r, []).ok == false, "un camino vacío no resuelve la sala")
	var ev := RoomLib.evaluate(r, {"cap": 6000})
	check(ev.ok, "la sala de prueba se evalúa bien (%s)" % str(ev.get("why", "")))
	if ev.ok:
		check(RoomLib.replay(r, ev.path).ok, "el camino que devuelve la evaluación se repite bien")
		var bad: Array = ev.path.duplicate()
		bad.pop_back()
		check(RoomLib.replay(r, bad).ok == false, "un camino al que le falta el último paso no resuelve")
		check(int(ev.moved) >= 1 and int(ev.grabs) >= 1, "hay que mover algún bloque")


func rotate_room(r: Dictionary, sym: int) -> Dictionary:
	var q := RoomLib.copy_room(r)
	var cells: Array[Vector2i] = []
	for c in r.cells:
		cells.append(RoomLib._sym(sym, c.x, c.y))
	q.cells = cells
	q.entry = RoomLib._sym(sym, r.entry.x, r.entry.y)
	q.exit = RoomLib._sym(sym, r.exit.x, r.exit.y)
	var cols := {}
	for c in r.cols:
		cols[RoomLib._sym(sym, c.x, c.y)] = r.cols[c]
	q.cols = cols
	var path: Array = []
	for a in r.path:
		var d: Vector3i = a.dir
		var e := RoomLib._sym(sym, d.x, d.z)
		path.append({"dir": Vector3i(e.x, 0, e.y), "mode": a.mode})
	q.path = path
	return q


func test_hashes() -> void:
	var r := sample_room()
	var ev := RoomLib.evaluate(r, {"cap": 6000})
	RoomLib.apply_result(r, ev.path, "sin_probar", 4, int(ev.states))
	check(r.id.length() == 32 and r.family.length() == 32 and r.pattern.length() == 32, "los tres hashes son de 32 caracteres")
	check(r.id != r.family, "el hash exacto y el de familia son distintos")
	for s in range(1, 8):
		var q := rotate_room(r, s)
		RoomLib.finalize(q)
		check(q.id == r.id, "el hash exacto no cambia con la simetría %d" % s)
		check(q.family == r.family, "el hash de familia no cambia con la simetría %d" % s)
		check(q.pattern == r.pattern, "el hash de patrón no cambia con la simetría %d" % s)
	# un bloque de otro tipo: cambia el exacto y no la familia
	var v := RoomLib.copy_room(r)
	v.cols[Vector2i(2, 1)] = "ni"
	RoomLib.finalize(v)
	check(v.id != r.id, "cambiar un tipo de bloque cambia el hash exacto")
	check(v.family == r.family, "cambiar un tipo de bloque no cambia la familia")
	# un bloque más: cambia todo
	var w := RoomLib.copy_room(r)
	w.cols[Vector2i(1, 0)] = "n"
	RoomLib.finalize(w)
	check(w.id != r.id and w.family != r.family, "un bloque más cambia el exacto y la familia")
	# el camino cambia el patrón y no la familia
	var p := RoomLib.copy_room(r)
	p.path = r.path.duplicate()
	p.path.append({"dir": Vector3i(1, 0, 0), "mode": TowerLogic.Mode.MOVE})
	RoomLib.finalize(p)
	check(p.family == r.family and p.pattern != r.pattern, "otro camino cambia el patrón y no la familia")
	# salas de otra altura son otras
	var hh := RoomLib.copy_room(r)
	hh.h = 5
	RoomLib.finalize(hh)
	check(hh.id != r.id, "otra altura, otro hash")
	var s1 := RoomLib.block_set(r)
	var s2 := RoomLib.block_set(rotate_room(r, 3))
	check(s1.size() > 0 and s1.size() == s2.size(), "el conjunto de bloques canónico no cambia al girar")
	check(RoomLib.distance(r, r, s1, s1) < 0.001, "la distancia de una sala a sí misma es cero")
	check(RoomLib.distance(r, w, s1, RoomLib.block_set(w)) > 0.0, "una sala distinta está a distancia positiva")


func test_serialization() -> void:
	var r := sample_room()
	var ev := RoomLib.evaluate(r, {"cap": 6000})
	RoomLib.apply_result(r, ev.path, "sin_probar", 4, int(ev.states))
	r.slots = {"2,1,2": "ic"}
	r.note = "prueba ñandú"
	r.stamp = 12345
	var line := RoomLib.to_line(r)
	check(line.find("\n") == -1, "la línea no tiene saltos")
	var back := RoomLib.from_line(line)
	check(not back.is_empty(), "la línea se lee de vuelta")
	check(back.id == r.id and back.family == r.family and back.pattern == r.pattern, "los hashes sobreviven")
	check(back.cols == r.cols, "las columnas sobreviven")
	check(back.shape == r.shape and back.h == r.h and back.entry == r.entry and back.exit == r.exit, "forma, altura y enchufes sobreviven")
	check(back.cells.size() == r.cells.size(), "las celdas sobreviven")
	check(RoomLib.path_string(back.path) == RoomLib.path_string(r.path), "el camino sobrevive")
	check(back.note == r.note and back.stamp == r.stamp and back.slots == r.slots, "las notas y marcas sobreviven")
	check(int(back.opt.moves) == int(r.opt.moves) and str(back.opt.proof) == "sin_probar", "las métricas sobreviven")
	check(RoomLib.replay(back, back.path).ok, "la sala leída se sigue resolviendo con su camino")
	check(RoomLib.from_line("esto no es json").is_empty(), "una línea basura no es una sala")
	check(RoomLib.from_line("{\"a\":1}").is_empty(), "un JSON sin campos de sala no es una sala")
	var pp := RoomLib.parse_path(RoomLib.path_string(r.path))
	check(pp.size() == r.path.size(), "el camino sobrevive a texto y de vuelta")
	for i in pp.size():
		check(pp[i].dir == r.path[i].dir and pp[i].mode == r.path[i].mode, "el paso %d sobrevive" % i)
	check(RoomLib.ascii(r).find("capa 1") != -1, "el dibujo de texto tiene capas")


func test_validate() -> void:
	var r := sample_room()
	check(RoomLib.validate_structure(r) == "", "coherente")
	var a := RoomLib.copy_room(r)
	a.cols[Vector2i(9, 9)] = "n"
	check(RoomLib.validate_structure(a) != "", "columna fuera de la arena")
	var b := RoomLib.copy_room(r)
	b.cols[b.exit] = "n"
	check(RoomLib.validate_structure(b) != "", "columna sobre la salida")
	var c := RoomLib.copy_room(r)
	c.cols[Vector2i(1, 2)] = "nnnn"
	check(RoomLib.validate_structure(c) != "", "columna más alta que el pilar")
	var d := RoomLib.copy_room(r)
	d.cols[Vector2i(1, 2)] = "x"
	check(RoomLib.validate_structure(d) != "", "tipo desconocido")
	var e := RoomLib.copy_room(r)
	e.cols[Vector2i(0, 0)] = "n"
	check(RoomLib.validate_structure(e) != "", "columna pegada a la llegada")
	var f := RoomLib.copy_room(r)
	f.h = 99
	check(RoomLib.validate_structure(f) != "", "altura absurda")


func test_evaluate_and_exact() -> void:
	var r := sample_room()
	var ev := RoomLib.evaluate(r, {"cap": 6000})
	check(ev.ok, "evalúa")
	var ex := RoomLib.verify_exact(r, 80000, 60000)
	check(ex.proof == "exacta", "el verificador exacto termina en una sala chica (%s)" % str(ex.proof))
	if ev.ok and ex.proof == "exacta":
		check(int(ex.moves) <= int(ev.moves), "el exacto nunca es más largo que el de producción")
		check(RoomLib.replay(r, ex.path).ok, "el camino del verificador exacto resuelve la sala")
	# una sala que se resuelve caminando es un atajo
	var easy := RoomLib.make_room("3x3", 5)
	easy.cols = {Vector2i(2, 2): "nnn", Vector2i(1, 2): "nn"}
	var ee := RoomLib.evaluate(easy, {"cap": 3000})
	check(ee.ok == false, "una sala sin nada que mover no pasa")
	# una sala sin solución
	var wall := RoomLib.make_room("3x3", 6)
	wall.cols = {Vector2i(1, 2): "hhhh", Vector2i(0, 2): "hhhh", Vector2i(2, 0): "hhhh", Vector2i(2, 1): "hhhh"}
	var ew := RoomLib.evaluate(wall, {"cap": 3000, "max_ms": 20000})
	check(ew.ok == false, "una sala que no se resuelve no pasa (%s)" % str(ew.get("why", "")))
	# el límite de tiempo corta
	var big := RoomLib.make_room("U", 12)
	big.cols = {Vector2i(1, 1): "nnnnn", Vector2i(3, 6): "nnnn"}
	var t0 := Time.get_ticks_msec()
	var eb := RoomLib.evaluate(big, {"cap": 1000000, "max_ms": 1500})
	check(Time.get_ticks_msec() - t0 < 12000, "el tope de tiempo corta la búsqueda")
	check(eb.ok == false, "una sala alta casi vacía no pasa")


func test_files() -> void:
	var dir := "user://test_room_lib"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "/a.jsonl"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var rooms: Array = []
	for i in 3:
		var r := sample_room()
		var ev := RoomLib.evaluate(r, {"cap": 6000})
		RoomLib.apply_result(r, ev.path, "sin_probar", 4, int(ev.states))
		r.cols[Vector2i(1, 0)] = "n".repeat(1 + i)
		r.note = "n%d" % i
		RoomLib.finalize(r)
		rooms.append(r)
		check(RoomLib.append_line(path, r), "se agrega la sala %d al archivo" % i)
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_line("basura que no es json")
	f.close()
	var got := RoomLib.read_file(path)
	check(got.rooms.size() == 3 and got.bad == 1, "se leen las 3 salas y se cuenta 1 línea mala (%d, %d)" % [got.rooms.size(), got.bad])
	check(RoomLib.write_file(path, got.rooms), "se reescribe el archivo")
	var again := RoomLib.read_file(path)
	check(again.rooms.size() == 3 and again.bad == 0, "al reescribir desaparece la línea mala")
	check(not FileAccess.file_exists(path + ".tmp"), "no queda el archivo temporal")
	check(RoomLib.read_file(dir + "/no_existe.jsonl").rooms.size() == 0, "un archivo que no existe se lee vacío")
	var a := RoomLib.copy_room(rooms[0])
	var b := RoomLib.copy_room(rooms[0])
	a.opt = {"proof": "sin_probar", "moves": 5}
	b.opt = {"proof": "exacta", "moves": 5}
	check(RoomLib.better(a, b).opt.proof == "exacta", "la prueba exacta gana a la que no está probada")
	DirAccess.remove_absolute(path)
