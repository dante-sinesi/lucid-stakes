extends SceneTree
## Pruebas de guardar y continuar: serializacion de torres y del run, archivo de guardado y el flujo completo en el juego.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_save.gd

const RunState := preload("res://scripts/datos/run_state.gd")
const SaveGame := preload("res://scripts/datos/save_game.gd")
const Items := preload("res://scripts/datos/items.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	SaveGame.path = "user://test_save.json"
	SaveGame.delete()
	test_run_roundtrip()
	test_file()
	await test_flow_tower()
	await test_checkpoint()
	await test_flow_casino()
	await test_death_saves()
	await test_end_deletes()
	await test_menu_button()
	SaveGame.delete()
	print("tests de guardado terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func make_main() -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	return main


func wait_tower(main: Node) -> void:
	await process_frame
	while main.generating or main.torre == null:
		await process_frame


func test_run_roundtrip() -> void:
	var run := RunState.new()
	run.stage = 9
	run.claridad = 431
	run.boosts.assign(["aire_extra", "mente_abierta"])
	run.consumables.assign(["freno"])
	run.casino_spent = 200
	run.casino_won = 90
	run.retries = 3
	run.tower_retries = 1
	run.towers_cleared = 8
	run.claridad_earned = 1500
	run.moves = 777
	run.max_stage = 9
	var back = RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	check(back.to_dict() == run.to_dict(), "el run se guarda y se carga igual")
	check(back.boosts == ["aire_extra", "mente_abierta"] and back.boost_capacity() == 7 and back.consumables == ["freno"], "los boosts y consumibles vuelven como Array[String] y con su capacidad")


func test_file() -> void:
	check(not SaveGame.exists() and SaveGame.read().is_empty() and SaveGame.peek_stage() == -1, "sin archivo no hay nada que continuar")
	check(SaveGame.write({"run": {"stage": 4}, "phase": "casino", "stage": 4}) and SaveGame.exists() and SaveGame.peek_stage() == 4, "se escribe y se lee")
	SaveGame.delete()
	check(not SaveGame.exists(), "borrar el archivo")
	var f := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	f.store_string("esto no es json {{{")
	f = null
	check(SaveGame.read().is_empty() and SaveGame.peek_stage() == -1, "un archivo danado se ignora")
	f = FileAccess.open(SaveGame.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 99, "run": {}, "phase": "tower", "stage": 2}))
	f = null
	check(SaveGame.read().is_empty(), "un archivo de otra version se ignora")
	f = FileAccess.open(SaveGame.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "stage": 2}))
	f = null
	check(SaveGame.read().is_empty(), "un archivo incompleto se ignora")
	SaveGame.delete()


func test_flow_tower() -> void:
	var a := make_main()
	await wait_tower(a)
	check(SaveGame.exists() and SaveGame.read().phase == "tower" and SaveGame.read().dirty == false, "al estar lista la torre se guarda (todavia sin empezar)")
	check(a.run.stage == a.stage_number and SaveGame.peek_stage() == a.stage_number, "el guardado dice en que etapa estas")
	# Continuar sin haber empezado: misma torre y sin costo
	a.run.claridad = 300
	a.save_game()
	var blocks_a: Array = a.torre.t.salas[0].d.bloques.duplicate(true)
	var c := make_main()
	await wait_tower(c)   # genera su propia torre y guarda; reescribimos el guardado de A para continuar desde ahi
	a.save_game()
	c.continue_game()
	check(c.torre.t.salas[0].d.bloques == blocks_a, "continuar vuelve a la misma torre")
	check(c.run.claridad == 300 and c.run.retries == 0, "si el intento no habia empezado, continuar no cuesta nada")
	check(not c.in_menu and c.hud_layer.visible and c.casino == null, "se vuelve al juego en la torre")
	# Primer movimiento: el intento ya empezo -> se guarda como 'sucio'
	a.run.stage = 1
	var cam: Array = a.torre.t.salas[0].d.camino   # (el primer paso del camino de la sala)
	a.torre.accion(Vector3i(int(cam[0][0]), 0, int(cam[0][1])), int(cam[0][2]))
	check(a.attempt_dirty and SaveGame.read().dirty == true, "al primer movimiento el guardado queda marcado como intento empezado")
	# Continuar con la sala empezada retoma la sala justo donde se dejó (posición, bloques y movimientos): no cuesta nada
	a.torre.accion(Vector3i(int(cam[1][0]), 0, int(cam[1][1])), int(cam[1][2])) if cam.size() > 1 else null
	var d := make_main()
	await wait_tower(d)
	a.save_game()
	var vidas: int = a.run.lives
	d.continue_game()
	check(d.run.retries == 0 and d.run.lives == vidas and d.run.claridad == 300, "continuar con la sala empezada no cuesta una vida ni claridad")
	check(d.torre.t.movs == a.torre.t.movs and d.torre.t.movs > 0, "...y conserva los movimientos de la sala")
	check(d.torre.t.motor.jugador == a.torre.t.motor.jugador and d.torre.t.motor.bloques == a.torre.t.motor.bloques, "...y el personaje y los bloques quedan donde estaban")
	check(d.torre.t.cosecha.sala == a.torre.t.cosecha.sala and d.torre.t.cosecha.streak == a.torre.t.cosecha.streak, "...y la claridad de la sala y la racha")
	# Aunque no queden vidas: la sala no se perdió, así que se continúa
	a.run.lives = 0
	a.save_game()
	var e := make_main()
	await wait_tower(e)
	a.save_game()
	e.continue_game()
	check(not e.run_over and e.torre != null and e.torre.t.movs == a.torre.t.movs, "sin vidas pero con la sala viva, continuar no termina el run")
	for m in [a, c, d, e]:
		m.queue_free()
	await process_frame
	SaveGame.delete()


