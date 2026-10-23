extends Control
## Los dados del tabernero: el minijuego de la pantalla de carga. Mientras se genera la torre, tenés 3 tiros. En cada uno elegís qué cara
## va a salir en cada uno de los 5 dados (clic en un dado: sube; flechas ▲ ▼ o la rueda: cambian; con el teclado, izquierda y derecha eligen
## el dado, arriba y abajo cambian la cara, 1 a 6 la fijan y Enter tira; también se puede con WASD: A y D eligen el dado, W y S cambian la
## cara, y E empieza cuando la torre está lista) y se tiran: caen desde arriba, rebotan y se frenan, y se revelan de a uno.
##   0 aciertos: nada, una frase del tabernero     1: +2 de claridad     2: +8
##   3: +25 de claridad     4: +80     5: +150   (los dados ya no dan Luz ni cosméticos)
## La trampa: con los dados ya revelados, los que fallaron se pueden amañar pagando Luz (2 el primero, 3 el segundo, 4 el tercero...: sube
## con cada uno y vuelve a empezar en cada tiro); con Luz de sobra se pueden comprar los cinco.
## No te saca del juego: jugarlo es obligatorio. Cuando se terminan las tiradas aparece a la derecha el botón "Empezar": gris y con una espiral
## de carga si la torre se sigue generando, listo para apretar si ya está. Al apretarlo se cierra.
## El juego (main.gd) aplica los premios (con un tope de claridad por partida) al recibir la señal `prize`.

const Draw := preload("res://scripts/ui/voxel_draw.gd")
const Profile := preload("res://scripts/datos/profile.gd")
const LuzIcon := preload("res://scripts/ui/luz_icon.gd")
const VFont := preload("res://scripts/ui/voxel_font.gd")
const UI := preload("res://scripts/ui/menu_ui.gd")
const Dice3D := preload("res://scripts/casino/dice_3d.gd")
const GameHelp := preload("res://scripts/ui/game_help.gd")
const PadHints := preload("res://scripts/ui/pad_hints.gd")
const PadGlyph := preload("res://scripts/ui/pad_glyph.gd")
const VoxelLabel := preload("res://scripts/ui/voxel_label.gd")
const ClarityCounter := preload("res://scripts/ui/clarity_counter.gd")
const LuzCounter := preload("res://scripts/ui/luz_counter.gd")
const DialogueBox := preload("res://scripts/ui/dialogue_box.gd")
const Loc := preload("res://scripts/idioma/loc.gd")
const Sfx := preload("res://scripts/sonido/sfx.gd")

signal prize(info: Dictionary)   ## el tiro terminó: {hits, claridad, luz}; quien lo recibe puede agregar `granted` (lo que de verdad se dio) y `cosmetic_name`
signal closed

const THROWS := 3            # tiradas para cumplir la predicción: los dados acertados quedan retenidos y sólo se vuelven a tirar los que fallaron
const DICE := 5
const ROLL_TIME := 1.5       # segundos que ruedan los dados antes de empezar a mostrarse
const REVEAL_STEP := 0.6     # segundos entre un dado y el siguiente
const RESULT_TIME := 1.6     # cuánto se queda el resultado antes del próximo tiro
const SLOT := 150.0          # separación entre dados
const SHIFT := 0.0           # (antes el juego se corría a la izquierda para dejar lugar al botón "Empezar": ahora ocupa todo el ancho y se sigue con Espacio o Enter)

enum Phase { IDLE, PICK, ROLLING, REVEAL, HOLD, RESULT, DONE }   # HOLD: los dados acertados quedan retenidos y se espera la próxima tirada de los que fallaron

## Premios por cantidad de aciertos al terminar las tiradas (una sola predicción y hasta THROWS tiradas para cumplirla).
const PRIZES := {
	0: {"claridad": 0, "luz": 0},
	1: {"claridad": 0, "luz": 0},
	2: {"claridad": 8, "luz": 0},
	3: {"claridad": 25, "luz": 0},
	4: {"claridad": 80, "luz": 0},
	5: {"claridad": 150, "luz": 0},
}

