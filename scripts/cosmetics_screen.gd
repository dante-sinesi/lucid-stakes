extends Control
## Pantalla Personaje (menú principal): a la izquierda el animalito elegido (con su gorro y su prenda, girando); a la derecha tres solapas:
## Personajes (los que desbloqueaste y los que todavía no), Gorros y Ropa. Un clic elige un personaje o se pone/saca una pieza; lo que no
## tenés se ve en gris con un "?" y, al pasar el mouse, dice cómo conseguirlo. Los cosméticos se ganan con los dados de la pantalla de carga.

const UI := preload("res://scripts/menu_ui.gd")
const Draw := preload("res://scripts/voxel_draw.gd")
const Profile := preload("res://scripts/profile.gd")
const Cosmetics := preload("res://scripts/cosmetics.gd")
const Characters := preload("res://scripts/characters.gd")
const VFont := preload("res://scripts/voxel_font.gd")
const Loc := preload("res://scripts/loc.gd")
const Sfx := preload("res://scripts/sfx.gd")

signal back

const COLUMNS := 5
const TABS: Array[String] = ["personajes", "gorros", "ropa"]
const TAB_NAMES := {"personajes": "Personajes", "gorros": "Gorros", "ropa": "Ropa"}

var tab := "personajes"
var grid: GridContainer
var tiles := {}          # id -> casillero
var tab_buttons := {}
var preview            # el animalito grande
var name_label: Control
var count_label: Control
var info_label: Control
var back_button
var _col: VBoxContainer


func _init() -> void:
	name = "cosmeticos"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.09, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 10)
	center.add_child(_col)
	var title := UI.label(_col, Loc.t("Personaje"), 5, UI.GOLD)
	title.dance = true
	count_label = UI.label(_col, "", 2, Color(0.8, 0.76, 0.92))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	_col.add_child(row)
	# Izquierda: el animalito grande
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	preview = _Preview.new()
	preview.custom_minimum_size = Vector2(330, 360)
	preview.spin = true
	left.add_child(preview)
	name_label = UI.label(left, "", 3, Draw.MARBLE)
	# Derecha: solapas y casilleros
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	right.add_child(tabs)
	for t in TABS:
		var b := UI.button(Loc.t(TAB_NAMES[t]), false, 2.5, 30, false)
		b.name = "solapa_" + t
		b.pressed.connect(set_tab.bind(t))
		tabs.add_child(b)
		tab_buttons[t] = b
	grid = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.custom_minimum_size = Vector2(5 * 118 + 4 * 12, 2 * 130 + 12)
	right.add_child(grid)
	info_label = UI.label(right, "", 2, Draw.MARBLE, false, 620)
	info_label.custom_minimum_size = Vector2(620, 70)
	back_button = UI.button(Loc.t("Volver"), true)
	back_button.name = "volver_cosmeticos"
	back_button.pressed.connect(func(): back.emit())
	_col.add_child(back_button)


func set_tab(t: String) -> void:
	tab = t
	refresh()


