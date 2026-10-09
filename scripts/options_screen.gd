extends Control
## Pantalla de Opciones (menú principal y pausa), con cuatro pestañas: General (idioma, pantalla), Gráficos (preajustes Alta/Media/Baja y ajustes
## sueltos), Sonido (volúmenes) y Controles (reasignar teclas y botones del mando). Cada cambio se aplica y se guarda al instante, y cada pestaña
## tiene su botón Restablecer. Al cambiar el idioma avisa con `language_changed` para que main reconstruya los menús.

const UI := preload("res://scripts/menu_ui.gd")
const Draw := preload("res://scripts/voxel_draw.gd")
const Loc := preload("res://scripts/loc.gd")
const Settings := preload("res://scripts/settings.gd")
const Graphics := preload("res://scripts/graphics.gd")
const Controls := preload("res://scripts/controls.gd")

signal back
signal language_changed

const TABS := ["general", "graficos", "sonido", "controles"]
const TAB_NAMES := {"general": "General", "graficos": "Gráficos", "sonido": "Sonido", "controles": "Controles"}

var lang_buttons := {}      # código -> botón
var mode_buttons := {}      # "window" / "fullscreen"
var vsync_buttons := {}     # "on" / "off"
var res_prev: Button
var res_next: Button
var res_label: Control
var vol_minus: Button
var vol_plus: Button
var vol_bar: Control
var vol_label: Control
var vol_rows := {}      # "music" / "sfx" -> {minus, plus, bar, label}
var back_button: Button
var reset_button: Button
var tab_buttons := {}       # pestaña -> botón
var tab := "general"
var pages := {}             # pestaña -> contenedor
var preset_buttons := {}    # "alta" / "media" / "baja" / "custom"
var gfx_buttons := {}       # ajuste -> {valor: botón}
var scale_prev: Button
var scale_next: Button
var scale_label: Control
var bind_buttons := {}      # acción -> {"key": botón, "pad": botón}
var bind_message: Control
var capturing := ""         # acción que espera una tecla o botón nuevo ("" = ninguna)
var capture_kind := ""      # "key" o "pad"
var _col: VBoxContainer
var _page: Control          # donde se agregan las filas de la pestaña que se está armando


func _init() -> void:
	name = "opciones"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.09, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 9)
	center.add_child(_col)
	var title := UI.label(_col, Loc.t("Opciones"), 5, UI.GOLD)
	title.dance = true
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_col.add_child(tabs)
	for t in TABS:
		var b := UI.button(Loc.t(TAB_NAMES[t]), false, 2.4, 0, false)
		b.name = "pestana_" + t
		b.pressed.connect(show_tab.bind(t))
		tabs.add_child(b)
		tab_buttons[t] = b
	var holder := Control.new()   # las pestañas comparten el mismo lugar (se alterna cuál se ve)
	holder.custom_minimum_size = Vector2(1060, 440)
	_col.add_child(holder)
	var inner := {}
	for t in TABS:
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 9)
		if t == "controles":   # (esta pestaña tiene su propio desplazamiento, con el aviso fijo abajo)
			page.name = "pagina_" + t
			page.set_anchors_preset(Control.PRESET_FULL_RECT)
			holder.add_child(page)
			pages[t] = page
		else:   # las demás se desplazan con la rueda si no entran en el alto
			var scroll := ScrollContainer.new()
			scroll.name = "pagina_" + t
			scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			holder.add_child(scroll)
			scroll.add_child(page)
			pages[t] = scroll
		inner[t] = page
	_build_general(inner.general)
	_build_graphics(inner.graficos)
	_build_sound(inner.sonido)
	_build_controls(inner.controles)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	_col.add_child(bottom)
	reset_button = UI.button(Loc.t("Restablecer"), false, 2.4, 0, false)
	reset_button.name = "restablecer"
	reset_button.pressed.connect(reset_tab)
	bottom.add_child(reset_button)
	back_button = UI.button(Loc.t("Volver"), true)
	back_button.name = "volver_opciones"
	back_button.pressed.connect(func(): back.emit())
	bottom.add_child(back_button)
	show_tab("general")
	refresh()


