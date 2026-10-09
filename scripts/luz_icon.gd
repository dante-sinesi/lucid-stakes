extends Control
## Ícono de la Luz: una esfera hecha de cubitos de verdad (voxels), vista en isométrico, como un sol en miniatura: arriba y al
## centro es blanco amarillento y hacia abajo se va a naranja; cada cubito muestra sus tres caras (arriba clara, derecha media,
## izquierda oscura) con una juntita entre ellos, así se nota que es un bloque. Late, y suelta cubitos más chicos que salen
## disparados hacia afuera y se apagan. `draw_sun` lo dibuja en cualquier control (botones, tarjetas); este Control lo dibuja animado.

const RADIUS := 4.4    # radio de la esfera fina, en cubitos (la que se usa cuando el ícono es grande)
const COARSE_RADIUS := 2.6   # esfera gruesa: con menos cubitos pero más grandes, para que a tamaño chico se siga notando cada voxel
const COARSE_BELOW := 6.0    # por debajo de este lado de cubito se usa la gruesa
const RAYS := 12       # partículas
const LIFE := 1.3      # segundos que dura cada partícula

static var _cache := {}   # lado del cubito -> esfera ya armada (la forma no cambia, sólo la luz)

var cube := 3.0:
	set(v):
		cube = v
		update_minimum_size()
		queue_redraw()
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2.ONE * radius_px(cube) * 2.5


## Radio de la esfera en píxeles para un cubito de lado `size_in` (el que se pasa a draw_sun).
static func radius_px(size_in: float) -> float:
	var coarse := size_in < COARSE_BELOW
	return (COARSE_RADIUS * size_in * (RADIUS / COARSE_RADIUS)) if coarse else RADIUS * size_in


func _draw() -> void:
	draw_sun(self, size * 0.5, cube, _t)


## Los cubitos de la esfera ordenados de atrás hacia adelante: [{p: posición en pantalla, k: 0 (abajo) a 1 (arriba), faces: qué caras se ven}].
static func _sphere(radius: float) -> Array:
	var key := int(radius * 10.0)
	if _cache.has(key):
		return _cache[key]
	var n := int(ceil(radius))
	var solid := {}
	for x in range(-n, n + 1):
		for y in range(-n, n + 1):
			for z in range(-n, n + 1):
				if Vector3(x, y, z).length() <= radius:
					solid[Vector3i(x, y, z)] = true
	var out: Array = []
	for c in solid:
		var faces := 0   # bits: 1 = arriba, 2 = derecha (+x), 4 = izquierda (+z)
		if not solid.has(c + Vector3i(0, 1, 0)):
			faces |= 1
		if not solid.has(c + Vector3i(1, 0, 0)):
			faces |= 2
		if not solid.has(c + Vector3i(0, 0, 1)):
			faces |= 4
		if faces == 0:
			continue
		out.append({"c": c, "depth": float(c.x + c.z) * 10.0 + float(c.y), "faces": faces,
				"k": _light(c, radius)})
	out.sort_custom(func(m, o): return m.depth < o.depth)
	_cache[key] = out
	return out


## Cuánta luz recibe un cubito de la esfera (0 = borde naranja, 1 = centro casi blanco): cuanto más de frente a la cámara
## isométrica y un poco más arriba, más claro. Eso hace que la silueta lea como una esfera y no como un cubo grande.
static func _light(c: Vector3i, radius: float) -> float:
	var n := Vector3(c).normalized()
	var facing := n.dot(Vector3(1, 1, 1).normalized())
	return clampf(0.2 + 0.85 * facing + 0.1 * float(c.y) / radius, 0.0, 1.0)


## Dibuja el sol centrado en `center`, con cubitos de lado `s`, en el instante `t` (segundos).
static func draw_sun(ci: CanvasItem, center: Vector2, size_in: float, t: float) -> void:
	# A tamaño chico se usa la esfera gruesa (menos cubitos, más grandes): el sol ocupa lo mismo y los voxels se siguen viendo.
	var coarse := size_in < COARSE_BELOW
	var radius := COARSE_RADIUS if coarse else RADIUS
	var s := size_in * (RADIUS / COARSE_RADIUS) if coarse else size_in
	var a := Vector2(0.866, 0.5) * s     # eje x en pantalla
	var b := Vector2(-0.866, 0.5) * s    # eje z en pantalla
	var c := Vector2(0, -1.0) * s        # eje y en pantalla
	var beat := 0.5 + 0.5 * sin(t * 4.5)
	var gap := clampf(s * 0.07, 0.4, 0.9)   # junta entre cubitos: se nota que cada uno es un bloque
	var r := radius * s
	ci.draw_circle(center, r * 1.5, Color(1.0, 0.8, 0.3, 0.10 + 0.05 * beat))
	# Partículas que quedan detrás de la esfera, la esfera, y las que quedan delante
	var behind: Array = []
	var front: Array = []
	for i in RAYS:
		var phase := fposmod(t / LIFE + float(i) * 0.6180339, 1.0)
		var az := float(i) * 2.3999632 + t * 0.4
		var el := asin(clampf(1.0 - 2.0 * (float(i) + 0.5) / RAYS, -1.0, 1.0))
		var dir := Vector3(cos(el) * cos(az), sin(el), cos(el) * sin(az))
		var dist := radius + 0.8 + phase * radius * 0.9
		var q := dir * dist
		var p := {"pos": center + a * q.x + b * q.z + c * q.y, "phase": phase, "depth": q.x + q.z}
		(front if q.x + q.z > 0.0 else behind).append(p)
	for p in behind:
		_particle(ci, p, a, b, c)
	# La esfera es siempre la misma: se arma una sola vez como malla y cada cuadro sólo se dibuja (el latido es un brillo sobre toda la malla).
	ci.draw_set_transform(center, 0.0, Vector2.ONE)
	ci.draw_mesh(_sphere_mesh(radius, s, gap), null, Transform2D.IDENTITY, Color(1, 1, 1).lightened(0.08 * beat))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for p in front:
		_particle(ci, p, a, b, c)


