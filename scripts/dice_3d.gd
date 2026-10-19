extends SubViewportContainer
## Los dados del tabernero en 3D, hechos de cubitos como los bloques del juego: cinco dados con sus puntos hundidos, una mesa de fieltro verde con borde de madera, una cámara
## ortogonal que mira desde arriba y una caída con física simple (caen girando, rebotan cada vez menos con un aplastón al pegar y frenan mostrando la cara que salió).
## Lo maneja dice_game.gd: cada cuadro le pasa su estado (`update`) y le pide chispas (`burst`) cuando un dado acierta. También le dice dónde está cada dado en pantalla (`slot_screen_pos`)
## para dibujar encima las flechas de elegir y los números.

const VoxelMesh := preload("res://scripts/voxel_mesh.gd")

const N := 8                   # cubitos por lado de un dado
const VOX := 0.09              # lado de un cubito del dado (el dado mide 0,72)
const HALF := 0.36             # la mitad del dado
const SPACING := 1.9           # separación entre dados (en unidades del mundo)
const PX_PER_UNIT := 118.0     # cuántos píxeles mide una unidad en pantalla
const TABLE_VOX := 0.12        # lado de un cubito de la mesa
const TABLE_X := 11.6
const TABLE_Z := 5.0
const DROP := 4.4              # altura desde la que caen
## Dónde van los puntos de cada cara (0 a 1 en los dos ejes de la cara).
const PIPS := {
	1: [[0.5, 0.5]],
	2: [[0.27, 0.27], [0.73, 0.73]],
	3: [[0.27, 0.27], [0.5, 0.5], [0.73, 0.73]],
	4: [[0.27, 0.27], [0.27, 0.73], [0.73, 0.27], [0.73, 0.73]],
	5: [[0.27, 0.27], [0.27, 0.73], [0.5, 0.5], [0.73, 0.27], [0.73, 0.73]],
	6: [[0.27, 0.27], [0.27, 0.5], [0.27, 0.73], [0.73, 0.27], [0.73, 0.5], [0.73, 0.73]],
}
const YAWS := [-0.32, 0.2, -0.14, 0.34, -0.24]   # cada dado descansa un poco girado, así se ven sus caras de costado

## Las fases de dice_game.gd (el orden del enum Phase): IDLE, PICK, ROLLING, REVEAL, HOLD, RESULT, DONE.
const PH_PICK := 1
const PH_ROLLING := 2
const PH_REVEAL := 3
const PH_HOLD := 4

## La cara de cada número en el dado: su normal (los opuestos suman 7) y los ejes con que se acomodan sus puntos.
const FACES := {
	1: [Vector3i(0, 1, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1)],
	6: [Vector3i(0, -1, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1)],
	2: [Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 1, 0)],
	5: [Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 1, 0)],
	3: [Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(0, 1, 0)],
	4: [Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(0, 1, 0)],
}

var viewport: SubViewport
var cam: Camera3D
var dice: Array[Node3D] = []        # la raíz de cada dado (gira y se mueve)
var mats: Array[StandardMaterial3D] = []
var shadows: Array[MeshInstance3D] = []
var locks: Array[Node3D] = []
var _cur_q: Array[Quaternion] = []
var _sparks: Array = []
var _spark_mesh: BoxMesh
var _spark_mat: StandardMaterial3D
var _t := 0.0


