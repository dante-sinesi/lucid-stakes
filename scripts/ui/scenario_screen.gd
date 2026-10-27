extends Control
## Selector de escenario (al tocar "Nueva partida"): tarjetas que se desplazan en horizontal. Cada una tiene un "?" (toda la
## información: reglas, pruebas, habilidades que se pueden ganar) y el botón de entrada con su costo en Luz (el sol). La Pesadilla
## es gratis. Sin la palabra "Luz": la moneda es el ícono del sol.

const UI := preload("res://scripts/ui/menu_ui.gd")
const PadHints := preload("res://scripts/ui/pad_hints.gd")
const PadGlyph := preload("res://scripts/ui/pad_glyph.gd")
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const Profile := preload("res://scripts/datos/profile.gd")
const Scenarios := preload("res://scripts/datos/scenarios.gd")
const Abilities := preload("res://scripts/datos/abilities.gd")
const Trials := preload("res://scripts/datos/trials.gd")
const ScenarioCard := preload("res://scripts/ui/scenario_card.gd")
const LuzCounter := preload("res://scripts/ui/luz_counter.gd")
const Tipos := preload("res://torre/tipos.gd")
const Loc := preload("res://scripts/idioma/loc.gd")
const Demo := preload("res://scripts/datos/demo.gd")

signal chosen(scenario_id: String)
signal back

const CARD_STEP := 324.0   # ancho de una tarjeta más la separación
const INFO_PASO := 60       # lo que baja o sube la información con cada pulsación

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
var info_scroll: ScrollContainer   # el desplazamiento de la información (flechas, WASD, Re Pág y Av Pág)


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
	var title := UI.label(col, "Elige el escenario", 5, UI.GOLD)
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
	PadHints.attach(self, [{"slot": PadGlyph.Slot.SOUTH, "key": "Espacio", "text": Loc.t("Entrar"), "keycode": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER], "call": _enter_current, "when": func(): return not info_panel.visible},
			{"slot": PadGlyph.Slot.NORTH, "key": "C", "text": Loc.t("Información"), "keycode": KEY_C, "call": _info_current, "when": func(): return not info_panel.visible},
			{"slot": PadGlyph.Slot.EAST, "key": "Esc", "text": Loc.t("Volver"), "keycode": KEY_ESCAPE, "call": func(): back.emit(), "when": func(): return not info_panel.visible}],
			[back_button, left_button, right_button])


## El escenario que está en el centro (el que se ve al desplazar las tarjetas con las flechas).
var sel_index := 0   # el escenario elegido (0 = el tutorial): con las flechas se llega a todos, aunque el desplazamiento no alcance a centrar los últimos


func _ids() -> Array:
	var ids: Array = [Scenarios.TUTORIAL.id]
	for sc in Scenarios.ALL:
		ids.append(sc.id)
	return ids


func _process(_delta: float) -> void:
	if not visible or cards.is_empty():
		return
	var cur := current_id()
	for id in cards:
		cards[id].is_current = (id == cur) and not info_panel.visible


## El escenario elegido.
func current_id() -> String:
	var ids := _ids()
	return str(ids[clampi(sel_index, 0, ids.size() - 1)])


## Elige otro escenario (con las flechas o la rueda) y desplaza las tarjetas para que se vea.
func move_selection(dir: int) -> void:
	sel_index = clampi(sel_index + dir, 0, _ids().size() - 1)
	var max_scroll := maxf(cards_box.get_combined_minimum_size().x - scroll.size.x, 0.0)
	var target := float(sel_index) * CARD_STEP - (scroll.size.x - CARD_STEP) * 0.5
	scroll.scroll_horizontal = int(clampf(target, 0.0, max_scroll))


func _enter_current() -> void:
	var id := current_id()
	if play_buttons.has(id) and not play_buttons[id].disabled:
		play_buttons[id].pressed.emit()


