extends SceneTree
## Captura la zona de una bomba (cubos rojos translúcidos que titilan): dos fotos con medio ciclo de diferencia.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 -s tests/capturas/shot_zona_bomba.gd -- PREFIJO
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
	for x in 4:
		for z in 3:
			m.poner(Vector3i(x, 1, z), "n")
	m.poner(Vector3i(3, 2, 1), "b9")
	m.poner(Vector3i(4, 1, 1), "f")
	main.torre.t.motor = m
	main.torre._refrescar(false)
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("%s_a.png" % pref)
	await create_timer(1.1).timeout
	root.get_texture().get_image().save_png("%s_b.png" % pref)
	quit(0)
