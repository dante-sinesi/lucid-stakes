extends Control
## Pantalla de Opciones (menú principal y pausa): idioma, ventana o pantalla completa, resolución, sincronía vertical y volumen.
## Cada cambio se aplica y se guarda al instante. Al cambiar el idioma avisa con `language_changed` para que main reconstruya los menús.

const UI := preload("res://scripts/menu_ui.gd")
const Draw := preload("res://scripts/voxel_draw.gd")
const Loc := preload("res://scripts/loc.gd")
const Settings := preload("res://scripts/settings.gd")

signal back
signal language_changed

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
var _col: VBoxContainer


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

	# Idioma
	var row := _row(Loc.t("Idioma"))
	var group := ButtonGroup.new()
	for code in Loc.LANG_ORDER:
		lang_buttons[code] = _toggle(row, Loc.LANGS[code], group, "idioma_" + code, _on_lang.bind(code))
	# Pantalla
	row = _row(Loc.t("Pantalla"))
	group = ButtonGroup.new()
	mode_buttons["window"] = _toggle(row, Loc.t("Ventana"), group, "modo_ventana", _on_mode.bind(false))
	mode_buttons["fullscreen"] = _toggle(row, Loc.t("Pantalla completa"), group, "modo_completa", _on_mode.bind(true))
	# Resolución
	row = _row(Loc.t("Resolución"))
	res_prev = _small(row, "<", "res_anterior", _on_res.bind(-1))
	res_label = UI.label(null, "", 2.5, Draw.MARBLE)
	res_label.custom_minimum_size = Vector2(200, 0)
	res_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	res_label.align = res_label.Align.CENTER
	row.add_child(res_label)
	res_next = _small(row, ">", "res_siguiente", _on_res.bind(1))
	# Sincronía vertical
	row = _row(Loc.t("Sincronía vertical"))
	group = ButtonGroup.new()
	vsync_buttons["on"] = _toggle(row, Loc.t("Sí"), group, "vsync_si", _on_vsync.bind(true))
	vsync_buttons["off"] = _toggle(row, Loc.t("No"), group, "vsync_no", _on_vsync.bind(false))
	# Volumen
	row = _row(Loc.t("Volumen"))
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

	back_button = UI.button(Loc.t("Volver"), true)
	back_button.name = "volver_opciones"
	back_button.pressed.connect(func(): back.emit())
	_col.add_child(back_button)
	refresh()


## Una fila: el nombre de la opción a la izquierda y sus controles a la derecha.
func _row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := UI.label(null, text, 2.5, Color(0.8, 0.76, 0.92), false)
	name_label.custom_minimum_size = Vector2(330, 0)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	_col.add_child(row)
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


## Esc vuelve.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		back.emit()
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