## Lo que dice el tabernero según los aciertos.
const LINES := {
	0: ["Ni uno. La casa agradece.", "Los dados hoy no te quieren, soñador.", "Nada. Pero tiras con estilo."],
	1: ["Uno. Algo es algo.", "Uno solo, pero cuenta.", "Un acierto: se nota que sabes."],
	2: ["¡Dos! Vas bien.", "Dos aciertos. Eso ya es puntería.", "Dos de cinco, nada mal."],
	3: ["¡Tres! Eso es suerte de la buena.", "Tres aciertos, soñador. Me estás asustando.", "¡Tres! La casa empieza a sudar."],
	4: ["¡CUATRO! Esto no pasa seguido.", "Cuatro... ¡y no es poca cosa!", "¿Cuatro? Estás tocado por la claridad."],
	5: ["¡LOS CINCO! No lo puedo creer...", "Cinco de cinco. Esto va a quedar en la historia de la taberna.", "¡¡Cinco!! Aquí tienes, te lo ganaste."],
}

const PIPS := {
	1: [[0.5, 0.5]],
	2: [[0.27, 0.27], [0.73, 0.73]],
	3: [[0.27, 0.27], [0.5, 0.5], [0.73, 0.73]],
	4: [[0.27, 0.27], [0.27, 0.73], [0.73, 0.27], [0.73, 0.73]],
	5: [[0.27, 0.27], [0.27, 0.73], [0.5, 0.5], [0.73, 0.27], [0.73, 0.73]],
	6: [[0.27, 0.27], [0.27, 0.5], [0.27, 0.73], [0.73, 0.27], [0.73, 0.5], [0.73, 0.73]],
}

var rng := RandomNumberGenerator.new()
var fast := false              # pruebas: el tiro se resuelve al instante
var phase := Phase.IDLE
var picks: Array[int] = [1, 2, 3, 4, 5]
var rolls: Array[int] = [1, 1, 1, 1, 1]
var revealed := 0              # cuántos dados ya se muestran
var throws_left := THROWS
var last_hits := 0
var total_claridad := 0        # lo ganado en esta carga
var total_luz := 0
var message := ""
var status_label: Control
var message_label: Control
var throw_button: Button
var unrevealed: Array[int] = []    # los dados que todavía no se revelaron, en el orden en que se van a mostrar
var reroll_round := false      # se está volviendo a tirar (los dados retenidos siguen a la vista)
var _round_total := 0          # cuántos dados se revelan en esta ronda (el primer tiro: 5)
var _round_done := 0
var _reveal_t := [-99.0, -99.0, -99.0, -99.0, -99.0]   # cuándo se reveló cada dado (para su saltito)
var selected := 0              # dado elegido con el teclado
var closing := false
var paused := false              # el tabernero está hablando encima: los dados no responden hasta que termine
var tower_ready := false       # la torre ya se generó: se puede empezar
var auto_start := false        # pruebas: apenas la torre está lista se cierra solo (sin esperar el botón)
var start_button: Button
var loading_spiral
var prize_info := {}
var _t := 0.0
var _phase_t := 0.0
var showcase                   # las recompensas en grande, al terminar las tiradas
var dice3d                     # los dados en 3D (dice_3d.gd)
var overlay_layer              # lo que se dibuja encima: flechas, números y la predicción


