extends Control
## Cuadro de diálogo de cubitos, abajo en la pantalla: la cara de quien habla a la izquierda, su nombre y el texto que va apareciendo
## letra por letra. Dos modos:
##  - bloqueante (historias): hay que avanzar con Enter, Espacio, E o un clic (Esc no la corta: abre la pausa y la charla sigue donde estaba).
##  - de consejo (lecciones del tutorial): el texto se escribe solo, se queda mientras jugás y no pide nada.
## Cada línea es un texto o {text, icon}: con `icon` ("luz" o "claridad") se muestra ese ícono animado al costado, para hablar de la
## moneda sin escribir su nombre.

const Draw := preload("res://scripts/voxel_draw.gd")
const VFont := preload("res://scripts/voxel_font.gd")
const VoxelLabel := preload("res://scripts/voxel_label.gd")
const Loc := preload("res://scripts/loc.gd")
const Sfx := preload("res://scripts/sfx.gd")
const LuzIcon := preload("res://scripts/luz_icon.gd")
const ClarityIcon := preload("res://scripts/clarity_icon.gd")

signal line_shown(index: int)
signal finished   ## se mostraron todas las líneas (o se saltaron)

const SPEED := 55.0          # letras por segundo
const CUBE := 2.5            # lado de un cubito del texto
const BOX_W := 1040.0
const BOX_H := 210.0
const TEXT_CELLS := 330      # ancho máximo del texto, en celdas (unos 55 caracteres por renglón)

## La cara del tabernero (12 x 13 cubitos): sombrero oscuro con cinta roja, bigote canoso, camisa blanca con chaleco.
const FACE := ["....kkkk....", "....kkkk....", "....rrrr....", "..kkkkkkkk..", "...ssssss...", "..ssessess..", "..ssssssss..",
		"..smmmmmms..", "..smmmmmms..", "...ssssss...", "..wwwwwwww..", ".wwwrrrrwww.", ".wwwrrrrwww."]
const FACE_PAL := {"k": Color(0.07, 0.07, 0.09), "r": Color(0.72, 0.1, 0.16), "s": Color(0.86, 0.68, 0.55), "e": Color(0.12, 0.1, 0.1),
		"m": Color(0.82, 0.82, 0.8), "w": Color(0.95, 0.95, 0.92)}

var speaker := "Tabernero"
var blocking := true
var any_key := false      # cualquier tecla avanza (el tutorial: el tabernero cuenta y con una tecla se va); si no, sólo Enter, Espacio y E
var lines: Array = []
var index := -1
var name_label: Control
var text_label: Control
var _full := ""          # la línea actual, ya cortada en renglones
var _shown := 0.0        # cuántas letras (sin contar los saltos de línea) se ven
var _letters := 0        # letras de la línea (sin saltos)
var _icon := ""
var _t := 0.0
var _active := false


func _init() -> void:
	name = "dialogo"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(BOX_W, BOX_H)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -BOX_W * 0.5
	offset_right = BOX_W * 0.5
	offset_top = -BOX_H - 14.0
	offset_bottom = -14.0
	name_label = VoxelLabel.new()
	name_label.cube = 3.0
	name_label.color = Draw.GOLD
	name_label.position = Vector2(176, 22)
	name_label.name = "nombre"
	add_child(name_label)
	text_label = VoxelLabel.new()
	text_label.localize = false   # el texto se traduce entero antes de escribirlo letra por letra
	text_label.localize = false   # el texto se traduce entero antes de escribirlo letra por letra
	text_label.cube = CUBE
	text_label.color = Color(0.97, 0.95, 0.9)
	text_label.position = Vector2(176, 62)
	text_label.name = "texto"
	add_child(text_label)


func is_typing() -> bool:
	return _active and int(_shown) < _letters


func is_active() -> bool:
	return _active


## Muestra una serie de líneas. `block`: si hay que avanzarlas (historias) o se escriben solas (consejos).
func show_lines(new_lines: Array, who := "Tabernero", block := true, any := false) -> void:
	lines = new_lines
	speaker = who
	blocking = block
	any_key = any
	index = -1
	_active = true
	visible = true
	name_label.text = who
	mouse_filter = Control.MOUSE_FILTER_STOP if block else Control.MOUSE_FILTER_IGNORE
	_next_line()


