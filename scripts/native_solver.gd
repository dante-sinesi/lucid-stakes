extends RefCounted
## Puente al solucionador nativo (native/solver_nativo.cpp, compilado a tools/solver_nativo.exe): arma el archivo de entrada con el estado, corre el programa y lee el resultado.
## Resuelve lo mismo que Solver.solve (mismas reglas y mismo A*), mucho más rápido. Si el programa no está, o el estado tiene algo que no entiende (bombas, catapultas, trampas, pinchos,
## boosts, la caída de la fila base), `solve` devuelve {} y el llamador usa el solucionador de GDScript.

const TowerLogic := preload("res://scripts/tower_logic.gd")
const DIR_CHARS := "EWSN"
const MODE_CHARS := "mgh"

static var _exe := ""
static var _looked := false
static var _counter := 0
static var _mutex := Mutex.new()
static var total_usec := 0
static var calls := 0


static func exe_path() -> String:
	if _looked:
		return _exe
	_looked = true
	var candidates: Array = []
	var base := OS.get_executable_path().get_base_dir()
	candidates.append(base.path_join("solver_nativo.exe"))
	candidates.append(base.path_join("tools").path_join("solver_nativo.exe"))
	candidates.append(ProjectSettings.globalize_path("res://tools/solver_nativo.exe"))
	candidates.append(ProjectSettings.globalize_path("res://build/herramientas/solver_nativo.exe"))
	for c in candidates:
		if FileAccess.file_exists(c):
			_exe = c
			break
	return _exe


static func available() -> bool:
	return exe_path() != "" and OS.get_name() == "Windows" and not OS.has_environment("SIN_NATIVO")


## ¿El estado usa sólo lo que entiende el programa nativo?
static func supported(s) -> bool:
	if not s.perks.is_empty() or not s.anchored.is_empty() or s.meteors or s.shield or s.double_jump or s.collapse_pause > 0:
		return false
	if not s.bomb_timer.is_empty():
		return false
	for id in s.kind_of:
		var k: int = s.kind_of[id]
		if k == TowerLogic.Kind.BOMB or k == TowerLogic.Kind.CATAPULT or k == TowerLogic.Kind.TRAP or k == TowerLogic.Kind.SPIKES:
			return false
	return true


static func _tmp_name(tag: String) -> String:
	_mutex.lock()
	_counter += 1
	var n := _counter
	_mutex.unlock()
	var dir := OS.get_user_data_dir().path_join("nativo")
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	return dir.path_join("%d_%d_%d_%s.txt" % [OS.get_process_id(), OS.get_thread_caller_id(), n, tag])


static func _write_input(s, target_y: int, goal_ids: Dictionary, header: Array, extra: Array) -> String:
	var lines: Array = []
	lines.append("SIZE %d %d" % [s.size.x, s.size.y])
	lines.append("FLOORY %d" % s.floor_y)
	lines.append("GOALY %d" % target_y)
	lines.append("PLAYER %d %d %d" % [s.player.x, s.player.y, s.player.z])
	lines.append("HANG %d %d %d" % [s.hang_dir.x, s.hang_dir.y, s.hang_dir.z])
	lines.append("DIRTY %d" % (1 if s._blocks_dirty else 0))
	for h in header:
		lines.append(h)
	for c in s.blocks:
		var id: int = s.blocks[c]
		var kind: int = s.kind_of.get(id, 0)
		lines.append("BLOCK %d %d %d %d %d %d %d" % [c.x, c.y, c.z, kind, 1 if s.fixed.has(c) else 0, 1 if goal_ids.has(id) else 0, 1 if s.standing.has(id) else 0])
	for e in extra:
		lines.append(e)
	lines.append("END")
	return "\n".join(lines) + "\n"


static func _run(text: String, tag: String) -> Dictionary:
	var fin := _tmp_name(tag + "_in")
	var fout := _tmp_name(tag + "_out")
	var f := FileAccess.open(fin, FileAccess.WRITE)
	if f == null:
		return {}
	f.store_string(text)
	f.close()
	var code := OS.execute(exe_path(), PackedStringArray([fin, fout]), [], true)
	var res := {}
	if code == 0 and FileAccess.file_exists(fout):
		var r := FileAccess.open(fout, FileAccess.READ)
		if r != null:
			res = {"text": r.get_as_text()}
			r.close()
	DirAccess.remove_absolute(fin)
	DirAccess.remove_absolute(fout)
	return res


## Igual que Solver.solve (mismas opciones: max_states, max_ms, heuristic, no_grab, goal_ids, admissible, h_weight). {} si no se puede usar el nativo.
static func solve(start, target_y: int, opts: Dictionary, prepared) -> Dictionary:
	if not available() or opts.get("use_collapse", false) or opts.get("prefer_plain", false):
		return {}
	if not supported(prepared) or prepared.goal_block >= 0:
		return {}
	var t0 := Time.get_ticks_usec()
	var goal_ids: Dictionary = opts.get("goal_ids", {})
	var heur := "prod"
	if not opts.get("heuristic", true):
		heur = "none"
	elif opts.get("admissible", false):
		heur = "adm"
	var header: Array = [
		"MODE solve",
		"MAXSTATES %d" % int(opts.get("max_states", 300000)),
		"MAXMS %d" % int(opts.get("max_ms", 0)),
		"HEUR %s" % heur,
		"WEIGHT %f" % float(opts.get("h_weight", 1.0)),
		"NOGRAB %d" % (1 if opts.get("no_grab", false) else 0),
	]
	var out: Dictionary = _run(_write_input(prepared, target_y, goal_ids, header, []), "s")
	if out.is_empty():
		return {}
	var res: Dictionary = _parse(out.text, prepared)
	calls += 1
	total_usec += Time.get_ticks_usec() - t0
	return res