func _init() -> void:
	name = "dados"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	dice3d = Dice3D.new()
	add_child(dice3d)
	overlay_layer = _Overlay.new()
	overlay_layer.game = self
	add_child(overlay_layer)
	var title := VoxelLabel.new()
	title.cube = 4.0
	title.color = UI.GOLD
	title.text = "Dados del tabernero"
	title.align = VoxelLabel.Align.CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 26
	title.dance = true
	title.name = "titulo"
	add_child(title)
	status_label = VoxelLabel.new()
	status_label.cube = 2.0
	status_label.color = Color(0.75, 0.72, 0.9)
	status_label.align = VoxelLabel.Align.CENTER
	status_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status_label.offset_top = 86
	status_label.name = "estado"
	add_child(status_label)
	message_label = VoxelLabel.new()
	message_label.cube = 3.0
	message_label.color = Color(0.97, 0.95, 0.9)
	message_label.align = VoxelLabel.Align.CENTER
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	message_label.offset_top = -176
	message_label.offset_left = -440 - SHIFT
	message_label.offset_right = 440 - SHIFT
	message_label.name = "mensaje"
	add_child(message_label)
	showcase = _Showcase.new()
	add_child(showcase)
	throw_button = UI.button("Tirar", true, 4.0, 22)
	throw_button.name = "tirar"
	throw_button.pressed.connect(_on_main_button)
	var button_row := CenterContainer.new()   # centrado abajo (debajo de los dados)
	button_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	button_row.offset_top = -104
	button_row.offset_bottom = -14
	button_row.offset_left = -SHIFT * 2.0
	button_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 22)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button_row.add_child(buttons)
	buttons.add_child(throw_button)
	add_child(button_row)
	# "Empezar", a la derecha: gris y con una espiral de carga hasta que la torre está lista
	var start_box := CenterContainer.new()
	start_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	start_box.offset_left = -330
	start_box.offset_right = -24
	start_box.offset_top = -50
	start_box.offset_bottom = 50
	start_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(start_box)
	start_button = UI.button("Empezar", true, 3.0, 92)
	start_button.name = "empezar"
	start_button.disabled = true
	start_button.pressed.connect(request_close)
	start_box.add_child(start_button)
	start_box.modulate.a = 0.0   # (ya no se ve: se sigue con Espacio o Enter; el botón queda como estado para las pruebas)
	start_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_button.focus_mode = Control.FOCUS_NONE
	hints = PadHints.attach(self, [], [throw_button])   # la botonera de abajo reemplaza a Tirar (Empezar se queda: es también el indicador de que la torre se está generando)
	hints.offset_left = -SHIFT * 2.0
	var spiral := _Spiral.new()
	spiral.name = "espiral"
	spiral.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	spiral.offset_left = -62
	spiral.offset_right = -18
	spiral.offset_top = -22
	spiral.offset_bottom = 22
	spiral.owner_game = self
	start_button.add_child(spiral)
	loading_spiral = _Spiral.new()   # el indicador de carga que se ve: abajo en el centro, sobre la botonera
	loading_spiral.name = "espiral_visible"
	loading_spiral.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	loading_spiral.offset_left = -22
	loading_spiral.offset_right = 22
	loading_spiral.offset_top = -108
	loading_spiral.offset_bottom = -64
	loading_spiral.owner_game = self
	loading_spiral.only_at_end = true
	add_child(loading_spiral)
	GameHelp.attach(self, "dados")   # la ayuda de los dados: se abre sola la primera vez que se juegan y con H o Select


func is_open() -> bool:
	return visible


## Abre el minijuego: una predicción nueva y 3 tiradas para cumplirla.
func open(random: RandomNumberGenerator = null) -> void:
	if random != null:
		rng = random
	else:
		rng.randomize()
	throws_left = THROWS
	total_claridad = 0
	total_luz = 0
	closing = false
	tower_ready = false
	_reset_round()
	start_button.disabled = true
	start_button.visible = false
	revealed = 0
	last_hits = 0
	picks = [1 + rng.randi() % 6, 1 + rng.randi() % 6, 1 + rng.randi() % 6, 1 + rng.randi() % 6, 1 + rng.randi() % 6]
	selected = 0
	message = ""
	message_label.text = message
	_show_prize({})
	phase = Phase.PICK
	_phase_t = 0.0
	visible = true
	_update_button()


## La torre ya está lista: se habilita "Empezar" (en las pruebas se cierra solo).
func set_ready(ready: bool) -> void:
	tower_ready = ready
	start_button.disabled = not ready
	_update_hints()
	if ready and auto_start:
		request_close()


