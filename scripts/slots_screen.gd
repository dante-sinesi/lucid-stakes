extends Control
## Pantalla de la tragamonedas con "retener". Las reglas viven en slots.gd; acá sólo se muestran los rodillos y se elige.
## Flujo: GIRAR (paga la ficha) -> los rodillos frenan de a uno -> se pueden retener los que gustan (teclas 1, 2 y 3) y "Volver a girar" los otros
## por media ficha, o Cobrar lo que hay -> se muestra el pago -> se puede jugar otra vez.
## Uso: crear, add_child, setup(run, rng). Emite `resolved` cuando se cobró o pagó algo (hay que guardar) y `closed` al salir.

const Slots := preload("res://scripts/slots.gd")
const Roulette := preload("res://scripts/roulette.gd")
const Icons := preload("res://scripts/casino_icons.gd")
const UI := preload("res://scripts/menu_ui.gd")
const Draw := preload("res://scripts/voxel_draw.gd")
const ClarityCounter := preload("res://scripts/clarity_counter.gd")
const Loc := preload("res://scripts/loc.gd")
const Sfx := preload("res://scripts/sfx.gd")

signal resolved
signal closed

enum UiState { IDLE, SPINNING, HOLD, DONE }

const STOP_TIMES := [0.7, 1.05, 1.4]   # cuándo frena cada rodillo (s desde que empieza a girar)

var run
var rng: RandomNumberGenerator
var game
var fast := false
var ui_state := UiState.IDLE
var holds: Array[bool] = [false, false, false]

var reel_nodes: Array = []
var hold_buttons: Array = []
var spin_button
var respin_button
var collect_button
var exit_button
var prizes_button
var claridad_counter
var price_counter
var result_label: Control
var prizes_panel: Control
var flash_rect: ColorRect
var _spin_t := 0.0
var _stopped := [false, false, false]
var _tick_t := 0.0
var _respin_mask: Array = [false, false, false]   # qué rodillos giran en la tirada de vuelta
var _pending: Dictionary = {}                      # el resultado ya calculado mientras los rodillos aún giran


func setup(run_state, random: RandomNumberGenerator, quick := false) -> void:
	run = run_state
	rng = random
	fast = quick
	game = Slots.new(run, rng)
	_build()
	_refresh()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.008, 0.035, 0.93)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

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
	prizes_button.pressed.connect(func(): prizes_panel.visible = true)
	top.add_child(prizes_button)
	exit_button = UI.button("Salir", false, 3.0, 16, false)
	exit_button.name = "salir"
	exit_button.pressed.connect(func(): request_close())
	top.add_child(exit_button)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)
	var title := UI.label(col, "Tragamonedas", 5, UI.GOLD)
	title.dance = true

	var reels_row := HBoxContainer.new()
	reels_row.add_theme_constant_override("separation", 26)
	reels_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(reels_row)
	for i in Slots.REELS:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		reels_row.add_child(cell)
		var reel := _Reel.new()
		reel.name = "rodillo_%d" % (i + 1)
		reel.symbol = int(game.reels[i])
		cell.add_child(reel)
		reel_nodes.append(reel)
		var hb := UI.button("Retener", false, 2.5, 38, false)
		hb.name = "retener_%d" % (i + 1)
		hb.pressed.connect(toggle_hold.bind(i))
		cell.add_child(hb)
		hold_buttons.append(hb)

	result_label = UI.label(col, "", 2.5, Color(0.9, 0.86, 1.0), true, 880)
	result_label.custom_minimum_size = Vector2(900, 64)
	result_label.vcenter = true
	result_label.align = UI.VoxelLabel.Align.CENTER

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 18)
	col.add_child(btn_row)
	spin_button = UI.button("GIRAR", true, 3.5, 50)
	spin_button.name = "girar"
	spin_button.pressed.connect(func(): spin())
	btn_row.add_child(spin_button)
	respin_button = UI.button("Volver a girar", false, 3.0, 60, false)
	respin_button.name = "volver_a_girar"
	respin_button.pressed.connect(func(): respin())
	btn_row.add_child(respin_button)
	collect_button = UI.button("Cobrar", false, 3.0, 36, false)
	collect_button.name = "cobrar"
	collect_button.pressed.connect(func(): collect())
	btn_row.add_child(collect_button)
	var price_box := HBoxContainer.new()
	price_box.alignment = BoxContainer.ALIGNMENT_CENTER
	price_box.add_theme_constant_override("separation", 10)
	col.add_child(price_box)
	UI.label(price_box, "Ficha", 3, Color(0.85, 0.8, 1.0), false)
	price_counter = ClarityCounter.new(3.0)
	price_counter.name = "ficha"
	price_box.add_child(price_counter)

	_build_prizes_panel()
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	add_child(flash_rect)


