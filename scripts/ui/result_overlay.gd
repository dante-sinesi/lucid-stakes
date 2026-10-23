extends Control
## Cartel de resultado de una jugada del casino (ruleta, tragamonedas y blackjack): "¡Ganaste!" o "¡Perdiste!" en grande sobre el juego, abajo cuánta claridad se ganó o
## se perdió y, si el premio es un boost o un consumible, su ícono con el nombre al costado. Se va solo a los pocos segundos o al instante con Espacio, Enter o un clic.

const UI := preload("res://scripts/ui/menu_ui.gd")
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const ClarityCounter := preload("res://scripts/ui/clarity_counter.gd")
const ItemSlot := preload("res://scripts/ui/item_slot.gd")
const Loc := preload("res://scripts/idioma/loc.gd")

signal dismissed

const SHOW_TIME := 2.6
const WIN := Color(1.0, 0.9, 0.45)
const LOSE := Color(0.85, 0.6, 1.0)
const TIE := Color(0.85, 0.85, 1.0)

var title: Control
var amount          # [ícono] +120 / −50
var item_slot
var item_label: Control
var note: Control
var showing := false
var _t := 0.0
var _gain_row: HBoxContainer
var _item_row: HBoxContainer


func _init() -> void:
	name = "resultado"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	title = UI.label(col, "", 10, WIN)
	title.name = "titulo"
	_gain_row = HBoxContainer.new()
	_gain_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_gain_row)
	amount = ClarityCounter.new(6.0)
	amount.name = "cantidad"
	_gain_row.add_child(amount)
	_item_row = HBoxContainer.new()
	_item_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_item_row.add_theme_constant_override("separation", 18)
	col.add_child(_item_row)
	item_slot = ItemSlot.new()
	item_slot.name = "premio"
	item_slot.custom_minimum_size = Vector2(96, 96)
	item_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_row.add_child(item_slot)
	item_label = UI.label(_item_row, "", 4, Draw.MARBLE, false, 520)
	item_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	note = UI.label(col, "", 2.5, Color(1.0, 0.86, 0.5), true, 760)
	note.name = "aviso"


## Muestra el resultado. `tie`: ni ganó ni perdió (se muestra "¡Empate!"). `delta`: la claridad que se ganó (positivo) o se perdió (negativo), 0 = no se muestra.
## `item_id`/`item_name`: el boost o consumible que se ganó (vacío = ninguno).
func show_result(won: bool, delta: int, item_id := "", item_name := "", notes := "", tie := false) -> void:
	title.text = Loc.t("¡Empate!") if tie else (Loc.t("¡Ganaste!") if won else Loc.t("¡Perdiste!"))
	title.color = TIE if tie else (WIN if won else LOSE)
	title.dance = won and not tie
	_gain_row.visible = delta != 0
	if delta != 0:
		amount.value = absi(delta)
		amount.label.text = ("+%d" if delta > 0 else "−%d") % absi(delta)
		amount.label.color = WIN if delta > 0 else Color(1.0, 0.65, 0.55)
	_item_row.visible = item_id != ""
	item_slot.item_id = item_id
	item_label.text = item_name
	note.text = notes.strip_edges()
	note.visible = note.text != ""
	_t = 0.0
	showing = true
	visible = true


func dismiss() -> void:
	if not showing:
		return
	showing = false
	visible = false
	dismissed.emit()


func _process(delta: float) -> void:
	if not showing:
		return
	_t += delta
	if _t >= SHOW_TIME:
		dismiss()


func _gui_input(event: InputEvent) -> void:
	if showing and event is InputEventMouseButton and event.pressed:
		dismiss()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if showing and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		dismiss()
		get_viewport().set_input_as_handled()
