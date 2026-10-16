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
const ALL_TECHNIQUES := ["trampolin", "pinchos", "hielo", "transporte", "escalera"]

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
var tries := {}
var eval_cap := 250000


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
	var cells: Array = anchors if not anchors.is_empty() else arena.keys()
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
	var step := _step(start, pos, "Torre %s de %d pisos" % [shape, pos.y - 1])
	step.note = "Módulos: " + " → ".join(modules.map(func(m): return str(m.kind)))
	StepLib.finalize(step)
	return {"step": step, "path": path, "modules": modules}


## El orden en que se prueban las técnicas en este piso: las menos usadas primero (al azar entre las empatadas), sin repetir la del módulo anterior, a lo sumo dos veces cada una, y las escaleras al final como último recurso.
func _module_order(techs: Array, _remaining: int) -> Array:
	var cands: Array = []
	for t in techs:
		if t != "escalera" and int(used.get(t, 0)) < 2:
			cands.append(t)
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	cands.sort_custom(func(a, b): return int(used.get(a, 0)) + (3 if a == last_kind else 0) < int(used.get(b, 0)) + (3 if b == last_kind else 0))
	if techs.has("escalera") or cands.is_empty():
		cands.append("escalera")
	return cands


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
	for attempt in 60:
		var cand: Dictionary = _sample(kind)
		if cand.is_empty():
			continue
		tries[kind] = int(tries.get(kind, 0)) + 1
		var add: Dictionary = cand.add
		var new_pos: Vector3i = cand.new_pos
		var bad := false
		for c in add:
			if blocks.has(c) or not _in_arena(c) or c.y > height - 1:
				bad = true
		if new_pos.y > height or bad:
			continue
		# estable (sin la plataforma de salida fija que taparía un apoyo faltante)
		var stab := _step(start, Vector3i(7, 3, 7), "estable", add)
		if StepLib.validate(stab) != "" or not StepLib.unsupported_cells(stab).is_empty():
			continue
		# se resuelve en el contexto de todo lo armado, y el especial hace falta
		var local := _step(pos, new_pos, kind, add)
		if StepLib.validate(local) != "":
			continue
		var ev := StepLib.evaluate(local, eval_cap, 6000, true)
		if not bool(ev.ok) or int(ev.moves) > 45 or int(ev.moves) < 2:
			continue
		var special: int = int(cand.get("special", -1))
		if special >= 0 and not bool(ev.needed.get(special, false)):
			continue
		if bool(cand.get("need_grab", false)) and int(ev.grabs) < 1:
			continue
		# y todo el camino desde el inicio sigue llegando
		var full_path: Array = path + ev.path
		var full := _step(start, new_pos, "sala", add)
		if not _replay_wins(full, full_path):
			continue
		for c in add:
			blocks[c] = add[c]
		path = full_path
		modules.append({"kind": kind, "moves": int(ev.moves), "grabs": int(ev.grabs), "text": StepLib.describe(ev), "from": pos, "to": new_pos})
		pos = new_pos
		used[kind] = int(used.get(kind, 0)) + 1
		last_kind = kind
		return true
	return false


func _in_arena(c: Vector3i) -> bool:
	return c.y >= 1 and arena.has(Vector2i(c.x, c.z))


func _replay_wins(step: Dictionary, actions: Array) -> bool:
	var t = StepLib.build_state(step)
	for a in actions:
		var r: Dictionary = t.try_action(a.dir, a.mode)
		if not r.ok or t.lost:
			return false
	return t.won


func _dir() -> Vector3i:
	return DIRS[rng.randi_range(0, DIRS.size() - 1)]


## Un módulo al azar de esa técnica: {add: {celda: tipo}, new_pos, special}. {} si esta muestra no tiene sentido.
func _sample(kind: String) -> Dictionary:
	match kind:
		"trampolin":
			return _sample_catapult()
		"pinchos":
			return _sample_spikes()
		"hielo":
			return _sample_ice()
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
	var d := _dir()
	var n := rng.randi_range(3, 5)
	var add := {}
	var spikes := rng.randi_range(1, 2)
	var spike_idx: Array = []
	for i in spikes:
		spike_idx.append(rng.randi_range(2, n - 1))
	for i in range(1, n + 1):
		add[pos + d * i + DOWN] = K.SPIKES if spike_idx.has(i) else K.NORMAL
	var top := _steps_after(add, pos + d * (n + 1), d)
	return {"add": add, "new_pos": top + UP, "special": K.SPIKES}


## Camino de hielo: una fila de hielo a tu nivel que se patina de una vez hasta un bloque común, y un escalón.
func _sample_ice() -> Dictionary:
	var d := _dir()
	var n := rng.randi_range(3, 6)
	var add := {}
	for i in range(1, n):
		add[pos + d * i + DOWN] = K.ICE
	add[pos + d * n + DOWN] = K.NORMAL
	var top := _steps_after(add, pos + d * (n + 1), d)
	return {"add": add, "new_pos": top + UP, "special": K.ICE}


## Transporte: una fila de bloques a tu nivel con un hueco, y un bloque suelto sobre la fila delante tuyo: hay que empujarlo hasta el hueco (cae y lo tapa) para poder pasar.
func _sample_transport() -> Dictionary:
	var d := _dir()
	var n := rng.randi_range(4, 6)
	var gap := rng.randi_range(3, n - 1)
	var add := {}
	for i in range(1, n + 1):
		if i != gap:
			add[pos + d * i + DOWN] = K.NORMAL
	add[pos + d + Vector3i.ZERO] = K.NORMAL   # el bloque suelto sobre la fila, delante tuyo
	var top := _steps_after(add, pos + d * (n + 1), d)
	return {"add": add, "new_pos": top + UP, "need_grab": true}


## De 1 a 3 escalones (cada uno un piso más alto y pegado al anterior) que empiezan en `first` (a tu nivel) y siguen en la dirección `d`; los agrega a `add` y devuelve el de más arriba.
func _steps_after(add: Dictionary, first: Vector3i, d: Vector3i) -> Vector3i:
	var n := rng.randi_range(1, 3)
	var top := first
	for i in n:
		top = first + d * i + UP * i
		add[top] = K.NORMAL
	return top


## Escalera: unos escalones seguidos (de 2 a 3 pisos), cada uno un piso más alto y pegado al anterior.
func _sample_stairs() -> Dictionary:
	var d := _dir()
	var n := rng.randi_range(2, 3)
	var add := {}
	for i in range(1, n + 1):
		add[pos + d * i + UP * (i - 1)] = K.NORMAL
	var top := pos + d * n + UP * (n - 1)
	return {"add": add, "new_pos": top + UP}
