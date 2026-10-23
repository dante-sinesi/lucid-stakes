extends SceneTree
## Captura de páginas de ayuda con teclado y con mando: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_ayuda_fichas.gd -- PREFIJO
const GameHelp := preload("res://scripts/ui/game_help.gd")
const Controls := preload("res://scripts/entrada/controls.gd")


func _init() -> void:
	var pre := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "capturas/fichas"
	for pad in [false, true]:
		Controls.using_pad = pad
		for entry in [["tragamonedas", 2], ["dados", 0], ["blackjack", 1]]:
			var host := Control.new()
			host.set_anchors_preset(Control.PRESET_FULL_RECT)
			root.add_child(host)
			var bg := ColorRect.new()
			bg.color = Color(0.05, 0.03, 0.09)
			bg.set_anchors_preset(Control.PRESET_FULL_RECT)
			host.add_child(bg)
			var h = GameHelp.attach(host, entry[0])
			h.open()
			for i in int(entry[1]):
				h.next_page()
			for i in 12:
				await process_frame
			root.get_texture().get_image().save_png("%s_%s_%s.png" % [pre, "mando" if pad else "teclado", entry[0]])
			host.queue_free()
			await process_frame
	quit(0)
