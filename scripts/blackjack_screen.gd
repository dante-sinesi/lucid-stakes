extends Control
## Pantalla del blackjack. Las reglas viven en blackjack.gd; acá se reparten las cartas con animación y se elige Pedir, Plantarse o Doblar.
## Teclas: Espacio = Pedir (o Repartir), Enter = Plantarse (o Repartir), D = Doblar, Esc = salir.
## Uso: crear, add_child, setup(run, rng). Emite `resolved` cuando se pagó o cobró algo (hay que guardar) y `closed` al salir.

const Blackjack := preload("res://scripts/blackjack.gd")
const Roulette := preload("res://scripts/roulette.gd")
const Icons := preload("res://scripts/casino_icons.gd")
const UI := preload("res://scripts/menu_ui.gd")
const Draw := preload("res://scripts/voxel_draw.gd")
const VFont := preload("res://scripts/voxel_font.gd")
const ClarityCounter := preload("res://scripts/clarity_counter.gd")
const Loc := preload("res://scripts/loc.gd")
const RuleUI := preload("res://scripts/casino_rule_ui.gd")
const CasinoTheme := preload("res://scripts/casino_theme.gd")
const Rules := preload("res://scripts/casino_rules.gd")
const Sfx := preload("res://scripts/sfx.gd")
const ResultOverlay := preload("res://scripts/result_overlay.gd")

signal resolved
signal closed

const SUIT_ICONS: Array[String] = ["cubo", "hielo", "bomba", "sol"]
const DEAL_STEP := 0.32   # pausa entre carta y carta

var run
var rng: RandomNumberGenerator
var game
var fast := false
var busy := false

var player_box: HBoxContainer
var dealer_box: HBoxContainer
var player_views: Array = []
var dealer_views: Array = []
var player_total: Control
var dealer_total: Control
var rule_label: Control
var th := CasinoTheme.for_tier(0)    # estética del nivel de casino (casino_theme.gd)
var sparkles: Control
var stake_ui := {}
var message: Control
var bet_counter
var claridad_counter
var deal_button
var hit_button
var stand_button
var double_button
var exit_button
var flash_rect: ColorRect
var overlay                 # el cartel de "¡Ganaste!" / "¡Perdiste!"


