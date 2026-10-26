extends SceneTree
## Captura la derrota por empujar el último bloque que sostiene la sala (cámara lenta): una foto cada 0,4 s.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1000x600 -s tests/capturas/shot_derrota_empuje.gd -- PREFIJO
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
	m.poner(Vector3i(1, 1, 1), "n")
	m.poner(Vector3i(2, 1, 1), "n")
	m.poner(Vector3i(2, 2, 1), "n")
	m.poner(Vector3i(1, 3, 1), "f")
	main.torre.t.motor = m
	main.torre._refrescar(false)
	await create_timer(0.3).timeout
	var r: Dictionary = main.torre.accion(Vector3i(1, 0, 0), Motor.Modo.AGARRAR)
	print(main.torre.t.motor.bloques, main.torre.t.motor.jugador, " evento=", r.get("evento"), " ok=", r.get("ok"), " tipo=", main.torre._tipo_anim)
	if str(r.get("evento")) == "muerte":
		var previo: float = main.torre.animar_derrota("prueba")
		print("previo=", previo)
	for k in 12:
		await create_timer(0.4).timeout
		root.get_texture().get_image().save_png("%s_%02d.png" % [pref, k])
	quit(0)