## Deja la ronda como recién empezada: ningún dado oculto ni retenido.
func _reset_round() -> void:
	unrevealed.clear()
	reroll_round = false
	_round_total = 0
	_round_done = 0
	_reveal_t = [-99.0, -99.0, -99.0, -99.0, -99.0]


## Pide cerrar: si hay un tiro en curso se espera a que termine (unos segundos como mucho); si no, se cierra enseguida.
func request_close() -> void:
	if not rounds_over():
		return
	closing = true
	if phase == Phase.HOLD:   # si esperaba la próxima tirada, se cobra lo que hay
		_finish_throw()
	_try_close()


## ¿Ya se jugaron las tiradas? Recién entonces aparece "Empezar" y se puede cerrar (en las pruebas, que no esperan el botón, siempre).
func rounds_over() -> bool:
	return phase == Phase.RESULT or phase == Phase.DONE or fast or auto_start


func _try_close() -> void:
	if closing and visible and (phase == Phase.PICK or phase == Phase.RESULT or phase == Phase.DONE or phase == Phase.IDLE):
		visible = false
		phase = Phase.IDLE
		closing = false
		closed.emit()


func set_pick(i: int, v: int) -> void:
	if phase != Phase.PICK or i < 0 or i >= DICE:
		return
	picks[i] = clampi(v, 1, 6)


## Cambia la cara elegida del dado `i` (con vuelta: del 6 al 1 y del 1 al 6).
func cycle_pick(i: int, dir: int) -> void:
	if phase != Phase.PICK or i < 0 or i >= DICE:
		return
	picks[i] = (picks[i] - 1 + dir + 6) % 6 + 1


func can_throw() -> bool:
	return (phase == Phase.PICK or phase == Phase.HOLD) and throws_left > 0


## Tira los dados: la primera vez los 5 y después sólo los que fallaron (los acertados quedan retenidos). Los resultados salen al azar
## y se muestran de a uno.
func throw_dice() -> void:
	if not can_throw():
		return
	var first := phase == Phase.PICK
	throws_left -= 1
	Sfx.play("dice")
	var again: Array[int] = []
	for i in DICE:
		if first or rolls[i] != picks[i]:
			rolls[i] = 1 + rng.randi() % 6
			again.append(i)
	unrevealed = again
	_round_total = again.size()
	_round_done = 0
	reroll_round = not first
	if first:
		revealed = 0
	phase = Phase.ROLLING
	_phase_t = 0.0
	message = ""
	message_label.text = ""
	_show_prize({})
	_update_button()
	if fast:   # (pruebas) se resuelven todas las tiradas de golpe
		unrevealed.clear()
		revealed = DICE
		while hits() < DICE and throws_left > 0:
			throws_left -= 1
			for i in DICE:
				if rolls[i] != picks[i]:
					rolls[i] = 1 + rng.randi() % 6
		_finish_throw()


## Salta la animación del tiro en curso: los dados que faltaban se muestran de golpe y se sigue como si hubiera terminado. Devuelve true si había algo que saltear.
func skip_animation() -> bool:
	if phase != Phase.ROLLING and phase != Phase.REVEAL:
		return false
	for k in unrevealed:
		_reveal_t[k] = _t
		if rolls[k] == picks[k]:
			dice3d.burst(k)
	if not unrevealed.is_empty():
		Sfx.play("ding") if hits() > 0 else Sfx.play("miss")
	unrevealed.clear()
	revealed = DICE
	_round_done = _round_total
	_after_reveal()
	return true


## Cuántos dados salieron como se pidió.
func hits() -> int:
	var n := 0
	for i in DICE:
		if rolls[i] == picks[i]:
			n += 1
	return n


## El premio de un número de aciertos (una copia: se puede modificar).
static func prize_for(n: int) -> Dictionary:
	return (PRIZES[clampi(n, 0, DICE)] as Dictionary).duplicate(true)


