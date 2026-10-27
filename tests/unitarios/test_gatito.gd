extends SceneTree
## La prueba "El gatito travieso" (docs/pruebas.md): está entre las pruebas, la torre elige para cada sala un cambio seguro del gato (de data/variantes_gato.jsonl), el gato lo aplica al entrar a la
## sala (con su propio límite de movimientos y sin tocar lo que ya se jugó) y en el juego sale en la etapa de la prueba (headless).
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_gatito.gd

const Torre := preload("res://torre/torre.gd")
const Trials := preload("res://scripts/datos/trials.gd")
const Scenarios := preload("res://scripts/datos/scenarios.gd")
const Profile := preload("res://scripts/datos/profile.gd")
const DevCommands := preload("res://scripts/herramientas/dev_commands.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_catalogo()
	test_torre()
	test_entrada()
	await test_juego()
	print("tests del gatito travieso terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_catalogo() -> void:
	check(Trials.CATALOG.has("gatito") and bool(Trials.CATALOG.gatito.get("gatito", false)) and str(Trials.CATALOG.gatito.name) == "El gatito travieso", "el gatito travieso está entre las pruebas")
	for s in Scenarios.ALL:
		check((s.pool as Array).has("gatito"), "%s: puede tocar el gatito" % s.id)
	var t := Trials.for_stage({6: "gatito"}, 6)
	check(t.get("gatito", false) and float(t.mult) > 1.0, "la prueba de la etapa 6 es la del gatito y paga más")


func _salas_de_prueba() -> Array:
	return Torre.cargar_paquete_del_juego()


func test_torre() -> void:
	var paquete := _salas_de_prueba()
	check(paquete.size() > 1000, "hay biblioteca (%d salas)" % paquete.size())
	var sin = Torre.armar(paquete, 5, 10, true, 6, "media")
	var con = Torre.armar(paquete, 5, 10, true, 6, "media", {"gatito": true})
	var con_gato := 0
	for e in sin.salas:
		check(not e.has("gato"), "sin la prueba ninguna sala trae gato")
	for e in con.salas:
		if not e.has("gato"):
			continue
		con_gato += 1
		var g: Dictionary = e.gato
		var pisos := int(e.orig.meta) - 1
		var minimo := 1 if pisos <= 7 else (2 if pisos <= 11 else (3 if pisos <= 15 else (4 if pisos <= 19 else 5)))
		var maximo := 2 if pisos <= 7 else minimo
		check(g.mov.size() >= minimo and g.mov.size() <= maximo, "sala %d (%d pisos): el gato mueve %d bloques (de %d a %d)" % [int(e.id), pisos, g.mov.size(), minimo, maximo])
		for m in g.mov:
			check(Torre.es_anillo(m[0].x, m[0].z) and Torre.es_anillo(m[1].x, m[1].z) and absi(m[0].x - m[1].x) + absi(m[0].z - m[1].z) == 1, "sala %d: el gato mueve un bloque una celda por el anillo" % int(e.id))
		check(int(g.max_mov) >= int(g.d.pasos) and int(g.d.pasos) > 0, "sala %d: tiene su límite de movimientos (%d para %d pasos)" % [int(e.id), int(g.max_mov), int(g.d.pasos)])
		check(g.d.bloques != e.d.bloques, "sala %d: la sala cambiada es distinta de la original" % int(e.id))
	check(con_gato >= con.salas.size() * 7 / 10, "casi todas las salas traen gato (%d de %d)" % [con_gato, con.salas.size()])
	# los cambios son los mismos con la misma semilla
	var otra = Torre.armar(paquete, 5, 10, true, 6, "media", {"gatito": true})
	var igual := true
	for i in con.salas.size():
		igual = igual and (con.salas[i].has("gato") == otra.salas[i].has("gato"))
		if con.salas[i].has("gato"):
			igual = igual and con.salas[i].gato.mov == otra.salas[i].gato.mov
	check(igual, "con la misma semilla el gato hace lo mismo")
	# cada variante elegida se puede jugar entera en la torre, con los bloques de la sala de arriba al alcance
	for i in con.salas.size():
		var e: Dictionary = con.salas[i]
		if not e.has("gato"):
			continue
		var obst: Array = Torre.obstaculos_de(con.salas[i + 1].d, int(e.d.meta)) if i + 1 < con.salas.size() else []
		check(Torre.camino_estricto(e.gato.d, obst), "sala %d: el camino de la variante anda en la torre" % int(e.id))


func test_entrada() -> void:
	var paquete := _salas_de_prueba()
	var t = Torre.armar(paquete, 5, 10, true, 6, "media", {"gatito": true})
	var i := -1
	for k in t.salas.size():
		if t.salas[k].has("gato"):
			i = k
			break
	check(i >= 0, "alguna sala de la torre trae gato")
	if i < 0:
		return
	t.saltar_a_sala(i, 0)
	check(not t.gato_pendiente().is_empty(), "al entrar a la sala el gato tiene algo para hacer")
	var original: Dictionary = t.motor.bloques.duplicate()
	var g: Dictionary = t.gato_pendiente()
	var max_antes: int = t.max_mov()
	t.aplicar_gato()
	check(t.gato_pendiente().is_empty() and t.movs == 0, "el gato lo hace una sola vez y la sala empieza de cero")
	var distintas := 0
	for c in original:
		if not t.motor.bloques.has(c) or str(t.motor.bloques[c]) != str(original[c]):
			distintas += 1
	check(distintas >= g.mov.size(), "la sala cambió (%d celdas distintas)" % distintas)
	check(t.salas[i].max_mov == g.max_mov and t.max_mov() >= 1, "el límite de movimientos es el de la sala cambiada (antes %d, ahora %d)" % [max_antes, t.max_mov()])
	var cambiada: Dictionary = t.motor.bloques.duplicate()
	t.reintentar_sala()
	check(t.gato_pendiente().is_empty() and t.motor.bloques == cambiada, "al reintentar la sala queda como la dejó el gato")
	# se juega el camino de la variante en el motor de la torre
	for a in t.sala_actual().d.camino:
		t.actuar(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
	check(t.motor.ganado or t.indice > i, "se gana la sala con el camino de la variante")


func test_juego() -> void:
	Profile.path = "user://test_profile_gatito.json"
	Profile.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	for k in 4:
		await process_frame
	main.start_game("pesadilla", "media")
	for k in 4:
		await process_frame
	while main.generating or main.torre == null:
		await process_frame
	check(main.torre.reglas.get("gatito", false) == false, "una torre común no lleva la regla del gatito")
	main.run.trial_schedule = {1: "gatito"}   # (la prueba en la etapa 1, para probar)
	main.new_tower(77)
	for k in 6:
		await process_frame
	while main.generating or main.torre == null:
		await process_frame
	check(main.trial.get("gatito", false) and main.torre.reglas.get("gatito", false), "en la etapa de la prueba la torre lleva la regla del gatito")
	var torre = main.torre
	var hubo := false
	for k in torre.t.salas.size():
		hubo = hubo or torre.t.salas[k].has("gato")
	check(hubo, "las salas de la torre traen gato")
	# el gato actúa al entrar a la primera sala: mientras tanto no se juega, y al terminar la sala cambió
	var pendiente: bool = not torre.t.gato_pendiente().is_empty()
	if pendiente:
		check(torre.gatito_actuando, "el gato está en escena")
		check(not torre.accion(Vector3i(1, 0, 0), 0).ok, "mientras el gato mueve bloques no se puede mover")
		var tope := 0
		while torre.gatito_actuando and tope < 900:
			await process_frame
			OS.delay_msec(8)
			tope += 1
		check(not torre.gatito_actuando and torre.t.gato_pendiente().is_empty(), "el gato terminó y la sala quedó cambiada")
		check(torre.gatito_nodo.visible, "el gato se queda esperando en el checkpoint")
	else:
		check(true, "(la primera sala de esta torre no tiene variante)")
	# el comando de desarrollo "prueba": esa prueba en esa etapa
	check(DevCommands.execute("prueba no_existe 3", main).begins_with("Uso:") and DevCommands.execute("prueba gatito 99", main).begins_with("Uso:"), "el comando prueba pide una prueba y una etapa válidas")
	var msg := DevCommands.execute("prueba gatito 3 pesadilla 55", main)
	check(msg.contains("etapa 3") and main.run.trial_at(3).get("gatito", false), "el comando prueba pone el gatito en la etapa 3 (%s)" % msg)
	main.queue_free()
	await process_frame
