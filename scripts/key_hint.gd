extends Control
## La ayuda del tutorial, arriba en el centro de la pantalla: una frase simple con las teclas dibujadas adentro, por ejemplo
## "Mantén [Shift] y pulsa [W] [A] [S] [D]". Las teclas están grises y se ponen doradas a medida que el jugador las usa bien.
## El texto lleva palabras sueltas y teclas entre llaves: {empujar} (Shift), {colgarse} (Espacio), {mover_adelante}... (WASD), {camara_arriba}... (flechas).
## Una tecla con `?` ({?mover_atras}) se dibuja pero no es obligatoria. Cuando todas las obligatorias están doradas se emite `completed`.
## `mode` dice qué cuenta como usarlas: "move" (caminar), "camera" (girar la cámara), "push" (empujar un bloque con Shift), "pull" (tirar de un bloque con Shift),
## "grab" (cualquiera de los dos) y "hang" (colgarse con Espacio).
## Con el mando (Controles > Ayudas de: Mando, o Automático y el último dispositivo fue el mando) las teclas se dibujan como botones del mando: el stick izquierdo para caminar, el derecho para la
## cámara, un gatillo o botón de cara para empujar y colgarse. Los cuatro movimientos de cada grupo se juntan en un solo stick con una flecha por dirección que se dora al usarla.
## Los nombres de las teclas son los de los controles que tenga el jugador. `note(action, mode)` lo avisa main.gd con cada movimiento que salió bien.

const Draw := preload("res://scripts/voxel_draw.gd")
const VFont := preload("res://scripts/voxel_font.gd")
const Controls := preload("res://scripts/controls.gd")
const PadGlyph := preload("res://scripts/pad_glyph.gd")
const Loc := preload("res://scripts/loc.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")

signal completed

const KEY_H := 50.0     # alto de una tecla
const KEY_W := 50.0     # ancho de una tecla común
const GAP := 12.0
const CUBE := 3.0       # cubito de las letras de la frase
const MOVES := ["mover_adelante", "mover_izquierda", "mover_atras", "mover_derecha"]
const CAMERA := ["camara_arriba", "camara_izquierda", "camara_abajo", "camara_derecha"]

const GREY := Color(0.34, 0.34, 0.38)
const GREY_RIM := Color(0.72, 0.72, 0.78)
const GOLD_PLATE := Color(0.58, 0.40, 0.08)

var text := ""
var mode := ""
var pieces: Array = []      # [{"word": String} | {"key": id, "required": bool}]
var pressed := {}           # id de tecla -> true (dorada)
var _pop := {}
var _done_emitted := false


func _init() -> void:
	name = "ayuda"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	offset_left = -560.0
	offset_right = 560.0
	offset_top = 64.0
	offset_bottom = offset_top + KEY_H + 36.0


func _process(delta: float) -> void:
	if not visible:
		return
	for k in _pop:
		_pop[k] += delta
	queue_redraw()


## Muestra la ayuda de una lección (texto con teclas entre llaves) y empieza de cero.
func show_help(help: String, use_mode := "") -> void:
	text = help
	mode = use_mode
	pressed.clear()
	_pop.clear()
	_done_emitted = false
	pieces.clear()
	for tok in Loc.t(help).split(" ", false):
		if tok.begins_with("{") and tok.ends_with("}"):
			var id := tok.substr(1, tok.length() - 2)
			var required := true
			if id.begins_with("?"):
				required = false
				id = id.substr(1)
			pieces.append({"key": id, "required": required})
		else:
			pieces.append({"word": tok})
	visible = help != ""
	queue_redraw()


func clear() -> void:
	show_help("")


## ¿Hay teclas obligatorias en esta ayuda?
func has_keys() -> bool:
	return not required_keys().is_empty()


func required_keys() -> Array:
	var out: Array = []
	for p in pieces:
		if p.has("key") and p.required:
			out.append(p.key)
	return out


func all_done() -> bool:
	for k in required_keys():
		if not pressed.has(k):
			return false
	return true


## El jugador movió con `action` (una de las de movimiento) con el modo `use_mode` (TowerLogic.Mode) y salió bien: se doran las teclas que cuentan.
func note(action: String, use_mode: int, grab_kind := "") -> void:
	if mode == "" or mode == "camera" or not MOVES.has(action):
		return
	match mode:
		"move":
			if use_mode != TowerLogic.Mode.MOVE:
				return
		"grab", "push", "pull":
			if use_mode != TowerLogic.Mode.GRAB or (mode != "grab" and grab_kind != mode):   # (empujar y tirar son distintos: cada lección pide el suyo)
				return
			_gild("empujar")
		"hang":
			if use_mode != TowerLogic.Mode.HANG:
				return
			_gild("colgarse")
	_gild(action)
	_check_done()


## La cámara se movió con la acción `action` (una de las flechas).
func note_camera(action: String) -> void:
	if mode != "camera" or not CAMERA.has(action):
		return
	_gild(action)
	_check_done()


