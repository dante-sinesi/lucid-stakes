extends RefCounted
## Dibuja una sala (un simulador de TowerLogic) con el aspecto del juego: los modelos de minibloques de block_models.gd y el shader de los bloques.
## Lo usan el Estudio de salas (vista principal y miniaturas). Todo es 3D en un nodo padre; la cámara la pone quien llama.

const BlockModels := preload("res://scripts/block_models.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")
const BLOCK_SHADER := preload("res://shaders/voxel_block.gdshader")

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
		mat.set_shader_parameter("tint", tint)
		mat.set_shader_parameter("glow_color", Color.BLACK)
		mat.set_shader_parameter("glow_energy", 0.0)
		mat.set_shader_parameter("shake", 0.0)
		_mats[key] = mat
	return _mats[key]


static func world_pos(c: Vector3i) -> Vector3:
	return Vector3(c.x + 0.5, c.y + 0.5, c.z + 0.5)


## Dónde mirar para ver la sala entera: {center, radius}.
static func bounds(room: Dictionary) -> Dictionary:
	var lo := Vector3(1e9, 0, 1e9)
	var hi := Vector3(-1e9, float(room.h) + 1.0, -1e9)
	for c in room.cells:
		lo.x = minf(lo.x, c.x)
		lo.z = minf(lo.z, c.y)
		hi.x = maxf(hi.x, c.x + 1.0)
		hi.z = maxf(hi.z, c.y + 1.0)
	lo.x = minf(lo.x, room.entry.x)
	lo.z = minf(lo.z, room.entry.y)
	hi.x = maxf(hi.x, room.entry.x + 1.0)
	hi.z = maxf(hi.z, room.entry.y + 1.0)
	var center := (lo + hi) * 0.5
	return {"center": center, "radius": (hi - lo).length() * 0.5}


## Arma los bloques de la sala bajo `parent` (se borra lo que había). `st` es el simulador a dibujar (la sala quieta o una reproducción).
static func populate(parent: Node3D, st, room: Dictionary, show_player := true, highlight: Array = [], warn: Array = []) -> void:
	register_globals()
	for ch in parent.get_children():
		parent.remove_child(ch)
		ch.queue_free()
	if st == null:
		return
	var top := float(room.h)
	var start_block := Vector3i(-999, -999, -999)
	var end_block := Vector3i(-999, -999, -999)
	if room.has("start_block"):   # (los pasos lo traen)
		start_block = room.start_block
		end_block = room.end_block
	elif room.has("entry") and room.has("exit") and room.entry is Vector2i:
		start_block = Vector3i(room.entry.x, 0, room.entry.y)
		end_block = Vector3i(room.exit.x, int(room.h), room.exit.y)
	var hl := {}
	for c in highlight:
		hl[c] = true
	for c in st.blocks:
		var kind: int = st.kind_at(c)
		var fixed: bool = st.fixed.has(c)
		var model_kind := kind
		var state := BlockModels.State.PURE
		var tint := Color(1.5, 1.5, 1.5)
		if fixed and c.y >= 1:
			model_kind = BlockModels.CORE
			tint = Color(1.7, 1.7, 1.7)
		elif fixed:   # el piso
			model_kind = TowerLogic.Kind.NORMAL
			tint = Color(0.42, 0.42, 0.52)
		if c == start_block:   # el bloque de inicio (verde) y el de fin (rojo)
			model_kind = TowerLogic.Kind.NORMAL
			tint = Color(0.25, 1.6, 0.45)
		elif c == end_block:
			model_kind = TowerLogic.Kind.NORMAL
			tint = Color(1.9, 0.25, 0.25)
		elif kind == TowerLogic.Kind.NORMAL:
			tint = Color.from_hsv(lerpf(0.62, 0.05, clampf(float(c.y) / maxf(top, 1.0), 0.0, 1.0)), 0.55, 1.0)
			tint = Color(tint.r * 1.15, tint.g * 1.15, tint.b * 1.15)
		var m := MeshInstance3D.new()
		m.mesh = BlockModels.mesh_for(model_kind, state, BlockModels.variant_for(c.x * 31 + c.y * 17 + c.z * 7, 0, model_kind))   # (las salas se ven con variedad, como en el juego)
		m.material_override = material(tint, kind == TowerLogic.Kind.ICE)
		m.position = world_pos(c)
		m.name = "b%d_%d_%d" % [c.x, c.y, c.z]
		parent.add_child(m)
	# el aviso de la llegada y el jugador
	var entry: Vector2i = room.entry
	var mark := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.28
	cyl.bottom_radius = 0.28
	cyl.height = 0.06
	mark.mesh = cyl
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.2, 1.0, 0.45)
	mm.emission_enabled = true
	mm.emission = Color(0.2, 1.0, 0.45)
	mm.emission_energy_multiplier = 0.8
	mark.material_override = mm
	mark.position = Vector3(entry.x + 0.5, float(room.get("entry_y", 1)) + 0.03, entry.y + 0.5)
	mark.name = "llegada"
	parent.add_child(mark)
	if show_player:
		var p := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.42, 0.78, 0.42)
		p.mesh = box
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(1.0, 0.62, 0.15)
		pm.emission_enabled = true
		pm.emission = Color(1.0, 0.5, 0.1)
		pm.emission_energy_multiplier = 0.5
		p.material_override = pm
		var pc: Vector3i = st.player
		p.position = Vector3(pc.x + 0.5, pc.y + 0.39, pc.z + 0.5)
		p.name = "jugador"
		parent.add_child(p)
	if not warn.is_empty():   # los bloques que se caerían: marcados en rojo
		var warn_mat := StandardMaterial3D.new()
		warn_mat.albedo_color = Color(1.0, 0.1, 0.1, 0.55)
		warn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		warn_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for c in warn:
			var w := MeshInstance3D.new()
			var wb := BoxMesh.new()
			wb.size = Vector3(1.1, 1.1, 1.1)
			w.mesh = wb
			w.material_override = warn_mat
			w.position = world_pos(c)
			w.name = "sin_apoyo"
			parent.add_child(w)
	if not hl.is_empty():
		var sel_mat := StandardMaterial3D.new()
		sel_mat.albedo_color = Color(0.2, 0.9, 1.0, 0.35)
		sel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for c in hl:
			var s := MeshInstance3D.new()
			var b2 := BoxMesh.new()
			b2.size = Vector3(1.06, 1.06, 1.06)
			s.mesh = b2
			s.material_override = sel_mat
			s.position = world_pos(c)
			s.name = "seleccion"
			parent.add_child(s)


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
