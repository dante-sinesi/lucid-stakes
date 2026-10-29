extends Control
## Pantalla de la Ruleta de la Luz. Las reglas viven en roulette.gd; acá sólo se muestra y se gira.
## Diseño simple: la rueda grande en el centro (cada casilla lleva el ícono de su rareza), GIRAR con lo que cuesta el giro, un botón "Premios" que abre la ventana con los premios
## posibles y sus probabilidades, y "Rotar vitrina" para cambiar los premios de la visita. No hay apuestas: todas las casillas dan premio.
## Uso: crear, add_child, setup(run, rng). Emite `spun(result)` al terminar cada giro y `closed` al salir.

const Roulette := preload("res://scripts/casino/roulette.gd")
const Showcase := preload("res://scripts/casino/showcase.gd")
const Items := preload("res://scripts/datos/items.gd")
const Wheel := preload("res://scripts/casino/roulette_wheel.gd")
const UI := preload("res://scripts/ui/menu_ui.gd")
const CasinoTheme := preload("res://scripts/casino/casino_theme.gd")
const ClarityCounter := preload("res://scripts/ui/clarity_counter.gd")
const PrizesWindow := preload("res://scripts/ui/prizes_window.gd")
const Juice := preload("res://scripts/ui/juice.gd")
const Loc := preload("res://scripts/idioma/loc.gd")
const Rules := preload("res://scripts/casino/casino_visit.gd")
const Sfx := preload("res://scripts/sonido/sfx.gd")
const ResultOverlay := preload("res://scripts/ui/result_overlay.gd")
const PadHints := preload("res://scripts/ui/pad_hints.gd")
const PadGlyph := preload("res://scripts/ui/pad_glyph.gd")

signal spun(result: Dictionary)
signal resolved   ## el giro ya se cobró y pagó (antes de la animación): hay que guardar
signal closed

enum State { IDLE, SPINNING, RESULT }

const IDLE_SPIN := 0.10    # radianes por segundo: la rueda gira despacio mientras se elige

var run
var rng: RandomNumberGenerator
var fast := false          # animación casi instantánea y rueda quieta (pruebas)
var forced_pocket := -1    # para pruebas: fija la casilla que cae
var state := State.IDLE

var wheel
var claridad_counter       # [ícono] claridad del run
var th := CasinoTheme.for_tier(0)    # estética del nivel de casino (casino_theme.gd)
var sparkles: Control
var price_counter          # [ícono] lo que cuesta el giro
var spin_button: Button
var prizes_button: Button
var rotate_button: Button
var exit_button: Button
var prizes_window
var result_label: Control
var flash_rect: ColorRect   # destello al caer
var overlay                 # el cartel de resultado
var _spin_tween: Tween
var _spin_time := 0.0
var _tick_t := 0.0
var pad_hints
var _retired: Array = []
var shown_claridad := 0     # claridad que se muestra mientras gira (el giro ya está cobrado, pero no se spoilea el resultado)