func _check_done() -> void:
	if has_keys() and all_done() and not _done_emitted:
		_done_emitted = true
		completed.emit()


func _gild(id: String) -> void:
	if not pressed.has(id):
		pressed[id] = true
		_pop[id] = 0.0
		queue_redraw()


func _label_of(id: String) -> String:
	match id:
		"empujar":
			return "Shift"
		"colgarse":
			return Loc.t("Espacio")
	return Controls.key_name(Controls.key_of(id))


func _key_width(id: String) -> float:
	if Controls.using_pad:
		return 70.0 if id == "empujar" else (60.0 if id == "colgarse" else KEY_W)
	match id:
		"empujar":
			return 118.0
		"colgarse":
			return 150.0
	return KEY_W


func _word_width(w: String) -> float:
	return float(VFont.line_width(w)) * CUBE


const STICK_W := 96.0


## Lo que se dibuja, en orden: palabras, teclas y (con mando) un stick por cada grupo de cuatro direcciones. {"word"} | {"key": id} | {"stick": "move"|"camera", "ids": [...]}.
func items() -> Array:
	var out: Array = []
	var i := 0
	while i < pieces.size():
		var p: Dictionary = pieces[i]
		if not p.has("key"):
			out.append(p)
			i += 1
			continue
		var group: Array = MOVES if MOVES.has(p.key) else (CAMERA if CAMERA.has(p.key) else [])
		if Controls.using_pad and not group.is_empty():
			var ids: Array = []
			while i < pieces.size() and pieces[i].has("key") and group.has(pieces[i].key):
				ids.append(pieces[i].key)
				i += 1
			out.append({"stick": "move" if group == MOVES else "camera", "ids": ids})
		else:
			out.append(p)
			i += 1
	return out


func _item_width(it: Dictionary) -> float:
	if it.has("stick"):
		return STICK_W
	return _key_width(it.key) if it.has("key") else _word_width(it.word)


## El ancho total de la frase (para centrarla).
func total_width() -> float:
	var w := 0.0
	for it in items():
		w += _item_width(it) + GAP
	return maxf(w - GAP, 0.0)


## Dónde está cada tecla de la frase (rectángulos en el espacio del control), por id (con mando, las cuatro direcciones de un stick comparten el mismo rectángulo).
func key_rects() -> Dictionary:
	var rects := {}
	var x := (size.x - total_width()) * 0.5
	for it in items():
		var w := _item_width(it)
		if it.has("stick"):
			for id in it.ids:
				rects[id] = Rect2(x, 18.0, w, KEY_H)
		elif it.has("key"):
			rects[it.key] = Rect2(x, 18.0, w, KEY_H)
		x += w + GAP
	return rects


func _draw() -> void:
	if not visible or pieces.is_empty():
		return
	var tw := total_width()
	var x := (size.x - tw) * 0.5
	draw_rect(Rect2(x - 24.0, 4.0, tw + 48.0, KEY_H + 28.0), Color(0.03, 0.01, 0.06, 0.78))   # placa oscura detrás de la frase
	for it in items():
		var w := _item_width(it)
		if it.has("stick"):
			_draw_stick(it, Rect2(x, 18.0, w, KEY_H))
		elif it.has("key"):
			_draw_key(it.key, Rect2(x, 18.0, w, KEY_H))
		else:
			var l: Dictionary = VFont.layout([it.word], 0)
			var sz := Vector2(l.size) * CUBE
			Draw.text_cells(self, Vector2(x, 18.0 + (KEY_H - sz.y) * 0.5), l.cells, l.size.y, CUBE, Color(0.97, 0.95, 0.9), 0.0, str(it.word).hash() & 0xFFFF, true)
		x += w + GAP


## Un stick del mando con una flecha por dirección (arriba, izquierda, abajo, derecha según el orden de las acciones del grupo): gris hasta que se usa y dorada después.
func _draw_stick(it: Dictionary, r: Rect2) -> void:
	var c := r.get_center()
	var all_on := true
	for id in it.ids:
		all_on = all_on and pressed.has(id)
	draw_rect(Rect2(r.position + Vector2(3, 5), r.size), Color(0, 0, 0, 0.55))
	draw_rect(r, GOLD_PLATE if all_on else Color(0.20, 0.19, 0.24))
	draw_circle(c, 12.0, Color(0.05, 0.03, 0.09))
	draw_circle(c, 10.0, Color(0.62, 0.62, 0.70))
	var order: Array = MOVES if it.stick == "move" else CAMERA   # adelante/arriba, izquierda, atrás/abajo, derecha
	var dirs := [Vector2(0, -1), Vector2(-1, 0), Vector2(0, 1), Vector2(1, 0)]
	for k in 4:
		var on: bool = it.ids.has(order[k]) and pressed.has(order[k])
		var col := Color(1.0, 0.85, 0.25) if on else Color(0.55, 0.55, 0.62)
		var d: Vector2 = dirs[k]
		var tip := c + d * 24.0
		var base := c + d * 15.0
		var side := Vector2(-d.y, d.x) * 6.0
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), col)
	var tag := "L" if it.stick == "move" else "R"
	_draw_text(tag, c, Color(0.08, 0.05, 0.12), 2.0)


