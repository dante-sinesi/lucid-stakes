extends RefCounted
## El duende del portal de cada torre: pide claridad para encender el portal de salida. `build()` arma su modelo 3D (cubos) y `FACE` es su cara para el cuadro de diálogo y la
## ventana de la partida (12 x 13 cubitos, como la del tabernero).

const FACE := ["...hhhhhh...", "..hhhhhhhh..", ".ghhhhhhhhg.", "gggggggggggg", ".ggyyggyygg.", ".ggykggkygg.", ".gggggggggg.", "..gggnnggg..",
		"..gdmmmmdg..", "...gmmmmg...", "....gggg....", "..bbbbbbbb..", ".bbbbbbbbbb."]
const FACE_PAL := {"h": Color(0.62, 0.16, 0.12), "g": Color(0.42, 0.72, 0.24), "y": Color(0.96, 0.9, 0.4), "k": Color(0.06, 0.06, 0.06), "n": Color(0.3, 0.55, 0.18),
		"d": Color(0.22, 0.4, 0.12), "m": Color(0.93, 0.88, 0.8), "b": Color(0.5, 0.33, 0.2)}
const SPEAKER := "Duende"


## Dibuja la cara del duende en un control: `origin` es la esquina de arriba a la izquierda y `s` el lado de un cubito.
static func draw_face(ci: CanvasItem, origin: Vector2, s: float) -> void:
	for y in FACE.size():
		var row: String = FACE[y]
		for x in row.length():
			if row[x] == ".":
				continue
			var col: Color = FACE_PAL.get(row[x], Color.MAGENTA)
			var p := origin + Vector2(x, y) * s
			ci.draw_rect(Rect2(p, Vector2(s, s)), col)
			ci.draw_rect(Rect2(p, Vector2(s, maxf(s * 0.18, 1.0))), col.lightened(0.3))
			ci.draw_rect(Rect2(p + Vector2(0, s * 0.82), Vector2(s, maxf(s * 0.18, 1.0))), col.darkened(0.35))


static func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


## El duende en 3D (pequeño: unos 0,55 de alto, los pies en y = 0), mirando hacia +z.
static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "duende"
	var skin: Color = FACE_PAL.g
	var cloth: Color = FACE_PAL.b
	_box(root, Vector3(-0.07, 0.07, 0), Vector3(0.1, 0.14, 0.12), Color(0.25, 0.16, 0.1))   # piernas
	_box(root, Vector3(0.07, 0.07, 0), Vector3(0.1, 0.14, 0.12), Color(0.25, 0.16, 0.1))
	_box(root, Vector3(0, 0.22, 0), Vector3(0.28, 0.17, 0.17), cloth)                      # cuerpo
	_box(root, Vector3(-0.17, 0.21, 0), Vector3(0.07, 0.15, 0.08), skin)                   # brazos
	_box(root, Vector3(0.17, 0.21, 0), Vector3(0.07, 0.15, 0.08), skin)
	_box(root, Vector3(0, 0.39, 0), Vector3(0.24, 0.2, 0.2), skin)                         # cabeza
	_box(root, Vector3(-0.19, 0.42, 0), Vector3(0.14, 0.05, 0.05), skin)                   # orejas puntiagudas
	_box(root, Vector3(0.19, 0.42, 0), Vector3(0.14, 0.05, 0.05), skin)
	_box(root, Vector3(-0.05, 0.4, 0.1), Vector3(0.05, 0.05, 0.02), FACE_PAL.y)            # ojos
	_box(root, Vector3(0.05, 0.4, 0.1), Vector3(0.05, 0.05, 0.02), FACE_PAL.y)
	_box(root, Vector3(-0.05, 0.4, 0.11), Vector3(0.02, 0.03, 0.02), FACE_PAL.k)
	_box(root, Vector3(0.05, 0.4, 0.11), Vector3(0.02, 0.03, 0.02), FACE_PAL.k)
	_box(root, Vector3(0, 0.35, 0.11), Vector3(0.09, 0.03, 0.02), FACE_PAL.m)              # sonrisa
	_box(root, Vector3(0, 0.51, 0), Vector3(0.26, 0.05, 0.22), FACE_PAL.h)                 # gorro
	_box(root, Vector3(0, 0.56, 0), Vector3(0.18, 0.06, 0.16), FACE_PAL.h)
	_box(root, Vector3(0, 0.61, 0), Vector3(0.1, 0.06, 0.1), FACE_PAL.h)
	return root
