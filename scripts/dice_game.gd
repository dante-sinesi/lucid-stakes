extends Control
## Los dados del tabernero: el minijuego de la pantalla de carga. Mientras se genera la torre, tenés 3 tiros. En cada uno elegís qué cara
## va a salir en cada uno de los 5 dados (clic en un dado: sube; flechas ▲ ▼ o la rueda: cambian; con el teclado, izquierda y derecha eligen
## el dado, arriba y abajo cambian la cara, 1 a 6 la fijan y Enter tira; también se puede con WASD: A y D eligen el dado, W y S cambian la
## cara, y E empieza cuando la torre está lista) y se tiran: caen desde arriba, rebotan y se frenan, y se revelan de a uno.
##   0 aciertos: nada, una frase del tabernero     1: +2 de claridad     2: +8
##   3: +25 de claridad y 1 de Luz                 4: +80, 2 de Luz y un cosmético común (a veces raro)
##   5: +150, 5 de Luz y un cosmético raro (a veces épico)   (1 chance en 7.776 por tiro)
## La trampa: con los dados ya revelados, los que fallaron se pueden amañar pagando Luz (2 el primero, 3 el segundo, 4 el tercero...: sube
## con cada uno y vuelve a empezar en cada tiro); con Luz de sobra se pueden comprar los cinco.
## No te saca del juego: cuando la torre está lista el minijuego se queda y a la derecha se habilita el botón "Empezar" (gris y con una
## espiral de carga mientras se genera); al apretarlo, el tiro en curso termina (unos segundos como mucho) y se cierra.
## El juego (main.gd) aplica los premios (con un tope de claridad por partida) al recibir la señal `prize`.

const Draw := preload("res://scripts/voxel_draw.gd")
const Profile := preload("res://scripts/profile.gd")
const Cosmetics := preload("res://scripts/cosmetics.gd")
const LuzIcon := preload("res://scripts/luz_icon.gd")
const VFont := preload("res://scripts/voxel_font.gd")
const UI := preload("res://scripts/menu_ui.gd")
const VoxelLabel := preload("res://scripts/voxel_label.gd")
const ClarityCounter := preload("res://scripts/clarity_counter.gd")
const LuzCounter := preload("res://scripts/luz_counter.gd")
const DialogueBox := preload("res://scripts/dialogue_box.gd")
const Loc := preload("res://scripts/loc.gd")
const Sfx := preload("res://scripts/sfx.gd")

signal prize(info: Dictionary)   ## el tiro terminó: {hits, claridad, luz, cosmetic}; quien lo recibe puede agregar `granted` (lo que de verdad se dio) y `cosmetic_name`
signal closed

const THROWS := 3
const DICE := 5
const ROLL_TIME := 1.5       # segundos que ruedan los dados antes de empezar a mostrarse
const REVEAL_STEP := 0.6     # segundos entre un dado y el siguiente
const RESULT_TIME := 1.6     # cuánto se queda el resultado antes del próximo tiro
const DIE := 30.0            # lado de un dado, en píxeles
const SLOT := 150.0          # separación entre dados
const SHIFT := 110.0         # el juego se corre a la izquierda para dejar lugar al botón "Empezar" a la derecha

enum Phase { IDLE, PICK, ROLLING, REVEAL, FIX, RESULT, DONE }   # FIX: se pueden retener los dados y volver a tirar los que fallaron

## Premios por cantidad de aciertos.
## `cosmetic`: las probabilidades de cada rareza del cosmético que se da ({} = ninguno).
const PRIZES := {
	0: {"claridad": 0, "luz": 0, "cosmetic": {}},
	1: {"claridad": 2, "luz": 0, "cosmetic": {}},
	2: {"claridad": 8, "luz": 0, "cosmetic": {}},
	3: {"claridad": 25, "luz": 1, "cosmetic": {}},
	4: {"claridad": 80, "luz": 2, "cosmetic": {"comun": 0.85, "raro": 0.15}},
	5: {"claridad": 150, "luz": 5, "cosmetic": {"raro": 0.7, "epico": 0.3}},
}
## Volver a tirar (con Luz): después de ver un tiro, los dados que acertaron quedan retenidos y de los que fallaron se elige cuáles volver a
## tirar; cada dado que se vuelve a tirar cuesta REROLL_COST de Luz y acierta con probabilidad 1/6 (no hay garantía). Hasta MAX_REROLLS veces por tiro.
const REROLL_COST := 1
const MAX_REROLLS := 2

