extends RefCounted
## Salas altas armadas con módulos (ver docs/modulos.md). La sala no tiene piso: el jugador empieza parado en un bloque verde fijo, el final es un bloque rojo fijo, y todo lo demás se sostiene del núcleo 2x2 de la torre
## (los bloques pegados al núcleo se sostienen siempre) o, en la 3x3 (que no toca el núcleo), de esos dos bloques fijos, que representan la sala anterior y la siguiente.
## Se construye de abajo hacia arriba, de a un módulo: cada módulo (trampolín, cornisa de pinchos que se cruza colgado, camino de hielo, hueco que se rellena empujando un bloque, escalera) sube unos pisos con una técnica.
## Cada módulo se arma con parámetros al azar y SÓLO se acepta si, resuelto con el solucionador exacto en el contexto de todo lo ya armado: la sala sigue siendo estable, se resuelve, y el bloque especial que trae hace falta
## (sacarlo cambia el camino más corto). Después de cada módulo se repite el camino completo desde el inicio. Los módulos de distintos pisos no se pisan: los bloques sólo se mueven en horizontal, así que cada piso se resuelve por separado.
## Devuelve un paso (scripts/step_lib.gd) que se abre en el Estudio de pasos.

const StepLib := preload("res://scripts/step_lib.gd")
const RoomLib := preload("res://scripts/room_lib.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const K := TowerLogic.Kind

const DIRS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const UP := Vector3i(0, 1, 0)
const DOWN := Vector3i(0, -1, 0)
const CORE_CELLS: Array[Vector2i] = [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)]
const WINDOW := 8
const ALL_TECHNIQUES := ["trampolin", "pinchos", "hielo", "arenisca", "transporte", "escalera"]

var rng := RandomNumberGenerator.new()
var shape := "3x8"
var arena := {}            # celdas (x, z) donde puede haber bloques sueltos
var anchors: Array = []    # celdas de la arena pegadas al núcleo
var height := 8            # altura total de la ventana
var with_core := true
var blocks := {}           # Vector3i -> tipo
var start := Vector3i.ZERO # donde empieza parado el jugador (sobre el bloque verde, que es fijo)
var pos := Vector3i.ZERO   # donde está parado al terminar el último módulo
var path: Array = []
var modules: Array = []    # [{kind, moves, text}]
var last_why := ""
var used := {}             # cuántas veces se usó cada técnica en esta sala
var last_kind := ""
var last_break := {}
var air := {}               # celdas por las que pasó el jugador o algún bloque suelto en el camino ya armado: los módulos nuevos no pueden poner bloques ahí
var reasons := {}           # por qué se descartaron las muestras ("técnica:motivo": cantidad)
var tries := {}
var eval_cap := 250000
var best_of := 6            # de cuántas muestras válidas de un módulo se elige la de más dificultad
var transport_min_grabs := 3   # el transporte sólo vale si el camino más corto tiene al menos tantos empujes y tirones
var transport_min_ratio := 0.4   # el transporte sólo vale si al menos esta parte de sus pasos son empujes y tirones
var min_diff := 0.0         # la sala armada tiene que tener al menos esta dificultad (empujes y tirones sobre pasos del camino más corto)
var total_moves := 0
var total_grabs := 0
var total_tech := 0
var min_tech := 0.0         # la sala armada tiene que tener al menos esta dificultad de técnica (empujar, tirar, colgarse, patinar y saltar con catapulta sobre pasos)


func _init(seed_value := 1) -> void:
	rng.seed = seed_value


# --- armado de la sala -----------------------------------------------------------------------------------------------------------

