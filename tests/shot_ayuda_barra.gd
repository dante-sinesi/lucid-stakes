extends SceneTree
## Captura de una pantalla de juego con el ítem "Ayuda" en la botonera (con mando): GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/shot_ayuda_barra.gd -- SALIDA.png
const GameHelp := preload("res://scripts/game_help.gd")
const Controls := preload("res://scripts/controls.gd")
const RunState := preload("res://scripts/run_state.gd")


func _init() -> void:
	Controls.using_pad = true
	var run := RunState.new()
	run.stage = 5
	run.claridad = 500
	var s = load("res://scripts/slots_screen.gd").new()
	root.add_child(s)
	s.setup(run, RandomNumberGenerator.new(), true)
	GameHelp.attach(s, "tragamonedas")
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "capturas/ayuda_barra.png")
	quit(0)
