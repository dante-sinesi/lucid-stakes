extends Control
## Pantalla de apuesta de la Ruleta de la Luz. Las reglas viven en roulette.gd; acá sólo se elige y se muestra.
## Diseño simple: la rueda grande en el centro (las fichas se ponen tocándola), las cuatro apuestas como cartas debajo, GIRAR con
## el precio de la ficha, y un botón "Premios" que abre la ventana con los premios posibles y sus probabilidades.
## Uso: crear, add_child, setup(run, rng). Emite `spun(result)` al terminar cada giro y `closed` al salir.

const Roulette := preload("res://scripts/roulette.gd")
const Showcase := preload("res://scripts/showcase.gd")
const Items := preload("res://scripts/items.gd")
const Wheel := preload("res://scripts/roulette_wheel.gd")
const UI := preload("res://scripts/menu_ui.gd")
const SwirlBG := preload("res://scripts/swirl_bg.gd")
const CasinoTheme := preload("res://scripts/casino_theme.gd")
const ClarityCounter := preload("res://scripts/clarity_counter.gd")
const PrizesWindow := preload("res://scripts/prizes_window.gd")
const Juice := preload("res://scripts/juice.gd")
const Loc := preload("res://scripts/loc.gd")
const RuleUI := preload("res://scripts/casino_rule_ui.gd")
const Sfx := preload("res://scripts/sfx.gd")
const ResultOverlay := preload("res://scripts/result_overlay.gd")
const PadHints := preload("res://scripts/pad_hints.gd")
const PadGlyph := preload("res://scripts/pad_glyph.gd")
const Controls := preload("res://scripts/controls.gd")

signal spun(result: Dictionary)
signal resolved   ## la tirada ya se cobró y pagó (antes de la animación): hay que guardar
signal closed

enum State { IDLE, SPINNING, RESULT }

const IDLE_SPIN := 0.10    # radianes por segundo: la rueda gira despacio mientras se elige

var run
var rng: RandomNumberGenerator
var fast := false          # animación casi instantánea y rueda quieta (pruebas)
var forced_pocket := -1    # para pruebas: fija la casilla que cae
var state := State.IDLE
var bet := Roulette.Bet.PLENO
var selected: Array = []   # casillas elegidas (en orden de elección)

var wheel
var claridad_counter       # [ícono] claridad del run
var rule_label: Control
var th := CasinoTheme.for_tier(0)    # estética del nivel de casino (casino_theme.gd)
var sparkles: Control
var price_counter          # [ícono] precio de la ficha
var bet_buttons := {}
var spin_button: Button
var prizes_button: Button
var rotate_button: Button
var exit_button: Button
var prizes_window
var result_label: Control
var flash_rect: ColorRect   # destello al ganar
var overlay                 # el cartel de "¡Ganaste!" / "¡Perdiste!"
var _spin_tween: Tween
var _spin_time := 0.0
var _tick_t := 0.0
var pad_hints
var _retired: Array = []
var pad_cursor := 1        # la casilla que marca el mando (se mueve con la cruceta; X pone o saca la ficha)
var shown_claridad := 0     # claridad que se muestra mientras gira (la tirada ya está cobrada, pero no se spoilea el resultado)


