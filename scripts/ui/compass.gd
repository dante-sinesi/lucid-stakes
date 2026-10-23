extends Control
## Rosa de los vientos 3D hecha de cubitos: un disco plano en el piso con un brazo por cada tecla (W, A, S, D) apuntando al eje de la
## grilla al que mueve esa tecla. Rota y se inclina con la cámara (lee el yaw y el pitch reales cada cuadro, incluso mientras anima).

const VoxelDraw := preload("res://scripts/ui/voxel_draw.gd")
const VFont := preload("res://scripts/ui/voxel_font.gd")
const Settings := preload("res://scripts/datos/settings.gd")
const Controls := preload("res://scripts/entrada/controls.gd")

const KEYS := [["W", 1, 1], ["D", 1, -1], ["S", -1, -1], ["A", -1, 1]]
const ARM := 4          # cubitos por brazo
const SPAN := 130.0     # tamaño del control

## Dónde leer la cámara: devuelve Vector2(yaw en grados, pitch en grados). Y a qué eje va cada tecla (sx, sy) -> Vector3i.
var view_source: Callable
var dir_source: Callable


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SPAN, SPAN)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


## Proyecta un vector del piso (x, z) a pantalla: derecha de la cámara en x, y el "adelante" achatado por la inclinación en y.
static func project(g: Vector2, yaw_deg: float, pitch_deg: float) -> Vector2:
	var yaw := deg_to_rad(yaw_deg)
	var right := Vector2(cos(yaw), -sin(yaw))
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var elev := absf(sin(deg_to_rad(pitch_deg)))
	return Vector2(g.dot(right), -g.dot(fwd) * elev)


## La acción de movimiento que lleva cada letra de KEYS (para mostrar la tecla que el jugador tenga asignada).
const ACTION_OF := {"W": "mover_adelante", "D": "mover_derecha", "S": "mover_atras", "A": "mover_izquierda"}


func _draw() -> void:
	if not view_source.is_valid() or not dir_source.is_valid() or not Settings.compass_on():   # (se puede apagar desde Opciones)
		return
	var pad: bool = Controls.using_pad
	var v: Vector2 = view_source.call()
	var c := size * 0.5
	var unit := SPAN * 0.5 / (ARM + 2.4)   # lado de un cubito en el piso
	var t := Time.get_ticks_msec() / 1000.0
	# el disco: vidrio oscuro con un aro dorado y un aro fino, y ocho marcas de cubitos en el borde
	var ring: PackedVector2Array = []
	var inner: PackedVector2Array = []
	for i in 48:
		var a := TAU * i / 48.0
		ring.append(c + project(Vector2(cos(a), sin(a)) * (ARM + 1.9), v.x, v.y) * unit)
		inner.append(c + project(Vector2(cos(a), sin(a)) * (ARM - 0.2), v.x, v.y) * unit)
	draw_colored_polygon(ring, Color(0.04, 0.025, 0.09, 0.72))
	draw_polyline(ring + PackedVector2Array([ring[0]]), VoxelDraw.GOLD.darkened(0.15), 3.0)
	draw_polyline(inner + PackedVector2Array([inner[0]]), Color(0.75, 0.70, 0.85, 0.28), 1.5)
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		var mp := c + project(Vector2(cos(a), sin(a)) * (ARM + 1.9), v.x, v.y) * unit
		VoxelDraw.cube(self, mp - Vector2(2.5, 2.5), 5.0, VoxelDraw.GOLD if i % 2 == 0 else Color(0.8, 0.74, 0.55), true)
	# los brazos: rombos de cubitos que van de grandes a chicos hacia la punta (el del norte, dorado); atrás primero
	var items: Array = []
	items.append({"p": c, "depth": 0.0, "col": VoxelDraw.GOLD.lightened(0.15), "size": 8.0})
	var tips: Array = []
	for k in KEYS:
		var d: Vector3i = dir_source.call(k[1], k[2])
		var g := Vector2(d.x, d.z)
		var north: bool = k[0] == "W"
		for i in range(1, ARM + 1):
			var col := VoxelDraw.GOLD if north else VoxelDraw.MARBLE.darkened(0.1 * (i % 2))
			var p := project(g * i, v.x, v.y)
			items.append({"p": c + p * unit, "depth": p.y, "col": col, "size": maxf(8.0 - float(i) * 1.1, 3.5)})
		var tip := project(g * (ARM + 1.1), v.x, v.y)
		var dir2 := project(g, v.x, v.y)
		tips.append({"p": c + tip * unit, "key": k[0], "north": north, "dir": dir2.normalized() if dir2.length() > 0.01 else Vector2.UP})
	items.sort_custom(func(m, n): return m.depth < n.depth)
	for it in items:
		var sz: float = it.size
		VoxelDraw.cube(self, it.p - Vector2(sz, sz) * 0.5 - Vector2(0, 2), sz, it.col, true)
	# las puntas: con teclado, una tecla con su letra; con mando, un botón redondo con una flecha que apunta hacia donde mueve el stick
	for tp in tips:
		if pad:
			_pad_cap(tp.p, tp.dir, tp.north, t)
		else:
			_key_cap(tp.p, str(tp.key), tp.north)
	if pad:   # en el centro, el stick izquierdo
		draw_circle(c, 7.0, Color(0.05, 0.03, 0.09))
		draw_circle(c, 5.8, VoxelDraw.GOLD)
		_letter(c + Vector2(0, -0.5), "L", false, Color(0.1, 0.06, 0.14))