## Arma todo con el perfil actual.
func refresh() -> void:
	Profile.load_profile()
	for ch in grid.get_children():
		grid.remove_child(ch)
		ch.queue_free()
	tiles.clear()
	for t in TABS:
		tab_buttons[t].selected = t == tab
	var cur_char := Profile.character()
	var hat := Profile.equipped_hat()
	var outfit := Profile.equipped_outfit()
	preview.show_model(cur_char, hat, outfit)
	match tab:
		"personajes":
			for c in Characters.ALL:
				_add_tile(c.id, c, Profile.has_character(c.id), cur_char == c.id, c.id, "", "")
		"gorros":
			_add_tile("", {"id": "", "name": "Sin gorro", "rarity": "comun"}, true, hat == "", cur_char, "", "")
			for c in Cosmetics.by_slot("gorro"):
				_add_tile(c.id, c, Profile.has_cosmetic(c.id), hat == c.id, cur_char, c.id, "")
		_:
			_add_tile("", {"id": "", "name": "Sin prenda", "rarity": "comun"}, true, outfit == "", cur_char, "", "")
			for c in Cosmetics.by_slot("prenda"):
				_add_tile(c.id, c, Profile.has_cosmetic(c.id), outfit == c.id, cur_char, "", c.id)
	var owned := 0
	var by_rarity := {}
	for r in Cosmetics.RARITY_ORDER:
		var have := 0
		for c in Cosmetics.by_rarity(r):
			if Profile.has_cosmetic(c.id):
				have += 1
		owned += have
		by_rarity[r] = Loc.f("%s %d/%d", [Loc.t(str(Cosmetics.RARITIES[r].name)), have, Cosmetics.by_rarity(r).size()])
	count_label.text = Loc.f("Conseguidos: %d de %d     %s     %s     %s", [owned, Cosmetics.ALL.size(), by_rarity.comun, by_rarity.raro, by_rarity.epico])
	var ch_info := Characters.get_character(cur_char)
	name_label.text = Loc.t(str(ch_info.name))
	var worn: Array[String] = []
	if hat != "":
		worn.append(Loc.t(str(Cosmetics.get_cosmetic(hat).name)))
	if outfit != "":
		worn.append(Loc.t(str(Cosmetics.get_cosmetic(outfit).name)))
	if not worn.is_empty():
		name_label.text = Loc.f("%s: %s", [Loc.t(str(ch_info.name)), ", ".join(worn)])
	info_label.text = ""


## Un casillero. `id` es lo que se elige ("" = quitar). `c` la descripción (nombre, rareza). El dibujito muestra al animalito `ch` con
## el gorro `hat` y/o la prenda `outfit`.
func _add_tile(id: String, c: Dictionary, owned: bool, equipped: bool, ch: String, hat: String, outfit: String) -> void:
	var tile := _Tile.new()
	tile.name = "casillero_" + (id if id != "" else "ninguno")
	grid.add_child(tile)
	tile.setup(c, owned, equipped, ch, hat, outfit, tab == "personajes")
	tile.pressed.connect(choose.bind(id))
	tile.hovered.connect(func(): _describe(id, c, owned))
	tiles[id] = tile


## El texto de abajo: qué es y cómo se consigue.
func _describe(id: String, c: Dictionary, owned: bool) -> void:
	var nm := Loc.t(str(c.name))
	info_label.color = Draw.MARBLE
	if id == "":
		info_label.text = nm
	elif tab == "personajes":
		info_label.text = nm if owned else Loc.f("%s: %s", [nm, Loc.t(str(Characters.get_character(id).how))])
	else:
		var rar := Loc.t(str(Cosmetics.RARITIES[c.rarity].name)).to_lower()
		info_label.text = Loc.f("%s (%s)", [nm, rar]) if owned else Loc.f("%s (%s): todavía no lo tenés. Sale en los dados de la pantalla de carga.", [nm, rar])
		info_label.color = Cosmetics.RARITIES[c.rarity].color


## Un clic: elige el personaje o se pone/saca la pieza (sólo si se tiene).
func choose(id: String) -> void:
	var changed := false
	match tab:
		"personajes":
			changed = Profile.select_character(id)
		"gorros":
			if id == "" or Profile.equipped_hat() == id:   # tocar el que llevás (o "sin gorro") lo saca
				if Profile.equipped_hat() != "":
					Profile.unequip("gorro")
					changed = true
			else:
				changed = Profile.equip(id)
		_:
			if id == "" or Profile.equipped_outfit() == id:
				if Profile.equipped_outfit() != "":
					Profile.unequip("prenda")
					changed = true
			else:
				changed = Profile.equip(id)
	if changed:
		Sfx.play("item")
		refresh()


