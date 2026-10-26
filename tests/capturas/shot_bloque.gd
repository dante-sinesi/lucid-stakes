extends SceneTree
## Captura del arte nuevo de un bloque (10 x 10 x 10 minibloques): arriba la fila de bloques corruptos y abajo los mismos, purificados.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1600x900 -s tests/capturas/shot_bloque.gd -- ARCHIVO.png [NIVEL | niveles] [TIPO: piedra | hierro]   ("niveles": una columna por nivel de corrupción, con la misma semilla)
const Escena := preload("res://torre/escena.gd")
const Art := preload("res://scripts/personajes/block_art.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var todos := args.size() > 1 and args[1] == "niveles"
	var tipo := args[2] if args.size() > 2 else "piedra"
	var nivel := int(args[1]) if args.size() > 1 and not todos else 0
	Escena.register_globals()
	var mundo := Node3D.new()
	root.add_child(mundo)
	Escena.add_lighting(mundo)
	var paso := Vector3(1.2, 0, -1.2)
	var arriba := Vector3(-2.2, 0, -2.2)   # (en la vista isométrica, hacia -x y -z es hacia arriba en la pantalla)
	var columnas := Art.NIVELES if todos else 4
	for i in columnas:
		for fila in 2:
			var m := MeshInstance3D.new()
			m.mesh = Art.malla_bloque(tipo, Art.Estado.CORRUPTO if fila == 0 else Art.Estado.PURIFICADO, i if todos else nivel, 1 if todos else i)
			m.material_override = Escena.material(Color.WHITE, false)
			m.position = Vector3(0.5, 0.5, 0.5) + paso * (i - (columnas - 1) * 0.5) + (arriba if fila == 0 else Vector3.ZERO)
			mundo.add_child(m)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 7.6 if todos else 6.6
	mundo.add_child(cam)
	Escena.place_camera(cam, Vector3(0.5, 0.5, 0.5) + arriba * 0.5, 45.0, 35.264, 30.0)
	cam.make_current()
	for k in 8:
		await process_frame
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png(args[0])
	quit(0)
