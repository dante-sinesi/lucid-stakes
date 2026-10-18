extends Control
## Tarjeta de un escenario: nombre, ilustración, un botón "?" arriba a la derecha (toda la información) y abajo al centro el botón
## de entrada con su costo y el sol de la Luz (o "Jugar" en el gratuito). Hecha de cubitos, como el resto de la interfaz.

const UI := preload("res://scripts/menu_ui.gd")
const Draw := preload("res://scripts/voxel_draw.gd")
const VFont := preload("res://scripts/voxel_font.gd")
const LuzIcon := preload("res://scripts/luz_icon.gd")
const ScenarioArt := preload("res://scripts/scenario_art.gd")
const VoxelLabel := preload("res://scripts/voxel_label.gd")

signal info_pressed(scenario_id: String)
signal enter_pressed(scenario_id: String)

const SIZE := Vector2(300, 430)

var scenario := {}
var info_button: Button
var enter_button: Button
var affordable := true:
	set(v):
		affordable = v
		if enter_button != null:
			enter_button.disabled = not v
		queue_redraw()
var locked_soon := false
var is_current := false:   # la tarjeta que se va a abrir con Enter (la del centro): se marca con un marco que titila
	set(v):
		is_current = v
		queue_redraw()
var _t := 0.0


func setup(s: Dictionary, can_afford: bool) -> void:
	scenario = s
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS
	var title := VoxelLabel.new()
	title.cube = 3.0
	title.color = Draw.GOLD if int(s.entry) > 0 else Draw.MARBLE
	title.align = VoxelLabel.Align.CENTER
	title.wrap_px = 270
	title.text = s.name
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 74
	title.offset_left = 10
	title.offset_right = -10
	title.name = "nombre"
	add_child(title)
	info_button = UI.button("?", false, 3.0, 8, false)
	info_button.name = "info"
	info_button.position = Vector2(SIZE.x - 66, 14)
	info_button.pressed.connect(func(): info_pressed.emit(scenario.id))
	add_child(info_button)
	enter_button = _CostButton.new()
	(enter_button as _CostButton).setup(int(s.entry))
	enter_button.name = "entrar"
	enter_button.pressed.connect(func(): enter_pressed.emit(scenario.id))
	add_child(enter_button)
	enter_button.position = Vector2((SIZE.x - enter_button.custom_minimum_size.x) * 0.5, SIZE.y - enter_button.custom_minimum_size.y - 26)
	affordable = can_afford
	# La entrada y la información ya no son botones: la tarjeta se dibuja con su costo, la botonera de la pantalla dice cómo entrar (Enter o A) y ver la información (C o Y),
	# y también se puede tocar con el mouse (la tarjeta entra; la "?" abre la información). Los botones siguen existiendo, ocultos, para las pruebas.
	for b in [info_button, enter_button]:
		b.visible = false
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE


## "Próximamente" (la demo): el botón de entrada no se puede usar y lo dice.
func lock_soon() -> void:
	locked_soon = true
	affordable = false
	enter_button.disabled = true
	enter_button.cost = 0
	enter_button.cube = 2.2   # (el texto es más largo que "Jugar": se achica para que entre en la tarjeta)
	enter_button.min_cells_w = 30
	enter_button.set_label(preload("res://scripts/demo.gd").soon_text())
	enter_button.primary = false
	enter_button.position.x = (SIZE.x - maxf(enter_button.custom_minimum_size.x, enter_button.size.x)) * 0.5


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Rect2(Vector2(SIZE.x - 66, 14), Vector2(52, 52)).has_point(event.position):
			info_pressed.emit(scenario.id)
		elif affordable and not locked_soon:
			enter_pressed.emit(scenario.id)
		accept_event()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var body := Rect2(Vector2.ZERO, SIZE - Vector2(0, 12))
	Draw.card(self, body, 6.0, 3 if not affordable else 0, 0.12, scenario.get("name", "").hash() & 0xFFFF, int(scenario.get("entry", 0)) > 0, -1.0)
	var theme: Color = ScenarioArt.THEME.get(scenario.get("id", ""), Color(0.15, 0.1, 0.25))
	if not affordable:
		theme = theme.darkened(0.4)
	var panel := Rect2(Vector2(36, 126), Vector2(SIZE.x - 72, 140))
	draw_rect(panel, theme)
	draw_rect(panel, Color(1, 1, 1, 0.12), false, 2.0)
	var bob := sin(_t * 1.6) * 3.0
	ScenarioArt.draw(self, scenario.get("id", ""), panel.get_center() + Vector2(0, bob), 11.0)
	# El costo de entrada (o "Jugar", o "Próximamente") y el "?" de la información, dibujados
	var entry_text: String = enter_button.text.strip_edges()
	var el: Dictionary = VFont.layout([entry_text], 1)
	var ecs := 3.0 if not locked_soon else 2.2
	var esz := Vector2(el.size) * ecs
	var extra := 40.0 if (int(scenario.get("entry", 0)) > 0 and not locked_soon) else 0.0   # (lugar para el sol)
	var plate := Rect2(Vector2((SIZE.x - esz.x - 60.0 - extra) * 0.5, SIZE.y - esz.y - 70.0), esz + Vector2(60.0 + extra, 30.0))
	draw_rect(plate.grow(3.0), Color(0.05, 0.03, 0.09))
	draw_rect(plate, Color(0.58, 0.40, 0.08) if affordable else Color(0.2, 0.18, 0.22))
	draw_rect(Rect2(plate.position, Vector2(plate.size.x, 4.0)), Draw.GOLD if affordable else Color(0.4, 0.38, 0.44))
	var ink := Color(1.0, 0.97, 0.85) if affordable else Color(0.55, 0.52, 0.6)
	var tpos := plate.position + Vector2(30.0, 15.0)
	Draw.text_cells(self, tpos, el.cells, el.size.y, ecs, ink, 0.0, 9, true)
	if int(scenario.get("entry", 0)) > 0 and not locked_soon:
		LuzIcon.draw_sun(self, tpos + Vector2(esz.x + 18.0, esz.y * 0.5), 2.2, _t)
	var qr := Rect2(Vector2(SIZE.x - 66, 14), Vector2(52, 52))
	draw_rect(qr.grow(2.0), Color(0.05, 0.03, 0.09))
	draw_rect(qr, Color(0.2, 0.15, 0.32))
	var ql: Dictionary = VFont.layout(["?"], 1)
	Draw.text_cells(self, qr.get_center() - Vector2(ql.size) * 1.5, ql.cells, ql.size.y, 3.0, Draw.MARBLE, 0.0, 5, true)
	if is_current:
		var pulse := 0.55 + 0.45 * sin(_t * 8.0)
		draw_rect(body.grow(-3.0), Color(1.0, 1.0, 0.9, pulse), false, 5.0)
	# Cuánta Luz paga: "×1.5" y el sol (el gratuito paga lo normal y no muestra nada)
	var mult: float = float(scenario.get("luz_mult", 1.0))
	if mult != 1.0:
		var txt := "x%.1f" % mult
		var l: Dictionary = VFont.layout([txt])
		var cs := 3.0
		var w: float = float(l.size.x) * cs
		var origin := Vector2((SIZE.x - w - 40.0) * 0.5, 288.0)
		Draw.text_cells(self, origin, l.cells, l.size.y, cs, Color(1.0, 0.95, 0.7), 0.0, 3, true)
		LuzIcon.draw_sun(self, origin + Vector2(w + 24.0, 12.0), 2.2, _t)


## Botón de entrada: el costo y el sol de la Luz a la derecha del número.
class _CostButton extends "res://scripts/voxel_button.gd":
	const LuzIcon2 := preload("res://scripts/luz_icon.gd")
	var cost := 0

	func setup(c: int) -> void:
		cost = c
		cube = 3.0
		min_cells_w = 26
		animated = false
		primary = c == 0
		set_label("Jugar" if c == 0 else "%d  " % c)

	func _update_processing() -> void:   # siempre se redibuja: el sol está animado
		set_process(true)
		queue_redraw()

	func _draw() -> void:
		super._draw()
		if cost > 0:
			var t := Time.get_ticks_msec() / 1000.0
			var fc := frame_cube()
			var center := Vector2(size.x, size.y - fc * 2.0) * 0.5
			var text_w := float(VFont.line_width(text)) * cube
			LuzIcon2.draw_sun(self, center + Vector2(text_w * 0.5 - 4.0, 0.0), 2.2, t)