## Una sala alta de `shape` con `target_h` pisos. `techniques`: cuáles usar (por defecto todas). Devuelve {step, path, modules} o {}.
func build(shape_name: String, target_h: int, techniques: Array = [], max_modules := 9) -> Dictionary:
	shape = shape_name
	height = mini(target_h + 4, StepLib.MAX_H)
	blocks = {}
	path = []
	modules = []
	tries = {}
	air = {}
	total_moves = 0
	total_grabs = 0
	total_tech = 0
	used = {}
	last_kind = ""
	arena = {}
	for c in RoomLib.shape_info(shape).cells:
		arena[c] = true
	with_core = shape != "3x3"
	anchors = []
	if with_core:
		for c in arena:
			for core in CORE_CELLS:
				if absi(c.x - core.x) + absi(c.y - core.y) == 1 and not anchors.has(c):
					anchors.append(c)
	var techs: Array = techniques if not techniques.is_empty() else ALL_TECHNIQUES
	# el inicio: sobre el bloque verde, pegado al núcleo si lo hay
	var cells: Array = arena.keys()
	var a: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
	start = Vector3i(a.x, 2, a.y)
	pos = start
	for m in max_modules:
		if pos.y - 1 >= target_h:
			break
		var ok := false
		var order: Array = _module_order(techs, target_h - (pos.y - 1))
		if order.is_empty():
			break
		for kind in order:
			if _try_module(kind):
				ok = true
				break
		if not ok:
			last_why = "ningún módulo entra desde %s (%s)" % [str(pos), str(tries)]
			return {}
	if pos.y - 1 < target_h:
		last_why = "no se llegó a la altura (%d de %d)" % [pos.y - 1, target_h]
		return {}
	var ratio := float(total_grabs) / maxf(float(total_moves), 1.0)
	if ratio < min_diff:
		last_why = "dificultad %d %% (se pedía %d %%)" % [roundi(100.0 * ratio), roundi(100.0 * min_diff)]
		return {}
	var tech_ratio := float(total_tech) / maxf(float(total_moves), 1.0)
	if tech_ratio < min_tech:
		last_why = "dificultad de técnica %d %% (se pedía %d %%)" % [roundi(100.0 * tech_ratio), roundi(100.0 * min_tech)]
		return {}
	var step := _step(start, pos, "Torre %s de %d pisos" % [shape, pos.y - 1])
	step.note = "Módulos: " + " → ".join(modules.map(func(m): return str(m.kind)))
	step.diff_armada = ratio
	step.diff_tecnica = float(total_tech) / maxf(float(total_moves), 1.0)
	StepLib.finalize(step)
	return {"step": step, "path": path, "modules": modules}


## El orden en que se prueban las técnicas en este piso: las menos usadas primero (al azar entre las empatadas), sin repetir la del módulo anterior y a lo sumo dos veces cada una; si la dificultad
## acumulada está por debajo de la pedida, el transporte de bloques (que es todo empujar y tirar) va primero y puede repetirse. Las escaleras al final como último recurso.
func _module_order(techs: Array, _remaining: int) -> Array:
	var low := min_diff > 0.0 and total_moves > 0 and float(total_grabs) / float(total_moves) < min_diff
	var cands: Array = []
	for t in techs:
		if t != "escalera" and (int(used.get(t, 0)) < 2 or (t == "transporte" and int(used.get(t, 0)) < 5)):
			cands.append(t)
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	cands.sort_custom(func(a, b): return _order_key(a, low) < _order_key(b, low))
	if low:
		cands.erase("transporte")
		cands.push_front("transporte")
	if techs.has("escalera") or cands.is_empty():
		cands.append("escalera")
	return cands


func _order_key(t: String, low: bool) -> int:
	return int(used.get(t, 0)) + (3 if t == last_kind else 0) + (-2 if low and t == "transporte" else 0)


func _step(entry: Vector3i, exit: Vector3i, name: String, extra: Dictionary = {}) -> Dictionary:
	var s := StepLib.make_step(name, WINDOW, WINDOW, height)
	for x in WINDOW:
		for z in WINDOW:
			s.holes.append([x, z])   # sin piso: caerse es perder
	if with_core:
		for c in CORE_CELLS:
			for y in range(0, height + 1):
				s.fixed.append([c.x, y, c.y])
	var all := blocks.duplicate()
	for c in extra:
		all[c] = extra[c]
	for c in all:
		s.blocks.append([c.x, c.y, c.z, int(all[c])])
	s.entry = [entry.x, entry.y, entry.z]
	s.exit = [exit.x, exit.y, exit.z]
	return s


# --- módulos ----------------------------------------------------------------------------------------------------------------------

