extends SceneTree
## Pruebas de la pantalla de la ruleta (headless): la rueda de rarezas, el giro, la ventana de premios y los límites.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_roulette_screen.gd

const RunState := preload("res://scripts/datos/run_state.gd")
const Roulette := preload("res://scripts/casino/roulette.gd")
const Items := preload("res://scripts/datos/items.gd")
const Screen := preload("res://scripts/casino/roulette_screen.gd")
const PrizesWindow := preload("res://scripts/ui/prizes_window.gd")

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
	await test_abrir_y_premios()
	await test_spin()
	await test_wheel()
	await test_limits()
	print("tests de la pantalla de la ruleta terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_abrir_y_premios() -> void:
	var m := make()
	var s = m[0]
	var run = m[1]
	check(s.can_spin() and not s.spin_button.disabled, "al abrir se puede girar (no hay nada que elegir)")
	check(s.wheel.tiers == Roulette.wheel_tiers(run) and s.price_counter.value == Roulette.spin_price(run), "la rueda muestra las rarezas y la pantalla lo que cuesta el giro")
	# Ventana de premios: ícono, descripción y probabilidad de cada premio posible, por rareza
	s.open_prizes()
	check(s.prizes_window.visible, "el boton Premios abre la ventana")
	var rows: Array = PrizesWindow.rows_for(Items.Tier.EPICO)
	var names := rows.map(func(r): return r.name)
	check(names.has("Segundo aliento") and rows.size() == Items.by_tier(Items.Tier.EPICO).size(), "sin vitrina las casillas épicas muestran todos los premios épicos del catálogo")
	for tier in Roulette.TIER_ORDER:
		var total := 0.0
		for r in PrizesWindow.rows_for(tier):
			total += r.prob
		check(is_equal_approx(total, Roulette.probability(tier)), "las probabilidades de los premios de %s suman las de caer en esa rareza" % Roulette.TIER_NAMES[tier])
	check(PrizesWindow.percent_text(1.0 / 52.0) == "1,9 %", "la probabilidad se muestra con coma: 1,9 %")
	check(s.prizes_window.list.get_child_count() == rows.size() and s.prizes_window.tabs[Items.Tier.EPICO].button_pressed and s.prizes_window.tabs.size() == 4, "la ventana lista una fila por premio y marca la rareza (4 solapas)")
	s.prizes_window.show_tier(Items.Tier.CONSUMIBLE)
	var bolsas := PrizesWindow.rows_for(Items.Tier.CONSUMIBLE).map(func(r): return r.name)
	check(bolsas.has("Bolsa de luz") and s.prizes_window.list.get_child_count() == bolsas.size(), "las casillas de bolsas muestran la Bolsa de luz")
	s.prizes_window.close_window()
	check(not s.prizes_window.visible, "la ventana se cierra")
	s.queue_free()


func test_spin() -> void:
	var m := make(500)
	var s = m[0]
	var run = m[1]
	var costo: int = Roulette.spin_price(run)
	s.forced_pocket = 0   # la casilla épica
	var res: Dictionary = await s.spin()
	check(res.ok and res.pocket == 0 and res.tier == Items.Tier.EPICO, "el giro devuelve el resultado")
	check(s.state == Screen.State.RESULT and s.wheel.result == 0, "terminado el giro, la rueda marca la casilla en la que cayó")
	check(run.claridad == 500 - costo and run.boosts.size() == 1, "se cobró el giro y se guardó el boost épico")
	check(s.result_label.text.contains("casilla de épico") and s.result_label.text.contains("Ganaste"), "el mensaje cuenta en qué casilla cayó y qué ganó")
	check(s.claridad_counter.value == 500 - costo and s.price_counter.value == costo, "se actualizan la claridad y el precio del giro en pantalla")
	# se puede girar otra vez, y una casilla de bolsas siempre da algo
	s.forced_pocket = 1
	var res2: Dictionary = await s.spin()
	check(res2.ok and not res2.prize.is_empty() and res2.tier == Items.Tier.CONSUMIBLE, "una casilla de bolsas también da un premio")
	s.queue_free()

	# señales
	m = make(500)
	s = m[0]
	var got := []
	s.spun.connect(func(r): got.append(r))
	s.forced_pocket = 1
	await s.spin()
	check(got.size() == 1 and got[0].pocket == 1, "se emite la señal spun con el resultado")
	var closed_count := [0]
	s.closed.connect(func(): closed_count[0] += 1)
	s.closed.emit()
	check(closed_count[0] == 1, "la señal closed se puede conectar")
	s.queue_free()


func test_wheel() -> void:
	var m := make(100000)
	var s = m[0]
	s.fast = true
	# para cada casilla, la rueda termina con esa casilla bajo la bola
	var ok := true
	for p in range(0, 13):
		s.forced_pocket = p
		var res: Dictionary = await s.spin()
		ok = ok and res.pocket == p and s.wheel.pocket_under_ball() == p
	check(ok, "para las 13 casillas la rueda termina con la casilla que cayó bajo la bola")
	check(is_equal_approx(s.wheel.sector() * 13.0, TAU), "13 sectores iguales")
	# la espera: la rueda gira sola despacio
	s.fast = false
	s.state = Screen.State.IDLE
	var before: float = s.wheel.rotation_angle
	s._process(0.5)
	check(s.wheel.rotation_angle > before, "mientras espera, la rueda gira despacio")
	s.queue_free()


func test_limits() -> void:
	# sin claridad
	var m := make(30)
	var s = m[0]
	check(not s.can_spin() and s.spin_button.disabled and s.result_label.text.contains("No alcanza"), "con menos claridad que el giro no se puede girar y la pantalla lo dice")
	var res: Dictionary = await s.spin()
	check(not res.ok and m[1].claridad == 30 and s.result_label.text.contains("claridad"), "intentar girar sin claridad avisa y no cobra")
	s.queue_free()

	# inventario lleno: el premio se convierte
	m = make(500)
	s = m[0]
	var run = m[1]
	for id in ["aire_extra", "madrugada", "ahorro", "pies_de_luz", "paso_firme"]:
		run.take(Items.get_item(id))
	s.forced_pocket = 0   # un boost épico sin lugar
	res = await s.spin()
	check(res.converted and s.result_label.text.contains("no hay lugar"), "con los lugares llenos el mensaje avisa que se convirtió en claridad")
	s.queue_free()

	# mientras gira, los controles están bloqueados
	m = make(300)
	s = m[0]
	s.fast = false
	s.forced_pocket = 2
	s.spin()  # sin await: queda girando mientras se inspecciona
	await process_frame
	check(s.state == Screen.State.SPINNING and s.spin_button.disabled and s.prizes_button.disabled, "mientras gira el boton esta bloqueado")
	var again: Dictionary = await s.spin()
	check(not again.ok and again.error.contains("girando"), "no se puede girar de nuevo mientras gira")
	s.queue_free()
