extends SceneTree
## Perfil del camino de las salas: a qué alturas se empuja y se tira. LIB, ID (prefijo; si no, resumen por altura).
const RoomLib := preload("res://scripts/room_lib.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")


func profile(r: Dictionary) -> Dictionary:
	var t = RoomLib.build_state(r)
	var ys: Array = []
	for a in r.path:
		if a.mode == TowerLogic.Mode.GRAB:
			ys.append(t.player.y)
		t.try_action(a.dir, a.mode)
	var lv := {}
	var mx := 0
	var mn := 99
	for y in ys:
		lv[y] = true
		mx = maxi(mx, y)
		mn = mini(mn, y)
	return {"levels": lv.size(), "max_y": mx, "min_y": mn if not ys.is_empty() else 0, "n": ys.size(), "ys": ys}


func _init() -> void:
	var rooms: Array = RoomLib.read_file(OS.get_environment("LIB")).rooms
	var want := OS.get_environment("ID")
	if want != "":
		for r in rooms:
			if str(r.id).begins_with(want):
				print(r.shape, " h", r.h, " ", profile(r))
		quit(0)
		return
	var agg := {}
	for r in rooms:
		var p := profile(r)
		var key := "h%d" % r.h
		if not agg.has(key):
			agg[key] = {"rooms": 0, "reach": 0.0, "levels": 0.0, "low": 0}
		agg[key].rooms += 1
		agg[key].reach += float(p.max_y) / float(r.h)
		agg[key].levels += float(p.levels)
		if float(p.max_y) < 0.5 * float(r.h):
			agg[key].low += 1
	for k in agg:
		print(k, ": ", agg[k].rooms, " salas, alcance medio ", snappedf(agg[k].reach / agg[k].rooms, 0.01), ", niveles medios ", snappedf(agg[k].levels / agg[k].rooms, 0.01), ", con empujes sólo en la mitad de abajo: ", agg[k].low)
	quit(0)