func setup(run_state, random: RandomNumberGenerator, quick := false) -> void:
	run = run_state
	rng = random
	fast = quick
	game = Blackjack.new(run, rng)
	th = CasinoTheme.for_run(run)
	_build()
	_refresh()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color((th.felt_edge as Color).darkened(0.75), 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var felt := _Felt.new()   # el paño de la mesa, detrás de las cartas
	felt.th = th
	add_child(felt)
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
	exit_button = UI.button("Salir", false, 3.0, 16, false)
	exit_button.name = "salir"
	exit_button.pressed.connect(func(): request_close())
	top.add_child(exit_button)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	center.add_child(col)
	var title := UI.label(col, "Blackjack", 4, UI.GOLD)
	title.dance = true
	rule_label = RuleUI.make_status(col, 900)

	UI.label(col, "Crupier", 2.5, Color(0.8, 0.76, 0.92))
	dealer_box = HBoxContainer.new()
	dealer_box.add_theme_constant_override("separation", 8)
	dealer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	dealer_box.custom_minimum_size = Vector2(0, 142)
	col.add_child(dealer_box)
	dealer_total = UI.label(col, "", 2.5, Draw.MARBLE)
	dealer_total.name = "total_crupier"

	message = UI.label(col, "", 3, Color(0.9, 0.86, 1.0), true, 880)
	message.custom_minimum_size = Vector2(900, 54)
	message.vcenter = true
	message.align = UI.VoxelLabel.Align.CENTER

	UI.label(col, "Vos", 2.5, Color(0.8, 0.76, 0.92))
	player_box = HBoxContainer.new()
	player_box.add_theme_constant_override("separation", 8)
	player_box.alignment = BoxContainer.ALIGNMENT_CENTER
	player_box.custom_minimum_size = Vector2(0, 142)
	col.add_child(player_box)
	player_total = UI.label(col, "", 2.5, Draw.MARBLE)
	player_total.name = "total_jugador"

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	deal_button = UI.button("Repartir", true, 3.0, 40)
	deal_button.name = "repartir"
	deal_button.pressed.connect(func(): deal())
	row.add_child(deal_button)
	hit_button = UI.button("Pedir", false, 3.0, 28, false)
	hit_button.name = "pedir"
	hit_button.pressed.connect(func(): hit())
	row.add_child(hit_button)
	stand_button = UI.button("Plantarse", false, 3.0, 36, false)
	stand_button.name = "plantarse"
	stand_button.pressed.connect(func(): stand())
	row.add_child(stand_button)
	double_button = UI.button("Doblar", false, 3.0, 30, false)
	double_button.name = "doblar"
	double_button.pressed.connect(func(): double_down())
	row.add_child(double_button)
	var bet_row := HBoxContainer.new()
	bet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bet_row.add_theme_constant_override("separation", 10)
	col.add_child(bet_row)
	UI.label(bet_row, "Apuesta", 3, Color(0.85, 0.8, 1.0), false)
	bet_counter = ClarityCounter.new(3.0)
	bet_counter.name = "apuesta"
	bet_row.add_child(bet_counter)
	stake_ui = RuleUI.make_stake_row(col, run, _refresh)

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	add_child(flash_rect)
	overlay = ResultOverlay.new()
	add_child(overlay)


func _wait(seconds: float) -> void:
	if not fast and is_inside_tree():
		await get_tree().create_timer(seconds).timeout


# --- jugadas -------------------------------------------------------------------------------------------------------------

func can_deal() -> bool:
	return not busy and game.phase != Blackjack.Phase.PLAYER


func can_act() -> bool:
	return not busy and game.phase == Blackjack.Phase.PLAYER


func deal() -> void:
	if not can_deal():
		return
	var res: Dictionary = game.deal()
	if not res.ok:
		_say(res.error, Color(1.0, 0.6, 0.5))
		return
	resolved.emit()
	busy = true
	_clear_hands()
	_say("", Color.WHITE)
	_refresh()
	await _add_card(player_box, player_views, game.player[0], true)
	await _add_card(dealer_box, dealer_views, game.dealer[0], true)
	await _add_card(player_box, player_views, game.player[1], true)
	await _add_card(dealer_box, dealer_views, game.dealer[1], not game.hole_hidden)
	busy = false
	if game.phase == Blackjack.Phase.DONE:   # blackjack (de alguno) o empate de entrada
		await _reveal_end()
	_refresh()


func hit() -> void:
	if not can_act():
		return
	busy = true
	game.hit()
	_refresh()
	await _add_card(player_box, player_views, game.player.back(), true)
	busy = false
	if game.phase == Blackjack.Phase.DONE:
		await _reveal_end()
	_refresh()


func stand() -> void:
	if not can_act():
		return
	busy = true
	game.stand()
	resolved.emit()
	await _reveal_end()
	_refresh()


func double_down() -> void:
	if not can_act() or not game.can_double():
		return
	busy = true
	game.double_down()
	resolved.emit()
	_refresh()
	Sfx.play("chip")
	await _add_card(player_box, player_views, game.player.back(), true)
	await _reveal_end()
	_refresh()


## Se da vuelta la carta tapada, el crupier pide lo que le toca y se muestra el resultado.
func _reveal_end() -> void:
	busy = true
	if dealer_views.size() > 1 and not dealer_views[1].face_up:
		dealer_views[1].flip()
		Sfx.play("flip")
		await _wait(0.45)
	_refresh()
	while dealer_views.size() < game.dealer.size():
		await _wait(0.45)
		await _add_card(dealer_box, dealer_views, game.dealer[dealer_views.size()], true)
		_refresh()
	await _wait(0.2)
	busy = false
	resolved.emit()
	_show_result()
	_refresh()


func _show_result() -> void:
	var r: Dictionary = game.result
	var o: int = int(r.outcome)
	var color := Color(1, 1, 1)
	match o:
		Blackjack.Outcome.BLACKJACK:
			color = Color(1.0, 0.9, 0.45)
			Sfx.play("jackpot")
			_flash()
			_sparkle(30)
		Blackjack.Outcome.WIN:
			color = Color(1.0, 0.9, 0.45)
			Sfx.play("win")
			Sfx.play("coin")
			_sparkle(16)
		Blackjack.Outcome.PUSH:
			color = Color(0.85, 0.85, 1.0)
			Sfx.play("chip")
		_:
			color = Color(1.0, 0.65, 0.55)
			Sfx.play("lose")
	var net: int = int(r.net)
	var tail := Loc.f("+%d de claridad.", [net]) if net > 0 else (Loc.f("−%d de claridad.", [-net]) if net < 0 else Loc.t("Sin cambios."))
	_say(Loc.f("%s  %s", [Loc.t(Blackjack.outcome_text(o)), tail]) + RuleUI.notes(r), color)
	if not fast:   # el cartel de resultado sobre la mesa (se saltea con Espacio)
		var won: bool = o == Blackjack.Outcome.WIN or o == Blackjack.Outcome.BLACKJACK
		overlay.show_result(won, net, "", "", RuleUI.notes(r), o == Blackjack.Outcome.PUSH)


func _say(text: String, color: Color) -> void:
	message.text = text
	message.color = color


## Chispas doradas sobre la mesa al ganar (casinos de nivel alto).
func _sparkle(count: int) -> void:
	if fast or int(th.shine) < 2:
		return
	if sparkles == null:
		sparkles = CasinoTheme.Sparkles.new()
		add_child(sparkles)
	sparkles.burst(size * 0.5, count * (int(th.shine) - 1), [Color(1.0, 0.9, 0.4), Color(1, 1, 0.9), Color(1.0, 0.7, 0.25)], 380.0)


func _flash() -> void:
	if fast:
		return
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.4, 0.06)
	tw.tween_property(flash_rect, "color:a", 0.0, 0.5)


