extends Control
## Pantalla de Opciones (menú principal y pausa), con cuatro pestañas: General (idioma, pantalla), Gráficos (preajustes Alta/Media/Baja y ajustes
## sueltos), Sonido (volúmenes) y Controles (reasignar teclas y botones del mando). Cada cambio se aplica y se guarda al instante, y cada pestaña
## tiene su botón Restablecer. Al cambiar el idioma avisa con `language_changed` para que main reconstruya los menús.

const UI := preload("res://scripts/ui/menu_ui.gd")
const PadHints := preload("res://scripts/ui/pad_hints.gd")
const PadGlyph := preload("res://scripts/ui/pad_glyph.gd")
const NOTE_WRAP := 940   # ancho máximo (px) de las notas bajo cada ajuste: más largas se parten en renglones
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const Loc := preload("res://scripts/idioma/loc.gd")
const Settings := preload("res://scripts/datos/settings.gd")
const Graphics := preload("res://scripts/ui/graphics.gd")
const Controls := preload("res://scripts/entrada/controls.gd")
const Telemetry := preload("res://scripts/datos/telemetry.gd")
const Casilla := preload("res://scripts/ui/casilla.gd")

signal back
signal language_changed

const TABS := ["general", "graficos", "sonido", "controles"]
const TAB_NAMES := {"general": "General", "graficos": "Gráficos", "sonido": "Sonido", "controles": "Controles"}

var focus_buttons := {}  # "box": la casilla
var device_buttons := {}   # Ayudas de: automático, teclado o mando
var style_buttons := {}    # botones del mando que se dibujan: automático, Xbox o PlayStation
var lang_buttons := {}      # código -> botón
var mode_buttons := {}      # "window" / "fullscreen"
var contrast_buttons := {}  # "box": la casilla
var casino_cam_buttons := {}  # "sala" / "personaje"
var panel_buttons := {}  # "mantener" / "alternar"
var profundidad_buttons := {}  # 0 / 1 / 2
var reading_buttons := {}  # "box": la casilla
var compass_buttons := {}  # "box": la casilla
var fondo_buttons := {}  # "box": la casilla
var vsync_buttons := {}  # "box": la casilla
var res_prev: Button
var ui_prev: Button
var ui_next: Button
var ui_label: Control
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
var gfx_checks := {}        # ajuste (sí o no) -> casilla
var scale_prev: Button
var scale_next: Button
var scale_label: Control
var bind_buttons := {}      # acción -> {"key": botón, "pad": botón}
var bind_message: Control
var capturing := ""         # acción que espera una tecla o botón nuevo ("" = ninguna)
var capture_kind := ""      # "key" o "pad"
var _col: VBoxContainer
var _desc: Control          # la descripción del ajuste que tiene el foco (o el mouse encima)
var _page: Control          # donde se agregan las filas de la pestaña que se está armando


func _init() -> void:
	name = "opciones"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.09, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()   # la pantalla ocupa todo el espacio que hay (con interfaz grande entra menos) y la pestaña se desplaza
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 64)   # (abajo queda la barra de teclas)
	add_child(margin)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 4)
	_col.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(_col)
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
	holder.custom_minimum_size = Vector2(960, 160)
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_col.add_child(holder)
	_desc = UI.label(_col, "", 2.0, Draw.MARBLE, true, NOTE_WRAP)
	_desc.name = "descripcion"
	_desc.localize = false   # (llega ya traducida)
	_desc.custom_minimum_size = Vector2(0, 44)
	var inner := {}
	for t in TABS:
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 3)
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
			scroll.follow_focus = true   # al bajar con las flechas o el mando, la lista acompaña al botón elegido
			holder.add_child(scroll)
			scroll.add_child(page)
			pages[t] = scroll
		inner[t] = page
	_build_general(inner.general)
	_build_graphics(inner.graficos)
	_build_sound(inner.sonido)
	_build_controls(inner.controles)
	_conectar_descripciones()
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
	PadHints.attach(self, [{"slot": PadGlyph.Slot.SOUTH, "key": "Espacio", "text": Loc.t("Elegir")},
			{"name": "LB|RB", "key": "Q | E", "text": Loc.t("Pestaña")},
			{"slot": PadGlyph.Slot.NORTH, "key": "C", "text": Loc.t("Restablecer"), "keycode": KEY_C, "call": reset_tab, "when": func(): return not Controls.capturing},
			{"slot": PadGlyph.Slot.EAST, "key": "Esc", "text": Loc.t("Volver"), "call": func(): back.emit()}], [reset_button, back_button])
	show_tab("general")
	refresh()


