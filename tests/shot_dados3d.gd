extends SceneTree
## Capturas de los dados 3D: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/shot_dados3d.gd -- PREFIJO
func _init() -> void:
	var pre := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "capturas/dados"
	var g = load("res://scripts/dice_game.gd").new()
	root.add_child(g)
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.open(RandomNumberGenerator.new())
	g.set_ready(true)
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png(pre + "_elegir.png")
	g.throw_dice()
	for step in [0.5, 1.1, 2.0, 3.6]:
		var t0 := Time.get_ticks_msec()
		while (Time.get_ticks_msec() - t0) < step * 700:
			await process_frame
		root.get_texture().get_image().save_png(pre + "_t%d.png" % int(step * 10))
	print("listo fase ", g.phase)
	quit(0)
