extends SceneTree
## El panel de información (Tab): lo que cuenta, que se abre y se cierra, los modos mantener y alternar, que la pausa lo esconde y que V es la vista de toda la torre.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/unitarios/test_panel_info.gd
const Profile := preload("res://scripts/datos/profile.gd")
const Contratos := preload("res://scripts/datos/contratos.gd")
const Controls := preload("res://scripts/entrada/controls.gd")
const Settings := preload("res://scripts/datos/settings.gd")
var fallos := 0


func _ok(c: bool, m: String) -> void:
	print(("ok  " if c else "FALLA ") + m)
	if not c:
		fallos += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _tecla(main, k: Key, apretada: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = apretada
	main._input(e)


func _tecla_torre(main, k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	main.torre._input(e)


func _init() -> void:
	Profile.path = "user://test_profile_panel.json"
	Profile.reset()
	Settings.set_value("panel_modo", "mantener")
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	await _frames(4)
	main.start_game("pesadilla", "media")
	await _frames(4)
	var d: Dictionary = main._panel_datos()
	_ok(d.has("etapa") and d.has("sala") and d.has("claridad") and d.has("movs"), "los datos traen etapa, sala, claridad y movimientos")
	_ok(Controls.key_of("panel_info") == KEY_TAB and Controls.key_of("vista_torre") == KEY_V, "Tab abre el panel y V es la vista de toda la torre")
	Settings.set_value("panel_modo", "alternar")   # (en mantener se cierra solo porque la tecla no está apretada)
	main.panel_info.abrir(d)
	await _frames(30)
	_ok(main.panel_info.abierto and main.panel_info.visible, "el panel se abre")
	_ok(main.panel_info.get_node("ventana").offset_left >= -1.0, "el panel termina de entrar por la izquierda")
	main.panel_info.cerrar()
	await _frames(30)
	_ok(not main.panel_info.abierto and not main.panel_info.visible, "el panel se cierra y se esconde")
	# modo alternar: un toque abre y otro cierra
	Settings.set_value("panel_modo", "alternar")
	if main._panel_permitido():
		main.panel_info.abrir(main._panel_datos())
		main.panel_info.cerrar(true)
	main.panel_info.abrir(main._panel_datos())
	_ok(main.panel_info.abierto, "en alternar queda abierto sin mantener la tecla")
	main._panel_vigilar()
	_ok(main.panel_info.abierto, "en alternar soltar la tecla no lo cierra")
	main.panel_info.cerrar(true)
	# modo mantener: sin la tecla apretada se cierra solo
	Settings.set_value("panel_modo", "mantener")
	main.panel_info.abrir(main._panel_datos())
	main._panel_vigilar()
	await _frames(30)
	_ok(not main.panel_info.abierto, "en mantener se cierra cuando se suelta la tecla")
	# la pausa lo esconde y deja el título y los botones
	main.panel_info.abrir(main._panel_datos())
	main.pause_game()
	_ok(not main.panel_info.abierto and not main.panel_info.visible, "al pausar el panel se esconde")
	main.resume_game()
	Settings.set_value("panel_modo", "mantener")
	# el panel de boosts y consumibles (derecha): lista lo que se tiene y bloquea el juego, menos la cámara
	main.run.boosts.append("segundo_aliento")
	main.run.consumables.append("totem")
	var di: Dictionary = main._panel_items_datos()
	_ok(di.boosts.size() == 1 and di.consumibles.size() == 1 and str(di.boosts[0].desc) != "", "los datos del panel de ítems traen los boosts y consumibles con su descripción")
	Settings.set_value("panel_modo", "alternar")
	main.panel_items.abrir(di)
	await _frames(30)
	_ok(main.panel_items.abierto and main.panel_items.get_node("ventana").offset_right <= 1.0, "el panel de ítems entra por la derecha")
	main._panel_vigilar()
	_ok(main.torre.solo_camara, "con un panel abierto la torre sólo mueve la cámara")
	var antes: int = main.torre.t.movs
	_tecla_torre(main, KEY_W)
	_ok(main.torre.t.movs == antes, "con un panel abierto no se juega")
	main.panel_items.cerrar(true)
	main._panel_vigilar()
	_ok(not main.torre.solo_camara, "al cerrar el panel se vuelve a jugar")
	Settings.set_value("panel_modo", "mantener")
	# el cursor: W y S recorren, Espacio abre el menú de la fila, tirar saca el ítem, usar cierra los paneles y abandonar saca el contrato
	main.run.boosts.clear()
	main.run.consumables.clear()
	main.run.boosts.append_array(["segundo_aliento", "madrugada"])
	main.run.consumables.append("totem")
	main.run.contratos = {"cartelera": [], "activos": [{"id": 1, "obj": "racha", "r": 0, "n": 2, "pct": 0.1, "monto": 120, "fianza": 40}], "iniciada": true, "rotaciones": 0, "torre": {}, "siguiente_id": 10}
	Settings.set_value("panel_modo", "alternar")
	_tecla(main, KEY_TAB, true)
	_ok(main.panel_info.abierto and main.panel_items.abierto, "Tab abre los dos paneles")
	_ok(main.panel_items.filas() == 3 and main.panel_info.filas() == 1, "el panel de ítems tiene 3 filas elegibles (2 boosts y 1 consumible) y el otro 1 (el contrato)")
	_ok(main._foco == 1 and main._foco_i == 0, "el cursor empieza en el primer ítem")
	_tecla(main, KEY_S, true)
	_ok(main._foco_i == 1, "S baja el cursor")
	_tecla(main, KEY_W, true)
	_tecla(main, KEY_SPACE, true)
	_ok(main._menu == ["tirar"], "Espacio sobre un boost abre su menú: tirar")
	_tecla(main, KEY_SPACE, true)
	_ok(main.run.boosts == ["madrugada"] and main._menu.is_empty(), "elegir tirar saca el boost")
	_tecla(main, KEY_S, true)
	_tecla(main, KEY_SPACE, true)
	_ok(main._menu == ["usar", "tirar"], "sobre un consumible el menú agrega usar")
	_tecla(main, KEY_S, true)
	_tecla(main, KEY_SPACE, true)
	_ok(main.run.consumables.is_empty(), "elegir tirar saca el consumible")
	_tecla(main, KEY_A, true)
	_ok(main._foco == 0, "A pasa al panel de la izquierda (contratos)")
	_tecla(main, KEY_SPACE, true)
	_ok(main._menu == ["abandonar"], "sobre un contrato el menú es abandonar")
	_tecla(main, KEY_ESCAPE, true)
	_ok(main._menu.is_empty() and Contratos.activos(main.run).size() == 1 and main.panel_info.abierto, "Esc cierra el menú sin hacer nada (y sin pausar)")
	_tecla(main, KEY_SPACE, true)
	_tecla(main, KEY_SPACE, true)
	_ok(Contratos.activos(main.run).is_empty() and not main.panel_info.abierto, "abandonar saca el contrato y cierra los paneles")
	Settings.set_value("panel_modo", "mantener")
	if fallos == 0:
		print("panel de información: todo bien")
	print("tests del panel de información terminados, fallos: %d" % fallos)
	quit(1 if fallos > 0 else 0)
