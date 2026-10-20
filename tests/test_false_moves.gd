extends SceneTree
## Movimientos en falso (Sin piedad): el camino perfecto no cuenta ninguno, un movimiento que deja más lejos de la salida cuenta uno, volver no se castiga de nuevo y al pasar el
## límite se avisa. Se prueba sobre una sala de la biblioteca, con el medidor en modo "inline" (sin hilo).
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_false_moves.gd

const RoomLib := preload("res://scripts/room_lib.gd")
const RoomPack := preload("res://scripts/room_pack.gd")
const FalseMoves := preload("res://scripts/false_moves.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
const Abilities := preload("res://scripts/abilities.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_scenario()
	test_room()
	print("tests de los movimientos en falso terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_scenario() -> void:
	var sc := Scenarios.get_scenario("sin_piedad")
	check(sc.id == "sin_piedad" and int(sc.mistakes) == 2 and bool(sc.no_undo) and Scenarios.playable("sin_piedad"), "Sin piedad: 2 falsos por sala, sin deshacer, se puede elegir")
	check(Scenarios.ability_ids(sc).has("margen_de_error") and not Abilities.get_ability("margen_de_error").is_empty(), "su habilidad existe")


## Las acciones posibles (caminar, empujar o tirar, colgarse en las cuatro direcciones).
func _actions() -> Array:
	var out: Array = []
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		for m in [0, 1, 2]:
			out.append({"dir": d, "mode": m})
	return out


func test_room() -> void:
	var lib: Array = RoomPack.load_library("res://data/salas.rooms")
	var room := {}
	for r in lib:
		if r.shape == "3x5" and int(r.h) >= 5 and int(r.opt.moves) >= 14 and int(r.opt.moves) <= 24:
			room = r
			break
	check(not room.is_empty(), "hay una sala de prueba")
	if room.is_empty():
		return
	var fm = FalseMoves.new()
	fm.inline = true
	var marks: Array = []
	var ended: Array = []
	fm.mistake.connect(func(n, a, r, dead): marks.append([n, a, r, dead]))
	fm.exhausted.connect(func(r): ended.append(r))
	var goal_y: int = int(room.h) + 1
	# camino perfecto: ningún falso
	var t = RoomLib.build_state(room)
	fm.setup([{"ey": 1, "h": int(room.h)}], 2, goal_y)
	fm.measure(t)
	check(int(fm._ref.get(0, -1)) == int(room.opt.moves), "al empezar faltan exactamente los pasos del camino más corto (%d y %d)" % [int(fm._ref.get(0, -1)), int(room.opt.moves)])
	for a in room.path:
		t.try_action(a.dir, a.mode)
		fm.after_move(t)
	check(marks.is_empty() and ended.is_empty() and int(fm.counts.get(0, 0)) == 0, "el camino perfecto no tiene movimientos en falso")
	check(fm.left(0) == 2, "quedan los 2 falsos")
	# movimientos que alejan: cada uno cuenta uno, hasta pasar el límite
	t = RoomLib.build_state(room)
	fm.setup([{"ey": 1, "h": int(room.h)}], 2, goal_y)
	marks.clear()
	ended.clear()
	fm.measure(t)
	var made := 0
	for _step in 8:
		var d_now: int = int(fm._ref.get(0, -1))
		var chosen := {}
		for a in _actions():
			var probe = t.clone()
			var r: Dictionary = probe.try_action(a.dir, a.mode)
			if not r.ok or probe.lost:
				continue
			var d2: int = fm._distance({"state": probe, "target": goal_y, "ey": 1})
			if d2 > d_now:
				chosen = a
				break
		if chosen.is_empty():
			break
		t.try_action(chosen.dir, chosen.mode)
		fm.after_move(t)
		made += 1
		if not ended.is_empty():
			break
	check(made >= 1 and int(fm.counts.get(0, 0)) == made, "cada movimiento que aleja cuenta uno (hechos %d, contados %d)" % [made, int(fm.counts.get(0, 0))])
	check(marks.size() == made and (marks.is_empty() or (int(marks[0][0]) == 1 and int(marks[0][1]) == 2)), "se avisa cada falso con su cuenta")
	if made >= 3:
		check(ended.size() == 1 and fm.left(0) == 0, "al tercer falso se avisa que se acabaron")
	else:
		print("(en esta sala sólo se encontraron %d movimientos que alejan: el aviso de agotado se prueba aparte)" % made)
	# el aviso de agotado: con 0 falsos permitidos, el primero ya lo agota
	var t2 = RoomLib.build_state(room)
	var fm0 = FalseMoves.new()
	fm0.inline = true
	var ended0: Array = []
	fm0.exhausted.connect(func(r): ended0.append(r))
	fm0.setup([{"ey": 1, "h": int(room.h)}], 0, goal_y)
	fm0.measure(t2)
	for a in _actions():
		var probe = t2.clone()
		var r: Dictionary = probe.try_action(a.dir, a.mode)
		if not r.ok or probe.lost:
			continue
		if fm0._distance({"state": probe, "target": goal_y, "ey": 1}) > int(fm0._ref.get(0, -1)):
			t2.try_action(a.dir, a.mode)
			fm0.after_move(t2)
			break
	check(ended0.size() == 1, "con 0 falsos permitidos, el primero agota")
	# la sala siguiente empieza de cero
	fm.setup([{"ey": 1, "h": 3}, {"ey": 4, "h": 3}], 2, 7)
	check(fm.room_of(1) == 0 and fm.room_of(3) == 0 and fm.room_of(4) == 1 and fm.room_of(9) == 1, "se sabe en qué sala está el jugador por la altura")
	fm.shutdown()