static var _mesh_cache := {}   # "radio|lado" -> malla de la esfera


## La esfera de cubitos como una malla (cada cubito con sus caras visibles y su juntita), con el centro de la esfera en el origen.
static func _sphere_mesh(radius: float, s: float, gap: float) -> ArrayMesh:
	var key := "%d|%d" % [int(radius * 10.0), int(s * 100.0)]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var a := Vector2(0.866, 0.5) * s
	var b := Vector2(-0.866, 0.5) * s
	var c := Vector2(0, -1.0) * s
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for v in _sphere(radius):
		var o: Vector2 = a * v.c.x + b * v.c.z + c * v.c.y
		var base := Color(1.0, 0.55, 0.12).lerp(Color(1.0, 0.97, 0.72), v.k)   # abajo naranja, arriba casi blanco
		var center := o + (a + b + c) * 0.5
		var f := 1.0 - gap / maxf(a.length(), 1.0)
		if v.faces & 1:
			_add_face(verts, cols, _shrink([o + c, o + a + c, o + a + b + c, o + b + c], center, f), base.lightened(0.28))
		if v.faces & 2:
			_add_face(verts, cols, _shrink([o + a, o + a + b, o + a + b + c, o + a + c], center, f), base)
		if v.faces & 4:
			_add_face(verts, cols, _shrink([o + b, o + a + b, o + a + b + c, o + b + c], center, f), base.darkened(0.3))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_cache[key] = mesh
	return mesh


static func _add_face(verts: PackedVector3Array, cols: PackedColorArray, quad: PackedVector2Array, col: Color) -> void:
	for i in [0, 1, 2, 0, 2, 3]:
		verts.append(Vector3(quad[i].x, quad[i].y, 0.0))
		cols.append(col)


## Un cubito con sus caras visibles (arriba, derecha, izquierda), un poco achicadas hacia el centro para dejar la junta.
static func _voxel(ci: CanvasItem, o: Vector2, a: Vector2, b: Vector2, c: Vector2, col: Color, faces: int, gap: float) -> void:
	var center := o + (a + b + c) * 0.5 + Vector2(0, 0)
	var f := 1.0 - gap / maxf(a.length(), 1.0)
	if faces & 1:
		ci.draw_colored_polygon(_shrink([o + c, o + a + c, o + a + b + c, o + b + c], center, f), col.lightened(0.28))
	if faces & 2:
		ci.draw_colored_polygon(_shrink([o + a, o + a + b, o + a + b + c, o + a + c], center, f), col)
	if faces & 4:
		ci.draw_colored_polygon(_shrink([o + b, o + a + b, o + a + b + c, o + b + c], center, f), col.darkened(0.3))


static func _shrink(pts: Array, center: Vector2, f: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var mid := Vector2.ZERO
	for p in pts:
		mid += p
	mid /= float(pts.size())
	for p in pts:
		out.append(mid + (p - mid) * f)
	return out


## Una partícula: un cubito chico que se achica y se apaga (de blanco amarillento a naranja).
static func _particle(ci: CanvasItem, p: Dictionary, a: Vector2, b: Vector2, c: Vector2) -> void:
	var ph: float = p.phase
	var sz := 0.75 - 0.45 * ph
	var col := Color(1.0, 0.95 - 0.4 * ph, 0.5 - 0.3 * ph, 1.0 - ph * 0.85)
	var o: Vector2 = p.pos - (a + b + c) * sz * 0.5
	var aa := a * sz
	var bb := b * sz
	var cc := c * sz
	ci.draw_colored_polygon(PackedVector2Array([o + cc, o + aa + cc, o + aa + bb + cc, o + bb + cc]), col.lightened(0.28))
	ci.draw_colored_polygon(PackedVector2Array([o + aa, o + aa + bb, o + aa + bb + cc, o + aa + cc]), col)
	ci.draw_colored_polygon(PackedVector2Array([o + bb, o + aa + bb, o + aa + bb + cc, o + bb + cc]), col.darkened(0.3))
