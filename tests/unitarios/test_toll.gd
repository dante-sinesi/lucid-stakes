extends SceneTree
## Pruebas del peaje de Farolín, que cobra en la puerta de salida del casino (la torre ya no cobra).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_toll.gd

const RunState := preload("res://scripts/datos/run_state.gd")
const CasinoScene := preload("res://scripts/casino/casino_scene.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	check(RunState.toll_for(1) < RunState.toll_for(15), "el peaje sube con la etapa")
	check(RunState.toll_for(1) > 0, "siempre hay peaje")
	test_curve()
	test_peaje_por_dificultad()
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
	while main.generating or main.torre == null:
		await process_frame
	check(main.torre != null, "la torre no cobra peaje (Farolín está en la puerta de salida del casino)")
	main.queue_free()
	await process_frame
	# Farolín en la puerta del casino: al llegar abre su diálogo (pagar, rehacer la torre o abandonar)
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
	var talk_n := [0]
	c.left.connect(func(): left_n[0] += 1)
	c.toll_talk.connect(func(): talk_n[0] += 1)
	c.cell = c.lay.exit
	check(c.step(Vector2i(0, -1)) == "blocked" and left_n[0] == 0 and talk_n[0] == 1 and run.claridad == 10, "al llegar a la puerta Farolín habla (no se paga ni se pasa solo)")
	var d: Dictionary = c.toll_dialog()
	check(d.options.size() == 2 and d.options[0].id == "pagar" and not d.options[0].enabled and d.options[1].id == "rehacer" and d.options[1].enabled, "sin claridad: Pagar apagado y Rehacer la torre disponible")
	check(not c.pay_toll() and left_n[0] == 0 and run.claridad == 10, "pagar sin que alcance no hace nada")
	run.lives = 0
	d = c.toll_dialog()
	check(d.options[1].id == "abandonar" and not d.options[0].enabled, "sin vidas ni claridad: sólo se puede abandonar")
	run.lives = 3
	check(c.farolin_cell_free(), "la celda de Farolín está libre de muebles")
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
	check(c2.step(Vector2i(0, -1)) == "blocked", "con claridad de sobra también habla Farolín (hay que elegir pagar)")
	d = c2.toll_dialog()
	check(d.options[0].enabled and d.options[0].id == "pagar", "con claridad suficiente Pagar está habilitado")
	check(c2.pay_toll() and left_n[0] == 1 and run.claridad == 7, "al pagar se cobra el precio y se pasa")
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


## La dificultad elegida cambia el peaje: Fácil cobra menos, Difícil y Pesadilla más (RunState.toll_dif).
func test_peaje_por_dificultad() -> void:
	var precios := {}
	for dif in ["facil", "media", "dificil", "pesadilla"]:
		var r := RunState.new()
		r.dificultad = dif
		precios[dif] = r.toll_after_discounts(1000)
	check(precios.media == 1000, "en Medio el peaje es el de la curva (%d)" % precios.media)
	check(precios.facil < precios.media and precios.media < precios.dificil and precios.dificil < precios.pesadilla, "el peaje sube con la dificultad (%s)" % str(precios))


## La curva de Farolín (RunState.toll_for): antes de la pared se paga con lo que rinde una torre; desde la etapa WALL_STAGE el precio supera lo que rinde una torre sin boosts (hay que tener un build o haber ahorrado).
func test_curve() -> void:
	var prev := 0
	for s in range(1, 16):
		var t := RunState.toll_for(s)
		check(t > prev, "el precio sube en cada etapa (etapa %d: %d)" % [s, t])
		prev = t
		if s <= RunState.HILL_START:
			check(float(t) < RunState.income_fit(s), "antes de la colina el precio es menos que lo que rinde una torre (etapa %d)" % s)
			check(RunState.max_budget_without_boosts(s) > float(t), "antes de la colina se puede pagar sin boosts (etapa %d)" % s)
		elif s < RunState.WALL_STAGE:
			check(float(t) > float(RunState.toll_for(s - 1)) * 1.1, "la colina sube de a poco (etapa %d)" % s)
		else:
			check(float(t) > RunState.income_fit(s), "desde la pared el precio supera lo que rinde una torre sin boosts (etapa %d: %d contra %.0f)" % [s, t, RunState.income_fit(s)])