func setup(run_state, random: RandomNumberGenerator, quick := false) -> void:
	run = run_state
	rng = random
	fast = quick
	th = CasinoTheme.for_run(run)
	_build()
	wheel.th = th
	wheel.tiers = Roulette.wheel_tiers(run)
	_refresh()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # (con offsets: se arma ya dentro del arbol, bajo una CanvasLayer)
	var bg := ColorRect.new()   # sólo oscurece lo que hay detrás: separa la ruleta del casino
	bg.color = Color(th.bg, 0.93)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Arriba: la claridad a la izquierda; Premios y Salir a la derecha.
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 14
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	claridad_counter = ClarityCounter.new(4.0)
	claridad_counter.name = "claridad"
	top.add_child(claridad_counter)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	prizes_button = UI.button("Premios", false, 3.0, 24)
	prizes_button.name = "premios"
	prizes_button.pressed.connect(open_prizes)
	top.add_child(prizes_button)
	rotate_button = UI.button("Rotar vitrina", false, 3.0, 36)
	rotate_button.name = "rotar"
	rotate_button.pressed.connect(rotate_showcase)
	top.add_child(rotate_button)
	top.move_child(rotate_button, prizes_button.get_index())
	exit_button = UI.button("Salir", false, 3.0, 16, false)
	exit_button.name = "salir"
	exit_button.pressed.connect(func(): closed.emit())
	top.add_child(exit_button)

	# Centro: la rueda grande y, a la derecha, una columna con el mensaje, el precio y GIRAR.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 44)
	center.add_child(row)
	wheel = Wheel.new()
	wheel.custom_minimum_size = Vector2(570, 570)
	wheel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(wheel)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(350, 0)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	result_label = UI.label(col, "", 2, Color(0.9, 0.86, 1.0), false, 350)
	result_label.custom_minimum_size = Vector2(350, 190)
	result_label.plate_alpha = 0.0
	result_label.align = UI.VoxelLabel.Align.CENTER
	result_label.vcenter = true
	var price_box := HBoxContainer.new()
	price_box.alignment = BoxContainer.ALIGNMENT_CENTER
	price_box.add_theme_constant_override("separation", 10)
	col.add_child(price_box)
	UI.label(price_box, "Giro", 3, Color(0.85, 0.8, 1.0), false)
	price_counter = ClarityCounter.new(3.0)
	price_counter.name = "precio"
	price_box.add_child(price_counter)
	spin_button = UI.button("GIRAR", true, 4.0, 85)
	spin_button.name = "girar"
	spin_button.size_flags_horizontal = Control.SIZE_FILL
	spin_button.pressed.connect(func(): spin())
	col.add_child(spin_button)

	prizes_window = PrizesWindow.new()
	prizes_window.run = run
	prizes_window.rotate_cb = rotate_showcase
	add_child(prizes_window)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	add_child(flash_rect)
	overlay = ResultOverlay.new()
	add_child(overlay)
	pad_hints = PadHints.new()   # la ayuda de los botones del mando (sólo se ve cuando se juega con mando)
	pad_hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	pad_hints.offset_top = -52.0
	pad_hints.offset_bottom = -8.0
	add_child(pad_hints)
	PadHints.focus_none(self)   # con el mando se juega apretando botones, no moviéndose por la pantalla
	pad_hints.set_items([{"slot": PadGlyph.Slot.SOUTH, "key": "Espacio", "text": Loc.t("Girar"), "call": func(): spin()},
			{"slot": PadGlyph.Slot.NORTH, "key": "C", "text": Loc.t("Premios"), "call": open_prizes},
			{"name": "LT", "key": "R", "text": Loc.t("Rotar vitrina"), "call": rotate_showcase},
			{"slot": PadGlyph.Slot.EAST, "key": "Esc", "text": Loc.t("Salir"), "call": func(): closed.emit()}])
	_retired = PadHints.retire([spin_button, prizes_button, rotate_button, exit_button])   # la botonera de abajo los reemplaza
	shown_claridad = run.claridad


func _process(delta: float) -> void:
	if wheel != null and not fast and state != State.SPINNING and not prizes_window.visible:
		wheel.rotation_angle += delta * IDLE_SPIN
	if state == State.SPINNING and not fast:   # tic tic tic: la bolilla pasa por las casillas, cada vez más despacio
		_spin_time += delta
		_tick_t += delta
		var interval := 0.045 + 0.2 * pow(clampf(_spin_time / 3.4, 0.0, 1.0), 2.0)
		if _tick_t >= interval:
			_tick_t = 0.0
			Sfx.play("tick", 0.9 + randf() * 0.2)


## Rota la vitrina (se sortean otros premios de la visita): cuesta una ficha, y una más por cada rotación que ya se hizo en esta visita.
func rotate_showcase() -> void:
	if state == State.SPINNING or run.showcase.is_empty():
		return
	if not Showcase.rotate(run, rng):
		result_label.text = Loc.f("Rotar la vitrina cuesta %d de claridad", [Showcase.rotate_cost(run)])
		return
	shown_claridad = run.claridad
	resolved.emit()
	_refresh()
	result_label.text = Loc.t("La vitrina cambió: mira los premios")
	if not prizes_window.visible:
		prizes_window.open_for(Items.Tier.EPICO)


func open_prizes() -> void:
	prizes_window.open_for(Items.Tier.EPICO)


# --- interacción ---------------------------------------------------------------------------------------------

func can_spin() -> bool:
	return state != State.SPINNING and Roulette.validate(run) == ""