func _try_module(kind: String) -> bool:
	var best: Dictionary = {}
	var best_score := -1.0
	var found := 0
	for attempt in (200 if kind == "transporte" else 80):
		if found >= best_of:
			break
		var cand: Dictionary = _sample(kind)
		if cand.is_empty():
			continue
		tries[kind] = int(tries.get(kind, 0)) + 1
		var add: Dictionary = cand.add
		var new_pos: Vector3i = cand.new_pos
		var bad := false
		for c in add:
			if blocks.has(c) or air.has(c) or not _in_arena(c) or c.y > height - 1:
				bad = true
		if new_pos.y > height or bad:
			_no(kind, "fuera")
			continue
		# estable (sin la plataforma de salida fija que taparía un apoyo faltante)
		var stab := _step(start, Vector3i(7, 3, 7), "estable", add)
		if StepLib.validate(stab) != "" or not StepLib.unsupported_cells(stab).is_empty():
			_no(kind, "inestable")
			continue
		# se resuelve en el contexto de todo lo armado, y el especial hace falta
		var local := _step(pos, new_pos, kind, add)
		if StepLib.validate(local) != "":
			_no(kind, "invalida")
			continue
		var ev := StepLib.evaluate(local, eval_cap, 6000, true)
		if not bool(ev.ok) or int(ev.moves) > 45 or int(ev.moves) < 2:
			_no(kind, "sin_solucion" if not bool(ev.ok) else "largo")
			continue
		var special: int = int(cand.get("special", -1))
		if special >= 0 and not bool(ev.needed.get(special, false)):
			_no(kind, "especial_adorno")
			continue
		if int(ev.grabs) < int(cand.get("min_grabs", 0)):
			_no(kind, "pocos_empujes")
			continue
		if bool(cand.get("need_grab", false)) and int(ev.grabs) < 1:
			_no(kind, "sin_empujes")
			continue
		if float(cand.get("min_ratio", 0.0)) > 0.0 and float(ev.grabs) / maxf(float(ev.moves), 1.0) < float(cand.min_ratio):
			_no(kind, "poca_dificultad")
			continue
		if cand.has("need_present"):   # el puente de arenisca: sin esos bloques (nada) la sala no se resuelve igual
			var without := _step(pos, new_pos, kind, add)
			var kept: Array = []
			for b in without.blocks:
				if int(b[3]) != int(cand.need_present):
					kept.append(b)
			without.blocks = kept
			var ev2 := StepLib.evaluate(without, eval_cap, 4000, false)
			if bool(ev2.ok) and int(ev2.moves) <= int(ev.moves):
				_no(kind, "no_hace_falta")
				continue
		# y todo el camino desde el inicio sigue llegando
		var full_path: Array = path + ev.path
		var full := _step(start, new_pos, "sala", add)
		if not _replay_wins(full, full_path):
			_no(kind, "camino_roto")
			last_break = {"prev": path.size(), "local": ev.path.size(), "at": _replay_break(full, full_path), "kind": kind}
			continue
		found += 1
		var score := float(ev.grabs) / maxf(float(ev.moves), 1.0) * 10.0 + float(ev.grabs) * 0.01
		if score > best_score:
			best_score = score
			best = {"add": add, "new_pos": new_pos, "ev": ev, "full": full, "full_path": full_path}
	if best.is_empty():
		return false
	var ev: Dictionary = best.ev
	air = _record_air(best.full, best.full_path)
	for c in best.add:
		blocks[c] = best.add[c]
	path = best.full_path
	total_moves += int(ev.moves)
	total_grabs += int(ev.grabs)
	total_tech += int(ev.tech)
	modules.append({"kind": kind, "moves": int(ev.moves), "grabs": int(ev.grabs), "text": StepLib.describe(ev), "from": pos, "to": best.new_pos})
	pos = best.new_pos
	used[kind] = int(used.get(kind, 0)) + 1
	last_kind = kind
	return true


func _no(kind: String, why: String) -> void:
	var k := "%s:%s" % [kind, why]
	reasons[k] = int(reasons.get(k, 0)) + 1


func _in_arena(c: Vector3i) -> bool:
	return c.y >= 1 and arena.has(Vector2i(c.x, c.z))


func _replay_wins(step: Dictionary, actions: Array) -> bool:
	var t = StepLib.build_state(step)
	for a in actions:
		var r: Dictionary = t.try_action(a.dir, a.mode)
		if not r.ok or t.lost:
			return false
	return t.won


## Todas las celdas por las que pasa el jugador, o donde está algún bloque suelto, al repetir el camino.
func _record_air(step: Dictionary, actions: Array) -> Dictionary:
	var seen := {}
	var t = StepLib.build_state(step)
	for c in t.blocks:
		seen[c] = true
	seen[t.player] = true
	for a in actions:
		t.try_action(a.dir, a.mode)
		seen[t.player] = true
		for id in t.positions:
			seen[t.positions[id]] = true
	return seen


## En qué acción se rompe un camino al repetirlo (-1 si no se rompe antes del final).
func _replay_break(step: Dictionary, actions: Array) -> int:
	var t = StepLib.build_state(step)
	for i in actions.size():
		var r: Dictionary = t.try_action(actions[i].dir, actions[i].mode)
		if not r.ok or t.lost:
			return i
	return -1


func _dir() -> Vector3i:
	return DIRS[rng.randi_range(0, DIRS.size() - 1)]


