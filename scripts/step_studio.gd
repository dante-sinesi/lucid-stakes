extends Control
## Estudio de pasos: el diseñador de piezas chicas de sala (ver scripts/step_lib.gd). Se diseña un paso (bloques, entrada, salida, pozos), se marca un tramo repetible con su rango de largos, se lo resuelve con el
## solucionador exacto (el camino más corto, reproducible) y se prueban todos los largos de una vez. Los pasos se guardan en un archivo .jsonl (por defecto user://pasos.jsonl).
## Se abre desde el Estudio de salas ("Diseñar pasos…") o con herramientas\pasos.bat. Prueba: tests/test_step_studio.gd.

const StepLib := preload("res://scripts/step_lib.gd")
const RoomView := preload("res://scripts/room_view.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")

const TOOLS := [["add", "Agregar bloque (clic en una cara)"], ["delete", "Borrar bloque"], ["type", "Cambiar tipo"], ["entry", "Poner el bloque de inicio, verde (clic en una cara)"], ["exit", "Poner el bloque de fin, rojo (clic en una cara)"], ["hole", "Pozo en el piso (alternar)"], ["slab", "Marcar el tramo repetible (dos clics)"]]
const HINTS := {"add": "Clic en la cara de un bloque o del piso: se agrega un bloque del tipo elegido pegado a esa cara.", "delete": "Clic en un bloque para borrarlo.", "type": "Clic en un bloque: cambia al tipo elegido.",
	"entry": "Clic en una cara: el jugador empieza parado sobre ese bloque, que se pinta de verde (si no hay bloque, se pone uno fijo).", "exit": "Clic en una cara: el jugador tiene que quedar parado sobre ese bloque, que se pinta de rojo y es fijo. La altura de la sala sale de dónde lo pongas.",
	"hole": "Clic en una celda del piso: se quita o se vuelve a poner (un pozo).", "slab": "Clic en la primera columna del tramo y después en la última (a lo largo del eje elegido)."}
const KINDS := [0, 1, 4, 3, 6, 7, 2, 5]

var steps: Array = []
var cur := -1
var current: Dictionary = {}
var dirty := false
var lib_path := "user://pasos.jsonl"
var tool := "add"
var kind_pick := 0
var view_r := 1
var view_only := false
var yaw := 35.0
var pitch := 38.0
var dist := 14.0
var center := Vector3(3, 2, 1)
var slab_first := -1
var undo_stack: Array = []
var redo_stack: Array = []
var last_eval: Dictionary = {}
var play_path: Array = []
var play_i := 0
var playing := false
var play_state = null
var _suppress := false
var _dragging := ""
var _press_pos := Vector2.ZERO
var _moved_px := 0.0
var _user_cam := false

var viewport: SubViewport
var vp_container: SubViewportContainer
var world: Node3D
var blocks_root: Node3D
var cam: Camera3D
var list: ItemList
var status: Label
var path_label: Label
var left_panel: Control
var right_panel: Control
var status_row: Control
var show_panels_btn: Button
var name_edit: LineEdit
var note_edit: LineEdit
var w_spin: SpinBox
var d_spin: SpinBox
var h_spin: SpinBox
var tool_opt: OptionButton
var kind_opt: OptionButton
var rep_check: CheckBox
var axis_opt: OptionButton
var from_spin: SpinBox
var to_spin: SpinBox
var min_spin: SpinBox
var max_spin: SpinBox
var view_spin: SpinBox
var result_label: RichTextLabel
var play_slider: HSlider
var play_label: Label
var play_timer: Timer
var file_dialog: FileDialog
var confirm_delete: ConfirmationDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font_size = 14
	theme = th
	DisplayServer.window_set_title("Estudio de pasos")
	if DisplayServer.get_name() != "headless":
		get_window().size = Vector2i(1700, 950)
		get_window().move_to_center()
	RoomView.register_globals()
	_build_ui()
	_build_world()
	var path := OS.get_environment("STEP_LIB")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lib="):
			path = a.substr(6)
	if path != "":
		lib_path = path
	open_library(lib_path)


