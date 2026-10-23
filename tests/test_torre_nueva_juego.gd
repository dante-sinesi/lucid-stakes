extends SceneTree
## La torre nueva dentro del juego (main.gd): arranque, victoria con claridad al run, muertes con las vidas del run, consumibles y guardado.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/test_torre_nueva_juego.gd
const Scenarios := preload("res://scripts/scenarios.gd")
const Profile := preload("res://scripts/profile.gd")
var fallos := 0
func _ok(c: bool, m: String) -> void:
	print(("ok  " if c else "FALLA ") + m)
	if not c:
		fallos += 1
func _frames(n: int) -> void:
	for i in n:
		await process_frame
func _jugar_sala(main, k: int) -> void:
	for a in main.nueva.t.salas[k].d.camino:
		main.nueva.accion(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
func _init() -> void:
	OS.set_environment("GAME_TORRE_NUEVA", "1")
	Profile.path = "user://test_profile_tn.json"
	Profile.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	main.test_mode_jobs = false
	root.add_child(main)
	await _frames(4)
	main.start_game()
	await _frames(4)
	_ok(main.nueva != null and main.nueva.t != null and main.nueva.t.salas.size() >= 5, "al empezar el run hay una torre nueva de %d salas" % (main.nueva.t.salas.size() if main.nueva != null and main.nueva.t != null else 0))
	_ok(main.logic == null and main.stage_number == 1, "la etapa 1 no usa la lógica vieja")
	_ok(main.nueva.t.externo and main.nueva.t.etapa == 1, "las vidas son las del run y la torre sabe su etapa")
	var vidas0: int = main.run.lives
	# muerte: se acaban los movimientos de la sala 1 -> pierde una vida del run y la sala vuelve a empezar
	var cam: Array = main.nueva.t.salas[0].d.camino
	main.nueva.t.salas[0].max_mov = 2
	main.nueva.t.mov_extra = 0
	for i in 2:
		main.nueva.accion(Vector3i(int(cam[i][0]), 0, int(cam[i][1])), int(cam[i][2]))
	_ok(main.nueva.t.muerta and main.lost_screen.visible and main.run.lives == vidas0, "morir muestra la pantalla de derrota y todavía no resta la vida")
	main.request_restart()   # (el botón Reintentar)
	_ok(main.run.lives == vidas0 - 1 and main.nueva.t.indice == 0 and main.nueva.t.movs == 0 and not main.nueva.t.muerta and not main.lost_screen.visible, "Reintentar resta una vida del run y reinicia la sala (%d vidas)" % main.run.lives)
	main.nueva.t.salas[0].max_mov = 999
	# el personaje y los cosméticos del perfil son los de la torre nueva (no siempre el gatito)
	Profile.select_character("dante")
	main._torre_nueva_arrancar(3)
	_ok(main.nueva.gato != null and Profile.character() == "dante" and main.nueva.gato.get_child_count() > 3, "la torre nueva usa el personaje elegido (dante) con su modelo")
	var ref_grilla = main.nueva.vivo.get_node_or_null("referencia")
	_ok(ref_grilla == null, "dentro del juego no se dibuja la grilla blanca de prueba")
	Profile.select_character("gato")
	main._torre_nueva_arrancar(3)
	# deshacer: vuelve el jugador, la cuenta de movimientos y la claridad
	var cam1: Array = main.nueva.t.salas[0].d.camino
	var pos0: Vector3i = main.nueva.t.motor.jugador
	var cl0: int = main.nueva.t.cosecha.claridad()
	main.nueva.accion(Vector3i(int(cam1[0][0]), 0, int(cam1[0][1])), int(cam1[0][2]))
	main.nueva.accion(Vector3i(int(cam1[1][0]), 0, int(cam1[1][1])), int(cam1[1][2]))
	_ok(main.nueva.t.movs == 2, "dos movimientos hechos")
	main.undo_move()
	main.undo_move()
	_ok(main.nueva.t.movs == 0 and main.nueva.t.motor.jugador == pos0 and main.nueva.t.cosecha.claridad() == cl0, "deshacer dos veces vuelve al comienzo (jugador, movimientos y claridad)")
	main.undo_move()
	_ok(main.nueva.t.movs == 0, "sin nada que deshacer no pasa nada")
	# el mando entra como teclas: la acción 'mover_adelante' mueve y 'deshacer' deshace
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = main.Controls.key_of("deshacer")
	main.nueva.accion(Vector3i(int(cam1[0][0]), 0, int(cam1[0][1])), int(cam1[0][2]))
	main.nueva._input(ev)
	_ok(main.nueva.t.movs == 0, "la tecla de deshacer (la que reasigna Controles) deshace")
	# consumible: Freno suma movimientos
	main.run.consumables.append("freno")
	var antes: int = main.nueva.t.max_mov()
	main.use_consumable_slot(main.run.consumables.size() - 1)
	_ok(main.nueva.t.max_mov() == antes + 5 and not main.run.consumables.has("freno"), "Freno suma 5 movimientos y se gasta")
	main.run.consumables.append("conv_roca")
	var n_cons: int = main.run.consumables.size()
	main.use_consumable_slot(n_cons - 1)
	_ok(main.run.consumables.size() == n_cons, "un consumible que todavía no funciona no se gasta")
	# jugar toda la torre con los caminos: claridad al run y casino
	var claridad0: int = main.run.claridad
	var total_salas: int = main.nueva.t.salas.size()
	_jugar_sala(main, 0)
	await _frames(2)
	_ok(main.nueva.t.indice == 1 and main.dialogue.is_active(), "en el checkpoint Farolín dice cuánto falta (cuadro de diálogo abierto)")
	_ok(str(main.dialogue.lines[0]).contains(str(total_salas - 1)) and main.dialogue.speaker == "Farolín", "Farolín dice cuántos checkpoints faltan (%s)" % str(main.dialogue.lines[0]))
	var sal0: Dictionary = main.nueva.t.sala_actual()
	var s0: Vector2i = main.nueva.Torre.salida_xz(sal0.d)
	_ok(main.nueva.farolin.visible and absf(main.nueva.farolin.position.x - (s0.x + 0.5)) < 0.01, "Farolín espera en el próximo checkpoint (la salida de la sala actual)")
	main.dialogue.hide_box()
	for k in range(1, total_salas):
		_jugar_sala(main, k)
	await _frames(4)
	_ok(main.casino != null and main.nueva == null, "al llegar al portal sigue el casino y la torre se saca")
	_ok(main.run.claridad > claridad0, "la claridad de la torre pasó al run (%d -> %d)" % [claridad0, main.run.claridad])
	main.leave_casino()
	await _frames(6)
	_ok(main.stage_number == 2 and main.nueva != null and main.nueva.t.etapa == 2, "se sale del casino a la torre nueva de la etapa 2")
	# guardado y continuar
	main.save_game()
	var data: Dictionary = main.SaveGame.read()
	_ok(str(data.get("phase", "")) == "tower" and bool(data.get("nueva", false)), "el guardado marca la torre nueva")
	# Sin piedad: los movimientos en falso de la sala (el solucionador nativo mide cuántos pasos faltan)
	main.run.scenario_id = "sin_piedad"
	main._torre_nueva_arrancar(7)   # (una semilla fija: la prueba no depende del azar)
	await _frames(3)
	_ok(main.nueva != null and main.nueva.falsos != null and main.nueva.falsos.permitidos == 2, "Sin piedad: la torre nueva trae el medidor con 2 falsos por sala")
	main.nueva.falsos.inline = true
	main.nueva.falsos.sala_nueva(main.nueva.t.motor)
	var vidas_sp: int = main.run.lives
	var intentos := 0
	var dirs := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	var max_cuenta := 0
	while main.run.lives == vidas_sp and intentos < 60 and main.nueva != null:
		var antes_cuenta: int = main.nueva.falsos.cuenta
		main.nueva.accion(dirs[intentos % 4], 0)
		max_cuenta = maxi(max_cuenta, main.nueva.falsos.cuenta)
		intentos += 1
	_ok(max_cuenta >= 1, "Sin piedad: andar sin rumbo cuenta movimientos en falso (%d)" % max_cuenta)
	main.run.scenario_id = Scenarios.FREE
	main.restart()
	await _frames(2)
	# sin vidas: termina el run
	main.run.lives = 0
	main.nueva.t.salas[0].max_mov = 1
	var c2: Array = main.nueva.t.salas[0].d.camino
	main.nueva.accion(Vector3i(int(c2[0][0]), 0, int(c2[0][1])), int(c2[0][2]))
	await _frames(2)
	_ok(main.run_over, "sin vidas, morir termina el run")
	# los dados de la pantalla de carga: al empezar cada torre nueva se ofrecen y "Empezar" está habilitado
	var main3 = load("res://scenes/main.tscn").instantiate()
	main3.test_mode = true
	main3.quick_portal = true
	main3.test_mode_jobs = false
	root.add_child(main3)
	await _frames(4)
	main3.dice_always = true
	main3.dice.auto_start = false   # (en las pruebas los dados se cierran solos: acá se dejan abiertos para comprobar que se ofrecen)
	main3.start_game()
	await _frames(6)
	_ok(main3.dice.visible and main3.nueva == null, "al empezar la torre nueva se abren los dados de la pantalla de carga (la torre espera)")
	main3.dice.auto_start = true
	main3.dice.set_ready(true)   # (se aprieta "Empezar")
	await _frames(10)
	_ok(not main3.dice.visible and main3.nueva != null, "al cerrar los dados empieza la torre")
	main3.queue_free()
	# la última lección del tutorial ('Una torre de verdad') es una torre nueva chica (2 salas)
	var main2 = load("res://scenes/main.tscn").instantiate()
	main2.test_mode = true
	main2.quick_portal = true
	main2.test_mode_jobs = false
	root.add_child(main2)
	await _frames(4)
	var Tut = load("res://scripts/tutorial.gd")
	main2.start_tutorial(Tut.count() - 1, true)
	await _frames(6)
	_ok(main2.nueva != null and main2.nueva.t.salas.size() == 2, "la última lección del tutorial es una torre nueva de 2 salas")
	for k in main2.nueva.t.salas.size():
		for a2 in main2.nueva.t.salas[k].d.camino:
			if main2.nueva == null:
				break
			main2.nueva.accion(Vector3i(int(a2[0]), 0, int(a2[1])), int(a2[2]))
	await _frames(8)
	_ok(main2.nueva == null, "al llegar al portal del tutorial se pasa a lo que sigue")
	main2.queue_free()
	Profile.reset()
	print("fallos: ", fallos)
	quit(1 if fallos > 0 else 0)