## Morir guarda al instante: si se sale al menú sin reintentar, al continuar ya cuenta la muerte (una vida menos). Alt + F4 también guarda.
func test_death_saves() -> void:
	var a := make_main()
	await wait_tower(a)
	a.run.claridad = 500
	a.attempt_dirty = true
	a.save_game()
	check(SaveGame.read().dead == false, "vivo: el guardado no dice que murió")
	var lives_before: int = a.run.lives
	a.torre.perder("Caíste al vacío")
	await process_frame
	check(SaveGame.read().dead == true and a.lost_screen.visible, "al morir se guarda al instante, marcando la muerte")
	check(a.run.lives == lives_before, "(la vida se gasta recién al continuar o reintentar)")
	var b := make_main()
	await wait_tower(b)
	a.save_game()
	b.continue_game()
	check(b.run.lives == lives_before - 1 and b.run.retries == 1, "salir sin reintentar y continuar: ya costó una vida")
	check(not b.torre.t.muerta and SaveGame.read().dead == false, "y la torre empieza de cero (vivo)")
	# Sin vidas ni Tótem: al continuar el run termina
	a.run.lives = 0
	a.save_game()
	var c := make_main()
	await wait_tower(c)
	a.save_game()
	c.continue_game()
	check(c.run_over, "si ya no te quedaban vidas, continuar después de morir termina el run")
	# Alt + F4: guardado rápido
	var d := make_main()
	await wait_tower(d)
	SaveGame.delete()
	d.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(SaveGame.exists(), "al cerrar la ventana (Alt + F4) se guarda")
	for m in [a, b, c, d]:
		m.queue_free()
	await process_frame
	SaveGame.delete()


## Al continuar, la torre se retoma en el checkpoint de la última sala superada, con la claridad asegurada hasta ahí.
func test_checkpoint() -> void:
	var a := make_main()
	await wait_tower(a)
	a.run.claridad = 100
	for paso in a.torre.t.salas[0].d.camino:   # se supera la primera sala
		a.torre.accion(Vector3i(int(paso[0]), 0, int(paso[1])), int(paso[2]))
	check(a.torre.t.indice == 1, "se superó la primera sala")
	var banco: int = a.torre.t.cosecha.banco
	check(int(SaveGame.read().get("sala", -1)) == 1 and SaveGame.read().dirty == false, "al llegar al checkpoint se guarda solo (sala nueva, todavía sin empezar)")
	a.save_game()
	check(int(SaveGame.read().get("sala", -1)) == 1 and int(SaveGame.read().get("banco", -1)) == banco, "el guardado dice en qué checkpoint estás y cuánta claridad ya es tuya")
	var b := make_main()
	await wait_tower(b)
	a.save_game()
	b.continue_game()
	check(b.torre.t.indice == 1 and b.torre.t.cosecha.banco == banco and b.torre.t.movs == 0, "continuar retoma en el último checkpoint, con la claridad asegurada")
	check(b.run.lives == a.run.lives and b.run.retries == 0 and not b.run_over, "y no cuesta nada: pasar un checkpoint y cerrar el juego no es perder la sala")
	check(b.torre.t.salas[0].d.bloques == a.torre.t.salas[0].d.bloques, "y es la misma torre")
	a.queue_free()
	b.queue_free()
	await process_frame
	SaveGame.delete()


