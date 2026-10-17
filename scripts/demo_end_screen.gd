extends Control
## Pantalla de fin de la demo (al pagarle o fallarle a Farolín del segundo casino): el resumen del run, un agradecimiento, la lista de deseos y los botones de volver a jugar
## y de menú principal.

const NumberFormat := preload("res://scripts/number_format.gd")
const UI := preload("res://scripts/menu_ui.gd")
const PadHints := preload("res://scripts/pad_hints.gd")
const PadGlyph := preload("res://scripts/pad_glyph.gd")
const MenuAnim := preload("res://scripts/menu_anim.gd")
const Draw := preload("res://scripts/voxel_draw.gd")
const SwirlBG := preload("res://scripts/swirl_bg.gd")
const ClarityCounter := preload("res://scripts/clarity_counter.gd")
const ItemSlot := preload("res://scripts/item_slot.gd")
const Demo := preload("res://scripts/demo.gd")
const Loc := preload("res://scripts/loc.gd")

signal new_game
signal to_menu

var title: Control
var message_label: Control
var stats_box: VBoxContainer
var items_row: HBoxContainer
var wishlist_button: Button
var new_button: Button
var menu_button: Button
var rows: Array = []


func _init() -> void:
	name = "fin_de_la_demo"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := SwirlBG.new()
	bg.dim = 0.45
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)
	title = UI.label(col, "", 6, UI.GOLD)
	title.dance = true
	message_label = UI.label(col, "", 3, Color(0.9, 0.86, 1.0), true, 900)
	stats_box = VBoxContainer.new()
	stats_box.custom_minimum_size = Vector2(620, 0)
	stats_box.add_theme_constant_override("separation", 6)
	col.add_child(stats_box)
	items_row = HBoxContainer.new()
	items_row.alignment = BoxContainer.ALIGNMENT_CENTER
	items_row.add_theme_constant_override("separation", 6)
	col.add_child(items_row)
	wishlist_button = UI.button("Agrégalo a tu lista de deseos", true, 4.0, 50)
	wishlist_button.name = "lista_de_deseos"
	wishlist_button.pressed.connect(func(): OS.shell_open(Demo.WISHLIST_URL))
	col.add_child(wishlist_button)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 24)
	col.add_child(btns)
	new_button = UI.button("Jugar de nuevo", false, 4.0, 40)
	new_button.name = "nueva"
	new_button.pressed.connect(func(): new_game.emit())
	btns.add_child(new_button)
	menu_button = UI.button("Menú principal", false, 4.0, 40)
	menu_button.name = "menu"
	menu_button.pressed.connect(func(): to_menu.emit())
	btns.add_child(menu_button)
	PadHints.attach(self, [{"slot": PadGlyph.Slot.SOUTH, "key": "Enter", "text": Loc.t("Agrégalo a tu lista de deseos"), "keycode": [KEY_ENTER, KEY_KP_ENTER], "call": func(): wishlist_button.pressed.emit()},
			{"slot": PadGlyph.Slot.WEST, "key": "Espacio", "text": Loc.t("Jugar de nuevo"), "keycode": KEY_SPACE, "call": func(): new_game.emit()},
			{"slot": PadGlyph.Slot.NORTH, "key": "C", "text": Loc.t("Menú principal"), "keycode": KEY_C, "call": func(): to_menu.emit()}], [wishlist_button, new_button, menu_button])


## Filas del resumen: [[etiqueta, valor, con_icono_de_claridad]].
static func summary_rows(run) -> Array:
	return [
		["Etapa alcanzada", "%d / %d" % [mini(run.max_stage, Demo.LAST_STAGE), Demo.LAST_STAGE], false],
		["Torres superadas", str(run.towers_cleared), false],
		["Claridad juntada", NumberFormat.fmt(run.claridad_earned), true],
		["Reintentos", str(run.retries), false],
		["Vidas que te quedan", str(run.lives), false],
	]


## `completed`: se pagó el peaje del último casino (si no, se terminó antes).
func show_summary(run, completed: bool) -> void:
	title.text = "¡Terminaste la demo!" if completed else "Fin de la demo"
	title.color = UI.GOLD if completed else Color(0.85, 0.6, 1.0)
	message_label.text = Loc.t("Gracias por jugar. En el juego completo te esperan 15 etapas, más escenarios, habilidades que se quedan, el blackjack, las tragamonedas y muchos más boosts y cosméticos.")
	for ch in stats_box.get_children():
		stats_box.remove_child(ch)
		ch.queue_free()
	rows = summary_rows(run)
	for r in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var name_label := UI.label(row, r[0], 3, Draw.MARBLE, false)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if r[2]:
			var counter := ClarityCounter.new(3.0)
			counter.label.text = str(r[1])
			row.add_child(counter)
		else:
			var val := UI.label(row, r[1], 3, Color(1, 1, 1), false)
			val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stats_box.add_child(row)
	for ch in items_row.get_children():
		items_row.remove_child(ch)
		ch.queue_free()
	for id in run.boosts:
		var slot := ItemSlot.new()
		slot.item_id = id
		slot.custom_minimum_size = Vector2(54, 54)
		items_row.add_child(slot)
	visible = true
	wishlist_button.grab_focus()
	MenuAnim.pop_in(title, 1.5, 0.4)
	MenuAnim.stagger(stats_box.get_children(), 0.12, 0.3, 0.35)
	MenuAnim.stagger(items_row.get_children(), 0.06, 0.25, 0.35 + 0.12 * rows.size())
	MenuAnim.stagger([wishlist_button, new_button, menu_button], 0.1, 0.3, 0.45 + 0.12 * rows.size())
