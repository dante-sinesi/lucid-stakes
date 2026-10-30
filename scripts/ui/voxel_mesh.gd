extends RefCounted
## Construye una malla a partir de un mapa de minibloques {Vector3i: Color} (el color va en los vértices).
## Sólo se dibujan las caras que se ven. Las coordenadas son en minibloques; `size` es el lado de un minibloque en el mundo.

const DIRS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
		Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


## `opacidad`: función (posición, color) -> 0..1 que va en UV.x (la usan los shaders translúcidos, como el del hielo y el del dado de cristal).
static func build(vox: Dictionary, size: float, opacidad := Callable()) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in vox:
		for d in DIRS:
			if not vox.has(p + d):
				_face(st, p, d, vox[p], size, float(opacidad.call(p, vox[p])) if opacidad.is_valid() else 1.0)
	return st.commit()


static func _face(st: SurfaceTool, p: Vector3i, d: Vector3i, c: Color, size: float, opacidad := 1.0) -> void:
	var n := Vector3(d)
	var a := Vector3(0, 1, 0)
	var b := Vector3(0, 0, 1)
	if d.y != 0:
		a = Vector3(1, 0, 0)
	elif d.z != 0:
		a = Vector3(1, 0, 0)
		b = Vector3(0, 1, 0)
	var center := (Vector3(p) + Vector3(0.5, 0.5, 0.5) + n * 0.5) * size
	var h := size * 0.5
	var v0 := center - a * h - b * h
	var v1 := center + a * h - b * h
	var v2 := center + a * h + b * h
	var v3 := center - a * h + b * h
	# Godot dibuja de frente las caras en sentido horario vistas desde afuera: el producto vectorial del
	# triángulo tiene que apuntar contra la normal; si no, se invierte el orden.
	if (v1 - v0).cross(v2 - v0).dot(n) > 0.0:
		var t := v1
		v1 = v3
		v3 = t
	for v in [v0, v1, v2, v0, v2, v3]:
		st.set_color(c)
		st.set_normal(n)
		st.set_uv(Vector2(opacidad, 0.0))
		st.add_vertex(v)
