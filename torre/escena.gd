extends RefCounted
## Lo común de la vista 3D de las salas (la torre dentro del juego y el Estudio): el shader y los materiales de los bloques, la luz, la cámara de una vista y el rayo para elegir una cara.

const BLOCK_SHADER := preload("res://shaders/voxel_block.gdshader")
const HIELO_SHADER := preload("res://shaders/voxel_hielo.gdshader")
const HIELO_ATRAS_SHADER := preload("res://shaders/voxel_hielo_atras.gdshader")

static var _globals_done := false
static var _mats := {}


## Los parámetros globales que usa el shader de los bloques (el juego los registra en main.gd; acá se apagan las ayudas de profundidad).
static func register_globals() -> void:
	if _globals_done or Engine.has_meta("globales_de_bloques"):   # (dentro del juego main.gd ya los registró)
		return
	_globals_done = true
	Engine.set_meta("globales_de_bloques", true)
	for spec in [["depth_focus", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0], ["depth_strength", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
			["xray_radius", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0], ["focus_view", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO]]:
		RenderingServer.global_shader_parameter_add(spec[0], spec[1], spec[2])


static func material(tint: Color, ice: bool) -> ShaderMaterial:
	var key := "%s|%s" % [tint.to_html(), str(ice)]
	if not _mats.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = BLOCK_SHADER
		mat.set_shader_parameter("roughness_value", 0.15 if ice else 0.8)
		mat.set_shader_parameter("rim", 0.35 if ice else 0.0)
		mat.set_shader_parameter("tint", tint)
		mat.set_shader_parameter("glow_color", Color.BLACK)
		mat.set_shader_parameter("glow_energy", 0.0)
		mat.set_shader_parameter("shake", 0.0)
		_mats[key] = mat
	return _mats[key]


## El material de un bloque translúcido con el arte nuevo (el hielo, con brillo en el canto, o la trampa, que se desvanece hacia abajo). `atras`: el de las caras de atrás (se dibuja antes que
## el de adelante: estos bloques van en dos mallas iguales, una con cada material, porque dentro de una misma malla Godot no ordena las caras translúcidas y al girar la cámara parpadeaban).
static func material_translucido(tipo: String, atras := false) -> ShaderMaterial:
	var clave := "%s_arte%s" % [tipo, "_atras" if atras else ""]
	if not _mats.has(clave):
		var mat := ShaderMaterial.new()
		mat.shader = HIELO_ATRAS_SHADER if atras else HIELO_SHADER
		mat.render_priority = 0 if atras else 1
		mat.set_shader_parameter("roughness_value", 0.12 if tipo == "hielo" else 0.8)
		mat.set_shader_parameter("rim", 0.45 if tipo == "hielo" else 0.0)
		mat.set_shader_parameter("tint", Color.WHITE)
		mat.set_shader_parameter("glow_color", Color.BLACK)
		mat.set_shader_parameter("glow_energy", 0.0)
		mat.set_shader_parameter("shake", 0.0)
		_mats[clave] = mat
	return _mats[clave]


static func world_pos(c: Vector3i) -> Vector3:
	return Vector3(c.x + 0.5, c.y + 0.5, c.z + 0.5)


## Un ambiente y una luz para un SubViewport propio (miniaturas) o para la vista principal.
static func add_lighting(parent: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.08, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.75)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.0
	parent.add_child(sun)


## Pone la cámara mirando la sala desde el ángulo (yaw, pitch en grados) a la distancia `dist` del punto `center`.
static func place_camera(cam: Camera3D, center: Vector3, yaw: float, pitch: float, dist: float) -> void:
	var y := deg_to_rad(yaw)
	var p := deg_to_rad(pitch)
	cam.look_at_from_position(center + dist * Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)), center, Vector3.UP)


## Pasa un punto de la pantalla (relativo al viewport) a la celda de bloque que toca el rayo (la primera con bloque). Vector3i(-1000, 0, 0) si no toca nada.
static func pick(cam: Camera3D, pos: Vector2, st) -> Vector3i:
	var origin := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	var t := 0.0
	while t < 120.0:
		var p := origin + dir * t
		var c := Vector3i(floori(p.x), floori(p.y), floori(p.z))
		if st.blocks.has(c):
			return c
		t += 0.04
	return Vector3i(-1000, 0, 0)


## Como `pick`, pero devuelve también la celda vacía por la que entró el rayo (la cara que se tocó): {hit, prev}. `hit.x == -1000` si no toca nada.
static func pick_face(cam: Camera3D, pos: Vector2, st) -> Dictionary:
	var origin := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	var t := 0.0
	var prev := Vector3i(-1000, 0, 0)
	while t < 120.0:
		var p := origin + dir * t
		var c := Vector3i(floori(p.x), floori(p.y), floori(p.z))
		if st.blocks.has(c):
			return {"hit": c, "prev": prev if prev.x != -1000 else c}
		prev = c
		t += 0.04
	return {"hit": Vector3i(-1000, 0, 0), "prev": Vector3i(-1000, 0, 0)}
