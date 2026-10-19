extends SceneTree
## Capturas de todas las páginas de ayuda: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/shot_ayudas.gd -- PREFIJO [id]
const GameHelp := preload("res://scripts/game_help.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var pre := args[0] if args.size() > 0 else "capturas/ayuda"
	var only := args[1] if args.size() > 1 else ""
	for id in GameHelp.PAGES:
		if only != "" and id != only:
			continue
		var host := Control.new()
		host.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(host)
		var bg := ColorRect.new()
		bg.color = Color(0.05, 0.03, 0.09)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		host.add_child(bg)
		var h = GameHelp.attach(host, id)
		h.open()
		for p in GameHelp.PAGES[id].size():
			for i in 6:
				await process_frame
			root.get_texture().get_image().save_png("%s_%s_%d.png" % [pre, id, p + 1])
			h.next_page()
		host.queue_free()
		await process_frame
	quit(0)
