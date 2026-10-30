extends SubViewportContainer
## Los dados del tabernero en 3D, hechos de cubitos como los bloques del juego: cinco dados con sus puntos hundidos, una mesa de fieltro verde con borde de madera, una cámara
## ortogonal que mira desde arriba y una caída con física simple (caen girando, rebotan cada vez menos con un aplastón al pegar y frenan mostrando la cara que salió).
## Lo maneja dice_game.gd: cada cuadro le pasa su estado (`update`) y le pide chispas (`burst`) cuando un dado acierta. También le dice dónde está cada dado en pantalla (`slot_screen_pos`)
## para dibujar encima las flechas de elegir y los números.

const VoxelMesh := preload("res://scripts/ui/voxel_mesh.gd")
const CRISTAL := preload("res://shaders/voxel_cristal.gdshader")
const CRISTAL_ATRAS := preload("res://shaders/voxel_cristal_atras.gdshader")

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
## El dado de cada casino. La taberna: hueso amarillento, comido en las esquinas y manchado, con alguna grieta violeta. El salón: marfil limpio con las esquinas de latón. El casino y el gran casino tienen
## varias alternativas (`ALTERNATIVAS`, indicadas con `variante`).
const DADOS := [
	{"cuerpo": Color(0.84, 0.78, 0.62), "pip": Color(0.22, 0.10, 0.26), "desgaste": 1.0, "mancha": Color(0.66, 0.58, 0.42), "grieta": Color(0.42, 0.14, 0.60), "rugosidad": 0.9, "metal": 0.0},
	{"cuerpo": Color(0.96, 0.93, 0.84), "pip": Color(0.15, 0.09, 0.20), "desgaste": 0.0, "esquina": Color(0.80, 0.62, 0.25), "rugosidad": 0.5, "metal": 0.0},
]
const ALTERNATIVAS := {
	2: [   # el casino (a elegir): A madera pulida, B perla rosada, C celadón, D mármol veteado
		{"cuerpo": Color(0.66, 0.42, 0.24), "pip": Color(0.97, 0.93, 0.82), "desgaste": 0.0, "vetas": "madera", "esquina": Color(0.80, 0.62, 0.25), "rugosidad": 0.3, "metal": 0.05},
		{"cuerpo": Color(0.96, 0.89, 0.87), "pip": Color(0.44, 0.20, 0.28), "desgaste": 0.0, "esquina": Color(0.86, 0.70, 0.58), "rugosidad": 0.3, "metal": 0.1},
		{"cuerpo": Color(0.68, 0.82, 0.75), "pip": Color(0.13, 0.30, 0.27), "desgaste": 0.0, "esquina": Color(0.80, 0.62, 0.25), "rugosidad": 0.3, "metal": 0.05},
		{"cuerpo": Color(0.94, 0.94, 0.95), "pip": Color(0.30, 0.31, 0.36), "desgaste": 0.0, "vetas": "marmol", "esquina": Color(0.80, 0.62, 0.25), "rugosidad": 0.25, "metal": 0.05},
	],
	3: [   # el gran casino: cáscara lila con las ocho esquinas de oro; el número y el núcleo son de cristal
		{"cuerpo": Color(0.78, 0.74, 1.0), "ventanas": true, "pip": Color(0.45, 0.34, 0.95, 0.80), "nucleo": Color(0.62, 0.52, 1.0, 0.62), "desgaste": 0.0, "esquina": Color(1.0, 0.85, 0.35), "rugosidad": 0.3, "metal": 0.1},
	],
}
var variante := 0   # la alternativa de dado del casino y del gran casino
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
var tier := 1                       # la estética de los dados y de la mesa según el casino (0 taberna, 1 salón, 2 casino, 3 gran casino; casino_theme.gd)
var _table_mi: MeshInstance3D
var vidrio_atras: Array[MeshInstance3D] = []     # el vidrio del dado de ventanas (el número y el núcleo): sus caras de atrás, que se dibujan antes
var vidrio_delante: Array[MeshInstance3D] = []   # y sus caras de adelante (dos mallas iguales, como el hielo: dentro de una sola Godot no ordena las caras translúcidas)
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
	var die_mesh := _malla_dado()
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
		mi.material_override = mat
		root.add_child(mi)
		var mi_atras := MeshInstance3D.new()   # (el vidrio: sólo se ve en el dado de ventanas del gran casino)
		mi_atras.position = mi.position
		root.add_child(mi_atras)
		vidrio_atras.append(mi_atras)
		var mi_delante := MeshInstance3D.new()
		mi_delante.position = mi.position
		root.add_child(mi_delante)
		vidrio_delante.append(mi_delante)
		_ajustar_material(mat, mi, mi_atras, mi_delante)
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