## Lo que dice el tabernero según los aciertos.
const LINES := {
	0: ["Ni uno. La casa agradece.", "Los dados hoy no te quieren, soñador.", "Nada. Pero tirás con estilo."],
	1: ["Uno. Algo es algo.", "Uno solo, pero cuenta.", "Un acierto: se nota que sabés."],
	2: ["¡Dos! Vas bien.", "Dos aciertos. Eso ya es puntería.", "Dos de cinco, nada mal."],
	3: ["¡Tres! Eso es suerte de la buena.", "Tres aciertos, soñador. Me estás asustando.", "¡Tres! La casa empieza a sudar."],
	4: ["¡CUATRO! Esto no pasa seguido.", "Cuatro... ¡y una luz de regalo!", "¿Cuatro? Estás tocado por la claridad."],
	5: ["¡LOS CINCO! No lo puedo creer...", "Cinco de cinco. Esto va a quedar en la historia de la taberna.", "¡¡Cinco!! Acá tenés, te lo ganaste."],
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
var marked: Array[bool] = [false, false, false, false, false]   # los que se van a volver a tirar (sólo entre los que fallaron)
var rerolls_left := 0          # cuántas veces más se puede volver a tirar en este tiro
var reroll_round := false      # se está volviendo a tirar (los dados retenidos siguen a la vista)
var luz_spent := 0             # Luz gastada en volver a tirar en este tiro
var collect_button: Button
var _round_total := 0          # cuántos dados se revelan en esta ronda (el primer tiro: 5)
var _round_done := 0
var _reveal_t := [-99.0, -99.0, -99.0, -99.0, -99.0]   # cuándo se reveló cada dado (para su saltito)
var luz_counter                # la Luz que tenés (para saber si alcanza para volver a tirar)
var selected := 0              # dado elegido con el teclado
var closing := false
var tower_ready := false       # la torre ya se generó: se puede empezar
var auto_start := false        # pruebas: apenas la torre está lista se cierra solo (sin esperar el botón)
var start_button: Button
var prize_info := {}
var _t := 0.0
var _phase_t := 0.0
var _prize_row: HBoxContainer
var _clarity_counter
var _luz_counter
var _cosmetic_label: Control


func _init() -> void:
	name = "dados"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
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
	_prize_row = HBoxContainer.new()
	_prize_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_prize_row.add_theme_constant_override("separation", 30)
	_prize_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prize_row.offset_top = -126
	_prize_row.offset_left = -400 - SHIFT
	_prize_row.offset_right = 400 - SHIFT
	_prize_row.name = "premio"
	add_child(_prize_row)
	_clarity_counter = ClarityCounter.new(3.0, Color(1.0, 0.97, 0.8))
	_clarity_counter.visible = false
	_prize_row.add_child(_clarity_counter)
	_luz_counter = LuzCounter.new(3.0)
	_luz_counter.visible = false
	_prize_row.add_child(_luz_counter)
	_cosmetic_label = UI.label(_prize_row, "", 3, Color(1.0, 0.9, 0.5), false)
	_cosmetic_label.visible = false
	luz_counter = LuzCounter.new(3.0)   # arriba a la derecha del panel: cuánta Luz tenés
	luz_counter.name = "luz"
	luz_counter.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	luz_counter.offset_left = -290
	luz_counter.offset_right = -150
	luz_counter.offset_top = 150
	luz_counter.plate_alpha = 0.5
	add_child(luz_counter)
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
	collect_button = UI.button("Cobrar", false, 3.2, 22)
	collect_button.name = "cobrar"
	collect_button.visible = false
	collect_button.pressed.connect(collect)
	buttons.add_child(collect_button)
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
	var spiral := _Spiral.new()
	spiral.name = "espiral"
	spiral.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	spiral.offset_left = -62
	spiral.offset_right = -18
	spiral.offset_top = -22
	spiral.offset_bottom = 22
	spiral.owner_game = self
	start_button.add_child(spiral)


func is_open() -> bool:
	return visible


func set_status(text: String) -> void:
	status_label.text = text


## Abre el minijuego con 3 tiros nuevos.
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
	luz_counter.value = Profile.luz()
	start_button.disabled = true
	revealed = 0
	last_hits = 0
	picks = [1 + rng.randi() % 6, 1 + rng.randi() % 6, 1 + rng.randi() % 6, 1 + rng.randi() % 6, 1 + rng.randi() % 6]
	selected = 0
	message = "Elegí qué cara va a salir en cada dado."
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
	if ready and auto_start:
		request_close()


## Deja el tiro como recién empezado: nada retenido, ningún dado oculto, todas las re-tiradas disponibles.
func _reset_round() -> void:
	unrevealed.clear()
	marked = [false, false, false, false, false]
	rerolls_left = MAX_REROLLS
	reroll_round = false
	luz_spent = 0
	_round_total = 0
	_round_done = 0
	_reveal_t = [-99.0, -99.0, -99.0, -99.0, -99.0]


## Pide cerrar: si hay un tiro en curso se espera a que termine (unos segundos como mucho); si no, se cierra enseguida.
func request_close() -> void:
	closing = true
	if phase == Phase.FIX:   # si estaba eligiendo qué volver a tirar, se cobra lo que hay
		_finish_throw()
	_try_close()


func _try_close() -> void:
	if closing and visible and (phase == Phase.PICK or phase == Phase.DONE or phase == Phase.IDLE):
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
	return phase == Phase.PICK and throws_left > 0


## Tira los 5 dados. Los resultados salen al azar; se muestran de a uno.
func throw_dice() -> void:
	if not can_throw():
		return
	throws_left -= 1
	Sfx.play("dice")
	for i in DICE:
		rolls[i] = 1 + rng.randi() % 6
	_reset_round()
	unrevealed.assign([0, 1, 2, 3, 4])
	_round_total = DICE
	revealed = 0
	phase = Phase.ROLLING
	_phase_t = 0.0
	message = ""
	message_label.text = ""
	_show_prize({})
	_update_button()
	if fast:
		unrevealed.clear()
		revealed = DICE
		_finish_throw()


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


## Cuánto cuesta volver a tirar los dados marcados.
func reroll_cost() -> int:
	return marks_count() * REROLL_COST


func marks_count() -> int:
	var n := 0
	for m in marked:
		if m:
			n += 1
	return n


## ¿Se puede volver a tirar ahora? (hay una fase de elegir, quedan re-tiradas, hay algo marcado y alcanza la Luz)
func can_reroll() -> bool:
	return phase == Phase.FIX and rerolls_left > 0 and marks_count() > 0 and Profile.luz() >= reroll_cost()


## Los dados que fallaron (los que se pueden volver a tirar).
func misses() -> Array[int]:
	var out: Array[int] = []
	for i in DICE:
		if rolls[i] != picks[i]:
			out.append(i)
	return out


## Marca (o desmarca) un dado que falló para volver a tirarlo; el resto queda retenido. Sólo se marcan los que alcanza la Luz.
func toggle_mark(i: int) -> bool:
	if phase != Phase.FIX or i < 0 or i >= DICE or rolls[i] == picks[i]:
		return false
	if marked[i]:
		marked[i] = false
	elif (marks_count() + 1) * REROLL_COST <= Profile.luz():
		marked[i] = true
	else:
		Sfx.play("miss")
		return false
	Sfx.play("chip")
	_refresh_fix_message()
	_update_button()
	return true


## Vuelve a tirar los dados marcados: paga la Luz y esos dados ruedan de nuevo (los demás quedan quietos). Devuelve false si no se puede.
func reroll() -> bool:
	if not can_reroll():
		return false
	var cost := reroll_cost()
	Profile.add_luz(-cost)
	luz_spent += cost
	luz_counter.value = Profile.luz()
	Sfx.play("coin")
	var again: Array[int] = []
	for i in DICE:
		if marked[i]:
			rolls[i] = 1 + rng.randi() % 6
			again.append(i)
	unrevealed = again
	_round_total = again.size()
	_round_done = 0
	marked = [false, false, false, false, false]
	rerolls_left -= 1
	reroll_round = true
	phase = Phase.ROLLING
	_phase_t = 0.0
	message = ""
	message_label.text = ""
	Sfx.play("dice")
	_update_button()
	return true


func _refresh_fix_message() -> void:
	message = Loc.f("Elegí qué dados volver a tirar (%d Luz cada uno). Quedan %d.", [REROLL_COST, rerolls_left])
	message_label.text = message


## Cobra el tiro tal como quedó.
func collect() -> void:
	if phase == Phase.FIX:
		_finish_throw()


func _on_main_button() -> void:
	if phase == Phase.FIX:
		reroll()
	else:
		throw_dice()


## Terminó de revelarse el tiro: si hay dados que fallaron, quedan re-tiradas y alcanza la Luz, se espera a que decidas (por defecto se marcan
## todos los que fallaron, hasta donde alcance la Luz); si no, se cobra.
func _after_reveal() -> void:
	revealed = DICE - unrevealed.size()
	if hits() < DICE and rerolls_left > 0 and Profile.luz() >= REROLL_COST and not fast:
		phase = Phase.FIX
		_phase_t = 0.0
		var m := misses()
		marked = [false, false, false, false, false]
		var afford := mini(m.size(), Profile.luz() / REROLL_COST)
		for k in afford:
			marked[m[k]] = true
		selected = m[0]
		_refresh_fix_message()
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
	prize_info["luz_spent"] = luz_spent
	prize.emit(prize_info)   # el juego lo aplica y puede completar `granted` y `cosmetic_name`
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


func _show_prize(info: Dictionary) -> void:
	var granted: int = int(info.get("granted", info.get("claridad", 0))) if not info.is_empty() else 0
	_clarity_counter.visible = granted > 0
	_clarity_counter.value = granted
	_luz_counter.visible = int(info.get("luz", 0)) > 0
	_luz_counter.value = int(info.get("luz", 0))
	var cosmetic_name: String = str(info.get("cosmetic_name", ""))
	_cosmetic_label.visible = cosmetic_name != ""
	var rarity: String = str(info.get("cosmetic_rarity", "comun"))
	var rinfo: Dictionary = Cosmetics.RARITIES.get(rarity, Cosmetics.RARITIES.comun)
	_cosmetic_label.text = Loc.f("¡Cosmético %s nuevo: %s!", [Loc.t(str(rinfo.name)).to_lower(), Loc.t(cosmetic_name)]) if cosmetic_name != "" else ""
	_cosmetic_label.color = rinfo.color


func _update_button() -> void:
	var fixing := phase == Phase.FIX
	if fixing:
		throw_button.set_label(Loc.f("Tirar de nuevo (−%d Luz)", [reroll_cost()]) if marks_count() > 0 else Loc.t("Tirar de nuevo"))
	else:
		throw_button.set_label("Tirar")
	throw_button.disabled = not (can_throw() or (fixing and can_reroll()))
	throw_button.visible = throws_left > 0 or phase != Phase.DONE
	collect_button.visible = fixing


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_phase_t += delta
	if luz_counter.value != Profile.luz():
		luz_counter.value = Profile.luz()
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
				Sfx.play("ding", 1.0 + 0.12 * _round_done) if rolls[k] == picks[k] else Sfx.play("miss")
			if unrevealed.is_empty() and _phase_t >= REVEAL_STEP * (_round_total + 0.4):
				_after_reveal()
		Phase.RESULT:
			if _phase_t >= RESULT_TIME:
				if throws_left > 0:
					phase = Phase.PICK
					message = Loc.f("Elegí otra vez. Quedan %d tiro%s.", [throws_left, "" if throws_left == 1 else "s"])
					message_label.text = message
					_show_prize({})
				else:
					phase = Phase.DONE
					message = "Se acabaron los tiros. ¡Gracias por jugar!"
					message_label.text = message
				_phase_t = 0.0
				_update_button()
		_:
			pass
	_try_close()
	queue_redraw()


# --- entrada ---------------------------------------------------------------------------------------------------------

func _slot_center(i: int) -> Vector2:
	return Vector2(size.x * 0.5 - SHIFT + (i - 2) * SLOT, size.y * 0.5 - 20.0)


## Qué dado (y qué parte: 1 = arriba, 0 = el dado, -1 = abajo) está bajo un punto.
func _hit_test(p: Vector2) -> Vector2i:
	for i in DICE:
		var c := _slot_center(i)
		if Rect2(c + Vector2(-38, -92), Vector2(76, 36)).has_point(p):
			return Vector2i(i, 1)
		if Rect2(c + Vector2(-38, 64), Vector2(76, 36)).has_point(p):
			return Vector2i(i, -1)
		if Rect2(c + Vector2(-48, -62), Vector2(96, 124)).has_point(p):
			return Vector2i(i, 0)
	return Vector2i(-1, 0)


func _gui_input(event: InputEvent) -> void:
	if phase == Phase.FIX and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var fix_hit := _hit_test(event.position)
		if fix_hit.x >= 0:
			selected = fix_hit.x
			toggle_mark(fix_hit.x)
			accept_event()
		return
	if phase != Phase.PICK or not (event is InputEventMouseButton) or not event.pressed:
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
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if phase == Phase.FIX:   # volver a tirar: A y D eligen un dado que falló, W o Espacio lo marcan, Enter vuelve a tirar los marcados, C cobra
		var m := misses()
		match event.keycode:
			KEY_LEFT, KEY_A:
				if not m.is_empty():
					selected = m[(maxi(m.find(selected), 0) + m.size() - 1) % m.size()]
			KEY_RIGHT, KEY_D:
				if not m.is_empty():
					selected = m[(maxi(m.find(selected), 0) + 1) % m.size()]
			KEY_UP, KEY_W, KEY_SPACE:
				toggle_mark(selected)
			KEY_ENTER, KEY_KP_ENTER:
				if can_reroll():
					reroll()
				else:
					collect()
			KEY_C:
				collect()
			KEY_E:
				if tower_ready:
					request_close()
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
			if tower_ready:
				request_close()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			set_pick(selected, event.keycode - KEY_0)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			throw_dice()
		_:
			return
	get_viewport().set_input_as_handled()


# --- dibujo ------------------------------------------------------------------------------------------------------------

func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.025, 0.08, 1.0))   # el fondo se dibuja acá: un hijo taparía los dados
	var panel := Rect2(Vector2(size.x * 0.5 - SHIFT - 420.0, 126.0), Vector2(840.0, size.y - 126.0 - 206.0))
	Draw.card(self, panel, 6.0, 0, 0.1, 777, false, -1.0)
	_draw_face(Vector2(panel.position.x + 56.0, panel.position.y + 34.0))
	_draw_throws(Vector2(panel.end.x - 140.0, panel.position.y + 40.0))
	for i in DICE:
		_draw_die(i)