func _build_general(page: Control) -> void:
	_page = page
	var row := _row(Loc.t("Idioma"))
	var group := ButtonGroup.new()
	for code in Loc.LANG_ORDER:
		lang_buttons[code] = _toggle(row, Loc.LANGS[code], group, "idioma_" + code, _on_lang.bind(code))
	_build_interface()
	row = _row(Loc.t("Modo de lectura"))
	reading_buttons["box"] = _casilla(row, "lectura", func(): _on_reading(not bool(Settings.get_value("reading_mode"))))
	_nota(row, Loc.t("Letras más claras y con contorno."))
	row = _row(Loc.t("Rosa de los vientos"))
	compass_buttons["box"] = _casilla(row, "rosa", func(): _on_compass(not bool(Settings.get_value("compass"))))
	_nota(row, Loc.t("Muestra a qué eje va cada tecla W, A, S y D, arriba a la derecha."))
	row = _row(Loc.t("Fondo animado"))
	fondo_buttons["box"] = _casilla(row, "fondo", func(): _on_fondo(not bool(Settings.get_value("fondo_animado"))))
	_nota(row, Loc.t("El remolino que se mueve despacio detrás de la torre. Apagado, el fondo es un color liso."))
	row = _row(Loc.t("Marco del foco"))
	focus_buttons["box"] = _casilla(row, "marco", func(): _on_focus_frame(not bool(Settings.get_value("focus_frame"))))
	_nota(row, Loc.t("Un marco blanco que titila alrededor del botón elegido, para verlo mejor con el mando."))
	row = _row(Loc.t("Alto contraste"))
	contrast_buttons["box"] = _casilla(row, "contraste", func(): _on_contrast(not bool(Settings.get_value("high_contrast"))))
	_nota(row, Loc.t("Cartas oscuras de borde claro, sin ruido, y la escena con más contraste y color."))
	row = _row(Loc.t("Cámara del casino"))
	group = ButtonGroup.new()
	casino_cam_buttons["sala"] = _toggle(row, Loc.t("El casino"), group, "casino_cam_sala", _on_casino_cam.bind("sala"))
	casino_cam_buttons["personaje"] = _toggle(row, Loc.t("El personaje"), group, "casino_cam_personaje", _on_casino_cam.bind("personaje"))
	_nota(row, Loc.t("A qué mira la cámara en el casino: a todo el salón o a tu personaje, que te sigue."))
	row = _row(Loc.t("Panel de información"))
	group = ButtonGroup.new()
	panel_buttons["mantener"] = _toggle(row, Loc.t("Mantener"), group, "panel_mantener", _on_panel_modo.bind("mantener"))
	panel_buttons["alternar"] = _toggle(row, Loc.t("Alternar"), group, "panel_alternar", _on_panel_modo.bind("alternar"))
	_nota(row, Loc.t("Mantener: se ve mientras sostienes la tecla. Alternar: un toque lo abre y otro lo cierra."))
	row = _row(Loc.t("Ayuda de profundidad"))
	group = ButtonGroup.new()
	for o in [[0, "Ninguna"], [1, "Atenuar"], [2, "Atenuar y transparentar"]]:
		profundidad_buttons[o[0]] = _toggle(row, Loc.t(o[1]), group, "profundidad_%d" % o[0], _on_profundidad.bind(o[0]))
	_nota(row, Loc.t("Atenuar: lo cercano se ve más claro. Transparentar: además, lo que tapa al personaje se vuelve transparente."))
	row = _row(Loc.t("Datos de juego"))
	var data_button := UI.button(Loc.t("Abrir la carpeta"), false, 2.4, 0, false)
	data_button.name = "abrir_carpeta"
	data_button.pressed.connect(Telemetry.open_folder)
	row.add_child(data_button)
	_nota(row, Loc.t("Tus datos quedan sólo en tu compu. Para ayudar, mandanos telemetria.jsonl."))


