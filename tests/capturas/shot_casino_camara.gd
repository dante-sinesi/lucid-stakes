extends SceneTree
## Captura el casino con la cámara en el casino entero y con la cámara en el personaje (Opciones > General > Cámara del casino).
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_casino_camara.gd -- PREFIJO
const Profile := preload("res://scripts/datos/profile.gd")
const Settings := preload("res://scripts/datos/settings.gd")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	Profile.path = "user://shot_profile_camara.json"
	Profile.reset()
	Profile.mark_tutorial_done()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	await _frames(6)
	main.start_game("pesadilla", "media")
	await _frames(20)
	main.enter_casino()
	await _frames(40)
	for modo in ["sala", "personaje"]:
		Settings.set_value("casino_camara", modo)
		await _frames(60)
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [args[0], modo])
	quit()