## La cara del tabernero (la del cuadro de diálogo), arriba a la izquierda del panel.
func _draw_face(origin: Vector2) -> void:
	var s := 5.0
	for y in DialogueBox.FACE.size():
		var row: String = DialogueBox.FACE[y]
		for x in row.length():
			if row[x] == ".":
				continue
			draw_rect(Rect2(origin + Vector2(x, y) * s, Vector2(s, s)), DialogueBox.FACE_PAL.get(row[x], Color.MAGENTA))


## Los tiros que quedan: tres cubitos dorados (los gastados, apagados).
func _draw_throws(origin: Vector2) -> void:
	for i in THROWS:
		var col := Draw.GOLD if i < throws_left else Color(0.25, 0.22, 0.3)
		Draw.cube(self, origin + Vector2(i * 36.0, 0.0), 24.0, col, true)


## Color de los dados (todos blancos) y las caras de los costados de cada uno según la de
## arriba: (izquierda, derecha), una orientación real de dado (las caras opuestas suman 7).
const DIE_COLORS := [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]
const SIDES := {1: [2, 3], 2: [3, 1], 3: [1, 2], 4: [2, 1], 5: [1, 3], 6: [3, 2]}
const DROP := 430.0   # desde qué altura (en píxeles) caen los dados


## El movimiento de un dado en el momento actual: {height (px sobre la mesa), squash (0..1, aplastón al pegar), slide (corrimiento
## horizontal), face (la cara que muestra), age (segundos desde que se reveló; -1 si no)}. Cae desde arriba acelerando, pega, rebota
## cada vez menos y se frena; mientras cae gira (cambia de cara cada vez más lento).
func _die_motion(i: int) -> Dictionary:
	var out := {"height": 0.0, "squash": 0.0, "slide": 0.0, "face": picks[i], "age": -1.0}
	var is_revealed := _is_revealed(i)
	if unrevealed.has(i) and (phase == Phase.ROLLING or phase == Phase.REVEAL):
		var t := _phase_t if phase == Phase.ROLLING else ROLL_TIME + _phase_t
		var t_land := 0.55 + 0.09 * i
		var cycle := 0.0
		if t < t_land:
			var k := t / t_land
			out.height = DROP * (1.0 - k * k)
			cycle = 24.0 * t
		else:
			var u := t - t_land
			out.height = absf(sin(u * 10.0)) * 46.0 * exp(-u * 4.2)
			out.squash = 0.22 * exp(-u * 14.0)
			out.slide = (1.0 if i % 2 == 0 else -1.0) * 20.0 * exp(-u * 3.0) * (1.0 - float(i) * 0.1)
			cycle = 24.0 * t_land + 10.0 * (1.0 - exp(-2.5 * u))
		out.face = 1 + int(cycle + float(i) * 3.0) % 6
	elif is_revealed:
		out.face = rolls[i]
		out.age = maxf(_t - float(_reveal_t[i]), 0.0)
		out.height = maxf(0.0, 1.0 - out.age * 3.0) * 16.0
	return out