## Los dados que fallaron (los que se vuelven a tirar).
func misses() -> Array[int]:
	var out: Array[int] = []
	for i in DICE:
		if rolls[i] != picks[i]:
			out.append(i)
	return out


func _on_main_button() -> void:
	throw_dice()


## Terminó de revelarse la tirada: si hay dados que fallaron y quedan tiradas, los acertados quedan retenidos y se espera la próxima tirada; si no,
## se cobra.
func _after_reveal() -> void:
	revealed = DICE - unrevealed.size()
	if hits() < DICE and throws_left > 0 and not fast and not closing:
		phase = Phase.HOLD
		_phase_t = 0.0
		var m := misses()
		selected = m[0]
		message = Loc.f("Verdes retenidos. Tira los demás: te quedan %d tiradas.", [throws_left]) if throws_left > 1 else Loc.t("Verdes retenidos. Tira los demás: última tirada.")
		message_label.text = message
		_update_button()
	else:
		_finish_throw()


func _finish_throw() -> void:
	var h := hits()
	if h >= DICE:
		Sfx.play("jackpot")
	elif h >= 3:
		Sfx.play("win")
	last_hits = hits()
	prize_info = prize_for(last_hits)
	prize_info["hits"] = last_hits
	prize.emit(prize_info)   # el juego lo aplica y puede completar `granted`
	var granted: int = int(prize_info.get("granted", prize_info.claridad))
	total_claridad += granted
	total_luz += int(prize_info.luz)
	var lines: Array = LINES[last_hits]
	message = lines[rng.randi() % lines.size()]
	message_label.text = message
	_show_prize(prize_info)
	phase = Phase.RESULT
	_phase_t = 0.0
	_update_button()


## Al terminar las tiradas se muestran las recompensas en grande (claridad, Luz y, si salió, el cosmético puesto en el personaje); `{}` las oculta.
func _show_prize(info: Dictionary) -> void:
	if info.is_empty():
		showcase.hide_prize()
	else:
		showcase.show_prize(info)


var hints
var _hint_key := ""


## La botonera según la fase: elegir dado y número, tirar, tirar de nuevo y entrar a la torre (apagado hasta que está lista).
func _update_hints() -> void:
	if hints == null:
		return
	var key := "%d%s%s" % [phase, str(can_throw()), str(tower_ready)]
	if key == _hint_key:
		return
	_hint_key = key
	match phase:
		Phase.PICK:
			hints.set_items([{"name": "DPAD_LR", "key": "← | →", "text": Loc.t("Dado")}, {"name": "DPAD", "key": "↑ | ↓", "text": Loc.t("Número")},
					{"slot": PadGlyph.Slot.SOUTH, "key": "Espacio", "text": Loc.t("Tirar"), "dim": not can_throw(), "call": throw_dice}])
		Phase.HOLD:
			hints.set_items([{"slot": PadGlyph.Slot.SOUTH, "key": "Espacio", "text": Loc.t("Tirar de nuevo"), "dim": not can_throw(), "call": throw_dice}])
		Phase.RESULT, Phase.DONE:
			hints.set_items([{"slot": PadGlyph.Slot.SOUTH, "key": "Espacio", "text": Loc.t("Empezar") if tower_ready else Loc.t("Generando la torre..."), "dim": not tower_ready, "call": func(): if tower_ready: request_close()}])
		_:
			hints.set_items([{"slot": PadGlyph.Slot.SOUTH, "key": "Espacio", "text": Loc.t("Saltear")}])


