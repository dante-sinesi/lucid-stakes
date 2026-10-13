extends Control
## Selector de escenario (al tocar "Nueva partida"): tarjetas que se desplazan en horizontal. Cada una tiene un "?" (toda la
## información: reglas, pruebas, habilidades que se pueden ganar) y el botón de entrada con su costo en Luz (el sol). La Pesadilla
## es gratis. Sin la palabra "Luz": la moneda es el ícono del sol.

const UI := preload("res://scripts/menu_ui.gd")
const Draw := preload("res://scripts/voxel_draw.gd")
const Profile := preload("res://scripts/profile.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
const Abilities := preload("res://scripts/abilities.gd")
const Trials := preload("res://scripts/trials.gd")
const ScenarioCard := preload("res://scripts/scenario_card.gd")
const LuzCounter := preload("res://scripts/luz_counter.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const Loc := preload("res://scripts/loc.gd")

signal chosen(scenario_id: String)
signal back

const CARD_STEP := 324.0   # ancho de una tarjeta más la separación

var luz_counter
var scroll: ScrollContainer
var cards_box: HBoxContainer
var cards := {}          # id -> tarjeta
var play_buttons := {}   # id -> botón de entrada de la tarjeta
var back_button: Button
var left_button: Button
var right_button: Button
var info_panel: Control  # información completa de un escenario (se abre con el "?")
var info_close: Button
var info_box: VBoxContainer


func _init() -> void:
	name = "escenarios"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.09, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)
	var title := UI.label(col, "Elegí el escenario", 5, UI.GOLD)
	title.dance = true
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(top)
	luz_counter = LuzCounter.new(4.0)
	luz_counter.name = "luz"
	top.add_child(luz_counter)
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 8)
	col.add_child(mid)
	left_button = UI.button("<", false, 4.0, 6, false)
	left_button.name = "izquierda"
	left_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left_button.pressed.connect(func(): scroll_cards(-1))
	mid.add_child(left_button)
	scroll = ScrollContainer.new()
	scroll.name = "desplazamiento"
	scroll.custom_minimum_size = Vector2(1000, 450)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.gui_input.connect(_scroll_input)
	mid.add_child(scroll)
	cards_box = HBoxContainer.new()
	cards_box.add_theme_constant_override("separation", 24)
	scroll.add_child(cards_box)
	right_button = UI.button(">", false, 4.0, 6, false)
	right_button.name = "derecha"
	right_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right_button.pressed.connect(func(): scroll_cards(1))
	mid.add_child(right_button)
	back_button = UI.button("Volver", false)
	back_button.name = "volver_escenarios"
	back_button.pressed.connect(func(): back.emit())
	col.add_child(back_button)
	_build_info_panel()


func _build_info_panel() -> void:
	info_panel = Control.new()
	info_panel.name = "info"
	info_panel.visible = false
	info_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	info_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	info_panel.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(980, 540)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 8)
	sc.add_child(info_box)
	info_close = UI.button("Volver", true)
	info_close.name = "cerrar_info"
	info_close.pressed.connect(func(): info_panel.visible = false)
	col.add_child(info_close)
	add_child(info_panel)


## Arma las tarjetas con el perfil actual (qué escenarios se pueden pagar).
func refresh() -> void:
	luz_counter.value = Profile.luz()
	for ch in cards_box.get_children():
		cards_box.remove_child(ch)
		ch.queue_free()
	cards.clear()
	play_buttons.clear()
	var all: Array[Dictionary] = [Scenarios.TUTORIAL]   # el tutorial es la primera tarjeta
	all.append_array(Scenarios.ALL)
	for s in all:
		var card := ScenarioCard.new()
		card.name = "tarjeta_" + s.id
		cards_box.add_child(card)
		card.setup(s, Profile.can_enter(s.id))
		card.info_pressed.connect(show_info)
		card.enter_pressed.connect(func(id): chosen.emit(id))
		cards[s.id] = card
		play_buttons[s.id] = card.enter_button
	info_panel.visible = false
	scroll.scroll_horizontal = 0


func focus_default() -> void:
	if play_buttons.has(Scenarios.FREE):
		play_buttons[Scenarios.FREE].grab_focus()


## Desplaza las tarjetas una a la izquierda (-1) o a la derecha (1).
func scroll_cards(dir: int) -> void:
	var max_scroll := maxf(cards_box.get_combined_minimum_size().x - scroll.size.x, 0.0)
	scroll.scroll_horizontal = int(clampf(round(scroll.scroll_horizontal / CARD_STEP) * CARD_STEP + dir * CARD_STEP, 0.0, max_scroll))