static func estilo(nivel: int, alt := 0) -> Dictionary:
	if ALTERNATIVAS.has(nivel):
		return ALTERNATIVAS[nivel][clampi(alt, 0, (ALTERNATIVAS[nivel] as Array).size() - 1)]
	return DADOS[clampi(nivel, 0, DADOS.size() - 1)]


## Las celdas de los puntos de un dado: para cada una, [la celda de la superficie, la normal de su cara].
static func _celdas_de_puntos() -> Array:
	var out: Array = []
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
					out.append([base + u * (su + du) + w * (sw + dw), n])
	return out


## El vidrio del dado de ventanas: el número (cada punto es una ventanita que baja dos minicubos hasta el núcleo) y el núcleo, un cubo de (N - 4) de lado en el centro con un degradé suave.
static func _vidrio_voxels(e: Dictionary) -> Dictionary:
	var vox := {}
	var nucleo: Color = e.nucleo
	for x in range(2, N - 2):
		for y in range(2, N - 2):
			for z in range(2, N - 2):
				var t := 1.0 - float(y - 2) / float(N - 5) * 0.3
				vox[Vector3i(x, y, z)] = Color(nucleo.r * t, nucleo.g * t, nucleo.b * t, nucleo.a)
	var pip: Color = e.pip
	for celda in _celdas_de_puntos():
		vox[celda[0]] = pip
		vox[celda[0] - celda[1]] = pip
	return vox


## La malla de la cáscara del dado del casino actual.
func _malla_dado() -> ArrayMesh:
	return VoxelMesh.build(_die_voxels(tier, variante), VOX)


## La malla del vidrio (con la opacidad de cada minicubo en UV.x, como el hielo).
func _malla_vidrio() -> ArrayMesh:
	return VoxelMesh.build(_vidrio_voxels(estilo(tier, variante)), VOX, func(_p, c: Color): return c.a)


## El material del dado (brillo y metal de la cáscara) y, en el dado de ventanas, el vidrio: los dos materiales translúcidos, el de adelante y el de las caras de atrás (que se dibuja antes).
func _ajustar_material(mat: StandardMaterial3D, mi: MeshInstance3D, mi_atras: MeshInstance3D, mi_delante: MeshInstance3D) -> void:
	var e := estilo(tier, variante)
	mat.roughness = float(e.rugosidad)
	mat.metallic = float(e.metal)
	mi.material_override = mat
	var ventanas := bool(e.get("ventanas", false))
	mi_atras.visible = ventanas
	mi_delante.visible = ventanas
	if not ventanas:
		return
	var delante := ShaderMaterial.new()
	delante.shader = CRISTAL
	delante.render_priority = 1
	var detras := ShaderMaterial.new()
	detras.shader = CRISTAL_ATRAS
	detras.render_priority = 0
	mi_delante.material_override = delante
	mi_atras.material_override = detras
	var vidrio := _malla_vidrio()
	mi_delante.mesh = vidrio
	mi_atras.mesh = vidrio
	for m in [mi_delante, mi_atras]:   # (un poco más chico que la cáscara hueca, para no tocar sus paredes)
		(m as MeshInstance3D).scale = Vector3.ONE * 0.97
		(m as MeshInstance3D).position = mi.position * 0.97


