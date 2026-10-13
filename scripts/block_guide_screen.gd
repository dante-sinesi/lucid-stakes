extends Control
## La guía de bloques (menú principal y menú de pausa): una lista con cada tipo de bloque. Los descubiertos se ven a color con su nombre y lo que hacen;
## los que faltan, en gris y sin nombre ni descripción: sólo dicen «Por descubrir» (ver block_guide.gd para cómo se descubren).

const UI := preload("res://scripts/menu_ui.gd")
const Draw := preload("res://scripts/voxel_draw.gd")
const BlockGuide := preload("res://scripts/block_guide.gd")
const Profile := preload("res://scripts/profile.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const Loc := preload("res://scripts/loc.gd")

signal back

const K := TowerLogic.Kind
const COLUMNS := 2

var title: Control
var count_label: Control
var grid: GridContainer
var rows := {}           # id -> {"panel", "icon", "name", "desc"}
var back_button: Button


func _init() -> void:
	name = "guia_bloques"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.09, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	center.add_child(col)
	title = UI.label(col, Loc.t("Guía de bloques"), 5, UI.GOLD)
	title.dance = true
	count_label = UI.label(col, "", 2, Color(0.8, 0.76, 0.92))
	grid = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 4)
	col.add_child(grid)
	for b in BlockGuide.ALL:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.custom_minimum_size = Vector2(580, 108)
		grid.add_child(row)
		var icon := _Icon.new()
		icon.kind = b.kind
		icon.custom_minimum_size = Vector2(112, 112)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(box)
		var name_label := UI.label(box, "", 2.5, UI.GOLD, false)
		var desc_label := UI.label(box, "", 2, Draw.MARBLE, false, 430)
		rows[b.id] = {"panel": row, "icon": icon, "name": name_label, "desc": desc_label}
	back_button = UI.button(Loc.t("Volver"), true)
	back_button.name = "volver_guia"
	back_button.pressed.connect(func(): back.emit())
	col.add_child(back_button)


## Vuelve a armar la lista con lo que el perfil ya descubrió.
func refresh() -> void:
	Profile.load_profile()
	for b in BlockGuide.ALL:
		var r: Dictionary = rows[b.id]
		var seen := BlockGuide.discovered(b.id)
		r.icon.discovered = seen
		r.icon.apply()
		if seen:
			r.name.text = Loc.t(str(b.name))
			r.name.color = UI.GOLD
			r.desc.text = Loc.t(str(b.desc))
		else:
			r.name.text = Loc.t("Por descubrir")   # (ni el nombre ni nada más: sólo esto)
			r.name.color = Color(0.55, 0.55, 0.6)
			r.desc.text = ""
	count_label.text = Loc.f("Descubiertos: %d de %d", [BlockGuide.count_discovered(), BlockGuide.ALL.size()])


func focus_default() -> void:
	back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		back.emit()
		get_viewport().set_input_as_handled()


## El ícono de un bloque: el mismo modelo 3D de minibloques y el mismo shader que en la partida, girando solito; uno genérico, gris y sin forma
## propia si todavía no se descubrió (así no se adelanta cómo es).
class _Icon extends SubViewportContainer:
	const BlockModels := preload("res://scripts/block_models.gd")
	const BLOCK_SHADER := preload("res://shaders/voxel_block.gdshader")

	var kind := 0
	var discovered := false
	var mesh_node: MeshInstance3D
	var block_mat: ShaderMaterial
	var _t := 0.0

	func _init() -> void:
		stretch = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.size = Vector2i(112, 112)
		vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		add_child(vp)
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.75, 0.75, 0.85)
		env.ambient_light_energy = 1.1
		var we := WorldEnvironment.new()
		we.environment = env
		vp.add_child(we)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-50, -30, 0)
		sun.light_energy = 1.3
		vp.add_child(sun)
		var cam := Camera3D.new()
		cam.fov = 34.0
		cam.position = Vector3(0, 0.62, 2.65)
		cam.rotation_degrees = Vector3(-11, 0, 0)
		vp.add_child(cam)
		mesh_node = MeshInstance3D.new()
		block_mat = ShaderMaterial.new()
		block_mat.shader = BLOCK_SHADER
		mesh_node.material_override = block_mat
		vp.add_child(mesh_node)
		mesh_node.rotation_degrees = Vector3(28, 35, 0)
		apply()

	## Pone el modelo y los colores que corresponden al estado (descubierto o no).
	func apply() -> void:
		if mesh_node == null:
			return
		var shown := kind if discovered else K.NORMAL
		var state := BlockModels.State.CORRUPT if (discovered and kind == K.BOMB) else BlockModels.State.PURE   # (la bomba activa es la que se ve en la torre; los demás, completos y a todo color)
		mesh_node.mesh = BlockModels.mesh_for(shown, state)
		block_mat.set_shader_parameter("roughness_value", 0.15 if discovered and kind == K.ICE else 0.8)
		var tint := Color(0.42, 0.42, 0.46)
		if discovered:
			tint = Color.from_hsv(0.62, 0.55, 0.95) if kind == K.NORMAL else Color.WHITE   # (el común toma un color de etapa, como en la torre)
		block_mat.set_shader_parameter("tint", tint)
		var glow := Color(0.9, 0.1, 0.05) if discovered and kind == K.BOMB else Color.BLACK
		block_mat.set_shader_parameter("glow_color", glow)
		block_mat.set_shader_parameter("glow_energy", 0.35 if glow != Color.BLACK else 0.0)

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_t += delta
		mesh_node.rotation_degrees.y = 35.0 + _t * 40.0
