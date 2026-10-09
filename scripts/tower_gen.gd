extends RefCounted
## Generador de etapas v3: core fijo + plataformas variadas + tipos de bloque. Ver docs/diseno.md.
##
## Estructura: un core fijo de core x core (2x2 por defecto) en el centro de una huella de
## (core + 6) x (core + 6): 3 cubos de espesor hacia todos los lados. Capa 0 = base completa;
## el core llega hasta una capa por encima de la meta.
## Fila y = puzzle de la capa y: el jugador está en el nivel y (parado sobre la capa y-1) y
## tiene que llegar al nivel y+1 trepando a un bloque de la capa y.
##  - Plataforma A_y: bloques de la capa y, con forma variada (mancha, barra, L, arco que sigue
##    al core). Sus celdas pueden ser de hielo o catapulta; es el piso de la fila siguiente.
##  - Obstáculos: bloques sueltos sobre el piso libre (normales, de hielo, bombas, catapultas;
##    a veces pilares de 2), concentrados en los accesos a la plataforma.
## Cada candidato se valida con el solucionador (ventana de capas) y se acepta si su mínimo
## cae en la banda objetivo. Se avanza fila a fila sobre una copia que ejecuta el camino
## óptimo; todo lo que pisa el jugador (rastro, con deslizamientos y saltos) y la celda de
## arriba quedan reservados en 3D para que nada posterior invalide la solución. Al final se
## reproduce todo el camino con la caída de la fila base activa; si falla, se reintenta con
## otra semilla derivada.
##
## Justicia de la dificultad (se ajustó con mediciones sobre torres reales):
##  - N (cada cuántos movimientos cae la fila base) = margen constante sobre el costo medio de una fila
##    (ratio 4.5 en dificultad 0, 2.6 en dificultad 1) y nunca menos que 1.6 veces el mínimo que exige
##    el propio camino. Así dos torres de la misma dificultad presionan igual, en vez de depender del peor
##    momento de cada una. La primera caída llega después de 2N movimientos (tiempo para explorar).
##  - Ninguna fila se resuelve en menos de 2 movimientos ni muy por debajo de la banda objetivo, ni en más de
##    banda + 4 (una fila mucho más larga que el resto es injusta).
##  - Las filas EXIGEN mover bloques (empujar o tirar): una fila "exige" mover bloques si, prohibiendo empujar y tirar,
##    no tiene solución o cuesta al menos 2 movimientos más. La mayoría de las filas lo exigen (60 % en dificultad 0,
##    hasta 100 % desde 0,5): sin eso, bastaba caminar y se podía pasar una torre casi sin tocar un bloque.
##  - Las mecánicas se introducen de a una: hielo desde 0.05, bomba desde 0.4 (la catapulta no se genera: ver CATAPULTS_IN_TOWERS),
##    con un tope de bloques especiales por fila.

const TowerLogic := preload("res://scripts/tower_logic.gd")
const Solver := preload("res://scripts/solver.gd")
const Loc := preload("res://scripts/loc.gd")
const K := TowerLogic.Kind

## Pone en true para abortar una generación en curso (la lee el hilo que genera; el juego lo usa al volver al menú).
static var cancel := false


## ¿Hay que abortar? Con la bandera global (`cancel`) o con el testigo propio de un trabajo ([false] que se pone en [true]); así, cuando
## varias semillas se generan a la vez, la primera que sale puede frenar a las otras sin tocar los demás trabajos.
static func _stopped(token) -> bool:
	return cancel or (token is Array and bool(token[0]))

## Filas por tramo: la torre se genera de a tramos y cada uno se valida entero (ver _segment_defects).
const SEG_ROWS := 5
const SEG_TRIES := 4
const BIG := 1 << 30
const DIRS2: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const ATTEMPTS := 4
## Las catapultas no se generan en las torres por ahora: suben 4 en vertical y se agarran de un borde, y en una torre
## generada casi nunca hay una pared alta con el borde libre al lado, así que no aportan nada a la solución y
## encarecen mucho la búsqueda. El bloque sigue existiendo (reglas, solucionador, vista) para la tienda y los trucos.
const CATAPULTS_IN_TOWERS := false
## Probabilidad de que un obstáculo normal sea un pilar de 2. Un bloque suelto de una sola capa es un escalón
## más (se trepa y resuelve la fila); sólo un pilar es de verdad un obstáculo, porque no se puede trepar.
const PILLAR_CHANCE := 0.6
## Dificultad desde la que aparecen los bloques pesados (no se mueven) y los agrietados (se rompen al bajarte).
const HEAVY_FROM := 0.15
const CRACKED_FROM := 0.25
const TRAP_FROM := 0.3       # a partir de qué dificultad aparecen las trampas (celdas de plataforma que se desarman al pisarlas)
const SPIKES_FROM := 0.35    # y los pinchos (bloques que no se pueden pisar: en las plataformas y como obstáculos)


static func geometry(core_size: int) -> Dictionary:
	var foot := core_size + 6
	return {"foot": Vector2i(foot, foot), "core": Rect2i(3, 3, core_size, core_size),
			"center": Vector2(3.0 + core_size * 0.5, 3.0 + core_size * 0.5)}


static func in_envelope(c: Vector2i, geo: Dictionary) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < geo.foot.x and c.y < geo.foot.y and not geo.core.has_point(c)


static func touches_core(c: Vector2i, geo: Dictionary) -> bool:
	for d in DIRS2:
		if geo.core.has_point(c + d):
			return true
	return false


## Distancia (Chebyshev) de una celda al core: 1 = pegada, 3 = el borde de la huella.
static func ring_of(c: Vector2i, geo: Dictionary) -> int:
	var core: Rect2i = geo.core
	var dx := maxi(maxi(core.position.x - c.x, c.x - (core.end.x - 1)), 0)
	var dy := maxi(maxi(core.position.y - c.y, c.y - (core.end.y - 1)), 0)
	return maxi(dx, dy)


## Celdas del anillo r alrededor del core, en orden (cada una es vecina de la siguiente; es un ciclo).
static func ring_cycle(geo: Dictionary, r: int) -> Array[Vector2i]:
	var core: Rect2i = geo.core
	var x0 := core.position.x - r
	var y0 := core.position.y - r
	var x1 := core.end.x + r - 1
	var y1 := core.end.y + r - 1
	var cycle: Array[Vector2i] = []
	for x in range(x0, x1 + 1):
		cycle.append(Vector2i(x, y0))
	for y in range(y0 + 1, y1 + 1):
		cycle.append(Vector2i(x1, y))
	for x in range(x1 - 1, x0 - 1, -1):
		cycle.append(Vector2i(x, y1))
	for y in range(y1 - 1, y0, -1):
		cycle.append(Vector2i(x0, y))
	return cycle