static func _parse(text: String, prepared) -> Dictionary:
	var status := ""
	var states := 0
	var freached := 0
	var path_text := ""
	for line in text.split("\n"):
		var parts: PackedStringArray = line.strip_edges().split(" ")
		if parts.size() < 2:
			continue
		match parts[0]:
			"STATUS":
				status = parts[1]
			"STATES":
				states = int(parts[1])
			"FREACHED":
				freached = int(parts[1])
			"PATH":
				path_text = parts[1]
	if status == "unsupported" or status == "":
		return {}
	if status == "solved":
		var path: Array = []
		var s = prepared.clone()
		if path_text != "-":
			for i in range(0, path_text.length(), 2):
				var mode := MODE_CHARS.find(path_text[i])
				var d: Vector3i = TowerLogic.DIRS[DIR_CHARS.find(path_text[i + 1])]
				path.append({"dir": d, "mode": mode})
				s.try_action(d, mode)
		return {"status": "solved", "moves": path.size(), "path": path, "states": states, "state": s}
	if status == "unsolvable":
		return {"status": "unsolvable", "moves": -1, "path": [], "states": states, "state": null}
	return {"status": "limit", "moves": -1, "path": [], "states": states, "state": null, "f_reached": freached}


## Para las pruebas: aplica las acciones en el programa nativo y devuelve, por cada una, [ok, px, py, pz, hx, hy, hz, lost, won, zob, dirty].
static func sim(s, target_y: int, goal_ids: Dictionary, actions: Array) -> Array:
	var extra: Array = []
	for a in actions:
		extra.append("ACTION %d %d" % [TowerLogic.DIRS.find(a.dir), int(a.mode)])
	var out: Dictionary = _run(_write_input(s, target_y, goal_ids, ["MODE sim"], extra), "t")
	var rows: Array = []
	if out.is_empty():
		return rows
	for line in out.text.split("\n"):
		var parts: PackedStringArray = line.strip_edges().split(" ")
		if parts.size() >= 12 and parts[0] == "R":
			var row: Array = []
			for i in range(1, 12):
				row.append(int(parts[i]))
			rows.append(row)
	return rows


## Excavar: explora el grafo de estados cerca de la sala (`t` es el estado de la sala: RoomLib.build_state) y devuelve las salas candidatas más difíciles que se alcanzan desde ella.
## {status, nodes, edges, wins, maxd, maxg, cands: [{d, g, blocks: [[x, y, z, tipo], ...]}]}; d y g son los pasos y los agarres exactos (dentro de lo explorado) que faltan desde ese candidato.
## {} si el nativo no está o la sala usa algo que no entiende.
static func excavate(t, entry: Vector2i, exit: Vector2i, path_text := "", max_nodes := 1000000, top_k := 20, min_d := 0, columns_only := true, max_y := 19) -> Dictionary:
	if not available():
		return {}
	var s = t.clone()
	s.lazy_settle = true
	if not supported(s):
		return {}
	var header: Array = ["MODE excavate", "MAXNODES %d" % max_nodes, "TOPK %d" % top_k, "MIND %d" % min_d, "ENTRY %d %d" % [entry.x, entry.y], "EXIT %d %d" % [exit.x, exit.y], "HEUR none", "COLUMNS %d" % (1 if columns_only else 0), "MAXY %d" % max_y]
	if path_text != "":
		header.append("PATH " + path_text)
	var out: Dictionary = _run(_write_input(s, t.goal_y, t.goal_ids, header, []), "x")
	if out.is_empty():
		return {}
	var res := {"status": "", "nodes": 0, "edges": 0, "wins": 0, "maxd": 0, "maxg": 0, "ms": 0, "cands": []}
	for line in out.text.split("\n"):
		var parts: PackedStringArray = line.strip_edges().split(" ")
		if parts.size() < 2:
			continue
		match parts[0]:
			"STATUS":
				res.status = parts[1]
			"NODES":
				res.nodes = int(parts[1])
			"EDGES":
				res.edges = int(parts[1])
			"WINS":
				res.wins = int(parts[1])
			"MAXD":
				res.maxd = int(parts[1])
			"MAXG":
				res.maxg = int(parts[1])
			"MS":
				res.ms = int(parts[1])
			"CAND":
				var blocks: Array = []
				if parts.size() >= 4:
					for b in parts[3].split(";"):
						var f: PackedStringArray = b.split(",")
						if f.size() == 4:
							blocks.append([int(f[0]), int(f[1]), int(f[2]), int(f[3])])
				res.cands.append({"d": int(parts[1]), "g": int(parts[2]), "blocks": blocks})
	return res
