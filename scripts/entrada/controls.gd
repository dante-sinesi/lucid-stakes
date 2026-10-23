extends RefCounted
## Controles: las acciones del juego (mover, empujar, colgarse, cámara, consumibles...) tienen nombre, una tecla y una entrada del mando, y se
## reasignan en Opciones (se guardan en Settings, clave "bindings").
## El mando se integra con `PadBridge`: cada botón o eje del mando se traduce a la tecla de la acción que tiene asignada, así todas las
## pantallas del juego (que leen teclas) funcionan igual con teclado y con mando.
## `action_of(event)` dice qué acción reasignable es una tecla; `key_of(id)` la tecla actual de una acción.

const Settings := preload("res://scripts/datos/settings.gd")
const Loc := preload("res://scripts/idioma/loc.gd")

## Ejes del mando (los números de Godot): stick izquierdo 0/1, derecho 2/3, gatillos 4/5.
const AXIS_LX := 0
const AXIS_LY := 1
const AXIS_RX := 2
const AXIS_RY := 3
const AXIS_LT := 4
const AXIS_RT := 5

## Reasignables. key: tecla por defecto; pad: lista de entradas del mando por defecto ({"button": n} o {"axis": n, "sign": ±1}).
const ACTIONS: Array[Dictionary] = [
	{"id": "mover_adelante", "name": "Mover adelante", "group": "Movimiento", "key": KEY_W, "pad": [{"axis": AXIS_LY, "sign": -1}, {"button": JOY_BUTTON_DPAD_UP}]},
	{"id": "mover_derecha", "name": "Mover a la derecha", "group": "Movimiento", "key": KEY_D, "pad": [{"axis": AXIS_LX, "sign": 1}, {"button": JOY_BUTTON_DPAD_RIGHT}]},
	{"id": "mover_atras", "name": "Mover hacia atrás", "group": "Movimiento", "key": KEY_S, "pad": [{"axis": AXIS_LY, "sign": 1}, {"button": JOY_BUTTON_DPAD_DOWN}]},
	{"id": "mover_izquierda", "name": "Mover a la izquierda", "group": "Movimiento", "key": KEY_A, "pad": [{"axis": AXIS_LX, "sign": -1}, {"button": JOY_BUTTON_DPAD_LEFT}]},
	{"id": "empujar", "name": "Empujar o tirar (mantener)", "group": "Acciones", "key": KEY_SHIFT, "pad": [{"axis": AXIS_LT, "sign": 1}]},
	{"id": "colgarse", "name": "Colgarse (mantener)", "group": "Acciones", "key": KEY_SPACE, "pad": [{"button": JOY_BUTTON_X}]},
	{"id": "deshacer", "name": "Deshacer el último movimiento", "group": "Acciones", "key": KEY_Z, "pad": []},
	{"id": "reintentar", "name": "Reintentar la torre", "group": "Acciones", "key": KEY_R, "pad": [{"button": JOY_BUTTON_BACK}]},
	{"id": "consumible_1", "name": "Usar consumible 1", "group": "Consumibles", "key": KEY_1, "pad": []},
	{"id": "consumible_2", "name": "Usar consumible 2", "group": "Consumibles", "key": KEY_2, "pad": []},
	{"id": "consumible_3", "name": "Usar consumible 3", "group": "Consumibles", "key": KEY_3, "pad": []},
	{"id": "consumible_4", "name": "Usar consumible 4", "group": "Consumibles", "key": KEY_4, "pad": []},
	{"id": "consumible_usar", "name": "Usar el consumible elegido (mantener y arriba o abajo para elegir)", "group": "Consumibles", "key": KEY_G, "pad": [{"axis": AXIS_RT, "sign": 1}]},
	{"id": "camara_izquierda", "name": "Girar la cámara a la izquierda", "group": "Cámara", "key": KEY_LEFT, "pad": [{"axis": AXIS_RX, "sign": -1}]},
	{"id": "camara_derecha", "name": "Girar la cámara a la derecha", "group": "Cámara", "key": KEY_RIGHT, "pad": [{"axis": AXIS_RX, "sign": 1}]},
	{"id": "camara_arriba", "name": "Inclinar la cámara hacia arriba", "group": "Cámara", "key": KEY_UP, "pad": [{"axis": AXIS_RY, "sign": -1}]},
	{"id": "camara_abajo", "name": "Inclinar la cámara hacia abajo", "group": "Cámara", "key": KEY_DOWN, "pad": [{"axis": AXIS_RY, "sign": 1}]},
	{"id": "vista_izquierda", "name": "Vista isométrica, girar a la izquierda", "group": "Cámara", "key": KEY_Q, "pad": [{"button": JOY_BUTTON_LEFT_SHOULDER}]},
	{"id": "vista_derecha", "name": "Vista isométrica, girar a la derecha", "group": "Cámara", "key": KEY_E, "pad": [{"button": JOY_BUTTON_RIGHT_SHOULDER}]},
	{"id": "zoom_mas", "name": "Acercar la cámara", "group": "Cámara", "key": KEY_EQUAL, "pad": [{"button": JOY_BUTTON_RIGHT_STICK}]},
	{"id": "zoom_menos", "name": "Alejar la cámara", "group": "Cámara", "key": KEY_MINUS, "pad": [{"button": JOY_BUTTON_LEFT_STICK}]},
	{"id": "profundidad", "name": "Cambiar la ayuda de profundidad", "group": "Cámara", "key": KEY_V, "pad": []},
	{"id": "pausa", "name": "Pausa", "group": "Interfaz", "key": KEY_ESCAPE, "pad": [{"button": JOY_BUTTON_START}]},
]

