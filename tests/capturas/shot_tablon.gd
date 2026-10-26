extends SceneTree
## Captura el tablón de contratos de cada casino (3, 4, 5 y 6 papeles). Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1300x600 -s tests/capturas/shot_tablon.gd -- ARCHIVO.png
const Room := preload("res://scripts/casino/casino_room.gd")
const VoxelMesh := preload("res://scripts/ui/voxel_mesh.gd")
const Arte := preload("res://scripts/ui/contract_art.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mundo := Node3D.new()
	root.add_child(mundo)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.08, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.72, 0.85)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	mundo.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, -30, 0)
	mundo.add_child(sol)
	var R := Arte.Rareza
	var tandas := [[R.COMUN, R.COMUN, R.RARA], [R.COMUN, R.RARA, R.COMUN, R.EPICA], [R.COMUN, R.RARA, R.EPICA, R.COMUN, R.RARA], [R.COMUN, R.RARA, R.EPICA, R.IMPOSIBLE, R.COMUN, -1]]
	for tier in 4:
		var L: Dictionary = Room.look([1, 5, 9, 13][tier], tier)
		var solid := {}
		var glow := {}
		for x in range(-2, 8):
			for z in range(-2, 8):
				solid[Vector3i(x, 1, z)] = (L.stone as Color) if (x + z) % 2 == 0 else (L.stone as Color).darkened(0.08)
		Room._station(solid, glow, {"id": "tablon", "cell": Vector2i(0, 0), "papeles": tandas[tier]}, L)
		var m := MeshInstance3D.new()
		m.mesh = VoxelMesh.build(solid, Room.VOXEL)
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		m.material_override = mat
		m.position = Vector3(tier * 2.2 - 3.5, 0, 0)
		mundo.add_child(m)
		var g := MeshInstance3D.new()
		g.mesh = VoxelMesh.build(glow, Room.VOXEL)
		var gm := StandardMaterial3D.new()
		gm.vertex_color_use_as_albedo = true
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		g.material_override = gm
		g.position = m.position
		mundo.add_child(g)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 5.0
	cam.look_at_from_position(Vector3(0.4, 1.3, 0.5) + Vector3(-3.0, 4.2, 6.0) * 1.5, Vector3(0.4, 1.3, 0.5), Vector3.UP)
	mundo.add_child(cam)
	cam.make_current()
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(args[0])
	quit(0)
