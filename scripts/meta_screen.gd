extends Control
## Pantalla de Habilidades (menú principal): una grilla con el ícono de cada habilidad persistente. Las que no tenés se ven grises y
## quietas; las que ganaste, a todo color y animadas. Al tocar un ícono se abre su descripción, cómo se consiguió (o cómo conseguirla:
## qué prueba la enseña) y en qué escenarios sale esa prueba. Acá no se compra nada: las habilidades se ganan superando pruebas (ver
## abilities.gd) y la Luz se gasta en la entrada de los escenarios (ver scenario_screen.gd).

const UI := preload("res://scripts/menu_ui.gd")
const Draw := preload("res://scripts/voxel_draw.gd")
const Profile := preload("res://scripts/profile.gd")
const Abilities := preload("res://scripts/abilities.gd")
const AbilityArt := preload("res://scripts/ability_art.gd")
const Trials := preload("res://scripts/trials.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
const LuzCounter := preload("res://scripts/luz_counter.gd")
const Loc := preload("res://scripts/loc.gd")

signal back

const COLUMNS := 5

var luz_counter
var stats_label: Control
var grid: GridContainer
var tiles := {}          # id de la habilidad -> casillero
var back_button: Button
var info_panel: Control  # descripción de una habilidad (se abre al tocar su ícono)
var info_box: VBoxContainer
var info_close: Button
var info_icon: Control


func _init() -> void:
	name = "despertar"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.09, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)
	var title := UI.label(col, "Habilidades", 5, UI.GOLD)
	title.dance = true
	var luz_row := HBoxContainer.new()
	luz_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(luz_row)
	luz_counter = LuzCounter.new(4.0)
	luz_counter.name = "luz"
	luz_row.add_child(luz_counter)
	stats_label = UI.label(col, "", 2, Color(0.8, 0.76, 0.92))
	grid = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	col.add_child(grid)
	back_button = UI.button("Volver", true)
	back_button.name = "volver_despertar"
	back_button.pressed.connect(func(): back.emit())
	col.add_child(back_button)
	_build_info_panel()


func _build_info_panel() -> void:
	info_panel = Control.new()
	info_panel.name = "info"
	info_panel.visible = false
	info_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	info_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	info_panel.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	col.add_child(row)
	info_icon = _BigIcon.new()
	info_icon.custom_minimum_size = Vector2(190, 190)
	info_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(info_icon)
	info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 10)
	info_box.custom_minimum_size = Vector2(760, 0)
	row.add_child(info_box)
	info_close = UI.button("Volver", true)
	info_close.name = "cerrar_info"
	info_close.pressed.connect(func(): info_panel.visible = false)
	col.add_child(info_close)
	add_child(info_panel)
	# Con la descripción abierta la grilla queda tapada: se la deja quieta (no se animan sus íconos) hasta que se cierre.
	info_panel.visibility_changed.connect(func(): grid.process_mode = Node.PROCESS_MODE_DISABLED if info_panel.visible else Node.PROCESS_MODE_INHERIT)


## Vuelve a armar la pantalla con el perfil actual.
func refresh() -> void:
	Profile.load_profile()
	luz_counter.value = Profile.luz()
	var d := Profile.data
	stats_label.text = Loc.f("Mejor etapa: %d     Runs: %d     Escapes: %d     Pruebas superadas: %d", [
			int(d.best_stage), int(d.runs), int(d.victories), int(d.trials_cleared)])
	for ch in grid.get_children():
		grid.remove_child(ch)
		ch.queue_free()
	tiles.clear()
	for a in Abilities.ALL:
		var tile := _Tile.new()
		tile.name = "casillero_" + a.id
		grid.add_child(tile)
		tile.setup(a.id, Profile.has_ability(a.id))
		tile.pressed.connect(show_info.bind(a.id))
		tiles[a.id] = tile
	info_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and info_panel.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		info_panel.visible = false
		get_viewport().set_input_as_handled()


