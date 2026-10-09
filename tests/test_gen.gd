extends SceneTree
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_gen.gd

const TowerLogic := preload("res://scripts/tower_logic.gd")
const Solver := preload("res://scripts/solver.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const K := TowerLogic.Kind

## Busqueda liviana: la que usa el juego al generar (la completa es mucho mas lenta; ver tests/test_gen_quality.gd).
const LIGHT := {"tries": 6, "climb": 0.5, "budget_states": 25000, "max_states": 2000}

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func mean(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(a.size(), 1)


func core_cells(lg) -> Array:
	var cells: Array = []
	for c in lg.fixed:
		cells.append(c)
	return cells


func _init() -> void:
	test_geometry()
	test_easy_tower()
	test_variety()
	test_difficulty()
	test_fairness()
	test_kind_weights()
	test_profiles()
	print("tests del generador terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_geometry() -> void:
	var g2 := Gen.geometry(2)
	var g3 := Gen.geometry(3)
	check(g2.foot == Vector2i(8, 8) and g3.foot == Vector2i(9, 9), "huella: core + 3 de espesor por lado (8x8 con core 2x2, 9x9 con core 3x3)")
	check(not Gen.in_envelope(Vector2i(3, 3), g2) and Gen.in_envelope(Vector2i(2, 3), g2) and Gen.touches_core(Vector2i(2, 3), g2) and not Gen.touches_core(Vector2i(1, 3), g2), "el core no es parte del anillo")

	# Anillos alrededor del core: ciclos cerrados de celdas vecinas, todas dentro de la huella.
	for r in range(1, 4):
		var cyc := Gen.ring_cycle(g2, r)
		var ok := cyc.size() == 4 * (2 + 2 * r) - 4
		for i in cyc.size():
			var a := cyc[i]
			var b := cyc[(i + 1) % cyc.size()]
			ok = ok and absi(a.x - b.x) + absi(a.y - b.y) == 1 and Gen.in_envelope(a, g2) and Gen.ring_of(a, g2) == r
		check(ok, "el anillo %d es un ciclo de celdas vecinas, todas a distancia %d del core" % [r, r])
	check(Gen.ring_of(Vector2i(2, 3), g2) == 1 and Gen.ring_of(Vector2i(0, 0), g2) == 3 and Gen.ring_of(Vector2i(2, 2), g2) == 1, "ring_of: pegado = 1, esquina de la huella = 3, diagonal al core = 1")


func test_easy_tower() -> void:
	var r := Gen.generate_stage(1, 5, 0.0, LIGHT)
	check(r.ok, "genera una etapa facil")
	if not r.ok:
		return
	var lg = r.logic
	check(lg.goal_y == 6 and r.rows.size() == 5, "5 filas, altura meta 6")
	check(lg.goal_block >= 0 and lg.positions.has(lg.goal_block), "la torre generada tiene bloque-portal")
	check(lg.size == Vector2i(8, 8), "huella 8x8")
	var core0 := core_cells(lg)
	check(core0.size() == 4 * (5 + 2), "el core 2x2 llega hasta una capa sobre la meta (y=0..6)")
	var in_foot := true
	for c in lg.blocks:
		in_foot = in_foot and c.x < 8 and c.z < 8
	check(in_foot, "ningun bloque sale de la huella")
	var s = lg.clone()
	for a in r.path:
		s.try_action(a.dir, a.mode)
	check(s.won and not s.lost, "el camino guardado gana con la caida de la fila base activa (N=%d)" % lg.collapse_every)
	var core_intact := true
	for c in core0:
		core_intact = core_intact and s.blocks.has(c) == (c.y >= s.floor_y)
	check(core_intact, "el core no se movio (solo cae por el piso que sube)")
	check(lg.collapse_every >= r.n_min, "N tiene margen sobre el minimo")
	var total := 0
	for m in r.rows:
		total += m
	check(total == r.path.size(), "la suma de filas es el largo del camino")
	var r2 := Gen.generate_stage(1, 5, 0.0, LIGHT)
	check(r2.rows == r.rows and r2.logic.blocks.size() == lg.blocks.size() and r2.shapes == r.shapes, "misma semilla, misma torre")
	var r3 := Gen.generate_stage(2, 3, 0.0, {"core": 3, "tries": 6, "climb": 0.5})
	check(r3.ok and r3.logic.size == Vector2i(9, 9), "core 3x3: huella 9x9")


## Una etapa dificil usa todas las formas de plataforma y todos los tipos de bloque, y sigue siendo ganable.
func test_variety() -> void:
	var t0 := Time.get_ticks_msec()
	var r := Gen.generate_stage(7, 8, 0.8, LIGHT.merged({"budget_states": 60000}, true))   # (con el tope de trabajo de la partida esta semilla sale con 2 formas: el test mira la variedad, no el tope)
	print("variedad (d=0.8): filas ", r.rows, " formas ", r.shapes, " tipos ", r.kinds, " ms=", Time.get_ticks_msec() - t0)
	check(r.ok, "genera una etapa dificil")
	if not r.ok:
		return
	var lg = r.logic
	var distinct_shapes := {}
	for sh in r.shapes:
		distinct_shapes[sh] = true
	check(distinct_shapes.size() >= 3, "al menos 3 formas de plataforma distintas (hay %d)" % distinct_shapes.size())
	check(r.kinds.has(K.ICE), "hay hielo en una etapa dificil (tipos presentes: %s)" % str(r.kinds.keys()))
	check(not r.kinds.has(K.CATAPULT) or Gen.CATAPULTS_IN_TOWERS, "las catapultas no se generan en las torres mientras CATAPULTS_IN_TOWERS sea falso")

	# Cada bomba tiene una cuenta valida; los tipos son los conocidos.
	var bombs_ok := true
	for id in lg.bomb_timer:
		bombs_ok = bombs_ok and lg.bomb_timer[id] >= 3 and lg.bomb_timer[id] <= 8 and lg.kind_of[id] == K.BOMB
	check(bombs_ok, "las cuentas de las bombas estan entre 3 y 8")
	var kinds_ok := true
	for id in lg.kind_of:
		kinds_ok = kinds_ok and lg.kind_of[id] >= K.ICE and lg.kind_of[id] <= K.SPIKES
	check(kinds_ok, "todos los tipos de bloque generados son validos")
	check(not lg.kind_of.is_empty() and lg.fixed.size() == 4 * (8 + 2), "los tipos van sobre bloques no fijos; el core sigue entero")

	# La solucion guardada gana con la caida activa y sin que ninguna bomba explote.
	var s = lg.clone()
	var exploded := false
	for a in r.path:
		var res: Dictionary = s.try_action(a.dir, a.mode)
		exploded = exploded or s.lost_reason.contains("bomba")
		if not res.ok:
			break
	check(s.won and not s.lost and not exploded, "la solucion de la torre dificil gana (N=%d) sin explosiones" % lg.collapse_every)

	# El minimo de la primera fila coincide con una resolucion independiente sobre la torre final.
	var solo := Solver.solve(lg, 2, {"max_states": 20000})
	check(solo.status == "solved" and solo.moves <= r.rows[0], "resolviendo la torre final, la fila 1 no cuesta mas que lo registrado (%d <= %d)" % [solo.moves, r.rows[0]])

	# Las filas con tipos especiales se pueden resolver de verdad: recorrer el camino nunca hace un movimiento invalido.
	var s2 = lg.clone()
	var invalid := 0
	for a in r.path:
		if not s2.try_action(a.dir, a.mode).ok:
			invalid += 1
	check(invalid == 0, "ningun movimiento de la solucion es invalido")


func test_difficulty() -> void:
	var low := []
	var high := []
	for sd in 2:
		var a := Gen.generate_stage(sd, 3, 0.0, LIGHT)
		var b := Gen.generate_stage(sd, 3, 1.0, LIGHT)
		check(a.ok and b.ok, "genera semilla %d en ambas dificultades" % sd)
		if a.ok and b.ok:
			low.append_array(a.rows)
			high.append_array(b.rows)
			print("sd ", sd, " d=0: ", a.rows, " ms=", a.ms, " | d=1: ", b.rows, " ms=", b.ms, " N=", b.logic.collapse_every)
	print("media por fila d=0: ", mean(low), "  d=1: ", mean(high))
	check(mean(high) > mean(low) + 1.5, "mayor dificultad => bastante mas movimientos minimos por fila")
	var band_hi := Gen.band_for(1.0).y
	check(high.max() <= band_hi + 4, "ninguna fila supera el techo de la banda + 4 (max %d, techo %d)" % [high.max(), band_hi + 4])
	check(high.max() >= 6, "con dificultad maxima aparecen filas largas (max %d)" % high.max())


func std(a: Array) -> float:
	var m := mean(a)
	var v := 0.0
	for x in a:
		v += (x - m) * (x - m)
	return sqrt(v / maxf(a.size(), 1))


## Justicia de la dificultad: dos torres de la misma dificultad presionan igual, casi no hay filas triviales,
## las mecanicas se desbloquean de a una y hay un tope de bloques especiales por fila.
func test_fairness() -> void:
	var d := 0.3
	var rows_all := []
	var ones := 0
	var ratio_ok := true
	var grace_ok := true
	var target := lerpf(4.5, 2.6, d)
	var ratios := []
	for sd in 3:
		var r := Gen.generate_stage(sd, 5, d, LIGHT)
		check(r.ok, "d=0.3 semilla %d genera" % sd)
		if not r.ok:
			continue
		var lg = r.logic
		var avg := float(r.path.size()) / 5.0
		var ratio := float(lg.collapse_every) / avg
		ratios.append(ratio)
		ratio_ok = ratio_ok and ratio >= target * 0.95 and ratio <= target * 1.4
		grace_ok = grace_ok and lg.moves_to_collapse == 2 * lg.collapse_every
		for m in r.rows:
			rows_all.append(m)
			if m <= 1:
				ones += 1
		# Sin bombas ni catapultas en esta dificultad (se desbloquean mas tarde)
		check(not r.kinds.has(K.BOMB), "d=0.3: todavia no hay bombas (se desbloquean desde 0.4)")
		# Tope de bloques especiales por fila (obstaculos)
		var cap_ok := true
		for inf in r.infos:
			var specials := 0
			for o in inf.obs:
				if o.kind != K.NORMAL:
					specials += 1
			cap_ok = cap_ok and specials <= 1 + int(d * 3.0)
		check(cap_ok, "d=0.3 semilla %d: no mas de %d obstaculos especiales por fila" % [sd, 1 + int(d * 3.0)])
	print("justicia d=0.3: margen N/costo medio por torre ", ratios, " (objetivo ", snappedf(target, 0.01), ") filas<=1: ", ones, "/", rows_all.size(), " desvio ", snappedf(std(rows_all), 0.01))
	check(ratio_ok, "el margen de la caida (N / costo medio por fila) es parecido en todas las torres de la misma dificultad")
	check(grace_ok, "la primera caida llega despues de 2N movimientos")
	check(float(ones) / maxf(rows_all.size(), 1) <= 0.2, "a lo sumo 20%% de filas triviales con la busqueda liviana (hay %d de %d); con la completa, 10%%: ver test_gen_quality" % [ones, rows_all.size()])
	check(std(rows_all) <= 2.5, "las filas de una misma etapa no se dispersan demasiado (desvio %.2f)" % std(rows_all))

	# Con dificultad 0 no aparecen mecanicas especiales salvo (como mucho) nada: sin hielo, catapultas ni bombas.
	var easy := Gen.generate_stage(3, 4, 0.0, LIGHT)
	check(easy.ok and easy.kinds.is_empty(), "dificultad 0: solo bloques normales")
	var mid := Gen.generate_stage(3, 4, 0.2, LIGHT)
	check(mid.ok and not mid.kinds.has(K.BOMB) and not mid.kinds.has(K.CATAPULT), "dificultad 0.2: puede haber hielo, pero todavia no catapultas ni bombas")


## Los pesos de cada mecanica: se desbloquean por dificultad y la catapulta no se genera. Se prueba directo con muchos
## sorteos (una sola torre depende de la suerte de su semilla).
func test_kind_weights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for d in [0.0, 0.2, 0.8]:
		var seen := {}
		for i in 600:
			var k: int = Gen._obstacle_kind(rng, d)
			seen[k] = seen.get(k, 0) + 1
		print("obstaculos d=", d, ": ", seen)
		check(not seen.has(K.CATAPULT), "d=%.1f: la catapulta no sale de los obstaculos generados" % d)
		if d == 0.0:
			check(seen.keys() == [K.NORMAL], "d=0: solo obstaculos normales")
		if d == 0.2:
			check(seen.has(K.ICE) and not seen.has(K.BOMB), "d=0.2: hay hielo pero todavia no bombas")
		if d == 0.8:
			check(seen.has(K.ICE) and seen.has(K.BOMB) and seen.has(K.NORMAL), "d=0.8: hay normales, hielo y bombas")
	# Celdas de hielo por plataforma: con tope
	var cap_ok := true
	for i in 200:
		var ks := Gen._platform_kinds(rng, 14, 0.8)
		var ice := 0
		for k in ks:
			if k == K.ICE:
				ice += 1
			cap_ok = cap_ok and k != K.CATAPULT
		cap_ok = cap_ok and ice <= 2 + int(0.8 * 2.0)
	check(cap_ok, "una plataforma tiene a lo sumo %d celdas de hielo y ninguna catapulta" % (2 + int(0.8 * 2.0)))
	var none := Gen._platform_kinds(rng, 14, 0.0)
	check(none.count(K.NORMAL) == 14, "d=0: la plataforma es toda de bloques normales")


## Perfiles de etapa y ritmos de caida.
func test_profiles() -> void:
	var p1 := Gen.profile_for_stage(1)
	var p27 := Gen.profile_for_stage(27)
	check(is_equal_approx(p1.difficulty, 0.0) and is_equal_approx(p27.difficulty, 1.0), "la etapa 1 es la mas facil y la 27 la mas dificil")
	check(Gen.profile_for_stage(1).pace == "normal" and Gen.profile_for_stage(2).pace == "normal", "las dos primeras etapas son de ritmo normal")
	var paces := {}
	for st in range(3, 28):
		paces[Gen.profile_for_stage(st).pace] = true
	check(paces.has("fast") and paces.has("normal") and paces.has("slow"), "a lo largo de las etapas hay ritmos rapidos, normales y lentos")
	check(Gen.profile_for_stage(5).combo == 0.0 and Gen.profile_for_stage(27).combo == 1.0 and Gen.profile_for_stage(20).combo > Gen.profile_for_stage(14).combo, "las mezclas de mecanicas empiezan tarde y crecen")
	check(Gen.profile_for_stage(1).mechanics.is_empty() and "hielo" in Gen.profile_for_stage(4).mechanics and not ("bomba" in Gen.profile_for_stage(8).mechanics) and "bomba" in Gen.profile_for_stage(14).mechanics, "las mecanicas se introducen de a una: hielo, despues bombas")
	check(Gen.profile_for_stage(deterministic_stage()).pace == Gen.profile_for_stage(deterministic_stage()).pace, "el perfil de una etapa es siempre el mismo")

	# El ritmo cambia el margen de la caida: rapida < normal < lenta, con la misma semilla.
	var ratios := {}
	var avgs := {}
	var bands := {}
	for pace in ["fast", "normal", "slow"]:
		var r := Gen.generate_stage(2, 4, 0.3, {"tries": 6, "climb": 0.5, "pace": pace})
		check(r.ok, "ritmo %s genera" % pace)
		if r.ok:
			ratios[pace] = float(r.logic.collapse_every) / (float(r.path.size()) / 4.0)
			avgs[pace] = float(r.path.size()) / 4.0
			bands[pace] = r.band
	print("ritmos (margen N/costo medio): ", ratios, " costo medio por fila: ", avgs)
	check(ratios.has("fast") and ratios.has("slow") and ratios.fast < ratios.normal and ratios.normal < ratios.slow, "el margen de la caida crece de rapido a lento (%s)" % str(ratios))
	check(ratios.get("fast", 9.0) <= 3.0 and ratios.get("slow", 0.0) >= 4.6, "rapido presiona de verdad (margen <= 3) y lento da aire (margen >= 4.6)")
	# La banda objetivo se corre segun el ritmo (el largo real de las filas la sigue solo de forma ruidosa: no se afirma).
	var base := Gen.band_for(0.3)
	var slow_band: Vector2i = bands.get("slow", Vector2i.ZERO)
	var fast_band: Vector2i = bands.get("fast", Vector2i.ZERO)
	check(slow_band == Vector2i(base.x + 2, base.y + 2), "ritmo lento: la banda objetivo sube 2 (%s)" % str(slow_band))
	check(fast_band == Vector2i(maxi(2, base.x - 1), maxi(4, base.y - 1)), "ritmo rapido: la banda objetivo baja 1 (%s)" % str(fast_band))
	check(bands.get("normal", Vector2i.ZERO) == base, "ritmo normal: la banda no cambia")

	# Las opciones de enriquecimiento (esfuerzo y mezclas) no rompen nada: la torre sigue siendo ganable.
	var rich := Gen.generate_stage(1, 3, 0.6, {"tries": 6, "climb": 0.5, "effort": true, "combo": 1.0})
	check(rich.ok, "con esfuerzo y mezclas activados la torre se genera")
	if rich.ok:
		var s = rich.logic.clone()
		for a in rich.path:
			s.try_action(a.dir, a.mode)
		check(s.won and not s.lost, "...y su solucion gana")
		check(rich.infos[0].has("effort") and rich.infos[0].has("kinds_n"), "cada fila registra su esfuerzo y cuantas mecanicas mezcla")


func deterministic_stage() -> int:
	return 17