func _init() -> void:
	name = "dados_3d"
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.handle_input_locally = false
	add_child(viewport)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(-52.0, 0.0, 0.0)
	cam.position = Vector3(0.0, 7.9, 6.2)
	cam.near = 0.05
	cam.far = 60.0
	viewport.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -28.0, 0.0)
	sun.light_energy = 1.05
	viewport.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.58, 0.72)
	e.ambient_light_energy = 0.7
	env.environment = e
	viewport.add_child(env)
	_build_table()
	_spark_mesh = BoxMesh.new()
	_spark_mesh.size = Vector3.ONE * 0.09
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.albedo_color = Color(1.0, 0.9, 0.4)
	_spark_mat.emission_enabled = true
	_spark_mat.emission = Color(1.0, 0.85, 0.3)
	_spark_mat.emission_energy_multiplier = 1.6
	var die_mesh := VoxelMesh.build(_die_voxels(), VOX)
	var lock_mesh := VoxelMesh.build(_lock_voxels(), 0.07)
	var shadow_mesh := QuadMesh.new()
	shadow_mesh.size = Vector2(1.0, 1.0)
	for i in 5:
		var root := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = die_mesh
		mi.position = -Vector3(HALF, HALF, HALF)
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.55
		mi.material_override = mat
		root.add_child(mi)
		viewport.add_child(root)
		dice.append(root)
		mats.append(mat)
		_cur_q.append(orient_for(1 + i % 6, YAWS[i]))
		var sh := MeshInstance3D.new()
		sh.mesh = shadow_mesh
		sh.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(0.0, 0.0, 0.0, 0.42)
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sh.material_override = smat
		viewport.add_child(sh)
		shadows.append(sh)
		var lk := Node3D.new()
		var lm := MeshInstance3D.new()
		lm.mesh = lock_mesh
		lm.position = -Vector3(3.5, 3.0, 1.0) * 0.07
		var lmat := StandardMaterial3D.new()
		lmat.vertex_color_use_as_albedo = true
		lmat.emission_enabled = true
		lmat.emission = Color(0.3, 0.9, 0.5)
		lmat.emission_energy_multiplier = 0.5
		lm.material_override = lmat
		lk.add_child(lm)
		lk.visible = false
		viewport.add_child(lk)
		locks.append(lk)
	_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit()


## La cámara ortogonal mide lo mismo en píxeles sea cual sea el tamaño de la pantalla.
func _fit() -> void:
	if cam == null:
		return
	cam.size = maxf(size.y, 100.0) / PX_PER_UNIT


# --- los modelos -----------------------------------------------------------------------------------------------------

## El dado: un cubo de marfil de N x N x N cubitos con las aristas un poco más oscuras y los puntos hundidos (se saca el cubito de la superficie y el de abajo queda oscuro).
static func _die_voxels() -> Dictionary:
	var vox := {}
	for x in N:
		for y in N:
			for z in N:
				var edges := int(x == 0 or x == N - 1) + int(y == 0 or y == N - 1) + int(z == 0 or z == N - 1)
				var tone := 1.0 - (0.09 if edges >= 2 else 0.0) - float((x * 7 + y * 13 + z * 17) % 5) * 0.012
				vox[Vector3i(x, y, z)] = Color(0.96 * tone, 0.93 * tone, 0.84 * tone)
	var pip_col := Color(0.2, 0.11, 0.24)
	for value in FACES:
		var f: Array = FACES[value]
		var n: Vector3i = f[0]
		var u: Vector3i = f[1]
		var w: Vector3i = f[2]
		var base := Vector3i((N - 1) if n.x > 0 else 0, (N - 1) if n.y > 0 else 0, (N - 1) if n.z > 0 else 0)
		if n.x == 0:
			base.x = 0
		if n.y == 0:
			base.y = 0
		if n.z == 0:
			base.z = 0
		for pip in PIPS[value]:
			var su := clampi(roundi(float(pip[0]) * N) - 1, 0, N - 2)
			var sw := clampi(roundi(float(pip[1]) * N) - 1, 0, N - 2)
			for du in 2:
				for dw in 2:
					var cell: Vector3i = base + u * (su + du) + w * (sw + dw)
					vox.erase(cell)
					vox[cell - n] = pip_col
	return vox


## El candado de los dados retenidos: un cuerpo verde y el arco arriba.
static func _lock_voxels() -> Dictionary:
	var vox := {}
	var body := Color(0.42, 0.95, 0.56)
	var dark := Color(0.2, 0.62, 0.34)
	for x in 7:
		for y in 4:
			for z in 3:
				vox[Vector3i(x, y, z)] = body if y > 0 else dark
	for y in range(4, 7):
		for z in 3:
			vox[Vector3i(1, y, z)] = body
			vox[Vector3i(5, y, z)] = body
	for x in range(1, 6):
		for z in 3:
			vox[Vector3i(x, 7, z)] = body
	vox.erase(Vector3i(3, 1, 0))   # el ojo de la cerradura
	vox.erase(Vector3i(3, 2, 0))
	return vox