## Un dado: cubo isométrico blanco, un relieve en cada cara y los puntos en las tres caras que se ven; cae desde arriba,
## rebota y se frena (con su sombra en la mesa); al revelarse salta un poquito y, si acertó, suelta chispas doradas.
func _draw_die(i: int) -> void:
	var c := _slot_center(i)
	var mo := _die_motion(i)
	var picking := phase == Phase.PICK
	var is_revealed := _is_revealed(i)
	var shown: int = mo.face
	var hit := is_revealed and rolls[i] == picks[i]
	var tint := Color(1, 1, 1)
	if is_revealed:
		tint = Color(0.62, 1.0, 0.7) if hit else Color(1.0, 0.62, 0.62)
		if phase == Phase.FIX and not hit and not marked[i]:
			tint = Color(0.72, 0.8, 1.0)   # retenido (no se vuelve a tirar): azulado
	elif picking and i == selected:
		tint = Color(1.0, 0.97, 0.78)
	var squash: float = mo.squash
	var a := Vector2(0.866, 0.5) * DIE * (1.0 + squash * 0.7)
	var b := Vector2(-0.866, 0.5) * DIE * (1.0 + squash * 0.7)
	var h := Vector2(0, -DIE * (1.0 - squash))
	var lift: float = mo.height
	var ground := c + Vector2(mo.slide, 0)
	var o := ground + Vector2(0, -lift) - (a + b + h) * 0.5 + Vector2(0, 8)
	# Sombra en la mesa: más chica y más clara cuanto más alto está
	var near := 1.0 - clampf(lift / DROP, 0.0, 1.0)
	var sw := (46.0 * (0.55 + 0.45 * near))
	draw_colored_polygon(PackedVector2Array([ground + Vector2(-sw, 40), ground + Vector2(sw, 40), ground + Vector2(sw * 0.78, 54), ground + Vector2(-sw * 0.78, 54)]), Color(0, 0, 0, 0.15 + 0.25 * near))
	var base: Color = (DIE_COLORS[i] as Color) * tint
	base.a = 1.0
	var faces := [
		{"poly": [o + a, o + a + b, o + a + b + h, o + a + h], "col": base.darkened(0.12), "origin": o + a + h, "u": b, "v": -h, "value": (SIDES[shown] as Array)[1]},   # derecha
		{"poly": [o + b, o + a + b, o + a + b + h, o + b + h], "col": base.darkened(0.3), "origin": o + b + h, "u": a, "v": -h, "value": (SIDES[shown] as Array)[0]},     # izquierda
		{"poly": [o + h, o + a + h, o + a + b + h, o + b + h], "col": base, "origin": o + h, "u": a, "v": b, "value": shown},                                          # arriba
	]
	for f in faces:
		var pts: Array = f.poly
		draw_colored_polygon(PackedVector2Array(pts), f.col)
		draw_colored_polygon(_inset(pts, 0.8), (f.col as Color).lightened(0.07))   # el relieve de cada cara (se ve redondeado)
		_pips(f.origin, f.u, f.v, int(f.value), Color(0.17, 0.1, 0.22))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), (f.col as Color).darkened(0.25), 1.5)
	# Chispas doradas del acierto
	if hit and mo.age >= 0.0 and mo.age < 0.8:
		for k in 7:
			var ang := float(k) / 7.0 * TAU + float(i)
			var d: float = 24.0 + float(mo.age) * 70.0
			var sp := Vector2(cos(ang) * d, sin(ang) * d * 0.7 - 14.0)
			var al: float = 1.0 - float(mo.age) / 0.8
			draw_rect(Rect2(c + sp - Vector2(3, 3), Vector2(6, 6)), Color(1.0, 0.92, 0.45, al))
	# Volver a tirar: los dados que fallaron muestran si se vuelven a tirar (cuánta Luz cuesta, con el sol) o si quedan retenidos (un candado);
	# el elegido lleva una flecha
	if phase == Phase.FIX and not hit:
		if marked[i]:
			var cost_text := str(REROLL_COST)
			var cl: Dictionary = VFont.layout([cost_text])
			var cp := c + Vector2(-float(cl.size.x) * 3.0 * 0.5 - 12.0, -118.0)
			Draw.text_cells(self, cp, cl.cells, cl.size.y, 3.0, Color(1.0, 0.95, 0.7), 0.0, i, true)
			LuzIcon.draw_sun(self, c + Vector2(float(cl.size.x) * 3.0 * 0.5 + 12.0, -104.0), 2.2, _t)
		else:   # retenido: un candado
			var lc := c + Vector2(0, -108.0)
			draw_rect(Rect2(lc + Vector2(-11, -2), Vector2(22, 16)), Color(0.72, 0.8, 1.0))
			draw_rect(Rect2(lc + Vector2(-11, -2), Vector2(22, 4)), Color(0.85, 0.9, 1.0))
			draw_polyline(PackedVector2Array([lc + Vector2(-7, -2), lc + Vector2(-7, -12), lc + Vector2(7, -12), lc + Vector2(7, -2)]), Color(0.72, 0.8, 1.0), 3.0)
		var arrow2 := Color(1.0, 0.85, 0.3) if i == selected else Color(0.6, 0.55, 0.72)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-14, -80), c + Vector2(14, -80), c + Vector2(0, -66)]), arrow2)
	# Flechas de elegir y lo pedido
	if picking:
		var arrow := Color(1.0, 0.85, 0.3) if i == selected else Color(0.6, 0.55, 0.72)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-16, -66), c + Vector2(16, -66), c + Vector2(0, -84)]), arrow)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-16, 70), c + Vector2(16, 70), c + Vector2(0, 88)]), arrow)
	var pick_text := str(picks[i])
	var l: Dictionary = VFont.layout([pick_text])
	var cs := 4.0
	var tsize := Vector2(l.size) * cs
	var col := Color(0.9, 0.85, 1.0)
	if is_revealed:
		col = Color(0.6, 1.0, 0.7) if hit else Color(1.0, 0.6, 0.6)
	Draw.text_cells(self, c + Vector2(-tsize.x * 0.5, 100.0), l.cells, l.size.y, cs, col, 0.0, i, true)