## La tecla del teclado (o la que el jugador haya puesto) dibujada como una teclita de cubitos con su letra.
func _key_cap(at: Vector2, key: String, north: bool) -> void:
	var label: String = Controls.key_name(Controls.key_of(str(ACTION_OF.get(key, "")))).to_upper()
	if label.length() > 3:
		label = label.substr(0, 3)
	var r := Rect2(at - Vector2(11, 11), Vector2(22, 22))
	draw_rect(r.grow(2.0), Color(0.04, 0.025, 0.09))
	draw_rect(r, VoxelDraw.GOLD if north else Color(0.86, 0.82, 0.74))
	draw_rect(Rect2(r.position + Vector2(0, 17), Vector2(22, 5)), (VoxelDraw.GOLD if north else Color(0.86, 0.82, 0.74)).darkened(0.3))
	draw_rect(Rect2(r.position, Vector2(22, 3)), Color(1, 1, 1, 0.35))
	_letter(at - Vector2(0, 2), label, north, Color(0.1, 0.06, 0.14))


## El mando: un botón redondo con una flecha que apunta en la dirección de la rosa (se mueve un poquito, como invitando a empujar el stick).
func _pad_cap(at: Vector2, dir: Vector2, north: bool, t: float) -> void:
	var col := VoxelDraw.GOLD if north else Color(0.86, 0.82, 0.74)
	var nudge := dir * sin(t * 4.0 + (0.0 if north else 1.5)) * 1.5
	var c := at + nudge
	draw_circle(c, 13.0, Color(0.04, 0.025, 0.09))
	draw_circle(c, 11.0, col)
	draw_arc(c, 11.0, 0.0, TAU, 24, col.lightened(0.35), 1.5)
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([c + dir * 9.0, c - dir * 5.5 + side * 4.2, c - dir * 5.5 - side * 4.2]), Color(0.1, 0.06, 0.14))   # (larga y angosta: se lee hacia dónde apunta)


func _letter(at: Vector2, ch: String, north: bool, color := Color(-1, 0, 0)) -> void:
	var s := 2.0
	var cells := VFont.layout([ch], 0)
	var origin := at - Vector2(cells.size) * s * 0.5
	var col := color if color.r >= 0.0 else (VoxelDraw.GOLD if north else Color(0.93, 0.90, 0.83))
	VoxelDraw.text_cells(self, origin, cells.cells, cells.size.y, s, col, 0.0, 0)
