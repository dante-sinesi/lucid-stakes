extends SceneTree
## La torre dentro del juego (main.gd): arranque, victoria con claridad al run, muertes con las vidas del run, consumibles y guardado.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/unitarios/test_torre_juego.gd
const Scenarios := preload("res://scripts/datos/scenarios.gd")
const Profile := preload("res://scripts/datos/profile.gd")
var fallos := 0
func _ok(c: bool, m: String) -> void:
	print(("ok  " if c else "FALLA ") + m)
	if not c:
		fallos += 1
func _frames(n: int) -> void:
	for i in n:
		await process_frame
func _jugar_sala(main, k: int) -> void:
	for a in main.torre.t.salas[k].d.camino:
		main.torre.accion(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
func _init() -> void:
	Profile.path = "user://test_profile_tn.json"
	Profile.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	await _frames(4)
	main.start_game()
	await _frames(4)
	_ok(main.torre != null and main.torre.t != null and main.torre.t.salas.size() >= 5, "al empezar el run hay una torre nueva de %d salas" % (main.torre.t.salas.size() if main.torre != null and main.torre.t != null else 0))
	_ok(main.torre.t.externo and main.torre.t.etapa == 1, "las vidas son las del run y la torre sabe su etapa")
	var vidas0: int = main.run.lives
	# muerte: se acaban los movimientos de la sala 1 -> pierde una vida del run y la sala vuelve a empezar
	var cam: Array = main.torre.t.salas[0].d.camino
	main.torre.t.salas[0].max_mov = 2
	main.torre.t.mov_extra = 0
	for i in 2:
		main.torre.accion(Vector3i(int(cam[i][0]), 0, int(cam[i][1])), int(cam[i][2]))
	_ok(main.torre.t.muerta and main.lost_screen.visible and main.run.lives == vidas0, "morir muestra la pantalla de derrota y todavía no resta la vida")
	main.request_restart()   # (el botón Reintentar)
	_ok(main.run.lives == vidas0 - 1 and main.torre.t.indice == 0 and main.torre.t.movs == 0 and not main.torre.t.muerta and not main.lost_screen.visible, "Reintentar resta una vida del run y reinicia la sala (%d vidas)" % main.run.lives)
	main.torre.t.salas[0].max_mov = 999
	# el personaje y los cosméticos del perfil son los de la torre (no siempre el gatito)
	Profile.select_character("dante")
	main._torre_arrancar(3)
	_ok(main.torre.gato != null and Profile.character() == "dante" and main.torre.gato.get_child_count() > 3, "la torre usa el personaje elegido (dante) con su modelo")
	var ref_grilla = main.torre.vivo.get_node_or_null("referencia")
	_ok(ref_grilla == null, "dentro del juego no se dibuja la grilla blanca de prueba")
	Profile.select_character("gato")
	main._torre_arrancar(3)
	# la dificultad del run gradúa los niveles de las salas
	var Torre = main.torre.Torre
	var sube := true
	var ordenadas := true
	for etapa in [1, 5, 10, 15]:
		var previo := -1.0
		for i in 7:
			var b: float = Torre.bits_objetivo(Torre.progreso(i, 7, etapa, "media"))
			sube = sube and b >= previo
			previo = b
		var bf: float = Torre.bits_objetivo(Torre.progreso(3, 7, etapa, "facil"))
		var bm: float = Torre.bits_objetivo(Torre.progreso(3, 7, etapa, "media"))
		var bd: float = Torre.bits_objetivo(Torre.progreso(3, 7, etapa, "dificil"))
		var bp: float = Torre.bits_objetivo(Torre.progreso(3, 7, etapa, "pesadilla"))
		ordenadas = ordenadas and bf <= bm and bm <= bd and bd <= bp
	_ok(sube and Torre.bits_objetivo(Torre.progreso(0, 7, 15)) > Torre.bits_objetivo(Torre.progreso(6, 7, 1)), "la dificultad que busca cada sala sube dentro de la torre y con la etapa")
	_ok(ordenadas, "Fácil busca salas más simples que Medio, Difícil que Medio y Pesadilla que Difícil")
	_ok(Torre.max_movimientos(20, "media", 8, "facil") > Torre.max_movimientos(20, "media", 8, "media") and Torre.max_movimientos(20, "media", 8, "media") > Torre.max_movimientos(20, "media", 8, "pesadilla"), "cuanto más difícil, menos margen de movimientos")
	# telemetría: una sala perdida deja su evento
	var eventos: Array = main.Telemetry.read_all()
	var salas_perdidas := 0
	var torres_muertas := 0
	for ev in eventos:
		if str(ev.kind) == "sala" and str(ev.resultado) == "perdida":
			salas_perdidas += 1
			_ok(int(ev.max_mov) >= int(ev.movs) and str(ev.nivel) != "" and int(ev.total) >= 5, "el evento 'sala' trae el nivel, los movimientos y el total de salas")
		if str(ev.kind) == "torre" and str(ev.outcome) == "muerta":
			torres_muertas += 1
	_ok(salas_perdidas >= 1 and torres_muertas >= 1, "la telemetría anota la sala perdida y el intento de torre muerto")
	# deshacer: vuelve el jugador, la cuenta de movimientos y la claridad
	var cam1: Array = main.torre.t.salas[0].d.camino
	var pos0: Vector3i = main.torre.t.motor.jugador
	var cl0: int = main.torre.t.cosecha.claridad()
	main.torre.accion(Vector3i(int(cam1[0][0]), 0, int(cam1[0][1])), int(cam1[0][2]))
	main.torre.accion(Vector3i(int(cam1[1][0]), 0, int(cam1[1][1])), int(cam1[1][2]))
	_ok(main.torre.t.movs == 2, "dos movimientos hechos")
	main.undo_move()
	main.undo_move()
	_ok(main.torre.t.movs == 1 and main.torre.t.motor.jugador == pos0 and main.torre.t.cosecha.claridad() == cl0, "deshacer dos veces vuelve al comienzo (jugador y claridad) y devuelve la mitad de los movimientos")
	main.undo_move()
	_ok(main.torre.t.movs == 1 and main.torre.t.motor.jugador == pos0, "sin nada que deshacer no pasa nada")
	# el mando entra como teclas: la acción 'mover_adelante' mueve y 'deshacer' deshace
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = main.Controls.key_of("deshacer")
	main.torre.accion(Vector3i(int(cam1[0][0]), 0, int(cam1[0][1])), int(cam1[0][2]))
	main.torre._input(ev)
	_ok(main.torre.t.motor.jugador == pos0, "la tecla de deshacer (la que reasigna Controles) deshace")
	# consumible: Freno suma movimientos
	main.run.consumables.append("freno")
	var antes: int = main.torre.t.max_mov()
	main.use_consumable_slot(main.run.consumables.size() - 1)
	_ok(main.torre.t.max_mov() == antes + 5 and not main.run.consumables.has("freno"), "Freno suma 5 movimientos y se gasta")
	main.run.consumables.append("conv_roca")
	var n_cons: int = main.run.consumables.size()
	main.use_consumable_slot(n_cons - 1)
	_ok(main.run.consumables.size() == n_cons, "un consumible que todavía no funciona no se gasta")
	# jugar toda la torre con los caminos: claridad al run y casino
	var claridad0: int = main.run.claridad
	var total_salas: int = main.torre.t.salas.size()
	_jugar_sala(main, 0)
	await _frames(2)
	_ok(main.torre.t.indice == 1 and not main.dialogue.is_active(), "en el checkpoint no se abre ningún diálogo (Farolín no habla por ahora)")
	var sal0: Dictionary = main.torre.t.sala_actual()
	var s0: Vector2i = main.torre.Torre.salida_xz(sal0.d)
	_ok(main.torre.farolin.visible and absf(main.torre.farolin.position.x - (s0.x + 0.5)) < 0.01, "Farolín espera en el próximo checkpoint (la salida de la sala actual)")
	main.dialogue.hide_box()
	for k in range(1, total_salas - 1):
		_jugar_sala(main, k)
	main.quick_portal = false   # (en el portal el HUD sigue a la vista un momento: la claridad no se cuenta dos veces)
	_jugar_sala(main, total_salas - 1)
	await _frames(3)
	_ok(main.banked and main.clarity_counter.value == main.run.claridad, "en el portal el contador muestra la claridad del run, sin contar dos veces la de la torre (%d y %d)" % [main.clarity_counter.value, main.run.claridad])
	main.quick_portal = true
	await create_timer(2.5).timeout   # (el personaje se mete en el portal antes de seguir)
	_ok(main.casino != null and main.torre == null, "al llegar al portal sigue el casino y la torre se saca")
	_ok(main.run.claridad > claridad0, "la claridad de la torre pasó al run (%d -> %d)" % [claridad0, main.run.claridad])
	main.leave_casino()
	await _frames(6)
	_ok(main.stage_number == 2 and main.torre != null and main.torre.t.etapa == 2, "se sale del casino a la torre de la etapa 2")
	# guardado y continuar
	main.save_game()
	var data: Dictionary = main.SaveGame.read()
	_ok(str(data.get("phase", "")) == "tower" and data.has("sala"), "el guardado marca la torre y la sala")
	# El camino corto: los movimientos en falso de la sala (el solucionador nativo mide cuántos pasos faltan)
	main.run.scenario_id = "sin_piedad"
	main._torre_arrancar(7)   # (una semilla fija: la prueba no depende del azar)
	await _frames(3)
	_ok(main.torre != null and main.torre.falsos != null and main.torre.falsos.permitidos == 2, "El camino corto: la torre trae el medidor con 2 falsos por sala")
	main.torre.falsos.inline = true
	main.torre.falsos.sala_nueva(main.torre.t.motor)
	var vidas_sp: int = main.run.lives
	var intentos := 0
	var dirs := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	var max_cuenta := 0
	while main.run.lives == vidas_sp and intentos < 60 and main.torre != null:
		var antes_cuenta: int = main.torre.falsos.cuenta
		main.torre.accion(dirs[intentos % 4], 0)
		max_cuenta = maxi(max_cuenta, main.torre.falsos.cuenta)
		intentos += 1
	_ok(max_cuenta >= 1, "El camino corto: andar sin rumbo cuenta movimientos en falso (%d)" % max_cuenta)
	main.run.scenario_id = Scenarios.FREE
	main.restart()
	await _frames(2)
	# sin vidas: termina el run
	main.run.lives = 0
	main.torre.t.salas[0].max_mov = 1
	var c2: Array = main.torre.t.salas[0].d.camino
	main.torre.accion(Vector3i(int(c2[0][0]), 0, int(c2[0][1])), int(c2[0][2]))
	_ok(not main.run_over and main.torre != null, "sin vidas, antes de terminar el run se ve la caída")
	await create_timer(0.4).timeout   # (en las pruebas la animación espera 0,1 s)
	_ok(main.run_over, "sin vidas, morir termina el run")
	# los dados de la pantalla de carga: al empezar cada torre nueva se ofrecen y "Empezar" está habilitado
	var main3 = load("res://scenes/main.tscn").instantiate()
	main3.test_mode = true
	main3.quick_portal = true
	root.add_child(main3)
	await _frames(4)
	main3.dice_always = true
	main3.start_game()
	await _frames(10)
	_ok(not main3.dice.visible and main3.torre != null, "al empezar la torre no se abren los dados (salen al entrar al casino)")
	main3.queue_free()
	# la última lección del tutorial ('Una torre de verdad') es una torre nueva chica (2 salas)
	var main2 = load("res://scenes/main.tscn").instantiate()
	main2.test_mode = true
	main2.quick_portal = true
	root.add_child(main2)
	await _frames(4)
	var Tut = load("res://scripts/datos/tutorial.gd")
	main2.start_tutorial(Tut.count() - 1, true)
	await _frames(6)
	_ok(main2.torre != null and main2.torre.t.salas.size() == 2, "la última lección del tutorial es una torre nueva de 2 salas")
	for k in main2.torre.t.salas.size():
		for a2 in main2.torre.t.salas[k].d.camino:
			if main2.torre == null:
				break
			main2.torre.accion(Vector3i(int(a2[0]), 0, int(a2[1])), int(a2[2]))
	await _frames(8)
	_ok(main2.torre == null, "al llegar al portal del tutorial se pasa a lo que sigue")
	main2.queue_free()
	Profile.reset()
	print("fallos: ", fallos)
	quit(1 if fallos > 0 else 0)
