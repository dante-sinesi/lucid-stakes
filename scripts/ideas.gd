extends RefCounted
## Las "ideas" de las torres (ver docs/torres_ideas.md): cada una es una receta que CONSTRUYE a propósito una situación que pide una técnica, y después se verifica con el
## solucionador que la situación hace lo que promete. (Prototipo: por ahora una sola idea, la pared de pinchos, en un tramo de 4 pisos.)
##
## Pared de pinchos: la salida es una escalera de columnas cada vez más altas, y el primer escalón (el único que se trepa desde el piso) está encerrado por columnas de pinchos
## de 2 de alto: no se pueden trepar ni pisar. Hay que abrir un hueco empujando o tirando de las columnas (cada una se saca en dos empujones: primero cae su mitad de arriba).
## Los bloques señuelo (pesados, sueltos, pinchos sueltos) cambian qué columna se puede sacar y desde dónde.

const Gen := preload("res://scripts/tower_gen.gd")
const Solver := preload("res://scripts/solver.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const K := TowerLogic.Kind

const ROWS := 4                  # pisos del tramo
const START := Vector2i(2, 3)    # donde empieza el jugador (a la izquierda del núcleo)
const MIN_MOVES := 7             # rango de movimientos pedido
const MAX_MOVES := 22
const NAMES := {"pared_pinchos": "Pared de pinchos", "cruce_agrietado": "Cruce agrietado", "hielo_freno": "Hielo y freno"}
const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func names() -> Array:
	return NAMES.keys()


## Arma una instancia válida de la idea con la semilla (prueba candidatos hasta que uno cumple). Devuelve {ok, logic, path, rows, moves, spikes_moved, ascii, tries, ...}
## (el mismo formato que `TowerGen.generate_stage`, así el juego la usa igual) o {ok: false, error}.
static func make(idea: String, seed_value: int, max_tries := 300) -> Dictionary:
	if not NAMES.has(idea):
		return {"ok": false, "error": "idea desconocida: %s (ideas: %s)" % [idea, ", ".join(names())]}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var last := "ninguna"
	for i in max_tries:
		var cand := _candidate_wall(rng) if idea == "pared_pinchos" else _candidate_standalone(rng, idea)
		var ev := _evaluate(cand, idea)
		if ev.ok:
			ev["tries"] = i + 1
			ev["ascii"] = ascii_of(cand)
			ev["idea"] = idea
			return ev
		last = ev.error
		if OS.get_environment("IDEA_LOG") != "" and ev.error != "sin escalera":
			print("eval ", ev.error)
	return {"ok": false, "error": "ninguno de %d candidatos cumplió (último: %s)" % [max_tries, last]}


## Un candidato: {cols: {Vector2i: {h, kind}}, c1, goal} sobre la huella de 8 x 8 (el núcleo ocupa 3..4 x 3..4).
static func _candidate_wall(rng: RandomNumberGenerator) -> Dictionary:
	var cols := {}
	var c1 := Vector2i.ZERO
	var options: Array[Vector2i] = []
	for x in range(0, 3):
		for z in range(0, 6):
			var c := Vector2i(x, z)
			if absi(c.x - START.x) + absi(c.y - START.y) >= 3:
				options.append(c)
	c1 = options[rng.randi_range(0, options.size() - 1)]
	cols[c1] = {"h": 1, "kind": K.NORMAL}
	# la escalera: tres columnas más (alturas 2, 3 y 4), cada una pegada a la anterior
	var chain: Array[Vector2i] = [c1]
	for h in range(2, 5):
		var tries := 0
		var next := Vector2i(-9, -9)
		while tries < 30:
			tries += 1
			var from: Vector2i = chain[chain.size() - 1]
			var d := DIRS4[rng.randi_range(0, 3)]
			var c := from + d
			if _ok_cell(c) and not cols.has(c) and c != START:
				next = c
				break
		if next.x < 0:
			return {"cols": {}, "c1": c1}
		cols[next] = {"h": h, "kind": K.NORMAL}
		chain.append(next)
	# la pared: columnas de pinchos de 2 de alto en los vecinos del primer escalón que no son la escalera
	for d in DIRS4:
		var c := c1 + d
		if _ok_cell(c) and not cols.has(c) and c != START:
			cols[c] = {"h": 2, "kind": K.SPIKES}
	# señuelos
	var decoys := [[K.HEAVY, rng.randi_range(0, 2)], [K.NORMAL, rng.randi_range(0, 2)], [K.SPIKES, rng.randi_range(0, 1)]]
	for dc in decoys:
		for i in int(dc[1]):
			var c := Vector2i(rng.randi_range(0, 7), rng.randi_range(0, 7))
			if _ok_cell(c) and not cols.has(c) and c != START and (c - START).length() >= 1.5:
				cols[c] = {"h": rng.randi_range(1, 2) if dc[0] != K.NORMAL else 1, "kind": dc[0]}
	return {"cols": cols, "c1": c1, "goal": chain[chain.size() - 1]}


static func _ok_cell(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < 8 and c.y < 8 and not (c.x in [3, 4] and c.y in [3, 4])


static func _build(cand: Dictionary) -> Dictionary:
	var base: Dictionary = Gen._new_base(Gen.geometry(2), ROWS)
	var cells: Array = cand.cols.keys()
	cells.sort_custom(func(a, b): return a.y * 8 + a.x < b.y * 8 + b.x)   # (orden estable: así la misma semilla da siempre la misma torre)
	for c in cells:
		var col: Dictionary = cand.cols[c]
		for y in range(1, int(col.h) + 1):
			var kind := int(col.top) if (col.has("top") and y == int(col.h)) else int(col.kind)
			base.tower.add_block(Vector3i(c.x, y, c.y), false, kind, 0)
			base.sim.add_block(Vector3i(c.x, y, c.y), false, kind, 0)
	return base


## Resuelve el candidato y comprueba lo que promete la idea. Devuelve {ok, ...} con el resultado de generación, o {ok: false, error}.
static func _evaluate(cand: Dictionary, idea := "pared_pinchos") -> Dictionary:
	if cand.is_empty() or cand.cols.is_empty():
		return {"ok": false, "error": "sin escalera"}
	var base: Dictionary = _build(cand)
	var tower = base.tower
	var solved: Dictionary = Solver.solve(tower, ROWS + 1, {"max_states": 40000})
	if solved.status != "solved":
		return {"ok": false, "error": "no se resuelve (%s)" % solved.status}
	if solved.moves < MIN_MOVES or solved.moves > MAX_MOVES:
		return {"ok": false, "error": "%d movimientos, fuera del rango" % solved.moves}
	# lo que promete: hay que mover bloques (sin empujar ni tirar no se llega) y, al menos, un bloque de pinchos
	var no_grab: Dictionary = Solver.solve(tower, ROWS + 1, {"max_states": 40000, "no_grab": true})
	if no_grab.status == "solved":
		return {"ok": false, "error": "se resuelve sin mover bloques"}
	var path: Array = solved.path
	var spikes_moved := _uses_idea(idea, tower, path, 1, cand)
	if spikes_moved == 0:
		return {"ok": false, "error": "la solución no usa el bloque clave de la idea"}
	var sim = base.sim
	for a in path:
		sim.try_action(a.dir, a.mode)
	var res: Dictionary = Gen._close_tower(tower, sim, path.duplicate(), [path.size()], ["idea"], [], 0, [], {}, 0.3, Gen.PACES["normal"], Vector2i(3, 6), ROWS)
	if res.ok:
		res["moves"] = path.size()
		res["ms"] = 0
		Gen._arm(res.logic, Gen.BIG)   # (es una torre de prueba: la fila de abajo no cae)
		res["collapse_every"] = Gen.BIG
		res["spikes_moved"] = spikes_moved
	return res


## El esquema de una instancia: las 4 capas una al lado de la otra. . vacío, n bloque, H pesado, ^ pinchos, C núcleo, o donde empezás, G la meta (arriba de la última columna).
static func ascii_of(cand: Dictionary) -> String:
	var lines: Array[String] = []
	var head := ""
	for y in range(1, ROWS + 1):
		head += "capa %d    " % y
	lines.append(head)
	for z in 8:
		var line := ""
		for y in range(1, ROWS + 1):
			for x in 8:
				var c := Vector2i(x, z)
				var ch := "."
				if x in [3, 4] and z in [3, 4]:
					ch = "C"
				elif cand.cols.has(c) and int(cand.cols[c].h) >= y:
					match int(cand.cols[c].kind):
						K.SPIKES:
							ch = "^"
						K.HEAVY:
							ch = "H"
						K.CRACKED:
							ch = "x"
						K.ICE:
							ch = "i"
						_:
							ch = "n"
				elif y == 1 and c == START:
					ch = "o"
				if cand.has("goal") and c == cand.goal and y == ROWS:
					ch = "G"
				line += ch
			line += "  "
		lines.append(line)
	return "\n".join(lines)


# --- composición de una torre completa (reglas v0, ver docs/torres_ideas.md) ---------------------------------------------------------

const SLAB_CELLS := 3     # celdas que se suman a la última columna: la plataforma de salida (con ella son 4)
const PLACE_TRIES := 25
const PLACE_STATES := 1200   # tope del solucionador por candidato: si en contexto no lo resuelve rápido, se sortea otro


## Dónde van los tramos de idea en una torre de `rows` pisos de dificultad `difficulty`: {piso donde empieza: idea}. Reglas: de 2 (etapa 1) a 5 (etapa 15) tramos de
## 4 pisos; los dos primeros pisos son respiro; nunca dos seguidos (al menos un piso de respiro entre ellos).
## La idea del tramo que sigue: se sortea entre las que hay, sin repetir la del tramo anterior.
static func _pick_idea(rng: RandomNumberGenerator, so_far: Dictionary) -> String:
	var pool: Array = names()
	if OS.get_environment("IDEA_ONLY") != "":   # (desarrollo) todos los tramos de una sola idea
		return OS.get_environment("IDEA_ONLY")
	if not so_far.is_empty():
		var last_y: int = so_far.keys().max()
		pool.erase(so_far[last_y])
	return pool[rng.randi_range(0, pool.size() - 1)]


static func plan(rng: RandomNumberGenerator, rows: int, _difficulty: float) -> Dictionary:
	var count := (rows - 1) / ROWS   # tantos como entren, uno atrás del otro (el piso de uno es la plataforma de salida del anterior), hasta la cima
	while count > 0 and 1 + count * ROWS > rows:
		count -= 1
	var out := {}
	if count == 0:
		return out
	var gaps: Array[int] = [1]            # antes del primero, entre ideas (al menos 1: ahí hay piso para la siguiente) y después del último
	for i in count - 1:
		gaps.append(0)
	gaps.append(0)
	var left := rows - count * ROWS - 1   # pisos que sobran para repartir
	while left > 0:
		gaps[rng.randi_range(0, gaps.size() - 1)] += 1
		left -= 1
	var y := 1
	for i in count:
		y += gaps[i]
		out[y] = _pick_idea(rng, out)
		y += ROWS
	return out


## Pone un tramo de la idea sobre el estado de generación `st` (tower, sim, path, row_moves, shapes, infos, reserved) en el piso `ey`, donde el jugador está parado.
## Si encuentra una instancia que cumple (se resuelve en el rango, hay que mover bloques y la solución mueve pinchos) la agrega al estado y devuelve {ok: true, rows: 4}.
## `index` y `total` son el lugar de esta idea entre las de la torre: la dificultad pedida (rango de movimientos) sube de una a la siguiente.
static var stats := {"calls": 0, "ok": 0, "tries": 0, "ms": 0, "solves": 0}


static func place(st: Dictionary, ey: int, rng: RandomNumberGenerator, index: int, total: int, idea := "pared_pinchos") -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var res := _place(st, ey, rng, index, total, idea)
	if not res.ok:   # la idea sorteada no entra en este lugar: se prueba con las otras (un tramo de idea vale más que un piso común)
		var others: Array = names()
		others.erase(idea)
		while not res.ok and not others.is_empty():
			var other: String = others.pop_at(rng.randi_range(0, others.size() - 1))
			res = _place(st, ey, rng, index, total, other)
	if OS.get_environment("IDEA_LOG") != "":
		print("  place %s ey=%d idx=%d ok=%s %d ms (tries %d)" % [idea, ey, index, str(res.ok), Time.get_ticks_msec() - t0, stats.tries])
	stats.calls += 1
	stats.ms += Time.get_ticks_msec() - t0
	if res.ok:
		stats.ok += 1
	return res


static func _place(st: Dictionary, ey: int, rng: RandomNumberGenerator, index: int, total: int, idea: String) -> Dictionary:
	var sim = st.sim
	if sim.player.y != ey or sim.hang_dir != Vector3i.ZERO or sim.lost:
		return {"ok": false}
	var arrival := Vector2i(sim.player.x, sim.player.z)
	# el tramo de una idea tiene su propio piso: se completa la capa donde está parado el jugador con todo lo que esté libre (como el piso de prueba de una sola idea). Si el tramo no
	# sale, el piso no queda: se trabaja sobre una copia del estado.
	var full := st.duplicate()
	full.tower = st.tower.clone()
	full.sim = st.sim.clone()
	for x in 8:
		for z in 8:
			var cell := Vector3i(x, ey - 1, z)
			if _ok_cell(Vector2i(x, z)) and not full.tower.blocks.has(cell) and not full.sim.blocks.has(cell) and not st.reserved.has(cell):
				full.tower.add_block(cell, false, K.NORMAL, 0)
				full.sim.add_block(cell, false, K.NORMAL, 0)
	sim = full.sim
	var floor_cells: Array[Vector2i] = []
	for x in 8:
		for z in 8:
			var c := Vector2i(x, z)
			if _ok_cell(c) and sim.blocks.has(Vector3i(x, ey - 1, z)) and not sim.blocks.has(Vector3i(x, ey, z)):
				floor_cells.append(c)
	if OS.get_environment("IDEA_LOG") != "":
		print("  piso de %s: %d celdas" % [idea, floor_cells.size()])
	var lo := MIN_MOVES + 2 * index
	var hi := lo + 16 + (total - 1 - index)
	for i in PLACE_TRIES:
		var cand := _candidate_in_context(rng, arrival, floor_cells, full, ey, idea)
		if cand.is_empty():
			continue
		stats.tries += 1
		if OS.get_environment("IDEA_LOG") != "":
			print("   try ", i, " ", Time.get_ticks_msec())
		var done := _try_commit(full, cand, ey, lo, hi, idea)
		if done.ok:
			st.tower = full.tower
			st.sim = full.sim
			return done
	return {"ok": false}


## ¿La solución usa lo que promete la idea? Devuelve cuántos bloques clave movió o gastó (0 = no la usa). Pinchos y cruce: el bloque protagonista cambió de lugar o se rompió.
## Hielo y freno: se movió el freno (el bloque normal arriba del hielo) y hubo al menos un deslizamiento (un movimiento que recorre 2 celdas o más).
static func _uses_idea(idea: String, lg, path: Array, ey: int, cand: Dictionary) -> int:
	var start := {}
	if idea == "hielo_freno":
		var id: int = lg.blocks.get(Vector3i(cand.brake.x, ey + 1, cand.brake.y), -1)
		if id >= 0:
			start[id] = lg.positions[id]
	else:
		for id in lg.kind_of:
			if lg.kind_of[id] == _key_kind(idea):
				start[id] = lg.positions[id]
	var replay = lg.clone()
	var slides := 0
	for a in path:
		var before: Vector3i = replay.player
		replay.try_action(a.dir, a.mode)
		if absi(replay.player.x - before.x) + absi(replay.player.z - before.z) >= 2:
			slides += 1
	var moved := 0
	for id in start:
		if replay.positions.get(id) != start[id]:
			moved += 1
	if idea == "hielo_freno" and slides == 0:
		return 0
	return moved


## El tipo de bloque que protagoniza cada idea: la solución tiene que moverlo (o gastarlo).
static func _key_kind(idea: String) -> int:
	return K.CRACKED if idea == "cruce_agrietado" else K.SPIKES


## Candidato de una idea sobre el piso de prueba de una sola idea (todas las celdas son piso, el jugador empieza en START).
static func _candidate_standalone(rng: RandomNumberGenerator, idea: String) -> Dictionary:
	var cells: Array[Vector2i] = []
	for x in 8:
		for z in 8:
			if _ok_cell(Vector2i(x, z)):
				cells.append(Vector2i(x, z))
	return _candidate_in_context(rng, START, cells, {}, 1, idea)


static func _layer_free(st: Dictionary, c: Vector2i, y0: int, y1: int) -> bool:
	if st.is_empty():
		return true
	for y in range(y0, y1 + 1):
		var cell := Vector3i(c.x, y, c.y)
		if st.tower.blocks.has(cell) or st.sim.blocks.has(cell) or st.reserved.has(cell):
			return false
	return true


## Un candidato en contexto: columnas {Vector2i: {h, kind}} (la escalera de 4, la pared y los señuelos) y la plataforma de salida, sobre el piso que hay en `ey`.
static func _candidate_in_context(rng: RandomNumberGenerator, arrival: Vector2i, floor_cells: Array[Vector2i], st: Dictionary, ey: int, idea := "pared_pinchos") -> Dictionary:
	if idea == "hielo_freno":
		return _candidate_ice(rng, arrival, floor_cells, st, ey)
	var options: Array[Vector2i] = []
	for c in floor_cells:
		if absi(c.x - arrival.x) + absi(c.y - arrival.y) >= 3 and _layer_free(st, c, ey, ey + 1):
			options.append(c)
	if options.is_empty():
		return {}
	var c1: Vector2i = options[rng.randi_range(0, options.size() - 1)]
	var cols := {c1: {"h": 1, "kind": K.NORMAL}}
	var chain: Array[Vector2i] = [c1]
	for h in range(2, 5):
		var next := Vector2i(-9, -9)
		for t in 30:
			var d := DIRS4[rng.randi_range(0, 3)]
			var c: Vector2i = chain[chain.size() - 1] + d
			if _ok_cell(c) and not cols.has(c) and c != arrival and _layer_free(st, c, ey, ey + h - 1):
				next = c
				break
		if next.x < 0:
			return {}
		cols[next] = {"h": h, "kind": K.NORMAL}
		chain.append(next)
	var decoys := []
	if idea == "cruce_agrietado":
		# la isla: pesados de 2 de alto (no se trepan ni se mueven) alrededor de toda la escalera, y un solo escalón agrietado suelto, lejos de la pared
		var ring: Array[Vector2i] = []
		for cc in chain:
			for d in DIRS4:
				var n: Vector2i = cc + d
				if _ok_cell(n) and not cols.has(n) and n != arrival and floor_cells.has(n) and not ring.has(n) and _layer_free(st, n, ey, ey + 1):
					ring.append(n)
		if ring.is_empty():
			return {}
		for n in ring:
			cols[n] = {"h": 2, "kind": K.HEAVY}
		var step_cells: Array[Vector2i] = []
		for c in floor_cells:
			if cols.has(c) or c == arrival or not _layer_free(st, c, ey, ey):
				continue
			var near := 99
			for n in ring:
				near = mini(near, absi(c.x - n.x) + absi(c.y - n.y))
			if near >= 2:
				step_cells.append(c)
		if step_cells.is_empty():
			return {}
		cols[step_cells[rng.randi_range(0, step_cells.size() - 1)]] = {"h": 1, "kind": K.CRACKED}
		decoys = [[K.HEAVY, rng.randi_range(0, 2)]]
	else:
		for d in DIRS4:   # la pared: pinchos de 2 de alto en los vecinos del primer escalón que son piso (los que no, ya son vacío)
			var c := c1 + d
			if _ok_cell(c) and not cols.has(c) and c != arrival and floor_cells.has(c) and _layer_free(st, c, ey, ey + 1):
				cols[c] = {"h": 2, "kind": K.SPIKES}
		decoys = [[K.HEAVY, rng.randi_range(0, 2)], [K.NORMAL, rng.randi_range(0, 2)], [K.SPIKES, rng.randi_range(0, 1)]]
	for dc in decoys:
		for i in int(dc[1]):
			if floor_cells.is_empty():
				break
			var c: Vector2i = floor_cells[rng.randi_range(0, floor_cells.size() - 1)]
			if not cols.has(c) and c != arrival and (c - arrival).length() >= 1.5 and _layer_free(st, c, ey, ey + 1):
				cols[c] = {"h": rng.randi_range(1, 2) if dc[0] != K.NORMAL else 1, "kind": dc[0]}
	# la plataforma de salida: celdas pegadas a la última columna, a la altura de su tope
	var goal: Vector2i = chain[chain.size() - 1]
	var slab: Array[Vector2i] = []
	var around: Array[Vector2i] = []
	for d in DIRS4:
		var c := goal + d
		if _ok_cell(c) and not cols.has(c) and _layer_free(st, c, ey + 3, ey + 3):
			around.append(c)
	if around.is_empty():
		return {}
	while slab.size() < SLAB_CELLS and not around.is_empty():
		slab.append(around.pop_at(rng.randi_range(0, around.size() - 1)))
	return {"cols": cols, "c1": c1, "goal": goal, "slab": slab}


## Hielo y freno: un pasillo de hielo (5 o 6 celdas) entre paredes pesadas; al pisarlo resbalás hasta chocar. La salida es una escalera cuyo primer escalón (2 de alto) sólo se alcanza
## desde una celda del pasillo, la `k`. Hay un bloque (el freno) arriba de la segunda celda: se empuja hacia adelante y hace que frenes justo antes de él. El final del pasillo es pared.
static func _candidate_ice(rng: RandomNumberGenerator, arrival: Vector2i, floor_cells: Array[Vector2i], st: Dictionary, ey: int) -> Dictionary:
	if floor_cells.is_empty():
		return _e(1)
	var d := DIRS4[rng.randi_range(0, 3)]
	var perp := Vector2i(-d.y, d.x)
	var length := rng.randi_range(5, 6)
	var s0: Vector2i = floor_cells[rng.randi_range(0, floor_cells.size() - 1)]
	var entry := s0 - d
	if not (floor_cells.has(entry) or entry == arrival):
		return _e(2)
	var lane: Array[Vector2i] = []
	for i in length:
		var c := s0 + d * i
		if not (_ok_cell(c) and floor_cells.has(c) and c != arrival and _layer_free(st, c, ey, ey + 1)):
			return _e(3)
		lane.append(c)
	var cols := {}
	for c in lane:
		cols[c] = {"h": 1, "kind": K.ICE}
	cols[lane[1]] = {"h": 2, "kind": K.ICE, "top": K.NORMAL}
	var k := rng.randi_range(3, length - 2)   # (con k = 2 se llega sin mover nada: resbalando desde el final contra el freno)
	var c1: Vector2i = lane[k] + perp * (1 if rng.randf() < 0.5 else -1)
	var side := {}   # las celdas de al lado del pasillo: paredes (salvo la de la escalera)
	for c in lane:
		side[c + perp] = true
		side[c - perp] = true
	side.erase(c1)
	if not _ok_cell(c1) or cols.has(c1) or c1 == arrival or c1 == entry or not _layer_free(st, c1, ey, ey + 3):
		return _e(4)
	cols[c1] = {"h": 2, "kind": K.NORMAL}
	var chain: Array[Vector2i] = [c1]
	for h in range(3, 5):
		var next := Vector2i(-9, -9)
		for t in 30:
			var n: Vector2i = chain[chain.size() - 1] + DIRS4[rng.randi_range(0, 3)]
			if _ok_cell(n) and not cols.has(n) and not side.has(n) and n != arrival and n != entry and _layer_free(st, n, ey, ey + h - 1):
				next = n
				break
		if next.x < 0:
			return _e(5)
		cols[next] = {"h": h, "kind": K.NORMAL}
		chain.append(next)
	var walls := {}   # celda -> alto. Las del pasillo son de 4: si no, parado encima del freno (un piso más arriba) se camina por encima de las paredes de 2 y se esquiva el pasillo
	for n in side:
		walls[n] = 4
	walls[lane[length - 1] + d] = 4
	for cc in chain:
		for dd in DIRS4:
			if not walls.has(cc + dd):
				walls[cc + dd] = 2
	for n in walls:
		if cols.has(n) or not _ok_cell(n) or not floor_cells.has(n):
			continue   # (lo que no es piso ya es vacío)
		if n == arrival or n == entry or not _layer_free(st, n, ey, ey + int(walls[n]) - 1):
			return _e(6)
		cols[n] = {"h": int(walls[n]), "kind": K.HEAVY}
	var goal: Vector2i = chain[chain.size() - 1]
	var slab := _slab_around(rng, goal, cols, st, ey, false)
	if slab.is_empty():
		return _e(7)
	return {"cols": cols, "c1": c1, "goal": goal, "slab": slab, "brake": lane[1]}


static func _slab_around(rng: RandomNumberGenerator, goal: Vector2i, cols: Dictionary, st: Dictionary, ey: int, strict := true) -> Array[Vector2i]:
	var slab: Array[Vector2i] = []
	var around: Array[Vector2i] = []
	for d in DIRS4:
		var c := goal + d
		var taken: bool = cols.has(c) and (strict or int(cols[c].h) >= 4 or (int(cols[c].h) >= 3 and int(cols[c].kind) == K.NORMAL))   # (si no es estricto, la plataforma de salida puede quedar sobre una pared baja: está tres pisos arriba)
		if _ok_cell(c) and not taken and _layer_free(st, c, ey + 3, ey + 3):
			around.append(c)
	while slab.size() < SLAB_CELLS and not around.is_empty():
		slab.append(around.pop_at(rng.randi_range(0, around.size() - 1)))
	return slab


## Prueba el candidato sobre el estado: lo resuelve en una ventana (sólo las capas que importan), comprueba lo que promete la idea y, si cumple, lo agrega al estado.
static func _try_commit(st: Dictionary, cand: Dictionary, ey: int, lo: int, hi: int, idea: String) -> Dictionary:
	var blocks: Array = []   # la plataforma de salida primero (así sus ids son los primeros)
	blocks.append({"c": Vector3i(cand.goal.x, ey + 3, cand.goal.y), "kind": K.NORMAL, "timer": 0, "plat": 1})
	for c in cand.slab:
		blocks.append({"c": Vector3i(c.x, ey + 3, c.y), "kind": K.NORMAL, "timer": 0, "plat": 1})
	var cells: Array = cand.cols.keys()
	cells.sort_custom(func(a, b): return a.y * 8 + a.x < b.y * 8 + b.x)
	for c in cells:
		var col: Dictionary = cand.cols[c]
		for y in range(0, int(col.h)):
			if c == cand.goal and y == 3:
				continue   # (el tope de la última columna es la plataforma)
			var kind := int(col.top) if (col.has("top") and y == int(col.h) - 1) else int(col.kind)
			blocks.append({"c": Vector3i(c.x, ey + y, c.y), "kind": kind, "timer": 0, "plat": 0})
	var trial = st.sim.clone()
	var base_id: int = trial._next_id
	for b in blocks:
		trial.add_block(b.c, false, b.kind, b.timer)
	var win = Gen._window(trial, ey, {base_id: true}, ey + 3)
	win.goal_y = ey + 4
	var solved: Dictionary = Solver.solve(win, ey + 4, {"max_states": PLACE_STATES, "goal_ids": win.goal_ids})
	if OS.get_environment("IDEA_LOG") != "":
		print("    solved ", solved.status, " ", solved.get("moves", -1), " ", Time.get_ticks_msec())
	if solved.status != "solved" or solved.moves < lo or solved.moves > hi:
		return _no(1)
	if Solver.solve(win, ey + 4, {"max_states": PLACE_STATES, "goal_ids": win.goal_ids, "no_grab": true}).status == "solved":
		return _no(2)
	var moved := _uses_idea(idea, win, solved.path, ey, cand)
	if moved == 0:
		return _no(3)
	# se agrega al estado y se comprueba que todo el camino (el anterior y el de la sección) siga llegando
	var tower = st.tower.clone()
	tower.row_platforms = tower.row_platforms.duplicate()
	tower.platform_row = tower.platform_row.duplicate()
	var sim = st.sim.clone()
	var plat_ids: Array = []
	for b in blocks:
		tower.add_block(b.c, false, b.kind, b.timer)
		sim.add_block(b.c, false, b.kind, b.timer)
		if b.plat == 1:
			plat_ids.append(tower.blocks[b.c])
	var per_row: Array[int] = [0, 0, 0, 0]   # movimientos por piso: los pasos hasta que el jugador sube a cada altura
	var reached := 0
	for a in solved.path:
		if not sim.try_action(a.dir, a.mode).ok or sim.lost:
			return _no(4)
		reached = maxi(reached, clampi(sim.player.y - ey - 1, 0, 3))
		per_row[reached] += 1
	if sim.player.y != ey + 4 or not plat_ids.has(sim.blocks.get(sim.player + Vector3i.DOWN, -2)):
		return _no(5)
	var chk = tower.clone()
	chk.goal_y = Gen.BIG
	for a in st.path:
		if not chk.try_action(a.dir, a.mode).ok or chk.lost:
			return _no(6)
	for a in solved.path:
		if not chk.try_action(a.dir, a.mode).ok or chk.lost:
			return _no(7)
	if chk.player != sim.player:
		return _no(8)
	tower.row_platforms[ey + 3] = plat_ids
	for id in plat_ids:
		tower.platform_row[id] = ey + 3
	var walk = tower.clone()   # las celdas del camino quedan reservadas, como en las filas comunes: ninguna fila siguiente las puede tapar
	for a in st.path:
		walk.try_action(a.dir, a.mode)
		for c in walk.trail:
			st.reserved[c] = true
			st.reserved[c + Vector3i(0, 1, 0)] = true
	for a in solved.path:
		walk.try_action(a.dir, a.mode)
		for c in walk.trail:
			st.reserved[c] = true
			st.reserved[c + Vector3i(0, 1, 0)] = true
	st.tower = tower
	st.sim = sim
	st.path.append_array(solved.path)
	for r in 4:
		st.row_moves.append(per_row[r])
		st.shapes.append("idea")
		st.infos.append({"featured": _key_kind(idea), "matters": true, "needs_grab": true, "effort": solved.states, "kinds_n": 1})
	return {"ok": true, "rows": 4, "moves": solved.path.size(), "spikes_moved": moved}


static func _no(code: int) -> Dictionary:
	if OS.get_environment("IDEA_LOG") != "":
		print("     rechazo ", code)
	return {"ok": false}


static func _e(code: int) -> Dictionary:
	if OS.get_environment("IDEA_LOG") != "":
		print("ice rechazo ", code)
	return {}
