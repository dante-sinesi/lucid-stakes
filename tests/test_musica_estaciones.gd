extends SceneTree
## La música de Vivaldi del juego: están los cuatro .ogg (Primavera en el menú, Verano en las torres, Otoño en los casinos, Invierno en las pruebas) y la torre elige la pista según sea o no una prueba.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_musica_estaciones.gd

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	for t in ["menu", "torre", "casino", "pruebas"]:
		check(ResourceLoader.exists("res://audio/music/%s.ogg" % t), "está la pista %s" % t)
		var s: AudioStream = load("res://audio/music/%s.ogg" % t)
		check(s != null and s.get_length() > 300.0, "la pista %s trae los tres movimientos (más de 5 minutos)" % t)
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	main.training = false
	main.run.trial_schedule = {3: "niebla"}
	check(main._tower_music(3) == "pruebas", "en una prueba suena el Invierno")
	check(main._tower_music(2) == "torre" and main._tower_music(4) == "torre", "en las torres comunes suena el Verano")
	main.training = true
	check(main._tower_music(3) == "torre", "en el entrenamiento y el tutorial no hay pruebas")
	main._cancel_jobs()
	main.queue_free()
	await process_frame
	print("tests de la música de las estaciones terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