func _build_general(page: Control) -> void:
	_page = page
	var row := _row(Loc.t("Idioma"))
	var group := ButtonGroup.new()
	for code in Loc.LANG_ORDER:
		lang_buttons[code] = _toggle(row, Loc.LANGS[code], group, "idioma_" + code, _on_lang.bind(code))
	row = _row(Loc.t("Pantalla"))
	group = ButtonGroup.new()
	mode_buttons["window"] = _toggle(row, Loc.t("Ventana"), group, "modo_ventana", _on_mode.bind(false))
	mode_buttons["fullscreen"] = _toggle(row, Loc.t("Pantalla completa"), group, "modo_completa", _on_mode.bind(true))
	row = _row(Loc.t("Resolución"))
	res_prev = _small(row, "<", "res_anterior", _on_res.bind(-1))
	res_label = UI.label(null, "", 2.5, Draw.MARBLE)
	res_label.custom_minimum_size = Vector2(200, 0)
	res_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	res_label.align = res_label.Align.CENTER
	row.add_child(res_label)
	res_next = _small(row, ">", "res_siguiente", _on_res.bind(1))
	row = _row(Loc.t("Sincronía vertical"))
	group = ButtonGroup.new()
	vsync_buttons["on"] = _toggle(row, Loc.t("Sí"), group, "vsync_si", _on_vsync.bind(true))
	vsync_buttons["off"] = _toggle(row, Loc.t("No"), group, "vsync_no", _on_vsync.bind(false))


func _build_sound(page: Control) -> void:
	_page = page
	var row := _row(Loc.t("Volumen"))
	vol_minus = _small(row, "-", "volumen_menos", _on_volume.bind(-1))
	vol_bar = _Bar.new()
	row.add_child(vol_bar)
	vol_plus = _small(row, "+", "volumen_mas", _on_volume.bind(1))
	vol_label = UI.label(null, "", 2.5, Draw.MARBLE)
	vol_label.custom_minimum_size = Vector2(90, 0)
	vol_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(vol_label)
	_volume_row(Loc.t("Música"), "music")
	_volume_row(Loc.t("Efectos"), "sfx")


func _build_graphics(page: Control) -> void:
	_page = page
	var row := _row(Loc.t("Calidad"))
	var group := ButtonGroup.new()
	for p in Graphics.PRESETS:
		preset_buttons[p] = _toggle(row, Loc.t(Graphics.PRESET_NAMES[p]), group, "preajuste_" + p, _on_preset.bind(p))
	preset_buttons["custom"] = _toggle(row, Loc.t("Personalizada"), group, "preajuste_custom", func(): pass)
	_choice("shadows", Loc.t("Sombras"), [["off", Loc.t("No")], ["hard", Loc.t("Duras")], ["soft", Loc.t("Suaves")]])
	_choice("particles", Loc.t("Partículas de los bloques"), [["none", Loc.t("No")], ["few", Loc.t("Pocas")], ["all", Loc.t("Todas")]])
	row = _row(Loc.t("Escala de render"))
	scale_prev = _small(row, "<", "escala_menos", func(): Graphics.cycle("scale", -1); refresh())
	scale_label = UI.label(null, "", 2.5, Draw.MARBLE)
	scale_label.custom_minimum_size = Vector2(120, 0)
	scale_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scale_label.align = scale_label.Align.CENTER
	row.add_child(scale_label)
	scale_next = _small(row, ">", "escala_mas", func(): Graphics.cycle("scale", 1); refresh())
	_choice("aa", Loc.t("Suavizado de bordes"), [[0, Loc.t("No")], [2, "2x"], [4, "4x"]])
	_choice("silhouette", Loc.t("Silueta tras las paredes"), [[true, Loc.t("Sí")], [false, Loc.t("No")]])
	_choice("effects", Loc.t("Destellos y temblores"), [[true, Loc.t("Sí")], [false, Loc.t("No")]])
	_choice("fps_cap", Loc.t("Límite de FPS"), [[30, "30"], [60, "60"], [144, "144"], [0, Loc.t("Sin límite")]])
	_choice("show_fps", Loc.t("Mostrar FPS"), [[true, Loc.t("Sí")], [false, Loc.t("No")]])


