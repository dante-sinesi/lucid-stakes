extends Control
## Editor de modelos: cubos (con variantes), cosméticos y personajes hechos con minibloques, como el Estudio de salas pero para el arte. Es una herramienta de desarrollo (la usa
## Dante; el jugador no la ve). Uso: Godot --path . res://scenes/model_editor.tscn   (o herramientas\editor_modelos.bat). Los modelos se guardan en data/modelos/*.jsonl (ver model_lib.gd).
##
## Mouse: botón izquierdo = usar la herramienta (Poner: en la cara que se toca, como en Minecraft; Sacar; Cuentagotas; Rellenar capa); derecho (arrastrar) = girar;
## medio (arrastrar) = mover; rueda = acercar. Teclas: Ctrl+Z deshacer, Ctrl+Y rehacer, Ctrl+S guardar, 1 a 8 elegir color, Q/E subir y bajar la capa.
## La lógica (modelo, pintar, deshacer, verificar) está en model_editor_model.gd y se prueba sin pantalla.

const EditorModel := preload("res://scripts/model_editor_model.gd")
const ModelLib := preload("res://scripts/model_lib.gd")
const ModelImport := preload("res://scripts/model_import.gd")
const BlockModels := preload("res://scripts/block_models.gd")
const Characters := preload("res://scripts/characters.gd")
const VoxelMesh := preload("res://scripts/voxel_mesh.gd")

const TOOLS := [["poner", "Poner"], ["sacar", "Sacar"], ["gotero", "Cuentagotas"], ["capa", "Rellenar capa"]]
const FILES := {"bloque": "bloques.jsonl", "cosmetico": "cosmeticos.jsonl", "personaje": "personajes.jsonl"}
const KIND_NAMES := {"bloque": "Bloque", "cosmetico": "Cosmético", "personaje": "Personaje"}
const STATE_NAMES := ["Corrupto", "Purificado", "Desactivado"]

var models: Array = []        # los modelos abiertos (EditorModel)
var cur = null                # el que se está editando
var tool := "poner"
var yaw := 35.0
var pitch := 28.0
var dist := 2.2
var center := Vector3.ZERO
var preview_state := 1        # BlockModels.State (sólo para bloques)
var show_char := true
var ref_char := "gato"
var status := ""

var viewport: SubViewport
var world: Node3D
var cam: Camera3D
var model_root: Node3D        # (la malla del modelo y la guía)
var mesh_cur: MeshInstance3D
var mesh_other: MeshInstance3D
var guide: MeshInstance3D
var hover_box: MeshInstance3D
var ref_node: Node3D
var list: ItemList
var filter: OptionButton
var palette_grid: GridContainer
var color_picker: ColorPickerButton
var verify_label: Label
var status_label: Label
var info_label: Label
var meta_box: VBoxContainer
var part_opt: OptionButton
var pivot_spins: Array = []
var layer_spin: SpinBox
var layer_check: CheckBox
var mirror_x_check: CheckBox
var mirror_z_check: CheckBox
var tool_buttons := {}
var state_row: HBoxContainer
var _dragging := ""
var _hover := Vector3i(-1000, 0, 0)
var _ui_lock := false
var _dirty_mesh := true


func _ready() -> void:
	if DisplayServer.get_name() != "headless" and get_window() == get_tree().root and not Engine.is_embedded_in_editor():   # (la ventana de las herramientas es más grande que la del juego)
		get_window().size = Vector2i(1750, 950)
		get_window().move_to_center()
	ModelLib.reload()
	_build_ui()
	_load_all()
	_rebuild_list()
	if not models.is_empty():
		_select(0)
	_refresh_all()


