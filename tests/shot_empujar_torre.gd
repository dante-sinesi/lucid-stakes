extends SceneTree
## Verificación a ojo: un bloque que se empuja se ve recorrer el camino. Uso: GAME_SANDBOX=1 godot --path . -s tests/shot_empujar_torre.gd -- PREFIJO
const Profile := preload("res://scripts/profile.gd")
const Motor := preload("res://salas_nuevas/motor.gd")
func _init() -> void:
	var pref: String = OS.get_cmdline_user_args()[0]
	Profile.path = "user://test_profile.json"
	Profile._loaded_from = ""
	Profile.mark_tutorial_done()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	main.start_game()
	await create_timer(0.5).timeout
	main.dice.auto_start = true
	main.dice.set_ready(true)
	await create_timer(1.5).timeout
	# una sala de prueba: el jugador sobre un bloque de la fila y otro bloque adelante que se empuja
	var m = Motor.nueva(6, Vector3i(1, 2, 1))
	m.poner(Vector3i(1, 1, 1), "n")
	m.poner(Vector3i(2, 2, 1), "n")
	m.poner(Vector3i(2, 1, 1), "n")
	m.poner(Vector3i(3, 1, 1), "f")
	main.nueva.t.motor = m
	main.nueva._refrescar(false)
	await create_timer(0.3).timeout
	var pos0 = main.nueva.vivo.get_children().map(func(n): return n.position)
	main.nueva.accion(Vector3i(1, 0, 0), Motor.Modo.AGARRAR)
	for k in 5:
		await create_timer(0.04).timeout
		var lista: Array = []
		for n in main.nueva.vivo.get_children():
			if n is Node3D:
				lista.append(n.position)
		print("k=", k, " ", lista)
		root.get_texture().get_image().save_png("%s_%d.png" % [pref, k])
	quit(0)
