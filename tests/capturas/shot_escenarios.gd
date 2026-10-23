extends SceneTree
## Captura del selector de escenarios: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_escenarios.gd -- SALIDA.png [pasos a la derecha]
const ScenarioScreen := preload("res://scripts/ui/scenario_screen.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var s: Control = ScenarioScreen.new()
	root.add_child(s)
	s.visible = true
	await process_frame
	s.refresh()
	for i in 10:
		await process_frame
	for i in (int(args[1]) if args.size() > 1 else 0):
		s.scroll_cards(1)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png(args[0] if args.size() > 0 else "capturas/escenarios.png")
	quit(0)
