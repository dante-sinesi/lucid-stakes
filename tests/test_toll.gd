extends SceneTree
## Pruebas del peaje del duende, que cobra en la puerta de salida del casino (la torre ya no cobra).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_toll.gd

const RunState := preload("res://scripts/run_state.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const CasinoScene := preload("res://scripts/casino_scene.gd")

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
	test_curve()
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
	check(main.logic.toll == 0, "la torre ya no cobra peaje (el duende está en la puerta de salida del casino)")
	check(main.goal_nodes.size() == 1, "en la meta sólo está el portal")
	main.queue_free()
	await process_frame
	# el duende de la puerta del casino
	var rng := RandomNumberGenerator.new()
	var run := RunState.new()
	run.stage = 2
	run.claridad = 10
	var c = CasinoScene.new()
	c.quick = true
	c.toll_base = RunState.toll_for(3)
	root.add_child(c)
	c.setup(run, rng)
	var left_n := [0]
	var failed_n := [0]
	c.left.connect(func(): left_n[0] += 1)
	c.failed_to_pay.connect(func(): failed_n[0] += 1)
	c.cell = c.lay.exit
	check(c.step(Vector2i(0, -1)) == "blocked" and left_n[0] == 0 and failed_n[0] == 0 and run.claridad == 10, "sin claridad suficiente el duende no deja pasar la primera vez (y avisa)")
	check(c.step(Vector2i(0, -1)) == "exit" and failed_n[0] == 1 and left_n[0] == 0 and run.claridad == 10, "si se insiste sin poder pagar: se vuelve a subir la torre (se pierde una vida), sin cobrar claridad")
	c.queue_free()
	await process_frame
	run.claridad = RunState.toll_for(3) + 7
	var c2 = CasinoScene.new()
	c2.quick = true
	c2.toll_base = RunState.toll_for(3)
	root.add_child(c2)
	c2.setup(run, rng)
	c2.left.connect(func(): left_n[0] += 1)
	c2.cell = c2.lay.exit
	check(c2.step(Vector2i(0, -1)) == "exit" and left_n[0] == 1 and run.claridad == 7, "con claridad suficiente se paga el precio y se pasa")
	c2.queue_free()
	await process_frame
	var c3 = CasinoScene.new()   # sin peaje (tutorial, entrenamiento, pruebas): se pasa gratis
	c3.quick = true
	root.add_child(c3)
	c3.setup(run, rng)
	c3.left.connect(func(): left_n[0] += 1)
	c3.cell = c3.lay.exit
	var before: int = run.claridad
	check(c3.step(Vector2i(0, -1)) == "exit" and left_n[0] == 2 and run.claridad == before, "sin peaje se pasa gratis")
	c3.queue_free()


## La curva del duende (RunState.toll_for): antes de la pared se puede pagar con lo que rinde una torre; desde la etapa WALL_STAGE no, ni con el máximo de cada torre sin gastar nada.
func test_curve() -> void:
	var cum_toll := 0.0
	var cum_max := 0.0
	var prev := 0
	for s in range(1, 16):
		var t := RunState.toll_for(s)
		check(t > prev, "el precio sube en cada etapa (etapa %d: %d)" % [s, t])
		prev = t
		cum_toll += float(t)
		cum_max += RunState.income_ceiling(s)
		if s < RunState.WALL_STAGE:
			check(float(t) < RunState.income_fit(s), "antes de la pared el precio es menos que lo que rinde una torre (etapa %d)" % s)
			check(RunState.max_budget_without_boosts(s) > float(t), "antes de la pared se puede pagar sin boosts (etapa %d)" % s)
		else:
			check(float(t) > RunState.max_budget_without_boosts(s), "desde la pared no se puede pagar sin boosts, ni juntando el máximo y sin gastar nada (etapa %d: %d contra %.0f)" % [s, t, RunState.max_budget_without_boosts(s)])
			check(cum_toll > cum_max, "el precio acumulado supera al presupuesto máximo acumulado (etapa %d)" % s)
