extends SceneTree
## Captura una sala con bloques a distintas profundidades desde cuatro ángulos (y uno más bajo), para juzgar si se entiende dónde está cada bloque.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1000x600 -s tests/capturas/shot_profundidad.gd -- PREFIJO [modo_profundidad]
const Profile := preload("res://scripts/datos/profile.gd")
const Motor := preload("res://torre/motor.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var pref: String = args[0]
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
	if args.size() > 1:
		main._set_depth_mode(int(args[1]))
	var Graphics = load("res://scripts/ui/graphics.gd")
	print("sombras: ", Graphics.value("shadows"), " sol: ", main._sun.shadow_enabled)
	if args.size() > 2 and args[2] == "B":   # (prueba: más sol y menos luz ambiente, con sombras suaves)
		main._sun.shadow_enabled = true
		main._sun.shadow_blur = 1.6
		main._sun.light_energy = 1.6
		main.env.ambient_light_energy = 0.4
	if args.size() > 2 and args[2] == "real":   # (la primera sala de verdad, tal como sale en el juego)
		await create_timer(0.5).timeout
		root.get_texture().get_image().save_png("%s_real.png" % pref)
		quit(0)
		return
	var m = Motor.crear(8, Vector3i(1, 2, 1))
	for p in [[1, 1, 1], [2, 1, 1], [2, 2, 2], [1, 1, 3], [3, 1, 3], [3, 2, 3], [0, 1, 2], [2, 3, 3], [4, 1, 1], [4, 2, 1]]:
		m.poner(Vector3i(p[0], p[1], p[2]), "n")
	m.poner(Vector3i(3, 3, 3), "f")
	main.torre.t.motor = m
	main.torre._refrescar(false)
	await create_timer(0.3).timeout
	var vistas := [[45.0, -35.264], [135.0, -35.264], [225.0, -35.264], [315.0, -35.264]]
	for i in vistas.size():
		main.torre.yaw_target = vistas[i][0]
		main.torre.cam_pitch = vistas[i][1]
		main.torre._poner_camara(false)
		await create_timer(0.3).timeout
		root.get_texture().get_image().save_png("%s_%d.png" % [pref, i])
	quit(0)