# --- interfaz -----------------------------------------------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.09, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	# ---- izquierda: la lista de modelos ----
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(280, 0)
	root.add_child(left)
	left.add_child(_title("Modelos"))
	filter = OptionButton.new()
	filter.add_item("Todos")
	filter.add_item("Bloques")
	filter.add_item("Cosméticos")
	filter.add_item("Personajes")
	filter.item_selected.connect(func(_i): _rebuild_list())
	left.add_child(filter)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(func(i): _select_from_list(i))
	left.add_child(list)
	var row := HBoxContainer.new()
	left.add_child(row)
	row.add_child(_menu_button("Nuevo", [["Bloque", "bloque"], ["Cosmético", "cosmetico"], ["Personaje", "personaje"]], _on_new))
	row.add_child(_btn("Duplicar", _on_duplicate))
	row.add_child(_btn("Borrar", _on_delete))
	row = HBoxContainer.new()
	left.add_child(row)
	row.add_child(_menu_button("Importar del código", [["Bloques", "bloques"], ["Personajes", "personajes"], ["Cosméticos", "cosmeticos"], ["Todo", "todo"]], _on_import))
	row.add_child(_btn("Guardar todo", _on_save_all))
	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(240, 0)
	left.add_child(info_label)
	# ---- centro: herramientas y vista 3D ----
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(mid)
	var bar := HBoxContainer.new()
	mid.add_child(bar)
	for t in TOOLS:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.pressed.connect(_on_tool.bind(t[0]))
		bar.add_child(b)
		tool_buttons[t[0]] = b
	mirror_x_check = _check("Simetría X", _on_mirror_x)
	bar.add_child(mirror_x_check)
	mirror_z_check = _check("Simetría Z", _on_mirror_z)
	bar.add_child(mirror_z_check)
	bar.add_child(_btn("Deshacer", _on_undo))
	bar.add_child(_btn("Rehacer", _on_redo))
	bar.add_child(_btn("Guardar", _on_save))
	var bar2 := HBoxContainer.new()
	mid.add_child(bar2)
	var ll := Label.new()
	ll.text = "Capa:"
	bar2.add_child(ll)
	layer_spin = SpinBox.new()
	layer_spin.min_value = 0
	layer_spin.max_value = 31
	layer_spin.value_changed.connect(func(v): _on_layer(int(v)))
	bar2.add_child(layer_spin)
	layer_check = _check("Ver y pintar sólo esta capa", func(on): _on_only_layer(on))
	bar2.add_child(layer_check)
	state_row = HBoxContainer.new()
	bar2.add_child(state_row)
	for i in STATE_NAMES.size():
		var b := Button.new()
		b.text = STATE_NAMES[i]
		b.pressed.connect(func(): _on_preview_state(i))
		state_row.add_child(b)
	var char_check := _check("Mostrar personaje", _on_show_char)
	char_check.button_pressed = true
	bar2.add_child(char_check)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.gui_input.connect(_on_view_input)
	mid.add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	container.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	_build_world()
	status_label = Label.new()
	mid.add_child(status_label)
	# ---- derecha: datos, partes, paleta, verificación ----
	var right := ScrollContainer.new()
	right.custom_minimum_size = Vector2(380, 0)
	root.add_child(right)
	meta_box = VBoxContainer.new()
	meta_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(meta_box)


func _title(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 18)
	return l


func _btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.pressed.connect(cb)
	return b


func _check(t: String, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = t
	c.toggled.connect(cb)
	return c


func _menu_button(t: String, items: Array, cb: Callable) -> MenuButton:
	var mb := MenuButton.new()
	mb.text = t
	var pm := mb.get_popup()
	for i in items.size():
		pm.add_item(items[i][0], i)
	pm.id_pressed.connect(func(i): cb.call(items[i][1]))
	return mb


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.12, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.85)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 0.9
	world.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 40
	cam.far = 100.0
	world.add_child(cam)
	model_root = Node3D.new()
	world.add_child(model_root)
	mesh_cur = MeshInstance3D.new()
	mesh_cur.material_override = _vertex_material(false)
	model_root.add_child(mesh_cur)
	mesh_other = MeshInstance3D.new()
	mesh_other.material_override = _vertex_material(true)
	model_root.add_child(mesh_other)
	guide = MeshInstance3D.new()
	world.add_child(guide)
	hover_box = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	hover_box.mesh = bm
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.2, 0.9, 1.0, 0.45)
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hover_box.material_override = hm
	hover_box.visible = false
	model_root.add_child(hover_box)
	_place_camera()


