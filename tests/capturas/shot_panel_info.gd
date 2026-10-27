extends SceneTree
## Captura la torre con el panel de información abierto y la pausa (sin la columna ni el cartel), para juzgar cómo queda.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_panel_info.gd -- PREFIJO [prueba]
const Profile := preload("res://scripts/datos/profile.gd")
const Settings := preload("res://scripts/datos/settings.gd")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var prefijo: String = args[0] if args.size() > 0 else "panel"
	Profile.path = "user://shot_profile_panel.json"
	Profile.reset()
	Profile.mark_tutorial_done()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	await _frames(6)
	main.start_game("pesadilla", "media")
	await _frames(40)
	Settings.set_value("panel_modo", "alternar")
	main.run.claridad = 340
	main.run.boosts.append("segundo_aliento")
	main.run.boosts.append("madrugada")
	main.run.consumables.append("totem")
	main.panel_info.abrir(main._panel_datos())
	main.panel_items.abrir(main._panel_items_datos())
	await _frames(40)
	root.get_viewport().get_texture().get_image().save_png("%s_panel.png" % prefijo)
	main.panel_info.cerrar(true)
	main.panel_items.cerrar(true)
	main.pause_game()
	await _frames(30)
	root.get_viewport().get_texture().get_image().save_png("%s_pausa.png" % prefijo)
	quit()
