extends SceneTree
## Captura a los cinco personajes (una columna cada uno) en tres poses (reposo, colgado y trepar). Uso: ... -- ARCHIVO.png [giro] [tamaño de la cámara]
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1600x700 -s tests/capturas/shot_poses.gd -- ARCHIVO.png [personaje] [exageradas 1|0]
const Characters := preload("res://scripts/personajes/characters.gd")
const Animacion := preload("res://scripts/personajes/animacion.gd")

const IDS := ["dante", "gaby", "gato", "perro", "conejo"]
const POSES := ["reposo", "colgado", "trepar"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mundo := Node3D.new()
	root.add_child(mundo)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.15, 0.32)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.9)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	mundo.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 30, 0)
	mundo.add_child(sol)
	for i in IDS.size():
		for j in POSES.size():
			var m := Characters.build(IDS[i], "", "")
			var lugar := Node3D.new()
			lugar.position = Vector3(i * 1.1 - 2.2, -j * 1.3, 0.0)
			lugar.rotation_degrees.y = float(args[1]) if args.size() > 1 else 30.0
			mundo.add_child(lugar)
			lugar.add_child(m)
			Animacion.pose(m, POSES[j], 0.5 if POSES[j] != "colgado" else 1.0)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(args[2]) if args.size() > 2 else 3.6
	cam.position = Vector3(0.0, -0.4, 6.0)
	cam.rotation_degrees = Vector3(-6, 0, 0)
	mundo.add_child(cam)
	cam.make_current()
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(args[0])
	quit(0)
