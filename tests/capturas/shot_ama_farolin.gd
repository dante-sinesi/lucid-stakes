extends SceneTree
## Las travesuras de Ama con Farolín, una por una, en el checkpoint de la primera sala de una torre de la prueba Travesuras.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_ama_farolin.gd -- PREFIJO TRAVESURA [SEMILLA]
##   TRAVESURA: mirar_llama, frotarse, sombrero o acurrucarse. Saca ocho cuadros repartidos en lo que dura.
const Profile := preload("res://scripts/datos/profile.gd")
const AF := preload("res://scripts/personajes/ama_farolin.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var pref: String = args[0]
	var que: String = args[1]
	var semilla := int(args[2]) if args.size() > 2 else 77
	Profile.path = "user://shot_profile_ama.json"
	Profile.reset()
	Profile.mark_tutorial_done()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	for k in 6:
		await process_frame
	main.start_game("pesadilla", "media")
	for k in 6:
		await process_frame
	main.run.trial_schedule = {1: "travesuras"}
	main.new_tower(semilla)
	for k in 6:
		await process_frame
	while main.generating or main.torre == null:
		await process_frame
	var torre = main.torre
	while torre.gatito_actuando or not torre.gatito_nodo.visible:   # (espera a que Ama termine y llegue al checkpoint)
		await process_frame
	Engine.time_scale = 8.0
	while torre._gatito_pose != "bollito":
		await process_frame
	Engine.time_scale = 1.0
	torre.faro_modelo.dormir(false)
	await create_timer(1.0).timeout
	# la cámara mira el checkpoint: el personaje se pone ahí (la cámara lo sigue) y se acerca
	torre.gato_nodo.position = torre.farolin.position + Vector3(0, 0.2, 0)
	torre.gato_nodo.visible = false
	torre.cam_pitch = 40.0
	torre._poner_camara(true)
	torre.vivo.visible = false   # (sólo se ve a Farolín y a Ama; la sala tapa el checkpoint desde acá)
	torre.zoom = 1.5
	torre.cam.size = 1.5
	torre._gatito_pose = ""
	print("faro ", torre.farolin.position, " vis ", torre.farolin.visible, " gato ", torre.gatito_nodo.position, " vis ", torre.gatito_nodo.visible, " esq ", torre._faro_esquina)
	var tareas := {"mirar_llama": 3.2, "frotarse": 4.9, "sombrero": 8.6, "acurrucarse": 1.0}
	var dur: float = tareas[que]
	var corrutina: Callable = func(): await AF.hacer(que, torre, func(): return true) if que != "acurrucarse" else await AF.acurrucarse(torre, func(): return true)
	corrutina.call()
	for i in 8:
		await create_timer(dur / 8.0).timeout
		root.get_viewport().get_texture().get_image().save_png("%s_%d.png" % [pref, i])
	quit()
