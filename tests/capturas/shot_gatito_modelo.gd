extends SceneTree
## Los diseños del gatito travieso (scripts/personajes/gatito_travieso.gd) uno al lado del otro, de frente y de costado, para elegir.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_gatito_modelo.gd -- ARCHIVO.png [ANGULO]
const Escena := preload("res://torre/escena.gd")
const Gatito := preload("res://scripts/personajes/gatito_travieso.gd")
const Characters := preload("res://scripts/personajes/characters.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var angulo := float(args[1]) if args.size() > 1 else 35.0
	Escena.register_globals()
	var mundo := Node3D.new()
	root.add_child(mundo)
	Escena.add_lighting(mundo)
	var fondo := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.22, 0.17, 0.35)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.68, 0.8)
	env.ambient_light_energy = 0.8
	fondo.environment = env
	mundo.add_child(fondo)
	# el suelo (un bloque largo) y los tres gatitos, con el personaje de siempre al final para comparar el tamaño
	var suelo := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(5.2, 0.2, 1.2)
	suelo.mesh = caja
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.26, 0.4)
	suelo.material_override = mat
	suelo.position = Vector3(0.9, -0.1, 0)
	mundo.add_child(suelo)
	for i in Gatito.VARIANTES.size():
		var g := Gatito.build(i)
		g.position = Vector3(-0.7 + i * 0.9, 0, 0)
		g.rotation.y = deg_to_rad(angulo)
		mundo.add_child(g)
	var jugador := Characters.build("gato")
	jugador.position = Vector3(2.9, 0, 0)
	jugador.rotation.y = deg_to_rad(angulo)
	mundo.add_child(jugador)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(args[2]) if args.size() > 2 else 2.6
	cam.position = Vector3(float(args[3]) if args.size() > 3 else 0.9, 1.3 if args.size() < 3 else 1.65, 4.0)
	cam.rotation_degrees = Vector3(-18, 0, 0)
	mundo.add_child(cam)
	cam.make_current()
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png(args[0])
	quit(0)
