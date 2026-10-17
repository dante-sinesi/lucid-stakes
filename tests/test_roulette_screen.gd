extends SceneTree
## Pruebas de la pantalla de la ruleta (headless).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_roulette_screen.gd

const RunState := preload("res://scripts/run_state.gd")
const Roulette := preload("res://scripts/roulette.gd")
const Items := preload("res://scripts/items.gd")
const Screen := preload("res://scripts/roulette_screen.gd")
const PrizesWindow := preload("res://scripts/prizes_window.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func make(claridad := 300) -> Array:
	var run := RunState.new()
	run.claridad = claridad
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var screen := Screen.new()
	root.add_child(screen)
	screen.setup(run, rng, true)
	return [screen, run]


func _init() -> void:
	await process_frame
	await test_selection()
	await test_spin()
	await test_wheel()
	await test_limits()
	await test_click_follows_rotation()
	print("tests de la pantalla de la ruleta terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_selection() -> void:
	var m := make()
	var s = m[0]
	check(s.bet == Roulette.Bet.PLENO and s.selected.is_empty() and not s.can_spin(), "al abrir: pleno elegido, sin fichas, no se puede girar")
	check(s.spin_button.disabled and s.result_label.text.contains("Toca 1 casilla"), "la pantalla pide elegir la casilla que falta")
	s.toggle_pocket(5)
	check(s.selected == [5] and s.can_spin() and not s.spin_button.disabled and s.result_label.text.contains("GIRAR"), "con una ficha el pleno ya se puede girar")
	check(s.wheel.covered == [5], "la rueda dibuja la ficha en la casilla elegida")
	s.toggle_pocket(5)
	check(s.selected.is_empty() and not s.can_spin(), "tocar de nuevo saca la ficha")
	s.toggle_pocket(0)
	s.toggle_pocket(13)
	check(s.selected.is_empty(), "la casilla 0 y las inexistentes no se pueden elegir")
	# terna: 3 fichas; al pasarse se suelta la mas vieja
	s.select_bet(Roulette.Bet.TERNA)
	for i in [1, 2, 3, 4]:
		s.toggle_pocket(i)
	check(s.selected == [2, 3, 4], "al poner una cuarta ficha en la terna se suelta la mas vieja")
	# al cambiar a una apuesta que cubre menos, se recortan las fichas
	s.select_bet(Roulette.Bet.PLENO)
	check(s.selected == [4], "al pasar a pleno queda solo la ficha mas nueva")
	# Ventana de premios: ícono, descripción y probabilidad de cada premio posible
	s.open_prizes()
	check(s.prizes_window.visible, "el boton Premios abre la ventana")
	var rows: Array = PrizesWindow.rows_for(Roulette.Bet.PLENO)
	var names := rows.map(func(r): return r.name)
	check(names.has("Segundo aliento") and rows.size() == Items.by_tier(Items.Tier.EPICO).size(), "sin vitrina el pleno muestra todos los premios épicos del catálogo")
	var total := 0.0
	for r in rows:
		total += r.prob
	check(is_equal_approx(total, Roulette.probability(Roulette.Bet.PLENO)), "las probabilidades de los premios suman la de acertar la apuesta (1/13)")
	check(PrizesWindow.percent_text(1.0 / 52.0) == "1,9 %", "la probabilidad se muestra con coma: 1,9 %")
	check(s.prizes_window.list.get_child_count() == rows.size() and s.prizes_window.tabs[Roulette.Bet.PLENO].button_pressed, "la ventana lista una fila por premio y marca la apuesta")
	s.prizes_window.show_bet(Roulette.Bet.RANGO)
	var rango_names := PrizesWindow.rows_for(Roulette.Bet.RANGO).map(func(r): return r.name)
	check(rango_names.has("Bolsa de luz") and s.prizes_window.list.get_child_count() == rango_names.size(), "el rango muestra premios basicos, con Bolsa de luz")
	var p_bolsa := 0.0
	for r in PrizesWindow.rows_for(Roulette.Bet.RANGO):
		if r.id == "bolsa_de_luz":
			p_bolsa = r.prob
	check(p_bolsa > 0.4 and p_bolsa < Roulette.probability(Roulette.Bet.RANGO), "la bolsa de luz es el premio mas probable del rango (%.3f)" % p_bolsa)
	s.prizes_window.close_window()
	check(not s.prizes_window.visible, "la ventana se cierra")
	s.queue_free()


func test_spin() -> void:
	# ganar
	var m := make(300)
	var s = m[0]
	var run = m[1]
	s.forced_pocket = 7
	s.toggle_pocket(7)
	var res: Dictionary = await s.spin()
	check(res.ok and res.won and res.pocket == 7, "el giro devuelve el resultado")
	check(s.state == Screen.State.RESULT and s.wheel.result == 7, "terminado el giro, la rueda marca la casilla ganadora")
	var ficha: int = Roulette.run_price(run)   # (la ficha de la etapa 1)
	check(run.claridad == 300 - ficha and run.boosts.size() == 1, "se cobro la ficha y se guardo el boost epico")
	check(s.result_label.text.contains("Cayó el 7") and s.result_label.text.contains("Ganaste"), "el mensaje cuenta que gano y que")
	check(s.claridad_counter.value == 300 - ficha and s.price_counter.value == ficha, "se actualizan la claridad y el precio de la ficha en pantalla")
	s.queue_free()

	# perder
	m = make(300)
	s = m[0]
	run = m[1]
	s.forced_pocket = 3
	s.toggle_pocket(9)
	res = await s.spin()
	check(not res.won and run.claridad == 300 - Roulette.run_price(run) and s.result_label.text.contains("Perdiste"), "perder: se pierde la ficha y el mensaje lo dice")

	# cae la casa
	s.forced_pocket = 0
	s.toggle_pocket(9)
	s.toggle_pocket(9)
	s.toggle_pocket(10)
	res = await s.spin()
	check(res.pocket == 0 and s.result_label.text.contains("casa"), "si cae el 0 el mensaje dice que gano la casa")

	# no se puede girar dos veces a la vez ni sin fichas
	var before: int = run.claridad
	s.selected.clear()
	var bad: Dictionary = await s.spin()
	check(not bad.ok and run.claridad == before, "sin fichas elegidas no gira ni cobra")
	s.queue_free()

	# señales
	m = make(300)
	s = m[0]
	var got := []
	s.spun.connect(func(r): got.append(r))
	s.forced_pocket = 1
	s.toggle_pocket(1)
	await s.spin()
	check(got.size() == 1 and got[0].pocket == 1, "se emite la señal spun con el resultado")
	var closed_count := [0]
	s.closed.connect(func(): closed_count[0] += 1)
	s.closed.emit()
	check(closed_count[0] == 1, "la señal closed se puede conectar")
	s.queue_free()


func test_wheel() -> void:
	var m := make()
	var s = m[0]
	s.fast = true
	# para cada casilla, la rueda termina con esa casilla bajo la bola
	var ok := true
	for p in range(0, 13):
		var run := RunState.new()
		run.claridad = 500
		s.run = run
		s.selected.clear()
		s.bet = Roulette.Bet.PLENO
		s.toggle_pocket(1 + (p % 12))
		s.forced_pocket = p
		var res: Dictionary = await s.spin()
		ok = ok and res.pocket == p and s.wheel.pocket_under_ball() == p
	check(ok, "para las 13 casillas la rueda termina con la casilla que cayo bajo la bola")
	check(is_equal_approx(s.wheel.sector() * 13.0, TAU), "13 sectores iguales")
	s.queue_free()


## Lo que ves es lo que tocás: la casilla bajo el mouse se calcula con la rotación ACTUAL de la rueda (no con la inicial).
func test_click_follows_rotation() -> void:
	var m := make(300)
	var s = m[0]
	s.wheel.size = Vector2(400, 400)
	var ok := true
	for angle in [0.0, 0.7, 2.3, 4.1, -1.9, 11.0]:
		s.wheel.rotation_angle = angle
		for p in range(1, 13):
			var mid: float = s.wheel.rotation_angle + p * s.wheel.sector() - PI / 2.0
			var pt: Vector2 = s.wheel.size / 2.0 + Vector2.from_angle(mid) * s.wheel.wheel_radius() * 0.6
			ok = ok and s.wheel.pocket_at_point(pt) == p
	check(ok, "para cualquier rotacion, tocar sobre la casilla p elige la casilla p")
	s.wheel.rotation_angle = 1.234
	var mid7: float = s.wheel.rotation_angle + 7 * s.wheel.sector() - PI / 2.0
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = s.wheel.size / 2.0 + Vector2.from_angle(mid7) * s.wheel.wheel_radius() * 0.6
	s.wheel._gui_input(ev)
	check(s.selected == [7], "el clic en la rueda pone la ficha en la casilla que se ve (aunque la rueda este girada)")
	ev.position = s.wheel.size / 2.0
	s.wheel._gui_input(ev)
	check(s.selected == [7], "el centro de la rueda no elige nada")
	var mid0: float = s.wheel.rotation_angle - PI / 2.0
	ev.position = s.wheel.size / 2.0 + Vector2.from_angle(mid0) * s.wheel.wheel_radius() * 0.6
	s.wheel._gui_input(ev)
	check(s.selected == [7], "la casilla 0 (la casa) no se puede cubrir")
	# la espera: la rueda gira sola despacio (y el clic sigue acertando con la rotacion actual)
	s.fast = false
	var before: float = s.wheel.rotation_angle
	s._process(0.5)
	check(s.wheel.rotation_angle > before, "mientras se elige, la rueda gira despacio")
	s.queue_free()


func test_limits() -> void:
	# sin claridad
	var m := make(30)
	var s = m[0]
	s.toggle_pocket(2)
	check(not s.can_spin() and s.spin_button.disabled and s.result_label.text.contains("No alcanza"), "con menos claridad que la ficha no se puede girar y la pantalla lo dice")
	var res: Dictionary = await s.spin()
	check(not res.ok and m[1].claridad == 30 and s.result_label.text.contains("claridad"), "intentar girar sin claridad avisa y no cobra")
	s.queue_free()

	# inventario lleno: el premio se convierte
	m = make(500)
	s = m[0]
	var run = m[1]
	for id in ["aire_extra", "ojo_de_hielo", "ahorro", "pies_de_luz", "paso_firme"]:
		run.take(Items.get_item(id))
	s.forced_pocket = 4
	s.toggle_pocket(4)
	res = await s.spin()
	check(res.converted and s.result_label.text.contains("no hay lugar"), "con los lugares llenos el mensaje avisa que se convirtio en claridad")
	s.queue_free()

	# mientras gira, los controles estan bloqueados
	m = make(300)
	s = m[0]
	s.fast = false
	s.forced_pocket = 2
	s.toggle_pocket(2)
	s.spin()  # sin await: queda girando mientras se inspecciona
	await process_frame
	check(s.state == Screen.State.SPINNING and s.spin_button.disabled and s.prizes_button.disabled, "mientras gira el boton esta bloqueado")
	var picks: Array = s.selected.duplicate()
	s.toggle_pocket(6)
	s.select_bet(Roulette.Bet.MITAD)
	check(s.selected == picks and s.bet == Roulette.Bet.PLENO, "mientras gira no se pueden cambiar la apuesta ni las fichas")
	var again: Dictionary = await s.spin()
	check(not again.ok and again.error.contains("girando"), "no se puede girar de nuevo mientras gira")
	s.queue_free()
