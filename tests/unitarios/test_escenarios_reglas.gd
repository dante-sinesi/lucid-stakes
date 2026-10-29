extends SceneTree
## Pruebas de las reglas de los escenarios (docs/escenarios_propuestas.md): las dificultades de cada uno, Gran Casino (un escalón más difícil), Relojería (menos movimientos), Contratista (cuatro
## contratos, recompensas mayores, Buena letra), Mundo abierto (todos los especiales desde la etapa 1 y más salas con especiales) y Usurero (peaje y premios, Buen regateo) (headless).
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_escenarios_reglas.gd

const RunState := preload("res://scripts/datos/run_state.gd")
const Scenarios := preload("res://scripts/datos/scenarios.gd")
const Abilities := preload("res://scripts/datos/abilities.gd")
const Contratos := preload("res://scripts/datos/contratos.gd")
const CasinoVisit := preload("res://scripts/casino/casino_visit.gd")
const Profile := preload("res://scripts/datos/profile.gd")
const Torre := preload("res://torre/torre.gd")
const DifficultyScreen := preload("res://scripts/ui/difficulty_screen.gd")
const ScenarioScreen := preload("res://scripts/ui/scenario_screen.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _run(scenario: String, dificultad := "media"):
	var r := RunState.new()
	r.scenario_id = scenario
	r.dificultad = dificultad
	return r


func _init() -> void:
	Profile.path = "user://test_profile.json"
	Profile.reset()
	test_catalogo()
	test_dificultades()
	test_reglas_en_pantalla()
	test_gran_casino()
	test_relojeria()
	test_contratista()
	test_mundo_abierto()
	test_usurero()
	await test_selector()
	await test_arranque()
	print("fallos: %d" % fails)
	quit(fails)


func test_catalogo() -> void:
	var ids: Array = Scenarios.ALL.map(func(s): return str(s.id))
	check(ids == ["pesadilla", "sin_piedad", "compromiso", "gran_casino", "relojeria", "contratista", "mundo_abierto", "usurero"], "los ocho escenarios (con La Pesadilla): %s" % str(ids))
	for id in ids:
		check(Scenarios.playable(id), id + ": se puede jugar")
		for a in Scenarios.ability_ids(Scenarios.get_scenario(id)):
			check(not Abilities.get_ability(a).is_empty(), "%s: la habilidad %s existe" % [id, a])
	check(str(Scenarios.get_scenario("sin_piedad").name) == "El camino corto", "Sin piedad se llama El camino corto (el id queda)")
	var dueno := {}
	for s in Scenarios.ALL:
		for a in Scenarios.ability_ids(s):
			check(not dueno.has(a), "la habilidad %s es de un solo escenario" % a)
			dueno[a] = s.id
	for a in Abilities.ALL:
		check(dueno.has(a.id), "la habilidad %s se puede ganar en algún escenario" % a.id)


func test_dificultades() -> void:
	check(Scenarios.difficulties("pesadilla") == ["facil", "media", "dificil", "pesadilla"], "La Pesadilla tiene las cuatro dificultades")
	for id in ["sin_piedad", "compromiso", "gran_casino", "relojeria", "contratista", "mundo_abierto", "usurero"]:
		check(Scenarios.difficulties(id) == ["media", "dificil", "pesadilla"], id + ": Medio, Difícil y Pesadilla (sin Fácil)")
	check(Scenarios.difficulties("tutorial").is_empty(), "el tutorial no tiene selector")


func test_gran_casino() -> void:
	check(_run("gran_casino", "media").dificultad_torre() == "dificil" and _run("gran_casino", "dificil").dificultad_torre() == "pesadilla", "Gran Casino: las torres, un escalón más difíciles")
	check(_run("gran_casino", "pesadilla").dificultad_torre() == "pesadilla", "...con tope en Pesadilla")
	check(_run("pesadilla", "media").dificultad_torre() == "media" and _run("relojeria", "dificil").dificultad_torre() == "dificil", "los demás escenarios no corren la dificultad")
	var sc := Scenarios.get_scenario("gran_casino")
	check(int(sc.casino_tier) == 3 and is_equal_approx(float(sc.price_mult), 0.8), "Gran Casino: casino de lujo y ficha a 0,8")


func test_relojeria() -> void:
	for etapa in [1, 4, 8, 15]:
		var normal := Torre.max_movimientos(40, "media", etapa, "media")
		var reloj := Torre.max_movimientos(40, "media", etapa, "media", float(Scenarios.get_scenario("relojeria").margen_mov))
		check(reloj <= normal and reloj >= 40, "Relojería: menos movimientos en la etapa %d (%d contra %d, mínimo 40)" % [etapa, reloj, normal])
	check(Torre.max_movimientos(40, "media", 8, "media", 0.5) < Torre.max_movimientos(40, "media", 8, "media"), "...y en la etapa 8 es estrictamente menos")
	check(is_equal_approx(float(Scenarios.get_scenario("relojeria").price_mult), 0.75), "Relojería: la ficha a 0,75")


func test_contratista() -> void:
	var r = _run("contratista")
	check(Contratos.limite(r) == 4 and Contratos.limite(_run("pesadilla")) == 2, "Contratista: cuatro contratos activos (los demás, dos)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var normal = _run("pesadilla")
	var p_c := Contratos.sortear(r, rng, 1)
	rng.seed = 7
	var p_n := Contratos.sortear(normal, rng, 1)
	check(p_c.obj == p_n.obj and p_c.r == p_n.r and is_equal_approx(float(p_c.pct), float(p_n.pct) * 1.5), "Contratista: la recompensa del mismo papel es un 50 %% mayor (%s contra %s)" % [str(p_c.pct), str(p_n.pct)])
	check(Contratos.fianza(p_c, 3) > Contratos.fianza(p_n, 3), "...y la fianza también")
	rng.seed = 3
	var nuevos_c := Contratos.entrar(r, rng, 1)   # (la primera visita llena la cartelera entera)
	var nuevos_n := Contratos.entrar(normal, rng, 1)
	check(nuevos_c == nuevos_n, "la primera visita llena la cartelera igual")
	# Buena letra: la primera fianza que se pierde en la partida se devuelve
	r.buena_letra = true
	r.claridad = 0
	var papel := {"id": 1, "obj": "ahorrar", "r": 0, "n": 1, "pct": 0.1, "monto": 50, "fianza": 25}
	var res := Contratos._resolver(r, papel, false)
	check(r.claridad == 25 and int(res.monto) == 0 and r.buena_letra_usada, "Buena letra: la primera fianza fallida se devuelve (claridad %d)" % r.claridad)
	var res2 := Contratos._resolver(r, papel, false)
	check(r.claridad == 25 and int(res2.monto) == -25, "...y la segunda se pierde")
	var sin = _run("contratista")
	var res3 := Contratos._resolver(sin, papel, false)
	check(int(res3.monto) == -25 and not sin.buena_letra_usada, "sin la habilidad la fianza se pierde")
	var libre := {"id": 2, "obj": "ahorrar", "r": 0, "n": 1, "pct": 0.1, "monto": 50, "fianza": 0}
	var r2 = _run("contratista")
	r2.buena_letra = true
	check(int(Contratos._resolver(r2, libre, false).monto) == 0 and not r2.buena_letra_usada, "un contrato sin fianza fallado no gasta Buena letra")
	# guardado
	var g := RunState.from_dict(r.to_dict())
	check(g.buena_letra and g.buena_letra_usada, "Buena letra se guarda y se carga")


func test_mundo_abierto() -> void:
	var paquete := Torre.cargar_paquete_del_juego()
	check(paquete.size() > 1000, "hay paquete de salas (%d)" % paquete.size())
	var reglas: Dictionary = Scenarios.get_scenario("mundo_abierto")
	# etapa 1: con la regla hay bastantes más salas con especiales que sin ella
	var sin_especiales := 0
	var con_regla := 0
	var total_sin := 0
	var total_con := 0
	for semilla in range(1, 7):
		var t_normal = Torre.armar(paquete, semilla, 14, true, 1, "media")
		var t_regla = Torre.armar(paquete, semilla, 14, true, 1, "media", reglas)
		for e in t_normal.salas:
			total_sin += 1
			if str(e.d.get("categoria", "base")) != "base":
				sin_especiales += 1
		for e in t_regla.salas:
			total_con += 1
			if str(e.d.get("categoria", "base")) != "base":
				con_regla += 1
	check(float(con_regla) / float(maxi(total_con, 1)) > 0.2, "etapa 1 con Mundo abierto: salas con especiales (%d de %d)" % [con_regla, total_con])
	check(con_regla > sin_especiales, "etapa 1: Mundo abierto trae más salas con especiales que La Pesadilla (%d contra %d de %d)" % [con_regla, sin_especiales, total_sin])
	# etapa 8 (con todo habilitado): la regla sube la fracción de salas con especiales
	var f_normal := 0
	var f_regla := 0
	var n_normal := 0
	var n_regla := 0
	for semilla in range(1, 7):
		for e in Torre.armar(paquete, semilla, 14, true, 8, "media").salas:
			n_normal += 1
			if str(e.d.get("categoria", "base")) != "base":
				f_normal += 1
		for e in Torre.armar(paquete, semilla, 14, true, 8, "media", reglas).salas:
			n_regla += 1
			if str(e.d.get("categoria", "base")) != "base":
				f_regla += 1
	var p_normal := float(f_normal) / float(maxi(n_normal, 1))
	var p_regla := float(f_regla) / float(maxi(n_regla, 1))
	check(p_regla > p_normal + 0.05, "etapa 8: la regla sube la fracción de salas con especiales (%.2f contra %.2f)" % [p_regla, p_normal])
	check(p_regla < 0.85, "...pero sin pasarse (%.2f)" % p_regla)
	# las dos primeras salas de cada torre siguen siendo comunes
	var t = Torre.armar(paquete, 3, 14, true, 8, "media", reglas)
	check(str(t.salas[0].d.get("categoria", "base")) == "base" and str(t.salas[1].d.get("categoria", "base")) == "base", "las dos primeras salas siguen siendo comunes")
	# sin reglas, la torre es la de siempre (misma semilla, mismas salas)
	var a = Torre.armar(paquete, 11, 10, true, 5, "media")
	var b = Torre.armar(paquete, 11, 10, true, 5, "media", {})
	var ids_a: Array = a.salas.map(func(e): return int(e.d.id))
	var ids_b: Array = b.salas.map(func(e): return int(e.d.id))
	check(ids_a == ids_b, "sin reglas, la torre es la de siempre")


func test_usurero() -> void:
	var u = _run("usurero")
	var n = _run("pesadilla")
	check(u.toll_after_discounts(100) == 140 and n.toll_after_discounts(100) == 100, "Usurero: el peaje cuesta un 40 %% más (%d contra %d)" % [u.toll_after_discounts(100), n.toll_after_discounts(100)])
	check(is_equal_approx(float(Scenarios.get_scenario("usurero").price_mult), 0.7), "Usurero: la ficha a 0,7")
	# Buen regateo: el peaje baja un 10 %
	Profile.grant_ability("buen_regateo")
	var u2 = _run("usurero")
	Profile.apply_to_run(u2)
	check(is_equal_approx(u2.toll_meta_discount, 0.1) and u2.toll_after_discounts(100) == 126, "Buen regateo: el peaje de Usurero baja un 10 %% (%d)" % u2.toll_after_discounts(100))
	var n2 = _run("pesadilla")
	Profile.apply_to_run(n2)
	check(n2.toll_after_discounts(100) == 90, "Buen regateo vale en todos los escenarios (%d)" % n2.toll_after_discounts(100))
	var g := RunState.from_dict(u2.to_dict())
	check(is_equal_approx(g.toll_meta_discount, 0.1), "Buen regateo se guarda y se carga")
	# los premios de las mesas valen un 25 % más
	var rv = _run("usurero")
	CasinoVisit.enter(rv, 1)
	var res := CasinoVisit.settle(rv, 100, 200, true, false, "ruleta")
	check(int(res.bonus) == 50 and rv.claridad == 50, "Usurero: los premios valen un 25 %% más (bono %d)" % int(res.bonus))
	var rn = _run("pesadilla")
	CasinoVisit.enter(rn, 1)
	var resn := CasinoVisit.settle(rn, 100, 200, true, false, "ruleta")
	check(int(resn.bonus) == 0, "sin Usurero no hay bono")
	var perd := CasinoVisit.settle(rv, 100, 0, false, false, "ruleta")
	check(int(perd.bonus) == 0, "lo que se pierde no tiene bono")


## El selector de dificultad: La Pesadilla ofrece las cuatro; los demás escenarios, sin Fácil.
func test_selector() -> void:
	await process_frame
	var d = DifficultyScreen.new()
	root.add_child(d)
	await process_frame
	d.ask(Scenarios.difficulties("pesadilla"))
	check(d.buttons["facil"].visible and d.buttons["media"].visible and d.buttons["dificil"].visible and d.buttons["pesadilla"].visible, "La Pesadilla ofrece las cuatro dificultades")
	d.visible = false
	d._open_t = -10.0
	d.ask(Scenarios.difficulties("compromiso"))
	check(not d.buttons["facil"].visible and d.buttons["media"].visible and d.buttons["dificil"].visible and d.buttons["pesadilla"].visible, "los demás escenarios no ofrecen Fácil")
	d.queue_free()


## Empezar una partida en cada escenario: la dificultad elegida, las reglas que arman la torre y las habilidades que se aplican.
func test_arranque() -> void:
	Profile.path = "user://test_profile_escenarios.json"
	Profile.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	for i in 4:
		await process_frame
	Profile.add_luz(500)   # (las entradas de los escenarios cuestan Luz)
	main.start_game("gran_casino", "media")
	for i in 4:
		await process_frame
	check(main.run.scenario_id == "gran_casino" and main.run.dificultad == "media" and main.torre.dificultad == "dificil", "Gran Casino en Medio arma la torre en Difícil (%s)" % main.torre.dificultad)
	main.start_game("relojeria", "pesadilla")
	for i in 4:
		await process_frame
	check(main.run.dificultad == "pesadilla" and is_equal_approx(float(main.torre.reglas.margen_mov), 0.5) and main.torre.t.max_mov() >= 1, "Relojería lleva su margen a la torre")
	var max_normal := Torre.max_movimientos(int(main.torre.t.salas[0].d.pasos), str(main.torre.t.salas[0].d.nivel), 1, "pesadilla")
	check(main.torre.t.salas[0].max_mov <= max_normal, "...y la primera sala da %d movimientos (con el margen normal, %d)" % [main.torre.t.salas[0].max_mov, max_normal])
	main.start_game("mundo_abierto", "media")
	for i in 4:
		await process_frame
	var especiales := 0
	for e in main.torre.t.salas:
		if str(e.d.get("categoria", "base")) != "base":
			especiales += 1
	check(float(main.torre.reglas.peso_especiales) == 0.6 and especiales > 0, "Mundo abierto: la etapa 1 trae salas con especiales (%d de %d)" % [especiales, main.torre.t.salas.size()])
	main.start_game("compromiso", "dificil")
	for i in 4:
		await process_frame
	check(main.run.lives == 1 and main.run.dificultad == "dificil", "Compromiso: una sola vida en Difícil")
	main.start_game("pesadilla", "facil")
	for i in 4:
		await process_frame
	check(main.torre.t.max_mov() == Torre.SIN_LIMITE and main.torre.dificultad == "facil", "La Pesadilla en Fácil sigue con movimientos ilimitados")
	main.queue_free()


## La información de cada escenario lista sus reglas en frases cortas (y el camino corto, con su aclaración del movimiento en falso).
func test_reglas_en_pantalla() -> void:
	var camino := Scenarios.get_scenario("sin_piedad")
	check(ScenarioScreen.rule_lines(camino) == ["Cada sala permite solo 2 movimientos en falso*; al siguiente se pierde una vida.", "No se puede deshacer."], "El camino corto: sus dos reglas (%s)" % str(ScenarioScreen.rule_lines(camino)))
	check(ScenarioScreen.rule_notes(camino) == ["* Movimiento en falso: movimiento que te deja a más pasos del final que antes."], "...y la aclaración del movimiento en falso")
	check(ScenarioScreen.rule_notes(Scenarios.get_scenario("usurero")).is_empty(), "los que no usan asterisco no llevan aclaración")
	for s in Scenarios.ALL:
		var lineas := ScenarioScreen.rule_lines(s)
		if s.id == "pesadilla":
			check(lineas == ["Las reglas de siempre."], "La Pesadilla: las reglas de siempre")
		else:
			check(not lineas.has("Las reglas de siempre.") and lineas.size() >= 1, "%s: lista sus reglas propias (%d)" % [s.id, lineas.size()])