## Una fila de opciones excluyentes: `options` = [[valor, texto], ...]; los botones se llaman "<ajuste>_<valor>".
func _choice(key: String, title: String, options: Array) -> void:
	var row := _row(title)
	var group := ButtonGroup.new()
	gfx_buttons[key] = {}
	for o in options:
		gfx_buttons[key][o[0]] = _toggle(row, str(o[1]), group, "%s_%s" % [key, str(o[0])], _on_gfx.bind(key, o[0]))


func _build_controls(page: Control) -> void:
	_page = page
	var scroll := ScrollContainer.new()
	scroll.name = "desplazamiento_controles"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var head := _row_in(list, Loc.t("Acción"))
	var head_key := UI.label(head, Loc.t("Teclado"), 2.2, UI.GOLD, false)
	head_key.custom_minimum_size = Vector2(230, 0)
	UI.label(head, Loc.t("Mando"), 2.2, UI.GOLD, false)
	var group := ""
	for a in Controls.ACTIONS:
		if a.group != group:
			group = a.group
			UI.label(list, Loc.t(group), 2.2, UI.GOLD, false)
		var row := _row_in(list, Loc.t(a.name))
		var kb := UI.button("", false, 2.0, 20, false)
		kb.name = "tecla_" + str(a.id)
		kb.pressed.connect(begin_capture.bind(str(a.id), "key"))
		row.add_child(kb)
		var pb := UI.button("", false, 2.0, 20, false)
		pb.name = "mando_" + str(a.id)
		pb.pressed.connect(begin_capture.bind(str(a.id), "pad"))
		row.add_child(pb)
		bind_buttons[str(a.id)] = {"key": kb, "pad": pb}
	bind_message = UI.label(page, "", 2.0, Color(1.0, 0.85, 0.5), false)
	bind_message.localize = false
	bind_message.custom_minimum_size = Vector2(0, 26)


## Una fila: el nombre de la opción a la izquierda y sus controles a la derecha.
func _row(text: String) -> HBoxContainer:
	return _row_in(_page, text)


