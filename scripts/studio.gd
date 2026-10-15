extends Control
## Estudio de salas: ver, jugar, corregir y anotar las salas de la biblioteca. La lógica está en studio_model.gd; acá van la vista 3D (la misma que el juego: minibloques y shader), el orbitar
## de la cámara, el elegir bloques con el mouse y los paneles. Uso: Godot --path . res://scenes/studio.tscn -- --lib=ARCHIVO.jsonl (o .rooms)
##
## Mouse: botón izquierdo = usar la herramienta sobre el bloque; derecho (arrastrar) = girar; medio (arrastrar) = mover; rueda = acercar. Teclas: Ctrl+Z deshacer, Ctrl+Y rehacer, Ctrl+S guardar, Supr borrar, Esc cancelar.

const RoomLib := preload("res://scripts/room_lib.gd")
const RoomView := preload("res://scripts/room_view.gd")
const StudioModel := preload("res://scripts/studio_model.gd")

const TOOLS := [["select", "Seleccionar"], ["add", "Agregar bloque arriba"], ["delete", "Borrar bloque"], ["type", "Cambiar tipo"], ["move", "Mover a otra columna"], ["add_side", "Agregar pegado a una cara"], ["delete_gap", "Borrar y dejar el hueco"]]
const SHAPE_NAMES := {"3x3": "Chica (3x3)", "3x5": "Mediana (3x5)", "3x8": "Grande (3x8)", "L": "L", "U": "U"}
const SORTS := [["diff", "Dificultad"], ["grabs", "Empujes y tirones"], ["moved", "Bloques distintos"], ["moves", "Pasos"], ["h", "Altura"], ["reciente", "Recientes"]]

var model := StudioModel.new()
var lib_path := ""
var yaw := 35.0
var pitch := 38.0
var dist := 16.0
var center := Vector3(4, 3, 3)
var tool := "select"
var kind_pick := "n"
var sel := {}
var move_src := {}
var thumbs := {}
var _list_ids: Array = []
var _dragging := ""
var _press_pos := Vector2.ZERO
var _moved_px := 0.0
var _suppress := false
var playing := false      # (Timer.is_stopped() da verdadero durante el aviso de un temporizador repetido: se lleva la cuenta aparte)
var _user_cam := false   # el usuario movió la cámara: no se reencuadra sola al cambiar el tamaño

var vp_container: SubViewportContainer
var viewport: SubViewport
var world: Node3D
var blocks_root: Node3D
var cam: Camera3D
var list: ItemList
var info: RichTextLabel
var status: Label
var count_label: Label
var path_label: Label
var f_shape: OptionButton
var f_hlo: SpinBox
var f_hhi: SpinBox
var f_moves: SpinBox
var f_grabs: SpinBox
var f_diff: SpinBox
var f_status: OptionButton
var f_origin: OptionButton
var f_proof: OptionButton
var f_text: LineEdit
var f_sort: OptionButton
var tool_opt: OptionButton
var kind_opt: OptionButton
var variant_checks := {}
var status_opt: OptionButton
var note_edit: LineEdit
var play_slider: HSlider
var play_btn: Button
var play_timer: Timer
var similar_box: VBoxContainer
var new_shape: OptionButton
var new_h: SpinBox
var file_dialog: FileDialog
var confirm_delete: ConfirmationDialog
var save_btn: Button
var save_new_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font_size = 14
	theme = th
	DisplayServer.window_set_title("Estudio de salas")
	if DisplayServer.get_name() != "headless":
		get_window().size = Vector2i(1700, 950)
		get_window().move_to_center()
	RoomView.register_globals()
	_build_ui()
	_build_world()
	var path := OS.get_environment("STUDIO_LIB")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lib="):
			path = a.substr(6)
	if path == "":
		path = "user://biblioteca/biblioteca.jsonl"
	if FileAccess.file_exists(path):
		open_library(path)
	else:
		path_label.text = "(no hay biblioteca: abrí un archivo .jsonl o .rooms)"
		_set_status("No se encontró " + path)
		refresh_all()