## Abre la descripción de una habilidad: qué hace, cómo se consiguió (o cómo conseguirla) y en qué escenarios.
func show_info(id: String) -> void:
	var a := Abilities.get_ability(id)
	var owned := Profile.has_ability(id)
	for ch in info_box.get_children():
		info_box.remove_child(ch)
		ch.queue_free()
	(info_icon as _BigIcon).setup(id, owned)
	UI.label(info_box, a.name, 5, UI.GOLD if owned else Color(0.7, 0.67, 0.78), false)
	UI.label(info_box, "Ya la tenés" if owned else "Todavía no la tenés", 2, Color(0.65, 0.95, 0.8) if owned else Color(0.78, 0.74, 0.86), false)
	UI.label(info_box, a.desc, 3, Draw.MARBLE, false, 740)
	var trial: Dictionary = Trials.CATALOG[a.trial]
	UI.label(info_box, ("Cómo la conseguiste" if owned else "Cómo conseguirla"), 3, UI.GOLD, false)
	UI.label(info_box, Loc.f("Superando la prueba «%s»: %s", [Loc.t(trial.name), Loc.t(trial.desc)]), 2, Color(0.88, 0.84, 0.96), false, 740)
	UI.label(info_box, "Escenarios donde sale esa prueba", 3, UI.GOLD, false)
	for s in scenarios_for_trial(a.trial):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		info_box.add_child(row)
		UI.label(row, Loc.f("- %s", [Loc.t(str(s.name))]), 2, Color(0.88, 0.84, 0.96), false)
		if int(s.entry) > 0:
			var cost := LuzCounter.new(2.0)
			cost.value = int(s.entry)
			row.add_child(cost)
		else:
			UI.label(row, "(gratis)", 2, Color(0.65, 0.95, 0.8), false)
	info_panel.visible = true
	info_close.grab_focus()


## Los escenarios cuyo sorteo incluye una prueba.
static func scenarios_for_trial(trial_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in Scenarios.ALL:
		if s.pool.has(trial_id):
			out.append(s)
	return out


## Casillero de la grilla: el ícono de una habilidad en un marco; gris y quieto si no la tenés, a color y animado si sí.
class _Tile extends BaseButton:
	const D := preload("res://scripts/voxel_draw.gd")
	const A := preload("res://scripts/ability_art.gd")
	var ability_id := ""
	var owned := false
	var _icon: Control

	func setup(id: String, has_it: bool) -> void:
		ability_id = id
		owned = has_it
		custom_minimum_size = Vector2(150, 150)
		focus_mode = Control.FOCUS_ALL
		# El marco (con sus cubitos) sólo se redibuja cuando cambia algo (el mouse, el foco); el ícono, que gira, es un hijo aparte que
		# se redibuja cada cuadro (si la tenés) con una malla ya armada: así la grilla no cuesta casi nada.
		_icon = _Icon.new()
		_icon.tile = self
		_icon.t = randf() * 10.0
		_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_icon)
		for sig in [mouse_entered, mouse_exited, focus_entered, focus_exited]:
			sig.connect(_icon.queue_redraw)

	func _draw() -> void:
		var hover := is_hovered() or has_focus()
		var st := 1 if hover else 0
		var k := 0.08 if owned else 0.0
		D.card(self, Rect2(Vector2.ZERO, size - Vector2(0, 8)), 5.0, st, k, ability_id.hash() & 0xFFFF, owned, -1.0)

	class _Icon extends Control:
		const A := preload("res://scripts/ability_art.gd")
		var tile
		var t := 0.0

		func _init() -> void:
			mouse_filter = Control.MOUSE_FILTER_IGNORE

		func _process(delta: float) -> void:
			if tile.owned or t >= 0.0:
				t += delta
				queue_redraw()
			if not tile.owned:
				set_process(false)   # el gris no se mueve: se dibuja una sola vez

		func _draw() -> void:
			var hover: bool = tile.is_hovered() or tile.has_focus()
			var c: Vector2 = (tile.size - Vector2(0, 8)) * 0.5
			A.draw(self, tile.ability_id, c + Vector2(0, 8), 8.4 * (1.06 if hover else 1.0), tile.owned, t)


## Ícono grande de la ventana de descripción.
class _BigIcon extends Control:
	const A := preload("res://scripts/ability_art.gd")
	var ability_id := ""
	var owned := false
	var _t := 0.0

	func setup(id: String, has_it: bool) -> void:
		ability_id = id
		owned = has_it
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.06, 0.16))
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.12), false, 2.0)
		A.draw(self, ability_id, size * 0.5 + Vector2(0, 10), 13.0, owned, _t)