func _draw_key(id: String, r: Rect2) -> void:
	var on := pressed.has(id)
	var lift := 0.0
	if on and _pop.has(id) and _pop[id] < 0.35:
		lift = sin(_pop[id] / 0.35 * PI) * 7.0
	var rr := Rect2(r.position - Vector2(0, lift), r.size)
	var plate := GOLD_PLATE if on else GREY
	var rim: Color = Draw.GOLD if on else GREY_RIM
	draw_rect(Rect2(rr.position + Vector2(3, 5), rr.size), Color(0, 0, 0, 0.55))   # sombra dura
	draw_rect(rr, plate)
	var b := 3.0
	draw_rect(Rect2(rr.position, Vector2(rr.size.x, b)), rim)
	draw_rect(Rect2(rr.position + Vector2(0, rr.size.y - b), Vector2(rr.size.x, b)), rim.darkened(0.35))
	draw_rect(Rect2(rr.position, Vector2(b, rr.size.y)), rim)
	draw_rect(Rect2(rr.position + Vector2(rr.size.x - b, 0), Vector2(b, rr.size.y)), rim.darkened(0.35))
	var ink := Color(1.0, 0.95, 0.7) if on else Color(0.92, 0.92, 0.96)
	if Controls.using_pad:
		_draw_pad_input(id, rr.get_center(), on)
		return
	var arrow := _arrow_of(id)
	if arrow != Vector2.ZERO:
		_draw_arrow(rr.get_center(), arrow, ink)
	else:
		_draw_text(_label_of(id), rr.get_center(), ink, CUBE)


## El botón del mando de una acción dibujado dentro de su placa (letra de cara, gatillo, hombro o su nombre).
func _draw_pad_input(id: String, center: Vector2, on: bool) -> void:
	var p: Dictionary = Controls.pad_of(id)
	if p.is_empty():
		_draw_text("-", center, Color(0.92, 0.92, 0.96), CUBE)
		return
	if p.has("button"):
		match int(p.button):
			JOY_BUTTON_A:
				PadGlyph.draw(self, center, 17.0, PadGlyph.Slot.SOUTH, false)
				return
			JOY_BUTTON_B:
				PadGlyph.draw(self, center, 17.0, PadGlyph.Slot.EAST, false)
				return
			JOY_BUTTON_X:
				PadGlyph.draw(self, center, 17.0, PadGlyph.Slot.WEST, false)
				return
			JOY_BUTTON_Y:
				PadGlyph.draw(self, center, 17.0, PadGlyph.Slot.NORTH, false)
				return
			JOY_BUTTON_LEFT_SHOULDER:
				PadGlyph.draw_named(self, center, 16.0, "LB", false)
				return
			JOY_BUTTON_RIGHT_SHOULDER:
				PadGlyph.draw_named(self, center, 16.0, "RB", false)
				return
	elif int(p.axis) == Controls.AXIS_LT:
		PadGlyph.draw_named(self, center, 16.0, "LT", false)
		return
	elif int(p.axis) == Controls.AXIS_RT:
		PadGlyph.draw_named(self, center, 16.0, "RT", false)
		return
	_draw_text(Controls.pad_name(p), center, Color(1.0, 0.95, 0.7) if on else Color(0.92, 0.92, 0.96), 2.4)


func _draw_text(label: String, center: Vector2, color: Color, cube: float) -> void:
	var l: Dictionary = VFont.layout([label], 1)
	var sz := Vector2(l.size) * cube
	Draw.text_cells(self, center - sz * 0.5, l.cells, l.size.y, cube, color, 0.0, label.hash() & 0xFFFF, true)


## Si la tecla de la acción es una flecha, hacia dónde apunta (si no, ZERO: se escribe su nombre).
func _arrow_of(id: String) -> Vector2:
	if not CAMERA.has(id):
		return Vector2.ZERO
	match Controls.key_of(id):
		KEY_UP:
			return Vector2(0, -1)
		KEY_DOWN:
			return Vector2(0, 1)
		KEY_LEFT:
			return Vector2(-1, 0)
		KEY_RIGHT:
			return Vector2(1, 0)
	return Vector2.ZERO


## Una flecha de cubitos (un triángulo escalonado) que apunta hacia `dir`.
func _draw_arrow(center: Vector2, dir: Vector2, color: Color) -> void:
	var s := 4.0
	var side := Vector2(-dir.y, dir.x)
	for row in 5:
		var n := row + 1
		for k in n:
			var off := (float(k) - float(n - 1) * 0.5) * s
			var pos := center + dir * (float(row) - 2.0) * s + side * off
			Draw.cube(self, pos - Vector2(s, s) * 0.5, s, color)