func _info_current() -> void:
	if cards.has(current_id()) and cards[current_id()].locked_soon:
		return
	show_info(current_id())


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
	info_scroll = ScrollContainer.new()
	info_scroll.custom_minimum_size = Vector2(980, 540)
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(info_scroll)
	info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 8)
	info_scroll.add_child(info_box)
	info_close = UI.button("Volver", true)
	info_close.name = "cerrar_info"
	info_close.pressed.connect(func(): info_panel.visible = false)
	col.add_child(info_close)
	PadHints.attach_in(col, [{"slot": PadGlyph.Slot.EAST, "key": "Esc", "text": Loc.t("Volver"), "call": func(): info_panel.visible = false}], [info_close])
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
		if not Scenarios.playable(str(s.id)) or not Demo.scenario_allowed(str(s.id)):   # los escenarios sin armar (y, en la demo, los que no incluye) dicen "Próximamente" y no se pueden entrar ni abrir
			card.lock_soon()
		card.info_pressed.connect(show_info)
		card.enter_pressed.connect(func(id): chosen.emit(id))
		cards[s.id] = card
		play_buttons[s.id] = card.enter_button
	info_panel.visible = false
	sel_index = maxi(_ids().find(Scenarios.FREE), 0)   # al abrir apunta a La Pesadilla (no al tutorial)
	scroll.scroll_horizontal = 0
	move_selection(0)


func focus_default() -> void:
	pass   # (se elige con las flechas y Enter: ningún botón queda apuntado)


## Desplaza las tarjetas una a la izquierda (-1) o a la derecha (1).
func scroll_cards(dir: int) -> void:
	move_selection(dir)


