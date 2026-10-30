extends SceneTree
## Los dados y su mesa en cada casino (taberna, salón, casino y gran casino): la fase de elegir y, después de tirar, el resultado.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_dados_casinos.gd -- PREFIJO [casos: por ejemplo 20,30 (casino y alternativa 0) para regenerar sólo esos]
const Profile := preload("res://scripts/datos/profile.gd")


func _init() -> void:
	var pre := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "capturas/dados_casino"
	Profile.path = "user://shot_profile_dados_casinos.json"
	Profile.reset()
	Profile.mark_tutorial_done()
	Profile.mark_help_seen("dados")
	var solo: PackedStringArray = OS.get_cmdline_user_args()[1].split(",") if OS.get_cmdline_user_args().size() > 1 else PackedStringArray()
	for caso in [[0, 0], [1, 0], [2, 0], [3, 0]]:
		var t: int = caso[0]
		var alt: int = caso[1]
		if not solo.is_empty() and not solo.has("%d%d" % [t, alt]):
			continue
		var g = load("res://scripts/casino/dice_game.gd").new()
		root.add_child(g)
		g.set_anchors_preset(Control.PRESET_FULL_RECT)
		g.open(RandomNumberGenerator.new())
		g.set_ready(true)
		g.dice3d.set_tier(t)
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
