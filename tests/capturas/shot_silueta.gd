extends SceneTree
## Captura la silueta del personaje (la transparencia a través de los bloques): un personaje detrás de una pared de cubos, en reposo y en una pose de acción.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1000x500 -s tests/capturas/shot_silueta.gd -- ARCHIVO.png [personaje]
const Characters := preload("res://scripts/personajes/characters.gd")
const Animacion := preload("res://scripts/personajes/animacion.gd")
const Escena := preload("res://torre/escena.gd")
const BlockArt := preload("res://scripts/personajes/block_art.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var id := args[1] if args.size() > 1 else "conejo"
	var mundo := Node3D.new()
	root.add_child(mundo)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.18, 0.4)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.9)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	mundo.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 30, 0)
	mundo.add_child(sol)
	var poses := ["reposo", "colgado", "trepar", "empujar"]
	for i in poses.size():
		var lugar := Node3D.new()
		lugar.position = Vector3(i * 1.6 - 2.4, 0.0, 0.0)
		lugar.rotation_degrees.y = 30.0
		mundo.add_child(lugar)
		var cuerpo := Characters.build(id, "", "")
		var sombra := Characters.build(id, "", "", true)
		lugar.add_child(cuerpo)
		lugar.add_child(sombra)
		Animacion.pose(cuerpo, poses[i], 0.5 if poses[i] != "colgado" else 1.0)
		Animacion.pose(sombra, poses[i], 0.5 if poses[i] != "colgado" else 1.0)
		# la pared de cubos de adelante, que lo tapa
		var pared := MeshInstance3D.new()
		pared.mesh = BlockArt.malla_bloque("piedra", BlockArt.Estado.CORRUPTO, 0, i)
		pared.material_override = Escena.material(Color.WHITE, false)
		pared.scale = Vector3(1.3, 1.5, 1.0)
		pared.position = Vector3(lugar.position.x, 0.4, 0.9)
		mundo.add_child(pared)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.2
	cam.position = Vector3(0.0, 1.2, 6.0)
	cam.rotation_degrees = Vector3(-10, 0, 0)
	mundo.add_child(cam)
	cam.make_current()
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(args[0])
	quit(0)