func setup(run_state, random: RandomNumberGenerator, quick := false) -> void:
	run = run_state
	rng = random
	fast = quick
	th = CasinoTheme.for_run(run)
	_build()
	wheel.th = th
	select_bet(Roulette.Bet.PLENO)


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
	rule_label = RuleUI.make_status(top, 620)   # (el estado de la regla ya no se muestra: lo cuenta el tabernero)
	rule_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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

	# Centro: la rueda grande y, a la derecha, una columna con el mensaje, las apuestas y GIRAR.
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
	wheel.pocket_clicked.connect(toggle_pocket)
	row.add_child(wheel)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(350, 0)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	result_label = UI.label(col, "", 2, Color(0.9, 0.86, 1.0), false, 350)
	result_label.custom_minimum_size = Vector2(350, 112)
	result_label.plate_alpha = 0.0
	result_label.align = UI.VoxelLabel.Align.CENTER
	result_label.vcenter = true
	for b in Roulette.BETS:
		var btn := UI.button(Loc.f("%s (%d)", [Loc.t(Roulette.BETS[b].name), Roulette.BETS[b].count]), false, 3.0, 110, false)
		btn.toggle_mode = true
		btn.pressed.connect(select_bet.bind(b))
		btn.size_flags_horizontal = Control.SIZE_FILL
		col.add_child(btn)
		bet_buttons[b] = btn
	var price_box := HBoxContainer.new()
	price_box.alignment = BoxContainer.ALIGNMENT_CENTER
	price_box.add_theme_constant_override("separation", 10)
	col.add_child(price_box)
	UI.label(price_box, "Ficha", 3, Color(0.85, 0.8, 1.0), false)
	price_counter = ClarityCounter.new(3.0)
	price_counter.name = "ficha"
	price_box.add_child(price_counter)
	spin_button = UI.button("GIRAR", true, 4.0, 85)
	spin_button.name = "girar"
	spin_button.size_flags_horizontal = Control.SIZE_FILL
	spin_button.pressed.connect(func(): spin())
	col.add_child(spin_button)

	prizes_window = PrizesWindow.new()
	prizes_window.run = run
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
	pad_hints.set_items([{"slot": PadGlyph.Slot.SOUTH, "key": "Enter", "text": Loc.t("Girar"), "call": func(): spin()},
			{"slot": PadGlyph.Slot.WEST, "key": "Espacio", "text": Loc.t("Poner ficha"), "call": func(): toggle_pocket(pad_cursor)},
			{"name": "DPAD", "key": "← | →", "text": Loc.t("Casilla")},
			{"name": "LB|RB", "key": "Q | E", "text": Loc.t("Tipo de apuesta")},
			{"slot": PadGlyph.Slot.NORTH, "key": "C", "text": Loc.t("Premios"), "call": open_prizes},
			{"name": "LT", "key": "Shift", "text": Loc.t("Rotar vitrina"), "call": rotate_showcase},
			{"slot": PadGlyph.Slot.EAST, "key": "Esc", "text": Loc.t("Salir"), "call": func(): closed.emit()}])
	_retired = PadHints.retire([spin_button, prizes_button, rotate_button, exit_button])   # la botonera de abajo los reemplaza
	shown_claridad = run.claridad


func _process(delta: float) -> void:
	if wheel != null:
		wheel.cursor_pocket = pad_cursor if state != State.SPINNING and not prizes_window.visible else -1
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
	result_label.text = Loc.t("La vitrina cambió: mirá los premios")
	prizes_window.open_for(bet)


func open_prizes() -> void:
	prizes_window.open_for(bet)


# --- interacción ---------------------------------------------------------------------------------------------

func select_bet(b: int) -> void:
	if state == State.SPINNING:
		return
	bet = b
	var n: int = Roulette.BETS[b].count
	while selected.size() > n:
		selected.pop_front()
	state = State.IDLE
	_refresh()


func toggle_pocket(i: int) -> void:
	if state == State.SPINNING or i < 1 or i >= Roulette.POCKETS:
		return
	Sfx.play("chip")
	if selected.has(i):
		selected.erase(i)
	else:
		selected.append(i)
		while selected.size() > Roulette.BETS[bet].count:
			selected.pop_front()  # al pasarse, se suelta la ficha más vieja
	if state == State.RESULT:
		state = State.IDLE
		wheel.result = -1
	_refresh()


func can_spin() -> bool:
	return state != State.SPINNING and Roulette.validate(run, bet, selected) == ""


