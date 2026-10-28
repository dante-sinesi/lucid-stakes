extends SceneTree
## Captura todos los cosméticos (gorros y prendas) puestos en un personaje: una fila de gorros y otra de prendas, vistos de frente y de espaldas arriba y abajo.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1700x900 -s tests/capturas/shot_cosmeticos.gd -- ARCHIVO.png [personaje] [giro] [tamaño de la cámara] [altura de la cámara]
const Characters := preload("res://scripts/personajes/characters.gd")
const Cosmetics := preload("res://scripts/personajes/cosmetics.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var id := args[1] if args.size() > 1 else "dante"
	var giro := float(args[2]) if args.size() > 2 else 25.0
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
	var filas := [Cosmetics.by_slot("gorro"), Cosmetics.by_slot("prenda")]
	for f in filas.size():
		for i in filas[f].size():
			var c: Dictionary = filas[f][i]
			for v in 2:   # (de frente y de espaldas)
				var m := Characters.build(id, str(c.id) if f == 0 else "", str(c.id) if f == 1 else "")
				var lugar := Node3D.new()
				lugar.position = Vector3(i * 1.0 - 3.0, -f * 2.9 - v * 1.35, 0.0)
				lugar.rotation_degrees.y = giro + 180.0 * v
				mundo.add_child(lugar)
				lugar.add_child(m)
			var l := preload("res://scripts/ui/rotulo_pixel.gd").crear(str(c.name), Color.WHITE, false, 0.011)   # (con la fuente del juego)
			l.position = Vector3(i * 1.0 - 3.0, -f * 2.9 + 0.95, 0.5)
			mundo.add_child(l)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(args[3]) if args.size() > 3 else 7.0
	cam.position = Vector3(0.0, float(args[4]) if args.size() > 4 else -2.2, 6.0)
	mundo.add_child(cam)
	cam.make_current()
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(args[0])
	quit(0)