func _scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			scroll_cards(1)
			scroll.accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			scroll_cards(-1)
			scroll.accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if info_panel.visible:
		if event.keycode == KEY_ESCAPE:
			info_panel.visible = false
			get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_RIGHT:
		scroll_cards(1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_LEFT:
		scroll_cards(-1)
		get_viewport().set_input_as_handled()


## Reglas propias de un escenario, en frases (salen de sus campos).
static func rule_lines(s: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var bias: Dictionary = s.get("bias", {})
	var kinds: Dictionary = bias.get("kinds", {})
	var K := TowerLogic.Kind
	if kinds.has(K.ICE) or float(bias.get("plat_ice", 0.0)) > 0.0:
		out.append("Las torres tienen mucho más hielo, desde la primera etapa.")
	if kinds.has(K.CRACKED) or kinds.has(K.HEAVY):
		out.append("Abundan los bloques agrietados y los pesados.")
	if kinds.has(K.BOMB):
		out.append("Hay muchas más bombas.")
	if str(s.get("pace", "")) == "fast":
		out.append("La fila de abajo siempre cae rápido.")
	if float(s.get("price_mult", 1.0)) < 1.0:
		out.append(Loc.f("La ficha de la ruleta cuesta %d %% menos.", [int(round((1.0 - float(s.price_mult)) * 100.0))]))
	if int(s.get("casino_tier", -1)) >= 0:
		out.append("El casino es de lujo desde la primera etapa.")
	if float(s.get("diff_offset", 0.0)) > 0.0:
		out.append("Las torres son más difíciles.")
	if bool(s.get("permadeath", false)):
		out.append("Una sola vida: si morís, se termina.")
	if bool(s.get("no_totem", false)) or bool(s.get("no_extra_life", false)):
		out.append("Los Tótems y las Vidas extra no funcionan.")
	if out.is_empty():
		out.append("Las reglas de siempre.")
	return out


## Abre la información completa de un escenario (el "?" de su tarjeta).
func show_info(id: String) -> void:
	var s := Scenarios.get_scenario(id)
	for ch in info_box.get_children():
		info_box.remove_child(ch)
		ch.queue_free()
	UI.label(info_box, s.name, 5, UI.GOLD, false)
	UI.label(info_box, s.desc, 3, Draw.MARBLE, false, 900)
	if id == "tutorial":   # no es un escenario: no hay pruebas, habilidades ni Luz
		UI.label(info_box, "Lo que vas a aprender", 3, UI.GOLD, false)
		for line in ["Moverte según la brújula y girar la cámara", "Trepar, empujar, tirar y colgarte de los bordes", "El hielo, los bloques pesados y agrietados, y las bombas", "Cómo son las torres de verdad", "Para qué sirven la claridad, la ruleta, las pruebas y las habilidades"]:
			UI.label(info_box, Loc.f("- %s", [Loc.t(line)]), 2, Color(0.88, 0.84, 0.96), false, 900)
		info_panel.visible = true
		info_close.grab_focus()
		return
	var pay := HBoxContainer.new()
	pay.add_theme_constant_override("separation", 24)
	info_box.add_child(pay)
	var cost := LuzCounter.new(3.0)
	cost.name = "costo"
	cost.value = int(s.entry)
	pay.add_child(cost)
	if float(s.luz_mult) != 1.0:
		var mult := LuzCounter.new(3.0)
		mult.name = "multiplicador"
		mult.label.text = "x%.1f" % float(s.luz_mult)
		pay.add_child(mult)
	UI.label(info_box, "Reglas", 3, UI.GOLD, false)
	for line in rule_lines(s):
		UI.label(info_box, Loc.f("- %s", [Loc.t(line)]), 2, Color(0.88, 0.84, 0.96), false, 900)
	UI.label(info_box, "Pruebas que pueden salir (de a una cada 3 etapas)", 3, UI.GOLD, false)
	var seen := {}
	for tid in s.pool:
		if seen.has(tid):
			continue
		seen[tid] = true
		UI.label(info_box, Loc.f("- %s: %s", [Loc.t(Trials.CATALOG[tid].name), Loc.t(Trials.CATALOG[tid].desc)]), 2, Color(0.88, 0.84, 0.96), false, 900)
	UI.label(info_box, "Habilidades que se pueden ganar al escapar (de a una por vez)", 3, Color(0.65, 0.95, 0.8), false, 900)
	for aid in Scenarios.ability_ids(s):
		var a := Abilities.get_ability(aid)
		UI.label(info_box, Loc.f("- %s: %s%s", [Loc.t(a.name), Loc.t(a.desc), Loc.t("  (ya la tenés)") if Profile.has_ability(aid) else ""]), 2, Color(0.75, 0.95, 0.85), false, 900)
	info_panel.visible = true
	info_close.grab_focus()