## Una vuelta de la rueda hasta dejar `pocket` bajo la bola (siempre hacia adelante desde donde esté).
func _turn_to(pocket: int) -> void:
	var duration := 0.1 if fast else 3.4
	var turns := 4 if not fast else 1
	var base: float = wheel.angle_for(pocket)
	var target: float = base + TAU * floorf((wheel.rotation_angle - base) / TAU) - TAU * turns
	var tw := create_tween()
	_spin_tween = tw
	if not fast:   # antes de arrancar, la rueda se echa un poco hacia atrás (como tomar impulso)
		tw.tween_property(wheel, "rotation_angle", wheel.rotation_angle + 0.28, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(wheel, "rotation_angle", target, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	await tw.finished
	wheel.rotation_angle = target


## Gira: se decide el resultado primero y la rueda gira para mostrarlo (con Segunda vuelta, a veces gira dos veces).
func spin() -> Dictionary:
	if state == State.SPINNING:
		return {"ok": false, "error": "La ruleta ya está girando"}
	var err := Roulette.validate(run)
	if err != "":
		result_label.cube = 2.0
		result_label.text = err
		result_label.color = Color(1.0, 0.6, 0.5)
		return {"ok": false, "error": err}
	shown_claridad = run.claridad
	var res := Roulette.resolve(run, rng, forced_pocket)
	resolved.emit()
	_spin_time = 0.0
	_tick_t = 0.0
	state = State.SPINNING
	wheel.result = -1
	wheel.win_t = -1.0
	wheel.spinning = not fast
	_refresh()
	await _turn_to(int(res.first_pocket))
	if bool(res.second_spin):   # Segunda vuelta: cayó en común y la rueda gira otra vez
		wheel.result = int(res.first_pocket)
		wheel.spinning = false
		result_label.cube = 2.0
		result_label.text = Loc.t("¡Segunda vuelta!")
		result_label.color = Color(1.0, 0.9, 0.45)
		if not fast:
			await get_tree().create_timer(0.7).timeout
		wheel.result = -1
		wheel.spinning = not fast
		_spin_time = 0.0
		await _turn_to(int(res.pocket))
	wheel.spinning = false
	wheel.result = res.pocket
	state = State.RESULT
	_spin_tween = null
	_result_effects(res)
	_show_result(res)
	_show_overlay(res)
	_refresh()
	spun.emit(res)
	return res


## Espacio mientras gira: se saltea la animación (la rueda llega enseguida).
func skip_spin() -> void:
	if state == State.SPINNING and _spin_tween != null and _spin_tween.is_valid():
		_spin_tween.set_speed_scale(60.0)


## La claridad que dio el premio de un giro (bolsa, o un ítem que no entró: se convierte), sin contar los extras de la sala.
func _reward_of(res: Dictionary) -> int:
	var prize: Dictionary = res.prize
	var unit := Roulette.run_price(run)
	if prize.type == Items.Type.CLARITY:
		return int(round(prize.mult * unit))
	if res.converted:
		return int(round(Items.value_of(prize, unit) * 0.5))
	return 0


## El cartel de resultado sobre la ruleta: cuánta claridad y, si el premio es un ítem, cuál.
func _show_overlay(res: Dictionary) -> void:
	if fast:
		return
	var prize: Dictionary = res.prize
	var delta := _reward_of(res) + int(res.get("rules", {}).get("total", 0))
	var item_id := ""
	var item_name := ""
	if prize.type != Items.Type.CLARITY and not res.converted:
		item_id = str(prize.id)
		item_name = Loc.t(str(prize.name))
	overlay.show_result(true, delta, item_id, item_name, Rules.notes(res))


## Con el mando: A gira, Y abre los premios, LT rota la vitrina y B sale.
func _pad_key(code: int) -> bool:
	if overlay.showing:
		return false
	match code:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if state == State.SPINNING:
				skip_spin()
			else:
				spin()   # (si no alcanza la claridad, muestra por qué)
			return true
		KEY_C:
			open_prizes()
			return true
		KEY_R:
			rotate_showcase()
			return true
		KEY_ESCAPE:
			closed.emit()
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or prizes_window.visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if _pad_key(event.keycode):
		get_viewport().set_input_as_handled()
		return
	if not event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		return
	if overlay.showing:
		return   # (el cartel se cierra solo con Espacio)
	if state == State.SPINNING:
		skip_spin()
	elif can_spin():
		spin()
	get_viewport().set_input_as_handled()


## Efectos al caer la bola: la bola rebota, parpadea la casilla, destello dorado (y chispas si es épica o rara) y la claridad sube contando hasta su valor final.
func _result_effects(res: Dictionary) -> void:
	if not fast:
		wheel.ball_hop()
		wheel.win_t = 0.0
	var tier := int(res.tier)
	if tier == Items.Tier.EPICO or tier == Items.Tier.RARO:
		_flash(Color(1.0, 0.88, 0.4), 0.3)
		_sparkle(18 if tier == Items.Tier.EPICO else 10)
	else:
		_flash(Color(0.8, 0.7, 1.0), 0.12)
	var from := shown_claridad
	if fast or from == run.claridad:
		shown_claridad = run.claridad
		return
	create_tween().tween_method(func(v: float) -> void:
			shown_claridad = int(round(v))
			claridad_counter.value = shown_claridad, float(from), float(run.claridad), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if run.claridad > from:
		Juice.pop(claridad_counter, 1.3)


## Chispas doradas al caer en una casilla buena en los casinos de nivel alto.
func _sparkle(count: int) -> void:
	if fast or int(th.shine) < 2:
		return
	if sparkles == null:
		sparkles = CasinoTheme.Sparkles.new()
		add_child(sparkles)
	sparkles.burst(wheel.global_position - global_position + wheel.size * 0.5, count * (int(th.shine) - 1), [Color(1.0, 0.9, 0.4), Color(1, 1, 0.9), Color(1.0, 0.7, 0.25)])


func _flash(color: Color, peak: float) -> void:
	if fast:
		return
	flash_rect.color = Color(color, peak)
	create_tween().tween_property(flash_rect, "color:a", 0.0, 0.5)


func _show_result(res: Dictionary) -> void:
	var tier := int(res.tier)
	Sfx.play("win" if tier == Items.Tier.EPICO or tier == Items.Tier.RARO else "coin")
	var prize: Dictionary = res.prize
	var donde := Loc.t(Roulette.TIER_NAMES[tier])
	var txt := ""
	if prize.type == Items.Type.CLARITY:
		txt = Loc.f("¡Cayó una casilla de %s! %s: +%d de claridad.", [donde.to_lower(), Loc.t(prize.name), _reward_of(res)])
	elif res.converted:
		txt = Loc.f("¡Cayó una casilla de %s! Ganaste %s, pero no hay lugar: se convirtió en %d de claridad.", [donde.to_lower(), Loc.t(prize.name), _reward_of(res)])
	else:
		txt = Loc.f("¡Cayó una casilla de %s! Ganaste %s: %s", [donde.to_lower(), Loc.t(prize.name), Loc.t(prize.desc)])
	result_label.cube = 2.0
	result_label.text = txt + Rules.notes(res)
	result_label.color = Color(1.0, 0.9, 0.45)
	if not fast:
		Juice.pop(result_label, 1.2)


func _refresh() -> void:
	var price: int = Roulette.spin_price(run)
	claridad_counter.value = shown_claridad if state == State.SPINNING else run.claridad
	price_counter.value = price
	wheel.tiers = Roulette.wheel_tiers(run)
	spin_button.disabled = not can_spin()
	prizes_button.disabled = state == State.SPINNING
	rotate_button.visible = not run.showcase.is_empty()
	rotate_button.text = Loc.f("Rotar vitrina (%d)", [Showcase.rotate_cost(run)])
	rotate_button.disabled = state == State.SPINNING or not run.can_afford(Showcase.rotate_cost(run))
	if state == State.RESULT:
		return   # queda el mensaje del resultado hasta el próximo giro
	result_label.color = Color(0.9, 0.86, 1.0)
	result_label.cube = 3.0
	if state == State.SPINNING:
		result_label.text = ""
	elif not run.can_afford(price):
		result_label.text = "No alcanza la claridad para el giro"
	else:
		result_label.text = ""   # (la botonera de abajo ya dice "Espacio Girar")


func _exit_tree() -> void:
	PadHints.free_retired(_retired)