# --- interfaz -------------------------------------------------------------------------------------------------------------------

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func _spin(lo: float, hi: float, val: float, cb: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = val
	s.value_changed.connect(cb)
	return s


func _row(label: String, nodes: Array) -> HBoxContainer:
	var r := HBoxContainer.new()
	if label != "":
		r.add_child(_label(label))
	for n in nodes:
		r.add_child(n)
	return r


func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	# izquierda: la biblioteca de pasos
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	root.add_child(left)
	left_panel = left
	var title := _label("Estudio de pasos")
	title.add_theme_font_size_override("font_size", 18)
	left.add_child(title)
	path_label = _label("")
	path_label.clip_text = true
	left.add_child(path_label)
	left.add_child(_row("", [_button("Abrir…", func(): file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE; file_dialog.popup_centered_ratio(0.7)), _button("Guardar", save), _button("Guardar como…", func(): file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE; file_dialog.popup_centered_ratio(0.7))]))
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(func(i): select_step(i))
	left.add_child(list)
	left.add_child(_row("", [_button("Paso nuevo", new_step), _button("Duplicar", duplicate_step), _button("Eliminar", func(): if cur >= 0: confirm_delete.popup_centered())]))
	left.add_child(_button("Volver al Estudio de salas", func(): get_tree().change_scene_to_file("res://scenes/studio.tscn")))
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.jsonl ; Pasos"])
	file_dialog.file_selected.connect(func(p): _file_chosen(p))
	add_child(file_dialog)
	confirm_delete = ConfirmationDialog.new()
	confirm_delete.dialog_text = "¿Eliminar este paso de la biblioteca?"
	confirm_delete.confirmed.connect(delete_step)
	add_child(confirm_delete)
	# centro: la vista
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(mid)
	vp_container = SubViewportContainer.new()
	vp_container.stretch = true
	vp_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vp_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vp_container.gui_input.connect(_on_view_input)
	vp_container.resized.connect(func(): if not _user_cam: _frame_camera())
	mid.add_child(vp_container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(800, 600)
	viewport.handle_input_locally = false
	vp_container.add_child(viewport)
	status = _label("")
	status.custom_minimum_size = Vector2(0, 26)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(status)
	status_row = _row("", [_button("Ver solo el paso (Tab)", func(): set_view_only(true)), _button("Desde atrás del personaje", view_from_behind), _button("Vista en diagonal", view_default)])
	mid.add_child(status_row)
	# derecha: el paso abierto
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	right_panel = scroll
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(right)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "nombre del paso"
	name_edit.text_changed.connect(func(t): if not _suppress and not current.is_empty(): _edit_meta("name", t))
	right.add_child(name_edit)
	note_edit = LineEdit.new()
	note_edit.placeholder_text = "nota"
	note_edit.text_changed.connect(func(t): if not _suppress and not current.is_empty(): _edit_meta("note", t))
	right.add_child(note_edit)
	right.add_child(_label("Ventana (celdas)"))
	w_spin = _spin(2, StepLib.MAX_SIDE, 6, func(v): _resize_window("w", int(v)))
	d_spin = _spin(1, StepLib.MAX_SIDE, 3, func(v): _resize_window("d", int(v)))
	h_spin = _spin(1, StepLib.MAX_H, 5, func(_v): pass)
	h_spin.editable = false
	h_spin.tooltip_text = "La altura sale sola: la del bloque más alto o la del bloque de fin (rojo)."
	right.add_child(_row("largo x", [w_spin, _label("ancho z"), d_spin, _label("alto (sola)"), h_spin]))
	right.add_child(_label("Herramienta (botón izquierdo)"))
	tool_opt = OptionButton.new()
	for t in TOOLS:
		tool_opt.add_item(t[1])
	tool_opt.item_selected.connect(func(i): set_tool(TOOLS[i][0]))
	right.add_child(tool_opt)
	kind_opt = OptionButton.new()
	for k in KINDS:
		kind_opt.add_item(String(StepLib.KIND_NAMES[k]))
	kind_opt.item_selected.connect(func(i): kind_pick = KINDS[i])
	right.add_child(_row("Tipo de bloque", [kind_opt]))
	right.add_child(_row("", [_button("Deshacer", undo), _button("Rehacer", redo)]))
	right.add_child(HSeparator.new())
	right.add_child(_label("Tramo repetible (el largo del camino)"))
	rep_check = CheckBox.new()
	rep_check.text = "Hay un tramo que se repite"
	rep_check.toggled.connect(func(on): _set_repeat("on", on))
	right.add_child(rep_check)
	axis_opt = OptionButton.new()
	axis_opt.add_item("a lo largo de x")
	axis_opt.add_item("a lo largo de z")
	axis_opt.item_selected.connect(func(i): _set_repeat("axis", "x" if i == 0 else "z"))
	right.add_child(axis_opt)
	from_spin = _spin(0, StepLib.MAX_SIDE, 1, func(v): _set_repeat("from", int(v)))
	to_spin = _spin(0, StepLib.MAX_SIDE, 1, func(v): _set_repeat("to", int(v)))
	right.add_child(_row("columnas desde", [from_spin, _label("hasta"), to_spin]))
	min_spin = _spin(1, 12, 1, func(v): _set_repeat("min", int(v)))
	max_spin = _spin(1, 12, 4, func(v): _set_repeat("max", int(v)))
	right.add_child(_row("se repite de", [min_spin, _label("a"), max_spin, _label("veces")]))
	view_spin = _spin(1, 12, 1, func(v): set_view_r(int(v)))
	right.add_child(_row("Ver con", [view_spin, _label("repeticiones (1 para editar)")]))
	right.add_child(HSeparator.new())
	right.add_child(_row("", [_button("Resolver este largo", solve_current), _button("Probar todos los largos", run_all_lengths)]))
	result_label = RichTextLabel.new()
	result_label.bbcode_enabled = true
	result_label.fit_content = true
	result_label.custom_minimum_size = Vector2(380, 80)
	right.add_child(result_label)
	right.add_child(_label("Camino más corto"))
	play_slider = HSlider.new()
	play_slider.min_value = 0
	play_slider.max_value = 0
	play_slider.step = 1
	play_slider.value_changed.connect(func(v): if not _suppress: play_goto(int(v)))
	right.add_child(play_slider)
	play_label = _label("")
	right.add_child(_row("", [_button("⏮", func(): play_goto(0)), _button("◀", func(): play_goto(play_i - 1)), _button("▶ Reproducir", toggle_play), _button("▶|", func(): play_goto(play_i + 1)), play_label]))
	play_timer = Timer.new()
	play_timer.wait_time = 0.35
	play_timer.timeout.connect(_on_play_tick)
	add_child(play_timer)
	show_panels_btn = _button("Mostrar paneles (Tab)", func(): set_view_only(false))
	show_panels_btn.visible = false
	show_panels_btn.position = Vector2(8, 8)
	add_child(show_panels_btn)


func _build_world() -> void:
	world = Node3D.new()
	viewport.add_child(world)
	RoomView.add_lighting(world)
	blocks_root = Node3D.new()
	world.add_child(blocks_root)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 300.0
	world.add_child(cam)
	cam.make_current()
	_place_cam()


func _place_cam() -> void:
	if cam != null:
		RoomView.place_camera(cam, center, yaw, pitch, dist)


func _fit_distance(radius: float) -> float:
	var vs := viewport.size
	var aspect := float(vs.x) / maxf(float(vs.y), 1.0)
	var half_v := deg_to_rad(cam.fov * 0.5)
	var half_h := atan(tan(half_v) * aspect)
	return radius / sin(minf(half_v, half_h)) * 1.08


func _frame_camera() -> void:
	var inst := _view_inst()
	center = Vector3(float(inst.w) * 0.5, float(int(inst.h) + 1) * 0.4, float(inst.d) * 0.5)
	dist = _fit_distance(Vector3(float(inst.w), float(int(inst.h) + 1), float(inst.d)).length() * 0.5)
	_place_cam()


func set_view_only(on: bool) -> void:
	view_only = on
	left_panel.visible = not on
	right_panel.visible = not on
	status.visible = not on
	status_row.visible = not on
	show_panels_btn.visible = on
	_user_cam = false
	_frame_camera()


func view_from_behind() -> void:
	if current.is_empty():
		return
	var inst := _view_inst()
	var dx := float(inst.exit[0] - inst.entry[0])
	var dz := float(inst.exit[2] - inst.entry[2])
	yaw = rad_to_deg(atan2(-dx, -dz)) if absf(dx) + absf(dz) > 0.0 else 180.0
	pitch = 28.0
	_user_cam = false
	_frame_camera()


func view_default() -> void:
	yaw = 35.0
	pitch = 38.0
	_user_cam = false
	_frame_camera()


func _set_status(t: String) -> void:
	status.text = t


# --- biblioteca ---------------------------------------------------------------------------------------------------------------

func open_library(path: String) -> int:
	lib_path = path
	steps = StepLib.read_file(path)
	if steps.is_empty() and not FileAccess.file_exists(path):
		steps = StepLib.examples()   # (todavía no hay biblioteca: se muestran los ejemplos; se guardan con Guardar)
	path_label.text = path
	cur = -1
	current = {}
	dirty = false
	undo_stack.clear()
	redo_stack.clear()
	if steps.is_empty():
		_set_status("No hay pasos en %s: creá uno con \"Paso nuevo\"." % path)
	else:
		select_step(0)
	refresh_all()
	return steps.size()


func _file_chosen(p: String) -> void:
	if file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		lib_path = p
		save()
	else:
		open_library(p)


func save() -> bool:
	if not current.is_empty() and cur >= 0:
		StepLib.finalize(current)
		current.stamp = int(Time.get_unix_time_from_system())
		steps[cur] = StepLib.copy_step(current)
	var ok := StepLib.write_file(lib_path, steps)
	dirty = not ok and dirty
	if ok:
		dirty = false
	path_label.text = lib_path
	_set_status(("Guardado: %d pasos en %s" % [steps.size(), lib_path]) if ok else "No se pudo guardar en " + lib_path)
	refresh_list()
	return ok


func select_step(i: int) -> void:
	if cur >= 0 and not current.is_empty() and cur < steps.size():
		steps[cur] = StepLib.copy_step(current)
	if i < 0 or i >= steps.size():
		return
	cur = i
	current = StepLib.copy_step(steps[i])
	undo_stack.clear()
	redo_stack.clear()
	last_eval = {}
	play_path = []
	_stop_play()
	view_r = 1
	slab_first = -1
	refresh_all()
	_user_cam = false
	_frame_camera()


func new_step() -> void:
	if cur >= 0 and not current.is_empty():
		steps[cur] = StepLib.copy_step(current)
	var s := StepLib.make_step("Paso %d" % (steps.size() + 1))
	StepLib.finalize(s)
	steps.append(s)
	dirty = true
	select_step(steps.size() - 1)


func duplicate_step() -> void:
	if current.is_empty():
		return
	var s := StepLib.copy_step(current)
	s.name = str(s.name) + " (copia)"
	StepLib.finalize(s)
	steps.append(s)
	dirty = true
	select_step(steps.size() - 1)


func delete_step() -> void:
	if cur < 0 or cur >= steps.size():
		return
	steps.remove_at(cur)
	cur = -1
	current = {}
	dirty = true
	if steps.is_empty():
		refresh_all()
	else:
		select_step(0)


func _row_text(s: Dictionary) -> String:
	var rep: Dictionary = s.repeat
	var t := "%s · %dx%d" % [s.name, int(s.w), int(s.d)]
	if bool(rep.on):
		t += " · largos %d-%d" % [int(rep.min), int(rep.max)]
	var res: Dictionary = s.get("results", {})
	if not res.is_empty():
		var ok := 0
		for k in res:
			ok += 1 if bool(res[k].get("ok", false)) else 0
		t += "  [%d/%d ✓]" % [ok, res.size()]
	return t


func refresh_list() -> void:
	list.clear()
	for i in steps.size():
		list.add_item(_row_text(current if i == cur and not current.is_empty() else steps[i]))
	if cur >= 0 and cur < list.item_count:
		list.select(cur)


func refresh_all() -> void:
	refresh_list()
	_refresh_form()
	_refresh_view()


func _refresh_form() -> void:
	_suppress = true
	var has := not current.is_empty()
	for c in [name_edit, note_edit, w_spin, d_spin, rep_check, axis_opt, from_spin, to_spin, min_spin, max_spin, view_spin]:
		if c is BaseButton:
			(c as BaseButton).disabled = not has
		elif c is SpinBox:
			(c as SpinBox).editable = has
		elif c is LineEdit:
			(c as LineEdit).editable = has
	if has:
		name_edit.text = str(current.name)
		note_edit.text = str(current.note)
		w_spin.value = int(current.w)
		d_spin.value = int(current.d)
		h_spin.value = int(current.h)
		var rep: Dictionary = current.repeat
		rep_check.button_pressed = bool(rep.on)
		axis_opt.select(0 if rep.axis == "x" else 1)
		from_spin.value = int(rep.from)
		to_spin.value = int(rep.to)
		min_spin.value = int(rep.min)
		max_spin.value = int(rep.max)
		view_spin.value = view_r
		var lim: int = (int(current.w) if rep.axis == "x" else int(current.d)) - 1
		from_spin.max_value = maxi(lim, 0)
		to_spin.max_value = maxi(lim, 0)
		_show_results()
	else:
		result_label.text = ""
	_suppress = false


func _show_results() -> void:
	var t := ""
	var res: Dictionary = current.get("results", {})
	var keys: Array = res.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	for k in keys:
		var r: Dictionary = res[k]
		t += "[b]largo %s[/b]: %s\n" % [str(k), str(r.get("text", ""))]
	var err := StepLib.validate(current)
	if err != "":
		t = "[color=#ff9060]%s[/color]\n" % err + t
	result_label.text = t


# --- vista --------------------------------------------------------------------------------------------------------------------

## El paso que se está mirando: el diseñado, o con el tramo repetido `view_r` veces.
func _view_inst() -> Dictionary:
	if current.is_empty():
		return StepLib.make_step()
	if bool(current.repeat.on) and StepLib.validate(current) == "":
		return StepLib.instantiate(current, view_r)
	return current


func view_state():
	if play_state != null:
		return play_state
	var inst := _view_inst()
	if StepLib.validate(inst) != "":
		return null
	return StepLib.build_state(inst)


func _refresh_view() -> void:
	if blocks_root == null:
		return
	if current.is_empty():
		RoomView.populate(blocks_root, null, {"h": 5, "entry": Vector2i.ZERO})
		return
	var inst := _view_inst()
	var st = view_state()
	if st == null:
		RoomView.populate(blocks_root, null, {"h": 5, "entry": Vector2i.ZERO})
		return
	var room := {"h": int(inst.h), "entry": Vector2i(int(inst.entry[0]), int(inst.entry[2])), "entry_y": int(inst.entry[1]),
		"start_block": Vector3i(int(inst.entry[0]), int(inst.entry[1]) - 1, int(inst.entry[2])), "end_block": Vector3i(int(inst.exit[0]), int(inst.exit[1]) - 1, int(inst.exit[2]))}
	var hl: Array = []
	var rep: Dictionary = current.repeat
	if bool(rep.on):
		var k := int(rep.to) - int(rep.from) + 1
		var n := view_r
		for i in k * n:
			var v := int(rep.from) + i
			if rep.axis == "x":
				for z in int(inst.d):
					hl.append(Vector3i(v, 0, z))
			else:
				for x in int(inst.w):
					hl.append(Vector3i(x, 0, v))
	RoomView.populate(blocks_root, st, room, play_state != null or true, hl)


func set_view_r(r: int) -> void:
	view_r = clampi(r, 1, 12)
	_stop_play()
	play_state = null
	_user_cam = false
	_refresh_view()
	_frame_camera()
	if view_r != 1:
		_set_status("Mirando con %d repeticiones: para editar volvé a 1." % view_r)


func _on_view_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_pos = mb.position
				_moved_px = 0.0
				_dragging = "click"
			elif _dragging == "click":
				_dragging = ""
				if _moved_px < 5.0:
					click_at(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = "orbit" if mb.pressed else ""
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = "pan" if mb.pressed else ""
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_user_cam = true
			dist = maxf(dist * 0.9, 3.0)
			_place_cam()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_user_cam = true
			dist = minf(dist * 1.1, 120.0)
			_place_cam()
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		_moved_px += mm.relative.length()
		if _dragging == "orbit" or _dragging == "pan":
			_user_cam = true
		if _dragging == "orbit":
			yaw -= mm.relative.x * 0.4
			pitch = clampf(pitch + mm.relative.y * 0.4, 4.0, 88.0)
			_place_cam()
		elif _dragging == "pan":
			var right := cam.global_transform.basis.x
			var up := cam.global_transform.basis.y
			center += (-right * mm.relative.x + up * mm.relative.y) * dist * 0.0016
			_place_cam()


func _unhandled_key_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_TAB:
		set_view_only(not view_only)
	elif k.ctrl_pressed and k.keycode == KEY_Z:
		undo()
	elif k.ctrl_pressed and k.keycode == KEY_Y:
		redo()
	elif k.ctrl_pressed and k.keycode == KEY_S:
		save()


# --- edición ------------------------------------------------------------------------------------------------------------------

func set_tool(name: String) -> void:
	tool = name
	slab_first = -1
	for i in TOOLS.size():
		if TOOLS[i][0] == name and tool_opt != null:
			tool_opt.select(i)
	_set_status(str(HINTS.get(name, "")))


func _can_edit() -> bool:
	if current.is_empty():
		return false
	if view_r != 1 and bool(current.repeat.on):
		_set_status("Mirando con %d repeticiones: volvé a 1 para editar." % view_r)
		return false
	if play_state != null:
		_stop_play()
		play_state = null
		_refresh_view()
	return true


func _push_undo() -> void:
	undo_stack.append(StepLib.copy_step(current))
	if undo_stack.size() > 100:
		undo_stack.pop_front()
	redo_stack.clear()


func _changed() -> void:
	dirty = true
	last_eval = {}
	play_path = []
	_stop_play()
	play_state = null
	_auto_height()
	StepLib.finalize(current)
	current.results = {}
	refresh_all()


## La altura de la ventana sale de lo más alto que hay: el bloque más alto o el bloque de fin (rojo), con un mínimo de 3.
func _auto_height() -> void:
	var top := 3
	for b in current.blocks:
		top = maxi(top, int(b[1]))
	top = maxi(top, int(current.exit[1]) - 1)
	top = maxi(top, int(current.entry[1]) - 1)
	current.h = mini(top, StepLib.MAX_H)


func undo() -> bool:
	if undo_stack.is_empty():
		return false
	redo_stack.append(StepLib.copy_step(current))
	current = undo_stack.pop_back()
	dirty = true
	refresh_all()
	return true


func redo() -> bool:
	if redo_stack.is_empty():
		return false
	undo_stack.append(StepLib.copy_step(current))
	current = redo_stack.pop_back()
	dirty = true
	refresh_all()
	return true


func _edit_meta(key: String, v: String) -> void:
	current[key] = v
	dirty = true
	refresh_list()


func _resize_window(key: String, v: int) -> void:
	if _suppress or not _can_edit():
		return
	if int(current[key]) == v:
		return
	_push_undo()
	current[key] = v
	# lo que queda fuera de la ventana se saca
	var keep: Array = []
	for b in current.blocks:
		if int(b[0]) < int(current.w) and int(b[2]) < int(current.d) and int(b[1]) <= int(current.h):
			keep.append(b)
	current.blocks = keep
	var keep_h: Array = []
	for ho in current.holes:
		if int(ho[0]) < int(current.w) and int(ho[1]) < int(current.d):
			keep_h.append(ho)
	current.holes = keep_h
	for port in ["entry", "exit"]:
		var p: Array = current[port]
		p[0] = mini(int(p[0]), int(current.w) - 1)
		p[2] = mini(int(p[2]), int(current.d) - 1)
		p[1] = mini(int(p[1]), int(current.h) + 1)
	_changed()
	_user_cam = false
	_frame_camera()


func _set_repeat(key: String, v) -> void:
	if _suppress or not _can_edit():
		return
	if current.repeat[key] == v:
		return
	_push_undo()
	current.repeat[key] = v
	if key == "to" and int(current.repeat.to) < int(current.repeat.from):
		current.repeat.from = current.repeat.to
	if key == "from" and int(current.repeat.from) > int(current.repeat.to):
		current.repeat.to = current.repeat.from
	if key == "max" and int(current.repeat.max) < int(current.repeat.min):
		current.repeat.min = current.repeat.max
	if key == "min" and int(current.repeat.min) > int(current.repeat.max):
		current.repeat.max = current.repeat.min
	_changed()


## La celda del piso que toca el rayo de la pantalla (plano y = 0.5).
func floor_cell_at(pos: Vector2) -> Vector2i:
	var o := cam.project_ray_origin(pos)
	var d := cam.project_ray_normal(pos)
	if absf(d.y) < 0.0001:
		return Vector2i(-1000, -1000)
	var t := (0.5 - o.y) / d.y
	if t < 0.0:
		return Vector2i(-1000, -1000)
	var p := o + d * t
	return Vector2i(floori(p.x), floori(p.z))


func click_at(pos: Vector2) -> void:
	if current.is_empty():
		return
	if tool == "hole" or tool == "slab":
		var fc := floor_cell_at(pos)
		if fc.x != -1000:
			click_floor(fc)
		return
	var st = view_state()
	if st == null:
		return
	var f := RoomView.pick_face(cam, pos, st)
	if f.hit.x == -1000:
		return
	click_face(f.hit, f.prev)


## Usa la herramienta sobre la cara tocada: `hit` es el bloque, `prev` la celda vacía pegada a esa cara.
func click_face(hit: Vector3i, prev: Vector3i) -> void:
	if not _can_edit():
		return
	match tool:
		"add":
			if prev.x < 0 or prev.x >= int(current.w) or prev.z < 0 or prev.z >= int(current.d) or prev.y < 1 or prev.y > StepLib.MAX_H:
				_set_status("Eso queda fuera de la ventana (el ancho y el largo se cambian a la derecha; el alto llega hasta %d)." % StepLib.MAX_H)
				return
			if _block_index(prev) >= 0:
				_set_status("Ahí ya hay un bloque.")
				return
			if prev == _port("entry") or prev == _port("exit"):
				_set_status("Ahí está una puerta.")
				return
			_push_undo()
			current.blocks.append([prev.x, prev.y, prev.z, kind_pick])
			_changed()
		"delete":
			var i := _block_index(hit)
			if i < 0:
				_set_status("Ahí no hay un bloque para borrar (el piso y la plataforma de salida no se borran).")
				return
			_push_undo()
			current.blocks.remove_at(i)
			_changed()
		"type":
			var j := _block_index(hit)
			if j < 0:
				_set_status("Ahí no hay un bloque.")
				return
			_push_undo()
			current.blocks[j][3] = kind_pick
			_changed()
		"entry", "exit":
			if prev.x < 0 or prev.x >= int(current.w) or prev.z < 0 or prev.z >= int(current.d) or prev.y < 1 or prev.y > StepLib.MAX_H + 1:
				_set_status("Eso queda fuera de la ventana.")
				return
			if _block_index(prev) >= 0:
				return
			_push_undo()
			current[tool] = [prev.x, prev.y, prev.z]
			_changed()


func click_floor(c: Vector2i) -> void:
	if not _can_edit():
		return
	if c.x < 0 or c.x >= int(current.w) or c.y < 0 or c.y >= int(current.d):
		return
	if tool == "hole":
		_push_undo()
		var idx := -1
		for i in current.holes.size():
			if int(current.holes[i][0]) == c.x and int(current.holes[i][1]) == c.y:
				idx = i
		if idx >= 0:
			current.holes.remove_at(idx)
		else:
			current.holes.append([c.x, c.y])
		_changed()
	elif tool == "slab":
		var v := c.x if current.repeat.axis == "x" else c.y
		if slab_first < 0:
			slab_first = v
			_set_status("Primera columna: %d. Ahora hacé clic en la última." % v)
		else:
			_push_undo()
			current.repeat.on = true
			current.repeat.from = mini(slab_first, v)
			current.repeat.to = maxi(slab_first, v)
			slab_first = -1
			_changed()
			_set_status("Tramo repetible: columnas %d a %d." % [int(current.repeat.from), int(current.repeat.to)])


func _port(key: String) -> Vector3i:
	return Vector3i(int(current[key][0]), int(current[key][1]), int(current[key][2]))


func _block_index(c: Vector3i) -> int:
	for i in current.blocks.size():
		var b: Array = current.blocks[i]
		if int(b[0]) == c.x and int(b[1]) == c.y and int(b[2]) == c.z:
			return i
	return -1


# --- resolver ------------------------------------------------------------------------------------------------------------------

## Resuelve el largo que se está mirando (el camino más corto) y lo deja para reproducir.
func solve_current() -> Dictionary:
	if current.is_empty():
		return {}
	var err := StepLib.validate(current)
	if err != "":
		_set_status(err)
		return {"ok": false, "why": err}
	var inst := _view_inst()
	_set_status("Resolviendo…")
	var ev := StepLib.evaluate(inst)
	last_eval = ev
	current.results[str(view_r)] = {"ok": bool(ev.ok), "moves": int(ev.get("moves", 0)), "grabs": int(ev.get("grabs", 0)), "hangs": int(ev.get("hangs", 0)), "slides": int(ev.get("slides", 0)), "text": StepLib.describe(ev)}
	play_path = ev.path if bool(ev.ok) else []
	play_i = 0
	play_state = null
	_refresh_play_ui()
	_show_results()
	refresh_list()
	_refresh_view()
	_set_status("Largo %d: %s" % [view_r, StepLib.describe(ev)])
	return ev


## Resuelve cada largo del rango por separado y muestra el resultado de todos.
func run_all_lengths() -> Dictionary:
	if current.is_empty():
		return {}
	var err := StepLib.validate(current)
	if err != "":
		_set_status(err)
		return {}
	var out := {}
	current.results = {}
	for r in StepLib.lengths(current):
		var inst := StepLib.instantiate(current, r)
		var ev := StepLib.evaluate(inst, 400000, 15000)
		out[r] = ev
		current.results[str(r)] = {"ok": bool(ev.ok), "moves": int(ev.get("moves", 0)), "grabs": int(ev.get("grabs", 0)), "hangs": int(ev.get("hangs", 0)), "slides": int(ev.get("slides", 0)), "text": StepLib.describe(ev)}
	_show_results()
	refresh_list()
	var ok := 0
	for r in out:
		ok += 1 if bool(out[r].ok) else 0
	_set_status("Largos que se resuelven: %d de %d." % [ok, out.size()])
	return out


# --- reproducción del camino ---------------------------------------------------------------------------------------------------

func _refresh_play_ui() -> void:
	_suppress = true
	play_slider.max_value = play_path.size()
	play_slider.value = play_i
	_suppress = false
	play_label.text = ("%d / %d" % [play_i, play_path.size()]) if not play_path.is_empty() else ""


func play_goto(i: int) -> void:
	if play_path.is_empty():
		return
	play_i = clampi(i, 0, play_path.size())
	var t = StepLib.build_state(_view_inst())
	for k in play_i:
		t.try_action(play_path[k].dir, play_path[k].mode)
	play_state = t if play_i > 0 else null
	_refresh_play_ui()
	_refresh_view()


func toggle_play() -> void:
	if playing:
		_stop_play()
		return
	if play_path.is_empty():
		solve_current()
		if play_path.is_empty():
			return
	if play_i >= play_path.size():
		play_goto(0)
	playing = true
	play_timer.start()


func _stop_play() -> void:
	playing = false
	if play_timer != null:
		play_timer.stop()


func _on_play_tick() -> void:
	if play_i >= play_path.size():
		_stop_play()
		return
	play_goto(play_i + 1)
