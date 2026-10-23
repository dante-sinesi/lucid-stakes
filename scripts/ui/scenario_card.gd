extends Control
## Tarjeta de un escenario: nombre, ilustración, un botón "?" arriba a la derecha (toda la información) y abajo al centro el botón
## de entrada con su costo y el sol de la Luz (o "Jugar" en el gratuito). Hecha de cubitos, como el resto de la interfaz.

const UI := preload("res://scripts/ui/menu_ui.gd")
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const VFont := preload("res://scripts/ui/voxel_font.gd")
const LuzIcon := preload("res://scripts/ui/luz_icon.gd")
const ScenarioArt := preload("res://scripts/ui/scenario_art.gd")
const VoxelLabel := preload("res://scripts/ui/voxel_label.gd")

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
var is_current := false:   # la tarjeta elegida (con las flechas): su botón de entrar se ve apuntado, como el foco de cualquier botón
	set(v):
		is_current = v
		if enter_button != null:
			enter_button.force_focus = v
		if info_button != null:
			info_button.force_focus = false
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
	for b in [info_button, enter_button]:   # (se elige con las flechas y se entra con Enter o A: los botones no toman el foco, pero se pueden tocar)
		b.focus_mode = Control.FOCUS_NONE


## "Próximamente" (la demo): el botón de entrada no se puede usar y lo dice.
func lock_soon() -> void:
	locked_soon = true
	affordable = false
	enter_button.disabled = true
	info_button.disabled = true   # (sin detalles: todavía no hay nada que contar)
	enter_button.cost = 0
	enter_button.cube = 2.2   # (el texto es más largo que "Jugar": se achica para que entre en la tarjeta)
	enter_button.min_cells_w = 30
	enter_button.set_label(preload("res://scripts/datos/demo.gd").soon_text())
	enter_button.primary = false
	enter_button.position.x = (SIZE.x - maxf(enter_button.custom_minimum_size.x, enter_button.size.x)) * 0.5


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
	if locked_soon:   # sin logo todavía: signos de pregunta
		_draw_question_marks(panel, bob)
		return
	ScenarioArt.draw(self, scenario.get("id", ""), panel.get_center() + Vector2(0, bob), 11.0)
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


## El "logo" de un escenario que todavía no está: un signo de pregunta grande y dos chicos a los lados que se mecen.
func _draw_question_marks(panel: Rect2, bob: float) -> void:
	var col := Color(0.78, 0.72, 0.95)
	var l: Dictionary = VFont.layout(["?"])
	var big := 13.0
	var sz := Vector2(l.size) * big
	Draw.text_cells(self, panel.get_center() + Vector2(0, bob) - sz * 0.5, l.cells, l.size.y, big, col, 0.0, 7, true)
	var small := 5.0
	var ssz := Vector2(l.size) * small
	for side in [-1.0, 1.0]:
		var c := panel.get_center() + Vector2(side * 84.0, -34.0 - bob * side)
		Draw.text_cells(self, c - ssz * 0.5, l.cells, l.size.y, small, col.darkened(0.25), 0.0, 9, true)


## Botón de entrada: el costo y el sol de la Luz a la derecha del número.
class _CostButton extends "res://scripts/ui/voxel_button.gd":
	const LuzIcon2 := preload("res://scripts/ui/luz_icon.gd")
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
