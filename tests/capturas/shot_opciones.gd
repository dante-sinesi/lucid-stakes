extends SceneTree
## Captura las Opciones (General y Gráficos) con una casilla enfocada, para ver las casillas y la descripción que aparece abajo.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_opciones.gd -- PREFIJO
const Profile := preload("res://scripts/datos/profile.gd")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	Profile.path = "user://shot_profile_opciones.json"
	Profile.reset()
	var o: Control = load("res://scripts/ui/options_screen.gd").new()
	root.add_child(o)
	o.visible = true
	await _frames(10)
	o.contrast_buttons.box.grab_focus()
	await _frames(20)
	root.get_viewport().get_texture().get_image().save_png("%s_general.png" % args[0])
	o.show_tab("graficos")
	await _frames(10)
	o.vsync_buttons.box.grab_focus()
	await _frames(20)
	root.get_viewport().get_texture().get_image().save_png("%s_graficos.png" % args[0])
	quit()