## Un número pseudoaleatorio estable en 0..1 para una celda.
static func _h(x: int, y: int, z: int, k: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (k * 2654435761)
	return float(absi(h) % 1000) / 1000.0


## El dado: un cubo de N x N x N cubitos con las aristas un poco más oscuras y los puntos hundidos (se saca el cubito de la superficie y el de abajo queda del color del punto). Cada casino
## tiene el suyo (`DADOS`, `ALTERNATIVAS`): desgastado en la taberna, con esquinas de latón en el salón, y en el casino y el gran casino los que se elijan (el del gran casino, de cáscara opaca con el número y el núcleo de cristal).
static func _die_voxels(nivel := 1, alt := 0) -> Dictionary:
	var e: Dictionary = estilo(nivel, alt)
	var ventanas := bool(e.get("ventanas", false))
	var cuerpo: Color = e.cuerpo
	var desgaste: float = e.desgaste
	var vox := {}
	for x in N:
		for y in N:
			for z in N:
				var edges := int(x == 0 or x == N - 1) + int(y == 0 or y == N - 1) + int(z == 0 or z == N - 1)
				var r := _h(x, y, z, 5)
				if desgaste > 0.0:   # (las esquinas y alguna arista, comidas)
					if edges == 3 and r < 0.6 * desgaste:
						continue
					if edges == 2 and r < 0.16 * desgaste:
						continue
				var tone := 1.0 - (0.09 if edges >= 2 else 0.0) - float((x * 7 + y * 13 + z * 17) % 5) * 0.012
				if e.get("vetas", "") == "madera":   # (las vetas de la madera pulida: vetas largas, más claras y más oscuras)
					tone *= 0.86 + 0.24 * _h(x, 0, z, 21) * (0.6 + 0.4 * _h(x, y / 3, z, 22))
				var col := Color(cuerpo.r * tone, cuerpo.g * tone, cuerpo.b * tone)
				if e.get("vetas", "") == "marmol" and (x + y + z * 2) % 7 == 0 and r < 0.75:
					col = Color(0.62 * tone, 0.63 * tone, 0.68 * tone)   # (las vetas grises del mármol)
				if bool(e.get("nacar", false)):   # (un reflejo que va del rosa al celeste según el lugar)
					col = col.lerp(Color(0.88, 0.93, 1.0) * tone, float(x + y + z) / float(3 * N - 3) * 0.7)
				if e.has("arista") and edges >= 2:
					var ar: Color = e.arista
					col = Color(ar.r * tone, ar.g * tone, ar.b * tone)
				elif e.has("esquina") and edges == 3:
					var esq: Color = e.esquina
					col = Color(esq.r * tone, esq.g * tone, esq.b * tone)
				elif desgaste > 0.0 and edges <= 1:
					if r > 1.0 - 0.1 * desgaste:
						col = e.mancha   # (manchas)
					elif (x * 5 + y * 3 + z * 11) % 23 == 0:
						col = e.grieta   # (una grieta violeta: la corrupción de la taberna)
				vox[Vector3i(x, y, z)] = col
	var pip_col: Color = e.pip
	pip_col.a = 1.0
	if ventanas:   # (la cáscara es opaca y hueca: los puntos son ventanas hasta el núcleo, que se rellenan con el vidrio aparte)
		for celda in _celdas_de_puntos():
			vox.erase(celda[0])
			vox.erase(celda[0] - celda[1])
		for x in range(2, N - 2):
			for y in range(2, N - 2):
				for z in range(2, N - 2):
					vox.erase(Vector3i(x, y, z))
		return vox
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


## Cambia la estética de los dados y de la mesa al casino `t` (0 taberna, 1 salón, 2 casino, 3 gran casino).
func set_tier(t: int, alt := 0) -> void:
	tier = clampi(t, 0, 3)
	variante = alt
	if _table_mi != null:
		_table_mi.queue_free()
	_build_table()
	var malla := _malla_dado()
	for i in dice.size():
		(dice[i].get_child(0) as MeshInstance3D).mesh = malla
		_ajustar_material(mats[i], dice[i].get_child(0) as MeshInstance3D, vidrio_atras[i], vidrio_delante[i])


## La mesa de cada casino. Taberna: tablones gastados, fieltro raído con parches de madera, una mancha y alguna grieta violeta. Salón: madera barnizada con tachuelas de latón y fieltro limpio. Casino: madera
## pulida con un filete dorado, gemas en las esquinas y fieltro profundo con su hilo dorado. Gran casino: mármol cálido con filigrana de oro, fieltro esmeralda con un rombo bordado en oro y pilares dorados en las esquinas.
func _build_table() -> void:
	var vox := {}
	var xn := int(TABLE_X / TABLE_VOX)
	var zn := int(TABLE_Z / TABLE_VOX)
	var oro := Color(0.92, 0.74, 0.28)
	for x in xn:
		for z in zn:
			var d := mini(mini(x, xn - 1 - x), mini(z, zn - 1 - z))   # (distancia al borde de la mesa)
			var rim := d < 2
			var n := float((x * 31 + z * 17) % 7) * 0.012
			var r := _h(x, 0, z, 9)
			var grueso := _h(x / 4, 1, z / 4, 3)   # (ruido en parches)
			var madera_borde := Color(0.42 - n, 0.26 - n, 0.12 - n)
			var madera_tapa := Color(0.5 - n, 0.31 - n, 0.15 - n)
			var madera_bajo := Color(0.3 - n, 0.18 - n, 0.08 - n)
			var fieltro := Color(0.1 + n, 0.4 + n * 1.4, 0.26 + n)
			var tapa := true   # (si el borde tiene el cubito de arriba)
			match tier:
				0:
					madera_borde = Color(0.30 - n, 0.18 - n, 0.08 - n)
					madera_tapa = Color(0.36 - n, 0.22 - n, 0.10 - n)
					madera_bajo = Color(0.22 - n, 0.13 - n, 0.06 - n)
					fieltro = Color(0.07 + n, 0.15 + n * 1.2, 0.12 + n)
					tapa = r > 0.12   # (el borde, mordido)
					if grueso < 0.14:
						fieltro = Color(0.25 - n, 0.15 - n, 0.07 - n)   # (parche gastado: se ve la madera)
					elif Vector2(x - xn * 0.3, z - zn * 0.62).length() < 5.0:
						fieltro = Color(0.04, 0.09, 0.07)   # (una mancha)
					elif (x + z * 2) % 37 == 0 and r < 0.7:
						fieltro = Color(0.28, 0.10, 0.40)   # (una grieta violeta)
				1:
					madera_borde = Color(0.46 - n, 0.27 - n, 0.12 - n)
					madera_tapa = Color(0.56 - n, 0.34 - n, 0.15 - n)
					madera_bajo = Color(0.40 - n, 0.24 - n, 0.11 - n)
					fieltro = Color(0.08 + n, 0.25 + n * 0.8, 0.17 + n) if (x + z) % 2 == 0 else Color(0.07 + n, 0.23 + n * 0.8, 0.155 + n)
				2:
					madera_borde = Color(0.22 - n, 0.12 - n, 0.07 - n)
					madera_tapa = Color(0.29 - n, 0.16 - n, 0.09 - n)
					madera_bajo = Color(0.17 - n, 0.09 - n, 0.05 - n)
					fieltro = Color(0.05 + n, 0.30 + n * 0.8, 0.20 + n)
				3:
					var veta := 0.0 if _h(x / 3, z / 3, 2, 7) > 0.2 else 0.12   # (vetas del mármol)
					madera_borde = Color(0.93 - veta - n, 0.90 - veta - n, 0.82 - veta - n)
					madera_tapa = Color(0.97 - veta - n, 0.94 - veta - n, 0.86 - veta - n)
					madera_bajo = Color(0.85 - n, 0.82 - n, 0.74 - n)
					fieltro = Color(0.04 + n, 0.38 + n * 0.8, 0.26 + n)
					if (x + z) % 10 == 0 or (x - z + 1000) % 10 == 0:
						fieltro = Color(0.06, 0.50, 0.34)   # (el rombo bordado en oro: hilos de otro verde)
			if rim:
				vox[Vector3i(x, 0, z)] = madera_borde
				if tapa:
					vox[Vector3i(x, 1, z)] = madera_tapa
				if tier == 1 and d == 1 and x % 8 == 4 and z % 1 == 0 and (x < 2 or x >= xn - 2 or z < 2 or z >= zn - 2) and (x % 8 == 4):
					vox[Vector3i(x, 1, z)] = Color(0.80, 0.62, 0.25)   # (tachuelas de latón)
				if tier >= 2 and d == 1:
					vox[Vector3i(x, 1, z)] = oro if tier == 2 else Color(1.0, 0.85, 0.35)   # (el filete dorado)
				if tier == 3 and d == 0 and (x + z) % 4 == 0:
					vox[Vector3i(x, 2, z)] = Color(1.0, 0.85, 0.35)   # (la filigrana: tachas doradas en el borde de afuera)
			else:
				vox[Vector3i(x, -1, z)] = fieltro
				if tier == 1 and d == 2:
					vox[Vector3i(x, -1, z)] = Color(0.80, 0.62, 0.25)   # (el hilo de latón junto al borde)
				if tier >= 2 and d == 2:
					vox[Vector3i(x, -1, z)] = oro if tier == 2 else Color(1.0, 0.85, 0.35)   # (el hilo dorado)
			for y in range(-4, -1):
				vox[Vector3i(x, y, z)] = madera_bajo
	if tier >= 2:   # las esquinas: gemas en el casino, pilares dorados en el gran casino
		for esquina in [Vector2i(0, 0), Vector2i(xn - 3, 0), Vector2i(0, zn - 3), Vector2i(xn - 3, zn - 3)]:
			for dx in 3:
				for dz in 3:
					var gema := Color(0.25, 0.45, 0.90) if (esquina.x + esquina.y) % 2 == 0 else Color(0.45, 0.20, 0.65)
					vox[Vector3i(esquina.x + dx, 2, esquina.y + dz)] = gema if tier == 2 else Color(1.0, 0.85, 0.35)
					if tier == 3:
						vox[Vector3i(esquina.x + dx, 3, esquina.y + dz)] = Color(1.0, 0.9, 0.5)
	# el fieltro está un cubito más abajo que el borde: el piso del fieltro es la capa y = -1
	_table_mi = MeshInstance3D.new()
	_table_mi.mesh = VoxelMesh.build(vox, TABLE_VOX)
	_table_mi.position = Vector3(-TABLE_X * 0.5, 0.0, -TABLE_Z * 0.5)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95 if tier == 0 else (0.7 if tier == 1 else 0.45)
	mat.metallic = 0.0 if tier < 3 else 0.1
	_table_mi.material_override = mat
	viewport.add_child(_table_mi)


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