func _scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			scroll_cards(1)
			scroll.accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			scroll_cards(-1)
			scroll.accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed:
		return
	if info_panel.visible:   # la información: Esc cierra; las flechas, WASD y Re Pág / Av Pág la recorren (también manteniendo apretado)
		var paso := 0
		match event.keycode:
			KEY_UP, KEY_W:
				paso = -INFO_PASO
			KEY_DOWN, KEY_S:
				paso = INFO_PASO
			KEY_PAGEUP:
				paso = -int(info_scroll.size.y * 0.8)
			KEY_PAGEDOWN:
				paso = int(info_scroll.size.y * 0.8)
			KEY_HOME:
				info_scroll.scroll_vertical = 0
				get_viewport().set_input_as_handled()
			KEY_END:
				info_scroll.scroll_vertical = int(info_box.size.y)
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if not event.echo:
					info_panel.visible = false
					get_viewport().set_input_as_handled()
		if paso != 0:
			info_scroll.scroll_vertical += paso
			get_viewport().set_input_as_handled()
		return
	if event.echo:
		return
	if event.keycode == KEY_RIGHT or event.keycode == KEY_D:
		scroll_cards(1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_LEFT or event.keycode == KEY_A:
		scroll_cards(-1)
		get_viewport().set_input_as_handled()


## Reglas propias de un escenario, en frases cortas (salen de sus campos). Una regla puede llevar un asterisco: su aclaración sale en `rule_notes`.
static func rule_lines(s: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if int(s.get("mistakes", 0)) > 0:
		out.append(Loc.f("Cada sala permite solo %d movimientos en falso*; al siguiente se pierde una vida.", [int(s.mistakes)]))
	if bool(s.get("no_undo", false)):
		out.append("No se puede deshacer.")
	if bool(s.get("permadeath", false)):
		out.append("Una sola vida: si mueres, se termina.")
	if bool(s.get("no_totem", false)) or bool(s.get("no_extra_life", false)):
		out.append("Los Tótems y las Vidas extra no funcionan.")
	if int(s.get("casino_tier", -1)) >= 0:
		out.append("El casino es de lujo desde la primera etapa.")
	if int(s.get("escalon", 0)) > 0:
		out.append("Las torres son un escalón más difíciles.")
	if float(s.get("margen_mov", 1.0)) < 1.0:
		out.append("Cada sala da menos movimientos de margen.")
	var contratos: Dictionary = s.get("contratos", {})
	if int(contratos.get("activos_extra", 0)) > 0:
		out.append(Loc.f("Hasta %d contratos activos a la vez.", [2 + int(contratos.activos_extra)]))
	if int(contratos.get("nuevos_extra", 0)) > 0:
		out.append("Llegan más papeles nuevos al tablón en cada visita.")
	if float(contratos.get("premio_mult", 1.0)) > 1.0:
		out.append(Loc.f("Las recompensas y las fianzas de los contratos son %d %% mayores.", [int(round((float(contratos.premio_mult) - 1.0) * 100.0))]))
	if int(s.get("especiales_desde", 0)) > 0:
		out.append("Todos los bloques especiales aparecen desde la primera etapa.")
	if float(s.get("peso_especiales", 0.0)) > 0.0:
		out.append("Las salas con especiales salen mucho más seguido.")
	if float(s.get("toll_mult", 1.0)) > 1.0:
		out.append(Loc.f("Farolín cobra un %d %% más en cada peaje.", [int(round((float(s.toll_mult) - 1.0) * 100.0))]))
	if float(s.get("price_mult", 1.0)) < 1.0:
		out.append(Loc.f("La ficha de la ruleta cuesta %d %% menos.", [int(round((1.0 - float(s.price_mult)) * 100.0))]))
	if float(s.get("premio_mult", 1.0)) > 1.0:
		out.append(Loc.f("Los premios de las mesas valen un %d %% más.", [int(round((float(s.premio_mult) - 1.0) * 100.0))]))
	if out.is_empty():
		out.append("Las reglas de siempre.")
	return out


## Las aclaraciones de las reglas que llevan asterisco.
static func rule_notes(s: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if int(s.get("mistakes", 0)) > 0:
		out.append("* Movimiento en falso: movimiento que te deja a más pasos del final que antes.")
	return out


## Abre la información completa de un escenario (el "?" de su tarjeta).
func show_info(id: String) -> void:
	if cards.has(id) and cards[id].locked_soon:   # los "Próximamente" no tienen detalles
		return
	var s := Scenarios.get_scenario(id)
	for ch in info_box.get_children():
		info_box.remove_child(ch)
		ch.queue_free()
	UI.label(info_box, s.name, 5, UI.GOLD, false)
	if id == "tutorial":   # no es un escenario: no hay reglas, pruebas, habilidades ni Luz; solo lo que se aprende
		UI.label(info_box, s.desc, 3, Draw.MARBLE, false, 900)
		UI.label(info_box, "Lo que vas a aprender", 3, UI.GOLD, false)
		for line in ["Moverte según la brújula y girar la cámara", "Trepar, empujar, tirar y colgarte de los bordes", "El hielo, los bloques pesados y agrietados, y las bombas", "Cómo son las torres de verdad", "Para qué sirven la claridad, la ruleta, las pruebas y las habilidades"]:
			UI.label(info_box, Loc.f("- %s", [Loc.t(line)]), 2, Color(0.88, 0.84, 0.96), false, 900)
		info_panel.visible = true
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
	for nota in rule_notes(s):
		UI.label(info_box, Loc.t(nota), 2, Color(0.66, 0.62, 0.78), false, 900)
	UI.label(info_box, "Pruebas (una cada 3 etapas)", 3, UI.GOLD, false)
	var seen := {}
	for tid in s.pool:
		if seen.has(tid):
			continue
		seen[tid] = true
		UI.label(info_box, Loc.f("- %s: %s", [Loc.t(Trials.CATALOG[tid].name), Loc.t(Trials.CATALOG[tid].desc)]), 2, Color(0.88, 0.84, 0.96), false, 900)
	UI.label(info_box, "Habilidades al escapar (una por vez)", 3, Color(0.65, 0.95, 0.8), false, 900)
	for aid in Scenarios.ability_ids(s):
		var a := Abilities.get_ability(aid)
		UI.label(info_box, Loc.f("- %s: %s%s", [Loc.t(a.name), Loc.t(a.desc), Loc.t("  (ya la tienes)") if Profile.has_ability(aid) else ""]), 2, Color(0.75, 0.95, 0.85), false, 900)
	info_panel.visible = true
