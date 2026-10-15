extends Button
## Botón-carta hecho de cubitos (estilo Balatro): flota, se inclina hacia el mouse, crece al pasar por encima y se hunde al
## apretarlo; una franja de brillo la cruza. Es un Button de verdad (foco, teclado, señales); sólo cambia cómo se dibuja.
## El tamaño se calcula a partir del texto, con margen de sobra: el texto nunca toca el borde.

const VFont := preload("res://scripts/voxel_font.gd")
const Draw := preload("res://scripts/voxel_draw.gd")
const Loc := preload("res://scripts/loc.gd")
const Sfx := preload("res://scripts/sfx.gd")

var cube := 3.0:
	set(v):
		cube = v
		_resize()
var primary := false:
	set(v):
		primary = v
		queue_redraw()
var selected := false:            # opción elegida de un grupo: se ve dorada (sin hundirse como un botón apretado)
	set(v):
		selected = v
		queue_redraw()
var corruption := -1.0:
	set(v):
		corruption = v
		queue_redraw()
var pad_cells := Vector2i(5, 2)   # espacio entre el texto y el borde, en cubitos de texto (además del borde)
var min_cells_w := 0              # ancho mínimo en cubitos de texto
var animated := true:             # flota y brilla siempre (los botones chicos sólo reaccionan al mouse)
	set(v):
		animated = v
		_update_processing()
var _t := 0.0


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	_t = randf() * 20.0
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]:
		add_theme_color_override(c, Color(0, 0, 0, 0))   # el texto lo dibujamos nosotros
	mouse_entered.connect(_hover_sound)
	pressed.connect(func(): Sfx.play("click"))
	mouse_entered.connect(_update_processing)
	mouse_exited.connect(_update_processing)
	focus_entered.connect(_update_processing)
	focus_exited.connect(_update_processing)
	toggled.connect(func(_on): queue_redraw())
	resized.connect(queue_redraw)
	_update_processing()


func _hover_sound() -> void:
	if not disabled:
		Sfx.play("hover", 1.0, -6.0)


func _update_processing() -> void:
	set_process(animated or is_hovered() or has_focus())
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Cambia el texto (usar esto en vez de asignar `text`, así se vuelve a medir el botón).
func set_label(t: String) -> void:
	text = Loc.auto(t)
	_resize()


## Lado de los cubitos del borde: el doble que los del texto, para que el marco se lea como bloques grandes.
func frame_cube() -> float:
	return cube * 2.0


## Tamaño de la carta (sin las chorreras de abajo): el texto más el margen y el borde.
func card_size() -> Vector2:
	var l: Dictionary = VFont.layout(text.replace("\r", "").split("\n"), 1)
	var fc := frame_cube()
	var w: float = maxf((l.size.x + pad_cells.x * 2) * cube + fc * 2.0, min_cells_w * cube)
	var h: float = (l.size.y + pad_cells.y * 2) * cube + fc * 2.0
	return Vector2(ceilf(w / fc) * fc, ceilf(h / fc) * fc)


func _resize() -> void:
	var cs := card_size()
	custom_minimum_size = cs + Vector2(0, frame_cube() * 2.0)  # + 2 cubitos del borde para las chorreras
	queue_redraw()


func _state() -> int:
	if disabled:
		return 3
	if button_pressed and toggle_mode:
		return 2
	if selected and not (is_pressed() and is_hovered()):
		return 1
	if is_pressed() and is_hovered():
		return 2
	if is_hovered() or has_focus():
		return 1
	return 0


func _draw() -> void:
	var st := _state()
	var k := Draw.default_corruption if corruption < 0.0 else corruption
	var seed_value := text.hash() & 0xFFFF
	var fc := frame_cube()
	var body_size := Vector2(size.x, size.y - fc * 2.0)
	var center := body_size * 0.5
	var hover := st == 1
	# Movimiento: flota y se balancea; al pasar el mouse se inclina hacia él; crece al resaltarse y se achica al apretarse.
	var bob := sin(_t * 1.7) * 2.0 if animated else 0.0
	var wobble := sin(_t * 1.3) * 0.02 if animated else 0.0
	var rel := Vector2.ZERO
	if hover and is_hovered():
		rel = ((get_local_mouse_position() - center) / (body_size * 0.5)).clampf(-1.0, 1.0)
	var scl := 1.0
	match st:
		1: scl = 1.06
		2: scl = 0.97
	var xf := Transform2D(wobble + rel.x * 0.05, Vector2(scl * (1.0 - absf(rel.y) * 0.04), scl * (1.0 - absf(rel.x) * 0.03)), rel.y * 0.07, center + Vector2(0, bob))
	draw_set_transform_matrix(xf)
	var gold := primary or selected or (toggle_mode and button_pressed)
	var shine := fmod(_t * 0.35, 1.6) if (animated or hover) else -1.0
	Draw.card(self, Rect2(-center, body_size), fc, st, k, seed_value, gold, shine if shine <= 1.0 else -1.0)
	var l: Dictionary = VFont.layout(text.replace("\r", "").split("\n"), 1)
	var text_size := Vector2(l.size) * cube
	var origin := -text_size * 0.5
	var col := Color(1.0, 0.98, 0.9) if gold else Draw.MARBLE
	if st == 3:
		col = col.darkened(0.5)
	elif hover and not gold:
		col = Draw.GOLD
	Draw.text_cells(self, origin, l.cells, l.size.y, cube, col, k * 0.4, seed_value + 1, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