static func _vertex_material(translucent: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	if translucent:
		m.albedo_color = Color(1, 1, 1, 0.35)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


# --- modelos abiertos -------------------------------------------------------------------------------------------------------

func _load_all() -> void:
	models.clear()
	for r in ModelLib.records():
		models.append(EditorModel.from_record(r))


func _label_of(m) -> String:
	var extra := ""
	if m.kind == "bloque":
		extra = " (%s v%d%s)" % [m.block, m.variant, " desact." if m.state == "defused" else ""]
	return "%s %s%s%s" % [KIND_NAMES.get(m.kind, m.kind), m.model_name, extra, " *" if m.dirty else ""]


func _visible_models() -> Array:
	var want: String = ["", "bloque", "cosmetico", "personaje"][filter.selected] if filter != null else ""
	return models.filter(func(m): return want == "" or m.kind == want)


func _rebuild_list() -> void:
	list.clear()
	var vis := _visible_models()
	for m in vis:
		list.add_item(_label_of(m))
	if cur != null:
		var i := vis.find(cur)
		if i >= 0:
			list.select(i)


func _select_from_list(i: int) -> void:
	var vis := _visible_models()
	if i >= 0 and i < vis.size():
		cur = vis[i]
		_refresh_all()


func _select(index: int) -> void:
	cur = models[index] if index >= 0 and index < models.size() else null
	_rebuild_list()


## Abre un modelo de afuera (la lista de modelos del editor) y lo deja elegido.
func open_model(m) -> void:
	if not models.has(m):
		models.append(m)
	cur = m
	_rebuild_list()
	_refresh_all()


func _on_new(kind: String) -> void:
	var n := 1
	var id := "%s_nuevo_%d" % [kind, n]
	while models.any(func(m): return m.id == id):
		n += 1
		id = "%s_nuevo_%d" % [kind, n]
	var m = EditorModel.new_model(kind, id)
	if kind == "bloque":
		m.variant = 4
	m.dirty = true
	open_model(m)
	_say("Modelo nuevo: %s" % id)


func _on_duplicate() -> void:
	if cur == null:
		return
	var rec: Dictionary = cur.to_record()
	var m = EditorModel.from_record(rec)
	if m.kind == "bloque":
		var vmax := 0
		for o in models:
			if o.kind == "bloque" and o.block == m.block:
				vmax = maxi(vmax, o.variant)
		m.variant = vmax + 1
		m.id = "%s_%d" % [m.block, m.variant]
	else:
		m.id += "_copia"
	m.model_name = m.id
	m.dirty = true
	open_model(m)
	_say("Duplicado como %s" % m.id)


func _on_delete() -> void:
	if cur == null:
		return
	ModelLib.delete_record(cur.to_record())
	models.erase(cur)
	cur = models[0] if not models.is_empty() else null
	BlockModels.clear_cache()
	_rebuild_list()
	_refresh_all()
	_say("Borrado.")


func _on_save() -> void:
	if cur == null:
		return
	var problems: Array = cur.verify()
	if not problems.is_empty():
		_say("No se guardó: %s" % problems[0])
		_refresh_meta_status()
		return
	_save_model(cur)
	_say("Guardado en %s/%s" % [ModelLib.dir, FILES[cur.kind]])


func _save_model(m) -> void:
	ModelLib.save_record(m.to_record(), FILES[m.kind])
	m.dirty = false
	BlockModels.clear_cache()
	_rebuild_list()


func _on_save_all() -> void:
	var saved := 0
	var skipped := 0
	for m in models:
		if m.dirty:
			if m.verify().is_empty():
				_save_model(m)
				saved += 1
			else:
				skipped += 1
	_say("Se guardaron %d modelos%s." % [saved, (" (%d no pasan la verificación)" % skipped) if skipped > 0 else ""])


func _on_import(what: String) -> void:
	var recs: Array = []
	if what == "bloques" or what == "todo":
		recs.append_array(ModelImport.blocks())
	if what == "personajes" or what == "todo":
		recs.append_array(ModelImport.characters())
	if what == "cosmeticos" or what == "todo":
		recs.append_array(ModelImport.cosmetics())
	for r in recs:
		var m = EditorModel.from_record(r)
		var replaced := false
		for i in models.size():
			if ModelLib.key_of(models[i].to_record()) == ModelLib.key_of(r):
				models[i] = m
				replaced = true
		if not replaced:
			models.append(m)
		m.dirty = true
	_rebuild_list()
	if cur == null and not models.is_empty():
		cur = models[0]
	_refresh_all()
	_say("Se pasaron %d modelos del código (sin guardar todavía: Guardar todo)." % recs.size())


# --- herramientas -----------------------------------------------------------------------------------------------------------

func _on_tool(t: String) -> void:
	tool = t
	for k in tool_buttons:
		tool_buttons[k].button_pressed = k == t


func _on_undo() -> void:
	if cur != null:
		cur.undo()
		_dirty_mesh = true
		_refresh_meta_status()


func _on_redo() -> void:
	if cur != null:
		cur.redo()
		_dirty_mesh = true
		_refresh_meta_status()


func _on_layer(y: int) -> void:
	if _ui_lock or cur == null:
		return
	if cur.only_layer >= 0:
		cur.only_layer = y
	_dirty_mesh = true


func _on_only_layer(on: bool) -> void:
	if _ui_lock or cur == null:
		return
	cur.only_layer = int(layer_spin.value) if on else -1
	_dirty_mesh = true


func _on_preview_state(i: int) -> void:
	preview_state = [BlockModels.State.CORRUPT, BlockModels.State.PURE, BlockModels.State.DEFUSED][i]
	_dirty_mesh = true


func _say(t: String) -> void:
	status = t
	if status_label != null:
		status_label.text = t


# --- refrescos --------------------------------------------------------------------------------------------------------------

func _refresh_all() -> void:
	_ui_lock = true
	_build_meta()
	if cur != null:
		mirror_x_check.button_pressed = cur.mirror_x
		mirror_z_check.button_pressed = cur.mirror_z
		layer_spin.max_value = maxi(cur.size.y - 1, 0)
		layer_check.button_pressed = cur.only_layer >= 0
		state_row.visible = cur.kind == "bloque"
	_on_tool(tool)
	_ui_lock = false
	_dirty_mesh = true
	_frame_camera()
	_rebuild_list()


func _refresh_meta_status() -> void:
	if cur == null or verify_label == null:
		return
	var problems: Array = cur.verify()
	verify_label.text = "Todo bien: se puede guardar." if problems.is_empty() else "\n".join(problems)
	verify_label.modulate = Color(0.5, 1, 0.55) if problems.is_empty() else Color(1, 0.7, 0.5)
	info_label.text = "%d minibloques · caja %dx%dx%d%s" % [cur.voxel_total(), cur.size.x, cur.size.y, cur.size.z, " · con cambios sin guardar" if cur.dirty else ""]


func _build_meta() -> void:
	for ch in meta_box.get_children():
		ch.queue_free()
	palette_grid = null
	part_opt = null
	pivot_spins = []
	if cur == null:
		return
	var m = cur
	meta_box.add_child(_title("Datos"))
	meta_box.add_child(_field("Id", m.id, func(t): _set_model(m, "id", t.strip_edges())))
	meta_box.add_child(_field("Nombre", m.model_name, func(t): _set_model(m, "model_name", t)))
	match m.kind:
		"bloque":
			meta_box.add_child(_option("Tipo de bloque", ModelLib.BLOCK_NAMES.values(), ModelLib.BLOCK_NAMES.values().find(m.block), func(i): _set_model(m, "block", str(ModelLib.BLOCK_NAMES.values()[i]))))
			meta_box.add_child(_spin("Variante", 0, 99, m.variant, func(v): _set_model(m, "variant", int(v))))
			meta_box.add_child(_option("Estado", ["pure", "defused"], ["pure", "defused"].find(m.state), func(i): _set_model(m, "state", ["pure", "defused"][i])))
		"cosmetico":
			meta_box.add_child(_option("Hueco", EditorModel.SLOTS, EditorModel.SLOTS.find(m.slot), func(i): _set_model(m, "slot", EditorModel.SLOTS[i])))
			meta_box.add_child(_option("Rareza", EditorModel.RARITIES, EditorModel.RARITIES.find(m.rarity), func(i): _set_model(m, "rarity", EditorModel.RARITIES[i])))
	if m.kind != "bloque":
		var names: Array = []
		for c in Characters.ALL:
			names.append(str(c.id))
		meta_box.add_child(_option("Personaje de referencia", names, maxi(names.find(ref_char), 0), func(i): _set_ref(str(names[i]))))
	# partes
	if m.parts.size() > 1:
		meta_box.add_child(_title("Partes"))
		part_opt = OptionButton.new()
		for p in m.parts:
			part_opt.add_item(str(p.name))
		part_opt.select(m.part)
		part_opt.item_selected.connect(func(i): _select_part(i))
		meta_box.add_child(part_opt)
		var prow := HBoxContainer.new()
		meta_box.add_child(prow)
		var pl := Label.new()
		pl.text = "Pivote:"
		prow.add_child(pl)
		for k in 3:
			var sp := SpinBox.new()
			sp.min_value = -2
			sp.max_value = 40
			sp.step = 0.5
			sp.custom_minimum_size = Vector2(70, 0)
			sp.value_changed.connect(func(_v): _on_pivot_changed())
			prow.add_child(sp)
			pivot_spins.append(sp)
		_build_pivot_row_refresh()
	# tamaño
	meta_box.add_child(_title("Caja"))
	var srow := HBoxContainer.new()
	meta_box.add_child(srow)
	var size_spins: Array = []
	for k in 3:
		var sp := SpinBox.new()
		sp.min_value = 1
		sp.max_value = 40
		sp.value = [m.size.x, m.size.y, m.size.z][k]
		sp.custom_minimum_size = Vector2(70, 0)
		srow.add_child(sp)
		size_spins.append(sp)
	meta_box.add_child(_btn("Cambiar tamaño", _on_resize.bind(size_spins)))
	# paleta
	meta_box.add_child(_title("Paleta"))
	palette_grid = GridContainer.new()
	palette_grid.columns = 8
	meta_box.add_child(palette_grid)
	_build_palette()
	color_picker = ColorPickerButton.new()
	color_picker.text = "Editar el color elegido"
	color_picker.custom_minimum_size = Vector2(0, 28)
	color_picker.color_changed.connect(_on_palette_color)
	meta_box.add_child(color_picker)
	meta_box.add_child(_btn("Agregar color", _on_add_color))
	# herramientas de la parte
	meta_box.add_child(_title("Parte actual"))
	var trow := HBoxContainer.new()
	meta_box.add_child(trow)
	trow.add_child(_btn("Espejar X", _on_flip))
	trow.add_child(_btn("Vaciar capa", _on_clear_layer))
	var mrow := HBoxContainer.new()
	meta_box.add_child(mrow)
	for d in [["←", Vector3i(-1, 0, 0)], ["→", Vector3i(1, 0, 0)], ["↓", Vector3i(0, -1, 0)], ["↑", Vector3i(0, 1, 0)], ["z-", Vector3i(0, 0, -1)], ["z+", Vector3i(0, 0, 1)]]:
		mrow.add_child(_btn(d[0], _on_shift.bind(d[1])))
	# verificación
	meta_box.add_child(_title("Verificación"))
	verify_label = Label.new()
	verify_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	verify_label.custom_minimum_size = Vector2(280, 0)
	meta_box.add_child(verify_label)
	meta_box.add_child(_btn("Verificar", _refresh_meta_status))
	_refresh_meta_status()


func _on_mirror_x(on: bool) -> void:
	if cur != null:
		cur.mirror_x = on


func _on_mirror_z(on: bool) -> void:
	if cur != null:
		cur.mirror_z = on


func _on_show_char(on: bool) -> void:
	show_char = on
	_dirty_mesh = true


func _set_model(m, prop: String, v) -> void:
	m.set(prop, v)
	m.dirty = true


func _after(_x = null) -> void:
	_refresh_meta_status()
	_rebuild_list()


func _set_ref(id: String) -> void:
	ref_char = id
	_dirty_mesh = true


func _select_part(i: int) -> void:
	if cur == null:
		return
	cur.part = i
	_build_pivot_row_refresh()
	_dirty_mesh = true


func _on_flip() -> void:
	if cur != null:
		cur.flip_x()
		_dirty_mesh = true


func _on_clear_layer() -> void:
	if cur != null:
		cur.clear_layer(int(layer_spin.value))
		_dirty_mesh = true


func _on_shift(d: Vector3i) -> void:
	if cur != null:
		cur.shift_part(d)
		_dirty_mesh = true


func _on_resize(spins: Array) -> void:
	if cur == null:
		return
	cur.resize(Vector3i(int(spins[0].value), int(spins[1].value), int(spins[2].value)))
	_refresh_all()


func _on_add_color() -> void:
	if cur == null:
		return
	cur.color_index = cur.add_palette_color(color_picker.color)
	_build_palette()


func _build_pivot_row_refresh() -> void:
	if cur == null or pivot_spins.is_empty():
		return
	var pv = cur.parts[cur.part].pivot
	for k in 3:
		pivot_spins[k].set_value_no_signal(0.0 if pv == null else [pv.x, pv.y, pv.z][k])


func _on_pivot_changed() -> void:
	if cur == null or pivot_spins.is_empty():
		return
	cur.set_pivot(Vector3(pivot_spins[0].value, pivot_spins[1].value, pivot_spins[2].value))
	_dirty_mesh = true


func _build_palette() -> void:
	if palette_grid == null or cur == null:
		return
	for ch in palette_grid.get_children():
		ch.queue_free()
	for i in cur.palette.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(28, 28)
		var sb := StyleBoxFlat.new()
		sb.bg_color = cur.palette[i]
		sb.border_color = Color.WHITE if i == cur.color_index else Color(0, 0, 0, 0.6)
		sb.set_border_width_all(3 if i == cur.color_index else 1)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.pressed.connect(func(): _pick_palette(i))
		palette_grid.add_child(b)
	if color_picker != null:
		color_picker.color = cur.palette[clampi(cur.color_index, 0, cur.palette.size() - 1)]


func _pick_palette(i: int) -> void:
	if cur == null or i < 0 or i >= cur.palette.size():
		return
	cur.color_index = i
	_build_palette()


func _on_palette_color(c: Color) -> void:
	if cur == null or _ui_lock:
		return
	cur.set_palette_color(cur.color_index, c)
	_dirty_mesh = true
	_build_palette()


func _field(label: String, value: String, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_changed.connect(func(t): _after(cb.call(t)))
	row.add_child(e)
	return row


func _option(label: String, items: Array, selected: int, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.select(maxi(selected, 0))
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.item_selected.connect(func(i): _after(cb.call(i)))
	row.add_child(o)
	return row


func _spin(label: String, lo: float, hi: float, value: float, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = value
	s.value_changed.connect(func(v): _after(cb.call(v)))
	row.add_child(s)
	return row


# --- la vista 3D ------------------------------------------------------------------------------------------------------------

## Dónde queda el modelo en el mundo: los bloques centrados; personajes y cosméticos con el origen en los pies.
func model_offset() -> Vector3:
	if cur == null:
		return Vector3.ZERO
	if cur.kind == "bloque":
		return -Vector3(cur.size) * cur.voxel * 0.5
	return -Vector3(cur.origin) * cur.voxel


func _place_camera() -> void:
	var y := deg_to_rad(yaw)
	var p := deg_to_rad(pitch)
	cam.look_at_from_position(center + dist * Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)), center, Vector3.UP)


func _frame_camera() -> void:
	if cur == null:
		return
	var s: Vector3 = Vector3(cur.size) * cur.voxel
	if cur.kind == "bloque":
		center = Vector3.ZERO
		dist = 2.4
	else:
		center = Vector3(0, s.y * 0.4, 0)
		dist = maxf(s.y * 1.9, 1.6)
	_place_camera()


func _process(_delta: float) -> void:
	if _dirty_mesh:
		_dirty_mesh = false
		_rebuild_view()


func _rebuild_view() -> void:
	if cur == null:
		mesh_cur.mesh = null
		mesh_other.mesh = null
		return
	var off: Vector3 = model_offset()
	mesh_cur.position = off
	mesh_other.position = off
	var cur_map := {}
	var other_map := {}
	for i in cur.parts.size():
		for c in cur.parts[i].map:
			if cur.only_layer >= 0 and c.y != cur.only_layer:
				continue
			var col: Color = cur.palette[clampi(int(cur.parts[i].map[c]), 0, cur.palette.size() - 1)]
			if i == cur.part:
				cur_map[c] = col
			else:
				other_map[c] = col
	if cur.kind == "bloque":   # cómo queda en cada estado (corrupto, purificado, desactivado)
		var kind: int = ModelLib.BLOCK_NAMES.values().find(cur.block)
		var kind_id: int = int(ModelLib.BLOCK_NAMES.keys()[kind]) if kind >= 0 else 0
		cur_map = BlockModels.state_view(cur_map, kind_id, cur.variant, preview_state)
	mesh_cur.mesh = VoxelMesh.build(cur_map, cur.voxel)
	mesh_other.mesh = VoxelMesh.build(other_map, cur.voxel) if not other_map.is_empty() else null
	_rebuild_guide()
	_rebuild_reference()


func _rebuild_guide() -> void:
	var im := ImmediateMesh.new()
	var s: Vector3 = Vector3(cur.size) * cur.voxel
	var o: Vector3 = model_offset()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var col := Color(0.55, 0.55, 0.7, 0.8)
	for x in range(cur.size.x + 1):   # el piso (y = 0) cuadriculado
		im.surface_set_color(col)
		im.surface_add_vertex(o + Vector3(x * cur.voxel, 0, 0))
		im.surface_add_vertex(o + Vector3(x * cur.voxel, 0, s.z))
	for z in range(cur.size.z + 1):
		im.surface_set_color(col)
		im.surface_add_vertex(o + Vector3(0, 0, z * cur.voxel))
		im.surface_add_vertex(o + Vector3(s.x, 0, z * cur.voxel))
	var top := Color(0.8, 0.7, 0.3, 0.6)
	for c in [Vector3(0, 0, 0), Vector3(s.x, 0, 0), Vector3(0, 0, s.z), Vector3(s.x, 0, s.z)]:   # las aristas de la caja
		im.surface_set_color(top)
		im.surface_add_vertex(o + c)
		im.surface_add_vertex(o + c + Vector3(0, s.y, 0))
	im.surface_end()
	guide.mesh = im
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.vertex_color_use_as_albedo = true
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	guide.material_override = gm


func _rebuild_reference() -> void:
	if ref_node != null and is_instance_valid(ref_node):
		ref_node.queue_free()
		ref_node = null
	if cur == null or cur.kind == "bloque" or not show_char:
		return
	if cur.kind == "personaje":
		return   # (el personaje se edita a sí mismo)
	ref_node = Characters.build_from_code(ref_char, "", "", false)
	ref_node.set_meta("reference", true)
	for ch in ref_node.get_children():   # el personaje de referencia se ve a medias, para no tapar lo que se pinta
		_make_translucent(ch)
	world.add_child(ref_node)


func _make_translucent(n: Node) -> void:
	if n is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		var old = (n as MeshInstance3D).material_override
		mat.albedo_color = (old as StandardMaterial3D).albedo_color if old is StandardMaterial3D else Color.GRAY
		mat.albedo_color.a = 0.28
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		_make_translucent(c)


## La celda de minibloques que está debajo de un punto del mundo.
func cell_at(p: Vector3) -> Vector3i:
	var local: Vector3 = (p - model_offset()) / cur.voxel
	return Vector3i(floori(local.x), floori(local.y), floori(local.z))


## El rayo desde la pantalla (relativa al viewport): {hit, prev} con la primera celda con minibloque y la vacía por la que entró; si no toca ninguno, la celda del piso (y = 0)
## que cruza (en prev) y hit con x = -1000.
func pick(pos: Vector2) -> Dictionary:
	var none := Vector3i(-1000, 0, 0)
	if cur == null:
		return {"hit": none, "prev": none}
	var origin := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	var step: float = cur.voxel * 0.2
	var t := 0.0
	var prev := none
	var floor_cell := none
	var taken := {}
	for i in cur.parts.size():
		for c in cur.parts[i].map:
			taken[c] = true
	while t < 40.0:
		var p := origin + dir * t
		var c := cell_at(p)
		if taken.has(c) and (cur.only_layer < 0 or c.y == cur.only_layer):
			return {"hit": c, "prev": prev if prev.x != -1000 else c}
		if floor_cell.x == -1000 and c.y == 0 and cur.in_box(c) and not taken.has(c):
			floor_cell = c
		if c.y < 0 and floor_cell.x != -1000:
			break
		if cur.in_box(c):
			prev = c
		t += step
	if floor_cell.x != -1000:
		return {"hit": none, "prev": floor_cell}
	return {"hit": none, "prev": none}


func _on_view_input(event: InputEvent) -> void:
	if cur == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			dist = maxf(dist * 0.9, 0.3)
			_place_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			dist = minf(dist * 1.1, 30.0)
			_place_camera()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = "orbit" if mb.pressed else ""
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = "pan" if mb.pressed else ""
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			use_tool_at(mb.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging == "orbit":
			yaw -= mm.relative.x * 0.4
			pitch = clampf(pitch + mm.relative.y * 0.4, -85.0, 85.0)
			_place_camera()
		elif _dragging == "pan":
			var right := cam.global_transform.basis.x
			var up := cam.global_transform.basis.y
			center += (-right * mm.relative.x + up * mm.relative.y) * dist * 0.0016
			_place_camera()
		else:
			_update_hover(mm.position)
			if mm.button_mask & MOUSE_BUTTON_MASK_LEFT != 0 and tool in ["poner", "sacar"]:
				use_tool_at(mm.position)


func _update_hover(pos: Vector2) -> void:
	var r := pick(pos)
	var c: Vector3i = r.hit if tool in ["sacar", "gotero"] else r.prev
	if tool == "capa":
		c = r.prev if r.prev.x != -1000 else r.hit
	hover_box.visible = c.x != -1000
	if hover_box.visible:
		hover_box.scale = Vector3.ONE * cur.voxel * 1.03
		hover_box.position = model_offset() + (Vector3(c) + Vector3(0.5, 0.5, 0.5)) * cur.voxel


## Usa la herramienta elegida en el punto de la pantalla. Devuelve true si cambió algo.
func use_tool_at(pos: Vector2) -> bool:
	var r := pick(pos)
	return apply_tool(r.hit, r.prev)


## La herramienta sobre una cara tocada (`hit` es el minibloque, `prev` la celda vacía de enfrente); lo usan el mouse y las pruebas.
func apply_tool(hit: Vector3i, prev: Vector3i) -> bool:
	var changed := false
	match tool:
		"poner":
			if prev.x != -1000:
				changed = cur.paint(prev)
		"sacar":
			if hit.x != -1000:
				changed = cur.erase(hit)
		"gotero":
			if hit.x != -1000 and cur.pick(hit):
				_build_palette()
		"capa":
			var y: int = (prev if prev.x != -1000 else hit).y
			if y >= 0:
				changed = cur.fill_layer(y) > 0
	if changed:
		_dirty_mesh = true
		_rebuild_list()
		_refresh_meta_status()
	return changed


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or cur == null:
		return
	var k := event as InputEventKey
	if k.ctrl_pressed and k.keycode == KEY_Z:
		_on_undo()
	elif k.ctrl_pressed and k.keycode == KEY_Y:
		_on_redo()
	elif k.ctrl_pressed and k.keycode == KEY_S:
		_on_save()
	elif k.keycode >= KEY_1 and k.keycode <= KEY_8:
		_pick_palette(k.keycode - KEY_1)
	elif k.keycode == KEY_Q:
		layer_spin.value = maxf(layer_spin.value - 1, 0)
	elif k.keycode == KEY_E:
		layer_spin.value = minf(layer_spin.value + 1, layer_spin.max_value)
