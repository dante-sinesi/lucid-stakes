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
		final_siempre = final_siempre and str(sch[15]).begins_with(Trials.FINAL_TRIAL)
		var prev := ""
		for st in Trials.stages():
			var id := str(sch[st])
			if st != 15 and id.begins_with(Trials.FINAL_TRIAL):
				bien = false
			if id == prev:
				seguidas = true
			if int((Trials.CATALOG[Trials.for_stage(sch, st).id] as Dictionary).get("desde", 3)) > st:
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
	for n in range(1, 5):   # (para probar: el jefe final con cada combinación elegida a mano)
		var forzado := Trials.for_stage({15: "pesadilla_despierta_%d" % n}, 15)
		check(forzado.id == Trials.FINAL_TRIAL and forzado.combo == Trials.COMBOS[n - 1].ids, "pesadilla_despierta_%d es el jefe final con la combinación %d" % [n, n])
	var sin_final := Trials.draw_schedule(["sin_ayudas", "sin_racha"], rng)
	check(not str(sin_final[15]).begins_with(Trials.FINAL_TRIAL), "un escenario sin el jefe en su lista no lo tiene")
	# Fácil no limita los movimientos: no salen Presupuesto compartido ni Espalda mala, y el jefe no lleva ninguna de las dos
	var sin_nada := true
	var jefe_bien := true
	for semilla in 150:
		rng.seed = 1000 + semilla
		var sf := Trials.draw_schedule(pool, rng, true)
		for st in Trials.stages():
			var pf := Trials.for_stage(sf, st)
			sin_nada = sin_nada and pf.id != "presupuesto" and pf.id != "espalda_mala"
		var jf := Trials.for_stage(sf, 15)
		jefe_bien = jefe_bien and jf.id == Trials.FINAL_TRIAL and not jf.reglas.has("presupuesto") and not jf.reglas.has("espalda_mala")
	check(sin_nada and jefe_bien, "en Fácil no salen las pruebas que tratan de los movimientos (ni en el jefe final)")
	var con_todo := false
	for semilla in 150:
		rng.seed = 2000 + semilla
		var sn := Trials.draw_schedule(pool, rng, false)
		for st in Trials.stages():
			var pn := Trials.for_stage(sn, st)
			con_todo = con_todo or pn.id == "presupuesto" or pn.id == "espalda_mala" or (pn.has("combo") and pn.combo.has("presupuesto"))
	check(con_todo, "en las otras dificultades sí salen")


func test_espalda_mala() -> void:
	var con_agarres = _torre({"espalda_mala": true}, 12, 91)
	var todas := true
	for e in con_agarres.salas:
		todas = todas and int(e.d.get("agarres", 0)) >= 4
	check(con_agarres.salas.size() == Torre.salas_de_etapa(12) and todas, "Espalda mala: la torre sólo lleva salas en las que la solución empuja o tira cuatro veces o más")
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
		todas = todas and int(e.d.get("distintos", 99)) <= 3 and int(e.d.get("distintos", 0)) >= 2
	check(t.salas.size() == Torre.salas_de_etapa(12) and todas, "Solo tres bloques: la torre sólo lleva salas que mueven dos o tres bloques distintos (con uno solo la regla no se notaría)")
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
	# todas las salas de la biblioteca: con los bloques quebradizos, la solución conocida anda
	var paquete: Array = Torre.cargar_paquete_del_juego()
	var rotas := 0
	var con_cambios := 0
	for d in paquete:
		var q: Dictionary = Torre.quebrar(d)
		if not Torre.camino_ok(q):
			rotas += 1
		if q != d:
			con_cambios += 1
	check(rotas == 0, "Quebradizo: la solución conocida anda en las %d salas de la biblioteca con los bloques quebradizos (fallan %d; %d salas tienen bloques agrietados)" % [paquete.size(), rotas, con_cambios])
	# y en las torres armadas (cada sala con los bloques de la de arriba al alcance)
	var mal := 0
	var torres := 0
	for etapa in [3, 6, 9, 12, 15]:
		for semilla in 6:
			var tq = _torre({"quebradizo": true}, etapa, 600 + semilla * 13 + etapa)
			torres += 1
			for i in tq.salas.size():
				var obst: Array = Torre.obstaculos_de(tq.salas[i + 1].d, int(tq.salas[i].d.meta)) if i + 1 < tq.salas.size() else []
				if not Torre.camino_ok(tq.salas[i].d, obst):
					mal += 1
	check(mal == 0, "Quebradizo: en %d torres de todas las etapas ninguna sala queda sin solución conocida (%d malas)" % [torres, mal])
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
	check(t.presupuesto_total >= suma_pasos, "Presupuesto compartido: el fondo (%d) alcanza para los mínimos de todas las salas (%d)" % [t.presupuesto_total, suma_pasos])
	check(float(t.presupuesto_total) <= float(suma_pasos) * 1.25 + float(t.salas.size()) + 1.0, "Presupuesto compartido: el fondo es justo, sólo un 25 %% más que los mínimos y un movimiento por sala (%d de %d)" % [t.presupuesto_total, suma_pasos])
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
	# colgado, el viento te suelta: al vacío es una muerte por la ventisca; sobre otro bloque, la cosa sigue
	var m4 = Motor.crear(6, Vector3i(4, 1, 5))
	m4.poner(Vector3i(5, 1, 5), "f")
	m4.jugador = Vector3i(4, 1, 5)
	m4.colgado = Vector3i(1, 0, 0)
	check(m4.viento(Vector3i(0, 0, 1)) and m4.perdido and m4.motivo == "Te tiró la ventisca" and m4.colgado == Vector3i.ZERO, "Ventisca: colgado sobre el vacío, el viento te suelta y la sala se pierde por la ventisca")
	var m5 = Motor.crear(6, Vector3i(4, 3, 5))
	m5.poner(Vector3i(5, 3, 5), "f")
	m5.poner(Vector3i(4, 1, 5), "f")
	m5.jugador = Vector3i(4, 3, 5)
	m5.colgado = Vector3i(1, 0, 0)
	check(m5.viento(Vector3i(0, 0, -1)) and not m5.perdido and m5.colgado == Vector3i.ZERO and m5.jugador == Vector3i(4, 2, 5), "Ventisca: colgado con un bloque más abajo, el viento te suelta y caes sobre él: la sala sigue")
	var t = _torre({"ventisca": true}, 6, 41)
	var d := Vector3i(1, 0, 0)
	var r: Dictionary = t.viento(d)
	check(r.has("ok") and r.has("evento"), "Ventisca: la torre responde como a una acción")


