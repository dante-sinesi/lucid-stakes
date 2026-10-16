extends SceneTree
## Colgado de un bloque que tiene otro encima, con piso a los costados del borde (caso del jugador): ¿se puede pasar al piso del costado y quedar parado?
const TowerLogic := preload("res://scripts/tower_logic.gd")


func _init() -> void:
	var t = TowerLogic.new()
	t.size = Vector2i(8, 8)
	t.collapse_every = 1 << 30
	t.moves_to_collapse = 1 << 30
	for x in [2, 3, 4]:
		t.add_block(Vector3i(x, 0, 2), true)   # piso (capa de abajo, fila de atrás)
	t.add_block(Vector3i(3, 1, 2), false)      # el bloque del que se cuelga
	t.add_block(Vector3i(3, 2, 2), false)      # y el que tiene encima: no se puede trepar
	t.player = Vector3i(3, 1, 3)
	t.hang_dir = Vector3i(0, 0, -1)
	t.goal_y = 99
	var r = t.try_action(Vector3i(1, 0, 0), TowerLogic.Mode.MOVE)
	var fails := 0
	if not (r.ok and t.player == Vector3i(4, 1, 2) and t.hang_dir == Vector3i.ZERO):
		fails += 1
		print("FAIL: colgado con un bloque encima, el costado con piso: ", r, " jugador ", t.player, " colgado ", t.hang_dir)
	print("test colgado, fallos: ", fails)
	quit(1 if fails > 0 else 0)
