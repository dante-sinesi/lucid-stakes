extends SceneTree
## La información de un escenario (el "?" de su tarjeta). Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_escenario_info.gd -- ARCHIVO.png ID
const ScenarioScreen := preload("res://scripts/ui/scenario_screen.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var s: Control = ScenarioScreen.new()
	root.add_child(s)
	s.visible = true
	await process_frame
	s.refresh()
	for i in 5:
		await process_frame
	s.show_info(args[1] if args.size() > 1 else "sin_piedad")
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png(args[0])
	quit(0)
