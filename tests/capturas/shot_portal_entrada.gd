extends SceneTree
## Captura la llegada al portal de la torre (el personaje entra al cubo en un solo desplazamiento horizontal) en varios instantes. Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_portal_entrada.gd -- PREFIJO
const Profile := preload("res://scripts/datos/profile.gd")
const Graphics := preload("res://scripts/ui/graphics.gd")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	Profile.path = "user://shot_profile_portal.json"
	Profile.reset()
	Profile.mark_tutorial_done()
	Graphics.set_value("silhouette", true)   # (la transparencia del personaje, para verlo cuando lo tapa el cubo)
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	await _frames(6)
	main.start_game("pesadilla", "media")
	await _frames(30)
	var tj = main.torre
	tj.t.indice = tj.t.salas.size() - 1   # (la última sala: el portal a la vista)
	tj._refrescar(true)
	await _frames(20)
	tj.gato_nodo.position = tj.portal.position + Vector3(-1.0, -0.5, 0)   # (en la celda de al lado, a la altura del portal: el último paso lo mete)
	tj.vista_sala = false
	Engine.time_scale = 0.1   # (guardar cada imagen tarda: con el tiempo del juego a 0,1x el intervalo de 0,16 s es exacto)
	tj._entrar_portal()
	root.get_viewport().get_texture().get_image().save_png("%s_00.png" % args[0])
	for i in 10:
		await create_timer(0.16).timeout
		root.get_viewport().get_texture().get_image().save_png("%s_%02d.png" % [args[0], i + 1])
	quit()
