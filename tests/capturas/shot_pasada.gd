extends SceneTree
## Pasada de verificación a ojo: el menú principal (con el fondo animado, dos instantes), el diálogo del tabernero sobre la torre y el selector de escenarios.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_pasada.gd -- PREFIJO
const Profile := preload("res://scripts/datos/profile.gd")
const Story := preload("res://scripts/datos/story.gd")


func _foto(nombre: String) -> void:
	root.get_texture().get_image().save_png(nombre)


func _init() -> void:
	var pref: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "capturas/pasada"
	Profile.path = "user://test_profile.json"   # (el perfil de pruebas, nunca el real)
	Profile._loaded_from = ""
	Profile.mark_tutorial_done()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.5).timeout
	_foto(pref + "_1_menu_a.png")
	await create_timer(2.0).timeout
	_foto(pref + "_2_menu_b.png")
	main.start_game()
	await create_timer(0.5).timeout
	main.dice.auto_start = true
	main.dice.set_ready(true)
	await create_timer(2.0).timeout
	main.dialogue.show_lines(["Cada ficha es un pedazo de despertar. ¿Cuánto vas a arriesgar?", "Y ojo: dentro de 2 torres te espera una prueba, «Mareo». Cada tanto te da un mareo y la cámara se cae."], Story.SPEAKER, true, true)
	await create_timer(1.2).timeout
	_foto(pref + "_3_dialogo_torre.png")
	quit(0)