## Juega la apuesta: se decide el resultado primero y la rueda gira para mostrarlo.
func spin() -> Dictionary:
	if state == State.SPINNING:
		return {"ok": false, "error": "La ruleta ya está girando"}
	var err := Roulette.validate(run, bet, selected)
	if err != "":
		result_label.cube = 2.0
		result_label.text = err
		result_label.color = Color(1.0, 0.6, 0.5)
		return {"ok": false, "error": err}
	shown_claridad = run.claridad
	var res := Roulette.resolve(run, bet, selected, rng, forced_pocket)
	resolved.emit()
	_spin_time = 0.0
	_tick_t = 0.0
	state = State.SPINNING
	wheel.result = -1
	wheel.win_t = -1.0
	wheel.spinning = not fast
	_refresh()
	var duration := 0.1 if fast else 3.4
	var turns := 4 if not fast else 1
	# La rueda gira siempre hacia adelante desde donde esté (la rotación de espera cuenta) y termina con la casilla ganadora arriba.
	var base: float = wheel.angle_for(res.pocket)
	var target: float = base + TAU * floorf((wheel.rotation_angle - base) / TAU) - TAU * turns
	var tw := create_tween()
	_spin_tween = tw
	if not fast:   # antes de arrancar, la rueda se echa un poco hacia atrás (como tomar impulso)
		tw.tween_property(wheel, "rotation_angle", wheel.rotation_angle + 0.28, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(wheel, "rotation_angle", target, duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	await tw.finished
	wheel.rotation_angle = target
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


## El cartel de resultado sobre la ruleta: ganaste o perdiste, cuánta claridad y, si el premio es un ítem, cuál.
func _show_overlay(res: Dictionary) -> void:
	if fast:
		return
	var delta := -int(res.price)
	var item_id := ""
	var item_name := ""
	if res.won:
		var prize: Dictionary = res.prize
		if prize.type == Items.Type.CLARITY:
			delta = int(round(prize.mult * res.price))
		elif res.converted:
			delta = int(round(Items.value_of(prize, res.price) * 0.5))
		else:
			delta = 0
			item_id = str(prize.id)
			item_name = Loc.t(str(prize.name))
	var extra := int(res.get("rules", {}).get("total", 0))
	if res.won and extra > 0:
		delta += extra
	elif not res.won and extra > 0:
		delta += extra   # (el fiado devuelve parte de lo perdido)
	overlay.show_result(res.won, delta, item_id, item_name, RuleUI.notes(res))


## Con el mando: A gira, X pone o saca la ficha de la casilla marcada, la cruceta (o el stick) mueve la marca, LB y RB cambian el tipo de apuesta, Y abre los premios, LT rota la vitrina y B sale.
func _pad_key(code: int) -> bool:
	if overlay.showing:
		return false
	var n := Roulette.POCKETS - 1   # las casillas 1 a 12 (la 0 es de la casa)
	match code:
		KEY_ENTER, KEY_KP_ENTER:
			if state == State.SPINNING:
				skip_spin()
			elif can_spin():
				spin()
			else:
				spin()   # (muestra por qué no se puede: "elegí N casillas")
			return true
		KEY_SPACE:
			toggle_pocket(pad_cursor)
			return true
		KEY_LEFT, KEY_UP:
			pad_cursor = posmod(pad_cursor - 2, n) + 1
			return true
		KEY_RIGHT, KEY_DOWN:
			pad_cursor = posmod(pad_cursor, n) + 1
			return true
		KEY_Q, KEY_E:
			var ids: Array = Roulette.BETS.keys()
			var i := ids.find(bet)
			select_bet(ids[posmod(i + (1 if code == KEY_E else -1), ids.size())])
			return true
		KEY_C:
			open_prizes()
			return true
		KEY_SHIFT:
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
		spin()   # con la misma apuesta de antes
	get_viewport().set_input_as_handled()


## Efectos al caer la bola: la bola rebota, parpadea la casilla, destello dorado si ganaste o temblor si ganó la casa,
## y la claridad sube (o baja) contando hasta su valor final.
func _result_effects(res: Dictionary) -> void:
	if not fast:
		wheel.ball_hop()
		wheel.win_t = 0.0
	if res.pocket == Roulette.HOUSE:
		wheel.shake_px = 0.0 if fast else 9.0
		_flash(Color(0.45, 0.1, 0.7), 0.3)
	elif res.won:
		_flash(Color(1.0, 0.88, 0.4), 0.3)
		_sparkle(18)
	var from := shown_claridad
	if fast or from == run.claridad:
		shown_claridad = run.claridad
		return
	create_tween().tween_method(func(v: float) -> void:
			shown_claridad = int(round(v))
			claridad_counter.value = shown_claridad, float(from), float(run.claridad), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if run.claridad > from:
		Juice.pop(claridad_counter, 1.3)


## Chispas doradas al ganar en los casinos de nivel alto.
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
	Sfx.play("win" if res.won else "lose")
	if res.won:
		Sfx.play("coin")
	var txt := ""
	var color := Color(1, 1, 1)
	if res.pocket == Roulette.HOUSE:
		txt = Loc.f("Cayó el 0: ganó la casa. Perdiste la ficha (%d).", [res.price])
		color = Color(0.8, 0.6, 1.0)
	elif not res.won:
		txt = Loc.f("Cayó el %d. Perdiste la ficha (%d).", [res.pocket, res.price])
		color = Color(1.0, 0.65, 0.55)
	else:
		var prize: Dictionary = res.prize
		if prize.type == Items.Type.CLARITY:
			txt = Loc.f("¡Cayó el %d! %s: +%d de claridad.", [res.pocket, Loc.t(prize.name), int(round(prize.mult * res.price))])
		elif res.converted:
			txt = Loc.f("¡Cayó el %d! Ganaste %s, pero no hay lugar: se convirtió en %d de claridad.", [res.pocket, Loc.t(prize.name), int(round(Items.value_of(prize, res.price) * 0.5))])
		else:
			txt = Loc.f("¡Cayó el %d! Ganaste %s: %s", [res.pocket, Loc.t(prize.name), Loc.t(prize.desc)])
		color = Color(1.0, 0.9, 0.45)
	result_label.cube = 2.0
	result_label.text = txt + RuleUI.notes(res)
	result_label.color = color
	if not fast:
		Juice.pop(result_label, 1.2)


func _refresh() -> void:
	var price: int = Roulette.run_price(run)
	claridad_counter.value = shown_claridad if state == State.SPINNING else run.claridad
	price_counter.value = price
	for b in bet_buttons:
		bet_buttons[b].button_pressed = (b == bet)
		bet_buttons[b].disabled = state == State.SPINNING
	wheel.covered = selected.duplicate()
	var need: int = Roulette.BETS[bet].count - selected.size()
	spin_button.disabled = not can_spin()
	prizes_button.disabled = state == State.SPINNING
	rotate_button.visible = not run.showcase.is_empty()
	rotate_button.text = Loc.f("Rotar vitrina (%d)", [Showcase.rotate_cost(run)])
	rotate_button.disabled = state == State.SPINNING or not run.can_afford(Showcase.rotate_cost(run))
	if state == State.RESULT:
		return   # queda el mensaje del resultado hasta que se toque otra casilla o apuesta
	result_label.color = Color(0.9, 0.86, 1.0)
	result_label.cube = 3.0
	if state == State.SPINNING:
		result_label.text = ""
	elif need > 0:
		result_label.text = Loc.f("Toca %d casilla%s en la rueda", [need, "" if need == 1 else "s"])
	elif not run.can_afford(price):
		result_label.text = "No alcanza la claridad para la ficha"
	else:
		result_label.text = "Listo: apretá GIRAR"


func _exit_tree() -> void:
	PadHints.free_retired(_retired)
