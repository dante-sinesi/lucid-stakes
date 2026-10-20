extends RefCounted
## Movimientos en falso (el escenario "Sin piedad"): en cada sala, un movimiento es "en falso" si después de hacerlo faltan MÁS pasos para salir de la sala que antes de hacerlo
## (según el solucionador exacto, desde el estado de la torre). Explorar un callejón, empujar un bloque que no ayuda o dejar la sala sin salida cuentan; volver sobre tus pasos
## no se castiga dos veces. Cada sala permite `allowed` en falso (2, o 3 con la habilidad); el siguiente se cuenta como `exhausted`.
## El solucionador corre en un hilo aparte (un trabajo por movimiento, en orden); el resultado vuelve al juego unos instantes después. En las pruebas, `inline` lo resuelve en el momento.

signal mistake(count: int, allowed: int, room: int, dead_end: bool)
signal exhausted(room: int)

const Solver := preload("res://scripts/solver.gd")

const DEAD := 1 << 20     # distancia de una sala sin salida
const MAX_STATES := 200000
const MAX_MS := 1500

var rooms: Array = []     # [{ey, h}] en orden de altura: de dónde a dónde llega cada sala
var allowed := 2
var inline := false       # pruebas: sin hilo
var active := false
var counts := {}          # sala -> movimientos en falso que lleva
var _ref := {}            # sala -> pasos que faltaban en la última medición
var _last_room := -1
var _epoch := 0
var _final_goal := 0
var _queue: Array = []
var _mutex := Mutex.new()
var _sem := Semaphore.new()
var _thread: Thread = null
var _stop := false


## Arranca una torre (o un reintento): las salas con sus alturas, cuántos falsos se permiten y la altura de la meta de toda la torre.
func setup(room_list: Array, allowed_n: int, final_goal_y: int) -> void:
	_epoch += 1
	rooms = []
	for r in room_list:
		rooms.append({"ey": int(r.ey), "h": int(r.h)})
	rooms.sort_custom(func(a, b): return a.ey < b.ey)
	allowed = allowed_n
	_final_goal = final_goal_y
	counts.clear()
	_ref.clear()
	_last_room = -1
	_mutex.lock()
	_queue.clear()
	_mutex.unlock()
	active = not rooms.is_empty()
	if active and not inline and _thread == null:
		_stop = false
		_thread = Thread.new()
		_thread.start(_worker)


func disable() -> void:
	_epoch += 1
	active = false
	_mutex.lock()
	_queue.clear()
	_mutex.unlock()


## Termina el hilo (al salir del juego o de la torre).
func shutdown() -> void:
	active = false
	_epoch += 1
	if _thread != null:
		_stop = true
		_sem.post()
		_thread.wait_to_finish()
		_thread = null


## Cuántos falsos le quedan al jugador en esa sala.
func left(room: int) -> int:
	return maxi(allowed - int(counts.get(room, 0)), 0)


## La sala (por posición en `rooms`) donde está parado el jugador.
func room_of(y: int) -> int:
	var idx := 0
	for i in rooms.size():
		if int(rooms[i].ey) <= y:
			idx = i
	return idx


## Se mide el estado actual (sin contar nada): al empezar o reintentar, y después de deshacer.
func measure(logic) -> void:
	_submit(logic, false)


## Se hizo un movimiento: se mide el estado nuevo y, si faltan más pasos que antes, cuenta como falso.
func after_move(logic) -> void:
	_submit(logic, true)


func _submit(logic, _count: bool) -> void:
	if not active or logic == null or logic.lost or logic.won:
		return
	var idx := room_of(logic.player.y)
	var target: int = int(rooms[idx].ey) + int(rooms[idx].h)
	if idx + 1 >= rooms.size():
		target = _final_goal
	var job := {"epoch": _epoch, "room": idx, "target": target, "ey": int(rooms[idx].ey), "state": logic.clone()}
	if inline:
		_apply(job.epoch, idx, _distance(job))
		return
	_mutex.lock()
	_queue.append(job)
	_mutex.unlock()
	_sem.post()


## Cuántos pasos faltan para llegar a la altura `target` (el piso de la sala que sigue) desde ese estado: -1 si no se pudo medir a tiempo, DEAD si no hay salida.
func _distance(job: Dictionary) -> int:
	var res: Dictionary = Solver.solve(_trim(job.state, int(job.get("ey", 0)), int(job.target)), int(job.target), {"max_states": MAX_STATES, "max_ms": MAX_MS, "admissible": true})
	if res.status == "solved":
		return int(res.moves)
	if res.status == "unsolvable":
		return DEAD
	return -1


## El estado reducido a lo que importa para salir de esa sala: sin los bloques de más arriba (de las salas que siguen) y con los de más abajo (las salas que ya pasaste) fijos.
## Con la torre entera el solucionador gasta decenas de veces más estados moviendo bloques que no sirven para esta sala.
func _trim(state, ey: int, target: int):
	var t = state.clone()
	for c in t.blocks.keys():
		if c.y > target + 1:
			t._remove_block(c)
		elif c.y < ey - 1:
			t.fixed[c] = true
	return t


func _worker() -> void:
	while true:
		_sem.wait()
		if _stop:
			return
		_mutex.lock()
		var job = _queue.pop_front() if not _queue.is_empty() else null
		_mutex.unlock()
		if job == null:
			continue
		if int(job.epoch) != _epoch:
			continue
		var d := _distance(job)
		call_deferred("_apply", int(job.epoch), int(job.room), d)


## Llega una medición (en orden): se compara con la anterior de la misma sala.
func _apply(epoch: int, room: int, d: int) -> void:
	if epoch != _epoch or not active:
		return
	var prev: int = int(_ref.get(room, -1))
	var same_room := room == _last_room
	_last_room = room
	_ref[room] = d
	if d < 0 or prev < 0 or not same_room:
		return
	if d > prev:
		counts[room] = int(counts.get(room, 0)) + 1
		var n: int = counts[room]
		mistake.emit(n, allowed, room, d >= DEAD)
		if n > allowed:
			exhausted.emit(room)
