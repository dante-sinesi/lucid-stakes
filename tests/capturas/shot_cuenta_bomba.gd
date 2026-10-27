extends SceneTree
## La cuenta de las bombas del juego (torre/cuenta_bomba.gd): tres bombas (una activa con la mecha corriendo, dos lejos, una de dos cifras) y una segunda toma con un muro de bloques
## delante de una de ellas, para ver que los bloques tapan la cuenta. Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 -s tests/capturas/shot_cuenta_bomba.gd -- PREFIJO
const Profile := preload("res://scripts/datos/profile.gd")
const Motor := preload("res://torre/motor.gd")


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
	var m = Motor.crear(8, Vector3i(1, 2, 1))
	for x in 6:
		for z in 5:
			m.poner(Vector3i(x, 1, z), "n")
	m.poner(Vector3i(2, 2, 1), "b9")    # cerca del jugador: activa
	m.poner(Vector3i(4, 2, 3), "b3")    # lejos
	m.poner(Vector3i(4, 2, 0), "b12")   # lejos, dos cifras
	m.poner(Vector3i(6, 1, 2), "f")
	main.torre.t.motor = m
	main.torre._refrescar(false)
	await create_timer(0.4).timeout
	for c in main.find_children("*", "Control", true, false):   # (fuera el cuadro del tabernero y el HUD: solo importa la torre)
		if "ialog" in str(c.name) or "ialog" in str(c.get_script().resource_path if c.get_script() else ""):
			c.visible = false
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("%s_a.png" % pref)
	for x in range(3, 6):   # un muro delante de la bomba del fondo
		for y in range(2, 4):
			m.poner(Vector3i(x, y, 4), "n")
	main.torre._refrescar(false)
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png("%s_b.png" % pref)
	print("listo")
	quit(0)
