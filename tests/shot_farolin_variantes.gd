extends SceneTree
## Captura los diseños de Farolín (en 3D y la cara 2D del cuadro de diálogo) lado a lado. Correr con GAME_SANDBOX=1.
## Uso: ... --rendering-driver opengl3 --resolution 1280x720 -s tests/shot_farolin_variantes.gd -- SALIDA
const Farolin := preload("res://scripts/farolin.gd")
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.08, 0.05, 0.14)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.45, 0.6)
	e.ambient_light_energy = 0.35
	env.environment = e
	root.add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, -0.15, 3.6)
	cam.fov = 28.0
	root.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 20, 0)
	sun.light_energy = 0.35
	root.add_child(sun)
	var names := ["Actual", "1 Sereno", "2 Boquita", "3 Cíclope"]
	for i in 4:
		var f: Node3D = Farolin.build(i)
		f.position = Vector3((i - 1.5) * 0.62, 0.0, 0)
		f.scale = Vector3.ONE * 1.25
		root.add_child(f)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)
	ui.draw.connect(func():
		for i in 4:
			var x := 120.0 + i * 275.0
			Farolin.draw_face(ui, Vector2(x - 10.0, 440.0), 11.0, i)
			ui.draw_string(ThemeDB.fallback_font, Vector2(x + 30.0, 665.0), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.95, 0.8)))
	for i in 30:
		await process_frame
	ui.queue_redraw()
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png(out + ".png")
	quit()