func _row_in(parent: Control, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := UI.label(null, text, 2.5, Color(0.8, 0.76, 0.92), false)
	name_label.custom_minimum_size = Vector2(440, 0)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	parent.add_child(row)
	return row


func _toggle(row: Control, text: String, group: ButtonGroup, node_name: String, action: Callable) -> Button:
	var b := UI.button(text, false, 2.2, 0, false)
	b.name = node_name
	b.pressed.connect(action)
	row.add_child(b)
	return b


func _small(row: Control, text: String, node_name: String, action: Callable) -> Button:
	var b := UI.button(text, false, 2.2, 0, false)
	b.name = node_name
	b.pressed.connect(action)
	row.add_child(b)
	return b


func show_tab(t: String) -> void:
	if not pages.has(t):
		return
	cancel_capture()
	tab = t
	for k in pages:
		pages[k].visible = k == t
		tab_buttons[k].selected = k == t
	refresh()


## Restablece sólo los ajustes de la pestaña que se está viendo (el idioma no se toca).
func reset_tab() -> void:
	cancel_capture()
	match tab:
		"general":
			Settings.set_value("fullscreen", false)
			Settings.set_value("resolution", [1280, 720])
			Settings.set_value("vsync", true)
		"graficos":
			Graphics.reset()
		"sonido":
			for key in ["volume", "music", "sfx"]:
				Settings.set_value(key, Settings.VOLUME_STEPS)
		"controles":
			Controls.reset_all()
			bind_message.text = ""
	refresh()


## Pone los controles como están los ajustes.
func refresh() -> void:
	for code in lang_buttons:
		lang_buttons[code].selected = code == Settings.lang()
	var fs: bool = Settings.get_value("fullscreen")
	mode_buttons.window.selected = not fs
	mode_buttons.fullscreen.selected = fs
	var res := Settings.resolution()
	res_label.text = "%d x %d" % [res.x, res.y]
	res_prev.disabled = fs
	res_next.disabled = fs
	var vs: bool = Settings.get_value("vsync")
	vsync_buttons.on.selected = vs
	vsync_buttons.off.selected = not vs
	var steps: int = Settings.get_value("volume")
	vol_bar.steps = steps
	vol_label.text = "%d%%" % (steps * 100 / Settings.VOLUME_STEPS)
	vol_minus.disabled = steps <= 0
	vol_plus.disabled = steps >= Settings.VOLUME_STEPS
	for key in vol_rows:
		var v: int = Settings.get_value(key)
		vol_rows[key].bar.steps = v
		vol_rows[key].label.text = "%d%%" % (v * 100 / Settings.VOLUME_STEPS)
		vol_rows[key].minus.disabled = v <= 0
		vol_rows[key].plus.disabled = v >= Settings.VOLUME_STEPS
	_refresh_graphics()
	_refresh_bindings()


func _refresh_graphics() -> void:
	var cur := Graphics.current()
	for p in preset_buttons:
		preset_buttons[p].selected = p == str(cur.preset)
	for key in gfx_buttons:
		for v in gfx_buttons[key]:
			gfx_buttons[key][v].selected = v == cur[key]
	scale_label.text = "%d%%" % int(cur.scale)
	var scales: Array = Graphics.CHOICES.scale
	scale_prev.disabled = int(cur.scale) <= int(scales[0])
	scale_next.disabled = int(cur.scale) >= int(scales[scales.size() - 1])


func _refresh_bindings() -> void:
	for id in bind_buttons:
		var b: Dictionary = bind_buttons[id]
		var waiting_key: bool = capturing == id and capture_kind == "key"
		var waiting_pad: bool = capturing == id and capture_kind == "pad"
		b.key.set_label(Loc.t("Apretá una tecla...") if waiting_key else Loc.literal(Controls.key_name(Controls.key_of(id))))
		b.pad.set_label(Loc.t("Apretá un botón...") if waiting_pad else Controls.pad_name(Controls.pad_of(id)))
		b.key.selected = waiting_key
		b.pad.selected = waiting_pad


# --- reasignar ---------------------------------------------------------------------------------------------------------------

## Empieza a esperar la tecla ("key") o el botón del mando ("pad") nuevo de una acción.
func begin_capture(id: String, kind: String) -> void:
	capturing = id
	capture_kind = kind
	Controls.capturing = true
	bind_message.text = ""
	_refresh_bindings()


func cancel_capture() -> void:
	if capturing == "":
		return
	capturing = ""
	capture_kind = ""
	Controls.capturing = false
	_refresh_bindings()


## Asigna la tecla o la entrada del mando que se estaba esperando. Si otra acción la tenía, se intercambian y se avisa.
func finish_capture(key_code: int, pad: Dictionary) -> void:
	var id := capturing
	var swapped := ""
	if capture_kind == "key":
		swapped = Controls.rebind_key(id, key_code)
	else:
		swapped = Controls.rebind_pad(id, pad)
	capturing = ""
	capture_kind = ""
	Controls.capturing = false
	if swapped != "":
		bind_message.text = Loc.f("Ya la usaba «%s»: se intercambiaron.", [Loc.t(str(Controls.get_action(swapped).name))])
	else:
		bind_message.text = ""
	_refresh_bindings()


func _input(event: InputEvent) -> void:
	if capturing == "" or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			cancel_capture()
		elif capture_kind == "key":
			finish_capture(event.keycode, {})
		else:
			return
		get_viewport().set_input_as_handled()
	elif capture_kind == "pad" and event is InputEventJoypadButton and event.pressed:
		finish_capture(0, {"button": int(event.button_index)})
		get_viewport().set_input_as_handled()
	elif capture_kind == "pad" and event is InputEventJoypadMotion and absf(event.axis_value) >= 0.7:
		finish_capture(0, {"axis": int(event.axis), "sign": 1 if event.axis_value > 0.0 else -1})
		get_viewport().set_input_as_handled()


# --- ajustes -----------------------------------------------------------------------------------------------------------------

func _on_lang(code: String) -> void:
	if code == Settings.lang():
		return
	Settings.set_value("lang", code)
	language_changed.emit()


func _on_mode(fullscreen: bool) -> void:
	Settings.set_value("fullscreen", fullscreen)
	refresh()


func _on_res(dir: int) -> void:
	var list := Settings.available_resolutions()
	var i := list.find(Settings.resolution())
	i = clampi((i if i >= 0 else 0) + dir, 0, list.size() - 1)
	Settings.set_value("resolution", [list[i].x, list[i].y])
	refresh()


func _on_vsync(on: bool) -> void:
	Settings.set_value("vsync", on)
	refresh()


func _on_preset(p: String) -> void:
	Graphics.set_preset(p)
	refresh()


func _on_gfx(key: String, v) -> void:
	Graphics.set_value(key, v)
	refresh()


## Una fila de volumen (música o efectos): menos, barra de cubitos, más y el porcentaje.
func _volume_row(title: String, key: String) -> void:
	var row := _row(title)
	var r := {}
	r["minus"] = _small(row, "-", key + "_menos", _on_volume_key.bind(key, -1))
	r["bar"] = _Bar.new()
	row.add_child(r["bar"])
	r["plus"] = _small(row, "+", key + "_mas", _on_volume_key.bind(key, 1))
	r["label"] = UI.label(null, "", 2.5, Draw.MARBLE)
	r["label"].custom_minimum_size = Vector2(90, 0)
	r["label"].size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(r["label"])
	vol_rows[key] = r


func _on_volume_key(key: String, dir: int) -> void:
	Settings.set_value(key, clampi(int(Settings.get_value(key)) + dir, 0, Settings.VOLUME_STEPS))
	refresh()


func _on_volume(dir: int) -> void:
	Settings.set_value("volume", clampi(int(Settings.get_value("volume")) + dir, 0, Settings.VOLUME_STEPS))
	refresh()


func focus_default() -> void:
	back_button.grab_focus()


## Esc vuelve; las acciones de vista (Q y E, LB y RB en el mando) cambian de pestaña.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		back.emit()
	elif Controls.hit(event, "vista_izquierda"):
		show_tab(TABS[(TABS.find(tab) + TABS.size() - 1) % TABS.size()])
	elif Controls.hit(event, "vista_derecha"):
		show_tab(TABS[(TABS.find(tab) + 1) % TABS.size()])
	else:
		return
	get_viewport().set_input_as_handled()


## Barra de volumen: una fila de cubitos, dorados los encendidos.
class _Bar extends Control:
	const D := preload("res://scripts/voxel_draw.gd")
	const Settings := preload("res://scripts/settings.gd")
	var steps := 0:
		set(v):
			steps = v
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(Settings.VOLUME_STEPS * 22, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in Settings.VOLUME_STEPS:
			var on := i < steps
			var h := 10.0 + float(i) * 1.6
			var r := Rect2(Vector2(i * 22, size.y * 0.5 + 10.0 - h), Vector2(18, h))
			draw_rect(r, D.GOLD if on else Color(0.25, 0.22, 0.32))
			draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), (D.GOLD if on else Color(0.25, 0.22, 0.32)).lightened(0.3))
