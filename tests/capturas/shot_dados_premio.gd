extends SceneTree
## Captura de los dados con la tira de recompensas: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1600x938 -s tests/capturas/shot_dados_premio.gd -- SALIDA.png
func _init() -> void:
	var g = load("res://scripts/casino/dice_game.gd").new()
	root.add_child(g)
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.open(RandomNumberGenerator.new())
	g.set_ready(true)
	g.fast = true
	g.prize.connect(func(info): info["granted"] = 8; info["luz"] = 1; info["cosmetic_name"] = "Gorro de copa"; info["cosmetic_rarity"] = "raro"; info["cosmetic_slot"] = "gorro"; info["cosmetic_id"] = "copa")
	g.throw_dice()
	for i in 60:
		await process_frame
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "capturas/dados_premio.png")
	var sc = g.showcase
	print("center ", sc.center.position, sc.center.size, " col ", sc.col.position, sc.col.size, " sc ", sc.size, sc.position)
	quit(0)
