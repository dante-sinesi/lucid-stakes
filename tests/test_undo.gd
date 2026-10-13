extends SceneTree
## Pruebas de deshacer el último movimiento. Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_undo.gd

const TowerLogic := preload("res://scripts/tower_logic.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	await test_undo()
	print("tests de deshacer terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_undo() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	main.in_menu = false
	var t := TowerLogic.new()
	t.size = Vector2i(5, 5)
	t.goal_y = 99
	t.collapse_every = 1000
	t.moves_to_collapse = 1000
	for x in 5:
		for z in 5:
			t.add_block(Vector3i(x, 0, z))
	t.add_block(Vector3i(3, 1, 2))
	t.player = Vector3i(2, 1, 2)
	main.stage_start = t
	main.restart()
	main.generating = false
	check(main.undo_stack.is_empty(), "al empezar no hay nada que deshacer")
	main.undo_move()
	check(main.logic.player == Vector3i(2, 1, 2), "deshacer sin historia no hace nada")
	main._apply(Vector3i(0, 0, 1), TowerLogic.Mode.MOVE)
	while main.busy:
		await process_frame
	check(main.logic.player == Vector3i(2, 1, 3) and main.undo_stack.size() == 1, "un movimiento se anota")
	main.undo_move()
	check(main.logic.player == Vector3i(2, 1, 2) and main.undo_stack.is_empty() and main.logic.moves_made == 0, "deshacer vuelve el movimiento (y la cuenta)")
	main._apply(Vector3i(1, 0, 0), TowerLogic.Mode.GRAB)   # empujar el bloque
	while main.busy:
		await process_frame
	check(main.logic.blocks.has(Vector3i(4, 1, 2)) and not main.logic.blocks.has(Vector3i(3, 1, 2)), "se empujó el bloque")
	main.undo_move()
	check(main.logic.blocks.has(Vector3i(3, 1, 2)) and not main.logic.blocks.has(Vector3i(4, 1, 2)), "deshacer vuelve el bloque")
	check(main.block_nodes.size() == main.logic.positions.size(), "y la vista tiene un nodo por bloque")
	main._apply(Vector3i(0, 0, -1), TowerLogic.Mode.MOVE)
	while main.busy:
		await process_frame
	main.restart()
	check(main.undo_stack.is_empty(), "reintentar vacía la historia")
	main._cancel_jobs()
	main.queue_free()
	await process_frame
