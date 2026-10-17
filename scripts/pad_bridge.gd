extends Node
## Puente del mando: traduce cada botón o eje del mando a la tecla de la acción que tiene asignada (ver controls.gd) y la inyecta como evento de
## teclado. Así todas las pantallas (que leen teclas) funcionan igual con teclado y con mando, y reasignar un botón es reasignar su tecla.
## En menús y juegos del casino (`nav_mode` verdadero) el stick izquierdo y la cruceta mueven con las flechas, que es lo que esas pantallas entienden.

const Controls := preload("res://scripts/controls.gd")

const PRESS_AT := 0.5
const RELEASE_AT := 0.35

## ¿Está en una pantalla de menú? (la decide el juego principal)
var nav_mode: Callable = func() -> bool: return false
## Qué teclas se apretaron por cada entrada del mando, para soltar las mismas aunque el modo haya cambiado entremedio.
var _down := {}


func _ready() -> void:
	# Godot ya mueve el foco de los menús con la cruceta y el stick (acciones ui_*); como acá se traducen a flechas, se quita eso para que cada movimiento cuente una sola vez
	# (si no, el foco avanza de a dos botones).
	for action in InputMap.get_actions():
		if not str(action).begins_with("ui_"):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				InputMap.action_erase_event(action, ev)
	Controls.using_pad = not Input.get_connected_joypads().is_empty()   # (con un mando conectado, las ayudas muestran sus botones desde el principio)
	Input.joy_connection_changed.connect(func(_id: int, connected: bool): Controls.using_pad = connected or not Input.get_connected_joypads().is_empty())


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			Controls.using_pad = false
		return
	if Controls.capturing:
		return
	if event is InputEventJoypadButton:
		Controls.using_pad = true
		_press(_name_of({"button": event.button_index}), {"button": event.button_index}, event.pressed)
	elif event is InputEventJoypadMotion:
		var v: float = event.axis_value
		for sgn in [-1, 1]:
			var p := {"axis": event.axis, "sign": sgn}
			var k := _name_of(p)
			var active: bool = _down.has(k)
			var mag: float = v * sgn
			if not active and mag >= PRESS_AT:
				Controls.using_pad = true
				_press(k, p, true)
			elif active and mag < RELEASE_AT:
				_press(k, p, false)


static func _name_of(p: Dictionary) -> String:
	return "b%d" % int(p.button) if p.has("button") else "a%d_%d" % [int(p.axis), int(p.sign)]


func _press(name: String, p: Dictionary, pressed: bool) -> void:
	var keys: Array = []
	if pressed:
		keys = _keys_now(p)
		if keys.is_empty():
			return
		_down[name] = keys
	else:
		keys = _down.get(name, [])
		_down.erase(name)
	for k in keys:
		_send(int(k), pressed)


func _keys_now(p: Dictionary) -> Array:
	if nav_mode.call():   # en menús y juegos valen los botones fijos (A confirma, B vuelve, X acción, Y cobra) y las flechas
		for f in Controls.PAD_FIXED:
			if Controls._same_pad(f.pad, p):
				return f.keys.duplicate()
		if _is_move(p):
			return [_arrow_for(p)]
	var out: Array[int] = Controls.keys_for_pad(p)
	return out


## ¿Es el stick izquierdo o la cruceta?
static func _is_move(p: Dictionary) -> bool:
	if p.has("button"):
		return int(p.button) in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]
	return int(p.axis) in [Controls.AXIS_LX, Controls.AXIS_LY]


static func _arrow_for(p: Dictionary) -> int:
	if p.has("button"):
		match int(p.button):
			JOY_BUTTON_DPAD_UP: return KEY_UP
			JOY_BUTTON_DPAD_DOWN: return KEY_DOWN
			JOY_BUTTON_DPAD_LEFT: return KEY_LEFT
			_: return KEY_RIGHT
	if int(p.axis) == Controls.AXIS_LX:
		return KEY_RIGHT if int(p.sign) > 0 else KEY_LEFT
	return KEY_DOWN if int(p.sign) > 0 else KEY_UP


static func _send(code: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code as Key
	e.physical_keycode = code as Key
	e.pressed = pressed
	Input.parse_input_event(e)