func _update_button() -> void:
	throw_button.set_label(Loc.t("Tirar de nuevo") if phase == Phase.HOLD else Loc.t("Tirar"))
	throw_button.disabled = not can_throw()
	throw_button.visible = false   # (la botonera de abajo lo reemplaza)
	start_button.visible = phase == Phase.RESULT or phase == Phase.DONE   # "Empezar" aparece cuando se terminaron las tiradas
	_update_hints()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_phase_t += delta
	var panel := _panel_rect()
	dice3d.position = panel.position + Vector2(6, 6)
	dice3d.size = panel.size - Vector2(12, 12)
	match phase:
		Phase.ROLLING:
			if _phase_t >= ROLL_TIME:
				phase = Phase.REVEAL
				_phase_t = 0.0
				revealed = DICE - unrevealed.size()
		Phase.REVEAL:
			var n := mini(int(_phase_t / REVEAL_STEP), _round_total)
			while _round_done < n and not unrevealed.is_empty():
				var k: int = unrevealed.pop_front()   # cada dado que se da vuelta suena: acierto o fallo
				revealed += 1
				_round_done += 1
				_reveal_t[k] = _t
				if rolls[k] == picks[k]:
					dice3d.burst(k)
				Sfx.play("ding", 1.0 + 0.12 * _round_done) if rolls[k] == picks[k] else Sfx.play("miss")
			if unrevealed.is_empty() and _phase_t >= REVEAL_STEP * (_round_total + 0.4):
				_after_reveal()
		Phase.RESULT:
			if _phase_t >= RESULT_TIME:
				phase = Phase.DONE
				message = "Se acabaron las tiradas. ¡Gracias por jugar!"
				message_label.text = message
				_phase_t = 0.0
				_update_button()
		_:
			pass
	_try_close()
	dice3d.update(self, delta)
	if showcase.visible:
		showcase.layout()
	overlay_layer.queue_redraw()
	queue_redraw()


# --- entrada ---------------------------------------------------------------------------------------------------------

func _slot_center(i: int) -> Vector2:
	if dice3d == null:
		return Vector2(size.x * 0.5 + (i - 2) * 200.0, size.y * 0.5 - 20.0)
	return dice3d.position + dice3d.slot_screen_pos(i)


## Qué dado (y qué parte: 1 = arriba, 0 = el dado, -1 = abajo) está bajo un punto.
func _hit_test(p: Vector2) -> Vector2i:
	for i in DICE:
		var c := _slot_center(i)
		if Rect2(c + Vector2(-46, -100), Vector2(92, 40)).has_point(p):
			return Vector2i(i, 1)
		if Rect2(c + Vector2(-46, 64), Vector2(92, 40)).has_point(p):
			return Vector2i(i, -1)
		if Rect2(c + Vector2(-56, -58), Vector2(112, 120)).has_point(p):
			return Vector2i(i, 0)
	return Vector2i(-1, 0)


func _gui_input(event: InputEvent) -> void:
	if paused or phase != Phase.PICK or not (event is InputEventMouseButton) or not event.pressed:
		return
	var hit := _hit_test(event.position)
	if hit.x < 0:
		return
	selected = hit.x
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			cycle_pick(hit.x, -1 if hit.y < 0 else 1)
			accept_event()
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_DOWN:
			cycle_pick(hit.x, -1)
			accept_event()
		MOUSE_BUTTON_WHEEL_UP:
			cycle_pick(hit.x, 1)
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if paused or not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var go: bool = event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER
	if go and (phase == Phase.ROLLING or phase == Phase.REVEAL):   # Espacio durante la animación: se saltea (se ven los resultados; para entrar a la torre hay que apretar otra vez)
		skip_animation()
		get_viewport().set_input_as_handled()
		return
	if go and (phase == Phase.RESULT or phase == Phase.DONE) and tower_ready:   # terminadas las tiradas, Espacio entra a la torre
		request_close()
		get_viewport().set_input_as_handled()
		return
	if phase == Phase.HOLD:   # esperando la próxima tirada: Enter o Espacio tiran los dados que fallaron
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				throw_dice()
			_:
				return
		get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_LEFT, KEY_A:
			if phase == Phase.PICK:
				selected = (selected + DICE - 1) % DICE
		KEY_RIGHT, KEY_D:
			if phase == Phase.PICK:
				selected = (selected + 1) % DICE
		KEY_UP, KEY_W:
			cycle_pick(selected, 1)
		KEY_DOWN, KEY_S:
			cycle_pick(selected, -1)
		KEY_E:
			if tower_ready and start_button.visible:
				request_close()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			set_pick(selected, event.keycode - KEY_0)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			throw_dice()
		_:
			return
	get_viewport().set_input_as_handled()


