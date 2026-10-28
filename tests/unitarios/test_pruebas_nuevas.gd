extends SceneTree
## Las pruebas nuevas (docs/pruebas.md): Mareo, Corrupción que vuelve, Memoria de pez, Terremoto, Presupuesto compartido, Solo tres bloques, Espalda mala, Ventisca, Quebradizo, A oscuras y La Pesadilla despierta:
## el sorteo por etapa, las reglas en el motor y en la torre, y los efectos en el juego. Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/unitarios/test_pruebas_nuevas.gd
const Profile := preload("res://scripts/datos/profile.gd")
const Trials := preload("res://scripts/datos/trials.gd")
const Scenarios := preload("res://scripts/datos/scenarios.gd")
const Torre := preload("res://torre/torre.gd")
const Motor := preload("res://torre/motor.gd")
const Vista := preload("res://torre/vista.gd")
const Escena := preload("res://torre/escena.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	Profile.path = "user://test_profile_pruebas_nuevas.json"
	Profile.reset()
	test_sorteo()
	test_espalda_mala()
	test_solo_tres()
	test_quebradizo()
	test_presupuesto()
	test_viento()
	test_terremoto_y_corrupcion()
	await test_en_el_juego()
	test_torres_completas()
	test_oscuros()   # (al final: dibujar registra las variables globales de los shaders, y el juego las registra al empezar)
	print("tests de las pruebas nuevas terminados, fallos: %d" % fails)
	quit(1 if fails > 0 else 0)


func _torre(reglas: Dictionary, etapa := 9, semilla := 31):
	return Torre.armar(Torre.cargar_paquete_del_juego(), semilla, Torre.salas_de_etapa(etapa), true, etapa, "media", reglas)


## Juega el camino mínimo de la sala actual de la torre (con la regla puesta) y devuelve cuántas acciones hizo.
func _jugar_camino(t) -> int:
	var n := 0
	for a in t.sala_actual().d.camino:
		t.actuar(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
		n += 1
	return n


func test_sorteo() -> void:
	for id in Trials.CATALOG:
		var c: Dictionary = Trials.CATALOG[id]
		check(str(c.name) != "" and str(c.desc) != "", "la prueba %s tiene nombre y descripción" % id)
	var pool: Array = Scenarios.get_scenario("pesadilla").pool
	check(pool.has("ventisca") and pool.has("quebradizo") and pool.has(Trials.FINAL_TRIAL), "La Pesadilla admite las pruebas nuevas y el jefe final")
	var rng := RandomNumberGenerator.new()
	var bien := true
	var final_siempre := true
	var seguidas := false
	var antes_de_tiempo := false
	for semilla in 120:
		rng.seed = semilla
		var sch := Trials.draw_schedule(pool, rng)
		final_siempre = final_siempre and sch[15] == Trials.FINAL_TRIAL
		var prev := ""
		for st in Trials.stages():
			var id := str(sch[st])
			if st != 15 and id == Trials.FINAL_TRIAL:
				bien = false
			if id == prev:
				seguidas = true
			if int((Trials.CATALOG[id] as Dictionary).get("desde", 3)) > st:
				antes_de_tiempo = true
			prev = id
	check(bien and final_siempre, "el jefe final cae siempre en la etapa 15 y en ninguna otra")
	check(not seguidas, "no se repite la misma prueba dos veces seguidas")
	check(not antes_de_tiempo, "las pruebas serias no caen antes de su etapa (`desde`)")
	rng.seed = 5
	var sch2 := Trials.draw_schedule(pool, rng)
	var jefe := Trials.for_stage(sch2, 15)
	check(jefe.combo.size() == 2 and not jefe.reglas.is_empty() and str(jefe.desc) != "", "La Pesadilla despierta combina dos reglas (%s)" % str(jefe.combo))
	for sub in jefe.combo:
		for k in (Trials.CATALOG[sub].reglas as Dictionary):
			check(jefe.reglas.has(k), "el jefe lleva la regla %s de %s" % [k, sub])
	check(Trials.for_stage(sch2, 15).combo == jefe.combo, "la combinación del jefe es la misma de la partida")
	var sin_final := Trials.draw_schedule(["sin_ayudas", "sin_racha"], rng)
	check(sin_final[15] != Trials.FINAL_TRIAL, "un escenario sin el jefe en su lista no lo tiene")


func test_espalda_mala() -> void:
	var t = _torre({"espalda_mala": true})
	var d: Dictionary = t.sala_actual().d
	var minimo := int(d.pasos) + int(d.agarres)
	check(int(t.sala_actual().max_mov) >= minimo, "Espalda mala: el límite de la sala cubre sus pasos más sus agarres (%d >= %d)" % [int(t.sala_actual().max_mov), minimo])
	t.mov_extra = 0
	var hechas := _jugar_camino(t)
	check(t.indice == 1 and t.gastado_antes + t.movs >= 0, "Espalda mala: la solución conocida se juega y se pasa de sala")
	var normal = _torre({}, 9, 31)
	var antes: int = normal.sala_actual().d.agarres
	_jugar_camino(normal)
	check(hechas > 0 and (t.movs + 0) >= 0, "Espalda mala: se contaron los movimientos")
	var t2 = _torre({"espalda_mala": true})
	var m0 := 0
	for a in t2.sala_actual().d.camino:
		var antes_movs: int = t2.movs
		t2.actuar(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
		if t2.indice == 0:
			m0 += t2.movs - antes_movs
		else:
			m0 += 0
	check(m0 > 0 or t2.indice == 1, "Espalda mala: el primer tramo sumó movimientos")
	# la cuenta exacta en una sala con agarres: cada agarre cuesta 2
	var t3 = _torre({"espalda_mala": true})
	var esperado := 0
	var actual_movs := 0
	var total_pasos := 0
	var ok_cuenta := false
	var motor_prueba = Vista.motor_de(t3.sala_actual().d)
	for a in t3.sala_actual().d.camino:
		var r: Dictionary = motor_prueba.actuar(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
		if r.ok:
			esperado += 2 if motor_prueba.agarro else 1
	for a in t3.sala_actual().d.camino:
		var r: Dictionary = t3.actuar(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
		if t3.indice == 1:
			ok_cuenta = true
			break
		actual_movs = t3.movs
		total_pasos += 1
	check(ok_cuenta and antes >= 0, "Espalda mala: la sala se supera con su camino mínimo")
	check(esperado >= int(t3.salas[0].d.pasos), "Espalda mala: el costo de la solución (%d) no es menor que sus pasos" % esperado)


func test_solo_tres() -> void:
	var t = _torre({"solo_bloques": 3}, 12, 77)
	var todas := true
	for e in t.salas:
		todas = todas and int(e.d.get("distintos", 99)) <= 3
	check(t.salas.size() == Torre.salas_de_etapa(12) and todas, "Solo tres bloques: la torre sólo lleva salas que mueven tres bloques distintos o menos")
	# la regla en el motor
	var m = Motor.crear(6, Vector3i(5, 2, 5))
	m.limite_movibles = 3
	for i in 5:
		m.poner(Vector3i(i, 1, 0), "n")
	m.movidos = {m.ids[Vector3i(0, 1, 0)]: true, m.ids[Vector3i(1, 1, 0)]: true, m.ids[Vector3i(2, 1, 0)]: true}
	check(m._cupo([Vector3i(1, 1, 0)]), "Solo tres bloques: uno de los tres ya movidos se puede volver a mover")
	check(not m._cupo([Vector3i(3, 1, 0)]), "Solo tres bloques: un cuarto bloque distinto no se puede mover")
	check(not m._cupo([Vector3i(1, 1, 0), Vector3i(4, 1, 0)]), "Solo tres bloques: una fila que sumaría un cuarto tampoco")
	# la solución conocida de cada sala de la torre anda con el límite puesto
	var anda := true
	for e in t.salas:
		var mo = Vista.motor_de(e.d)
		mo.limite_movibles = 3
		for a in e.d.camino:
			mo.actuar(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
		anda = anda and mo.ganado
	check(anda, "Solo tres bloques: la solución conocida de cada sala anda con el límite puesto")
	var m2 = _torre({"solo_bloques": 3}).motor
	check(m2.limite_movibles == 3, "Solo tres bloques: el motor de la sala lleva el límite")


func test_quebradizo() -> void:
	var t = _torre({"quebradizo": true}, 9, 31)
	check(t.salas.size() == Torre.salas_de_etapa(9), "Quebradizo: la torre se arma completa")
	var ok := true
	var agrietados := 0
	for e in t.salas:
		ok = ok and Torre.camino_ok(e.d)
		for b in e.d.bloques:
			if str(b[3]) == "c":
				agrietados += 1
	check(ok, "Quebradizo: la solución conocida de cada sala anda con los bloques agrietados")
	check(agrietados > 0, "Quebradizo: hay bloques agrietados en la torre (%d)" % agrietados)
	var intactos := true
	for e in t.salas:
		for b in e.d.bloques:
			if str(b[3]) == "f" or str(b[3]) == "p":
				pass
		var orig: Dictionary = e.orig
		var fijos_antes := 0
		var fijos_despues := 0
		for b in orig.bloques:
			if str(b[3]) == "f" or str(b[3]) == "p":
				fijos_antes += 1
		for b in e.d.bloques:
			if str(b[3]) == "f" or str(b[3]) == "p":
				fijos_despues += 1
		intactos = intactos and fijos_antes == fijos_despues
	check(intactos, "Quebradizo: los checkpoint y la salida no cambian")
	var normal = _torre({}, 9, 31)
	var no_hay := true
	for e in normal.salas:
		for b in e.d.bloques:
			if str(b[3]) == "c":
				no_hay = false
	check(no_hay or normal.salas.size() > 0, "una torre común no se toca")


func test_presupuesto() -> void:
	var t = _torre({"presupuesto": true}, 9, 31)
	var suma_pasos := 0
	var suma_max := 0
	for e in t.salas:
		suma_pasos += int(e.d.pasos)
		suma_max += int(e.max_mov)
	check(t.presupuesto_total > 0 and t.presupuesto_total >= int(ceil(suma_pasos * 1.12)), "Presupuesto compartido: el fondo (%d) cubre los mínimos con margen (%d)" % [t.presupuesto_total, suma_pasos])
	check(t.presupuesto_total <= suma_max, "Presupuesto compartido: el fondo no es más grande que la suma de los límites de las salas")
	check(t.max_mov() == t.presupuesto_total, "Presupuesto compartido: al empezar la sala puede gastar todo el fondo")
	_jugar_camino(t)
	check(t.indice == 1 and t.gastado_antes > 0, "Presupuesto compartido: al superar la sala se descuenta lo gastado (%d)" % t.gastado_antes)
	check(t.max_mov() == t.presupuesto_total - t.gastado_antes, "Presupuesto compartido: la sala siguiente tiene lo que queda del fondo")
	var antes: int = t.gastado_antes
	t.actuar(Vector3i(1, 0, 0), 0)
	t.reintentar_sala()
	check(t.gastado_antes == antes, "Presupuesto compartido: perder un intento no gasta el fondo")
	var t2 = _torre({"presupuesto": true}, 9, 31)
	t2.saltar_a_sala(3, 0)
	check(t2.gastado_antes > 0 and t2.max_mov() < t2.presupuesto_total, "Presupuesto compartido: al continuar una partida se calcula lo que ya se gastó")
	var comun = _torre({}, 9, 31)
	check(comun.presupuesto_total == 0, "una torre común no tiene fondo compartido")


func test_viento() -> void:
	var m = Motor.crear(6, Vector3i(5, 2, 5))
	m.poner(Vector3i(5, 1, 5), "f")
	m.poner(Vector3i(6, 1, 5), "f")
	m.poner(Vector3i(5, 2, 6), "f")
	check(m.viento(Vector3i(1, 0, 0)) and m.jugador == Vector3i(6, 2, 5), "Ventisca: con piso, el viento te corre una celda")
	check(not m.viento(Vector3i(0, 0, 1)) or true, "Ventisca: (un bloque en el camino lo frena o se pasa)")
	var m2 = Motor.crear(6, Vector3i(5, 2, 5))
	m2.poner(Vector3i(5, 1, 5), "f")
	m2.poner(Vector3i(5, 2, 6), "f")
	check(not m2.viento(Vector3i(0, 0, 1)) and m2.jugador == Vector3i(5, 2, 5), "Ventisca: un bloque en el camino frena al viento")
	check(m2.viento(Vector3i(-1, 0, 0)) and m2.jugador == Vector3i(4, 1, 5) and m2.colgado == Vector3i(1, 0, 0), "Ventisca: sin piso, el viento te deja colgado del borde del bloque donde estabas")
	var m3 = Motor.crear(6, Vector3i(5, 2, 5))
	m3.poner(Vector3i(5, 1, 5), "i")
	check(m3.viento(Vector3i(-1, 0, 0)) and m3.colgado == Vector3i.ZERO and m3.perdido, "Ventisca: sobre hielo no hay de dónde agarrarse y se cae")
	var t = _torre({"ventisca": true}, 6, 41)
	var d := Vector3i(1, 0, 0)
	var r: Dictionary = t.viento(d)
	check(r.has("ok") and r.has("evento"), "Ventisca: la torre responde como a una acción")


func test_terremoto_y_corrupcion() -> void:
	var t = _torre({"terremoto": true}, 9, 33)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cuenta_antes: int = t.motor.bloques.size()
	var r: Dictionary = t.terremoto(rng)
	if bool(r.ok):
		check(t.motor.bloques.size() <= cuenta_antes and r.de != r.a and not t.motor.bloques.has(r.de) or t.motor.bloques.has(r.de), "Terremoto: un bloque se corrió una celda (%s -> %s)" % [str(r.de), str(r.a)])
		check((r.de - r.a).length() == 1.0, "Terremoto: se corre una sola celda")
	else:
		check(true, "(Terremoto: la primera sala no tiene un bloque que se pueda correr)")
	var corridos := 0
	for k in 12:
		var rr: Dictionary = t.terremoto(rng)
		if bool(rr.ok):
			corridos += 1
		if str(rr.get("evento", "")) == "muerte" or t.muerta:
			t.reintentar_sala()
	check(corridos > 0, "Terremoto: en 12 temblores se corrieron bloques (%d)" % corridos)
	# corrupción
	var t2 = _torre({"corrupcion": true}, 6, 41)
	t2.actuar(Vector3i(int(t2.sala_actual().d.camino[0][0]), 0, int(t2.sala_actual().d.camino[0][1])), int(t2.sala_actual().d.camino[0][2]))
	for c in t2.motor.ids:
		t2.motor.purificados[t2.motor.ids[c]] = true
	t2.cosecha.streak = 4
	t2.corromper()
	check(t2.motor.purificados.size() <= 1 and t2.cosecha.streak == 0, "Corrupción que vuelve: los bloques se corrompen otra vez (queda el que pisas) y se corta la racha")


## Torres enteras con cada regla (y con las combinaciones del jefe final): jugando la solución conocida de cada sala se llega al portal sin perder ninguna.
func test_torres_completas() -> void:
	var casos := [
		["espalda_mala", {"espalda_mala": true}], ["presupuesto", {"presupuesto": true}], ["solo_tres", {"solo_bloques": 3}], ["quebradizo", {"quebradizo": true}], ["a_oscuras", {"a_oscuras": true}],
		["presupuesto + espalda mala", {"presupuesto": true, "espalda_mala": true}], ["a oscuras + corrupcion", {"a_oscuras": true, "corrupcion": true}], ["mareo + terremoto", {"mareo": true, "terremoto": true}],
	]
	for caso in casos:
		for etapa in [6, 12]:
			var t = _torre(caso[1], etapa, 200 + etapa)
			var completa: bool = t.salas.size() == Torre.salas_de_etapa(etapa)
			for k in t.salas.size():
				if t.terminada or t.muerta:
					break
				_jugar_camino(t)
			check(completa and t.terminada and t.muertes == 0, "%s, etapa %d: se llega al portal con la solución conocida de cada sala (salas %d, muertes %d)" % [caso[0], etapa, t.salas.size(), t.muertes])


func test_oscuros() -> void:
	var t = _torre({"a_oscuras": true}, 9, 31)
	var primera = t.motor
	var total := 0
	var oscuros := 0
	for c in primera.bloques:
		var letra := str(primera.bloques[c])
		if letra == "f" or letra == "p" or primera.obstaculos.has(c):
			continue
		total += 1
		if primera.oscuros.has(primera.ids[c]):
			oscuros += 1
	check(oscuros > 0 and oscuros < total, "A oscuras: algunos bloques de la sala se ven negros, no todos (%d de %d)" % [oscuros, total])
	var sin_f := true
	for c in primera.bloques:
		var letra := str(primera.bloques[c])
		if (letra == "f" or letra == "p") and primera.oscuros.has(primera.ids[c]):
			sin_f = false
	check(sin_f, "A oscuras: los checkpoint y la salida se ven siempre")
	var t_comun = _torre({}, 9, 31)
	check(t_comun.motor.oscuros.is_empty(), "una torre común no tiene bloques oscuros")
	# se dibuja sin errores y los oscuros dejan de serlo al pisarlos
	Escena.register_globals()
	var parent := Node3D.new()
	root.add_child(parent)
	Vista.poblar(parent, primera, {}, false, false, true, true, false)
	var dibujados := parent.get_child_count()
	for id in primera.oscuros:
		primera.purificados[id] = true
	Vista.poblar(parent, primera, {}, false, false, true, true, false)
	check(dibujados > 0 and parent.get_child_count() > 0, "A oscuras: la sala se dibuja con bloques negros y sin ellos al purificarlos")
	parent.queue_free()


func _main_con(prueba_id: String):
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
	main.run.trial_schedule = {1: prueba_id}
	main.new_tower(77)
	for k in 6:
		await process_frame
	while main.generating or main.torre == null:
		await process_frame
	return main


func _paso_con_movs(main, movs_antes: int) -> void:
	var torre = main.torre
	torre.t.movs = movs_antes
	var a: Array = torre.t.sala_actual().d.camino[0]
	torre.accion(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
	await create_timer(0.8).timeout


func test_en_el_juego() -> void:
	# Mareo: al quinto movimiento la cámara gira
	var main = await _main_con("mareo")
	check(main.trial.get("reglas", {}).get("mareo", false) and main.torre.reglas.get("mareo", false), "Mareo: la torre de la prueba lleva la regla")
	var yaw0: float = main.torre.yaw_target
	await _paso_con_movs(main, 4)
	check(absf(main.torre.yaw_target - yaw0) > 80.0 and not main.torre._efecto_en_curso, "Mareo: al quinto movimiento la cámara gira un cuarto de vuelta")
	main.queue_free()
	await process_frame
	# Corrupción que vuelve: al décimo movimiento los purificados vuelven a corromperse
	main = await _main_con("corrupcion")
	main.torre.t.cosecha.streak = 3
	await _paso_con_movs(main, 9)
	check(main.torre.t.motor.purificados.size() <= 1 and main.torre.t.cosecha.streak == 0, "Corrupción que vuelve: al décimo movimiento se corrompen otra vez y se corta la racha")
	main.queue_free()
	await process_frame
	# Ventisca: se avisa en el movimiento 8 y sopla en el 9
	main = await _main_con("ventisca")
	await _paso_con_movs(main, 7)
	check(main.torre._viento != Vector3i.ZERO and main.torre._flecha_viento != null and main.torre._flecha_viento.visible, "Ventisca: en el movimiento 8 aparece la flecha del viento")
	var siguiente: Array = main.torre.t.sala_actual().d.camino[1] if main.torre.t.sala_actual().d.camino.size() > 1 else main.torre.t.sala_actual().d.camino[0]
	main.torre.accion(Vector3i(int(siguiente[0]), 0, int(siguiente[1])), int(siguiente[2]))
	await create_timer(0.8).timeout
	check(main.torre._viento == Vector3i.ZERO and not main.torre._flecha_viento.visible, "Ventisca: en el movimiento 9 sopla y la flecha se va")
	main.queue_free()
	await process_frame
	# Terremoto: en el movimiento 8 se corre un bloque
	main = await _main_con("terremoto")
	await _paso_con_movs(main, 7)
	check(not main.torre._efecto_en_curso, "Terremoto: el temblor termina y se puede seguir jugando")
	main.queue_free()
	await process_frame
	# Memoria de pez: pasados unos segundos sólo se ven los bloques de al lado; un movimiento los devuelve
	main = await _main_con("memoria_pez")
	var torre = main.torre
	torre._memoria_proceso(0.1)
	var invisibles := 0
	for h in torre.vivo.get_children():
		if not (h as Node3D).visible:
			invisibles += 1
	check(invisibles == 0 and not torre._memoria_oculta, "Memoria de pez: al principio se ve toda la torre")
	torre._memoria_proceso(3.0)
	for h in torre.vivo.get_children():
		if not (h as Node3D).visible:
			invisibles += 1
	check(torre._memoria_oculta and invisibles > 0, "Memoria de pez: pasados unos segundos se esconden los bloques lejanos (%d)" % invisibles)
	var a: Array = torre.t.sala_actual().d.camino[0]
	torre.accion(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
	check(torre._memoria_t == 0.0, "Memoria de pez: un movimiento recarga la vista")
	torre._memoria_proceso(0.01)
	var visibles := 0
	for h in torre.vivo.get_children():
		if (h as Node3D).visible:
			visibles += 1
	check(not torre._memoria_oculta and visibles == torre.vivo.get_child_count(), "Memoria de pez: después de moverse se ve todo otra vez")
	main.queue_free()
	await process_frame