# --- cartas y estado -----------------------------------------------------------------------------------------------------

func _clear_hands() -> void:
	for v in player_views + dealer_views:
		v.queue_free()
	player_views.clear()
	dealer_views.clear()


func _add_card(box: HBoxContainer, views: Array, card: Vector2i, face_up: bool) -> void:
	var v := _CardView.new()
	v.card = card
	v.th = th
	v.face_up = face_up
	v.instant = fast
	box.add_child(v)
	views.append(v)
	Sfx.play("card", 0.9 + randf() * 0.25)
	_refresh_totals()
	await _wait(DEAL_STEP)


func _refresh_totals() -> void:
	var pv: Dictionary = Blackjack.value(game.player.slice(0, player_views.size()))
	player_total.text = (Loc.f("%d (blando)", [pv.total]) if pv.soft and pv.total < 21 else str(pv.total)) if not player_views.is_empty() else ""
	var shown: Array = []
	for i in dealer_views.size():
		if dealer_views[i].face_up:
			shown.append(game.dealer[i])
	var dv: Dictionary = Blackjack.value(shown)
	var hidden := dealer_views.size() > shown.size()
	dealer_total.text = ("" if shown.is_empty() else (str(dv.total) + ("  + ?" if hidden else "")))


func _refresh() -> void:
	claridad_counter.value = run.claridad
	var showing_bet: bool = game.bet > 0 and game.phase != Blackjack.Phase.IDLE
	bet_counter.value = game.bet if showing_bet else Roulette.run_price(run) * Rules.stake(run)
	RuleUI.refresh_stake(stake_ui, run, can_deal())
	deal_button.visible = game.phase != Blackjack.Phase.PLAYER
	deal_button.disabled = not can_deal()
	deal_button.set_label(Loc.t("Repartir") if game.phase == Blackjack.Phase.IDLE else Loc.t("Otra mano"))
	var acting: bool = game.phase == Blackjack.Phase.PLAYER
	hit_button.visible = acting
	stand_button.visible = acting
	double_button.visible = acting
	hit_button.disabled = not can_act()
	stand_button.disabled = not can_act()
	double_button.disabled = not (can_act() and game.can_double())
	double_button.set_label(Loc.f("Doblar (−%d)", [game.bet]))
	exit_button.disabled = busy
	_refresh_totals()


func request_close() -> void:
	if busy:
		return
	if game.phase == Blackjack.Phase.PLAYER:   # salir con una mano abierta es plantarse: se juega y se cobra
		game.stand()
		resolved.emit()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if overlay.showing and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		return   # (el cartel de resultado lo maneja él: Espacio lo saltea; no se salta nada más)
	match event.keycode:
		KEY_ESCAPE:
			request_close()
		KEY_SPACE:
			if can_deal():
				deal()
			else:
				hit()
		KEY_ENTER, KEY_KP_ENTER:
			if can_deal():
				deal()
			else:
				stand()
		KEY_D, KEY_C:
			double_down()
		_:
			return
	get_viewport().set_input_as_handled()


