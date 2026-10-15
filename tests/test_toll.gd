extends SceneTree
## Pruebas del peaje del duende en el portal de salida de la torre.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_toll.gd

const RunState := preload("res://scripts/run_state.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	check(RunState.toll_for(1) < RunState.toll_for(15), "el peaje sube con la etapa")
	check(RunState.toll_for(1) > 0, "siempre hay peaje")
	var t := TowerLogic.new()
	t.toll = 50
	t.wallet = 10
	t.claridad = 30
	check(not t.can_pay_toll(), "40 < 50: no alcanza")
	t.claridad = 40
	check(t.can_pay_toll(), "50 >= 50: alcanza")
	var c = t.clone()
	check(c.toll == 50 and c.wallet == 10, "el clon conserva el peaje")
	t.toll = 0
	check(t.can_pay_toll(), "sin peaje siempre se paga")
	await _scene()
	print("tests del peaje terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func _scene() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	main.toll_in_tests = true
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	check(main.logic.toll == RunState.toll_for(main.stage_number), "la torre arranca con el peaje de su etapa")
	check(main.goal_nodes.size() == 2, "portal y duende en la meta")
	main.run.claridad = 0
	var before: int = main.run.claridad
	main.logic.claridad = main.logic.toll
	main.logic.wallet = 0
	main.banked = false
	main._bank_claridad()
	check(main.run.claridad == maxi(before + main.logic.claridad - main.logic.toll, 0), "se cobra el peaje al salir")
	main.queue_free()