func test_flow_casino() -> void:
	var a := make_main()
	await wait_tower(a)
	a.run.claridad = 400
	a.torre.t.cosecha.sala = 20
	await a._torre_ganada()
	check(a.casino != null and SaveGame.read().phase == "casino" and int(SaveGame.read().run.claridad) == 420, "al entrar al casino se guarda con la claridad ya sumada")
	# cada tirada de la ruleta se guarda al resolverse (antes de la animacion)
	a.casino.quick = true
	a.casino.open_roulette()
	a.casino.screen.fast = true
	var before := int(SaveGame.read().run.claridad)
	a.casino.screen.spin()   # sin await: se cobra al instante
	check(int(SaveGame.read().run.claridad) != before or a.run.claridad != before, "la tirada se guarda en cuanto se cobra")
	check(int(SaveGame.read().run.claridad) == a.run.claridad, "lo guardado coincide con la claridad actual")
	var saved_claridad: int = a.run.claridad
	var stage_saved: int = a.stage_number
	await process_frame
	a.casino.close_roulette()
	# continuar: vuelve al casino con el mismo run
	var b := make_main()
	await wait_tower(b)
	a.save_game()
	b.continue_game()
	check(b.casino != null and b.run.claridad == saved_claridad and b.stage_number == stage_saved and b.run.towers_cleared == a.run.towers_cleared, "continuar vuelve al casino con el mismo run")
	check(b.run.towers_cleared == 1, "sin volver a sumar la torre superada")
	b.casino.quick = true
	b.casino.cell = b.casino.lay.exit
	b.casino.step(Vector2i(0, -1))
	var loading := SaveGame.read()
	check(str(loading.get("phase", "")) != "casino" and int(loading.stage) == stage_saved + 1, "al irse del casino (peaje pagado) se guarda la torre que sigue: al cerrar y volver no se repite el casino")
	var c := make_main()   # cerrar el juego ahora y volver: continúa la carga de la torre siguiente, no el casino
	await wait_tower(c)
	SaveGame.write(loading)   # (lo que había en disco al cerrar el juego justo después de pagar)
	c.continue_game()
	check(c.casino == null and c.stage_number == stage_saved + 1, "continuar después de pagar sigue la torre siguiente (sin volver al casino)")
	var guardia := 0
	while (b.generating or c.generating or b.torre == null or c.torre == null) and guardia < 3000:
		await process_frame
		guardia += 1
	check(b.stage_number == stage_saved + 1 and b.torre != null, "al salir del casino empieza la etapa siguiente")
	check(c.torre != null and c.stage_number == stage_saved + 1, "la partida continuada llega a la torre siguiente")
	for m in [a, b, c]:
		m.queue_free()
	await process_frame
	SaveGame.delete()


func test_end_deletes() -> void:
	var a := make_main()
	await wait_tower(a)
	check(SaveGame.exists(), "hay un guardado en una torre")
	a.end_run(false, "x")
	check(not SaveGame.exists(), "al terminar el run se borra el guardado")
	a.save_game()
	check(not SaveGame.exists(), "y con el run terminado no se vuelve a guardar")
	a.queue_free()
	await process_frame
	# el entrenamiento no guarda
	var t := make_main()
	await wait_tower(t)
	SaveGame.delete()
	t._set_training(true)
	t.save_game()
	check(not SaveGame.exists(), "el modo entrenamiento no guarda")
	t.queue_free()
	await process_frame


func test_menu_button() -> void:
	SaveGame.delete()
	var a := make_main()
	await wait_tower(a)
	a.open_main_menu()   # guarda al salir al menu
	check(SaveGame.exists() and a.main_menu.buttons["continuar"].visible and a.main_menu.buttons["continuar"].text.contains("etapa %d" % a.stage_number), "al volver al menu aparece Continuar con la etapa")
	check(a.main_menu.buttons["continuar"].primary and not a.main_menu.buttons["nueva"].primary, "Continuar pasa a ser el boton principal")
	a.main_menu.buttons["continuar"].pressed.emit()
	check(not a.in_menu and a.torre != null, "Continuar vuelve al juego")
	a.end_run(false)
	a.open_main_menu()
	check(not a.main_menu.buttons["continuar"].visible and a.main_menu.buttons["nueva"].primary, "sin guardado no hay Continuar")
	a.queue_free()
	await process_frame