# --- dibujo ------------------------------------------------------------------------------------------------------------

func _panel_rect() -> Rect2:
	return Rect2(Vector2(60.0, 126.0), Vector2(size.x - 120.0, size.y - 126.0 - 206.0))


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.025, 0.08, 1.0))   # el fondo se dibuja acá: un hijo taparía los dados
	var panel := _panel_rect()
	Draw.card(self, panel, 6.0, 0, 0.1, 777, false, -1.0)


## La cara del tabernero (la del cuadro de diálogo), arriba a la izquierda del panel.
func _draw_face(ci: CanvasItem, origin: Vector2) -> void:
	var s := 5.0
	for y in DialogueBox.FACE.size():
		var row: String = DialogueBox.FACE[y]
		for x in row.length():
			if row[x] == ".":
				continue
			ci.draw_rect(Rect2(origin + Vector2(x, y) * s, Vector2(s, s)), DialogueBox.FACE_PAL.get(row[x], Color.MAGENTA))


## Los tiros que quedan: tres cubitos dorados (los gastados, apagados).
func _draw_throws(ci: CanvasItem, origin: Vector2) -> void:
	for i in THROWS:
		var col := Draw.GOLD if i < throws_left else Color(0.25, 0.22, 0.3)
		Draw.cube(ci, origin + Vector2(i * 36.0, 0.0), 24.0, col, true)


## Lo que se dibuja encima de los dados 3D: las flechas de elegir, el número pedido y la predicción como un dadito (verde si acertó, rojo si falló).
func _draw_overlay(ci: CanvasItem) -> void:
	var panel := _panel_rect()
	_draw_face(ci, Vector2(panel.position.x + 36.0, panel.position.y + 24.0))
	_draw_throws(ci, Vector2(panel.end.x - 140.0, panel.position.y + 30.0))
	for i in DICE:
		var c := _slot_center(i)
		var picking := phase == Phase.PICK
		var is_revealed := _is_revealed(i)
		var hit := is_revealed and rolls[i] == picks[i]
		if picking:
			var arrow := Color(1.0, 0.85, 0.3) if i == selected else Color(0.6, 0.55, 0.72)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-18, -66), c + Vector2(18, -66), c + Vector2(0, -86)]), arrow)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-18, 70), c + Vector2(18, 70), c + Vector2(0, 90)]), arrow)
		var col := Color(0.9, 0.85, 1.0)
		if is_revealed:
			col = Color(0.6, 1.0, 0.7) if hit else Color(1.0, 0.6, 0.6)
		if picking or phase == Phase.IDLE:   # mientras se elige, el número de la cara pedida
			var l: Dictionary = VFont.layout([str(picks[i])])
			var cs := 4.0
			var tsize := Vector2(l.size) * cs
			Draw.text_cells(ci, c + Vector2(-tsize.x * 0.5, 102.0), l.cells, l.size.y, cs, col, 0.0, i, true)
		else:   # después, la predicción como un dadito debajo, para no olvidar qué se pidió
			var m := 40.0
			var top_left := c + Vector2(-m * 0.5, 96.0)
			ci.draw_rect(Rect2(top_left, Vector2(m, m)), Color(col, 0.28))
			ci.draw_rect(Rect2(top_left, Vector2(m, m)), col, false, 2.0)
			_pips(ci, top_left, Vector2(m, 0), Vector2(0, m), picks[i], col)


## ¿El dado `i` ya muestra su resultado? (los ocultos ruedan; al volver a tirar, los retenidos siguen a la vista)
func _is_revealed(i: int) -> bool:
	if unrevealed.has(i):
		return false
	return phase == Phase.REVEAL or phase == Phase.HOLD or phase == Phase.RESULT or phase == Phase.DONE or (phase == Phase.ROLLING and reroll_round)