# --- armado de la interfaz ------------------------------------------------------------------------------------------------------

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _option(items: Array, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.item_selected.connect(cb)
	o.focus_mode = Control.FOCUS_NONE
	return o


func _spin(lo: float, hi: float, val: float, cb: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = val
	s.value_changed.connect(cb)
	return s


func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	# --- izquierda: biblioteca
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(310, 0)
	root.add_child(left)
	var title := _label("Estudio de salas")
	title.add_theme_font_size_override("font_size", 18)
	left.add_child(title)
	path_label = _label("")
	path_label.clip_text = true
	left.add_child(path_label)
	var file_row := HBoxContainer.new()
	file_row.add_child(_button("Abrir…", func(): file_dialog.popup_centered_ratio(0.7)))
	file_row.add_child(_button("Recargar", func(): if lib_path != "": open_library(lib_path)))
	left.add_child(file_row)
	var shapes: Array = ["(todos)"]
	for sh in RoomLib.SHAPES:
		shapes.append(SHAPE_NAMES[sh])
	f_shape = _option(shapes, func(_i): refresh_list())
	var row1 := HBoxContainer.new()
	row1.add_child(_label("Tipo"))
	row1.add_child(f_shape)
	row1.add_child(_label("Orden"))
	f_sort = _option(SORTS.map(func(s): return s[1]), func(_i): refresh_list())
	row1.add_child(f_sort)
	left.add_child(row1)
	var row2 := HBoxContainer.new()
	row2.add_child(_label("Altura (pisos) de"))
	f_hlo = _spin(0, 20, 0, func(_v): refresh_list())
	f_hhi = _spin(0, 20, 20, func(_v): refresh_list())
	row2.add_child(f_hlo)
	row2.add_child(_label("a"))
	row2.add_child(f_hhi)
	left.add_child(row2)
	var row2a := HBoxContainer.new()
	row2a.add_child(_label("Pasos ≥"))
	f_moves = _spin(0, 400, 0, func(_v): refresh_list())
	row2a.add_child(f_moves)
	row2a.add_child(_label("Con desplazamiento ≥"))
	f_grabs = _spin(0, 60, 0, func(_v): refresh_list())
	row2a.add_child(f_grabs)
	left.add_child(row2a)
	var row2b := HBoxContainer.new()
	row2b.add_child(_label("Dificultad ≥ %"))
	f_diff = _spin(0, 100, 0, func(_v): refresh_list())
	row2b.add_child(f_diff)
	row2b.add_child(_button("Limpiar filtros", clear_filters))
	left.add_child(row2b)
	var row3 := HBoxContainer.new()
	f_status = _option(["(todos)"] + RoomLib.STATUSES, func(_i): refresh_list())
	f_origin = _option(["(todos)", "minero", "manual", "autor"], func(_i): refresh_list())
	f_proof = _option(["(todas)", "exacta", "cota", "sin_probar"], func(_i): refresh_list())
	row3.add_child(f_status)
	row3.add_child(f_origin)
	row3.add_child(f_proof)
	left.add_child(row3)
	f_text = LineEdit.new()
	f_text.placeholder_text = "buscar por id, familia o patrón"
	f_text.text_changed.connect(func(_t): refresh_list())
	left.add_child(f_text)
	count_label = _label("")
	count_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(count_label)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(_on_list_selected)
	left.add_child(list)
	var new_row := HBoxContainer.new()
	new_shape = _option(RoomLib.SHAPES.map(func(sh): return SHAPE_NAMES[sh]), func(_i): pass)
	new_h = _spin(RoomLib.MIN_H, RoomLib.MAX_H, 6, func(_v): pass)
	new_row.add_child(_button("Sala nueva", do_new))
	new_row.add_child(new_shape)
	new_row.add_child(new_h)
	left.add_child(new_row)
	# --- centro: la sala
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
	# --- derecha: la sala abierta
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(370, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(right)
	info = RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.custom_minimum_size = Vector2(350, 120)
	info.scroll_active = false
	right.add_child(info)
	right.add_child(HSeparator.new())
	right.add_child(_label("Herramienta (botón izquierdo)"))
	tool_opt = _option(TOOLS.map(func(t): return t[1]), func(i): set_tool(TOOLS[i][0]))
	right.add_child(tool_opt)
	var kind_row := HBoxContainer.new()
	kind_row.add_child(_label("Tipo de bloque"))
	kind_opt = _option(StudioModel.KINDS.map(func(k): return StudioModel.KIND_NAMES[k]), func(i): kind_pick = StudioModel.KINDS[i])
	kind_row.add_child(kind_opt)
	right.add_child(kind_row)
	var edit_row := HBoxContainer.new()
	edit_row.add_child(_button("Deshacer", do_undo))
	edit_row.add_child(_button("Rehacer", do_redo))
	edit_row.add_child(_button("Descartar", do_revert))
	right.add_child(edit_row)
	var ver_row := HBoxContainer.new()
	ver_row.add_child(_button("Verificar", do_verify))
	ver_row.add_child(_button("Verificar a fondo", do_verify_exact))
	right.add_child(ver_row)
	var opt_row := HBoxContainer.new()
	opt_row.add_child(_button("Podar relleno", do_prune))
	opt_row.add_child(_button("Mejorar camino", do_optimize))
	right.add_child(opt_row)
	var save_row := HBoxContainer.new()
	save_btn = _button("Guardar", do_save)
	save_new_btn = _button("Como nueva", do_save_new)
	save_row.add_child(save_btn)
	save_row.add_child(save_new_btn)
	save_row.add_child(_button("Eliminar", func(): if model.has_current() and model.original_id != "": confirm_delete.popup_centered()))
	right.add_child(save_row)
	right.add_child(HSeparator.new())
	right.add_child(_label("Estado y nota"))
	var st_row := HBoxContainer.new()
	status_opt = _option(RoomLib.STATUSES, func(_i): pass)
	note_edit = LineEdit.new()
	note_edit.placeholder_text = "nota"
	note_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st_row.add_child(status_opt)
	st_row.add_child(note_edit)
	st_row.add_child(_button("Marcar", do_annotate))
	right.add_child(st_row)
	right.add_child(HSeparator.new())
	right.add_child(_label("Este bloque puede ser también…"))
	var var_row := HBoxContainer.new()
	for k in StudioModel.KINDS:
		var cb := CheckBox.new()
		cb.text = StudioModel.KIND_NAMES[k]
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(_on): _on_variant_toggled())
		variant_checks[k] = cb
		var_row.add_child(cb)
	right.add_child(var_row)
	var var_btn := HBoxContainer.new()
	var_btn.add_child(_button("Probar variantes", do_check_variants))
	var_btn.add_child(_button("Crear variantes", do_create_variants))
	right.add_child(var_btn)
	right.add_child(HSeparator.new())
	right.add_child(_label("Camino más corto"))
	var play_row := HBoxContainer.new()
	play_row.add_child(_button("⏮", func(): play_goto(0)))
	play_row.add_child(_button("◀", func(): play_goto(model.play_index - 1)))
	play_btn = _button("▶ Reproducir", toggle_play)
	play_row.add_child(play_btn)
	play_row.add_child(_button("▶|", func(): play_goto(model.play_index + 1)))
	right.add_child(play_row)
	play_slider = HSlider.new()
	play_slider.min_value = 0
	play_slider.max_value = 1
	play_slider.step = 1
	play_slider.value_changed.connect(func(v): if not _suppress: play_goto(int(v)))
	right.add_child(play_slider)
	play_timer = Timer.new()
	play_timer.wait_time = 0.35
	play_timer.timeout.connect(_on_play_tick)
	add_child(play_timer)
	right.add_child(HSeparator.new())
	right.add_child(_label("Salas más parecidas"))
	similar_box = VBoxContainer.new()
	right.add_child(similar_box)
	# diálogos
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.jsonl ; Biblioteca de texto", "*.rooms ; Biblioteca comprimida"])
	file_dialog.file_selected.connect(func(p): open_library(p))
	add_child(file_dialog)
	confirm_delete = ConfirmationDialog.new()
	confirm_delete.dialog_text = "¿Eliminar esta sala de la biblioteca? No se puede deshacer."
	confirm_delete.confirmed.connect(do_delete)
	add_child(confirm_delete)


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


## A qué distancia hay que poner la cámara para que entre una esfera de ese radio (según el ancho y el alto de la vista).
func fit_distance(radius: float) -> float:
	var vs := viewport.size
	var aspect := float(vs.x) / maxf(float(vs.y), 1.0)
	var half_v := deg_to_rad(cam.fov * 0.5)
	var half_h := atan(tan(half_v) * aspect)
	return radius / sin(minf(half_v, half_h)) * 1.08


func _frame_camera() -> void:
	if not model.has_current():
		return
	var b := RoomView.bounds(model.current)
	center = b.center
	dist = fit_distance(float(b.radius))
	_place_cam()


# --- biblioteca y lista -------------------------------------------------------------------------------------------------------------

func open_library(path: String) -> int:
	lib_path = path
	var n := model.load_file(path)
	path_label.text = path
	sel = {}
	move_src = {}
	thumbs.clear()
	_set_status("%d salas en la biblioteca" % n)
	refresh_list()
	refresh_all()
	return n


func filters() -> Dictionary:
	var f := {"sort": SORTS[f_sort.selected][0], "h_lo": int(f_hlo.value), "h_hi": int(f_hhi.value), "min_moves": int(f_moves.value), "min_grabs": int(f_grabs.value), "min_diff": f_diff.value / 100.0, "text": f_text.text}
	if f_shape.selected > 0:
		f["shape"] = RoomLib.SHAPES[f_shape.selected - 1]
	if f_status.selected > 0:
		f["status"] = RoomLib.STATUSES[f_status.selected - 1]
	if f_origin.selected > 0:
		f["origin"] = ["minero", "manual", "autor"][f_origin.selected - 1]
	if f_proof.selected > 0:
		f["proof"] = ["exacta", "cota", "sin_probar"][f_proof.selected - 1]
	return f


## Deja todos los filtros como al abrir (el orden se mantiene).
func clear_filters() -> void:
	f_shape.select(0)
	f_hlo.value = 0
	f_hhi.value = 20
	f_moves.value = 0
	f_grabs.value = 0
	f_diff.value = 0
	f_status.select(0)
	f_origin.select(0)
	f_proof.select(0)
	f_text.text = ""
	refresh_list()


func _row_text(r: Dictionary) -> String:
	var o: Dictionary = r.opt
	var mark: String = {"buena": "+", "mala": "x", "mejorable": "?", "nuevo": " "}.get(r.status, " ")
	var pr: String = {"exacta": "E", "cota": "c", "sin_probar": "·"}.get(str(o.get("proof", "")), "·")
	return "%s %s %2dp  d%3d%%  %2d/%-3d  %s %s" % [mark, r.shape, r.h, roundi(float(o.get("diff", 0.0)) * 100.0), int(o.get("grabs", 0)), int(o.get("moves", 0)), pr, str(r.id).substr(0, 8)]


func refresh_list() -> void:
	if list == null:
		return
	var rooms := model.filtered(filters())
	list.clear()
	_list_ids = []
	for r in rooms:
		list.add_item(_row_text(r))
		_list_ids.append(r.id)
	count_label.text = "%d de %d salas · d dificultad, con desplazamiento / pasos, E exacta" % [rooms.size(), model.rooms.size()]
	_select_in_list()


func _select_in_list() -> void:
	if model.has_current():
		var i := _list_ids.find(model.original_id if model.original_id != "" else model.current.id)
		if i >= 0:
			list.select(i)
			list.ensure_current_is_visible()
			return
	list.deselect_all()


func _on_list_selected(i: int) -> void:
	select_room(str(_list_ids[i]))


func select_room(id: String) -> bool:
	if model.dirty and model.has_current() and model.original_id != id and model.current.id != id:
		_set_status("Hay cambios sin guardar: guardá o descartá antes de abrir otra sala.")
		_select_in_list()
		return false
	if not model.open(id):
		_set_status(model.message)
		return false
	sel = {}
	move_src = {}
	_stop_play()
	_user_cam = false
	_frame_camera()
	refresh_all()
	return true


# --- refrescar ----------------------------------------------------------------------------------------------------------------------

func refresh_all() -> void:
	_refresh_view()
	_refresh_info()
	_refresh_variants_ui()
	_refresh_play_ui()
	_refresh_similar()
	var has := model.has_current()
	save_btn.disabled = not has
	save_new_btn.disabled = not has
	if has:
		status_opt.select(maxi(RoomLib.STATUSES.find(model.current.status), 0))
		note_edit.text = str(model.current.note)


func _highlight_cells() -> Array:
	var out: Array = []
	for s in [sel, move_src]:
		if not s.is_empty():
			out.append(Vector3i(s.cell.x, s.y, s.cell.y))
	return out


func _refresh_view() -> void:
	if blocks_root == null:
		return
	var st = model.view_state()
	if st == null:
		RoomView.populate(blocks_root, null, {})
		return
	RoomView.populate(blocks_root, st, model.current, true, _highlight_cells())


func _refresh_info() -> void:
	if info == null:
		return
	if not model.has_current():
		info.text = "[i]Elegí una sala de la lista o creá una nueva.[/i]"
		return
	var r := model.current
	var o: Dictionary = r.opt
	var counts := {"n": 0, "h": 0, "i": 0, "c": 0}
	for c in r.cols:
		var ks: String = r.cols[c]
		for i in ks.length():
			if ks[i] != RoomLib.GAP:
				counts[ks[i]] = int(counts[ks[i]]) + 1
	var t := "[b]%s · %d pisos[/b]   %d bloques (común %d, pesado %d, hielo %d, agrietado %d) en %d columnas\n" % [r.shape, r.h, model.block_count(), counts.n, counts.h, counts.i, counts.c, r.cols.size()]
	t += "id [code]%s[/code]  familia [code]%s[/code]  patrón [code]%s[/code]\n" % [str(r.id).substr(0, 10), str(r.family).substr(0, 10), str(r.pattern).substr(0, 10)]
	t += "origen: %s · estado: %s%s\n" % [r.origin, r.status, ("  ·  vino de [code]%s[/code]" % str(r.parent).substr(0, 8)) if str(r.parent) != "" else ""]
	if o.has("moves"):
		var proof := str(o.get("proof", "sin_probar"))
		var proof_txt: String = {"exacta": "[color=#7fe08a]exacta: es el mínimo[/color]", "cota": "[color=#e0c860]cota: entre %d y %d[/color]" % [int(o.get("lower", 0)), int(o.moves)], "sin_probar": "[color=#e0a060]sin probar el mínimo[/color]"}.get(proof, proof)
		var label := "camino más corto" if proof == "exacta" else "camino conocido (el mínimo puede ser menor)"
		t += "dificultad [b]%d %%[/b]: %d empujes o tirones de %d pasos · %d bloques distintos\n" % [roundi(float(o.get("diff", 0.0)) * 100.0), int(o.get("grabs", 0)), int(o.moves), int(o.get("moved", 0))]
		t += "%s (%d pasos) · %s%s\n" % [label, int(o.moves), proof_txt, " · camino plantado" if str(o.get("source", "")) == "plantada" else ""]
	elif o.has("error"):
		t += "[color=#ff7070]no se resuelve: %s[/color]\n" % str(o.error)
	else:
		t += "[color=#e0a060]sin verificar[/color]\n"
	if model.dirty:
		t += "[color=#ff9060]hay cambios sin guardar[/color]%s\n" % ("" if model.verified else " · [color=#ff7070]sin verificar[/color]")
	if str(r.note) != "":
		t += "nota: %s\n" % str(r.note)
	if not r.variants.is_empty():
		t += "variantes probadas: "
		for v in r.variants:
			var kp: PackedStringArray = str(v.key).split(",")
			t += "bloque (%s, piso %s, %s) → %s %s;  " % [kp[0], kp[1], kp[2], StudioModel.KIND_NAMES.get(str(v.kind), "?"), ("✓ %d pasos" % int(v.moves)) if v.ok else ("✗ " + str(v.why))]
		t += "\n"
	info.text = t


func _refresh_variants_ui() -> void:
	var ok := false
	if not sel.is_empty() and model.has_current() and sel.y >= 1 and RoomLib.block_char(model.current, sel.cell, sel.y) != "":
		ok = true
	for k in variant_checks:
		var cb: CheckBox = variant_checks[k]
		cb.disabled = not ok
		_suppress = true
		cb.button_pressed = false
		if ok:
			var cur: String = String(model.current.cols[sel.cell])[sel.y - 1]
			cb.button_pressed = (k == cur) or model.slot_of(sel.cell, sel.y).find(k) != -1
			cb.disabled = (k == cur)
		_suppress = false


func _refresh_play_ui() -> void:
	if play_slider == null:
		return
	var n: int = model.current.path.size() if model.has_current() else 0
	play_slider.max_value = maxi(n, 1)
	play_slider.editable = n > 0
	_suppress = true
	play_slider.value = model.play_index if model.play_state != null else 0
	_suppress = false
	play_btn.text = "⏸ Pausa" if playing else "▶ Reproducir"
	play_btn.disabled = n == 0


func _refresh_similar() -> void:
	if similar_box == null:
		return
	for ch in similar_box.get_children():
		ch.queue_free()
	if not model.has_current():
		return
	for s in model.similar(5):
		var r: Dictionary = s.room
		var row := HBoxContainer.new()
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(72, 72)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tr)
		var b := Button.new()
		b.text = "distancia %.2f\n%s · %d pisos · dificultad %d %%\n%s" % [float(s.dist), r.shape, r.h, roundi(float(r.opt.get("diff", 0.0)) * 100.0), str(r.id).substr(0, 8)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		var rid: String = r.id
		b.pressed.connect(func(): select_room(rid))
		row.add_child(b)
		similar_box.add_child(row)
		_load_thumb(r, tr)


## Pone la miniatura de la sala en el TextureRect: de la caché, del disco o dibujándola aparte (no en modo sin pantalla).
func _load_thumb(room: Dictionary, tr: TextureRect) -> void:
	var id: String = room.id
	if thumbs.has(id):
		tr.texture = thumbs[id]
		return
	var dir := lib_path.get_base_dir().path_join("thumbs") if lib_path != "" else ""
	var file := dir.path_join(id + ".png") if dir != "" else ""
	if file != "" and FileAccess.file_exists(file):
		var img := Image.load_from_file(file)
		if img != null and not img.is_empty():
			thumbs[id] = ImageTexture.create_from_image(img)
			tr.texture = thumbs[id]
			return
	var tex = await render_thumb(room)
	if tex != null:
		thumbs[id] = tex
		if is_instance_valid(tr):
			tr.texture = tex
		if file != "":
			DirAccess.make_dir_recursive_absolute(dir)
			(tex as ImageTexture).get_image().save_png(file)


## Dibuja la sala en un SubViewport aparte y devuelve la imagen como textura. null si no hay pantalla.
func render_thumb(room: Dictionary, size := 128) -> Variant:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return null
	var vp := SubViewport.new()
	vp.size = Vector2i(size, size)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var root3d := Node3D.new()
	vp.add_child(root3d)
	RoomView.add_lighting(root3d)
	var holder := Node3D.new()
	root3d.add_child(holder)
	var c := Camera3D.new()
	c.fov = 38.0
	root3d.add_child(c)
	RoomView.populate(holder, RoomLib.build_state(room), room, false)
	var b := RoomView.bounds(room)
	c.fov = 38.0
	RoomView.place_camera(c, b.center, 35.0, 35.0, float(b.radius) / sin(deg_to_rad(19.0)) * 1.1)
	add_child(vp)
	c.make_current()
	await get_tree().process_frame
	await get_tree().process_frame
	var tex := vp.get_texture()
	var img: Image = tex.get_image() if tex != null else null
	vp.queue_free()
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


func _set_status(t: String) -> void:
	if status != null:
		status.text = t


# --- la vista 3D ---------------------------------------------------------------------------------------------------------------------

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


## Un clic en la pantalla de la vista (posición relativa al contenedor): se usa la herramienta sobre el bloque que toca el rayo.
func click_at(pos: Vector2) -> void:
	var st = model.view_state()
	if st == null:
		return
	if tool == "add_side":
		var f := RoomView.pick_face(cam, pos, st)
		if f.hit.x == -1000:
			return
		var q: Vector3i = f.prev
		if model.add_block_at(Vector2i(q.x, q.z), q.y, kind_pick):
			after_edit()
		else:
			_set_status(model.message)
		return
	var c := RoomView.pick(cam, pos, st)
	if c.x == -1000:
		return
	click_cell(c)


## Usa la herramienta sobre la celda de bloque `c` (y = 0 es el piso).
func click_cell(c: Vector3i) -> void:
	if not model.has_current():
		return
	var cell := Vector2i(c.x, c.z)
	var y := c.y
	match tool:
		"select":
			sel = {"cell": cell, "y": y}
			_refresh_view()
			_refresh_variants_ui()
			var ks := String(model.current.cols.get(cell, ""))
			if y >= 1 and RoomLib.block_char(model.current, cell, y) != "":
				_set_status("Bloque (%d, %d) piso %d: %s" % [cell.x, cell.y, y, StudioModel.KIND_NAMES[ks[y - 1]]])
			elif cell == model.current.exit:
				_set_status("La salida: el pilar no se edita.")
			else:
				_set_status("Celda (%d, %d)" % [cell.x, cell.y])
		"add":
			if model.add_block(cell, kind_pick):
				after_edit()
			else:
				_set_status(model.message)
		"delete":
			if y >= 1 and model.delete_block(cell, y):
				after_edit()
			else:
				_set_status(model.message if model.message != "" else "Ahí no hay un bloque para borrar.")
		"delete_gap":
			if y >= 1 and model.delete_block(cell, y, true):
				after_edit()
			else:
				_set_status(model.message if model.message != "" else "Ahí no hay un bloque para borrar.")
		"type":
			if y >= 1 and model.set_kind(cell, y, kind_pick):
				after_edit()
			else:
				_set_status(model.message if model.message != "" else "Ahí no hay un bloque.")
		"move":
			if move_src.is_empty():
				if y >= 1 and RoomLib.block_char(model.current, cell, y) != "":
					move_src = {"cell": cell, "y": y}
					_refresh_view()
					_set_status("Ahora elegí la columna adonde va el bloque (Esc cancela).")
				else:
					_set_status("Elegí primero el bloque que querés mover.")
			else:
				var src := move_src
				move_src = {}
				if model.move_block(src.cell, src.y, cell):
					after_edit()
				else:
					_refresh_view()
					_set_status(model.message)


func set_tool(name: String) -> void:
	tool = name
	move_src = {}
	for i in TOOLS.size():
		if TOOLS[i][0] == name and tool_opt != null:
			tool_opt.select(i)
	_refresh_view()
	var hints := {"select": "Clic en un bloque para seleccionarlo (y marcar sus variantes).", "add": "Clic en una columna (o en el piso): se agrega un bloque arriba.", "delete": "Clic en un bloque para borrarlo.", "type": "Clic en un bloque: cambia al tipo elegido.", "move": "Clic en el bloque que querés mover y después en la columna destino.", "add_side": "Clic en la cara de un bloque: se agrega un bloque pegado a esa cara (puede quedar en el aire si se sostiene de sus vecinos).", "delete_gap": "Clic en un bloque para borrarlo; los de arriba quedan donde están si se sostienen solos."}
	_set_status(str(hints.get(name, "")))


func set_kind_pick(k: String) -> void:
	kind_pick = k
	kind_opt.select(maxi(StudioModel.KINDS.find(k), 0))


# --- acciones -----------------------------------------------------------------------------------------------------------------------

## Después de cada cambio: se vuelve a verificar la sala y se redibuja todo.
func after_edit() -> void:
	sel = {} if sel.is_empty() or RoomLib.block_char(model.current, sel.cell, int(sel.y)) == "" else sel
	var v := model.verify(3000)
	if v.ok:
		_set_status("Verificada: %d empujes o tirones de %d pasos (dificultad %d %%)%s." % [int(v.grabs), int(v.moves), roundi(100.0 * float(v.grabs) / maxf(float(v.moves), 1.0)), " (se conservó el camino)" if v.reused else ""])
	else:
		_set_status("Sin solución: %s." % str(v.why))
	refresh_all()
	_select_in_list()


func do_verify() -> void:
	if not model.has_current():
		return
	after_edit()


func do_verify_exact() -> void:
	if not model.has_current():
		return
	_set_status("Verificando a fondo (puede tardar)…")
	var r := model.verify_exact()
	match str(r.proof):
		"exacta":
			_set_status("Probado: el mínimo es %d pasos." % int(r.moves))
		"cota":
			_set_status("No alcanzó el presupuesto: el mínimo está entre %d y %d pasos." % [int(r.lower), model.current.path.size()])
		_:
			_set_status("No se pudo verificar: %s" % str(r.get("why", r.proof)))
	refresh_all()


func do_prune() -> void:
	if not model.has_current():
		return
	var n := model.prune_current()
	if n > 0:
		_set_status("Se sacaron %d bloques de relleno; la sala sigue siendo válida." % n)
	else:
		_set_status(model.message if model.message != "" else "No hay relleno para sacar.")
	sel = {}
	refresh_all()


func do_optimize() -> void:
	if not model.has_current():
		return
	if not model.verified:
		model.verify()
	var r := model.optimize_path()
	if r.exact:
		_set_status("Camino probado como el mínimo: %d pasos (eran %d)." % [int(r.after), int(r.before)])
	else:
		_set_status("Camino de %d pasos (eran %d); los últimos %d están probados como mínimos." % [int(r.after), int(r.before), int(r.proven)])
	refresh_all()


func do_save() -> void:
	var r := model.save(true)
	_set_status(str(r.msg))
	refresh_list()
	refresh_all()


func do_save_new() -> void:
	var r := model.save(false)
	_set_status(str(r.msg))
	refresh_list()
	refresh_all()


func do_delete() -> void:
	if model.has_current() and model.original_id != "":
		var id := model.original_id
		if model.delete_room(id):
			_set_status("Sala eliminada.")
		sel = {}
		refresh_list()
		refresh_all()


func do_new() -> void:
	if model.dirty:
		_set_status("Hay cambios sin guardar: guardá o descartá antes de crear otra sala.")
		return
	var shape: String = RoomLib.SHAPES[new_shape.selected]
	if model.new_room(shape, int(new_h.value)):
		sel = {}
		_frame_camera()
		_set_status("Sala nueva vacía de %s y %d pisos: agregá bloques." % [shape, int(new_h.value)])
		set_tool("add")
		refresh_all()
	else:
		_set_status(model.message)


func do_undo() -> void:
	if model.undo():
		after_edit()


func do_redo() -> void:
	if model.redo():
		after_edit()


func do_revert() -> void:
	if model.has_current():
		model.revert()
		sel = {}
		move_src = {}
		_set_status("Cambios descartados.")
		refresh_all()


func do_annotate() -> void:
	if not model.has_current():
		return
	var status_txt: String = RoomLib.STATUSES[status_opt.selected]
	if model.dirty or model.original_id == "":
		model.current.status = status_txt
		model.current.note = note_edit.text
		_set_status("Estado y nota puestos en la sala; se guardan con la sala.")
	elif model.annotate(model.original_id, status_txt, note_edit.text):
		_set_status("Sala marcada como %s." % status_txt)
	refresh_list()
	_refresh_info()


func _on_variant_toggled() -> void:
	if _suppress or sel.is_empty() or not model.has_current() or sel.y < 1:
		return
	var chars := ""
	for k in variant_checks:
		var cb: CheckBox = variant_checks[k]
		if cb.button_pressed and not cb.disabled:
			chars += k
	model.set_slot(sel.cell, sel.y, chars)
	_refresh_info()


func do_check_variants() -> void:
	if not model.has_current():
		return
	if model.current.slots.is_empty():
		_set_status("Marcá primero qué otros tipos puede tener un bloque (seleccionalo y tildá).")
		return
	var res := model.check_variants()
	var ok := 0
	for r in res:
		if r.ok:
			ok += 1
	_set_status("Variantes probadas: %d válidas de %d." % [ok, res.size()])
	_refresh_info()


func do_create_variants() -> void:
	if not model.has_current():
		return
	if model.dirty:
		_set_status("Guardá la sala antes de crear sus variantes.")
		return
	var n := model.create_variants()
	_set_status("Se crearon %d salas nuevas." % n)
	refresh_list()
	refresh_all()


# --- reproducción del camino --------------------------------------------------------------------------------------------------------

func play_goto(i: int) -> void:
	if not model.has_current() or model.current.path.is_empty():
		return
	model.play_to(clampi(i, 0, model.current.path.size()))
	_refresh_view()
	_refresh_play_ui()


func toggle_play() -> void:
	if not model.has_current() or model.current.path.is_empty():
		return
	if not playing:
		if model.play_state == null or model.play_index >= model.current.path.size():
			play_goto(0)
		playing = true
		play_timer.start()
	else:
		playing = false
		play_timer.stop()
	_refresh_play_ui()


func _stop_play() -> void:
	playing = false
	if play_timer != null:
		play_timer.stop()


func _on_play_tick() -> void:
	var r := model.play_step()
	_refresh_view()
	_refresh_play_ui()
	if not r.ok or r.done:
		playing = false
		play_timer.stop()
		_refresh_play_ui()


func _unhandled_key_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.ctrl_pressed and k.keycode == KEY_Z:
		do_undo()
	elif k.ctrl_pressed and k.keycode == KEY_Y:
		do_redo()
	elif k.ctrl_pressed and k.keycode == KEY_S:
		do_save()
	elif k.keycode == KEY_DELETE and not sel.is_empty() and sel.y >= 1 and model.has_current():
		if model.delete_block(sel.cell, sel.y):
			after_edit()
	elif k.keycode == KEY_ESCAPE:
		move_src = {}
		_refresh_view()
