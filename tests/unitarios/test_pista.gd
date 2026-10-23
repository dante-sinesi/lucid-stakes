extends SceneTree
## Fácil: movimientos ilimitados y modo pista (la tecla de la pista muestra arriba el próximo movimiento de la solución); y lo que cambia con la dificultad:
## cosméticos por dificultad y Luz del run. Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/unitarios/test_pista.gd
const Profile := preload("res://scripts/datos/profile.gd")
const Cosmetics := preload("res://scripts/personajes/cosmetics.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Torre := preload("res://torre/torre.gd")
var fallos := 0


func _ok(c: bool, m: String) -> void:
	print(("ok  " if c else "FALLA ") + m)
	if not c:
		fallos += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Espera (con tope) a que la pista del juego muestre algo.
func _esperar_pista(main) -> bool:
	for i in 600:
		await process_frame
		if main.pista_hint.visible:
			return true
		OS.delay_msec(10)
	return false


func _init() -> void:
	Profile.path = "user://test_profile_pista.json"
	Profile.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	await _frames(4)
	main.start_game("pesadilla", "facil")
	await _frames(4)
	var torre = main.torre
	_ok(torre.t.max_mov() == Torre.SIN_LIMITE, "en Fácil las salas no tienen límite de movimientos")
	_ok(torre.pista_permitida, "en Fácil se puede usar el modo pista")
	_ok(not main.pista_hint.visible, "la pista empieza apagada")
	# un solo movimiento a la vez: la pista dice cuál es el próximo y al hacerlo cambia
	torre.alternar_pista()
	_ok(await _esperar_pista(main), "al encender el modo pista aparece el próximo movimiento arriba")
	var texto: String = torre._pista_texto
	_ok(texto.begins_with("Pulsa {") or texto.begins_with("Mantén {"), "la pista trae las teclas entre llaves (%s)" % texto)
	var camino: Array = torre.t.salas[0].d.camino
	var antes: String = torre._clave_pista()
	torre.accion(Vector3i(int(camino[0][0]), 0, int(camino[0][1])), int(camino[0][2]))
	await _frames(2)
	_ok(torre._clave_pista() != antes, "el estado cambió después del movimiento")
	_ok(await _esperar_pista(main), "después de mover aparece la pista siguiente")
	torre.alternar_pista()
	await _frames(2)
	_ok(not main.pista_hint.visible and torre._pista_texto == "", "al apagar el modo pista se saca de la pantalla")
	# en Medio no hay pista ni movimientos ilimitados
	main.start_game("pesadilla", "media")
	await _frames(4)
	_ok(not main.torre.pista_permitida and main.torre.t.max_mov() < Torre.SIN_LIMITE, "en Medio no hay pista y los movimientos tienen límite")
	main.torre.alternar_pista()
	_ok(not main.torre.pista_activa, "alternar la pista en Medio no hace nada")
	# cosméticos por dificultad
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_ok(Cosmetics.roll_por_dificultad("facil", [], rng).is_empty(), "Fácil no da cosméticos")
	var rarezas := {}
	for dif in ["media", "dificil", "pesadilla"]:
		rarezas[dif] = {}
		for i in 60:
			var c := Cosmetics.roll_por_dificultad(dif, [], rng)
			rarezas[dif][str(c.rarity)] = true
	_ok(rarezas.media.has("comun") and rarezas.media.has("raro") and not rarezas.media.has("epico"), "Medio da comunes y raros, nunca épicos")
	_ok(rarezas.dificil.has("comun") and rarezas.dificil.has("raro") and not rarezas.dificil.has("epico"), "Difícil da comunes y raros, nunca épicos")
	_ok(rarezas.pesadilla.has("raro") and rarezas.pesadilla.has("epico") and not rarezas.pesadilla.has("comun"), "Pesadilla da raros y épicos")
	var no_comunes: Array = []
	for c in Cosmetics.ALL:
		if c.rarity != "comun":
			no_comunes.append(c.id)
	var c2 := Cosmetics.roll_por_dificultad("pesadilla", no_comunes, rng)
	_ok(not c2.is_empty() and c2.rarity == "comun", "en Pesadilla, si ya tienes todos los raros y épicos y te faltan comunes, sale uno común")
	var todos_cr: Array = []
	for c in Cosmetics.ALL:
		if c.rarity != "epico":
			todos_cr.append(c.id)
	_ok(Cosmetics.roll_por_dificultad("media", todos_cr, rng).is_empty(), "en Medio, si ya tienes todos los comunes y raros, no sale nada")
	# los dados ya no dan cosméticos
	var DiceGame = load("res://scripts/casino/dice_game.gd")
	var sin_cosmeticos := true
	for n in 6:
		sin_cosmeticos = sin_cosmeticos and DiceGame.prize_for(n).cosmetic.is_empty()
	_ok(sin_cosmeticos, "los dados no dan cosméticos")
	# la Luz del run en Fácil
	var run := RunState.new()
	run.towers_cleared = 10
	run.dificultad = "media"
	var luz_media := Profile.luz_for_run(run, false)
	run.dificultad = "facil"
	var luz_facil := Profile.luz_for_run(run, false)
	_ok(luz_facil < luz_media and luz_facil > 0, "Fácil da menos Luz que Medio (%d contra %d)" % [luz_facil, luz_media])
	print("pista terminados, fallos: ", fallos)
	quit(1 if fallos > 0 else 0)
