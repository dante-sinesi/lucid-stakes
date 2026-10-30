extends SceneTree
## V alterna entre la vista de sala (la cámara abarca toda la sala y no sigue al personaje) y la vista del personaje; ya no hay vista de toda la torre.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_vista_sala.gd

var fallos := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fallos += 1
		print("FAIL: ", label)


func _tecla_v() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = KEY_V
	ev.physical_keycode = KEY_V
	ev.pressed = true
	return ev


func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	await process_frame
	while main.generating or main.torre == null:
		await process_frame
	var tj = main.torre
	check(tj.get("panorama") == null, "ya no existe la vista de toda la torre")
	check(not tj.vista_sala, "empieza en la vista del personaje")
	var zoom_personaje: float = tj.zoom
	tj._input(_tecla_v())
	for i in 40:
		await process_frame
	var c: Dictionary = tj._gatito_camara()
	check(tj.vista_sala, "V pasa a la vista de sala")
	check(absf(tj.cam.size - float(c.tam)) < 0.2, "en la vista de sala el zoom contiene toda la sala (%.1f / %.1f)" % [tj.cam.size, c.tam])
	check(tj.pivot.position.distance_to(c.foco) < 0.3, "y la cámara está en el centro de la sala")
	tj._input(_tecla_v())
	for i in 40:
		await process_frame
	check(not tj.vista_sala, "V otra vez vuelve a la vista del personaje")
	check(absf(tj.cam.size - zoom_personaje) < 0.2, "con su zoom de antes (%.1f / %.1f)" % [tj.cam.size, zoom_personaje])
	var foco: Vector3 = tj.gato_nodo.position + Vector3(0, 0.5, 0)
	check(tj.pivot.position.distance_to(foco) < 0.6, "y la cámara sigue al personaje")
	main.queue_free()
	print("tests de la vista de sala terminados, fallos: ", fallos)
	quit(1 if fallos > 0 else 0)
