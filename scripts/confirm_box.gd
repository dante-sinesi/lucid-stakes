extends Control
## Cuadro de confirmación (abandonar la partida, empezar una nueva sobre una sin terminar): un título, el detalle de lo que se pierde y dos salidas, con la botonera de abajo
## ("[A / Enter] Sí..." "[B / Esc] No..."). `ask(title, body, yes_text, no_text)` y se contesta con `chosen(yes)`. Funciona con el juego en pausa.

const Draw := preload("res://scripts/voxel_draw.gd")
const UI := preload("res://scripts/menu_ui.gd")
const PadHints := preload("res://scripts/pad_hints.gd")
const PadGlyph := preload("res://scripts/pad_glyph.gd")
const Loc := preload("res://scripts/loc.gd")

signal chosen(yes: bool)

var title_label: Control
var body_label: Control
var hints
var _open_t := 0.0   # cuando se abrió (los primeros instantes no se atiende nada: un Enter que venía apretado no confirma sin querer)


func _init() -> void:
	name = "confirmacion"
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card := Control.new()
	card.custom_minimum_size = Vector2(820, 330)
	card.draw.connect(func(): Draw.card(card, Rect2(Vector2.ZERO, card.size), 6.0, 0, 0.1, 2024, false, -1.0))
	center.add_child(card)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	card.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(col)
	title_label = UI.label(col, "", 4, UI.GOLD, true, 740)
	body_label = UI.label(col, "", 2.4, Color(0.9, 0.86, 1.0), true, 740)
	hints = PadHints.new()
	col.add_child(hints)


## Abre el cuadro. Con `yes_text`/`no_text` ya traducidos (o claves de Loc).
func ask(title: String, body: String, yes_text: String, no_text: String) -> void:
	title_label.text = title
	body_label.text = body
	hints.set_items([{"slot": PadGlyph.Slot.SOUTH, "key": "Enter", "text": yes_text, "call": func(): _answer(true)},
			{"slot": PadGlyph.Slot.EAST, "key": "Esc", "text": no_text, "call": func(): _answer(false)}])
	_open_t = Time.get_ticks_msec() / 1000.0
	visible = true


func is_open() -> bool:
	return visible


func _answer(yes: bool) -> void:
	if not visible:
		return
	visible = false
	chosen.emit(yes)


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if Time.get_ticks_msec() / 1000.0 - _open_t < 0.3:
		get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_answer(true)
		KEY_ESCAPE:
			_answer(false)
		_:
			return
	get_viewport().set_input_as_handled()