## El animalito en 3D dentro de su propia mini-escena: gira despacio (el grande) o se dibuja una sola vez (los casilleros).
class _Preview extends SubViewportContainer:
	const Characters := preload("res://scripts/characters.gd")
	var spin := false
	var _vp: SubViewport
	var _model: Node3D
	var _yaw := 0.6

	func _init() -> void:
		stretch = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vp = SubViewport.new()
		_vp.own_world_3d = true
		_vp.transparent_bg = true
		_vp.handle_input_locally = false
		add_child(_vp)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 1.25
		cam.position = Vector3(0, 0.62, 3.0)
		_vp.add_child(cam)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-40, -35, 0)
		_vp.add_child(sun)
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.75, 0.75, 0.9)
		env.ambient_light_energy = 0.75
		var we := WorldEnvironment.new()
		we.environment = env
		_vp.add_child(we)

	func _ready() -> void:
		set_process(spin)
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if spin else SubViewport.UPDATE_ONCE

	func show_model(ch: String, hat: String, outfit: String, dark := false) -> void:
		if _model != null:
			_model.queue_free()
		_model = Characters.build(ch, hat, outfit)
		_model.rotation.y = _yaw
		_vp.add_child(_model)
		if dark:   # lo que no se tiene: todo gris oscuro
			_tint_dark(_model)
		if not spin:
			_vp.render_target_update_mode = SubViewport.UPDATE_ONCE

	func _tint_dark(n: Node) -> void:
		if n is MeshInstance3D and n.material_override is StandardMaterial3D:
			var m := n.material_override as StandardMaterial3D
			var g := m.albedo_color.get_luminance() * 0.4 + 0.08
			m.albedo_color = Color(g, g, g * 1.1)
		for ch in n.get_children():
			_tint_dark(ch)

	func _process(delta: float) -> void:
		if _model != null:
			_yaw += delta * 0.7
			_model.rotation.y = _yaw


## Un casillero: la miniatura 3D, una barrita con el color de la rareza y un marco dorado si es lo que llevás.
class _Tile extends BaseButton:
	const D := preload("res://scripts/voxel_draw.gd")
	const C := preload("res://scripts/cosmetics.gd")
	const VFont := preload("res://scripts/voxel_font.gd")
	signal hovered
	var info := {}
	var owned := false
	var equipped := false
	var _mini

	func setup(c: Dictionary, has_it: bool, is_equipped: bool, ch: String, hat: String, outfit: String, is_character: bool) -> void:
		info = c
		owned = has_it
		equipped = is_equipped
		custom_minimum_size = Vector2(118, 130)
		focus_mode = Control.FOCUS_ALL
		mouse_entered.connect(func(): hovered.emit())
		focus_entered.connect(func(): hovered.emit())
		if str(c.get("id", "")) != "" or is_character:
			_mini = load("res://scripts/cosmetics_screen.gd")._Preview.new()
			_mini.spin = false
			_mini.position = Vector2(5, 2)
			_mini.custom_minimum_size = Vector2(108, 100)
			_mini.size = Vector2(108, 100)
			add_child(_mini)
			_mini.show_model(ch, hat, outfit, not has_it)
		if not has_it:   # el "?" va encima de la miniatura (un hijo se dibuja después que el padre)
			var mark: Control = load("res://scripts/cosmetics_screen.gd")._Mark.new()
			mark.size = Vector2(118, 104)
			add_child(mark)

	func _draw() -> void:
		var hover := is_hovered() or has_focus()
		D.card(self, Rect2(Vector2.ZERO, size - Vector2(0, 6)), 5.0, 1 if hover else 0, 0.05, str(info.get("id", "")).hash() & 0xFFFF, equipped, -1.0)
		var rarity: Dictionary = C.RARITIES.get(info.get("rarity", "comun"), C.RARITIES.comun)
		draw_rect(Rect2(Vector2(16, size.y - 24), Vector2(size.x - 32, 5)), rarity.color if owned else Color(0.35, 0.33, 0.42))
		if _mini == null:   # "sin gorro" / "sin prenda": una cruz
			var cc := Vector2(size.x * 0.5, 52)
			draw_line(cc + Vector2(-16, -16), cc + Vector2(16, 16), Color(0.7, 0.67, 0.8), 4.0)
			draw_line(cc + Vector2(16, -16), cc + Vector2(-16, 16), Color(0.7, 0.67, 0.8), 4.0)


## El "?" de lo que todavía no se tiene.
class _Mark extends Control:
	const D := preload("res://scripts/voxel_draw.gd")
	const VFont := preload("res://scripts/voxel_font.gd")

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var l: Dictionary = VFont.layout(["?"])
		D.text_cells(self, size * 0.5 - Vector2(l.size) * 4.0 * 0.5 - Vector2(0, 4), l.cells, l.size.y, 4.0, Color(0.9, 0.87, 1.0), 0.0, 1, true)
