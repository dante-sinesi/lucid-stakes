extends SceneTree
## Captura la sala de un casino (voxeles de `build_voxels`) con su tablón de contratos contra la pared del norte.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1300x800 -s tests/capturas/shot_casino_tablon.gd -- ARCHIVO.png NIVEL(0..3)
const Room := preload("res://scripts/casino/casino_room.gd")
const VoxelMesh := preload("res://scripts/ui/voxel_mesh.gd")
const Arte := preload("res://scripts/ui/contract_art.gd")

# donde va el tablón en cada casino: la celda de la izquierda, sobre la pared del norte (ocupa dos celdas de ancho cuando lo pida el diseño)
const CELDAS := [Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 0), Vector2i(4, 0)]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var tier := int(args[1])
	var stage: int = [1, 5, 9, 13][tier]
	var data: Dictionary = Room.build_voxels(stage, tier)
	var L: Dictionary = Room.look(stage, tier)
	var R := Arte.Rareza
	var rarezas := [[R.COMUN, R.COMUN, R.RARA], [R.COMUN, R.RARA, R.COMUN, R.EPICA], [R.COMUN, R.RARA, R.EPICA, R.COMUN, R.RARA], [R.COMUN, R.RARA, R.EPICA, R.IMPOSIBLE, R.COMUN, R.EPICA]]
	var papeles: Array = rarezas[tier]
	var lay: Dictionary = Room.layout(stage, tier)
	Room._station(data.solid, data.glow, {"id": "tablon", "cell": CELDAS[tier], "tier": tier, "papeles": papeles}, L)
	var mundo := Node3D.new()
	root.add_child(mundo)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.04, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.7)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	mundo.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55, -30, 0)
	mundo.add_child(sol)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	var glow_mat := StandardMaterial3D.new()
	glow_mat.vertex_color_use_as_albedo = true
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for par in [[data.solid, mat, Room.VOXEL], [data.glow, glow_mat, Room.VOXEL]]:
		var m := MeshInstance3D.new()
		m.mesh = VoxelMesh.build(par[0], par[2])
		m.material_override = par[1]
		mundo.add_child(m)
	var centro := Vector3(float(lay.cells.x * Room.CELL_VOX) * Room.VOXEL * 0.5, 0.6, float(lay.cells.y * Room.CELL_VOX) * Room.VOXEL * 0.5)
	var pivot := Node3D.new()
	pivot.position = centro
	pivot.rotation_degrees.y = 45.0
	mundo.add_child(pivot)
	var pitch := Node3D.new()
	pitch.rotation_degrees.x = -35.264
	pivot.add_child(pitch)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(lay.cam_size) * 0.95
	if args.size() > 2 and args[2] == "cerca":   # (de cerca: centrada en el tablón)
		pivot.position = Vector3((CELDAS[tier].x * Room.CELL_VOX + 2.5) * Room.VOXEL, 1.4, (CELDAS[tier].y * Room.CELL_VOX + 3.0) * Room.VOXEL)
		cam.size = 6.5
	cam.far = 200.0
	cam.position = Vector3(0, 0, 40)
	pitch.add_child(cam)
	cam.make_current()
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(args[0])
	quit(0)