func _build_table() -> void:
	var vox := {}
	var xn := int(TABLE_X / TABLE_VOX)
	var zn := int(TABLE_Z / TABLE_VOX)
	for x in xn:
		for z in zn:
			var rim := x < 2 or x >= xn - 2 or z < 2 or z >= zn - 2
			var n := float((x * 31 + z * 17) % 7) * 0.012
			if rim:
				vox[Vector3i(x, 0, z)] = Color(0.42 - n, 0.26 - n, 0.12 - n)
				vox[Vector3i(x, 1, z)] = Color(0.5 - n, 0.31 - n, 0.15 - n)
			else:
				vox[Vector3i(x, -1, z)] = Color(0.1 + n, 0.4 + n * 1.4, 0.26 + n)
			for y in range(-4, -1):
				vox[Vector3i(x, y, z)] = Color(0.3 - n, 0.18 - n, 0.08 - n)
		# el fieltro está un cubito más abajo que el borde: el piso del fieltro es la capa y = -1
	var mi := MeshInstance3D.new()
	mi.mesh = VoxelMesh.build(vox, TABLE_VOX)
	mi.position = Vector3(-TABLE_X * 0.5, 0.0, -TABLE_Z * 0.5)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mi.material_override = mat
	viewport.add_child(mi)


## La orientación de un dado que muestra el número `v` arriba (girado `yaw` sobre la mesa).
static func orient_for(v: int, yaw: float) -> Quaternion:
	var q := Quaternion.IDENTITY
	if v == 6:
		q = Quaternion(Vector3.RIGHT, PI)
	elif v != 1:
		q = Quaternion(Vector3((FACES[v] as Array)[0]), Vector3.UP)
	return Quaternion(Vector3.UP, yaw) * q


func rest_pos(i: int) -> Vector3:
	return Vector3((i - 2) * SPACING, HALF, 0.0)


## Dónde se ve el centro del dado `i` en pantalla (coordenadas de este control).
func slot_screen_pos(i: int) -> Vector2:
	if cam == null or not cam.is_inside_tree() or size.x < 10.0:
		return size * 0.5 + Vector2((i - 2) * SPACING * PX_PER_UNIT, 0.0)
	return cam.unproject_position(rest_pos(i))


# --- el movimiento ------------------------------------------------------------------------------------------------------

