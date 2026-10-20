extends SceneTree
## Prototipos de las ideas nuevas del Glaciar (patinaje, billar de precisión, escalada, tobogán, puente, embudo): por cada idea arma salas al azar (scripts/glaciar_gen.gd), las resuelve con
## el A* exacto, se queda con las que cumplen lo que esa idea promete y elige las N más distintas entre sí (para que se entienda la idea con buena variación).
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/probe_glaciar_ideas.gd -- CARPETA [N=25] [SEMILLA=1] [IDEAS separadas por comas] [INTENTOS_MAX=2500]
const RoomLib := preload("res://scripts/room_lib.gd")
const Pack := preload("res://scripts/room_pack.gd")
const Gen := preload("res://scripts/glaciar_gen.gd")

var rng := RandomNumberGenerator.new()


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "bibliotecas/glaciar_prototipo/ideas"
	var want := int(args[1]) if args.size() > 1 else 25
	rng.seed = int(args[2]) if args.size() > 2 else 1
	var ideas: Array = Array(args[3].split(",")) if args.size() > 3 else Gen.IDEAS.duplicate()
	var max_attempts := int(args[4]) if args.size() > 4 else 2500
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var all: Array = []
	for idea in ideas:
		var res := _run_idea(idea, want, max_attempts)
		var picked: Array = res.picked
		for r in picked:
			all.append(r)
		Pack.write_library(picked, ProjectSettings.globalize_path(dir).path_join("%s.rooms" % idea), true)
		print("%s: %d intentos · %d válidas · %d resueltas · %d cumplen · %d elegidas · %s" % [idea, res.attempts, res.valid, res.solved, res.good.size(), picked.size(), str(res.why)])
		print("    pasos %s · resbalones %s · empujes %s · hielo movido %s · colgadas %s · caídas %s · alturas %s" % [_range(picked, "moves"), _range(picked, "slides"), _range(picked, "grabs"), _range(picked, "ice_moved"), _range(picked, "colgadas"), _range(picked, "drops"), _range_h(picked)])
	Pack.write_library(all, ProjectSettings.globalize_path(dir).path_join("ideas_glaciar.rooms"), true)
	print("total: %d salas en %s" % [all.size(), dir])
	quit(0)


func _run_idea(idea: String, want: int, max_attempts: int) -> Dictionary:
	var shapes: Array = Gen.shapes_for(idea)
	var hs: Array = Gen.heights_for(idea)
	var good: Dictionary = {}
	var why := {}
	var valid := 0
	var solved := 0
	var attempts := 0
	var target := want * 4
	while attempts < max_attempts and good.size() < target:
		attempts += 1
		var shape: String = shapes[attempts % shapes.size()]
		var room := Gen.random_room(rng, shape, int(hs[rng.randi_range(0, hs.size() - 1)]), idea)
		if room.is_empty():
			why["no_arma"] = int(why.get("no_arma", 0)) + 1
			continue
		var bad := RoomLib.validate_structure(room)
		if bad != "":
			why[bad] = int(why.get(bad, 0)) + 1
			continue
		valid += 1
		var ver := RoomLib.verify_exact(room, 60000, 4000)
		if ver.proof != "exacta":
			why[str(ver.proof)] = int(why.get(str(ver.proof), 0)) + 1
			continue
		solved += 1
		room["path"] = ver.path
		RoomLib.apply_result(room, ver.path, "exacta", int(ver.moves), int(ver.states))
		if not RoomLib.outside_cells(room).is_empty():   # (el camino se apoya en el hueco del core, en otra sala o en el vacío: no sirve)
			why["sale_de_la_arena"] = int(why.get("sale_de_la_arena", 0)) + 1
			continue
		var tc := RoomLib.technique_counts(room)
		room.opt["colgadas"] = int(tc.colgadas)
		room.opt["arenisca"] = int(tc.arenisca)
		room.opt["drops"] = _drops(room)
		room.opt["slides_all"] = _slides_all(room)
		room.opt["source"] = "glaciar"
		room.opt["familia"] = idea
		if not _promise_kept(idea, room):
			why["no_cumple"] = int(why.get("no_cumple", 0)) + 1
			continue
		good[room.id] = room
	var list: Array = good.values()
	return {"attempts": attempts, "valid": valid, "solved": solved, "good": list, "picked": _diverse(list, want), "why": why}


