extends SceneTree
## Qué técnicas usa de verdad el camino más corto de cada sala de una biblioteca: colgadas, patinazos, saltos de catapulta, pisadas en arenisca, trampas desarmadas. LIB, MIN (dificultad mínima, 0).
const RoomLib := preload("res://scripts/room_lib.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")


func _init() -> void:
	var rooms: Array = RoomLib.read_file(OS.get_environment("LIB")).rooms
	var min_d := float(OS.get_environment("MIN")) if OS.get_environment("MIN") != "" else 0.0
	var total := {}
	var rows: Array = []
	for r in rooms:
		if float(r.opt.get("diff", 0.0)) < min_d:
			continue
		var t = RoomLib.build_state(r)
		var f := {"colgadas": 0, "patinazos": 0, "saltos": 0, "arenisca": 0, "trampas": 0}
		for a in r.path:
			var before: Vector3i = t.player
			var kind: int = t.kind_at(before + Vector3i(0, -1, 0))
			t.try_action(a.dir, a.mode)
			if a.mode == TowerLogic.Mode.HANG or (t.hang_dir != Vector3i.ZERO and before != t.player and t.player.y == before.y - 1):
				f.colgadas += 1
			if a.mode == TowerLogic.Mode.MOVE and t.hang_dir == Vector3i.ZERO and absi(t.player.x - before.x) + absi(t.player.z - before.z) >= 2 and t.player.y == before.y:
				f.patinazos += 1
			if t.player.y - before.y >= 3:
				f.saltos += 1
			if kind == TowerLogic.Kind.CRACKED and t.player != before:
				f.arenisca += 1
			if t.trap_broke:
				f.trampas += 1
		for k in f:
			if int(f[k]) > 0:
				total[k] = int(total.get(k, 0)) + 1
		rows.append([r.shape, r.h, r.opt.diff, r.opt.grabs, r.opt.moves, f, str(r.id).substr(0, 8)])
	print("salas ", rows.size(), " que usan: ", total)
	rows.sort_custom(func(a, b): return float(a[2]) > float(b[2]))
	for k in ["colgadas", "patinazos", "saltos", "arenisca", "trampas"]:
		for row in rows:
			if int(row[5][k]) > 0:
				print("  %s: %s %dp id %s %d%% (%d de %d) %s" % [k, row[0], row[1], row[6], roundi(100.0 * float(row[2])), row[3], row[4], str(row[5])])
				break
	quit(0)
