extends SceneTree
## Verificación a ojo del checkpoint: la cámara y la caída de la sala anterior, cuadro a cuadro.
## Uso: GAME_SANDBOX=1 godot --path . -s tests/shot_checkpoint_torre.gd -- PREFIJO
const Profile := preload("res://scripts/profile.gd")
func _init() -> void:
	var pref: String = OS.get_cmdline_user_args()[0]
	Profile.path = "user://test_profile.json"   # (el perfil de pruebas, nunca el real)
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
	var cam: Array = main.nueva.t.salas[0].d.camino
	for i in cam.size() - 1:
		main.nueva.accion(Vector3i(int(cam[i][0]), 0, int(cam[i][1])), int(cam[i][2]))
		await create_timer(0.35).timeout
	root.get_texture().get_image().save_png(pref + "_0antes.png")
	var a = cam[cam.size() - 1]
	main.nueva.accion(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
	for k in 8:
		await create_timer(0.05).timeout
		print("k=", k, " pivot=", main.nueva.pivot.position, " gato=", main.nueva.gato_nodo.position)
		root.get_texture().get_image().save_png("%s_%d.png" % [pref, k + 1])
	quit(0)
