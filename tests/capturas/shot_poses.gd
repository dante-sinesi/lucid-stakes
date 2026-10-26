extends SceneTree
## Captura las poses de las animaciones del personaje (animacion.gd) una al lado de la otra: arriba las acciones, abajo los pasatiempos y el colgado.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1600x700 -s tests/capturas/shot_poses.gd -- ARCHIVO.png [personaje] [exageradas 1|0]
const Characters := preload("res://scripts/personajes/characters.gd")
const Animacion := preload("res://scripts/personajes/animacion.gd")

const POSES := [["caminar", 0.5], ["empujar", 0.55], ["tirar", 0.65], ["trepar", 0.5], ["bajar", 0.5], ["colgarse", 0.9], ["desplazar", 0.25], ["resbalar", 0.6],
	["catapulta", 0.6], ["desactivar", 0.5], ["mirar", 0.25], ["estirar", 0.5], ["rascar", 0.5], ["saludar", 0.5], ["colgado", 1.0], ["reposo", 1.0]]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var id := args[1] if args.size() > 1 else "dante"
	var exagerado := (args[2] != "0") if args.size() > 2 else true
	var amp := 1.0 if exagerado else 0.45
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
	for i in POSES.size():
		var p: Array = POSES[i]
		var m := Characters.build(id, "", "")
		var lugar := Node3D.new()   # (el modelo se mueve solo con la pose: se lo pone dentro de un nodo que lo coloca)
		lugar.position = Vector3((i % 8) * 1.0 - 3.5, -(i / 8) * 1.4, 0.0)
		lugar.rotation_degrees.y = float(args[3]) if args.size() > 3 else 65.0   # (de tres cuartos, para ver los brazos y las patas que van hacia adelante y hacia los lados)
		mundo.add_child(lugar)
		lugar.add_child(m)
		Animacion.pose(m, str(p[0]), float(p[1]), amp, exagerado)
		var l := Label3D.new()
		l.text = str(p[0])
		l.font_size = 48
		l.pixel_size = 0.004
		l.position = lugar.position + Vector3(0, -0.15, 0.3)
		mundo.add_child(l)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(args[4]) if args.size() > 4 else 5.2
	cam.position = Vector3(0.0, 0.2, 6.0)
	cam.rotation_degrees = Vector3(-8, 0, 0)
	mundo.add_child(cam)
	cam.make_current()
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(args[0])
	quit(0)