## La tabla de pagos: cada símbolo con lo que paga por dos y por tres iguales.
func _build_prizes_panel() -> void:
	prizes_panel = Control.new()
	prizes_panel.name = "premios_panel"
	prizes_panel.visible = false
	prizes_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.97)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prizes_panel.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prizes_panel.add_child(c)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	c.add_child(box)
	UI.label(box, "Premios", 5, UI.GOLD)
	UI.label(box, "Pagos en múltiplos de la ficha. Dos iguales pagan poco; tres, mucho. Tres coronas dan además un boost épico.", 2, Color(0.85, 0.8, 1.0), true, 880)
	for s in range(Slots.SYMBOLS.size() - 1, -1, -1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(row)
		var icon := _Icon.new()
		icon.symbol = s
		row.add_child(icon)
		var txt := UI.label(row, Loc.f("Tres: ×%s   Dos: ×%s", [_fmt(Slots.TRIPLE[s]), _fmt(Slots.PAIR[s])]), 3, Draw.MARBLE, false)
		txt.custom_minimum_size = Vector2(520, 0)
		txt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var back := UI.button("Volver", true)
	back.name = "cerrar_premios"
	back.pressed.connect(func(): prizes_panel.visible = false)
	box.add_child(back)
	add_child(prizes_panel)


static func _fmt(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, round(x)) else ("%.1f" % x).replace(".", ",")


func _process(delta: float) -> void:
	if ui_state != UiState.SPINNING or fast:
		return
	_spin_t += delta
	_tick_t += delta
	if _tick_t >= 0.07:
		_tick_t = 0.0
		Sfx.play("reel_tick", 1.0 + randf() * 0.3)
	for i in Slots.REELS:
		if _respin_mask[i] and not _stopped[i] and _spin_t >= float(STOP_TIMES[i]):
			_stop_reel(i)
	var all_done := true
	for i in Slots.REELS:
		if _respin_mask[i] and not _stopped[i]:
			all_done = false
	if all_done:
		_spin_finished()


func _stop_reel(i: int) -> void:
	_stopped[i] = true
	reel_nodes[i].stop(int(game.reels[i]))
	Sfx.play("reel_stop")


# --- interacción -------------------------------------------------------------------------------------------------------

func can_spin() -> bool:
	return ui_state == UiState.IDLE or ui_state == UiState.DONE


## Paga la ficha y gira los tres rodillos.
func spin() -> void:
	if not can_spin():
		return
	var res: Dictionary = game.start()
	if not res.ok:
		_say(res.error, Color(1.0, 0.6, 0.5))
		return
	resolved.emit()
	holds = [false, false, false]
	_say("", Color.WHITE)
	_begin_spin([true, true, true])
	_refresh()


func toggle_hold(i: int) -> void:
	if ui_state != UiState.HOLD or not game.can_respin():
		return
	holds[i] = not holds[i]
	Sfx.play("chip")
	_refresh()


## Vuelve a girar los que no se retuvieron (media ficha) y paga.
func respin() -> void:
	if ui_state != UiState.HOLD or not game.can_respin():
		return
	var res: Dictionary = game.respin(holds)   # (sin nada retenido se vuelve a girar todo)
	if not res.ok:
		_say(res.error, Color(1.0, 0.6, 0.5))
		return
	resolved.emit()
	_pending = res
	_begin_spin([not holds[0], not holds[1], not holds[2]])
	_refresh()


## Cobra lo que hay (sin volver a girar).
func collect() -> void:
	if ui_state != UiState.HOLD:
		return
	var res: Dictionary = game.collect()
	resolved.emit()
	_finish(res)


func _begin_spin(mask: Array) -> void:
	_respin_mask = mask
	ui_state = UiState.SPINNING
	_spin_t = 0.0
	_tick_t = 0.0
	_stopped = [false, false, false]
	for i in Slots.REELS:
		if mask[i]:
			reel_nodes[i].start()
		else:
			_stopped[i] = true
	if fast:
		for i in Slots.REELS:
			if mask[i]:
				_stop_reel(i)
		_spin_finished()


func _spin_finished() -> void:
	if not _pending.is_empty():   # era el giro de vuelta: ya está pagado
		var res := _pending
		_pending = {}
		_finish(res)
		return
	if game.can_respin():
		ui_state = UiState.HOLD
		var p: Dictionary = Slots.payout(game.reels)
		_say(_describe_now(p), Color(0.9, 0.86, 1.0))
		_refresh()
	else:
		_finish(game.collect())
		resolved.emit()


func _finish(res: Dictionary) -> void:
	ui_state = UiState.DONE
	_show_result(res)
	_refresh()


func _show_result(res: Dictionary) -> void:
	var txt := ""
	var color := Color(1, 1, 1)
	match str(res.kind):
		"none":
			txt = Loc.f("Nada. Perdiste la ficha (%d).", [int(res.spent)])
			color = Color(1.0, 0.65, 0.55)
			Sfx.play("lose")
		"pair":
			txt = Loc.f("Dos %s: +%d de claridad.", [Loc.t(Slots.NAMES[int(res.symbol)]).to_lower(), int(res.claridad)])
			color = Color(0.9, 0.95, 0.6)
			Sfx.play("coin")
		_:
			if int(res.symbol) == Slots.CROWN:
				var item: Dictionary = res.item
				txt = Loc.f("¡JACKPOT! Tres coronas: +%d de claridad y el boost %s.", [int(res.claridad), Loc.t(str(item.get("name", "")))]) if not res.converted \
						else Loc.f("¡JACKPOT! Tres coronas: +%d de claridad (el boost no entraba).", [int(res.claridad)])
				Sfx.play("jackpot")
				_flash()
			else:
				txt = Loc.f("¡Tres %s! +%d de claridad.", [Loc.t(Slots.NAMES[int(res.symbol)]).to_lower(), int(res.claridad)])
				Sfx.play("win")
				_flash()
			color = Color(1.0, 0.9, 0.45)
	_say(txt, color)


func _describe_now(p: Dictionary) -> String:
	if p.kind == "none":
		return Loc.t("Retené los rodillos que quieras y volvé a girar, o cobrá.")
	return Loc.f("Ahora pagaría %d de claridad. Retené los que quieras y volvé a girar, o cobrá.", [int(round(float(p.mult) * Roulette.run_price(run)))])


func _say(text: String, color: Color) -> void:
	result_label.text = text
	result_label.color = color


func _flash() -> void:
	if fast:
		return
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.45, 0.06)
	tw.tween_property(flash_rect, "color:a", 0.0, 0.5)


