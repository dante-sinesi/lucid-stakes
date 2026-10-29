extends Control
## Selector de dificultad (al elegir el escenario): Fácil, Medio, Difícil y Pesadilla en La Pesadilla; los demás escenarios no tienen Fácil. La dificultad gradúa el nivel de las salas a lo largo de las 15 etapas
## (ver `Torre.niveles_para`) y cuánto margen de movimientos tienen. Se elige con las flechas (o WASD) y Espacio; Shift o Esc vuelven.
## `ask()` abre el cuadro y se contesta con `chosen(id)` ("" = volvió atrás).

const Draw := preload("res://scripts/ui/voxel_draw.gd")
const UI := preload("res://scripts/ui/menu_ui.gd")
const PadHints := preload("res://scripts/ui/pad_hints.gd")
const PadGlyph := preload("res://scripts/ui/pad_glyph.gd")
const Loc := preload("res://scripts/idioma/loc.gd")

signal chosen(id: String)

## id, nombre y qué cambia.
const OPTIONS := [
	{"id": "facil", "name": "Fácil", "desc": "Para practicar: movimientos ilimitados y modo pista (una tecla muestra el próximo movimiento). Menos Luz y ningún cosmético."},
	{"id": "media", "name": "Medio", "desc": "La dificultad pensada para el juego: empieza suave y sube hasta salas muy exigentes."},
	{"id": "dificil", "name": "Difícil", "desc": "Las salas se ponen difíciles mucho antes y hay menos margen de movimientos."},
	{"id": "pesadilla", "name": "Pesadilla", "desc": "Salas medias o difíciles casi desde el principio y, al final, solo las peores, con muy poco margen."},
]

var buttons := {}
var desc_label: Control
var hints
var _open_t := 0.0
var _elegibles: Array = ["facil", "media", "dificil", "pesadilla"]


func _init() -> void:
	name = "dificultad"
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card := Control.new()
	card.custom_minimum_size = Vector2(860, 560)
	card.draw.connect(func(): Draw.card(card, Rect2(Vector2.ZERO, card.size), 6.0, 0, 0.1, 2025, false, -1.0))
	center.add_child(card)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	card.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(col)
	UI.label(col, Loc.t("Elige la dificultad"), 4, UI.GOLD, true, 780)
	for o in OPTIONS:
		var b := UI.button(Loc.t(o.name), o.id == "media", 3.5, 24)
		b.name = str(o.id)
		b.pressed.connect(_choose.bind(str(o.id)))
		b.focus_entered.connect(_show_desc.bind(str(o.id)))
		b.mouse_entered.connect(func(): b.grab_focus())
		col.add_child(b)
		buttons[str(o.id)] = b
	desc_label = UI.label(col, "", 2.2, Color(0.9, 0.86, 1.0), true, 780)
	desc_label.custom_minimum_size = Vector2(780, 90)
	hints = PadHints.new()
	col.add_child(hints)


## Abre el cuadro con "Medio" marcado. `elegibles`: las dificultades que se ofrecen (las demás no se ven).
func ask(elegibles: Array = ["facil", "media", "dificil", "pesadilla"]) -> void:
	_elegibles = elegibles
	hints.set_items([{"slot": PadGlyph.Slot.SOUTH, "key": "Espacio", "text": Loc.t("Elegir")},
			{"slot": PadGlyph.Slot.WEST, "key": "Shift", "text": Loc.t("Volver"), "call": func(): _choose("")}])
	for o in OPTIONS:
		buttons[str(o.id)].visible = elegibles.has(str(o.id))
	_open_t = Time.get_ticks_msec() / 1000.0
	visible = true
	buttons["media"].grab_focus()
	_show_desc("media")


func is_open() -> bool:
	return visible


func _show_desc(id: String) -> void:
	for o in OPTIONS:
		if o.id == id:
			desc_label.text = Loc.t(o.desc)


func _choose(id: String) -> void:
	if not visible:
		return
	visible = false
	chosen.emit(id)


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if Time.get_ticks_msec() / 1000.0 - _open_t < 0.3:   # (una tecla que venía apretada no elige sin querer)
		get_viewport().set_input_as_handled()
		return
	var ids: Array = OPTIONS.map(func(o): return str(o.id)).filter(func(id): return _elegibles.has(id))
	var cur := maxi(ids.find("media"), 0)
	for i in ids.size():
		if buttons[ids[i]].has_focus():
			cur = i
	match event.keycode:
		KEY_SHIFT, KEY_ESCAPE:
			_choose("")
		KEY_UP, KEY_W:
			buttons[ids[maxi(cur - 1, 0)]].grab_focus()
		KEY_DOWN, KEY_S:
			buttons[ids[mini(cur + 1, ids.size() - 1)]].grab_focus()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_choose(ids[cur])
		_:
			return
	get_viewport().set_input_as_handled()