## Ritmos de caída de la fila base. ratio multiplica el margen de la caída (N respecto del costo medio de una fila) y
## band_shift corre la banda objetivo de movimientos por fila: las etapas rápidas tienen filas más cortas y la
## fila de abajo cae más cerca; las lentas, filas más largas y más margen.
const PACES := {
	"fast": {"ratio": 0.55, "band_shift": -1},
	"normal": {"ratio": 1.0, "band_shift": 0},
	"slow": {"ratio": 1.25, "band_shift": 2},
}


## Perfil de una etapa (1..27): dificultad, ritmo de caída, probabilidad de combinar mecánicas en una fila y mecánicas
## activas. Las dos primeras etapas son de ritmo normal; después el ritmo cambia de una etapa a otra.
## `trial` y `scenario` (opcionales) son los de la etapa: pueden fijar el ritmo, subir la dificultad y sesgar los tipos de bloque.
static func profile_for_stage(stage: int, trial := {}, scenario := {}) -> Dictionary:
	var d := clampf(difficulty_for_stage(stage) + float(scenario.get("diff_offset", 0.0)), 0.0, 1.0)
	var pace := "normal"
	if stage >= 3:
		pace = ["normal", "fast", "slow"][(stage * 7 + stage / 3) % 3]
	for src in [scenario, trial]:   # el escenario y, encima, la prueba, pueden fijar el ritmo
		if str(src.get("pace", "")) != "":
			pace = src.pace
	var mechanics: Array[String] = []
	if d >= 0.05:
		mechanics.append("hielo")
	if d >= HEAVY_FROM:
		mechanics.append("pesado")
	if d >= CRACKED_FROM:
		mechanics.append("agrietado")
	if d >= 0.4:
		mechanics.append("bomba")
	if d >= TRAP_FROM:
		mechanics.append("trampa")
	if d >= SPIKES_FROM:
		mechanics.append("pinchos")
	var combo := 0.0 if d < 0.4 else clampf((d - 0.4) / 0.6, 0.0, 1.0)
	var bias := {"kinds": {}, "plat_ice": 0.0, "cap_bonus": 0}
	for src in [scenario.get("bias", {}), trial.get("bias", {})]:
		for k in src.get("kinds", {}):
			bias.kinds[k] = float(bias.kinds.get(k, 0.0)) + float(src.kinds[k])
		bias.plat_ice += float(src.get("plat_ice", 0.0))
		bias.cap_bonus += int(src.get("cap_bonus", 0))
	return {"stage": stage, "difficulty": d, "pace": pace, "combo": combo, "mechanics": mechanics, "bias": bias}


## Dificultad de una etapa (1..27) en 0..1.
static func difficulty_for_stage(stage: int) -> float:
	return clampf((stage - 1) / 26.0, 0.0, 1.0)


## Banda objetivo de movimientos mínimos por fila para una dificultad 0..1.
static func band_for(difficulty: float) -> Vector2i:
	var lo := 2 + int(round(difficulty * 8.0))
	return Vector2i(lo, lo + 2)


## opts: pace ("normal"|"fast"|"slow"), combo (0..1: probabilidad de preferir filas que mezclan mecánicas), effort (true: entre
## los candidatos válidos se prefiere el que más búsqueda le cuesta al solucionador, o sea más caminos tentadores sin salida),
## core (2), tries (10), max_states (8000), slack (1.6), climb (1.0: escala las iteraciones del ascenso por mutaciones;
## menos es más rápido y da filas menos afinadas a la banda), budget_states (0: trabajo total —estados que explora el solucionador— que se gasta en afinar las filas; pasado
## ese tope cada fila se queda con lo mejor que tiene. Se mide en trabajo y no en milisegundos para que la misma semilla dé siempre la misma torre).
## Devuelve {ok, logic, rows, path, shapes, kinds, n_min, collapse_every, states, ms, band, attempts}.
static func generate_stage(seed_value: int, rows: int, difficulty: float, opts: Dictionary = {}) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var last_error := ""
	for a in ATTEMPTS:
		if _stopped(opts.get("cancel_token", null)):
			break
		var res := _generate_once(seed_value + a * 100003, rows, difficulty, opts)
		if res.ok:
			res["attempts"] = a + 1
			res["ms"] = Time.get_ticks_msec() - t0
			return res
		last_error = res.error
	return {"ok": false, "error": last_error}


