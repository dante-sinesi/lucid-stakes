extends SceneTree
## Captura del selector de dificultad y de la pantalla de derrota con las teclas nuevas. Uso: GAME_SANDBOX=1 godot --path . -s tests/capturas/shot_dificultad.gd -- PREFIJO
const Profile := preload("res://scripts/datos/profile.gd")
func _init() -> void:
	var pref: String = OS.get_cmdline_user_args()[0]
	Profile.path = "user://test_profile.json"
	Profile._loaded_from = ""
	Profile.mark_tutorial_done()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.2).timeout
	main._on_new_game("pesadilla")
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png(pref + "_1.png")
	# bajar con S (WASD) y elegir Difícil con Espacio
	var ev := InputEventKey.new()
	ev.keycode = KEY_S
	ev.physical_keycode = KEY_S
	ev.pressed = true
	Input.parse_input_event(ev)
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(pref + "_2.png")
	print("foco: ", main.difficulty_screen.get_viewport().gui_get_focus_owner().name if main.difficulty_screen.get_viewport().gui_get_focus_owner() != null else "-")
	var sp := InputEventKey.new()
	sp.keycode = KEY_SPACE
	sp.physical_keycode = KEY_SPACE
	sp.pressed = true
	Input.parse_input_event(sp)
	await create_timer(0.1).timeout
	var sr := InputEventKey.new()
	sr.keycode = KEY_SPACE
	sr.physical_keycode = KEY_SPACE
	sr.pressed = false
	Input.parse_input_event(sr)
	await create_timer(0.5).timeout
	print("confirmación abierta: ", main.confirm_box.visible, " dificultad del run: ", main.run.dificultad, " en menú: ", main.in_menu, " abierto: ", main.difficulty_screen.visible)
	quit(0)