## Una carta: boca arriba (rango y palo) o boca abajo (el reverso con el patrón de cubos); entra deslizándose y se da vuelta con un giro.
class _CardView extends Control:
	const Icons := preload("res://scripts/casino_icons.gd")
	const VFont := preload("res://scripts/voxel_font.gd")
	const Draw := preload("res://scripts/voxel_draw.gd")
	const SIZE := Vector2(96, 134)
	var card := Vector2i(1, 0)
	var th := CasinoTheme.for_tier(0)
	var _t := randf() * 3.0
	var face_up := true
	var instant := false
	var _appear := 0.0
	var _flip := 1.0   # 1 = quieto; de 0 a 1 mientras se da vuelta

	func _init() -> void:
		custom_minimum_size = SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		if instant:
			_appear = 1.0
		pivot_offset = SIZE * 0.5

	func flip() -> void:
		face_up = true
		_flip = 0.0 if not instant else 1.0

	func _process(delta: float) -> void:
		_t += delta
		if _appear < 1.0:
			_appear = minf(_appear + delta * 4.5, 1.0)
		if _flip < 1.0:
			_flip = minf(_flip + delta * 5.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var e := 1.0 - pow(1.0 - _appear, 2.0)
		var sx := maxf(_flip, 0.06)   # al darse vuelta la carta se angosta y se vuelve a abrir
		draw_set_transform(Vector2(SIZE.x * 0.5 * (1.0 - sx), (1.0 - e) * -60.0), 0.0, Vector2(sx, 1.0))
		modulate.a = e
		var r := Rect2(Vector2.ZERO, SIZE)
		var orn: int = th.ornament
		var trim: Color = th.trim
		if face_up:
			draw_rect(r, th.card)
			draw_rect(r.grow(-3), th.card_in)
			if float(th.corruption) >= 0.4:   # taberna: cartas manoseadas, con alguna mancha y un borde mordido
				for k in 5:
					var nx := Draw.noise(card.x * 7 + k, card.y * 5, 21)
					var ny := Draw.noise(card.x * 3 + k, card.y * 11, 33)
					draw_rect(Rect2(Vector2(6.0 + nx * (SIZE.x - 18.0), 6.0 + ny * (SIZE.y - 18.0)), Vector2(5, 4)), Color(0.55, 0.42, 0.25, 0.28))
				draw_rect(Rect2(Vector2(SIZE.x - 9, 0), Vector2(9, 5)), Color(0.04, 0.02, 0.07, 0.9))
			var rank: String = ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"][card.x]
			var l: Dictionary = VFont.layout([rank])
			var col := Color(0.15, 0.08, 0.25) if card.y % 2 == 0 else Color(0.7, 0.12, 0.12)
			Draw.text_cells(self, Vector2(10, 8), l.cells, l.size.y, 3.0, col, 0.0, card.x, false)
			Icons.draw(self, ["cubo", "hielo", "bomba", "sol"][card.y], Vector2(SIZE.x * 0.5, SIZE.y * 0.58), 52.0)
			Icons.draw(self, ["cubo", "hielo", "bomba", "sol"][card.y], Vector2(SIZE.x - 17, SIZE.y - 17), 18.0)
			if orn >= 3:   # filete interior dorado y rombitos en las esquinas
				draw_rect(r.grow(-6), Color(trim, 0.85), false, 1.0)
				for p in [Vector2(11, SIZE.y - 11), Vector2(SIZE.x - 11, 11)]:
					draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4), p + Vector2(4, 0), p + Vector2(0, 4), p + Vector2(-4, 0)]), trim)
			if int(th.shine) >= 3:   # un brillo cruza la carta de vez en cuando
				var sw := CasinoTheme.sweep(_t, 3.2)
				if sw > 0.0 and sw < 1.0:
					var x := sw * (SIZE.x + 20.0) - 10.0
					draw_colored_polygon(PackedVector2Array([Vector2(maxf(x - 10, 0), SIZE.y), Vector2(clampf(x + 2, 0, SIZE.x), SIZE.y), Vector2(clampf(x + 22, 0, SIZE.x), 0), Vector2(clampf(x + 10, 0, SIZE.x), 0)]), Color(1, 1, 1, 0.22))
		else:
			draw_rect(r, th.card)
			draw_rect(r.grow(-6), th.back)
			for y in 7:
				for x in 5:
					if (x + y) % 2 == 0:
						var dot: Color = th.back_dot
						if orn >= 2:   # en los niveles altos el damero es de rombos dorados
							var c := Vector2(14 + x * 14 + 6, 14 + y * 15 + 6)
							draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)]), dot)
						else:
							draw_rect(Rect2(Vector2(14 + x * 14, 14 + y * 15), Vector2(12, 12)), dot)
			if orn >= 1:
				draw_rect(r.grow(-6), Color(trim, 0.9), false, 2.0 if orn >= 2 else 1.0)
			if orn >= 3:
				draw_rect(r.grow(-11), Color(trim, 0.6), false, 1.0)
		draw_rect(r, th.card_edge, false, 3.0 if orn >= 3 else 2.0)
		if orn >= 2 and face_up:   # esquinas con una tachuela dorada
			for p in [Vector2(3, 3), Vector2(SIZE.x - 6, 3), Vector2(3, SIZE.y - 6), Vector2(SIZE.x - 6, SIZE.y - 6)]:
				draw_rect(Rect2(p, Vector2(3, 3)), trim)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## El paño de la mesa de blackjack, detrás de las cartas: verde manchado y gastado en la taberna, cada vez más limpio, hasta esmeralda con filete y
