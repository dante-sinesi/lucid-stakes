extends SceneTree
## Captura las lecciones del tutorial con el motor de la torre. Uso: GAME_SANDBOX=1 godot --path . -s tests/capturas/shot_tutorial.gd -- PREFIJO
const Profile := preload("res://scripts/datos/profile.gd")
func _init() -> void:
	var pref: String = OS.get_cmdline_user_args()[0]
	Profile.path = "user://test_profile.json"
	Profile._loaded_from = ""
	Profile.mark_tutorial_done()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.2).timeout
	for i in [0, 1, 2, 3, 4]:
		await main.start_tutorial(i, true)
		await create_timer(1.0).timeout
		main.dialogue.hide_box()
		main._show_lesson_help()
		await create_timer(0.8).timeout
		root.get_texture().get_image().save_png("%s_%d.png" % [pref, i])
		if i == 0:   # la lección de la cámara también desde atrás: el tramo tapado se tiene que ver
			main.torre.yaw_target += 180.0
			await create_timer(1.5).timeout
			root.get_texture().get_image().save_png("%s_0_atras.png" % pref)
	quit(0)