## Pone todos los textos y botones como corresponde al estado.
func _refresh() -> void:
	claridad_counter.value = run.claridad
	price_counter.value = Roulette.run_price(run)
	var holding := ui_state == UiState.HOLD
	for i in Slots.REELS:
		hold_buttons[i].visible = true
		hold_buttons[i].disabled = not (holding and game.can_respin())
		hold_buttons[i].selected = holds[i]
		hold_buttons[i].set_label(Loc.t("Retenido") if holds[i] else Loc.t("Retener"))
		reel_nodes[i].held = holds[i] and holding
	spin_button.disabled = not can_spin()
	spin_button.set_label(Loc.t("GIRAR") if ui_state != UiState.DONE else Loc.t("Jugar otra vez"))
	respin_button.visible = holding
	respin_button.disabled = not game.can_respin()
	respin_button.set_label(Loc.f("Volver a girar (−%d)", [Slots.respin_price(Roulette.run_price(run))]))
	collect_button.visible = holding
	exit_button.disabled = ui_state == UiState.SPINNING


func request_close() -> void:
	if ui_state == UiState.SPINNING:
		return
	if ui_state == UiState.HOLD:   # salir con una tirada abierta es cobrarla
		game.collect()
		resolved.emit()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if prizes_panel.visible:
		if event.keycode == KEY_ESCAPE:
			prizes_panel.visible = false
			get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_ESCAPE:
			request_close()
		KEY_1, KEY_KP_1:
			toggle_hold(0)
		KEY_2, KEY_KP_2:
			toggle_hold(1)
		KEY_3, KEY_KP_3:
			toggle_hold(2)
		KEY_SPACE:
			if ui_state == UiState.HOLD:
				respin()
			else:
				spin()
		KEY_ENTER, KEY_KP_ENTER:
			if ui_state == UiState.HOLD:
				collect()
			else:
				spin()
		_:
			return
	get_viewport().set_input_as_handled()


