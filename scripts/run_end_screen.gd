extends Control
## Pantalla de fin de run: si escapaste (pasaste las 27 etapas) o si el run terminó antes, con el resumen (etapa alcanzada, torres,
## claridad, reintentos, movimientos y los boosts que tenías) y dos botones: Nueva partida y Menú principal.

const NumberFormat := preload("res://scripts/number_format.gd")
const Stages := preload("res://scripts/stages.gd")
const UI := preload("res://scripts/menu_ui.gd")
const MenuAnim := preload("res://scripts/menu_anim.gd")
const Draw := preload("res://scripts/voxel_draw.gd")
const SwirlBG := preload("res://scripts/swirl_bg.gd")
const ClarityCounter := preload("res://scripts/clarity_counter.gd")
const LuzCounter := preload("res://scripts/luz_counter.gd")
const ItemSlot := preload("res://scripts/item_slot.gd")
const Loc := preload("res://scripts/loc.gd")
const FINAL_STAGE := Stages.FINAL

signal new_game
signal to_menu

var title: Control
var reason_label: Control
var abil_label: Control   # habilidades persistentes ganadas en el run
var luz_row: Control      # el sol: "+N" (lo que dio este run) y lo que tenés en total
var luz_gain
var luz_total_counter
var stats_box: VBoxContainer
var items_row: HBoxContainer
var new_button: Button
var menu_button: Button
var rows: Array = []   # [[etiqueta, valor]] de la última vez que se armó (para pruebas)


func _init() -> void:
	name = "fin_del_run"
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
	reason_label = UI.label(col, "", 3, Color(0.9, 0.86, 1.0), true, 900)
	luz_row = HBoxContainer.new()
	luz_row.alignment = BoxContainer.ALIGNMENT_CENTER
	luz_row.add_theme_constant_override("separation", 40)
	col.add_child(luz_row)
	luz_gain = LuzCounter.new(4.0)
	luz_gain.prefix = "+"
	luz_gain.name = "luz_ganada"
	luz_row.add_child(luz_gain)
	luz_total_counter = LuzCounter.new(3.0, Color(0.85, 0.82, 0.95))
	luz_total_counter.name = "luz_total"
	luz_row.add_child(luz_total_counter)
	abil_label = UI.label(col, "", 3, Color(0.7, 1.0, 0.8))
	stats_box = VBoxContainer.new()
	stats_box.custom_minimum_size = Vector2(620, 0)
	stats_box.add_theme_constant_override("separation", 6)
	col.add_child(stats_box)
	items_row = HBoxContainer.new()
	items_row.alignment = BoxContainer.ALIGNMENT_CENTER
	items_row.add_theme_constant_override("separation", 6)
	col.add_child(items_row)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 24)
	col.add_child(btns)
	new_button = UI.button("Nueva partida", true, 4.0, 50)
	new_button.name = "nueva"
	new_button.pressed.connect(func(): new_game.emit())
	btns.add_child(new_button)
	menu_button = UI.button("Menú principal", false, 4.0, 50)
	menu_button.name = "menu"
	menu_button.pressed.connect(func(): to_menu.emit())
	btns.add_child(menu_button)


## Filas del resumen: [[etiqueta, número, con_icono_de_claridad]].
static func summary_rows(run, victory: bool) -> Array:
	return [
		["Etapa alcanzada", "%d / %d" % [FINAL_STAGE if victory else run.max_stage, FINAL_STAGE], false],
		["Torres superadas", str(run.towers_cleared), false],
		["Claridad juntada", NumberFormat.fmt(run.claridad_earned), true],
		["Gastada en la ruleta", str(run.casino_spent), true],
		["Ganada en la ruleta", str(run.casino_won), true],
		["Reintentos", str(run.retries), false],
		["Movimientos", str(run.moves), false],
	]


## `luz`: la Luz que dio el run (-1 si no corresponde mostrarla).
func show_summary(run, victory: bool, reason := "", luz := -1, luz_total := 0, new_abilities := []) -> void:
	abil_label.visible = not new_abilities.is_empty()
	abil_label.text = Loc.f("Habilidad persistente nueva: %s", [", ".join(new_abilities.map(func(n): return Loc.t(str(n))))]) if not new_abilities.is_empty() else ""
	luz_row.visible = luz >= 0
	luz_gain.value = maxi(luz, 0)
	luz_total_counter.value = luz_total
	title.text = "¡Escapaste de la pesadilla!" if victory else "Fin de la partida"
	title.color = UI.GOLD if victory else Color(0.85, 0.6, 1.0)
	reason_label.text = reason if reason != "" else (Loc.f("Pasaste las %d etapas.", [FINAL_STAGE]) if victory else "")
	for ch in stats_box.get_children():
		stats_box.remove_child(ch)
		ch.queue_free()
	rows = summary_rows(run, victory)
	var count_targets: Array = []   # [control, valor] que cuentan hacia arriba al aparecer
	for r in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var name_label := UI.label(row, r[0], 3, Draw.MARBLE, false)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if r[2]:
			var counter := ClarityCounter.new(3.0)
			counter.value = int(r[1])
			row.add_child(counter)
			count_targets.append([counter, int(r[1])])
		else:
			var val := UI.label(row, r[1], 3, Color(1, 1, 1), false)
			val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if str(r[1]).is_valid_int():
				count_targets.append([val, int(r[1])])
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
	new_button.grab_focus()
	# Entrada: el título cae con un golpe, las filas aparecen una a una y sus números cuentan hacia arriba.
	MenuAnim.pop_in(title, 1.5, 0.4)
	MenuAnim.stagger(stats_box.get_children(), 0.12, 0.3, 0.35)
	for i in count_targets.size():
		MenuAnim.count_up(count_targets[i][0], count_targets[i][1], 0.9, 0.45 + 0.12 * i)
	MenuAnim.stagger(items_row.get_children(), 0.06, 0.25, 0.35 + 0.12 * rows.size())
	MenuAnim.stagger([new_button, menu_button], 0.1, 0.3, 0.45 + 0.12 * rows.size())
