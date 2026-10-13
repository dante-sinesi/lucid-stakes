extends SceneTree
## Pruebas de los servicios del casino (Rumores, Taller, Caja fuerte, Seguro), sus pantallas y cómo se enganchan a la sala y al run (headless).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_casino_services.gd

const Services := preload("res://scripts/casino_services.gd")
const ServiceScreens := preload("res://scripts/casino_service_screens.gd")
const Room := preload("res://scripts/casino_room.gd")
const Roulette := preload("res://scripts/roulette.gd")
const RunState := preload("res://scripts/run_state.gd")
const Items := preload("res://scripts/items.gd")
const CasinoScene := preload("res://scripts/casino_scene.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_layout()
	test_taller()
	test_vault()
	test_insurance()
	test_run_state()
	await test_screens()
	await test_scene()
	print("tests de los servicios del casino terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func make_run(stage := 5, claridad := 1000) -> RunState:
	var run := RunState.new()
	run.stage = stage
	run.claridad = claridad
	return run


func test_layout() -> void:
	var ids := []
	check(not Room.layout(1).has("station") and Services.service_for_tier(0) == "", "la taberna no tiene estación de servicio")
	for st in [5, 9, 13]:
		var lay := Room.layout(st)
		ids.append(lay.station.id)
		check(Services.service_for_tier(lay.tier) == lay.station.id, "la estación de la etapa %d es la de su nivel" % st)
		check(not Room.walkable(lay.station.cell, lay) and Room.in_room(lay.station.cell, lay), "la estación ocupa una celda de la sala (no se camina por ahí)")
		var reach := Room.reachable(lay.entry, lay)
		var near := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			near = near or reach.has(lay.station.cell + d)
		check(near, "se llega caminando hasta la estación de la etapa %d" % st)
		check(not Room.build_voxels(st).solid.is_empty(), "la sala de la etapa %d se arma con su estación" % st)
	check(ids == ["taller", "caja", "seguro"], "una estación distinta por nivel (menos la taberna): %s" % str(ids))


func test_taller() -> void:
	var run := make_run(5, 100)
	var price := Roulette.run_price(run)
	run.boosts.assign(["aire_extra", "reflejos"])
	run.consumables.assign(["freno", "desarmar"])
	check(Services.sell_price(run, "aire_extra") == int(round(100.0 * price / 50.0 * 0.4)), "el taller paga 40 % del valor del ítem")
	var before := run.claridad
	var res := Services.sell(run, "boost", 0)
	check(res.ok and run.boosts == ["reflejos"] and run.claridad == before + res.claridad, "vender un boost lo saca y paga")
	res = Services.sell(run, "consumable", 1)
	check(res.ok and run.consumables == ["freno"], "y un consumible")
	check(not Services.sell(run, "boost", 5).ok, "no se vende lo que no hay")
	# cambiar: mismo tipo y nivel
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	run.boosts.assign(["aire_extra"])
	var options := Services.swap_options(run, "boost", 0)
	check(options.size() >= 1 and options.all(func(o): return o.type == Items.Type.BOOST and o.tier == Items.get_item("aire_extra").tier and o.id != "aire_extra"), "las opciones de cambio son del mismo tipo y nivel")
	var bal := run.claridad
	res = Services.swap(run, "boost", 0, rng)
	check(res.ok and run.boosts.size() == 1 and run.boosts[0] != "aire_extra" and run.claridad == bal - Services.swap_price(run), "cambiar reemplaza el boost y cobra")
	run.claridad = 0
	check(not Services.swap(run, "boost", 0, rng).ok, "sin claridad no se puede cambiar")
	# no se puede vender el boost que agranda las barras si los demás ya no entrarían
	var full := make_run(5, 0)
	full.boosts.assign(["mente_abierta"])
	for k in 6:
		full.boosts.append("aire_extra_%d" % k)   # (ids inventados: sólo cuentan lugares)
	check(full.boosts.size() == 7 and full.boost_capacity() == 7, "(preparación: 7 boosts con Mente abierta)")
	check(not Services.sell(full, "boost", 0).ok and full.boosts.size() == 7, "no se vende Mente abierta si los demás dejarían de entrar")


func test_vault() -> void:
	var run := make_run(5, 200)
	check(not Services.deposit(run, 0).ok and not Services.deposit(run, 999).ok, "no se guarda cero ni más de lo que hay")
	check(Services.deposit(run, 100).ok and run.claridad == 100 and run.vault == 100 and run.vault_stage == 5, "se guarda claridad")
	check(Services.vault_payout(run) == 115, "con 15 % de interés")
	check(Services.enter(run) == 0 and run.vault == 100, "en el mismo casino no se cobra")
	run.stage = 6
	var paid := Services.enter(run)
	check(paid == 115 and run.claridad == 215 and run.vault == 0, "en el casino siguiente se cobra con interés")
	check(Services.enter(run) == 0, "y no se cobra dos veces")
	Services.deposit(run, 50)
	check(Services.withdraw(run) == 50 and run.vault == 0 and run.claridad == 215, "retirar devuelve lo guardado sin interés")
	# la claridad guardada no sirve para reintentar
	var poor := make_run(5, 30)
	Services.deposit(poor, 30)
	check(not poor.can_afford_restart(), "mientras está guardada no alcanza para reintentar")


func test_insurance() -> void:
	var run := make_run(5, 500)
	var first := Services.first_retry_cost(run)
	check(first == RunState.RESTART_BASE + 10 and Services.insurance_price(run) == int(round(first * 0.6)), "el seguro cuesta 60 % del primer reintento")
	var bal := run.claridad
	check(Services.buy_insurance(run).ok and run.insurance and run.claridad == bal - Services.insurance_price(run), "se contrata")
	check(not Services.buy_insurance(run).ok, "no se contrata dos veces")
	check(run.restart_cost() == 0 and run.can_afford_restart(), "con seguro el reintento es gratis")
	run.note_retry()
	check(not run.insurance and run.retries == 1 and run.tower_retries == 1 and run.restart_cost() > 0, "el primer reintento gasta el seguro")
	var poor := make_run(5, 1)
	check(not Services.buy_insurance(poor).ok, "sin claridad no se contrata")
	# expira si no se usa
	var run2 := make_run(5, 500)
	Services.buy_insurance(run2)
	run2.stage = 6
	Services.enter(run2)
	check(not run2.insurance, "el seguro expira al llegar al casino siguiente")


func test_run_state() -> void:
	var run := make_run(7, 100)
	run.vault = 40
	run.vault_stage = 7
	run.insurance = true
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	check(back.vault == 40 and back.vault_stage == 7 and back.insurance, "la caja y el seguro se guardan con el run")
	check(RunState.from_dict({}).vault == 0 and not RunState.from_dict({}).insurance, "un guardado viejo no los trae")


func test_screens() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var run: RunState
	# Taller
	run = make_run(5, 100)
	run.boosts.assign(["aire_extra"])
	run.consumables.assign(["freno"])
	var t = ServiceScreens.make("taller")
	root.add_child(t)
	t.setup(run, rng, true)
	await process_frame
	var saved := [0]
	t.resolved.connect(func(): saved[0] += 1)
	check(t.find_child("vender", true, false).disabled, "sin elegir nada no se puede vender")
	t.select("boost", 0)
	check(not t.find_child("vender", true, false).disabled and t.find_child("vender", true, false).text.contains("+"), "al elegir un ítem se puede vender y dice cuánto paga")
	t.find_child("vender", true, false).pressed.emit()
	check(run.boosts.is_empty() and saved[0] == 1, "vender por la pantalla")
	t.select("consumable", 0)
	t.find_child("cambiar", true, false).pressed.emit()
	check(run.consumables.size() == 1 and saved[0] == 2, "cambiar por la pantalla")
	t.queue_free()
	# Caja
	run = make_run(5, 200)
	var c = ServiceScreens.make("caja")
	root.add_child(c)
	c.setup(run, rng, true)
	await process_frame
	check(c.find_child("retirar", true, false).disabled, "sin nada guardado no se puede retirar")
	c.find_child("guardar_mitad", true, false).pressed.emit()
	check(run.vault == 100 and run.claridad == 100 and not c.find_child("retirar", true, false).disabled, "Guardar ½")
	c.find_child("guardar_todo", true, false).pressed.emit()
	check(run.vault == 200 and run.claridad == 0 and c.find_child("guardar_todo", true, false).disabled, "Guardar todo")
	c.find_child("retirar", true, false).pressed.emit()
	check(run.vault == 0 and run.claridad == 200, "Retirar")
	c.queue_free()
	# Seguro
	run = make_run(5, 500)
	var s = ServiceScreens.make("seguro")
	root.add_child(s)
	s.setup(run, rng, true)
	await process_frame
	check(not s.find_child("contratar", true, false).disabled, "se puede contratar")
	s.find_child("contratar", true, false).pressed.emit()
	check(run.insurance and s.find_child("contratar", true, false).disabled, "contratar el seguro")
	s.queue_free()


func test_scene() -> void:
	var run := make_run(14, 500)
	run.vault = 100
	run.vault_stage = 13
	run.insurance = true
	var c := CasinoScene.new()
	root.add_child(c)
	c.quick = true
	c.setup(run, RandomNumberGenerator.new())
	await process_frame
	check(run.vault == 0 and run.claridad == 615 and not run.insurance, "al entrar al casino se cobra la caja fuerte y expira el seguro")
	var st: Vector2i = c.lay.station.cell
	check(c._bump(st) == "service" and c.screen != null, "chocar con la estación abre su pantalla")
	c.close_roulette()
	check(c.screen == null, "y se cierra")
	c.cell = st + Vector2i(0, 1)
	c.facing = Vector2i(0, -1)
	check(c.interact() == "service" and c.screen != null, "también con Espacio mirándola")
	c.queue_free()
	# en el tutorial las estaciones están cerradas
	var story_c := CasinoScene.new()
	story_c.story = true
	root.add_child(story_c)
	story_c.quick = true
	story_c.setup(make_run(8, 0), RandomNumberGenerator.new())
	await process_frame
	check(story_c._bump(story_c.lay.station.cell) == "blocked" and story_c.screen == null, "en el tutorial la estación está cerrada")
	story_c.queue_free()
