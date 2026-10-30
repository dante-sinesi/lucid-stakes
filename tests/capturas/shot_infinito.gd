extends SceneTree
## Captura del texto "Movimientos 0/∞" (el glifo de infinito de la fuente de cubitos): GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 640x240 -s tests/capturas/shot_infinito.gd -- SALIDA.png
const UI := preload("res://scripts/ui/menu_ui.gd")


func _init() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.12, 0.05, 0.2)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(fondo)
	var caja := VBoxContainer.new()
	caja.position = Vector2(20, 20)
	root.add_child(caja)
	UI.label(caja, "Movimientos 0/∞", 3.0, Color.WHITE, false, 600)
	UI.label(caja, "Movimientos 12/20", 3.0, Color.WHITE, false, 600)
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "capturas/infinito.png")
	quit(0)