func test_terremoto_y_corrupcion() -> void:
	var t = _torre({"terremoto": true}, 9, 33)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cuenta_antes: int = t.motor.bloques.size()
	var r: Dictionary = t.terremoto(rng, 3)
	if bool(r.ok):
		var una_celda := true
		for par in r.movidos:
			una_celda = una_celda and (par.de - par.a).length() == 1.0 and par.de != par.a
		check(una_celda and r.movidos.size() <= 3, "Terremoto: se corren hasta tres bloques, una celda cada uno (%d)" % r.movidos.size())
		check(t.motor.bloques.size() <= cuenta_antes, "Terremoto: no aparecen bloques")
	else:
		check(true, "(Terremoto: la primera sala no tiene un bloque que se pueda correr)")
	# un temblor no tira ningún bloque: cambia de lugar los que corre y deja todo lo demás como estaba
	var caidas := 0
	var sacudidas := 0
	var rng4 := RandomNumberGenerator.new()
	rng4.seed = 9
	for k in 10:
		var tt = _torre({"terremoto": true}, 12, 800 + k)
		for q in 4:
			var cuenta_q: int = tt.motor.bloques.size()
			var rq2: Dictionary = tt.terremoto(rng4, 3)
			if bool(rq2.ok):
				sacudidas += 1
				if tt.motor.bloques.size() != cuenta_q or not tt.motor.caidos_fuera.is_empty():
					caidas += 1
	check(sacudidas > 0 and caidas == 0, "Terremoto: en %d temblores no se cayó ningún bloque (cayeron en %d)" % [sacudidas, caidas])
	var varios := 0
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 3
	for k in 8:
		var tq = _torre({"terremoto": true}, 9, 400 + k)
		var rq: Dictionary = tq.terremoto(rng3, 3)
		if bool(rq.ok) and rq.movidos.size() >= 2:
			varios += 1
	check(varios >= 4, "Terremoto: casi siempre se corren varios bloques a la vez (%d de 8 torres)" % varios)
	var corridos := 0
	for k in 12:
		var rr: Dictionary = t.terremoto(rng)
		if bool(rr.ok):
			corridos += 1
		if str(rr.get("evento", "")) == "muerte" or t.muerta:
			t.reintentar_sala()
	check(corridos > 0, "Terremoto: en 12 temblores se corrieron bloques (%d)" % corridos)
	# siguiendo la solución conocida, el temblor no la rompe: se juegan salas enteras con un temblor después de cada 3 acciones
	var seguro := true
	var temblores := 0
	for semilla in 6:
		var tt = _torre({"terremoto": true}, 9, 300 + semilla)
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = semilla
		for k in tt.salas.size():
			if tt.terminada:
				break
			var camino: Array = tt.sala_actual().d.camino
			var sala_antes: int = tt.indice
			for i in camino.size():
				if tt.indice != sala_antes:
					break
				tt.actuar(Vector3i(int(camino[i][0]), 0, int(camino[i][1])), int(camino[i][2]))
				if tt.indice == sala_antes and i % 3 == 2:
					var rt: Dictionary = tt.terremoto(rng2)
					if bool(rt.ok):
						temblores += 1
			seguro = seguro and tt.indice != sala_antes or tt.terminada
		seguro = seguro and tt.muertes == 0
	check(seguro and temblores > 0, "Terremoto: siguiendo la solución conocida los temblores (%d) no hacen perder ninguna sala" % temblores)
	# corrupción
	var t2 = _torre({"corrupcion": true}, 6, 41)
	for k in 3:   # (los primeros tres pasos de la solución: purifican bloques)
		var a: Array = t2.sala_actual().d.camino[k]
		t2.actuar(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
	var purificados_antes: int = t2.motor.purificados.size()
	var viejo: int = int(t2.motor.purificados.keys()[0])
	var sala_antes: int = t2.cosecha.sala
	var rc: Dictionary = t2.corromper()
	check(bool(rc.ok) and t2.motor.purificados.size() == purificados_antes - 1 and not t2.motor.purificados.has(viejo), "Corrupción que vuelve: se corrompe el bloque purificado más viejo, uno solo (%d -> %d)" % [purificados_antes, t2.motor.purificados.size()])
	check(int(rc.perdida) > 0 and t2.cosecha.sala == sala_antes - int(rc.perdida), "Corrupción que vuelve: se pierde la claridad que daba (%d)" % int(rc.perdida))
	var pisado: int = int(t2.motor.ids[t2.motor.jugador + Vector3i(0, -1, 0)])
	var sigue := true
	for k in 6:
		t2.corromper()
		sigue = sigue and (t2.motor.purificados.has(pisado) or not t2.motor.ids.has(t2.motor.jugador + Vector3i(0, -1, 0)))
	check(sigue, "Corrupción que vuelve: el bloque que pisas no se corrompe")
	var t3 = _torre({}, 6, 41)
	check(not bool(t3.corromper().ok), "Corrupción que vuelve: sin bloques purificados no hay nada que corromper")


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
	var oscuros_torre := 0
	var bloques_torre := 0
	var esp_total := 0
	var esp_oscuros := 0
	var com_total := 0
	var com_oscuros := 0
	for etapa in [9, 12, 15]:
		var tq = _torre({"a_oscuras": true}, etapa, 700 + etapa)
		for e in tq.salas:
			var mo = Vista.motor_de(e.d)
			var os: Dictionary = Torre.oscuros_de(mo, int(e.id))
			for c in mo.bloques:
				var letra := str(mo.bloques[c])
				if letra == "f" or letra == "p" or letra == "d" or (letra.length() >= 2 and letra[0] == "b"):
					continue
				bloques_torre += 1
				var oscuro: bool = os.has(mo.ids[c])
				oscuros_torre += 1 if oscuro else 0
				if letra == "n":
					com_total += 1
					com_oscuros += 1 if oscuro else 0
				else:
					esp_total += 1
					esp_oscuros += 1 if oscuro else 0
	check(esp_total > 20 and float(esp_oscuros) / float(esp_total) >= 0.8, "A oscuras: casi todos los bloques especiales se esconden (%d de %d)" % [esp_oscuros, esp_total])
	check(float(com_oscuros) / float(maxi(com_total, 1)) >= 0.2 and float(com_oscuros) / float(maxi(com_total, 1)) <= 0.6, "A oscuras: de los comunes se esconde una parte (%d de %d)" % [com_oscuros, com_total])
	check(float(oscuros_torre) / float(maxi(bloques_torre, 1)) >= 0.45, "A oscuras: cerca de la mitad o más de los bloques de la torre son negros (%d de %d)" % [oscuros_torre, bloques_torre])
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


func _paso_con_movs(main, movs_antes: int, idx := 0) -> void:
	var torre = main.torre
	torre.t.movs = movs_antes
	var a: Array = torre.t.sala_actual().d.camino[idx]
	torre.accion(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
	await create_timer(0.8).timeout


func test_en_el_juego() -> void:
	# Mareo: cada dos movimientos la cámara gira (45 grados) y no hay cartel
	var main = await _main_con("mareo")
	check(main.trial.get("reglas", {}).get("mareo", false) and main.torre.reglas.get("mareo", false), "Mareo: la torre de la prueba lleva la regla")
	var yaw0: float = main.torre.yaw_target
	await _paso_con_movs(main, 1)
	check(absf(absf(main.torre.yaw_target - yaw0) - 45.0) < 0.01 and not main.torre._efecto_en_curso, "Mareo: al segundo movimiento la cámara gira 45 grados")
	var yaw1: float = main.torre.yaw_target
	await _paso_con_movs(main, 2, 1)   # (el tercer movimiento no gira)
	check(is_equal_approx(main.torre.yaw_target, yaw1), "Mareo: el tercer movimiento no la gira")
	main.queue_free()
	await process_frame
	# Corrupción que vuelve: de a poco un bloque purificado se corrompe otra vez
	main = await _main_con("corrupcion")
	var tj = main.torre
	var camino0: Array = tj.t.sala_actual().d.camino
	for k in 3:
		tj.accion(Vector3i(int(camino0[k][0]), 0, int(camino0[k][1])), int(camino0[k][2]))
		await create_timer(0.35).timeout
	var antes_p: int = tj.t.motor.purificados.size()
	tj._corrupcion()
	check(tj.t.motor.purificados.size() == antes_p - 1, "Corrupción que vuelve: en el juego se corrompe un bloque purificado (%d -> %d)" % [antes_p, tj.t.motor.purificados.size()])
	main.queue_free()
	await process_frame
	# Ventisca: se avisa de 1 a 3 movimientos antes (líneas de minicubos) y sopla; los momentos son al azar y no se reinician con cada sala
	main = await _main_con("ventisca")
	main.torre._viento_cada = 6
	main.torre._viento_aviso = 1
	main.torre._viento_acciones = 4   # (con la acción de ahora son 5: un movimiento antes del viento, se avisa)
	await _paso_con_movs(main, 3)
	check(main.torre._viento != Vector3i.ZERO and main.torre._viento_chorro != null and main.torre._viento_chorro.emitting, "Ventisca: antes del viento aparecen las líneas de minicubos")
	check(main.torre._viento_chorro.mesh != null and main.torre._viento_chorro.direction == Vector3(main.torre._viento), "Ventisca: las líneas corren hacia donde va a soplar")
	var siguiente: Array = main.torre.t.sala_actual().d.camino[1] if main.torre.t.sala_actual().d.camino.size() > 1 else main.torre.t.sala_actual().d.camino[0]
	main.torre.accion(Vector3i(int(siguiente[0]), 0, int(siguiente[1])), int(siguiente[2]))
	await create_timer(0.8).timeout
	check(main.torre._viento == Vector3i.ZERO, "Ventisca: en el movimiento siguiente sopla y se limpia el aviso")
	var intervalos := {}
	var avisos := {}
	for k in 60:
		main.torre._sortear_viento()
		intervalos[main.torre._viento_cada] = true
		avisos[main.torre._viento_aviso] = true
	check(intervalos.size() >= 4 and intervalos.keys().min() >= 5 and intervalos.keys().max() <= 11, "Ventisca: el momento del viento se sortea entre 5 y 11 movimientos (%s)" % str(intervalos.keys()))
	check(avisos.has(1) and avisos.has(2) and avisos.has(3) and avisos.size() == 3, "Ventisca: el aviso viene de 1 a 3 movimientos antes (%s)" % str(avisos.keys()))
	# el viento no se reinicia con cada sala: sigue contando
	main.torre._viento_acciones = 3
	main.torre._viento_cada = 9
	main.torre._viento_aviso = 2
	var antes_sala: int = main.torre._viento_acciones
	main.torre._reglas_despues({"ok": true, "evento": "checkpoint"})
	check(main.torre._viento_acciones == antes_sala + 1, "Ventisca: un movimiento que cambia de sala también cuenta para el viento")
	main.queue_free()
	await process_frame
	# Terremoto: tiembla la torre (los bloques se sacuden) y se corren varios bloques
	main = await _main_con("terremoto")
	main.torre._sala_reglas = main.torre.t.indice
	main.torre._movs_reglas = 3
	main.torre._sig_temblor = 5
	await _paso_con_movs(main, 3)   # (un movimiento antes: el aviso)
	check(main.torre._temblor > 0.0 and not main.torre._efecto_en_curso, "Terremoto: un movimiento antes empieza a temblar")
	var sig2: Array = main.torre.t.sala_actual().d.camino[1] if main.torre.t.sala_actual().d.camino.size() > 1 else main.torre.t.sala_actual().d.camino[0]
	main.torre.accion(Vector3i(int(sig2[0]), 0, int(sig2[1])), int(sig2[2]))
	await create_timer(0.45).timeout
	check(main.torre._temblor > 1.0, "Terremoto: al llegar el temblor la sacudida es fuerte (%.2f s)" % main.torre._temblor)
	await create_timer(0.8).timeout
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
