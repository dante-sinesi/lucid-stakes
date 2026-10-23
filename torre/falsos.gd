extends RefCounted
## Movimientos en falso en la torre nueva (el escenario "Sin piedad"): en cada sala, un movimiento es "en falso" si después de hacerlo faltan MÁS pasos para salir de la sala
## que antes de hacerlo (según el solucionador nativo exacto, desde el estado de la sala). Explorar un callejón, empujar un bloque que no ayuda o dejar la sala sin salida cuentan;
## volver sobre los pasos no se castiga dos veces. Cada sala permite `permitidos` en falso; el siguiente se cuenta como `agotado` (la sala se pierde como si se hubiera caído).
## El solucionador corre en un hilo aparte (un trabajo por movimiento, en orden); el resultado vuelve al juego unos instantes después. En las pruebas, `inline` lo resuelve en el momento.

signal falso(cuenta: int, permitidos: int, sin_salida: bool)
signal agotado

const Nat := preload("res://torre/nativo.gd")

const SIN_SALIDA := 1 << 20   # distancia de una sala sin salida
const TOPE := 250000          # estados que se le dejan gastar al solucionador por movimiento

var permitidos := 0
var activo := false
var cuenta := 0       # movimientos en falso que lleva la sala actual
var inline := false   # pruebas: sin hilo
var _ref := -1        # pasos que faltaban en la última medición de la sala
var _epoca := 0
var _cola: Array = []
var _mutex := Mutex.new()
var _sem := Semaphore.new()
var _hilo: Thread = null
var _parar := false


func configurar(n: int) -> void:
	permitidos = n
	activo = n > 0
	_epoca += 1
	cuenta = 0
	_ref = -1
	if activo and not inline and _hilo == null:
		_parar = false
		_hilo = Thread.new()
		_hilo.start(_trabajo)


func quedan() -> int:
	return maxi(permitidos - cuenta, 0)


## Empieza (o vuelve a empezar) una sala: la cuenta vuelve a cero y se mide el estado de partida.
func sala_nueva(motor) -> void:
	_epoca += 1
	cuenta = 0
	_ref = -1
	_mutex.lock()
	_cola.clear()
	_mutex.unlock()
	medir(motor)


## Se mide el estado actual sin contar nada (al empezar la sala o después de deshacer).
func medir(motor) -> void:
	_enviar(motor, false)


## Se hizo un movimiento: se mide el estado nuevo y, si faltan más pasos que antes, cuenta como falso.
func despues_de_mover(motor) -> void:
	_enviar(motor, true)


func _enviar(motor, contar: bool) -> void:
	if not activo or motor == null or motor.perdido or motor.ganado:
		return
	var trabajo := {"epoca": _epoca, "motor": motor.duplicar(), "contar": contar}
	if inline:
		_aplicar(int(trabajo.epoca), _distancia(trabajo.motor), contar)
		return
	_mutex.lock()
	_cola.append(trabajo)
	_mutex.unlock()
	_sem.post()


## Cuántos pasos faltan para salir de la sala desde ese estado: -1 si no se pudo medir (se acabó el tope), SIN_SALIDA si no hay salida.
func _distancia(motor) -> int:
	var r: Dictionary = Nat.resolver(motor, TOPE)
	if bool(r.ok):
		return int(r.moves)
	if bool(r.get("tope", false)):
		return -1
	return SIN_SALIDA


func _trabajo() -> void:
	while true:
		_sem.wait()
		if _parar:
			return
		_mutex.lock()
		var t = _cola.pop_front() if not _cola.is_empty() else null
		_mutex.unlock()
		if t == null or int(t.epoca) != _epoca:
			continue
		var d := _distancia(t.motor)
		call_deferred("_aplicar", int(t.epoca), d, bool(t.contar))


## Llega una medición (en orden): se compara con la anterior de la sala.
func _aplicar(epoca: int, d: int, contar: bool) -> void:
	if epoca != _epoca or not activo:
		return
	var antes := _ref
	_ref = d
	if not contar or d < 0 or antes < 0:   # (una medición sin contar: al empezar la sala o después de deshacer)
		return
	if d > antes:
		cuenta += 1
		falso.emit(cuenta, permitidos, d >= SIN_SALIDA)
		if cuenta > permitidos:
			agotado.emit()


func apagar() -> void:
	activo = false
	_epoca += 1


## Termina el hilo (al sacar la torre).
func cerrar() -> void:
	activo = false
	_epoca += 1
	if _hilo != null:
		_parar = true
		_sem.post()
		_hilo.wait_to_finish()
		_hilo = null
