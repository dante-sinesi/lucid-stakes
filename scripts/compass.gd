extends Control
## Rosa de los vientos 3D hecha de cubitos: un disco plano en el piso con un brazo por cada tecla (W, A, S, D) apuntando al eje de la
## grilla al que mueve esa tecla. Rota y se inclina con la cámara (lee el yaw y el pitch reales cada cuadro, incluso mientras anima).

const VoxelDraw := preload("res://scripts/voxel_draw.gd")
const VFont := preload("res://scripts/voxel_font.gd")

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


func _draw() -> void:
	if not view_source.is_valid() or not dir_source.is_valid():
		return
	var v: Vector2 = view_source.call()
	var c := size * 0.5
	var unit := SPAN * 0.5 / (ARM + 2.2)   # lado de un cubito en el piso
	var cs := 7.0                          # lado dibujado de cada cubito
	# disco del piso
	var ring: PackedVector2Array = []
	for i in 40:
		var a := TAU * i / 40.0
		ring.append(c + project(Vector2(cos(a), sin(a)) * (ARM + 1.6), v.x, v.y) * unit)
	draw_colored_polygon(ring, Color(0.05, 0.03, 0.10, 0.62))
	draw_polyline(ring + PackedVector2Array([ring[0]]), Color(0.75, 0.70, 0.85, 0.55), 2.0)
	# brazos: cubitos del centro hacia afuera, ordenados de atrás hacia adelante
	var items: Array = []
	items.append({"p": c, "depth": 0.0, "col": VoxelDraw.MARBLE, "lift": 0.0})
	for k in KEYS:
		var d: Vector3i = dir_source.call(k[1], k[2])
		var g := Vector2(d.x, d.z)
		var north: bool = k[0] == "W"
		for i in range(1, ARM + 1):
			var col := VoxelDraw.GOLD if north else VoxelDraw.MARBLE.darkened(0.12 * (i % 2))
			var p := project(g * i, v.x, v.y)
			items.append({"p": c + p * unit, "depth": p.y, "col": col, "lift": 0.0})
		var tip := project(g * (ARM + 1.5), v.x, v.y)
		items.append({"p": c + tip * unit, "depth": tip.y + 0.01, "letter": k[0], "north": north})
	items.sort_custom(func(m, n): return m.depth < n.depth)
	for it in items:
		if it.has("letter"):
			_letter(it.p, it.letter, it.north)
		else:
			VoxelDraw.cube(self, it.p - Vector2(cs, cs) * 0.5 - Vector2(0, 3), cs, it.col, true)


func _letter(at: Vector2, ch: String, north: bool) -> void:
	var s := 2.2
	var origin := at - Vector2(VFont.W, VFont.H) * s * 0.5
	var col := VoxelDraw.GOLD if north else Color(0.93, 0.90, 0.83)
	VoxelDraw.text_cells(self, origin, VFont.glyph_cells(ch), VFont.H, s, col, 0.0, 0)