## Un rodillo: muestra su símbolo; al girar, los símbolos pasan hacia abajo; al frenar, el elegido rebota y se asienta.
class _Reel extends Control:
	const Icons := preload("res://scripts/casino_icons.gd")
	const Draw := preload("res://scripts/voxel_draw.gd")
	const SIZE := Vector2(190, 210)
	var symbol := 0
	var spinning := false
	var held := false
	var _scroll := 0.0
	var _settle := 1.0   # 0..1 desde que frenó: el símbolo cae y rebota

	func _init() -> void:
		custom_minimum_size = SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func start() -> void:
		spinning = true
		_scroll = randf() * 5.0

	func stop(sym: int) -> void:
		spinning = false
		symbol = sym
		_settle = 0.0

	func _process(delta: float) -> void:
		if spinning:
			_scroll += delta * 14.0
			queue_redraw()
		elif _settle < 1.0:
			_settle = minf(_settle + delta * 3.5, 1.0)
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, SIZE)
		Draw.card(self, r, 6.0, 0, 0.04, 77, held, -1.0)
		var inner := r.grow(-14)
		draw_rect(inner, Color(0.04, 0.02, 0.09))
		var step := 118.0
		var icon := 96.0
		if spinning:
			var frac := fmod(_scroll, 1.0)
			var base := int(floor(_scroll))
			for k in range(-1, 2):
				var sym := posmod(base - k, 5)
				var cy := SIZE.y * 0.5 + (frac + float(k)) * step - step * 0.0
				Icons.draw(self, ["cubo", "hielo", "bomba", "sol", "corona"][sym], Vector2(SIZE.x * 0.5, cy), icon, Color(1, 1, 1, 0.9))
			# las franjas de arriba y abajo tapan lo que sale de la ventana
			draw_rect(Rect2(inner.position.x, r.position.y, inner.size.x, inner.position.y - r.position.y), Color(0.13, 0.07, 0.22))
			draw_rect(Rect2(inner.position.x, inner.end.y, inner.size.x, r.end.y - inner.end.y), Color(0.13, 0.07, 0.22))
		else:
			var drop := (1.0 - _settle)
			var bounce := -sin(drop * PI) * 10.0 * drop
			Icons.draw(self, ["cubo", "hielo", "bomba", "sol", "corona"][symbol], Vector2(SIZE.x * 0.5, SIZE.y * 0.5 - drop * 40.0 + bounce), icon)


## Un ícono suelto (para la tabla de premios).
class _Icon extends Control:
	const Icons := preload("res://scripts/casino_icons.gd")
	var symbol := 0

	func _init() -> void:
		custom_minimum_size = Vector2(54, 54)

	func _draw() -> void:
		Icons.draw(self, ["cubo", "hielo", "bomba", "sol", "corona"][symbol], size * 0.5, 54.0)