## Entradas del mando que no son de una acción reasignable: valen siempre. {entrada: teclas que se sintetizan}
const PAD_FIXED := [
	{"pad": {"button": JOY_BUTTON_A}, "keys": [KEY_SPACE]},   # (en los menús: Espacio confirma, Shift es la decisión secundaria, Esc vuelve)
	{"pad": {"button": JOY_BUTTON_B}, "keys": [KEY_ESCAPE]},
	{"pad": {"button": JOY_BUTTON_X}, "keys": [KEY_SHIFT]},
	{"pad": {"axis": AXIS_LT, "sign": 1}, "keys": [KEY_R]},   # (rotar la vitrina)
	{"pad": {"button": JOY_BUTTON_Y}, "keys": [KEY_C]},
	{"pad": {"button": JOY_BUTTON_BACK}, "keys": [KEY_H]},   # Select: la ayuda del juego (en la torre sigue siendo reintentar)
	{"pad": {"button": JOY_BUTTON_DPAD_UP}, "keys": [KEY_UP]},
	{"pad": {"button": JOY_BUTTON_DPAD_DOWN}, "keys": [KEY_DOWN]},
	{"pad": {"button": JOY_BUTTON_DPAD_LEFT}, "keys": [KEY_LEFT]},
	{"pad": {"button": JOY_BUTTON_DPAD_RIGHT}, "keys": [KEY_RIGHT]},
]

## Mientras se espera una tecla o botón nuevo en Opciones, el puente del mando no traduce nada.
static var capturing := false
## ¿Lo último que se usó fue el mando? (los textos de ayuda muestran los nombres de los botones o de las teclas)
static var using_pad := false
## Lo que detecta el puente del mando: ¿lo último que se tocó fue el mando? (con "auto" las ayudas lo siguen; con "teclado" o "mando" en Opciones no importa)
static var detected_pad := false


## El puente avisa qué dispositivo se usó último; `using_pad` sigue la elección del jugador en Opciones (automático, teclado o mando).
static func set_pad_detected(on: bool) -> void:
	detected_pad = on
	apply_device()


static func apply_device() -> void:
	match str(Settings.get_value("input_device")):
		"keyboard":
			using_pad = false
		"pad":
			using_pad = true
		_:
			using_pad = detected_pad
## Los cambios del jugador sobre lo de fábrica: {id: {"key": código, "pad": {"button": n} | {"axis": n, "sign": ±1}}}.
static var overrides := {}
static var _loaded := false


static func get_action(id: String) -> Dictionary:
	for a in ACTIONS:
		if a.id == id:
			return a
	return {}


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var saved = Settings.get_value("bindings")
	overrides = (saved as Dictionary).duplicate(true) if saved is Dictionary else {}


## Qué acción reasignable es esta tecla apretada ("" si ninguna). Mira la tecla y, si no, la tecla física.
static func action_of(event: InputEventKey) -> String:
	ensure()
	for a in ACTIONS:
		var k := key_of(str(a.id))
		if event.keycode == k or event.physical_keycode == k:
			return str(a.id)
	return ""


## ¿El evento es esa acción recién apretada (sin repeticiones)?
static func hit(event: InputEvent, id: String) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and action_of(event) == id


## ¿Se mantiene apretada la tecla de esa acción?
static func held(id: String) -> bool:
	ensure()
	var k := key_of(id)
	return Input.is_key_pressed(k as Key) or Input.is_physical_key_pressed(k as Key)


## ¿Se mantiene la acción `id` (por ejemplo "empujar", que por defecto es Shift)? Además de las teclas apretadas, mira los modificadores del
## propio evento (así vale también para eventos armados a mano en las pruebas).
static func modifier_held(event: InputEvent, id: String) -> bool:
	if held(id):
		return true
	if event is InputEventKey:
		match key_of(id):
			KEY_SHIFT:
				return (event as InputEventKey).shift_pressed
			KEY_CTRL:
				return (event as InputEventKey).ctrl_pressed
			KEY_ALT:
				return (event as InputEventKey).alt_pressed
	return false


## La tecla asignada hoy a una acción reasignable.
static func key_of(id: String) -> int:
	ensure()
	var a := get_action(id)
	if a.is_empty():
		return KEY_NONE
	return int((overrides.get(id, {}) as Dictionary).get("key", a.key))