func _build_interface() -> void:
	var row := _row(Loc.t("Tamaño de la interfaz"))
	ui_prev = _small(row, "<", "ui_menos", _on_ui_scale.bind(-1))
	ui_label = UI.label(null, "", 2.5, Draw.MARBLE)
	ui_label.custom_minimum_size = Vector2(120, 0)
	ui_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ui_label.align = ui_label.Align.CENTER
	row.add_child(ui_label)
	ui_next = _small(row, ">", "ui_mas", _on_ui_scale.bind(1))


func _build_display() -> void:
	var group: ButtonGroup
	var row := _row(Loc.t("Pantalla"))
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
	vsync_buttons["box"] = _casilla(row, "vsync", func(): _on_vsync(not bool(Settings.get_value("vsync"))))


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
	_build_display()
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
	_check("silhouette", Loc.t("Transparencia del personaje"))
	_check("effects", Loc.t("Destellos y temblores"))
	_choice("fps_cap", Loc.t("Límite de FPS"), [[30, "30"], [60, "60"], [144, "144"], [0, Loc.t("Sin límite")]])


## Una fila de sí o no de Gráficos: una casilla ("<ajuste>_casilla").
func _check(key: String, title: String) -> void:
	var row := _row(title)
	gfx_checks[key] = _casilla(row, key, func(): _on_gfx(key, not bool(Graphics.current()[key])))


## Una casilla de verificación en la fila (se llama "<nombre>_casilla"): `action` cambia el ajuste y `refresh` la deja marcada.
func _casilla(row: Control, node_name: String, action: Callable) -> Button:
	var c := Casilla.new()
	c.name = node_name + "_casilla"
	c.pressed.connect(action)
	row.add_child(c)
	return c


## Una fila de opciones excluyentes: `options` = [[valor, texto], ...]; los botones se llaman "<ajuste>_<valor>".
func _choice(key: String, title: String, options: Array) -> void:
	var row := _row(title)
	var group := ButtonGroup.new()
	gfx_buttons[key] = {}
	for o in options:
		gfx_buttons[key][o[0]] = _toggle(row, str(o[1]), group, "%s_%s" % [key, str(o[0])], _on_gfx.bind(key, o[0]))


func _build_controls(page: Control) -> void:
	_page = page
	var row0 := _row(Loc.t("Ayudas de"))
	var dev_group := ButtonGroup.new()
	for d in [["auto", "Automático"], ["keyboard", "Teclado"], ["pad", "Mando"]]:
		device_buttons[d[0]] = _toggle(row0, Loc.t(d[1]), dev_group, "entrada_" + d[0], _on_device.bind(d[0]))
	var row1 := _row(Loc.t("Botones del mando"))
	var style_group := ButtonGroup.new()
	for st in [["auto", "Automático"], ["xbox", "Xbox"], ["playstation", "PlayStation"]]:
		style_buttons[st[0]] = _toggle(row1, Loc.t(st[1]), style_group, "estilo_" + st[0], _on_pad_style.bind(st[0]))
	var scroll := ScrollContainer.new()
	scroll.name = "desplazamiento_controles"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
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


## La descripción de una fila: aparece abajo cuando el foco (o el mouse) pasa por alguno de sus botones, en vez de ir escrita en la pantalla.
func _nota(row: Control, texto: String) -> void:
	for b in row.get_children():
		if b is BaseButton:
			b.set_meta("desc", texto)


func _conectar_descripciones() -> void:
	for page in pages.values():
		for b in page.find_children("*", "BaseButton", true, false):
			b.focus_entered.connect(_describir.bind(b))
			b.mouse_entered.connect(_describir.bind(b))


