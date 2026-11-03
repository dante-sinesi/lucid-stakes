extends SceneTree
## La taberna del tutorial: el tabernero habla y, al terminar, se puede caminar con la ayuda de WASD a la vista; tras unos pasos se marca el portal de atrás.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_taberna_tutorial.gd -- PREFIJO
const Profile := preload("res://scripts/datos/profile.gd")
const Story := preload("res://scripts/datos/story.gd")
func _init() -> void:
	var pref: String = OS.get_cmdline_user_args()[0]
	Profile.path = "user://test_profile.json"
	Profile._loaded_from = ""
	Profile.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	await create_timer(1.2).timeout
	main.start_tutorial()
	await create_timer(2.0).timeout
	root.get_texture().get_image().save_png("%s_1_habla.png" % pref)
	main.dialogue.skip_all()
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png("%s_2_wasd.png" % pref)
	for i in Story.INTRO_PASOS:
		main._on_taberna_movida("mover_adelante")
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png("%s_3_portal.png" % pref)
	quit(0)