## Los puntos de una cara: `origin` es una esquina de la cara y `u`, `v` sus dos ejes.
func _pips(ci: CanvasItem, origin: Vector2, u: Vector2, v: Vector2, value: int, color: Color) -> void:
	for pip in PIPS[clampi(value, 1, 6)]:
		var pc: Vector2 = origin + u * float(pip[0]) + v * float(pip[1])
		var pu := u * 0.15
		var pv := v * 0.15
		ci.draw_colored_polygon(PackedVector2Array([pc - pu - pv, pc + pu - pv, pc + pu + pv, pc - pu + pv]), color)


## La capa que se dibuja encima de los dados 3D.
class _Overlay extends Control:
	var game

	func _init() -> void:
		name = "encima"
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if game != null and game.visible:
			game._draw_overlay(self)


## Espiral de carga: cubitos que van girando en espiral y se apagan; se ve mientras la torre se genera y desaparece cuando está lista.
class _Spiral extends Control:
	var owner_game
	var only_at_end := false   # sólo se ve cuando ya terminaron las tiradas y la torre todavía no está lista
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		visible = owner_game != null and not owner_game.tower_ready and (not only_at_end or owner_game.phase == owner_game.Phase.RESULT or owner_game.phase == owner_game.Phase.DONE)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var n := 14
		for i in n:
			var k := float(i) / float(n)
			var ang := _t * 5.0 + k * TAU * 1.5
			var r := 3.0 + k * 17.0
			var p := c + Vector2(cos(ang), sin(ang)) * r
			var sz := 2.0 + k * 4.0
			draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(0.85, 0.82, 0.95, 0.25 + 0.75 * k))


## Las recompensas de la carga, en grande: una tira debajo de los dados con la claridad y la Luz que se ganaron.
class _Showcase extends Control:
	const UI := preload("res://scripts/ui/menu_ui.gd")
	const Draw := preload("res://scripts/ui/voxel_draw.gd")
	const ClarityCounter := preload("res://scripts/ui/clarity_counter.gd")
	const LuzCounter := preload("res://scripts/ui/luz_counter.gd")
	const Loc := preload("res://scripts/idioma/loc.gd")

	var title: Control
	var row: HBoxContainer
	var clarity
	var luz
	var _card := Rect2()
	var center: CenterContainer
	var col: VBoxContainer

	func _init() -> void:
		name = "recompensas"
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center = CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(center)
		col = VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		center.add_child(col)
		var line := HBoxContainer.new()   # el título y los premios en una sola línea, chica, sobre la mesa
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", 40)
		col.add_child(line)
		title = UI.label(line, "", 4, Draw.GOLD)
		title.name = "titulo"
		row = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 34)
		line.add_child(row)
		clarity = ClarityCounter.new(3.5, Color(1.0, 0.97, 0.8))
		clarity.name = "claridad"
		row.add_child(clarity)
		luz = LuzCounter.new(3.5)
		luz.name = "luz"
		row.add_child(luz)

	## Una tira abajo de la mesa.
	func layout() -> void:
		var panel: Rect2 = get_parent()._panel_rect()
		var area := Rect2(panel.position.x, panel.end.y - 92.0, panel.size.x, 84.0)
		center.position = area.position
		center.size = area.size
		queue_redraw()

	func hide_prize() -> void:
		visible = false

	func show_prize(info: Dictionary) -> void:
		var granted: int = int(info.get("granted", info.get("claridad", 0)))
		var luz_n: int = int(info.get("luz", 0))
		title.text = Loc.t("¡Recompensas!") if granted > 0 or luz_n > 0 else Loc.t("Sin recompensa esta vez")
		clarity.visible = granted > 0
		clarity.value = granted
		luz.visible = luz_n > 0
		luz.value = luz_n
		row.visible = granted > 0 or luz_n > 0
		layout()
		visible = true
