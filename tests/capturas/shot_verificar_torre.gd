extends SceneTree
## Verificación a ojo: temblor gradual, caída del personaje al perder, reintentar a mitad de la caída y la pausa con etapa y peaje.
## Uso: GAME_SANDBOX=1 godot --path . -s tests/capturas/shot_verificar_torre.gd -- PREFIJO
const Profile := preload("res://scripts/datos/profile.gd")
func _init() -> void:
	Profile.path = "user://test_profile.json"   # (el perfil de pruebas, nunca el real)
	Profile._loaded_from = ""
	Profile.mark_tutorial_done()   # (si no, la primera vez empieza el tutorial en la taberna)
	var pref: String = OS.get_cmdline_user_args()[0]
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	main.start_game()
	await create_timer(0.5).timeout
	main.dice.auto_start = true
	main.dice.set_ready(true)
	await create_timer(1.2).timeout
	var cam: Array = main.torre.t.salas[0].d.camino
	var sala = main.torre.t.salas[0]
	print("camino ", cam.size(), " max_mov ", main.torre.t.max_mov())
	sala.max_mov = cam.size() + 6
	# 1) temblor: con el 40 %, el 75 % y el 95 % de los movimientos gastados (se fija el contador)
	for k in 3:
		main.torre.t.movs = int(sala.max_mov * [0.4, 0.75, 0.95][k])
		await create_timer(0.4).timeout
		root.get_texture().get_image().save_png("%s_temblor%d.png" % [pref, k])
	main.torre.t.movs = 0
	# 2) perder: se acaban los movimientos
	var a0 = cam[0]
	main.torre.t.movs = main.torre.t.max_mov() - 1
	main.torre.accion(Vector3i(int(a0[0]), 0, int(a0[1])), int(a0[2]))
	print("muerta ", main.torre.t.muerta)
	await create_timer(0.9).timeout
	root.get_texture().get_image().save_png(pref + "_caida1.png")
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(pref + "_caida2.png")
	# 3) reintentar a mitad de la caída
	main.request_restart()
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png(pref + "_reintento.png")
	await create_timer(3.0).timeout
	root.get_texture().get_image().save_png(pref + "_reintento_despues.png")
	# 4) pausa
	main.pause_game()
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(pref + "_pausa.png")
	quit(0)
