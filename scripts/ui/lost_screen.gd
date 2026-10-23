extends Control
## Pantalla de derrota de una torre: el fondo se va tiñendo de oscuro de a poco, aparece el motivo ("Caíste al vacío") y dos botones:
## Reintentar (con su costo en claridad) y Salir al menú principal. Si no alcanza la claridad para reintentar, el botón pasa a "Terminar la partida".
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


## Muestra la derrota. `reason`: lo que pasó (ya traducido). `cost`: lo que cuesta reintentar; `free`: el reintento no cuesta (tutorial);
## `can_afford`: alcanza la claridad.
func show_loss(reason: String, cost: int, can_afford := true, free := false, life := false) -> void:
	title_label.text = reason
	if life:   # (la torre: reintentar la sala cuesta una vida; con un Tótem no cuesta)
		retry_button.set_label(Loc.t("Reintentar (−1 vida)") if not free else Loc.t("Reintentar"))
		hint_label.text = ""
	elif free:
		retry_button.set_label(Loc.t("Reintentar"))
		hint_label.text = ""
	elif cost == 0:
		retry_button.set_label(Loc.t("Reintentar"))
		hint_label.text = ""
	elif can_afford:
		retry_button.set_label(Loc.f("Reintentar (−%d de claridad)", [cost]))
		hint_label.text = ""
	else:
		retry_button.set_label(Loc.t("Terminar la partida"))
		hint_label.text = Loc.f("No te alcanza la claridad para reintentar la torre (cuesta %d).", [cost])
	var listo := func(): return box.modulate.a > 0.5   # (las teclas valen cuando el cuadro ya se ve: la barra con la que se suelta una cornisa no debe actuar durante la caída)
	hints.set_items([{"slot": PadGlyph.Slot.SOUTH, "key": "Espacio", "text": retry_button.text, "keycode": KEY_SPACE, "when": listo, "call": func(): retry.emit()},
			{"slot": PadGlyph.Slot.WEST, "key": "Shift", "text": Loc.t("Salir al menú principal"), "keycode": KEY_SHIFT, "when": listo, "call": func(): menu.emit()}])
	visible = true
	if _tween != null:
		_tween.kill()
	if fast:
		dim.color.a = DIM_ALPHA
		box.modulate.a = 1.0
		pass
		return
	dim.color.a = 0.0
	box.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_interval(SHOW_DELAY)
	_tween.tween_property(dim, "color:a", DIM_ALPHA, DIM_TIME).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(box, "modulate:a", 1.0, 0.7).set_delay(0.5)
	_tween.tween_callback(func(): pass)


func hide_screen() -> void:
	if _tween != null:
		_tween.kill()
	visible = false
	dim.color.a = 0.0
	box.modulate.a = 0.0