## La entrada del mando asignada hoy a una acción reasignable (la primera): {} si no tiene.
static func pad_of(id: String) -> Dictionary:
	var l := pads_of(id)
	return l[0] if not l.is_empty() else {}


## Todas las entradas del mando de una acción (de fábrica puede tener varias, por ejemplo stick y cruceta; reasignada, una sola).
static func pads_of(id: String) -> Array:
	ensure()
	var a := get_action(id)
	if a.is_empty():
		return []
	var ov: Dictionary = overrides.get(id, {})
	if ov.has("pad"):
		return [ov.pad] if not (ov.pad as Dictionary).is_empty() else []
	return a.pad


# --- nombres para mostrar -------------------------------------------------------------------------------------------------------

static func key_name(code: int) -> String:
	if code == KEY_NONE:
		return "-"
	return OS.get_keycode_string(code as Key)


const BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_BACK: "Select", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "Cruceta arriba", JOY_BUTTON_DPAD_DOWN: "Cruceta abajo", JOY_BUTTON_DPAD_LEFT: "Cruceta izquierda", JOY_BUTTON_DPAD_RIGHT: "Cruceta derecha",
}
const AXIS_NAMES := {AXIS_LX: "Stick izq.", AXIS_LY: "Stick izq.", AXIS_RX: "Stick der.", AXIS_RY: "Stick der.", AXIS_LT: "LT", AXIS_RT: "RT"}


static func pad_name(p: Dictionary) -> String:
	if p.is_empty():
		return "-"
	if p.has("button"):
		var bn: String = BUTTON_NAMES.get(int(p.button), "")
		return Loc.literal(Loc.t(bn) if bn.begins_with("Cruceta") else (bn if bn != "" else "B%d" % int(p.button)))
	var axis := int(p.axis)
	var base: String = AXIS_NAMES.get(axis, "")
	var out := (Loc.t(base) if base.begins_with("Stick") else base) if base != "" else "Eje %d" % axis
	match axis:
		AXIS_LX, AXIS_RX:
			out += " " + (Loc.t("izquierda") if int(p.sign) < 0 else Loc.t("derecha"))
		AXIS_LY, AXIS_RY:
			out += " " + (Loc.t("arriba") if int(p.sign) < 0 else Loc.t("abajo"))
	return Loc.literal(out)


# --- reasignar ---------------------------------------------------------------------------------------------------------------

## Asigna una tecla a la acción `id`. Si otra acción reasignable ya la usaba, se la cambian (se intercambian las teclas). Devuelve la acción
## con la que se intercambió ("" si no hubo).
static func rebind_key(id: String, code: int) -> String:
	ensure()
	var swapped := ""
	var old := key_of(id)
	for a in ACTIONS:
		if str(a.id) != id and key_of(str(a.id)) == code:
			_set_override(str(a.id), "key", old)
			swapped = str(a.id)
	_set_override(id, "key", code)
	_save()
	return swapped


## Asigna un botón o eje del mando (`p`: {"button": n} o {"axis": n, "sign": ±1}). Igual que rebind_key: intercambia si estaba usado.
static func rebind_pad(id: String, p: Dictionary) -> String:
	ensure()
	var swapped := ""
	var old := pad_of(id)
	for a in ACTIONS:
		if str(a.id) == id:
			continue
		var uses := false
		for q in pads_of(str(a.id)):
			if _same_pad(q, p):
				uses = true
		if uses:
			_set_override(str(a.id), "pad", old)
			swapped = str(a.id)
	_set_override(id, "pad", p)
	_save()
	return swapped


static func _set_override(id: String, field: String, value) -> void:
	var ov: Dictionary = overrides.get(id, {})
	ov[field] = value
	overrides[id] = ov


static func _save() -> void:
	Settings.set_value("bindings", overrides.duplicate(true))


## Vuelve todo a los controles de fábrica.
static func reset_all() -> void:
	ensure()
	overrides = {}
	_save()


## Vuelve una sola acción a lo de fábrica.
static func reset_action(id: String) -> void:
	ensure()
	overrides.erase(id)
	_save()


## Qué teclas hay que sintetizar cuando el mando aprieta esa entrada (`p`: {"button"} o {"axis","sign"}): las de las acciones que la usan
## más, si ninguna la usa, las fijas.
static func keys_for_pad(p: Dictionary) -> Array[int]:
	ensure()
	var out: Array[int] = []
	for a in ACTIONS:
		var hit_pad := false
		for q in pads_of(str(a.id)):
			if _same_pad(q, p):
				hit_pad = true
		if hit_pad:
			var k := key_of(str(a.id))
			if k != KEY_NONE and not out.has(k):
				out.append(k)
	if out.is_empty():
		for f in PAD_FIXED:
			if _same_pad(f.pad, p):
				for k in f.keys:
					if not out.has(k):
						out.append(k)
	return out


static func _same_pad(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	if a.has("button") != b.has("button"):
		return false
	if a.has("button"):
		return int(a.button) == int(b.button)
	return int(a.axis) == int(b.axis) and int(a.sign) == int(b.sign)
