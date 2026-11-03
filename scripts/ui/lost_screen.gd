extends Control
## Pantalla de derrota de una torre: el fondo se va tiñendo de oscuro de a poco, aparece el motivo ("Caíste al vacío") y dos botones:
## Reintentar (cuesta una vida; con un Tótem no) y Salir al menú principal.
## `retry` y `menu` avisan a main.gd; la tecla R sigue valiendo como atajo (ver Main.request_restart).

const UI := preload("res://scripts/ui/menu_ui.gd")
const PadHints := preload("res://scripts/ui/pad_hints.gd")
const PadGlyph := preload("res://scripts/ui/pad_glyph.gd")
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const Loc := preload("res://scripts/idioma/loc.gd")

signal retry
signal menu

const DIM_ALPHA := 0.8
const DIM_TIME := 1.6      # lo que tarda en oscurecerse el fondo
const SHOW_DELAY := 1.0    # se espera un momento para ver cómo se cae antes de oscurecer

var dim: ColorRect
var box: VBoxContainer
var title_label
var hint_label
var hints
var retry_button
var menu_button
var fast := false          # pruebas: sin animación
var _tween: Tween


func _init() -> void:
	name = "pantalla_derrota"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	dim = ColorRect.new()
	dim.color = Color(0.015, 0.005, 0.03, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.modulate.a = 0.0
	center.add_child(box)
	title_label = UI.label(box, "", 6, Color(1.0, 0.55, 0.5))
	title_label.dance = true
	hint_label = UI.label(box, "", 2.5, Color(0.85, 0.8, 0.95), true, 900)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	box.add_child(gap)
	retry_button = UI.button(Loc.t("Reintentar"), true, 3.2, 70)
	retry_button.name = "reintentar"
	retry_button.pressed.connect(func(): retry.emit())
	box.add_child(retry_button)
	menu_button = UI.button(Loc.t("Salir al menú principal"), false, 3.0, 70)
	menu_button.name = "salir_al_menu"
	menu_button.pressed.connect(func(): menu.emit())
	box.add_child(menu_button)
	hints = PadHints.attach(self, [], [retry_button, menu_button])


## Muestra la derrota. `reason`: lo que pasó (ya traducido). `free`: el reintento no cuesta la vida (un Tótem te salva); `lives_left`: las vidas que quedan (-1 no se dice).
func show_loss(reason: String, free := false, lives_left := -1) -> void:
	title_label.text = reason
	retry_button.set_label(Loc.t("Reintentar (−1 vida)") if not free else Loc.t("Reintentar"))
	if free:
		hint_label.text = Loc.t("Vuelves a empezar la sala; el Tótem te salva la vida.")
	elif lives_left >= 0:
		hint_label.text = Loc.f("Vuelves a empezar la sala. Vidas que te quedan: %d.", [lives_left])
	else:
		hint_label.text = ""
	var listo := func(): return box.modulate.a > 0.5   # (las teclas valen cuando el cuadro ya se ve: la barra con la que se suelta una cornisa no debe actuar durante la caída)
	hints.set_items([{"slot": PadGlyph.Slot.SOUTH, "key": "Espacio", "text": retry_button.text, "keycode": KEY_SPACE, "when": listo, "call": func(): retry.emit()},
			{"slot": PadGlyph.Slot.WEST, "key": "Shift", "text": Loc.t("Salir al menú principal"), "keycode": KEY_SHIFT, "when": listo, "call": func(): menu.emit()}])
	visible = true
	if _tween != null:
		_tween.kill()
	if fast:
		dim.color.a = DIM_ALPHA
		box.modulate.a = 1.0
		hints.modulate.a = 1.0
		return
	dim.color.a = 0.0
	box.modulate.a = 0.0
	hints.modulate.a = 0.0   # (ni el motivo, ni los botones, ni la guía de teclas se ven antes de que el fundido termine: así no se pisan con la torre)
	_tween = create_tween()
	_tween.tween_interval(SHOW_DELAY)
	_tween.tween_property(dim, "color:a", DIM_ALPHA, DIM_TIME).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(box, "modulate:a", 1.0, 0.5)
	_tween.parallel().tween_property(hints, "modulate:a", 1.0, 0.5)


func hide_screen() -> void:
	if _tween != null:
		_tween.kill()
	visible = false
	dim.color.a = 0.0
	box.modulate.a = 0.0
