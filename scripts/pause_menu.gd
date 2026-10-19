extends Control
## Menú de pausa (Esc): Continuar, Reintentar la torre, Volver al menú principal, Abandonar partida y Salir. Hecho de cubitos.

const UI := preload("res://scripts/menu_ui.gd")
const PadHints := preload("res://scripts/pad_hints.gd")
const PadGlyph := preload("res://scripts/pad_glyph.gd")
const MenuAnim := preload("res://scripts/menu_anim.gd")
const OptionsScreen := preload("res://scripts/options_screen.gd")
const Loc := preload("res://scripts/loc.gd")

signal resume
signal restart_tower
signal to_main_menu
signal abandon_run
signal quit_game
signal language_changed
var buttons := {}
var column: VBoxContainer
var center: CenterContainer
var options: Control
var hints


func _init() -> void:
	name = "menu_pausa"
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue funcionando con el juego en pausa
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)
	var title := UI.label(column, Loc.t("Pausa"), 6, UI.GOLD)
	title.dance = true
	_button("continuar", "Continuar", true, func(): resume.emit())
	_button("reiniciar", Loc.t("Reintentar la torre"), false, func(): restart_tower.emit())
	_button("menu", Loc.t("Volver al menú principal"), false, func(): to_main_menu.emit())
	_button("abandonar", Loc.t("Abandonar partida"), false, func(): abandon_run.emit())
	_button("opciones", Loc.t("Opciones"), false, func(): show_options(true))
	_button("salir", Loc.t("Salir del juego"), false, func(): quit_game.emit())
	hints = PadHints.attach(self, [{"slot": PadGlyph.Slot.SOUTH, "key": "Enter", "text": Loc.t("Elegir")}, {"name": "DPAD", "key": "↑ | ↓", "text": Loc.t("Moverse")},
			{"slot": PadGlyph.Slot.EAST, "key": "Esc", "text": Loc.t("Continuar"), "call": func(): resume.emit()}])
	options = OptionsScreen.new()
	options.back.connect(func(): show_options(false))
	options.language_changed.connect(func(): language_changed.emit())
	add_child(options)


func _button(id: String, text: String, primary: bool, action: Callable) -> void:
	var b := UI.button(text, primary, 3.0, 88)
	b.name = id
	b.pressed.connect(action)
	column.add_child(b)
	buttons[id] = b


## El botón de reintentar: cuesta una vida (gratis en el tutorial y el entrenamiento) y en el casino no aparece. `lives`: las vidas que quedan.
func set_restart(lives: int, free: bool, in_casino: bool) -> void:
	var b = buttons["reiniciar"]
	b.visible = not in_casino
	b.disabled = false
	if free:
		b.set_label(Loc.t("Reintentar la torre"))
	elif lives <= 0:
		b.disabled = true
		b.set_label(Loc.t("Reintentar (sin vidas)"))
	else:
		b.set_label(Loc.t("Reintentar la torre (−1 vida)"))
	buttons["abandonar"].visible = not free


## Con una prueba activa el cartel de la prueba se ve entero al pausar (abajo): el menú sube un poco para no taparlo.
func make_room_for_banner(on: bool) -> void:
	center.offset_top = -100.0 if on else 0.0
	center.offset_bottom = -100.0 if on else 0.0


## La primera vez, en el tutorial, no se puede volver al menú principal ni abandonar.
func set_tutorial_lock(on: bool) -> void:
	buttons["menu"].visible = not on
	if on:
		buttons["abandonar"].visible = false


## Muestra u oculta las opciones dentro de la pausa.
func show_options(on: bool) -> void:
	center.visible = not on
	if hints != null:
		hints.visible = not on
	options.visible = on
	if on:
		options.refresh()
		options.focus_default()
	else:
		buttons["opciones"].grab_focus()


func open() -> void:
	visible = true
	show_options(false)
	buttons["continuar"].grab_focus()
	MenuAnim.stagger(MenuAnim.buttons_in(column), 0.04, 0.25)


func close() -> void:
	visible = false


# Esc cierra la pausa.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if options.visible:
			show_options(false)
		else:
			resume.emit()
		get_viewport().set_input_as_handled()