## ¿El dado `i` ya muestra su resultado? (los ocultos ruedan; al volver a tirar, los retenidos siguen a la vista)
func _is_revealed(i: int) -> bool:
	if unrevealed.has(i):
		return false
	return phase == Phase.REVEAL or phase == Phase.FIX or phase == Phase.RESULT or phase == Phase.DONE or (phase == Phase.ROLLING and reroll_round)


## Los puntos de una cara: `origin` es una esquina de la cara y `u`, `v` sus dos ejes (hacia el otro lado).
func _pips(origin: Vector2, u: Vector2, v: Vector2, value: int, color: Color) -> void:
	for pip in PIPS[clampi(value, 1, 6)]:
		var pc: Vector2 = origin + u * float(pip[0]) + v * float(pip[1])
		var pu := u * 0.15
		var pv := v * 0.15
		draw_colored_polygon(PackedVector2Array([pc - pu - pv, pc + pu - pv, pc + pu + pv, pc - pu + pv]), color)
		draw_colored_polygon(PackedVector2Array([pc - pu * 0.5 - pv * 0.5, pc + pu * 0.5 - pv * 0.5, pc + pu * 0.5 - pv * 0.1, pc - pu * 0.5 - pv * 0.1]), color.lightened(0.35))


## Un polígono achicado hacia su centro (el relieve de cada cara).
func _inset(pts: Array, k: float) -> PackedVector2Array:
	var mid := Vector2.ZERO
	for p in pts:
		mid += p
	mid /= float(pts.size())
	var out := PackedVector2Array()
	for p in pts:
		out.append(mid + (p - mid) * k)
	return out


## Espiral de carga: cubitos que van girando en espiral y se apagan; se ve mientras la torre se genera y desaparece cuando está lista.
class _Spiral extends Control:
	var owner_game
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		visible = owner_game != null and not owner_game.tower_ready
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