func _describir(b: Control) -> void:
	_desc.text = str(b.get_meta("desc", ""))


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
	_desc.text = ""
	tab = t
	for k in pages:
		pages[k].visible = k == t
		tab_buttons[k].selected = k == t
	refresh()
	_link_focus()


## El foco se mueve como se ve: izquierda y derecha dentro de la fila, arriba y abajo de fila en fila (a la misma columna, o a la última si la fila tiene menos); desde la primera fila se
## sube a las pestañas y desde las pestañas se baja a la primera fila. En los bordes se queda donde está (antes saltaba de forma impredecible, sobre todo en Controles).
func _link_focus() -> void:
	var rows: Array = []
	_collect_rows(pages[tab], rows)
	var tab_list: Array = []
	for t in TABS:
		tab_list.append(tab_buttons[t])
	for k in tab_list.size():
		var b: Control = tab_list[k]
		b.focus_neighbor_left = b.get_path_to(tab_list[maxi(k - 1, 0)])
		b.focus_neighbor_right = b.get_path_to(tab_list[mini(k + 1, tab_list.size() - 1)])
		b.focus_neighbor_top = b.get_path_to(b)
		b.focus_neighbor_bottom = b.get_path_to(rows[0][0] if not rows.is_empty() else b)
	for r in rows.size():
		var row: Array = rows[r]
		for c in row.size():
			var n: Control = row[c]
			n.focus_neighbor_left = n.get_path_to(row[c - 1] if c > 0 else n)
			n.focus_neighbor_right = n.get_path_to(row[c + 1] if c < row.size() - 1 else n)
			var up: Control = tab_buttons[tab] if r == 0 else rows[r - 1][mini(c, rows[r - 1].size() - 1)]
			n.focus_neighbor_top = n.get_path_to(up)
			var down: Control = n if r == rows.size() - 1 else rows[r + 1][mini(c, rows[r + 1].size() - 1)]
			n.focus_neighbor_bottom = n.get_path_to(down)


## Las filas de botones de una pestaña, en el orden en que se ven (cada fila, sus botones de izquierda a derecha).
func _collect_rows(node: Node, out: Array) -> void:
	for ch in node.get_children():
		if ch is HBoxContainer:
			var buttons: Array = []
			for b in ch.get_children():
				if b is BaseButton and b.focus_mode != Control.FOCUS_NONE:
					buttons.append(b)
			if not buttons.is_empty():
				out.append(buttons)
				continue
		_collect_rows(ch, out)