## Cuántas celdas seguidas de la arena hay desde donde estás parado en la dirección `d` (sin contar la tuya).
func _room_along(d: Vector3i) -> int:
	var k := 0
	while arena.has(Vector2i(pos.x + d.x * (k + 1), pos.z + d.z * (k + 1))):
		k += 1
	return k


## Una fila de entre `min_n` y `max_n` celdas en una dirección que tenga lugar (y al menos `min_after` celdas más para los escalones): {d, n, after}. {} si ninguna dirección alcanza.
func _plan_row(min_n: int, max_n: int, min_after := 1) -> Dictionary:
	var order: Array = DIRS.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	for d in order:
		var avail := _room_along(d)
		var hi := mini(max_n, avail - min_after)
		if hi >= min_n:
			var n := rng.randi_range(min_n, hi)
			return {"d": d, "n": n, "after": avail - n}
	return {}


## Un módulo al azar de esa técnica: {add: {celda: tipo}, new_pos, special}. {} si esta muestra no tiene sentido.
func _sample(kind: String) -> Dictionary:
	# a veces el módulo empieza un paso al costado (por un bloque de conexión), para no pisar el camino de abajo
	var shift := Vector3i.ZERO
	if rng.randf() < 0.6:
		shift = _dir()
	if shift == Vector3i.ZERO:
		return _sample_here(kind)
	var base := pos + shift
	if not arena.has(Vector2i(base.x, base.z)) or air.has(base) or air.has(base + DOWN) or blocks.has(base + DOWN):
		return {}
	var saved := pos
	pos = base
	var cand := _sample_here(kind)
	pos = saved
	if cand.is_empty():
		return {}
	cand.add[base + DOWN] = K.NORMAL
	return cand


func _sample_here(kind: String) -> Dictionary:
	match kind:
		"trampolin":
			return _sample_catapult()
		"pinchos":
			return _sample_spikes()
		"hielo":
			return _sample_ice()
		"arenisca":
			return _sample_cracked()
		"transporte":
			return _sample_transport()
		"escalera":
			return _sample_stairs()
	return {}


## Trampolín: una catapulta pegada al lugar donde estás parado, y más arriba un borde (un bloque) al costado de la columna de lanzamiento, donde el jugador queda colgado y trepa.
func _sample_catapult() -> Dictionary:
	var d := _dir()
	var c := pos + d                       # la celda de la catapulta (a tu nivel)
	var ledge_y := pos.y + rng.randi_range(2, 5)
	var e := _dir()
	var g := Vector3i(c.x + e.x, ledge_y, c.z + e.z)
	if g == pos or e == Vector3i.ZERO:
		return {}
	return {"add": {c + DOWN: K.CATAPULT, g: K.NORMAL}, "new_pos": g + UP, "special": K.CATAPULT}


## Cornisa de pinchos: una fila de bloques a tu nivel (menos uno) con pinchos adentro, que no se puede cruzar por arriba: hay que colgarse del costado, avanzar por debajo y trepar del otro lado a un escalón.
func _sample_spikes() -> Dictionary:
	var plan := _plan_row(3, 5)
	if plan.is_empty():
		return {}
	var d: Vector3i = plan.d
	var n: int = plan.n
	var add := {}
	var spikes := rng.randi_range(1, 2)
	var spike_idx: Array = []
	for i in spikes:
		spike_idx.append(rng.randi_range(2, n - 1))
	for i in range(1, n + 1):
		add[pos + d * i + DOWN] = K.SPIKES if spike_idx.has(i) else K.NORMAL
	var top := _steps_after(add, pos + d * (n + 1), d, int(plan.after))
	return {"add": add, "new_pos": top + UP, "special": K.SPIKES}


## Camino de hielo: una fila de hielo a tu nivel que se patina de una vez hasta un bloque común, y un escalón.
func _sample_ice() -> Dictionary:
	var plan := _plan_row(3, 6)
	if plan.is_empty():
		return {}
	var d: Vector3i = plan.d
	var n: int = plan.n
	var add := {}
	for i in range(1, n):
		add[pos + d * i + DOWN] = K.ICE
	add[pos + d * n + DOWN] = K.NORMAL
	var top := _steps_after(add, pos + d * (n + 1), d, int(plan.after))
	return {"add": add, "new_pos": top + UP, "special": K.ICE}