## El estado de la caída del dado `i` a los `t` segundos de tirarlo: {pos, quat, squash}. Todo sale de una fórmula del tiempo (sin simular cuadro a cuadro),
## así es igual en cada cuadro y termina exactamente en el número que salió.
func throw_state(i: int, t: float, face: int, seed_key: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash(seed_key * 7919 + i * 131 + face * 17)
	var rest := rest_pos(i)
	var sx := r.randf_range(-0.9, 0.9)
	var sz := r.randf_range(-0.6, 0.6)
	var axis := Vector3(r.randf_range(-1.0, 1.0), r.randf_range(-0.4, 0.4), r.randf_range(-1.0, 1.0)).normalized()
	var a0 := TAU * r.randf_range(2.2, 3.4) * (1.0 if r.randf() > 0.5 else -1.0)
	var yaw0: float = YAWS[i] + r.randf_range(-0.25, 0.25)
	var t_land := 0.55 + 0.09 * i
	var settle := t_land + 0.75
	var pos := rest
	var squash := 0.0
	if t < t_land:
		var k := t / t_land
		pos = Vector3(lerpf(rest.x + sx, rest.x, k), HALF + (DROP - HALF) * (1.0 - k * k), lerpf(rest.z + sz, rest.z, k))
	else:
		var u := t - t_land
		pos = Vector3(rest.x + sx * 0.12 * exp(-u * 3.0), HALF + absf(sin(u * 9.0)) * 0.7 * exp(-u * 3.4), rest.z + sz * 0.1 * exp(-u * 3.0))
		squash = 0.2 * exp(-u * 14.0) * (1.0 if absf(sin(u * 9.0)) < 0.35 else 0.4)
	var a := a0 * pow(maxf(1.0 - t / settle, 0.0), 2.0)
	var q := Quaternion(axis, a) * orient_for(face, yaw0)
	# el cubo girado nunca se hunde en la mesa: su mitad de alto depende de cuánto está inclinado
	var ext := HALF * (absf((q * Vector3.RIGHT).y) + absf((q * Vector3.UP).y) + absf((q * Vector3.BACK).y))
	pos.y += ext - HALF
	return {"pos": pos, "quat": q, "squash": squash}


## Se pone cada dado según el estado del juego `g` (dice_game.gd) en este cuadro.
func update(g, delta: float) -> void:
	_t += delta
	var k := 1.0 - exp(-14.0 * delta)
	var t_throw: float = g._phase_t if g.phase == PH_ROLLING else (g.ROLL_TIME + g._phase_t)
	for i in 5:
		var node := dice[i]
		var mat := mats[i]
		var picking: bool = g.phase == PH_PICK or g.phase == 0
		var throwing: bool = (g.phase == PH_ROLLING or g.phase == PH_REVEAL) and g.unrevealed.has(i)
		var revealed: bool = g._is_revealed(i)
		var hit: bool = revealed and g.rolls[i] == g.picks[i]
		var pos := rest_pos(i)
		var q: Quaternion
		var squash := 0.0
		var tint := Color.WHITE
		var glow := 0.0
		if throwing:
			var st := throw_state(i, t_throw, g.rolls[i], g.throws_left)
			pos = st.pos
			q = st.quat
			squash = st.squash
			_cur_q[i] = q
		else:
			var face: int = g.picks[i] if picking else g.rolls[i]
			var target: Quaternion = orient_for(face, YAWS[i])
			if picking and i == g.selected:
				target = Quaternion(Vector3.UP, sin(_t * 1.6) * 0.18) * target   # el elegido se mece un poquito
				pos.y += 0.05 + 0.05 * sin(_t * 3.0)
				glow = 0.4 + 0.12 * sin(_t * 5.0)
			_cur_q[i] = _cur_q[i].slerp(target, k)
			q = _cur_q[i]
			if revealed:
				var age := maxf(g._t - float(g._reveal_t[i]), 0.0)
				pos.y += maxf(0.0, 1.0 - age * 3.0) * 0.3 * sin(minf(age * 3.0, 1.0) * PI + 0.0001)
				tint = Color(0.66, 1.0, 0.74) if hit else Color(1.0, 0.66, 0.66)
				if hit and age < 0.9:
					glow = 0.6 * (1.0 - age / 0.9)
		node.position = pos
		node.basis = Basis(q).scaled(Vector3(1.0 + squash * 0.7, 1.0 - squash, 1.0 + squash * 0.7))
		mat.albedo_color = tint
		mat.emission_enabled = glow > 0.01
		mat.emission = Color(1.0, 0.9, 0.5) if not revealed else (Color(0.4, 1.0, 0.6) if hit else Color(1.0, 0.4, 0.4))
		mat.emission_energy_multiplier = glow
		# la sombra: más chica y más clara cuanto más alto está el dado
		var h := maxf(pos.y - HALF, 0.0)
		var near := 1.0 - clampf(h / DROP, 0.0, 1.0)
		var sh := shadows[i]
		sh.position = Vector3(pos.x, 0.012, pos.z)
		sh.scale = Vector3.ONE * (0.55 + 0.7 * near)
		(sh.material_override as StandardMaterial3D).albedo_color = Color(0.0, 0.0, 0.0, 0.1 + 0.34 * near)
		# el candado verde de los dados retenidos mientras se espera la próxima tirada
		var lk := locks[i]
		lk.visible = g.phase == PH_HOLD and hit
		lk.position = Vector3(rest_pos(i).x, 1.35 + 0.06 * sin(_t * 3.0 + i), 0.0)
		lk.rotation = Vector3(deg_to_rad(-52.0), 0.0, 0.0)
	_update_sparks(delta)


## Chispas doradas sobre el dado `i` (cuando acierta).
func burst(i: int) -> void:
	var origin := rest_pos(i) + Vector3(0.0, 0.5, 0.0)
	var r := RandomNumberGenerator.new()
	r.randomize()
	for k in 12:
		var mi := MeshInstance3D.new()
		mi.mesh = _spark_mesh
		mi.material_override = _spark_mat
		mi.position = origin
		viewport.add_child(mi)
		var ang := r.randf() * TAU
		var spd := r.randf_range(1.0, 2.4)
		_sparks.append({"node": mi, "vel": Vector3(cos(ang) * spd, r.randf_range(2.4, 4.2), sin(ang) * spd * 0.7), "age": 0.0})


func _update_sparks(delta: float) -> void:
	var keep: Array = []
	for sp in _sparks:
		sp.age += delta
		sp.vel.y -= 9.0 * delta
		var node: MeshInstance3D = sp.node
		node.position += sp.vel * delta
		node.scale = Vector3.ONE * clampf(1.0 - sp.age / 0.9, 0.05, 1.0)
		if sp.age >= 0.9:
			node.queue_free()
		else:
			keep.append(sp)
	_sparks = keep
