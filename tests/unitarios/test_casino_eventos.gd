extends SceneTree
## Los eventos aleatorios del casino (casino_eventos.gd): el casino torcido (sólo una mesa abierta) y el peaje por adelantado (Farolín cobra antes y devuelve una parte al salir).
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/unitarios/test_casino_eventos.gd
const Demo := preload("res://scripts/datos/demo.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const CasinoScene := preload("res://scripts/casino/casino_scene.gd")
const Eventos := preload("res://scripts/casino/casino_eventos.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	Demo.forced = 0   # (el juego completo: estas pruebas no valen para la demo, aunque se corran con GAME_DEMO=1)
	test_sorteo()
	test_guardado()
	await test_torcido()
	await test_adelanto()
	print("tests de los eventos del casino terminados, fallos: %d" % fails)
	quit(1 if fails > 0 else 0)


func test_sorteo() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var torcidos := 0
	var adelantos := 0
	var ninguno := 0
	var juegos := {}
	for stage in range(1, 400):
		var run := RunState.new()
		run.stage = stage
		run.claridad = 500
		var ev := Eventos.al_entrar(run, rng, 3, 60)
		if ev.is_empty():
			ninguno += 1
		elif ev.id == Eventos.TORCIDO:
			torcidos += 1
			juegos[ev.solo] = true
		else:
			adelantos += 1
	check(torcidos > 20 and adelantos > 20 and ninguno > 150 and ninguno < 330, "el sorteo da casinos torcidos (%d), peajes por adelantado (%d) y visitas sin evento (%d)" % [torcidos, adelantos, ninguno])
	check(juegos.size() == 3, "el casino torcido deja abierta cada una de las tres mesas, según el sorteo")
	for nivel in [0, 1]:
		var run := RunState.new()
		var hay := false
		for k in 200:
			run.stage = k + 1
			hay = hay or not Eventos.al_entrar(run, rng, nivel, 60).is_empty()
		check(not hay, "la taberna y el salón no tienen eventos (nivel %d)" % nivel)
	var sin_plata := RunState.new()
	sin_plata.claridad = 5
	var adelanto_sin_plata := false
	for k in 300:
		sin_plata.stage = k + 1
		var ev := Eventos.al_entrar(sin_plata, rng, 3, 60)
		adelanto_sin_plata = adelanto_sin_plata or (not ev.is_empty() and ev.id == Eventos.ADELANTO)
	check(not adelanto_sin_plata, "el peaje por adelantado sólo sale si la claridad alcanza")
	var sin_peaje := RunState.new()
	sin_peaje.claridad = 500
	var adelanto_sin_peaje := false
	for k in 300:
		sin_peaje.stage = k + 1
		var ev2 := Eventos.al_entrar(sin_peaje, rng, 3, 0)
		adelanto_sin_peaje = adelanto_sin_peaje or (not ev2.is_empty() and ev2.id == Eventos.ADELANTO)
	check(not adelanto_sin_peaje, "si el casino no cobra peaje no hay adelanto")
	# el evento de una etapa se sortea una sola vez
	var run2 := RunState.new()
	run2.stage = 4
	run2.claridad = 500
	var primero := {}
	var intento := 0
	while primero.is_empty() and intento < 100:
		run2.casino_evento = {}
		primero = Eventos.al_entrar(run2, rng, 3, 60)
		intento += 1
	check(not primero.is_empty() and bool(primero.nuevo), "el primer sorteo de la etapa trae el evento como nuevo")
	var segundo := Eventos.al_entrar(run2, rng, 3, 60)
	check(segundo.id == primero.id and not bool(segundo.nuevo), "al volver a entrar al mismo casino el evento es el mismo y ya no es nuevo")
	run2.stage = 5
	Eventos.al_entrar(run2, rng, 3, 60)
	check(int(run2.casino_evento.stage) == 5, "en otra etapa se sortea de nuevo (queda anotada la etapa 5)")


func test_guardado() -> void:
	var run := RunState.new()
	run.stage = 7
	run.toll_adelanto = 42
	run.casino_evento = {"stage": 7, "id": Eventos.TORCIDO, "solo": "blackjack"}
	var otra := RunState.from_dict(run.to_dict())
	check(otra.toll_adelanto == 42 and otra.casino_evento.id == Eventos.TORCIDO and otra.casino_evento.solo == "blackjack" and int(otra.casino_evento.stage) == 7, "el adelanto y el evento sorteado se guardan con la partida")
	check(Eventos.cerrada(otra, "ruleta") and Eventos.cerrada(otra, "tragamonedas") and not Eventos.cerrada(otra, "blackjack"), "con un casino torcido sólo queda abierta la mesa elegida")
	otra.stage = 8
	check(not Eventos.cerrada(otra, "ruleta"), "en otra etapa las mesas no están cerradas")
	check(Eventos.devolucion(100, 100) == 10 and Eventos.devolucion(100, 70) == 40, "Farolín devuelve lo que sobró y el 10 % por la confianza")


func _casino(run, toll: int):
	var c = CasinoScene.new()
	c.quick = true
	c.toll_base = toll
	root.add_child(c)
	c.setup(run, RandomNumberGenerator.new())
	return c


func test_torcido() -> void:
	var run := RunState.new()
	run.stage = 13
	run.claridad = 500
	run.casino_evento = {"stage": 13, "id": Eventos.TORCIDO, "solo": "ruleta"}
	var c = _casino(run, 0)
	c.poner_evento({"stage": 13, "id": Eventos.TORCIDO, "solo": "ruleta"})
	check(c._carteles_cerrado.size() >= 3, "casino torcido: hay carteles de CERRADO sobre las mesas cerradas (%d)" % c._carteles_cerrado.size())
	var m: Vector2i = c.lay.machines[0]
	check(c._bump(m) == "blocked" and c.screen == null, "casino torcido: las tragamonedas están cerradas")
	check(c._bump(c.lay.card_tables[0].position) == "blocked" and c.screen == null, "casino torcido: el blackjack está cerrado")
	check(c._bump(c.lay.table.position) == "roulette" and c.screen != null, "casino torcido: la ruleta, la mesa elegida, abre")
	c.close_roulette()
	var lineas: Array = c.talk_to_keeper()
	check(lineas.size() >= 2 and str(lineas[lineas.size() - 1]).contains("ruleta"), "casino torcido: el tabernero recuerda qué mesa se puede usar")
	var a := Eventos.anuncio({"id": Eventos.TORCIDO, "solo": "blackjack"}, 0, "Tabernero", "Farolín")
	check(a.speaker == "Tabernero" and a.lines.size() == 2 and str(a.lines[1]).contains("blackjack"), "casino torcido: lo anuncia el tabernero")
	c.queue_free()
	await process_frame
	# sin evento todo abre
	var run_normal := RunState.new()
	run_normal.stage = 13
	var c2 = _casino(run_normal, 0)
	check(c2._bump(c2.lay.machines[0]) == "slots", "sin evento las tragamonedas abren")
	c2.queue_free()
	await process_frame


func test_adelanto() -> void:
	var run := RunState.new()
	run.stage = 13
	run.claridad = 500
	var peaje := 60
	var c = _casino(run, peaje)
	var ev := {"stage": 13, "id": Eventos.ADELANTO, "solo": "", "nuevo": true}
	var cobrado := Eventos.aplicar_entrada(run, ev, run.toll_after_discounts(peaje))
	run.casino_evento = {"stage": 13, "id": Eventos.ADELANTO, "solo": ""}
	check(cobrado > 0 and run.claridad == 500 - cobrado and run.toll_adelanto == cobrado, "peaje por adelantado: Farolín cobra el peaje en el acto (%d)" % cobrado)
	check(Eventos.aplicar_entrada(run, ev, run.toll_after_discounts(peaje)) == 0 and run.toll_adelanto == cobrado, "peaje por adelantado: no se cobra dos veces")
	check(c.toll_now() == 0, "peaje por adelantado: al salir ya no queda nada por pagar")
	var a := Eventos.anuncio(ev, cobrado, "Tabernero", "Farolín")
	check(a.speaker == "Farolín" and str(a.lines[1]).contains(str(cobrado)), "peaje por adelantado: lo anuncia Farolín con lo que cobró")
	var hablo := [0]
	var salio := [0]
	c.toll_talk.connect(func(): hablo[0] += 1)
	c.left.connect(func(): salio[0] += 1)
	c.cell = c.lay.exit
	check(c.step(Vector2i(0, -1)) == "blocked" and hablo[0] == 1 and salio[0] == 0, "peaje por adelantado: en la puerta Farolín habla y salda la cuenta")
	var d: Dictionary = c.toll_dialog()
	check(d.options.size() == 1 and d.options[0].id == "pagar" and d.options[0].enabled and str(d.text).contains(str(Eventos.devolucion(cobrado, cobrado))), "peaje por adelantado: el diálogo dice cuánto devuelve y deja salir")
	var antes := run.claridad
	check(c.pay_toll() and salio[0] == 1, "peaje por adelantado: se sale")
	check(run.claridad == antes + Eventos.devolucion(cobrado, cobrado) and run.toll_adelanto == 0, "peaje por adelantado: Farolín devuelve una parte (+%d) y la cuenta queda saldada" % (run.claridad - antes))
	c.queue_free()
	await process_frame
	# si el peaje bajó (Soborno), también devuelve la diferencia
	var run3 := RunState.new()
	run3.stage = 13
	run3.claridad = 500
	var c3 = _casino(run3, peaje)
	var cobrado3 := Eventos.aplicar_entrada(run3, {"id": Eventos.ADELANTO}, run3.toll_after_discounts(peaje))
	run3.toll_bribe = true
	var precio_ahora := run3.toll_after_discounts(peaje)
	check(precio_ahora <= cobrado3 and c3.toll_now() == 0, "peaje por adelantado con soborno: no se debe nada")
	var antes3 := run3.claridad
	c3.cell = c3.lay.exit
	c3.step(Vector2i(0, -1))
	c3.pay_toll()
	check(run3.claridad == antes3 + Eventos.devolucion(cobrado3, precio_ahora), "peaje por adelantado con soborno: devuelve lo que sobró más el 10 %")
	c3.queue_free()
	await process_frame