## Puente de arenisca: una fila de bloques agrietados a tu nivel que se rompen al bajarte de ellos (se cruza una sola vez), y unos escalones. Hace falta si sin esos bloques no se llega.
func _sample_cracked() -> Dictionary:
	var plan := _plan_row(2, 5)
	if plan.is_empty():
		return {}
	var d: Vector3i = plan.d
	var n: int = plan.n
	var add := {}
	for i in range(1, n + 1):
		add[pos + d * i + DOWN] = K.CRACKED
	var top := _steps_after(add, pos + d * (n + 1), d, int(plan.after))
	return {"add": add, "new_pos": top + UP, "special": -1, "need_present": K.CRACKED}


## ¿La celda (x, z) está pegada al núcleo? (ahí los bloques se sostienen solos)
func _is_anchor(c: Vector2i) -> bool:
	return with_core and anchors.has(c)


## Transporte, de dos maneras: llevar un bloque suelto hasta un hueco de la fila (cae y lo tapa), o llevarlo hasta el pie de un escalón alto para usarlo de escalón. Hay que empujar y tirar varias veces.
func _sample_transport() -> Dictionary:
	return _sample_transport_gap() if rng.randf() < 0.5 else _sample_transport_stone()


## Un hueco en la fila con un bloque suelto sobre ella antes del hueco. Lo que queda del otro lado del hueco tiene que sostenerse solo: sólo vale si ahí hay una celda pegada al núcleo.
func _sample_transport_gap() -> Dictionary:
	var plan := _plan_row(4, 8)
	if plan.is_empty():
		return {}
	var d: Vector3i = plan.d
	var n: int = plan.n
	var gap := rng.randi_range(maxi(3, n - 2), n - 1)
	var anchored_far := false
	for i in range(gap + 1, n + 2):
		if _is_anchor(Vector2i(pos.x + d.x * i, pos.z + d.z * i)):
			anchored_far = true
	if not anchored_far:
		return {}
	var add := {}
	for i in range(1, n + 1):
		if i != gap:
			add[pos + d * i + DOWN] = K.NORMAL
	var loose: Array = [pos + d * 1]
	if rng.randf() < 0.3:
		var c2 := pos + d * rng.randi_range(1, gap - 1)
		if not loose.has(c2):
			loose.append(c2)
	for c in loose:
		add[c] = K.NORMAL
	var top := _steps_after(add, pos + d * (n + 1), d, int(plan.after))
	return {"add": add, "new_pos": top + UP, "need_grab": true, "min_grabs": transport_min_grabs, "min_ratio": transport_min_ratio}


## Una piedra: una fila continua, un escalón alto (dos pisos) al final al que no se llega trepando, y un bloque suelto sobre la fila que hay que llevar hasta el pie del escalón para trepar primero a él y después al escalón.
func _sample_transport_stone() -> Dictionary:
	var plan := _plan_row(3, 7, 1)
	if plan.is_empty():
		return {}
	var d: Vector3i = plan.d
	var n: int = plan.n                       # la fila llega hasta la celda n (a tu nivel menos uno)
	var add := {}
	for i in range(1, n + 1):
		add[pos + d * i + DOWN] = K.NORMAL
	var loose := pos + d * rng.randi_range(1, maxi(1, n - 2))   # sobre la fila
	add[loose] = K.NORMAL
	var s_cell := pos + d * (n + 1)           # el escalón de abajo, a tu nivel (apoya en la arista del último bloque de la fila)
	add[s_cell] = K.NORMAL
	var p_cell := s_cell + UP                 # el escalón alto, dos pisos más arriba que la fila
	add[p_cell] = K.NORMAL
	return {"add": add, "new_pos": p_cell + UP, "need_grab": true, "min_grabs": transport_min_grabs, "min_ratio": transport_min_ratio}


## De 1 a 3 escalones (cada uno un piso más alto y pegado al anterior) que empiezan en `first` (a tu nivel) y siguen en la dirección `d`; los agrega a `add` y devuelve el de más arriba.
func _steps_after(add: Dictionary, first: Vector3i, d: Vector3i, max_steps := 3) -> Vector3i:
	var n := rng.randi_range(1, maxi(1, mini(3, max_steps)))
	var top := first
	for i in n:
		top = first + d * i + UP * i
		add[top] = K.NORMAL
	return top


## Escalera: unos escalones seguidos (de 2 a 3 pisos), cada uno un piso más alto y pegado al anterior.
func _sample_stairs() -> Dictionary:
	var plan := _plan_row(2, 3, 0)
	if plan.is_empty():
		return {}
	var d: Vector3i = plan.d
	var n: int = plan.n
	var add := {}
	for i in range(1, n + 1):
		add[pos + d * i + UP * (i - 1)] = K.NORMAL
	var top := pos + d * n + UP * (n - 1)
	return {"add": add, "new_pos": top + UP}
