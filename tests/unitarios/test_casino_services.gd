extends SceneTree
## Pruebas de los servicios del casino (Taller y ahorros), sus pantallas y cómo se enganchan a la sala y al run (headless).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_casino_services.gd

const Services := preload("res://scripts/casino/casino_services.gd")
const ServiceScreens := preload("res://scripts/casino/casino_service_screens.gd")
const Room := preload("res://scripts/casino/casino_room.gd")
const Roulette := preload("res://scripts/casino/roulette.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Items := preload("res://scripts/datos/items.gd")
const CasinoScene := preload("res://scripts/casino/casino_scene.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_layout()
	test_taller()
	test_ahorros()
	test_run_state()
	await test_screens()
	await test_pad_screens()
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
	check(not Room.layout(13).has("station") and Services.service_for_tier(3) == "", "el gran casino no tiene estación de servicio (ya no hay seguro)")
	check(not Room.layout(9).has("station"), "el casino ya no tiene la Caja fuerte en su sala")
	for st in [5]:
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
	check(ids == ["taller"], "la única estación de las salas es el Taller del salón: %s" % str(ids))


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
	# dentro de una visita, cada cambio cuesta más que el anterior
	run.claridad = 100000
	run.casino_visit = {"tier": 1, "cambios": 0}
	var p0 := Services.swap_price(run)
	var s1 := Services.swap(run, "boost", 0, rng)
	var p1 := Services.swap_price(run)
	var s2 := Services.swap(run, "boost", 0, rng)
	check(s1.ok and s2.ok and absi(p1 - p0 * 2) <= 1 and absi(Services.swap_price(run) - p0 * 3) <= 2, "cada cambio de la visita cuesta más que el anterior (%d, %d, %d)" % [p0, p1, Services.swap_price(run)])
	run.casino_visit = {}
	run.claridad = 0
	check(not Services.swap(run, "boost", 0, rng).ok, "sin claridad no se puede cambiar")
	# no se puede vender el boost que agranda las barras si los demás ya no entrarían
	var full := make_run(5, 0)
	full.boosts.assign(["mente_abierta"])
	for k in 6:
		full.boosts.append("aire_extra_%d" % k)   # (ids inventados: sólo cuentan lugares)
	check(full.boosts.size() == 7 and full.boost_capacity() == 7, "(preparación: 7 boosts con Mente abierta)")
	check(not Services.sell(full, "boost", 0).ok and full.boosts.size() == 7, "no se vende Mente abierta si los demás dejarían de entrar")


func test_ahorros() -> void:
	var run := make_run(5, 200)
	run.claridad_inicio_torre = 200
	check(Services.enter(run) == 0 and run.claridad == 200, "sin Caja fuerte ni Alcancía no se cobra nada")
	run.boosts.append("caja_fuerte")
	check(Services.enter(run) == 30 and run.claridad == 230, "la Caja fuerte cobra un 15 % de la claridad con la que empezaste la torre")
	run.alcancia = true
	check(Services.enter(run) == 90 and run.claridad == 320 and not run.alcancia, "con la Alcancía suma un 30 % y se gasta (los dos: 45 %)")
	check(Services.enter(run) == 30, "la Alcancía se cobra una sola vez")
	var otra := make_run(5, 200)
	otra.claridad_inicio_torre = 0
	otra.alcancia = true
	check(Services.enter(otra) == 0 and not otra.alcancia, "si se empezó la torre sin claridad no cobra nada (y se gasta igual)")
	check(Items.get_item("caja_fuerte").type == Items.Type.BOOST and Items.get_item("alcancia").type == Items.Type.CONSUMABLE and Items.CASINO_USABLE.has("alcancia"), "la Caja fuerte es un boost y la Alcancía un consumible del casino")


func test_run_state() -> void:
	var run := make_run(7, 100)
	run.claridad_inicio_torre = 40
	run.alcancia = true
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	check(back.claridad_inicio_torre == 40 and back.alcancia, "los ahorros se guardan con el run")
	check(RunState.from_dict({}).claridad_inicio_torre == 0 and not RunState.from_dict({}).alcancia, "un guardado viejo no los trae")


## Con el mando (o el teclado) los servicios se manejan con la botonera: flechas para elegir el casillero, Enter, Espacio o C para lo que dice cada ítem.
func test_pad_screens() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var run := make_run(5, 500)
	run.boosts.assign(["aire_extra", "cosecha"])
	run.consumables.assign(["freno"])
	var t = ServiceScreens.make("taller")
	root.add_child(t)
	t.setup(run, rng, true)
	await process_frame
	check(t.hints != null and t.hints.items.size() >= 3, "el taller tiene su botonera (elegir, vender, cambiar, tienda, salir)")
	check(not t.find_child("vender", true, false).visible and not t.find_child("salir", true, false).visible, "los botones que repite la botonera no se ven")
	t.step_selection(1)
	check(t.sel_kind == "boost" and t.sel_index == 0, "la flecha derecha elige el primer casillero")
	t.step_selection(1)
	check(t.sel_kind == "boost" and t.sel_index == 1, "y la siguiente el que sigue")
	t.step_selection(1)
	check(t.sel_kind == "consumable" and t.sel_index == 0, "pasa de los boosts a los consumibles")
	t.step_selection(-1)
	t.step_selection(-1)
	check(t.sel_kind == "boost" and t.sel_index == 0, "y vuelve")
	var before := run.boosts.size()
	for it in t.hints.items:
		if it.get("keycode") != null and (it.keycode is Array) and it.keycode.has(KEY_ENTER):
			it.call.call()   # A (Enter): vender
	check(run.boosts.size() == before - 1, "Enter vende el casillero elegido")
	t.queue_free()
	var shop = ServiceScreens.make("tienda")
	root.add_child(shop)
	var shop_run := make_run(5, 5000)
	shop_run.showcase = {"shop": ["aire_extra", "freno"], "sold": []}
	shop.setup(shop_run, rng, true)
	await process_frame
	shop.step_selection(1)
	check(shop.sel != "", "en la tienda las flechas también eligen")
	check(shop.hints.items.size() >= 2, "la tienda tiene su botonera")
	shop.queue_free()
	await process_frame


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


func test_scene() -> void:
	var run := make_run(5, 500)
	run.boosts.append("caja_fuerte")
	run.claridad_inicio_torre = 500
	var c := CasinoScene.new()
	root.add_child(c)
	c.quick = true
	c.setup(run, RandomNumberGenerator.new())
	await process_frame
	check(run.claridad == 575, "al entrar al casino se cobra la Caja fuerte (15 % de 500)")
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
	story_c.setup(make_run(5, 0), RandomNumberGenerator.new())
	await process_frame
	check(story_c._bump(story_c.lay.station.cell) == "blocked" and story_c.screen == null, "en el tutorial la estación está cerrada")
	story_c.queue_free()
