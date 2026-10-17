extends SceneTree
## Captura la decisión de Farolín con los botones del mando (Xbox, PlayStation) y con el teclado. Correr con GAME_SANDBOX=1.
## Uso: ... --rendering-driver opengl3 --resolution 1280x720 -s tests/shot_dialogo_mando.gd -- SALIDA
const DialogueBox := preload("res://scripts/dialogue_box.gd")
const Farolin := preload("res://scripts/farolin.gd")
const Controls := preload("res://scripts/controls.gd")
const PadGlyph := preload("res://scripts/pad_glyph.gd")
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main = load("res://scenes/main.tscn").instantiate()
	main.quit_game_override = true
	root.add_child(main)
	for f in 30:
		await process_frame
	main.start_tutorial(2, true)
	for f in 60:
		await process_frame
	var box = main.dialogue
	var d := Farolin.toll_dialog(120, 300, true)
	var i := 0
	for cfg in [[false, 0], [true, PadGlyph.Style.XBOX], [true, PadGlyph.Style.PLAYSTATION]]:
		Controls.using_pad = cfg[0]
		PadGlyph.forced = cfg[1]
		box.show_choice(d.text, d.options, Farolin.SPEAKER)
		for f in 140:
			await process_frame
		root.get_texture().get_image().save_png("%s_%d.png" % [out, i])
		i += 1
	quit()
