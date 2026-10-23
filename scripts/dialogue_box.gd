extends Control
## Cuadro de diálogo de cubitos, abajo en la pantalla: la cara de quien habla a la izquierda, su nombre y el texto que va apareciendo
## letra por letra. Dos modos:
##  - bloqueante (historias): hay que avanzar con Enter, Espacio, E o un clic (Esc no la corta: abre la pausa y la charla sigue donde estaba).
##  - de consejo (lecciones del tutorial): el texto se escribe solo, se queda mientras jugás y no pide nada.
## Con `show_choice` el cuadro ofrece dos o más salidas lado a lado (decisiones de texto): se elige con las flechas izquierda y derecha (o el mouse) y se confirma con
## Enter, Espacio o E (en el mando: izquierda/derecha y A); no se dibujan teclas ni flechas, sólo las opciones con la elegida resaltada. Esc cancela (chosen con -1).
## Cada línea es un texto o {text, icon}: con `icon` ("luz" o "claridad") se muestra ese ícono animado al costado, para hablar de la
## moneda sin escribir su nombre.

const Draw := preload("res://scripts/voxel_draw.gd")
const VFont := preload("res://scripts/voxel_font.gd")
const VoxelLabel := preload("res://scripts/voxel_label.gd")
const Loc := preload("res://scripts/loc.gd")
const Sfx := preload("res://scripts/sfx.gd")
const LuzIcon := preload("res://scripts/luz_icon.gd")
const ClarityIcon := preload("res://scripts/clarity_icon.gd")
const Farolin := preload("res://scripts/farolin.gd")
const PadGlyph := preload("res://scripts/pad_glyph.gd")
const Controls := preload("res://scripts/controls.gd")

signal line_shown(index: int)
signal finished   ## se mostraron todas las líneas (o se saltaron)
signal chosen(index: int)   ## se eligió una opción de `show_choice` (-1: se canceló con Esc)

const SPEED := 55.0          # letras por segundo
const CUBE := 2.5            # lado de un cubito del texto
const BOX_W := 1040.0
const BOX_H := 210.0
const WHITE_TEXT := Color(0.97, 0.95, 0.9)
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
var _options: Array = []   # las salidas de una decisión: [{id, text, enabled}]
var _opt_labels: Array = []
var _opt_rects: Array[Rect2] = []
var selected := 0
const OPT_Y := 138.0
const OPT_H := 52.0


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
	_clear_options()
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
	_clear_options()
	_active = false
	visible = false
	lines = []
	index = -1


## Una decisión: `text` (lo que dice quien habla) y las `options` [{id, text, enabled}] que aparecen cuando termina de escribirse. Emite `chosen(índice)`.
func show_choice(text: String, options: Array, who := "Tabernero") -> void:
	show_lines([text], who, true)
	_options = options.duplicate(true)
	selected = 0
	for i in _options.size():
		if bool(_options[i].enabled):
			selected = i
			break
	_build_options()


func is_choosing() -> bool:
	return _active and not _options.is_empty()


## ¿Ya se ven las opciones? (terminó de escribirse el texto)
func options_visible() -> bool:
	return is_choosing() and not is_typing()


func _clear_options() -> void:
	for l in _opt_labels:
		if is_instance_valid(l):
			l.queue_free()
	_opt_labels.clear()
	_opt_rects.clear()
	_options = []
	selected = 0


func _build_options() -> void:
	var x := 176.0
	for i in _options.size():
		var l := VoxelLabel.new()
		l.localize = false
		l.cube = 2.5
		l.text = str(_options[i].text)
		l.name = "opcion_%d" % i
		add_child(l)
		var w := maxf(l.get_combined_minimum_size().x + 110.0, 230.0)   # (a la izquierda va el botón que elige la opción: del mando o número del teclado)
		_opt_rects.append(Rect2(Vector2(x, OPT_Y), Vector2(w, OPT_H)))
		l.position = Vector2(x + 76.0, OPT_Y + 14.0)
		l.visible = false
		_opt_labels.append(l)
		x += w + 24.0


## Mueve la elección hacia `dir` (-1 izquierda, 1 derecha), saltando las opciones apagadas.
func select_step(dir: int) -> void:
	if not options_visible():
		return
	var n := _options.size()
	var i := selected
	for _k in n:
		i = posmod(i + dir, n)
		if bool(_options[i].enabled):
			if i != selected:
				selected = i
				Sfx.play("blip", 1.4, -8.0)
			return


## Confirma la opción elegida (si está habilitada); se oculta el cuadro y se emite `chosen`.
func confirm_choice() -> void:
	if not options_visible() or not bool(_options[selected].enabled):
		return
	var idx := selected
	_clear_options()
	_active = false
	visible = false
	lines = []
	index = -1
	chosen.emit(idx)