## Oculta el cuadro (sin emitir `finished`).
func hide_box() -> void:
	_active = false
	visible = false
	lines = []
	index = -1


func _next_line() -> void:
	index += 1
	if index >= lines.size():
		_active = false
		visible = false
		finished.emit()
		return
	var l = lines[index]
	var txt: String = Loc.t(l if typeof(l) == TYPE_STRING else str(l.get("text", "")))
	_icon = "" if typeof(l) == TYPE_STRING else str(l.get("icon", ""))
	var wrap_cells := TEXT_CELLS - (80 if _icon != "" else 0)
	_full = "\n".join(VFont.wrap(txt, wrap_cells))
	_letters = _full.replace("\n", "").length()
	_shown = 0.0
	text_label.text = ""
	line_shown.emit(index)
	queue_redraw()


## Avanza: si todavía está escribiendo muestra la línea entera; si no, pasa a la siguiente (o termina).
func advance() -> void:
	if not _active:
		return
	if is_typing():
		_shown = float(_letters)
		_update_text()
		return
	_next_line()


## Salta todas las líneas que faltan.
func skip_all() -> void:
	if not _active:
		return
	_active = false
	visible = false
	index = lines.size()
	finished.emit()


func _update_text() -> void:
	var n := int(_shown)
	var out := ""
	var count := 0
	for ch in _full:
		if ch == "\n":
			out += ch
			continue
		if count >= n:
			break
		out += ch
		count += 1
	text_label.text = out


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	if int(_shown) < _letters:
		var before := int(_shown)
		_shown = minf(_shown + SPEED * delta, float(_letters))
		_update_text()
		if int(_shown) / 2 != before / 2:   # un blip cada dos letras, como el tabernero hablando
			Sfx.play("blip", randf_range(0.85, 1.2), -4.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if blocking and _active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or not blocking or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
			advance()
			get_viewport().set_input_as_handled()
		_:
			if any_key:
				advance()
				get_viewport().set_input_as_handled()


func _draw() -> void:
	if not _active:
		return
	Draw.card(self, Rect2(Vector2.ZERO, Vector2(BOX_W, BOX_H - 10.0)), 6.0, 0, 0.1, 4242, false, -1.0)
	# La cara
	var s := 7.0
	var origin := Vector2(48, 24)
	draw_rect(Rect2(origin - Vector2(8, 8), Vector2(12 * s + 16, 13 * s + 16)), Color(0.05, 0.03, 0.09))
	for y in FACE.size():
		var row: String = FACE[y]
		for x in row.length():
			if row[x] == ".":
				continue
			var col: Color = FACE_PAL.get(row[x], Color.MAGENTA)
			var p := origin + Vector2(x, y) * s + Vector2(0, sin(_t * 2.0) * 1.2 if is_typing() and int(_t * 8.0) % 2 == 0 else 0.0)
			draw_rect(Rect2(p, Vector2(s, s)), col)
			draw_rect(Rect2(p, Vector2(s, maxf(s * 0.18, 1.0))), col.lightened(0.3))
			draw_rect(Rect2(p + Vector2(0, s * 0.82), Vector2(s, maxf(s * 0.18, 1.0))), col.darkened(0.35))
	# Ícono que acompaña a la línea (la Luz o la claridad), sin nombrarlos
	if _icon == "luz":
		LuzIcon.draw_sun(self, Vector2(BOX_W - 100, 82), 4.2, _t)
	elif _icon == "claridad":
		ClarityIcon.draw_bolt(self, Vector2(BOX_W - 100, 82), 6.0, _t * 1.4)
	# Indicador de "seguí": un cubito que sube y baja cuando la línea terminó de escribirse
	if blocking and not is_typing():
		var bob := sin(_t * 5.0) * 3.0
		Draw.cube(self, Vector2(BOX_W - 56, BOX_H - 54 + bob), 10.0, Draw.GOLD, true)