## Restablece sólo los ajustes de la pestaña que se está viendo (el idioma no se toca).
func reset_tab() -> void:
	cancel_capture()
	match tab:
		"general":   # (el idioma no se toca)
			Settings.set_value("ui_scale", 100)
			Settings.set_value("reading_mode", false)
			Settings.set_value("high_contrast", false)
			Settings.set_value("compass", true)
			Settings.set_value("fondo_animado", true)
			Settings.set_value("focus_frame", false)
		"graficos":
			Settings.set_value("fullscreen", false)
			Settings.set_value("resolution", [1280, 720])
			Settings.set_value("vsync", true)
			Graphics.reset()
		"sonido":
			for key in ["volume", "music", "sfx"]:
				Settings.set_value(key, Settings.MUSIC_DEFAULT if key == "music" else Settings.VOLUME_STEPS)
		"controles":
			Settings.set_value("input_device", "auto")
			Settings.set_value("pad_style", "auto")
			Controls.apply_device()
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
	res_prev.disabled = false
	res_next.disabled = false
	var us: int = Settings.get_value("ui_scale")
	ui_label.text = "%d%%" % us
	ui_prev.disabled = us <= Settings.UI_SCALES[0]
	ui_next.disabled = us >= Settings.UI_SCALES[Settings.UI_SCALES.size() - 1]
	for k in device_buttons:
		device_buttons[k].selected = k == str(Settings.get_value("input_device"))
	for k in style_buttons:
		style_buttons[k].selected = k == str(Settings.get_value("pad_style"))
	var ff: bool = Settings.get_value("focus_frame")
	focus_buttons.box.checked = ff
	var rm: bool = Settings.get_value("reading_mode")
	reading_buttons.box.checked = rm
	var cp: bool = Settings.get_value("compass")
	compass_buttons.box.checked = cp
	for k in casino_cam_buttons:
		casino_cam_buttons[k].selected = k == str(Settings.get_value("casino_camara"))
	for k in panel_buttons:
		panel_buttons[k].selected = k == str(Settings.get_value("panel_modo"))
	for k in profundidad_buttons:
		profundidad_buttons[k].selected = k == int(Settings.get_value("ayuda_profundidad"))
	var fa: bool = Settings.get_value("fondo_animado")
	fondo_buttons.box.checked = fa
	var hc: bool = Settings.get_value("high_contrast")
	contrast_buttons.box.checked = hc
	var vs: bool = Settings.get_value("vsync")
	vsync_buttons.box.checked = vs
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
	for key in gfx_checks:
		gfx_checks[key].checked = bool(cur[key])
	scale_label.text = "%d%%" % int(cur.scale)
	var scales: Array = Graphics.CHOICES.scale
	scale_prev.disabled = int(cur.scale) <= int(scales[0])
	scale_next.disabled = int(cur.scale) >= int(scales[scales.size() - 1])


func _refresh_bindings() -> void:
	for id in bind_buttons:
		var b: Dictionary = bind_buttons[id]
		var waiting_key: bool = capturing == id and capture_kind == "key"
		var waiting_pad: bool = capturing == id and capture_kind == "pad"
		b.key.set_label(Loc.t("Aprieta una tecla...") if waiting_key else Loc.literal(Controls.key_name(Controls.key_of(id))))
		b.pad.set_label(Loc.t("Aprieta un botón...") if waiting_pad else Controls.pad_name(Controls.pad_of(id)))
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
	Graphics.apply_global()   # en pantalla completa la resolución es la del render
	refresh()


func _on_res(dir: int) -> void:
	var list := Settings.available_resolutions()
	var i := list.find(Settings.resolution())
	i = clampi((i if i >= 0 else 0) + dir, 0, list.size() - 1)
	Settings.set_value("resolution", [list[i].x, list[i].y])
	Graphics.apply_global()
	refresh()


func _on_ui_scale(dir: int) -> void:
	var i := Settings.UI_SCALES.find(int(Settings.get_value("ui_scale")))
	i = clampi((i if i >= 0 else 2) + dir, 0, Settings.UI_SCALES.size() - 1)
	Settings.set_value("ui_scale", Settings.UI_SCALES[i])
	refresh()


func _on_contrast(on: bool) -> void:
	Settings.set_value("high_contrast", on)
	refresh()


func _on_casino_cam(modo: String) -> void:
	Settings.set_value("casino_camara", modo)
	refresh()


func _on_panel_modo(modo: String) -> void:
	Settings.set_value("panel_modo", modo)
	refresh()


func _on_profundidad(k: int) -> void:
	Settings.set_value("ayuda_profundidad", k)
	refresh()


func _on_compass(on: bool) -> void:
	Settings.set_value("compass", on)
	refresh()


func _on_fondo(on: bool) -> void:
	Settings.set_value("fondo_animado", on)
	refresh()


func _on_device(which: String) -> void:
	Settings.set_value("input_device", which)
	Controls.apply_device()
	refresh()


func _on_pad_style(which: String) -> void:
	Settings.set_value("pad_style", which)
	refresh()


func _on_focus_frame(on: bool) -> void:
	Settings.set_value("focus_frame", on)
	refresh()


func _on_reading(on: bool) -> void:
	Settings.set_value("reading_mode", on)
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
	PadHints.focus_first(self)


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
	const D := preload("res://scripts/ui/voxel_draw.gd")
	const Settings := preload("res://scripts/datos/settings.gd")
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
