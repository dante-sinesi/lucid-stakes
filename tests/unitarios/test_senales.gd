extends SceneTree
## Las señales sin texto que reemplazan a los avisos flotantes: rebobinar y cancelado, el casillero que rechaza, el ítem que vuela y las ventanas de claridad y de logro.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_senales.gd

const SenalPantalla := preload("res://scripts/ui/senal_pantalla.gd")
const ItemBar := preload("res://scripts/ui/item_bar.gd")
const ItemVuela := preload("res://scripts/ui/item_vuela.gd")
const ResumenClaridad := preload("res://scripts/ui/resumen_claridad.gd")
const VentanaLogro := preload("res://scripts/ui/ventana_logro.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Profile := preload("res://scripts/datos/profile.gd")

var fallos := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fallos += 1
		print("FAIL: ", label)


func _init() -> void:
	Profile.path = "user://test_profile.json"
	Profile.reset()
	await test_senal()
	await test_casillero_y_vuelo()
	await test_resumen()
	await test_en_el_juego()
	Profile.reset()
	print("tests de las señales terminados, fallos: ", fallos)
	quit(1 if fallos > 0 else 0)


func test_senal() -> void:
	var s := SenalPantalla.new()
	root.add_child(s)
	check(not s.visible, "la señal empieza oculta")
	for tipo in [SenalPantalla.Tipo.REBOBINAR, SenalPantalla.Tipo.NO_REBOBINAR, SenalPantalla.Tipo.RECHAZO, SenalPantalla.Tipo.CANDADO]:
		s.mostrar(tipo)
		await process_frame
		check(s.visible and s.modulate.a > 0.9, "la señal %d se ve" % tipo)
	s.mostrar(SenalPantalla.Tipo.RECHAZO, Vector2(300, 200))
	check(s._punto == Vector2(300, 200), "la señal de rechazo se puede poner en un punto de la pantalla")
	s.ocultar()
	check(not s.visible, "se oculta")
	s.queue_free()


func test_casillero_y_vuelo() -> void:
	var run := RunState.new()
	run.consumables.assign(["freno", "totem"])
	var barra := ItemBar.new()
	root.add_child(barra)
	barra.setup(run, ItemBar.Kind.CONSUMABLE, true)
	await process_frame
	barra.rechazar(1)
	check(barra.slots[1]._rechazo > 0.9 and barra.slots[0]._rechazo == 0.0, "rechazar hace temblar sólo el casillero indicado")
	barra.rechazar(99)   # (un casillero que no existe no rompe nada)
	check(barra.rect_de(0).size.x > 10.0 and barra.rect_de(99).size == Vector2.ZERO, "el casillero sabe dónde está en pantalla (y uno que no existe da un rectángulo vacío)")
	var n := root.get_child_count()
	ItemVuela.volar(root, "totem", barra.rect_de(1))
	await process_frame
	check(root.get_child_count() == n + 1, "al usar un ítem se lanza el vuelo de su ícono")
	await create_timer(1.8).timeout
	check(root.get_child_count() == n, "el vuelo termina y se limpia solo")
	barra.queue_free()


func test_resumen() -> void:
	var r := ResumenClaridad.new()
	root.add_child(r)
	var cerrado := [0]
	r.cerrado.connect(func(): cerrado[0] += 1)
	r.mostrar("Entras al casino", 420, [{"id": "", "nombre": "Torre", "valor": 310}, {"id": "", "nombre": "Dados", "valor": 0}, {"id": "caja_fuerte", "nombre": "Caja fuerte", "valor": 63}])
	await process_frame
	check(r.visible and r.filas_mostradas.size() == 2, "sólo se muestran las filas que sumaron algo")
	check(r.entrada_counter.value == 420 and r.suma_counter.value == 373 and r.total_counter.value == 793, "la cuenta: entrada + lo añadido = total (420 + 373 = 793)")
	r.cerrar()
	check(not r.visible and cerrado[0] == 1, "se cierra y avisa")
	r.cerrar()
	check(cerrado[0] == 1, "cerrarla de nuevo no avisa otra vez")
	r.queue_free()
	var v := VentanaLogro.new()
	root.add_child(v)
	v.mostrar("¡Personaje nuevo!", ["Conejito"])
	await process_frame
	check(v.visible and v.lista.get_child_count() == 1, "la ventana de logro muestra una línea por logro")
	v.cerrar()
	check(not v.visible, "y se cierra")
	v.queue_free()


func test_en_el_juego() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	await process_frame
	while main.generating or main.torre == null:
		await process_frame
	check(not main.has_method("_flash"), "el juego ya no tiene carteles de texto flotantes")
	# deshacer sin nada que deshacer no muestra nada; un escenario que no deja deshacer muestra el cancelado
	main.run.consumables.assign(["freno"])
	main.left_bar.refresh()
	main.use_consumable_slot(0)
	await process_frame
	check(main.run.consumables.is_empty(), "un consumible que funciona se gasta")
	var vuelos := 0
	for ch in main.hud_layer.get_children():
		if ch.name.begins_with("item_vuela"):
			vuelos += 1
	check(vuelos >= 1, "y su ícono vuela al medio (sin texto)")
	main.run.consumables.assign(["totem"])
	main.left_bar.refresh()
	main.use_consumable_slot(0)
	check(main.run.consumables == ["totem"] and main.left_bar.slots[0]._rechazo > 0.9, "el Tótem no se usa a mano: el casillero tiembla y no se gasta")
	main.run.lives = 3
	main.run.consumables.assign(["vida_extra"])
	main.left_bar.refresh()
	main.use_consumable_slot(0)
	check(main.run.consumables == ["vida_extra"] and main.left_bar.slots[0]._rechazo > 0.9, "una Vida extra con todas las vidas no se gasta: el casillero tiembla")
	main.run.scenario_id = "sin_piedad"
	main.undo_move()
	check(main.senal.visible, "un escenario que no deja deshacer muestra el cancelado (sin texto)")
	main.queue_free()
	await process_frame
