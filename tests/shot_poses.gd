extends SceneTree
## Hoja de contacto de las poses del personaje: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1600x900 -s tests/shot_poses.gd -- SALIDA.png [personaje]
const Characters := preload("res://scripts/characters.gd")
const Poses := preload("res://scripts/poses.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var who: String = args[1] if args.size() > 1 else "dante"
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.18, 0.17, 0.24)
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 0.9
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(light)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.6
	cam.position = Vector3(10.0, 1.6, 0.0)
	cam.rotation_degrees = Vector3(0, 90, 0)
	world.add_child(cam)
	var shown := [["empujar", 1], ["tirar", 1], ["trepar", 0], ["saltar", 0], ["caer", 1], ["resbalar", 0], ["colgarse", 0], ["avanzar_colgado", 0], ["subir_del_borde", 0], ["victoria", 1], ["reposo", 0]]
	var x := 0.0
	for i in shown.size():
		var m := Characters.build(who, "", "")
		m.position = Vector3(0.0, 2.3 - float(i / 6) * 2.2, float(i % 6) * -1.5 + 3.75)
		world.add_child(m)
		m.rotation.y = 0.0
		if shown[i][0] in ["colgarse", "avanzar_colgado"]:
			var bar := MeshInstance3D.new()   # el borde del que se agarra
			var bm := BoxMesh.new()
			bm.size = Vector3(0.9, 0.14, 0.4)
			bar.mesh = bm
			bar.position = m.position + Vector3(0.0, 0.64, 0.38)
			bar.rotation.y = 0.0
			world.add_child(bar)
		Poses.apply_now(m, shown[i][0], shown[i][1])
	for i in 5:
		await process_frame
	root.get_texture().get_image().save_png(args[0] if args.size() > 0 else "capturas/poses.png")
	quit(0)
