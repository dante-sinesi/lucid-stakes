extends SceneTree
## Compara los bloques corruptos de las dos primeras etapas (nivel 0 arriba, nivel 1 abajo): la piedra común junto a los tipos que se tienen que distinguir de ella.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_corruptos.gd -- ARCHIVO.png [tipos separados por coma: piedra,pinchos,catapulta] [PURIFICADO]
const Escena := preload("res://torre/escena.gd")
const Art := preload("res://scripts/personajes/block_art.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var tipos: PackedStringArray = (args[1] if args.size() > 1 else "piedra,pinchos,catapulta").split(",")
	var estado: int = Art.Estado.PURIFICADO if args.size() > 2 else Art.Estado.CORRUPTO
	Escena.register_globals()
	var mundo := Node3D.new()
	root.add_child(mundo)
	Escena.add_lighting(mundo)
	var paso := Vector3(1.25, 0, -1.25)
	var abajo := Vector3(1.4, 0, 1.4)
	for fila in 2:
		for i in tipos.size():
			var m := MeshInstance3D.new()
			m.mesh = Art.malla_bloque(tipos[i], estado, fila, 1)
			m.material_override = Escena.material(Color.WHITE, false)
			m.position = Vector3(0.5, 0.5, 0.5) + paso * (i - (tipos.size() - 1) * 0.5) + abajo * (fila - 0.5)
			mundo.add_child(m)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 6.4
	mundo.add_child(cam)
	Escena.place_camera(cam, Vector3(0.5, 0.5, 0.5), 45.0, 35.264, 30.0)
	cam.make_current()
	for k in 8:
		await process_frame
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png(args[0])
	quit(0)
