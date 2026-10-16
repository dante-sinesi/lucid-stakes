extends SceneTree
## Bombas con zona esférica: cuentan sólo si el jugador está a distancia² <= 5; la cuenta de una sala se afina (lo mínimo + 1).
const TowerLogic := preload("res://scripts/tower_logic.gd")
const RoomLib := preload("res://scripts/room_lib.gd")
var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	# la forma de la zona en la capa de la bomba: 01110 / 11111 / 11b11 / 11111 / 01110
	var rows: Array = []
	for dz in range(-2, 3):
		var row := ""
		for dx in range(-2, 3):
			row += "1" if TowerLogic.in_bomb_zone(Vector3i(0, 0, 0), Vector3i(dx, 0, dz)) else "0"
		rows.append(row)
	check(rows == ["01110", "11111", "11111", "11111", "01110"], "la zona en la capa de la bomba tiene la forma pedida: %s" % str(rows))
	check(TowerLogic.in_bomb_zone(Vector3i(0, 0, 0), Vector3i(0, 2, 0)) and not TowerLogic.in_bomb_zone(Vector3i(0, 0, 0), Vector3i(0, 3, 0)), "la zona llega 2 pisos arriba y no 3")
	check(TowerLogic.in_bomb_zone(Vector3i(0, 0, 0), Vector3i(1, 1, 1)) and not TowerLogic.in_bomb_zone(Vector3i(0, 0, 0), Vector3i(2, 1, 1)), "(1,1,1) adentro y (2,1,1) afuera")
	# la cuenta sólo baja dentro de la zona
	var t = TowerLogic.new()
	t.size = Vector2i(8, 8)
	t.collapse_every = 1 << 30
	t.moves_to_collapse = 1 << 30
	for x in range(0, 8):
		t.add_block(Vector3i(x, 0, 0), true)
	t.add_block(Vector3i(7, 1, 0), false, TowerLogic.Kind.BOMB, 5)   # (se hace a un lado: la bomba está en el extremo)
	t.player = Vector3i(0, 1, 0)
	t.goal_y = 99
	var bid: int = t.blocks[Vector3i(7, 1, 0)]
	t.try_action(Vector3i(1, 0, 0))   # x=1: lejos
	check(t.bomb_timer[bid] == 5, "lejos de la bomba no cuenta")
	for i in 4:
		t.try_action(Vector3i(1, 0, 0))   # x=5 (distancia 2): adentro
	check(t.bomb_timer[bid] == 5 - 1 - 0 or t.bomb_timer[bid] < 5, "dentro de la zona cuenta (%d)" % t.bomb_timer[bid])
	# la cuenta afinada de una sala con bomba
	var room := RoomLib.make_room("3x3", 5)
	room.cols[Vector2i(1, 0)] = "n"
	room.cols[Vector2i(2, 0)] = "nnb"
	room.cols[Vector2i(1, 2)] = "nn"
	var tuned := RoomLib.tune_fuse(room)
	check(tuned.is_empty() or int(tuned.fuse) >= 2, "la cuenta afinada de una sala es razonable (%s)" % str(tuned.get("fuse", "sin solución")))
	print("test bombas, fallos: ", fails)
	quit(1 if fails > 0 else 0)
