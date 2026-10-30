extends SceneTree
## Los dados y su mesa en cada casino (taberna, salón, casino y gran casino) y las alternativas del casino y del gran casino: la fase de elegir y, después de tirar, el resultado.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_dados_casinos.gd -- PREFIJO
const Profile := preload("res://scripts/datos/profile.gd")


func _init() -> void:
	var pre := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "capturas/dados_casino"
	Profile.path = "user://shot_profile_dados_casinos.json"
	Profile.reset()
	Profile.mark_tutorial_done()
	Profile.mark_help_seen("dados")
	for caso in [[0, 0], [1, 0], [2, 0], [2, 1], [2, 2], [3, 0], [3, 1], [3, 2]]:
		var t: int = caso[0]
		var alt: int = caso[1]
		var g = load("res://scripts/casino/dice_game.gd").new()
		root.add_child(g)
		g.set_anchors_preset(Control.PRESET_FULL_RECT)
		g.open(RandomNumberGenerator.new())
		g.set_ready(true)
		g.dice3d.set_tier(t, alt)
		for i in 8:
			await process_frame
		root.get_texture().get_image().save_png("%s_%d%d_elegir.png" % [pre, t, alt])
		g.throw_dice()
		var t0 := Time.get_ticks_msec()
		while (Time.get_ticks_msec() - t0) < 2600:
			await process_frame
		root.get_texture().get_image().save_png("%s_%d%d_tirada.png" % [pre, t, alt])
		g.queue_free()
		await process_frame
	quit(0)
