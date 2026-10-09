extends Control
## Ícono de la claridad: una barra vertical atravesada por tres barras horizontales (cruces), hecha de cubitos, vista en
## isométrico y girando. Colores cálidos, como el de un rayo: blanco amarillento por arriba, dorado y ámbar por los costados.
## `draw_bolt` lo dibuja con un ángulo fijo (para listas y ventanas); este Control lo dibuja girando.

const SPIN := 1.4   # radianes por segundo

var cube := 4.0:
	set(v):
		cube = v
		update_minimum_size()
		queue_redraw()
var _t := 0.0
var _model: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta * SPIN
	queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(13.0, 15.0) * cube


func _draw() -> void:
	draw_bolt(self, size * 0.5, cube, _t)


## Voxeles del modelo: la barra vertical (x = z = 0) y tres cruces horizontales a distinta altura y largo.
static func model() -> Array:
	var vs: Array = []
	for y in 11:
		vs.append(Vector3(0, y, 0))
	for bar in [[2, 2], [5, 3], [8, 2]]:   # [altura, largo de cada brazo]
		for i in range(1, bar[1] + 1):
			for sgn in [-1, 1]:
				vs.append(Vector3(sgn * i, bar[0], 0))
				vs.append(Vector3(0, bar[0], sgn * i))
	return vs


const STEPS := 90
static var _meshes := {}   # paso de giro -> malla (cubitos de lado 1, armada una sola vez)


## La malla del ícono visto con el giro `step`: se arma una vez por ángulo y después sólo se dibuja (antes se rearmaba cubito por cubito en
## cada cuadro, y este ícono está siempre en pantalla).
static func _mesh(step: int) -> ArrayMesh:
	if _meshes.has(step):
		return _meshes[step]
	var angle := TAU * float(step) / float(STEPS)
	var ca := cos(angle)
	var sa := sin(angle)
	var a := Vector2(0.866, 0.5)
	var b := Vector2(-0.866, 0.5)
	var c := Vector2(0, -1.0)
	var items: Array = []
	for v in model():
		var rx: float = v.x * ca + v.z * sa
		var rz: float = -v.x * sa + v.z * ca
		items.append({"p": a * rx + b * rz + c * v.y, "depth": (rx + rz) * 10.0 + v.y, "core": v.x == 0 and v.z == 0})
	items.sort_custom(func(m, n): return m.depth < n.depth)
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for it in items:
		var p: Vector2 = it.p
		var core: bool = it.core
		var top := Color(1.0, 0.98, 0.80) if core else Color(1.0, 0.95, 0.65)
		var right := Color(1.0, 0.86, 0.38) if core else Color(0.98, 0.78, 0.25)
		var left := Color(0.93, 0.68, 0.16) if core else Color(0.85, 0.57, 0.10)
		_quad(verts, cols, [p + a, p + a + b, p + a + b + c, p + a + c], right)
		_quad(verts, cols, [p + b, p + a + b, p + a + b + c, p + b + c], left)
		_quad(verts, cols, [p + c, p + a + c, p + a + b + c, p + b + c], top)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[step] = mesh
	return mesh


static func _quad(verts: PackedVector3Array, cols: PackedColorArray, p: Array, col: Color) -> void:
	for i in [0, 1, 2, 0, 2, 3]:
		verts.append(Vector3(p[i].x, p[i].y, 0.0))
		cols.append(col)


## Dibuja el ícono centrado en `center`, con cubitos de lado `s`, girado `angle` radianes alrededor del eje vertical.
static func draw_bolt(ci: CanvasItem, center: Vector2, s: float, angle: float) -> void:
	var step := int(round(fposmod(angle, TAU) / TAU * STEPS)) % STEPS
	var origin := center - Vector2(0, -5.0 * s)   # el centro del modelo (altura 5) queda en `center`
	ci.draw_set_transform(origin, 0.0, Vector2(s, s))
	ci.draw_mesh(_mesh(step), null)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
