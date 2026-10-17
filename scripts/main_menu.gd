extends Control
## Menú principal: Continuar, Nueva partida, Tutorial, Cómo jugar, Créditos y Salir. Todo hecho de cubitos (híbrido: limpio que se corrompe).
## Avisa con señales; main.gd decide qué hacer.

const UI := preload("res://scripts/menu_ui.gd")
const MenuAnim := preload("res://scripts/menu_anim.gd")
const Draw := preload("res://scripts/voxel_draw.gd")
const SwirlBG := preload("res://scripts/swirl_bg.gd")
const MetaScreen := preload("res://scripts/meta_screen.gd")
const ScenarioScreen := preload("res://scripts/scenario_screen.gd")
const CosmeticsScreen := preload("res://scripts/cosmetics_screen.gd")
const OptionsScreen := preload("res://scripts/options_screen.gd")
const Loc := preload("res://scripts/loc.gd")
const Demo := preload("res://scripts/demo.gd")
const VoxelLabel := preload("res://scripts/voxel_label.gd")

signal new_game(scenario_id: String)
signal continue_game
signal start_tutorial
signal quit_game
signal language_changed

var buttons := {}
var credits: Control
var licenses: Control
var scenarios: Control   # selector de escenario (al tocar Nueva partida)
var soon_label: Control   # el aviso de "Disponible en la versión completa"
var _soon_tween: Tween
var cosmetics: Control   # pantalla de cosméticos
var meta: Control   # pantalla del Despertar (meta-progresión)
var options: Control   # pantalla de opciones
var credits_button: Button
var main_center: CenterContainer
var column: VBoxContainer


func _init() -> void:
	name = "menu_principal"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := SwirlBG.new()   # fondo en remolino de cubitos
	bg.dim = 0.3
	add_child(bg)
	main_center = CenterContainer.new()
	main_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_center)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	main_center.add_child(column)
	var title := UI.label(column, UI.TITLE, 7, UI.GOLD)
	title.name = "titulo"
	title.dance = true
	UI.label(column, Loc.t(UI.SUBTITLE), 3.5, Color(0.85, 0.8, 1.0))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	column.add_child(spacer)
	_button("continuar", Loc.t("Continuar"), true, func(): continue_game.emit())
	buttons["continuar"].visible = false
	_button("nueva", Loc.t("Nueva partida"), false, func(): show_panel("escenarios"))
	_button("despertar", Loc.t("Habilidades"), false, _open_abilities)
	_button("cosmeticos", Loc.t("Personaje"), false, func(): show_panel("cosmeticos"))
	_button("opciones", Loc.t("Opciones"), false, func(): show_panel("opciones"))
	_button("salir", Loc.t("Salir"), false, func(): quit_game.emit())
	credits = UI.make_credits_panel(func(): show_panel("principal"), func(): show_panel("licencias"))
	add_child(credits)
	licenses = UI.make_licenses_panel(func(): show_panel("creditos"))
	add_child(licenses)
	scenarios = ScenarioScreen.new()
	scenarios.back.connect(func(): show_panel("principal"))
	scenarios.chosen.connect(func(id):   # la primera tarjeta es el tutorial
		if id == "tutorial":
			start_tutorial.emit()
		else:
			new_game.emit(id))
	add_child(scenarios)
	cosmetics = CosmeticsScreen.new()
	cosmetics.back.connect(func(): show_panel("principal"))
	add_child(cosmetics)
	meta = MetaScreen.new()
	meta.back.connect(func(): show_panel("principal"))
	add_child(meta)
	options = OptionsScreen.new()
	options.back.connect(func(): show_panel("principal"))
	options.language_changed.connect(func(): language_changed.emit())
	add_child(options)
	credits_button = UI.button(Loc.t("Créditos"), false, 2.0, 30, false)   # abajo a la izquierda
	credits_button.name = "creditos"
	credits_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	credits_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	credits_button.offset_left = 18.0
	credits_button.offset_top = -18.0
	credits_button.offset_bottom = -18.0
	credits_button.pressed.connect(func(): show_panel("creditos"))
	add_child(credits_button)
	buttons["creditos"] = credits_button


## Habilidades persistentes: en la demo el botón sólo avisa que es del juego completo.
func _open_abilities() -> void:
	if Demo.on():
		soon_message(Demo.full_text())
		return
	show_panel("despertar")


## Un aviso corto abajo en el medio del menú (se desvanece solo).
func soon_message(text: String) -> void:
	if soon_label == null:
		soon_label = VoxelLabel.new()
		soon_label.cube = 3.0
		soon_label.color = Color(1.0, 0.85, 0.4)
		soon_label.align = VoxelLabel.Align.CENTER
		soon_label.plate_alpha = 0.6
		soon_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		soon_label.name = "aviso"
		add_child(soon_label)
	soon_label.text = text
	soon_label.y_offset = 640.0
	soon_label.modulate.a = 1.0
	if _soon_tween != null:
		_soon_tween.kill()
	_soon_tween = create_tween()
	_soon_tween.tween_interval(1.6)
	_soon_tween.tween_property(soon_label, "modulate:a", 0.0, 0.8)


func _button(id: String, text: String, primary: bool, action: Callable) -> void:
	var b := UI.button(text, primary, 2.5, 100)
	b.name = id
	b.pressed.connect(action)
	column.add_child(b)
	buttons[id] = b


## Muestra el botón Continuar si hay una partida guardada (stage > 0) con su etapa; si no, lo oculta.
func set_continue(stage_saved: int) -> void:
	buttons["continuar"].visible = stage_saved > 0
	if stage_saved > 0:
		buttons["continuar"].set_label(Loc.f("Continuar (etapa %d)", [stage_saved]))
	buttons["nueva"].primary = stage_saved <= 0
	buttons["continuar"].primary = stage_saved > 0


## Muestra una sola pantalla: "principal", "escenarios", "despertar", "cosmeticos", "opciones", "creditos" o "licencias".
func show_panel(which: String) -> void:
	main_center.visible = which == "principal"
	credits.visible = which == "creditos"
	licenses.visible = which == "licencias"
	scenarios.visible = which == "escenarios"
	if which == "escenarios":
		scenarios.refresh()
	cosmetics.visible = which == "cosmeticos"
	if which == "cosmeticos":
		cosmetics.refresh()
	options.visible = which == "opciones"
	if which == "opciones":
		options.refresh()
	meta.visible = which == "despertar"
	if which == "despertar":
		meta.refresh()
	credits_button.visible = which == "principal"
	var panel: Control = main_center
	match which:
		"principal":
			(buttons["continuar"] if buttons["continuar"].visible else buttons["nueva"]).grab_focus()
		"escenarios":
			panel = scenarios
			scenarios.focus_default()
		"cosmeticos":
			panel = cosmetics
			cosmetics.back_button.grab_focus()
		"opciones":
			panel = options
			options.focus_default()
		"despertar":
			panel = meta
			meta.back_button.grab_focus()
		"creditos":
			panel = credits
			credits.find_child("volver_creditos", true, false).grab_focus()
		"licencias":
			panel = licenses
			licenses.find_child("volver_licencias", true, false).grab_focus()
	MenuAnim.stagger(MenuAnim.buttons_in(panel), 0.05, 0.28, 0.05)


func open() -> void:
	visible = true
	show_panel("principal")
