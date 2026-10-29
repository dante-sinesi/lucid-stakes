extends Control
## Ventana de premios de la ruleta: para cada rareza de la rueda muestra los premios posibles (los de la vitrina de la visita) con su ícono, su descripción y la
## probabilidad de ganarlos en un giro (casillas de esa rareza ÷ 13 × peso del premio dentro de su rareza).
## Se cierra con el botón, con un clic fuera de la ventana o con Esc.

const Roulette := preload("res://scripts/casino/roulette.gd")
const Showcase := preload("res://scripts/casino/showcase.gd")
const Items := preload("res://scripts/datos/items.gd")
const Icons := preload("res://scripts/ui/item_icons.gd")
const ClarityIcon := preload("res://scripts/ui/clarity_icon.gd")
const UI := preload("res://scripts/ui/menu_ui.gd")
const PadHints := preload("res://scripts/ui/pad_hints.gd")
const PadGlyph := preload("res://scripts/ui/pad_glyph.gd")
const MenuAnim := preload("res://scripts/ui/menu_anim.gd")
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const VoxelLabel := preload("res://scripts/ui/voxel_label.gd")
const Loc := preload("res://scripts/idioma/loc.gd")

signal closed

var tier := Items.Tier.EPICO
var panel: Control
var run   # (el run: con él la ventana muestra la vitrina de la visita y no todo el catálogo)
var tabs := {}
var list: VBoxContainer
var title: Control
var hints   # la botonera de la ventana
var rotate_cb := Callable()   # rota la vitrina de la visita (lo pone la ruleta); la ventana sigue abierta y muestra lo nuevo


## Filas de la ventana para una rareza: [{id, name, desc, prob}] (prob en 0..1).
static func rows_for(tier_kind: int, run = null) -> Array:
	var pool: Array[Dictionary] = Showcase.pool(run, tier_kind) if run != null else Items.by_tier(tier_kind)   # (con vitrina: los premios de esta visita)
	var wsum := 0.0
	for it in pool:
		wsum += it.weight
	var out: Array = []
	for it in pool:
		out.append({"id": it.id, "name": it.name, "desc": it.desc, "prob": Roulette.probability(tier_kind, run) * it.weight / wsum})
	return out


static func percent_text(p: float) -> String:
	return ("%.1f %%" % (p * 100.0)).replace(".", ",")


func _init() -> void:
	name = "premios"
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
	panel.custom_minimum_size = Vector2(1000, 692)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	title = UI.label(col, "Premios", 4, UI.GOLD)
	var tab_row := HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_theme_constant_override("separation", 8)
	col.add_child(tab_row)
	for b in Roulette.TIER_ORDER:
		var t := UI.button(Loc.f("%s (%d)", [Loc.t(Roulette.TIER_NAMES[b]), Roulette.count_of(b)]), false, 2.0, 22, false)
		t.toggle_mode = true
		t.pressed.connect(show_tier.bind(b))
		tab_row.add_child(t)
		tabs[b] = t
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	col.add_child(list)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var close := UI.button("Cerrar", true, 3.0, 30)
	close.name = "cerrar"
	close.pressed.connect(close_window)
	col.add_child(close)
	hints = PadHints.attach_in(col, [], [close])
	_update_hints()


func _can_rotate() -> bool:
	return run != null and not run.showcase.is_empty() and rotate_cb.is_valid()


func _update_hints() -> void:
	if hints == null:
		return
	var items := []
	if _can_rotate():
		items.append({"name": "LT", "key": "R", "text": Loc.f("Rotar vitrina (%d)", [Showcase.rotate_cost(run)]), "call": rotate_here, "dim": not run.can_afford(Showcase.rotate_cost(run))})
	items.append({"slot": PadGlyph.Slot.EAST, "key": "Esc", "text": Loc.t("Cerrar"), "call": close_window})
	hints.set_items(items)


## Rota la vitrina sin salir de la ventana: las filas se arman de nuevo con los premios nuevos.
func rotate_here() -> void:
	if not _can_rotate():
		return
	rotate_cb.call()
	show_tier(tier)


func open_for(tier_kind: int) -> void:
	visible = true
	show_tier(tier_kind)
	MenuAnim.pop_in(panel, 0.92, 0.28)


func close_window() -> void:
	if visible:
		visible = false
		closed.emit()


func show_tier(tier_kind: int) -> void:
	tier = tier_kind
	for b in tabs:
		tabs[b].button_pressed = (b == tier_kind)
	for ch in list.get_children():
		ch.queue_free()
		list.remove_child(ch)
	for r in rows_for(tier_kind, run):
		list.add_child(_make_row(r))
	_update_hints()
	MenuAnim.stagger(list.get_children(), 0.04, 0.22, 0.05)   # al cambiar de rareza, las filas entran una tras otra


func _make_row(r: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "fila_" + r.id
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size = Vector2(0, 54)
	row.add_child(_IconBox.new(r.id))
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI.label(texts, r.name, 3, Draw.MARBLE, false)
	UI.label(texts, r.desc, 2, Color(0.78, 0.72, 0.9), false, 760)
	row.add_child(texts)
	var p := UI.label(null, percent_text(r.prob), 3, UI.GOLD, false)
	p.name = "prob"
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(p)
	return row


# Esc cierra la ventana; un clic en el fondo oscuro también.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_Q, KEY_E, KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D]:   # las flechas, LB y RB cambian la rareza
		var ids: Array = Roulette.TIER_ORDER
		show_tier(ids[posmod(ids.find(tier) + (1 if event.keycode in [KEY_E, KEY_RIGHT, KEY_D] else -1), ids.size())])
		get_viewport().set_input_as_handled()
		return
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:   # R (LT) rota la vitrina sin cerrar la ventana
		rotate_here()
		get_viewport().set_input_as_handled()
		return
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
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


## Casillero con el ícono de un premio (los de claridad usan el ícono de la claridad, quieto).
class _IconBox extends Control:
	const I := preload("res://scripts/ui/item_icons.gd")
	const CI := preload("res://scripts/ui/clarity_icon.gd")
	var id := ""

	func _init(item_id: String) -> void:
		id = item_id
		custom_minimum_size = Vector2(56, 54)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if I.has_icon(id):
			I.draw(self, id, size * 0.5 - Vector2(I.SIZE, I.SIZE) * 4.0 * 0.5, 4.0)
		else:
			CI.draw_bolt(self, size * 0.5, 3.8, 0.6)
