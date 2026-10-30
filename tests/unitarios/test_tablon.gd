extends SceneTree
## El tablón de contratos dentro del juego: la escena del casino (los papeles cuelgan, chocar con el tablón abre su pantalla, aceptar y descolgar cambian lo que cuelga) y la torre (los contratos activos
## se cumplen mientras se juega, se cobran y vuelven a empezar con la torre siguiente).
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_tablon.gd
const CasinoScene := preload("res://scripts/casino/casino_scene.gd")
const Room := preload("res://scripts/casino/casino_room.gd")
const Contratos := preload("res://scripts/datos/contratos.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Profile := preload("res://scripts/datos/profile.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	await test_escena()
	await test_torre()
	print("tests del tablón de contratos terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func make_run(stage: int, claridad := 1000) -> RunState:
	var run := RunState.new()
	run.stage = stage
	run.claridad = claridad
	return run


func test_escena() -> void:
	for stage in [1, 5, 9, 13]:
		var run := make_run(stage)
		var sc := CasinoScene.new()
		root.add_child(sc)
		sc.quick = true
		sc.setup(run, RandomNumberGenerator.new())
		await process_frame
		var tier: int = sc.lay.tier
		check(Contratos.cartelera(run).size() == Contratos.capacidad(tier) and Contratos.cartelera(run).count(null) == 0, "etapa %d: al entrar cuelgan los %d papeles" % [stage, Contratos.capacidad(tier)])
		check(sc._tablon_nodos.size() == 3 and sc._papeles_del_tablon().size() == Contratos.capacidad(tier), "etapa %d: el tablón se dibuja con sus papeles" % stage)
		var fino_antes: int = (sc._tablon_nodos[2].mesh as ArrayMesh).surface_get_array_len(0)
		check(fino_antes > 0, "etapa %d: los papeles tienen minibloques" % stage)
		sc.cell = sc.lay.tablon + Vector2i(1, 0)   # (parado al lado del tablón y mirándolo, Espacio lo abre)
		sc.facing = Vector2i(-1, 0)
		check(sc.interact() == "service" and sc.screen != null and sc.screen.find_child("tienda", true, false) == null and sc.screen.find_child("pestana_contratos", true, false) == null, "etapa %d: Espacio frente al tablón lo abre, sin rastro de la tienda" % stage)
		sc.close_roulette()
		check(sc._bump(sc.lay.tablon) == "service" and sc.screen != null and sc.screen.get("service_id") == "tablon", "etapa %d: chocar con el tablón abre su pantalla" % stage)
		var s = sc.screen
		check(s.find_child("aceptar", true, false) != null and s.find_child("rotar", true, false) != null and s.find_child("descolgar", true, false) != null, "etapa %d: tiene aceptar, descolgar y rotar" % stage)
		check((s.find_child("fianza", true, false) != null) == (tier >= 2), "etapa %d: la fianza sólo está en el casino y el gran casino" % stage)
		s.find_child("aceptar", true, false).pressed.emit()
		check(Contratos.activos(run).size() == 1 and Contratos.cartelera(run)[0] == null, "etapa %d: aceptar pasa el papel a activos" % stage)
		var fino_despues: int = (sc._tablon_nodos[2].mesh as ArrayMesh).surface_get_array_len(0)
		check(fino_despues < fino_antes, "etapa %d: el papel aceptado ya no cuelga del tablón (se rehízo la malla)" % stage)
		s.select(1)
		s.find_child("descolgar", true, false).pressed.emit()
		check(Contratos.cartelera(run)[1] == null, "etapa %d: descolgar deja el hueco" % stage)
		var antes := run.claridad
		s.find_child("rotar", true, false).pressed.emit()
		check(run.claridad < antes and Contratos.cartelera(run)[0] == null and Contratos.cartelera(run)[1] == null, "etapa %d: rotar cuesta claridad y respeta los huecos de lo aceptado" % stage)
		sc.close_roulette()
		sc.queue_free()
		await process_frame
	# la próxima visita: los papeles que quedaron siguen y entran como mucho 2 nuevos
	var run2 := make_run(5)
	var sc2 := CasinoScene.new()
	root.add_child(sc2)
	sc2.quick = true
	sc2.setup(run2, RandomNumberGenerator.new())
	await process_frame
	Contratos.rechazar(run2, 0)
	Contratos.rechazar(run2, 1)
	Contratos.rechazar(run2, 2)
	var colgados: Array = Contratos.cartelera(run2).filter(func(p): return p != null).map(func(p): return p.id)
	sc2.queue_free()
	await process_frame
	var sc3 := CasinoScene.new()
	root.add_child(sc3)
	sc3.quick = true
	run2.stage = 6
	sc3.setup(run2, RandomNumberGenerator.new())
	await process_frame
	var ahora: Array = Contratos.cartelera(run2).filter(func(p): return p != null).map(func(p): return p.id)
	check(ahora.size() == colgados.size() + 2 and colgados.all(func(id): return ahora.has(id)), "al volver al casino siguen los papeles de antes y llegan 2 nuevos")
	sc3.queue_free()
	# el tutorial no tiene tablón ni papeles
	var story_c := CasinoScene.new()
	story_c.story = true
	root.add_child(story_c)
	story_c.quick = true
	var run3 := make_run(1, 0)
	story_c.setup(run3, RandomNumberGenerator.new())
	await process_frame
	check(Contratos.cartelera(run3).is_empty() and story_c._tablon_nodos.is_empty(), "en el tutorial no hay contratos")
	check(story_c._bump(story_c.lay.tablon) == "blocked" and story_c.screen == null, "y el tablón está cerrado")
	story_c.queue_free()


func test_torre() -> void:
	Profile.path = "user://test_profile_tablon.json"
	Profile.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	for i in 4:
		await process_frame
	main.start_game()
	for i in 4:
		await process_frame
	var run: RunState = main.run
	run.contratos = {"cartelera": [], "activos": [], "iniciada": true, "rotaciones": 0, "torre": {}, "siguiente_id": 10}
	for p in [{"id": 1, "obj": "racha", "r": 0, "n": 2, "pct": 0.1, "monto": 120, "fianza": 0}, {"id": 2, "obj": "sin_deshacer", "r": 0, "n": 0, "pct": 0.1, "monto": 80, "fianza": 40},
			{"id": 3, "obj": "sin_vidas", "r": 1, "n": 0, "pct": 0.2, "monto": 50, "fianza": 0}, {"id": 4, "obj": "claridad", "r": 3, "n": 99999, "pct": 1.0, "monto": 500, "fianza": 0}]:
		run.contratos.activos.append(p)
	run.claridad = 0
	main._contratos_registrar("deshacer", {})   # (el de "sin deshacer" ya está perdido)
	check(Contratos.activos(run).size() == 3 and main._contratos_cola.size() == 1 and not main._contratos_cola[0].cumplido and main._contratos_cola[0].monto == -40, "deshacer pierde el contrato y muestra la fianza (-40)")
	main._contratos_mostrar()
	check(main._contratos_cola.is_empty(), "en las pruebas la cola se vacía sin pantalla")
	var tj = main.torre
	check(tj.contrato_evento.get_connections().size() >= 1, "la torre le avisa al juego lo que pasa")
	check(main._panel_datos().get("contratos", []).size() == 3, "el panel de información lista los 3 contratos activos")
	# se juega la torre por su camino mínimo: la racha se cumple en el camino y los demás al terminar
	var cobrados: Array = []
	var n_acciones := 0
	while not tj.t.terminada and n_acciones < 400:
		var cam: Array = tj.t.sala_actual().d.camino
		var i := 0
		var sala: int = tj.t.indice
		while i < cam.size() and tj.t.indice == sala and not tj.t.terminada:
			var a: Array = cam[i]
			tj.accion(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
			n_acciones += 1
			i += 1
	check(tj.t.terminada, "la torre se completó por su camino mínimo")
	var ids_activos: Array = Contratos.activos(run).map(func(p): return p.id)
	check(not ids_activos.has(1), "la racha se cumplió en el camino y se cobró (%s)" % str(ids_activos))
	check(run.claridad >= 120, "se cobró lo del contrato de la racha (claridad %d)" % run.claridad)
	for i in 6:   # (el juego ya llamó a _torre_ganada al llegar al portal)
		await process_frame
	check(Contratos.activos(run).size() == 0, "al terminar la torre se resolvieron todos los contratos")
	check(run.claridad >= 120 + 50, "Intocable (sin perder vidas) se cumplió y se cobró")
	main.queue_free()