## Esc: se cierra la decisión sin elegir.
func cancel_choice() -> void:
	if not is_choosing():
		return
	_clear_options()
	_active = false
	visible = false
	lines = []
	index = -1
	chosen.emit(-1)


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
	if not _options.is_empty():   # (una decisión: Enter/Espacio confirma la elegida; el diálogo no avanza solo)
		confirm_choice()
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
	if options_visible():
		if event is InputEventMouseMotion:
			for i in _opt_rects.size():
				if _opt_rects[i].has_point(event.position) and bool(_options[i].enabled) and i != selected:
					selected = i
					Sfx.play("blip", 1.4, -8.0)
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for i in _opt_rects.size():
				if _opt_rects[i].has_point(event.position) and bool(_options[i].enabled):
					selected = i
					confirm_choice()
			accept_event()
		return
	if blocking and _active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or not blocking or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if is_choosing():
		var direct := direct_choice(event)
		if direct >= 0:
			if options_visible() and direct < _options.size() and bool(_options[direct].enabled):
				selected = direct
				confirm_choice()
			get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_LEFT, KEY_A:
				select_step(-1)
				get_viewport().set_input_as_handled()
				return
			KEY_RIGHT, KEY_D:
				select_step(1)
				get_viewport().set_input_as_handled()
				return
			KEY_ESCAPE:
				cancel_choice()
				get_viewport().set_input_as_handled()
				return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
			advance()
			get_viewport().set_input_as_handled()
		_:
			if any_key:
				advance()
				get_viewport().set_input_as_handled()


## La opción que elige un botón apretado sin moverse por la pantalla: con el mando, A, X e Y (las que traduce el puente a Espacio, Shift y C) y con el teclado los números 1, 2 y 3. -1 si ninguna.
func direct_choice(event: InputEventKey) -> int:
	match event.keycode:
		KEY_1, KEY_KP_1:
			return 0
		KEY_2, KEY_KP_2:
			return 1
		KEY_3, KEY_KP_3:
			return 2
	if Controls.using_pad:
		match event.keycode:
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				return 0
			KEY_SHIFT:
				return 1
			KEY_C:
				return 2
	return -1


func _draw() -> void:
	if not _active:
		return
	Draw.card(self, Rect2(Vector2.ZERO, Vector2(BOX_W, BOX_H - 10.0)), 6.0, 0, 0.1, 4242, false, -1.0)
	# La cara (la de quien habla)
	var s := 7.0
	var origin := Vector2(48, 24)
	draw_rect(Rect2(origin - Vector2(8, 8), Vector2(12 * s + 16, 13 * s + 16)), Color(0.05, 0.03, 0.09))
	var face_rows: Array = FACE
	var face_pal: Dictionary = FACE_PAL
	if speaker == Farolin.SPEAKER:
		face_rows = Farolin.face_rows()
		face_pal = Farolin.FACE_PAL
		draw_circle(origin + Vector2(6, 6) * s, 64.0, Color(1.0, 0.8, 0.3, 0.06 + 0.02 * sin(_t * 6.0)))   # (la luz de su llama sobre el cuadro)
	var bob := Vector2(0, sin(_t * 2.0) * 1.2 if is_typing() and int(_t * 8.0) % 2 == 0 else 0.0)
	if speaker == Farolin.SPEAKER:
		Farolin.draw_face(self, origin, s, -1, bob)
		face_rows = []   # (Farolín dibuja su propia cara)
	for y in face_rows.size():
		var row: String = face_rows[y]
		for x in row.length():
			if row[x] == ".":
				continue
			var col: Color = face_pal.get(row[x], Color.MAGENTA)
			var p := origin + Vector2(x, y) * s + bob
			draw_rect(Rect2(p, Vector2(s, s)), col)
			draw_rect(Rect2(p, Vector2(s, maxf(s * 0.18, 1.0))), col.lightened(0.3))
			draw_rect(Rect2(p + Vector2(0, s * 0.82), Vector2(s, maxf(s * 0.18, 1.0))), col.darkened(0.35))
	# Ícono que acompaña a la línea (la Luz o la claridad), sin nombrarlos
	if _icon == "luz":
		LuzIcon.draw_sun(self, Vector2(BOX_W - 100, 82), 4.2, _t)
	elif _icon == "claridad":
		ClarityIcon.draw_bolt(self, Vector2(BOX_W - 100, 82), 6.0, _t * 1.4)
	# Las opciones de una decisión: la elegida, dorada; las que no se pueden, apagadas
	var show_opts := options_visible()
	for i in _opt_labels.size():
		_opt_labels[i].visible = show_opts
		if show_opts:
			var en := bool(_options[i].enabled)
			_opt_labels[i].color = (Color(0.45, 0.4, 0.42) if not en else (Color(1.0, 0.95, 0.7) if i == selected else WHITE_TEXT))
			Draw.card(self, _opt_rects[i], 4.0, 3 if not en else (1 if i == selected else 0), 0.0, 5 + i, i == selected and en, -1.0)
			var gc: Vector2 = _opt_rects[i].position + Vector2(40.0, _opt_rects[i].size.y * 0.5)
			if Controls.using_pad:
				PadGlyph.draw(self, gc, 17.0, PadGlyph.slot_for_option(i), not en)
			else:
				PadGlyph.draw_key(self, gc, 15.0, str(i + 1), not en)
	# Indicador de "sigue": un cubito que sube y baja cuando la línea terminó de escribirse
	if blocking and not is_typing() and _options.is_empty():
		var arrow_bob := sin(_t * 5.0) * 3.0
		Draw.cube(self, Vector2(BOX_W - 56, BOX_H - 54 + arrow_bob), 10.0, Draw.GOLD, true)