## Lo que promete cada idea (si no, la sala resuelta no sirve para mostrarla).
func _promise_kept(idea: String, room: Dictionary) -> bool:
	var o: Dictionary = room.opt
	match idea:
		"patinaje":
			return int(o.slides_all) >= 3 and int(o.moves) >= 6
		"billar_precision":
			return int(o.ice_moved) >= 1 and int(o.grabs) >= 3 and int(o.moves) >= 8
		"escalada":
			return int(o.moves) >= 12 and (int(o.colgadas) >= 1 or int(o.grabs) >= 4)
		"tobogan":
			return int(o.drops) >= 1 and int(o.slides) >= 3 and int(o.moves) >= 8
		"puente":
			return int(o.moves) >= 10 and (int(o.arenisca) >= 1 or int(o.slides) >= 3)
		"embudo":
			return int(o.slides) >= 3 and int(o.moves) >= 10
	return true


## Cuántas veces el camino mueve al jugador dos casillas o más de golpe (resbalones, también cuando cambia de altura).
func _slides_all(room: Dictionary) -> int:
	var t = RoomLib.build_state(room)
	var n := 0
	for a in room.path:
		var p: Vector3i = t.player
		t.try_action(a.dir, a.mode)
		if a.mode == 0 and absi(t.player.x - p.x) + absi(t.player.z - p.z) >= 2:
			n += 1
	return n


## Cuántas veces el camino baja dos niveles o más de golpe (se tira a propósito).
func _drops(room: Dictionary) -> int:
	var t = RoomLib.build_state(room)
	var n := 0
	for a in room.path:
		var y: int = t.player.y
		t.try_action(a.dir, a.mode)
		if y - t.player.y >= 2:
			n += 1
	return n


func _features(r: Dictionary) -> Array:
	var shapes := ["3x3", "3x5", "3x8", "L", "U"]
	var o: Dictionary = r.opt
	return [float(o.moves) / 25.0, float(o.get("slides_all", o.slides)) / 10.0, float(o.grabs) / 10.0, float(o.get("ice_moved", 0)) / 6.0, float(r.h) / 8.0, float(r.cells.size()) / 40.0,
			float(r.cols.size()) / 40.0, float(shapes.find(r.shape)) / 4.0, float(o.get("colgadas", 0)) / 4.0, float(o.get("drops", 0)) / 3.0, float(o.get("arenisca", 0)) / 4.0]


## Las `n` más distintas entre sí (se parte de la de más pasos y se agrega siempre la más lejana de las ya elegidas).
func _diverse(list: Array, n: int) -> Array:
	if list.size() <= n:
		return list
	var feats: Array = []
	for r in list:
		feats.append(_features(r))
	var first := 0
	for i in list.size():
		if int(list[i].opt.moves) > int(list[first].opt.moves):
			first = i
	var chosen: Array = [first]
	var dist: Array = []
	for i in list.size():
		dist.append(_dist(feats[i], feats[first]))
	while chosen.size() < n:
		var best := -1
		for i in list.size():
			if chosen.has(i):
				continue
			if best < 0 or dist[i] > dist[best]:
				best = i
		chosen.append(best)
		for i in list.size():
			dist[i] = minf(dist[i], _dist(feats[i], feats[best]))
	var out: Array = []
	for i in chosen:
		out.append(list[i])
	return out


func _dist(a: Array, b: Array) -> float:
	var s := 0.0
	for i in a.size():
		s += (float(a[i]) - float(b[i])) * (float(a[i]) - float(b[i]))
	return s


func _range(list: Array, key: String) -> String:
	if list.is_empty():
		return "-"
	var lo := 999
	var hi := -999
	for r in list:
		var v := int(r.opt.get(key, 0))
		lo = mini(lo, v)
		hi = maxi(hi, v)
	return "%d-%d" % [lo, hi]


func _range_h(list: Array) -> String:
	var counts := {}
	for r in list:
		counts[int(r.h)] = int(counts.get(int(r.h), 0)) + 1
	return str(counts)
