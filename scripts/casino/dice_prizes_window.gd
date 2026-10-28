extends Control
## Ventana de premios de los dados del tabernero: lo que da cada cantidad de aciertos (la claridad es un porcentaje de la que tienes ahora, con un mínimo
## fijo; con 4 y 5 aciertos puede salir además un cosmético). Se abre con C desde los dados y se cierra con el botón, un clic fuera de la ventana, C o Esc.

const DiceGame := preload("res://scripts/casino/dice_game.gd")
const UI := preload("res://scripts/ui/menu_ui.gd")
const PadHints := preload("res://scripts/ui/pad_hints.gd")
const PadGlyph := preload("res://scripts/ui/pad_glyph.gd")
const MenuAnim := preload("res://scripts/ui/menu_anim.gd")
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const Loc := preload("res://scripts/idioma/loc.gd")

signal closed

var claridad := 0   # la claridad de ahora: con ella se calcula lo que daría cada acierto
var panel: Control
var list: VBoxContainer


## Las filas de la ventana: [{hits, pct, ahora, cosmetico}] de más a menos aciertos (con 0 y 1 no hay premio).
static func rows(claridad_ahora: int) -> Array:
	var out: Array = []
	for n in range(DiceGame.DICE, 1, -1):
		var p: Dictionary = DiceGame.prize_for(n)
		var cos := ""
		if not (p.cosmetic as Dictionary).is_empty():
			cos = Loc.t("Cosmético común o raro, a veces") if (p.cosmetic as Dictionary).has("comun") else Loc.t("Cosmético raro o épico")
		out.append({"hits": n, "pct": int(round(float(p.pct) * 100.0)), "ahora": DiceGame.claridad_para(n, claridad_ahora), "cosmetico": cos})
	return out


func _init() -> void:
	name = "premios_dados"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = _Panel.new()
	panel.custom_minimum_size = Vector2(1000, 470)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	UI.label(col, "Premios", 4, UI.GOLD)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	col.add_child(list)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var close := UI.button("Cerrar", true, 3.0, 30)
	close.name = "cerrar"
	close.pressed.connect(close_window)
	col.add_child(close)
	PadHints.attach_in(col, [{"slot": PadGlyph.Slot.EAST, "key": "Esc", "text": Loc.t("Cerrar"), "call": close_window}], [close])


func open_window(claridad_ahora: int) -> void:
	claridad = claridad_ahora
	for ch in list.get_children():
		list.remove_child(ch)
		ch.queue_free()
	for r in rows(claridad):
		list.add_child(_make_row(r))
	visible = true
	MenuAnim.pop_in(panel, 0.92, 0.28)
	MenuAnim.stagger(list.get_children(), 0.04, 0.22, 0.05)


func close_window() -> void:
	if visible:
		visible = false
		closed.emit()


func _make_row(r: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "fila_%d" % int(r.hits)
	row.add_theme_constant_override("separation", 24)
	row.custom_minimum_size = Vector2(0, 62)
	var hits := UI.label(null, Loc.f("%d aciertos", [int(r.hits)]), 3, Draw.MARBLE, false)
	hits.custom_minimum_size = Vector2(230, 0)
	hits.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hits)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 4)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI.label(texts, Loc.f("%d %% de tu claridad (+%d ahora)", [int(r.pct), int(r.ahora)]), 3, UI.GOLD, false)
	if str(r.cosmetico) != "":
		UI.label(texts, str(r.cosmetico), 2, Color(0.78, 0.72, 0.9), false)
	row.add_child(texts)
	return row


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_C]:
		close_window()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not panel.get_global_rect().has_point(get_global_mouse_position()):
			close_window()


## Fondo de la ventana: una carta grande de cubitos.
class _Panel extends Control:
	const D := preload("res://scripts/ui/voxel_draw.gd")

	func _draw() -> void:
		D.card(self, Rect2(Vector2.ZERO, size - Vector2(0, 12)), 6.0, 0, 0.3, 77, false, -1.0)
