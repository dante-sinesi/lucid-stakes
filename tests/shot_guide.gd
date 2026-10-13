extends SceneTree
## Captura de la guía de bloques (con algunos bloques descubiertos). Correr con GAME_SANDBOX=1.
## Uso: ... --rendering-driver opengl3 --resolution 1280x720 -s tests/shot_guide.gd -- SALIDA
const Profile := preload("res://scripts/profile.gd")
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var main = load("res://scenes/main.tscn").instantiate()
	main.quit_game_override = true
	root.add_child(main)
	for i in 20: await process_frame
	for id in ["normal", "hielo", "bomba", "trampa", "pinchos"]:
		Profile.discover_block(id)
	main.main_menu.show_panel("guia")
	for i in 60: await process_frame
	root.get_texture().get_image().save_png(args[0] + "_guia.png")
	for id in ["normal", "hielo", "bomba", "trampa", "pinchos"]:
		Profile.data.blocks_seen.erase(id)
	if Profile.path.contains("test_"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.path))
	quit()