## guarda dorada y un brillo que lo cruza en el gran casino.
class _Felt extends Control:
	const Draw := preload("res://scripts/voxel_draw.gd")
	var th := CasinoTheme.for_tier(0)
	var _t := 0.0
	var _frame := -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(delta: float) -> void:
		_t += delta
		if int(th.shine) >= 3:
			var fr := int(_t * 10.0)
			if fr != _frame:
				_frame = fr
				queue_redraw()

	func _draw() -> void:
		var s := 10.0
		var area := Rect2(size * 0.5 - Vector2(560, 320), Vector2(1120, 640)).intersection(Rect2(Vector2(12, 70), size - Vector2(24, 84)))
		var cols := int(area.size.x / s)
		var rows := int(area.size.y / s)
		var o := area.position + (area.size - Vector2(cols, rows) * s) * 0.5
		var felt: Color = th.felt
		draw_rect(Rect2(o, Vector2(cols, rows) * s), felt)
		var corr: float = th.corruption
		if corr > 0.05:   # manchas y quemaduras (sólo en las salas gastadas)
			for y in rows:
				for x in cols:
					var n := Draw.noise(x, y, 91)
					if n < corr * 0.06:
						draw_rect(Rect2(o + Vector2(x, y) * s, Vector2(s, s)), felt.darkened(0.35))
					elif n > 1.0 - corr * 0.006:
						draw_rect(Rect2(o + Vector2(x, y) * s, Vector2(s, s)), Draw.corrupt_color(n))
		var orn: int = th.ornament
		# borde: marco oscuro de madera y, desde el salón, un filete de metal
		for x in cols:
			for y in [0, rows - 1]:
				Draw.cube(self, o + Vector2(x, y) * s, s, th.felt_edge if orn == 0 else (th.trim as Color).darkened(0.2 if orn == 1 else 0.0), true)
		for y in range(1, rows - 1):
			for x in [0, cols - 1]:
				Draw.cube(self, o + Vector2(x, y) * s, s, th.felt_edge if orn == 0 else (th.trim as Color).darkened(0.2 if orn == 1 else 0.0), true)
		if orn >= 3:   # guarda dorada interior y rombos en las esquinas
			var inner := Rect2(o + Vector2(2, 2) * s, Vector2(cols - 4, rows - 4) * s)
			draw_rect(inner, Color(th.trim, 0.7), false, 2.0)
			for p in [inner.position, Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y), inner.end]:
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -9), p + Vector2(9, 0), p + Vector2(0, 9), p + Vector2(-9, 0)]), th.trim)
			var sw := CasinoTheme.sweep(_t, 4.0)
			if sw > 0.0 and sw < 1.0:
				var x := inner.position.x + sw * inner.size.x
				draw_colored_polygon(PackedVector2Array([Vector2(x - 40, inner.end.y), Vector2(x - 10, inner.end.y), Vector2(x + 70, inner.position.y), Vector2(x + 40, inner.position.y)]), Color(1, 1, 1, 0.05))
