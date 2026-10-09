extends SceneTree
## Captura del menú y de Opciones (con ventana; usa y deja limpio el archivo de ajustes del jugador).
## Uso: ... --rendering-driver opengl3 --resolution 1280x720 -s tests/shot_options.gd -- SALIDA [en]
const Settings := preload("res://scripts/settings.gd")
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var main = load("res://scenes/main.tscn").instantiate()
	main.quit_game_override = true
	root.add_child(main)
	for i in 20: await process_frame
	root.get_texture().get_image().save_png(args[0] + "_menu.png")
	main.main_menu.buttons["opciones"].pressed.emit()
	if args.size() > 1:
		main.main_menu.options.lang_buttons.en.pressed.emit()
		for i in 5: await process_frame
	for i in 40: await process_frame
	root.get_texture().get_image().save_png(args[0] + "_opciones.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	quit()