static func _generate_once(seed_value: int, rows: int, difficulty: float, opts: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var token = opts.get("cancel_token", null)
	if token != null:
		rng.set_meta("cancel", token)
	rng.set_meta("bias", opts.get("bias", {}))   # sesgo de los escenarios y pruebas (ver _bias); va en el rng para no usar estado global entre hilos
	var geo := geometry(opts.get("core", 2))
	var tries: int = opts.get("tries", 10)
	var max_states: int = opts.get("max_states", 8000)
	var slack: float = opts.get("slack", 1.6)
	var climb: float = opts.get("climb", 1.0)
	var pace: Dictionary = PACES[opts.get("pace", "normal")]
	var combo: float = opts.get("combo", 0.0)
	var use_effort: bool = opts.get("effort", true)
	var band := band_for(difficulty)
	band = Vector2i(maxi(2, band.x + pace.band_shift), maxi(4, band.y + pace.band_shift))  # el ritmo corre la banda
	# La fila se resuelve al llegar a su plataforma, así que el costo medido incluye caminar hasta ella (~1 movimiento más):
	# la banda de búsqueda se corre 1 para que el esfuerzo percibido no cambie y la búsqueda no sea más profunda de lo necesario.
	var row_band := Vector2i(maxi(2, band.x - 1), maxi(4, band.y - 1))

	var tower := TowerLogic.new()
	tower.size = geo.foot
	tower.collapse_every = BIG
	tower.moves_to_collapse = BIG
	for z in geo.foot.y:
		for x in geo.foot.x:
			tower.add_block(Vector3i(x, 0, z), geo.core.has_point(Vector2i(x, z)))
	for y in range(1, rows + 2):
		for z in range(geo.core.position.y, geo.core.end.y):
			for x in range(geo.core.position.x, geo.core.end.x):
				tower.add_block(Vector3i(x, y, z), true)
	tower.goal_y = rows + 1
	var start := Vector2i(geo.core.position.x - 1, geo.core.position.y)
	tower.player = Vector3i(start.x, 1, start.y)

	# Estado de la generación: se guarda en un diccionario para poder volver al inicio de un tramo y rehacerlo.
	# Durante la generación la simulación no gana por llegar alto: un camino puede pasar por encima de la altura final
	# (por escalones sobrantes) y volver a bajar a la plataforma de su fila.
	var sim0 = tower.clone()
	sim0.goal_y = BIG
	var st := {"tower": tower, "sim": sim0, "path": [], "row_moves": [] as Array[int], "shapes": [] as Array[String],
			"infos": [], "reserved": {Vector3i(start.x, 1, start.y): true}, "states": 0}
	var row_budget: int = int(opts.get("budget_states", 0)) / maxi(rows, 1)  # trabajo de afinado por fila (0 = sin tope)
	var seg_len: int = opts.get("seg", SEG_ROWS)
	var seg_tries: int = opts.get("seg_tries", SEG_TRIES)
	var segments: Array = []   # por tramo: filas, intentos y defectos del que quedó
	var y := 1
	while y <= rows:
		if _stopped(token):
			return {"ok": false, "error": "cancelado"}
		var y_end := mini(y + seg_len - 1, rows)
		var start_state := _snapshot(st)
		var best := {}
		var best_defects := 1 << 30
		var used := 0
		var last_err := ""
		for att in seg_tries:
			used += 1
			if att > 0:
				st = _snapshot(start_state)
			# En los reintentos se pide mover bloques con menos frecuencia: las compuertas son lo que más escalones regala.
			var grab_scale := 1.0 - 0.3 * att
			var failed := false
			for yy in range(y, y_end + 1):
				var shapes_now: Array = st.shapes
				var row := _make_row(st.tower, st.sim, yy, rng, row_band, difficulty, tries, max_states, geo, st.reserved,
						shapes_now[shapes_now.size() - 1] if not shapes_now.is_empty() else "", climb, combo, use_effort, st.path, grab_scale, row_budget)
				if row.has("fail"):
					failed = true
					last_err = "no se pudo generar la fila %d (%s)" % [yy, row.fail]
					break
				st.sim = row.sim
				for c in row.reserve:
					st.reserved[c] = true
				st.path.append_array(row.path)
				st.row_moves.append(row.moves)
				st.shapes.append(row.shape)
				st.infos.append(row.info)
				st.states += row.states
			var defects := (1 << 29) if failed else _segment_defects(st, y, y_end, rows, seg_len)
			if defects < best_defects:
				best_defects = defects
				best = _snapshot(st) if not failed else {}
			if defects == 0:
				break
		if best.is_empty():
			return {"ok": false, "error": last_err}
		st = best
		segments.append({"from": y, "to": y_end, "attempts": used, "defects": best_defects})
		y = y_end + 1
	tower = st.tower
	var sim = st.sim
	var path: Array = st.path
	var row_moves: Array[int] = st.row_moves
	var shapes: Array[String] = st.shapes
	var infos: Array = st.infos
	var states: int = st.states
	# El portal exige estar PARADO sobre un bloque: si la última fila termina colgado del borde, se suma el paso de trepar.
	if not sim.blocks.has(sim.player + Vector3i.DOWN) and sim.hang_dir != Vector3i.ZERO:
		for d in [sim.hang_dir, Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var c = sim.clone()
			if c.try_action(d, TowerLogic.Mode.MOVE).ok and c.blocks.has(c.player + Vector3i.DOWN):
				sim = c
				path.append({"dir": d, "mode": TowerLogic.Mode.MOVE})
				row_moves[row_moves.size() - 1] += 1
				break
	tower.goal_cell = sim.player
	tower.goal_block = sim.blocks.get(sim.player + Vector3i.DOWN, -1)  # el portal: el bloque donde termina el camino (puede haberse movido; el id es el mismo en la torre inicial)

	if not _replay_wins(tower, path, BIG):
		return {"ok": false, "error": "el camino completo no gana sobre la torre final",
				"debug": {"tower": tower, "path": path, "rows": row_moves, "infos": infos}}
	var n_min := min_collapse_every(tower, path)
	var avg_row := float(path.size()) / rows
	var ratio: float = opts.get("ratio", maxf(1.8, lerpf(4.5, 2.6, difficulty) * pace.ratio))
	var n := maxi(maxi(3, ceili(avg_row * ratio)), ceili(n_min * slack))
	while not _replay_wins(tower, path, n):
		n += 1
	_arm(tower, n)

	var kinds := {}
	for id in tower.kind_of:
		kinds[tower.kind_of[id]] = kinds.get(tower.kind_of[id], 0) + 1
	return {"ok": true, "logic": tower, "rows": row_moves, "path": path, "shapes": shapes,
			"kinds": kinds, "infos": infos, "segments": segments, "grab_rows": _count_grab(infos), "n_min": n_min, "collapse_every": n, "states": states, "band": band}


## Copia independiente del estado de generación (la torre, la simulación y todo lo acumulado hasta ahora).
static func _snapshot(st: Dictionary) -> Dictionary:
	var t = st.tower.clone()
	t.row_platforms = t.row_platforms.duplicate()   # la torre los va llenando fila a fila: la copia no puede compartirlos
	t.platform_row = t.platform_row.duplicate()
	return {"tower": t, "sim": st.sim.clone(), "path": st.path.duplicate(), "row_moves": st.row_moves.duplicate(),
			"shapes": st.shapes.duplicate(), "infos": st.infos.duplicate(), "reserved": st.reserved.duplicate(), "states": st.states}


## Defectos de un tramo recién generado (0 = válido):
##  - cada fila trivial (1 movimiento) suma 10: el tramo tiene que exigir algo en todas sus filas;
##  - Los escalones que sobran de un tramo no regalan la fila siguiente: cada fila se resuelve al llegar a SU plataforma.
static func _segment_defects(st: Dictionary, y_from: int, y_to: int, rows: int, _seg_len: int) -> int:
	var defects := 0
	var moves: Array = st.row_moves
	for k in range(y_from - 1, y_to):
		if moves[k] <= 1:
			defects += 10
	return defects


static func _count_grab(infos: Array) -> int:
	var n := 0
	for inf in infos:
		if inf.get("needs_grab", false):
			n += 1
	return n


static func _make_row(tower, sim, y: int, rng: RandomNumberGenerator, band: Vector2i, difficulty: float,
		tries: int, max_states: int, geo: Dictionary, reserved: Dictionary, last_shape := "", climb := 1.0, combo := 0.0, use_effort := true, prefix: Array = [], grab_scale := 1.0, budget_states := 0) -> Dictionary:
	var stat := {"states": 0}
	# Trabajo máximo para AFINAR la fila (ascenso, variantes, enriquecimiento); encontrar una fila válida no tiene tope.
	var over := func() -> bool: return budget_states > 0 and stat.states > budget_states
	var arrival := Vector2i(sim.player.x, sim.player.z)
	var forbidden := {arrival: true}  # celdas (x, z) donde la capa y no puede llevar plataforma ni obstáculo
	for rc in reserved:
		if rc.y == y:
			forbidden[Vector2i(rc.x, rc.z)] = true
	# Piso libre: hay bloque en la capa y-1 y la capa y está vacía (se puede estar parado ahí).
	var floor_free := {}
	for z in geo.foot.y:
		for x in geo.foot.x:
			var c := Vector2i(x, z)
			if in_envelope(c, geo) and sim.blocks.has(Vector3i(x, y - 1, z)) and not sim.blocks.has(Vector3i(x, y, z)):
				floor_free[c] = true
	var ctx := {"cancel": rng.get_meta("cancel") if rng.has_meta("cancel") else null, "forbidden": forbidden, "floor_free": floor_free, "arrival": arrival, "geo": geo,
			"sim": sim, "y": y, "reserved": reserved, "max_states": max_states, "band_ref": [band]}
	var dmin := 1 + (band.x * 2) / 3  # distancia mínima (Manhattan) entre donde llegás y la plataforma nueva

	var solved: Array = []
	var want_grab := rng.randf() < clampf(0.6 + 0.8 * difficulty, 0.6, 1.0) * grab_scale  # ¿esta fila tiene que exigir mover bloques?
	ctx["check_grab"] = want_grab
	# Rondas 0-4: dificultad pedida, relajando la distancia mínima. Rondas 5-6: dificultad 0 (siempre produce algo).
	for round_i in 7:
		var d_eff := difficulty if round_i < 5 else 0.0
		ctx["dmin"] = maxi(1, dmin - 2 * round_i) if round_i < 5 else 1
		# Tamaño mínimo de la plataforma: es el espacio de juego de la fila siguiente (con 3 celdas no hay lugar
		# para obstáculos y la fila sale trivial). Se relaja si no hay candidatos.
		ctx["min_cells"] = 5 if round_i < 3 else (4 if round_i < 5 else 2)
		var kmax := 2 + (band.x if round_i < 5 else 2) / 2
		var n_tries := tries + int(d_eff * 2.0 * tries)
		for i in n_tries:
			var shape := _pick_shape(rng, d_eff)
			var plat := _make_platform(rng, shape, ctx, d_eff)
			if plat.is_empty():
				continue
			# Compuerta: pilares en todas las celdas desde las que se accede a la plataforma, así que no se puede entrar
			# caminando y hay que empujar o tirar de uno. Se usa a veces cuando la fila tiene que exigir mover bloques.
			var gated := want_grab and rng.randf() < 0.5
			var cand := {"plat": plat, "kinds": _platform_kinds(rng, plat.size(), d_eff), "shape": shape,
					"obs": _make_gate(plat, ctx) if gated else _make_obstacles(rng, plat, ctx, kmax, d_eff)}
			var res := _eval(cand, ctx, stat)
			if not res.is_empty():
				solved.append(res)
		if not solved.is_empty():
			break

	# Si la fila tiene que exigir mover bloques y todavía no hay ningún candidato que lo haga, se busca a propósito con
	# compuertas (relajando de a poco la distancia y el tamaño mínimos).
	if want_grab and not solved.any(func(c): return c.needs_grab):
		for relax in 3:
			ctx["dmin"] = maxi(1, dmin - 2 * relax)
			ctx["min_cells"] = 5 if relax < 2 else 4
			for i in tries * 2:
				var shape := _pick_shape(rng, difficulty)
				var plat := _make_platform(rng, shape, ctx, difficulty)
				if plat.is_empty():
					continue
				var res := _eval({"plat": plat, "kinds": _platform_kinds(rng, plat.size(), difficulty), "shape": shape,
						"obs": _make_gate(plat, ctx)}, ctx, stat)
				if not res.is_empty():
					solved.append(res)
			if solved.any(func(c): return c.needs_grab):
				break

	# Ascenso por mutaciones: parte del mejor candidato y le suma obstáculos mientras siga siendo
	# resoluble, para empujar el mínimo de movimientos hacia la banda.
	if not solved.is_empty():
		var best: Dictionary = solved[0]
		for c in solved:
			if c.dist < best.dist or (c.dist == best.dist and c.moves > best.moves):
				best = c
		var iters := int((8 + difficulty * 30.0) * climb)
		for i in iters:
			if best.dist == 0 or best.moves > band.y or over.call():
				break
			var res := _eval(_mutate(rng, best, ctx, difficulty), ctx, stat)
			if res.is_empty():
				continue
			solved.append(res)
			if res.moves >= best.moves and res.moves <= band.y + 2:
				best = res

	var want_combo := rng.randf() < combo

	# Variantes sin la parte de arriba de los pilares: no dejan escalones regalados en la fila siguiente.
	var stripped: Array = []
	for c in solved:
		if over.call():
			break
		var tops: Array = c.obs.filter(func(o): return o.c.y != y)
		if tops.is_empty():
			continue
		var res := _eval({"plat": c.plat, "kinds": c.kinds, "shape": c.shape,
				"obs": c.obs.filter(func(o): return o.c.y == y)}, ctx, stat)
		if not res.is_empty():
			stripped.append(res)
	solved.append_array(stripped)

	# Piso de dificultad: ninguna fila trivial. Si lo mejor que hay es muy fácil, se sigue mutando.
	var min_ok := maxi(2, band.x - 1)
	if not solved.is_empty():
		var cur: Dictionary = solved[0]
		for c in solved:
			if c.moves > cur.moves:
				cur = c
		for i in int(40 * climb):
			if cur.moves >= min_ok or over.call():
				break
			var res := _eval(_mutate(rng, cur, ctx, difficulty), ctx, stat)
			if res.is_empty():
				continue
			solved.append(res)
			if res.moves >= cur.moves:
				cur = res
	# Enriquecimiento: con la fila ya dentro de la banda, se sigue mutando mientras no salga de ella y gane en
	# "engaño" (más búsqueda para el solucionador = más caminos tentadores sin salida) o, si toca combinar, en
	# mecánicas mezcladas. Es lo que hace que no se resuelva en línea recta.
	if (use_effort or want_combo or want_grab) and not solved.is_empty():
		var rich: Dictionary = {}
		for c in solved:
			if c.dist == 0 and (rich.is_empty() or _score(c, want_combo, want_grab) > _score(rich, want_combo, want_grab)):
				rich = c
		if not rich.is_empty():
			for i in int(14 * climb):
				if over.call():
					break
				var res := _eval(_mutate(rng, rich, ctx, difficulty), ctx, stat)
				if res.is_empty() or res.dist != 0:
					continue
				solved.append(res)
				if _score(res, want_combo, want_grab) > _score(rich, want_combo, want_grab):
					rich = res

	var max_ok := band.y + 4  # techo: una fila mucho más larga que la banda es injusta
	var pool: Array = solved.filter(func(s): return s.moves >= min_ok and s.moves <= max_ok)
	if pool.is_empty():
		pool = solved.filter(func(s): return s.moves >= min_ok)
	if pool.is_empty():
		pool = solved

	if want_grab:  # si hay candidatos que exigen mover bloques, se elige entre ellos
		var needing: Array = pool.filter(func(c): return c.needs_grab)
		if not needing.is_empty():
			pool = needing
	var in_band: Array = pool.filter(func(s): return s.dist == 0)
	var rest: Array = pool.filter(func(s): return s.dist > 0)
	rest.sort_custom(func(a, b): return a.dist < b.dist)
	for j in range(in_band.size() - 1, 0, -1):  # Fisher–Yates con el rng de la semilla
		var k := rng.randi_range(0, j)
		var tmp = in_band[j]
		in_band[j] = in_band[k]
		in_band[k] = tmp
	var order: Array = []
	# Dentro de la banda: preferir (1) mezclar mecánicas, si toca combinar; (2) una forma distinta a la de la fila anterior;
	# (3) el que más búsqueda le cuesta al solucionador (más caminos tentadores sin salida). Después, el resto por cercanía.
	var groups: Array = [[], [], [], []]
	for c in in_band:
		var g := 0 if (want_combo and c.kinds_n >= 2) else 2
		if c.shape == last_shape:
			g += 1
		groups[g].append(c)
	for g in groups:
		if use_effort:
			g.sort_custom(func(a, b): return a.effort > b.effort)
		order.append_array(g)
	order.append_array(rest)

	var fallback := {}
	var why := {"resueltos": solved.size(), "probados": 0, "accion_invalida": 0, "nivel_o_murio": 0, "repeticion": 0}
	for cand in order:
		why.probados += 1
		var exec = sim.clone()
		for b in cand.blocks:
			exec.add_block(b.c, false, b.kind, b.timer)
		var ok := true
		var reserve: Array[Vector3i] = []
		for a in cand.path:
			var prev_hang: Vector3i = exec.hang_dir
			var prev_pos: Vector3i = exec.player
			if not exec.try_action(a.dir, a.mode).ok:
				ok = false
				break
			for c in exec.trail:
				reserve.append(c)
				reserve.append(c + Vector3i(0, 1, 0))
			# Colgado, avanzar o doblar exige el borde libre arriba del bloque del que se agarra (el viejo y el nuevo).
			if prev_hang != Vector3i.ZERO:
				reserve.append(prev_pos + prev_hang + Vector3i(0, 1, 0))
			if exec.hang_dir != Vector3i.ZERO:
				reserve.append(exec.player + exec.hang_dir + Vector3i(0, 1, 0))
		if not ok:
			why.accion_invalida += 1
			continue
		var on_plat := false
		for j in cand.plat.size():
			on_plat = on_plat or exec.blocks.get(exec.player + Vector3i.DOWN, -2) == sim._next_id + j
		if not (exec.player.y == y + 1 and not exec.lost and on_plat):
			why.nivel_o_murio += 1
			continue
		# Validación: con el candidato agregado a la torre, todo el camino anterior más el nuevo tiene que seguir
		# llegando donde llegaba. Un bloque nuevo puede sostener uno que en la simulación caía (la parte de arriba de
		# un pilar) o frenar uno que se deslizaba; en ese caso se descarta el candidato.
		if not _path_consistent(tower, cand.blocks, prefix, cand.path, y + 1, cand.plat.size()):
			why.repeticion += 1
			continue
		var done := {"sim": exec, "path": cand.path, "moves": cand.moves, "states": stat.states,
				"reserve": reserve, "shape": cand.shape, "cand": cand,
				"info": {"arrival": arrival, "plat": cand.plat, "obs": cand.obs, "kinds": cand.kinds,
						"effort": cand.effort, "kinds_n": cand.kinds_n, "needs_grab": cand.needs_grab}}
		return _commit(tower, done, y)
	if not fallback.is_empty():
		return _commit(tower, fallback, y)
	return {"fail": str(why)}


## Celdas que ninguna plataforma posterior puede ocupar para no cambiar lo que le pasó a cada bloque que se movió o
## cayó durante la solución: un vecino nuevo podría sostener un bloque que en la simulación caía (por ejemplo la parte de
## arriba de un pilar) o frenar uno que se deslizaba. Se reserva la caja que recorrió cada bloque, agrandada en 1.
static func _moved_reserve(sim, exec, cand_blocks: Array) -> Array[Vector3i]:
	var starts := {}
	for id in sim.positions:
		starts[id] = sim.positions[id]
	for i in cand_blocks.size():
		starts[sim._next_id + i] = cand_blocks[i].c
	var out: Array[Vector3i] = []
	for id in starts:
		var a: Vector3i = starts[id]
		var moved: bool = not exec.positions.has(id) or exec.positions[id] != a
		if not moved:
			continue
		var b: Vector3i = exec.positions.get(id, Vector3i(a.x, maxi(exec.floor_y, 0), a.z))  # sin posición: cayó al vacío
		for x in range(mini(a.x, b.x) - 1, maxi(a.x, b.x) + 2):
			for y in range(maxi(mini(a.y, b.y) - 1, 0), maxi(a.y, b.y) + 2):
				for z in range(mini(a.z, b.z) - 1, maxi(a.z, b.z) + 2):
					out.append(Vector3i(x, y, z))
	return out


## ¿Sigue llegando a donde llegaba todo el camino anterior más el de la fila nueva, sobre la torre con los bloques
## del candidato agregados? (la torre es la intacta, sin caída de la fila base)
static func _path_consistent(tower, cand_blocks: Array, prefix: Array, cand_path: Array, level: int, plat_n: int) -> bool:
	var chk = tower.clone()
	chk.goal_y = BIG
	var base_id: int = chk._next_id
	for b in cand_blocks:
		chk.add_block(b.c, false, b.kind, b.timer)
	for a in prefix:
		if not chk.try_action(a.dir, a.mode).ok or chk.lost:
			return false
	for a in cand_path:
		if not chk.try_action(a.dir, a.mode).ok or chk.lost:
			return false
	var base_ok := false
	for j in plat_n:
		base_ok = base_ok or chk.blocks.get(chk.player + Vector3i.DOWN, -2) == base_id + j
	return chk.player.y == level and base_ok


## Qué tan "enriquecida" está una fila: esfuerzo del solucionador, y (si toca combinar) mecánicas mezcladas.
static func _score(c: Dictionary, want_combo: bool, want_grab := false) -> int:
	return c.effort + (100000 * c.kinds_n if want_combo else 0) + (10000000 if want_grab and c.needs_grab else 0)


static func _commit(tower, done: Dictionary, y: int) -> Dictionary:
	var plat_ids: Array = []
	for j in done.cand.plat.size():
		plat_ids.append(tower._next_id + j)
	tower.row_platforms[y] = plat_ids
	for id in plat_ids:
		tower.platform_row[id] = y
	for b in done.cand.blocks:
		tower.add_block(b.c, false, b.kind, b.timer)
	done.erase("cand")
	done.erase("next_cost")
	return done


## Arma los bloques del candidato, los valida con el solucionador y devuelve el resultado
## ({blocks, moves, path, shape, dist, plat, kinds, obs}) o {} si no se resuelve.
static func _eval(cand: Dictionary, ctx: Dictionary, stat: Dictionary) -> Dictionary:
	if _stopped(ctx.get("cancel", null)):
		return {}
	var y: int = ctx.y
	var plat: Array = cand.plat
	var blocks: Array = []
	for j in plat.size():
		blocks.append({"c": Vector3i(plat[j].x, y, plat[j].y), "kind": cand.kinds[j], "timer": 0})
	blocks.append_array(cand.obs)
	var trial = ctx.sim.clone()
	var plat_ids := {}   # la fila se resuelve al llegar a SU plataforma, no a cualquier bloque de esa altura
	for j in plat.size():
		plat_ids[trial._next_id + j] = true
	for b in blocks:
		trial.add_block(b.c, false, b.kind, b.timer)
	var win = _window(trial, y, plat_ids)
	var res := Solver.solve(win, y + 1, {"max_states": ctx.max_states, "goal_ids": win.goal_ids})
	stat.states += res.states
	if res.status != "solved":
		return {}
	var kinds := {}
	for k in cand.kinds:
		if k != K.NORMAL:
			kinds[k] = true
	for o in cand.obs:
		if o.kind != K.NORMAL:
			kinds[o.kind] = true
	var dist := _band_dist(res.moves, ctx.band_ref[0])
	# ¿La fila exige mover bloques? Sin empujar ni tirar no tiene solución o cuesta al menos 2 movimientos más.
	# Sólo se comprueba en los candidatos cercanos a la banda (es un segundo solucionador por candidato).
	var needs := false
	if ctx.get("check_grab", false) and dist <= 2:
		var ng := Solver.solve(win, y + 1, {"max_states": 3000, "no_grab": true, "goal_ids": win.goal_ids})
		stat.states += ng.states
		needs = ng.status == "unsolvable" or (ng.status == "solved" and ng.moves >= res.moves + 2)
	return {"blocks": blocks, "moves": res.moves, "path": res.path, "shape": cand.shape,
			"plat": plat, "kinds": cand.kinds, "obs": cand.obs, "dist": dist,
			"effort": res.states, "kinds_n": kinds.size(), "needs_grab": needs}


## Una mutación: suma un obstáculo, cambia el tipo de uno, lo mueve, o cambia el tipo de una celda de la plataforma.
static func _mutate(rng: RandomNumberGenerator, cand: Dictionary, ctx: Dictionary, difficulty: float) -> Dictionary:
	var out := {"plat": cand.plat, "kinds": cand.kinds.duplicate(), "shape": cand.shape, "obs": cand.obs.duplicate(true)}
	var op := rng.randi_range(0, 3)
	var used := {}
	for o in out.obs:
		used[Vector2i(o.c.x, o.c.z)] = true
	var free: Array = []
	var fw: Array = []
	for c in ctx.floor_free:
		if ctx.forbidden.has(c) or out.plat.has(c) or used.has(c):
			continue
		var access := false
		for d in DIRS2:
			if out.plat.has(c + d):
				access = true
		free.append(c)
		fw.append(4.0 if access else 1.0)
	if op == 3 and difficulty >= 0.05 and not out.kinds.is_empty():  # (el hielo se desbloquea desde 0.05)
		var i := rng.randi_range(0, out.kinds.size() - 1)
		out.kinds[i] = K.ICE if out.kinds[i] == K.NORMAL else K.NORMAL
		return out
	if op == 2 and not out.obs.is_empty() and not free.is_empty():  # mover un obstáculo (el pilar, si lo hay, no)
		var j := rng.randi_range(0, out.obs.size() - 1)
		if out.obs[j].c.y == ctx.y:
			var c: Vector2i = free[_pick(fw, rng)]
			out.obs[j].c = Vector3i(c.x, ctx.y, c.y)
			out.obs = out.obs.filter(func(o): return o.c.y == ctx.y or Vector2i(o.c.x, o.c.z) == c)
			return out
	if op == 1 and not out.obs.is_empty():  # cambiar el tipo de un obstáculo
		var j := rng.randi_range(0, out.obs.size() - 1)
		if out.obs[j].c.y == ctx.y:
			var k := _capped_kind(rng, difficulty, out.obs)
			out.obs[j].kind = k
			out.obs[j].timer = rng.randi_range(3, 8) if k == K.BOMB else 0
			return out
	if not free.is_empty():  # sumar un obstáculo
		var c: Vector2i = free[_pick(fw, rng)]
		var k := _capped_kind(rng, difficulty, out.obs)
		out.obs.append({"c": Vector3i(c.x, ctx.y, c.y), "kind": k, "timer": rng.randi_range(3, 8) if k == K.BOMB else 0})
		if k == K.NORMAL and rng.randf() < PILLAR_CHANCE and not ctx.reserved.has(Vector3i(c.x, ctx.y + 1, c.y)):
			out.obs.append({"c": Vector3i(c.x, ctx.y + 1, c.y), "kind": K.NORMAL, "timer": 0})
	return out


## Sesgo de la generación (escenarios y pruebas): {"kinds": {Kind: peso extra}, "plat_ice": prob. extra de hielo en las plataformas,
## "cap_bonus": bloques especiales extra por fila}. El peso extra vale aunque la dificultad de la etapa todavía no desbloquee ese tipo.
static func _bias(rng: RandomNumberGenerator) -> Dictionary:
	return rng.get_meta("bias", {})


## Como _obstacle_kind, pero sin pasar el tope de bloques especiales ya presentes en la fila.
static func _capped_kind(rng: RandomNumberGenerator, difficulty: float, obs: Array) -> int:
	var specials := 0
	for o in obs:
		if o.kind != K.NORMAL:
			specials += 1
	var k := _obstacle_kind(rng, difficulty)
	return K.NORMAL if k != K.NORMAL and specials >= 1 + int(difficulty * 3.0) + int(_bias(rng).get("cap_bonus", 0)) else k


## Tipo de un obstáculo; las mecánicas se desbloquean con la dificultad (hielo, después catapulta, después bomba).
static func _obstacle_kind(rng: RandomNumberGenerator, difficulty: float) -> int:
	var weights := [1.0,
			0.0 if difficulty < 0.05 else 0.15 + 0.5 * difficulty,
			0.0 if difficulty < 0.4 else 0.1 + 0.5 * (difficulty - 0.4),
			0.0 if (difficulty < 0.25 or not CATAPULTS_IN_TOWERS) else 0.05 + 0.2 * (difficulty - 0.25),
			0.0 if difficulty < CRACKED_FROM else 0.15 + 0.35 * (difficulty - CRACKED_FROM),
			0.0 if difficulty < HEAVY_FROM else 0.15 + 0.35 * (difficulty - HEAVY_FROM),
			0.0 if difficulty < SPIKES_FROM else 0.1 + 0.3 * (difficulty - SPIKES_FROM)]
	var kinds := [K.NORMAL, K.ICE, K.BOMB, K.CATAPULT, K.CRACKED, K.HEAVY, K.SPIKES]
	var extra: Dictionary = _bias(rng).get("kinds", {})
	for i in kinds.size():
		weights[i] += float(extra.get(kinds[i], 0.0))
	return kinds[_pick(weights, rng)]


# --- formas de plataforma ---------------------------------------------------------------------

static func _pick_shape(rng: RandomNumberGenerator, difficulty: float) -> String:
	var shapes := ["blob", "bar", "L", "arc"]
	return shapes[_pick([2.0, 2.0, 2.0, 1.0 + 3.0 * difficulty], rng)]


static func _cell_ok(c: Vector2i, ctx: Dictionary) -> bool:
	var a: Vector2i = ctx.arrival
	return in_envelope(c, ctx.geo) and not ctx.forbidden.has(c) \
			and not ctx.sim.blocks.has(Vector3i(c.x, ctx.y, c.y)) \
			and absi(c.x - a.x) + absi(c.y - a.y) >= ctx.dmin


## Conjunto conexo de celdas de la capa y, o [] si no se pudo armar.
static func _make_platform(rng: RandomNumberGenerator, shape: String, ctx: Dictionary,
		difficulty: float) -> Array[Vector2i]:
	var geo: Dictionary = ctx.geo
	var arrival: Vector2i = ctx.arrival
	var floor_free: Dictionary = ctx.floor_free
	var center: Vector2 = geo.center
	var theta_a := atan2(arrival.y + 0.5 - center.y, arrival.x + 0.5 - center.x)
	var seeds: Array = []
	var weights: Array = []
	for z in geo.foot.y:
		for x in geo.foot.x:
			var c := Vector2i(x, z)
			if not _cell_ok(c, ctx):
				continue
			var adj := false
			for d in DIRS2:
				if floor_free.has(c + d):
					adj = true
			if not adj:
				continue
			var dth := wrapf(atan2(c.y + 0.5 - center.y, c.x + 0.5 - center.x) - theta_a, -PI, PI)
			var w := 0.4 + 3.0 * exp(-pow(dth - 0.6, 2.0) / 0.4)
			if touches_core(c, geo):
				w *= 2.0
			seeds.append(c)
			weights.append(w)
	if seeds.is_empty():
		return []
	var seed_cell: Vector2i = seeds[_pick(weights, rng)]
	var cells: Array[Vector2i] = []
	match shape:
		"bar":
			var d: Vector2i = DIRS2[rng.randi_range(0, 3)]
			cells = _line(seed_cell, d, rng.randi_range(4, 5 + int(difficulty * 3.0)), ctx)
		"L":
			var d: Vector2i = DIRS2[rng.randi_range(0, 3)]
			cells = _line(seed_cell, d, rng.randi_range(3, 4 + int(difficulty * 2.0)), ctx)
			if not cells.is_empty():
				var turn := Vector2i(-d.y, d.x) if rng.randf() < 0.5 else Vector2i(d.y, -d.x)
				var leg := _line(cells[cells.size() - 1], turn, rng.randi_range(2, 3 + int(difficulty * 2.0)), ctx)
				for c in leg:
					if not cells.has(c):
						cells.append(c)
		"arc":
			cells = _arc(seed_cell, rng, rng.randi_range(5 + int(difficulty * 3.0), 6 + int(difficulty * 6.0)), ctx)
		_:
			cells = _blob(seed_cell, rng, rng.randi_range(5 + int(difficulty * 3.0), 8 + int(difficulty * 6.0)), ctx)
	return _finish(cells, ctx, 4 if shape == "bar" else 99)


## Celdas en línea recta desde c (incluida), cortando en la primera celda no válida.
static func _line(c: Vector2i, d: Vector2i, n: int, ctx: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in n:
		var p := c + d * i
		if not _cell_ok(p, ctx):
			break
		cells.append(p)
	return cells


## Arco que sigue el anillo alrededor del core, hacia un lado u otro.
static func _arc(c: Vector2i, rng: RandomNumberGenerator, n: int, ctx: Dictionary) -> Array[Vector2i]:
	var cycle := ring_cycle(ctx.geo, ring_of(c, ctx.geo))
	var idx := cycle.find(c)
	var cells: Array[Vector2i] = []
	if idx < 0:
		return cells
	var dir := 1 if rng.randf() < 0.5 else -1
	for i in mini(n, cycle.size() / 2):
		var p := cycle[posmod(idx + dir * i, cycle.size())]
		if not _cell_ok(p, ctx):
			break
		cells.append(p)
	return cells


## Mancha conexa: crece pegándose al core o a lo que ya tiene.
static func _blob(c: Vector2i, rng: RandomNumberGenerator, n: int, ctx: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [c]
	while cells.size() < n:
		var cand: Array = []
		var cw: Array = []
		for p in cells:
			for d in DIRS2:
				var q: Vector2i = p + d
				if cells.has(q) or cand.has(q) or not _cell_ok(q, ctx):
					continue
				cand.append(q)
				cw.append(3.0 if touches_core(q, ctx.geo) else (1.5 if ctx.floor_free.has(q) else 1.0))
		if cand.is_empty():
			break
		cells.append(cand[_pick(cw, rng)])
	return cells


## Tiene que haber un mínimo de celdas (ctx.min_cells) y una celda de piso libre pegada a la plataforma, para trepar.
static func _finish(cells: Array[Vector2i], ctx: Dictionary, cap_min := 99) -> Array[Vector2i]:
	if cells.size() < mini(ctx.get("min_cells", 2), cap_min):
		return []
	for c in cells:
		for d in DIRS2:
			if ctx.floor_free.has(c + d) and not cells.has(c + d):
				return cells
	return []


static func _platform_kinds(rng: RandomNumberGenerator, n: int, difficulty: float) -> Array[int]:
	var res: Array[int] = []
	var p_ice := (0.0 if difficulty < 0.05 else 0.04 + 0.20 * difficulty) + float(_bias(rng).get("plat_ice", 0.0))
	var p_tramp := 0.0 if (difficulty < 0.25 or not CATAPULTS_IN_TOWERS) else 0.02 + 0.06 * difficulty
	var ice_cap := 2 + int(difficulty * 2.0) + int(_bias(rng).get("cap_bonus", 0))  # tope de celdas de hielo por plataforma (lo más difícil de leer)
	var ice := 0
	# Trampas (celdas que se desarman al pisarlas) y pinchos: pocos por plataforma; el solucionador comprueba que siempre haya camino.
	var p_trap := 0.0 if difficulty < TRAP_FROM else 0.05 + 0.10 * (difficulty - TRAP_FROM)
	var p_spikes := 0.0 if difficulty < SPIKES_FROM else 0.03 + 0.07 * (difficulty - SPIKES_FROM)
	var traps := 0
	var spikes := 0
	for i in n:
		var r := rng.randf()
		if r < p_ice:
			if ice < ice_cap:
				ice += 1
				res.append(K.ICE)
			else:
				res.append(K.NORMAL)  # tope de hielo alcanzado
		elif r < p_ice + p_tramp:
			res.append(K.CATAPULT)
		elif r < p_ice + p_tramp + p_trap and traps < 2:
			traps += 1
			res.append(K.TRAP)
		elif r < p_ice + p_tramp + p_trap + p_spikes and spikes < 1:
			spikes += 1
			res.append(K.SPIKES)
		else:
			res.append(K.NORMAL)
	return res


## Compuerta: pilares de 2 en todas las celdas de piso libre pegadas a la plataforma (salvo las reservadas).
static func _make_gate(plat: Array[Vector2i], ctx: Dictionary) -> Array:
	var y: int = ctx.y
	var out: Array = []
	for c in ctx.floor_free:
		if ctx.forbidden.has(c) or plat.has(c):
			continue
		var access := false
		for d in DIRS2:
			if plat.has(c + d):
				access = true
		if not access:
			continue
		out.append({"c": Vector3i(c.x, y, c.y), "kind": K.NORMAL, "timer": 0})
		if not ctx.reserved.has(Vector3i(c.x, y + 1, c.y)):
			out.append({"c": Vector3i(c.x, y + 1, c.y), "kind": K.NORMAL, "timer": 0})
	return out


## Obstáculos sobre el piso libre, concentrados en los accesos a la plataforma.
static func _make_obstacles(rng: RandomNumberGenerator, plat: Array[Vector2i], ctx: Dictionary, kmax: int,
		difficulty: float) -> Array:
	var y: int = ctx.y
	var free: Array = []
	var fw: Array = []
	for c in ctx.floor_free:
		if ctx.forbidden.has(c) or plat.has(c):
			continue
		var access := false  # pegada a la plataforma: desde ahí se trepa
		for d in DIRS2:
			if plat.has(c + d):
				access = true
		free.append(c)
		fw.append(4.0 if access else 1.0)
	var out: Array = []
	var specials := 0
	var cap := 1 + int(difficulty * 3.0)  # tope de bloques especiales (hielo, bomba, catapulta) por fila
	var want := mini(rng.randi_range(0, kmax), free.size())
	for j in want:  # sorteo ponderado sin repetición: los accesos tapados obligan a mover bloques
		var idx := _pick(fw, rng)
		var c: Vector2i = free[idx]
		free.remove_at(idx)
		fw.remove_at(idx)
		var kind := _obstacle_kind(rng, difficulty)
		if kind != K.NORMAL:
			if specials >= cap:
				kind = K.NORMAL
			else:
				specials += 1
		out.append({"c": Vector3i(c.x, y, c.y), "kind": kind, "timer": rng.randi_range(3, 8) if kind == K.BOMB else 0})
		if kind == K.NORMAL and rng.randf() < PILLAR_CHANCE and not ctx.reserved.has(Vector3i(c.x, y + 1, c.y)):
			out.append({"c": Vector3i(c.x, y + 1, c.y), "kind": K.NORMAL, "timer": 0})  # pilar de 2: no se puede trepar
	return out


static func _pick(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return weights.size() - 1


static func _band_dist(moves: int, band: Vector2i) -> int:
	if moves < band.x:
		return band.x - moves
	return maxi(0, moves - band.y)


## Recorte de la torre alrededor de la fila y: capas y-2 .. y+1 (lo único que influye en subir un
## nivel); si hay catapultas se suben las capas de arriba hasta donde pueden llegar los saltos.
static func _window(src, y: int, goal_ids := {}):
	var top := y + 1
	for id in src.kind_of:
		if src.kind_of[id] == K.CATAPULT and src.positions[id].y >= y - 2 and src.positions[id].y <= y + 1:
			top = y + 7  # una catapulta sube hasta 4 (y 1 más al trepar a ella)
			break
	var w = TowerLogic.new()
	w.size = src.size
	w.collapse_every = BIG
	w.moves_to_collapse = BIG
	w.floor_y = maxi(y - 3, 0)
	for c in src.blocks:
		if c.y >= y - 2 and c.y <= top:
			var id: int = src.blocks[c]
			if goal_ids.has(id):
				w.goal_ids[w._next_id] = true
			w.add_block(c, src.fixed.has(c), src.kind_of.get(id, K.NORMAL), src.bomb_timer.get(id, 0))
	w.player = src.player
	w.hang_dir = src.hang_dir
	w.goal_y = y + 1
	return w


## Menor N con el que el camino óptimo completo sobrevive a la caída de la fila base.
static func min_collapse_every(tower, path: Array) -> int:
	for n in range(1, path.size() + 2):
		if _replay_wins(tower, path, n):
			return n
	return path.size() + 1


## Programa la caída de la fila base: cada n movimientos, y la primera tarda el doble (tiempo para explorar).
static func _arm(t, n: int) -> void:
	t.collapse_every = n
	t.moves_to_collapse = 2 * n


static func _replay_wins(tower, path: Array, collapse_every: int) -> bool:
	var s = tower.clone()
	_arm(s, collapse_every)
	for a in path:
		if not s.try_action(a.dir, a.mode).ok or s.lost:
			return false
		if s.won:
			break
	return s.won
