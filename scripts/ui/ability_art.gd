extends RefCounted
## Íconos de las habilidades persistentes: cada uno es una figura de 9 x 9 cubitos (una letra por color, el punto es vacío) que se extruye en
## 3 capas de espesor y se dibuja en isométrico, girando despacio alrededor del eje vertical (como la Luz y la claridad).
## Si no tenés la habilidad el ícono se ve gris y quieto (en 3D, sin girar); si la tenés, a todo color, girando, flotando, con un brillo que lo cruza y chispas.

const ART := {
	"mente_despejada": {   # una lamparita encendida
		"pal": {"o": Color(0.9, 0.55, 0.1), "y": Color(1.0, 0.88, 0.3), "w": Color(1.0, 1.0, 0.85), "g": Color(0.6, 0.6, 0.66)},
		"rows": ["..ooooo..", ".oyyyyyo.", "oyywwwyyo", "oywwwwwyo", "oywwwwwyo", ".oyywwyo.", "..ogggo..", "..ogggo..", "...ooo..."]},
	"ojos_de_gato": {   # un ojo de pupila vertical
		"pal": {"g": Color(0.15, 0.5, 0.2), "y": Color(0.95, 0.85, 0.2), "p": Color(0.05, 0.05, 0.08)},
		"rows": [".........", "..ggggg..", ".gyyyyyg.", "gyyypyyyg", "gyyypyyyg", "gyyypyyyg", ".gyyyyyg.", "..ggggg..", "........."]},
	"pies_ligeros": {   # una bota con alas
		"pal": {"w": Color(0.95, 0.95, 1.0), "b": Color(0.78, 0.2, 0.2), "s": Color(0.32, 0.2, 0.14)},
		"rows": ["ww.......", "wwww.bb..", ".www.bb..", "....bbb..", "....bbb..", "...bbbbb.", "..bbbbbbb", "..sssssss", "........."]},
	"bolsillo_sonador": {   # una bolsita con su cordón
		"pal": {"r": Color(0.8, 0.15, 0.2), "p": Color(0.5, 0.32, 0.75), "a": Color(1.0, 0.85, 0.3)},
		"rows": ["...rrr...", "....r....", "..ppppp..", ".ppppppp.", "pppaaappp", "pppaaappp", "ppppppppp", ".ppppppp.", "..ppppp.."]},
	"segunda_oportunidad": {   # una flecha que da la vuelta
		"pal": {"g": Color(0.35, 0.75, 0.45), "a": Color(0.75, 1.0, 0.8)},
		"rows": ["..gggg.a.", ".gg...aaa", "gg.....a.", "g.......g", "g.......g", "gg.....gg", ".gg...gg.", "..ggggg..", "........."]},
	"racha_firme": {   # una llama
		"pal": {"o": Color(1.0, 0.45, 0.1), "y": Color(1.0, 0.8, 0.2), "w": Color(1.0, 1.0, 0.8)},
		"rows": ["....o....", "...oo....", "..ooyo...", "..oyyoo..", ".ooyyyoo.", ".oyywyyo.", ".oyywwyo.", "..oyyyo..", "...ooo..."]},
	"corazon": {   # una vida (el contador de vidas): un corazón
		"pal": {"r": Color(0.92, 0.16, 0.27), "h": Color(1.0, 0.62, 0.68), "d": Color(0.62, 0.06, 0.16)},
		"rows": ["..rr.rr..", ".rhrrrrr.", "rhrrrrrrr", "rrrrrrrrr", "rrrrrrrrr", ".rrrrrrd.", "..rrrrd..", "...rdd...", "....d...."]},
	"corazon_extra": {   # un corazón con una cruz dorada: una vida de más
		"pal": {"r": Color(0.92, 0.16, 0.27), "h": Color(1.0, 0.62, 0.68), "d": Color(0.62, 0.06, 0.16), "y": Color(1.0, 0.88, 0.3)},
		"rows": ["..rr.rr..", ".rhrrrrr.", "rhrrryrrr", "rrrryyyrr", "rrrrryrrr", ".rrrrrrd.", "..rrrrd..", "...rdd...", "....d...."]},
	"margen_de_error": {   # una diana: un poco de margen alrededor del centro
		"pal": {"r": Color(0.85, 0.2, 0.2), "w": Color(0.96, 0.96, 1.0), "y": Color(1.0, 0.85, 0.2)},
		"rows": ["..rrrrr..", ".rwwwwwr.", "rwwrrrwwr", "rwrwwwrwr", "rwrwywrwr", "rwrwwwrwr", "rwwrrrwwr", ".rwwwwwr.", "..rrrrr.."]},
	"mecha_larga": {   # una bomba con la mecha larga
		"pal": {"g": Color(0.22, 0.22, 0.26), "h": Color(0.5, 0.5, 0.56), "f": Color(0.6, 0.35, 0.12), "y": Color(1.0, 0.85, 0.2), "o": Color(1.0, 0.45, 0.1)},
		"rows": [".....y..y", "......o..", ".....f...", "....f....", "..ggggg..", ".gghgggg.", ".ghgggggg", ".ggggggg.", "..ggggg.."]},
	"buena_letra": {   # un papel con su sello de lacre: un contrato bien visto
		"pal": {"p": Color(0.95, 0.88, 0.7), "d": Color(0.7, 0.55, 0.35), "k": Color(0.25, 0.15, 0.1), "r": Color(0.8, 0.15, 0.18)},
		"rows": [".ppppppp.", ".pkkkkkp.", ".ppppppp.", ".pkkkkpp.", ".ppppppp.", "..pprrrp.", "..pprrrp.", ".ppppppp.", ".ddddddd."]},
	"buen_regateo": {   # una moneda con una flecha hacia abajo: el peaje baja
		"pal": {"g": Color(1.0, 0.85, 0.3), "o": Color(0.75, 0.55, 0.1), "w": Color(1.0, 0.97, 0.8), "a": Color(0.3, 0.75, 0.4)},
		"rows": ["..ggggg..", ".gwggggo.", "gwggagggo", "gwggagggo", "gwaaaaago", "gggaaaggo", "ggggaggoo", ".gooooog.", "..ooooo.."]},
}


static var _models := {}   # id -> cubitos 3D ya armados
const SPIN := 0.55         # radianes por segundo (despacio)
const START_ANGLE := 0.7   # ángulo fijo de los que no se tienen


## El modelo 3D de una habilidad: [{x, y, z, col}] con x e y centrados (y hacia arriba). Cada celda se extruye en profundidad según qué tan
## adentro de la figura está (como una almohadilla): el borde tiene 3 cubitos de espesor y el centro hasta 5.
static func model(id: String) -> Array:
	if _models.has(id):
		return _models[id]
	var art: Dictionary = ART.get(id, ART.ojos_de_gato)
	var rows: Array = art.rows
	var out: Array = []
	var h := rows.size()
	var w: int = rows[0].length()
	for ry in h:
		var line: String = rows[ry]
		for rx in line.length():
			var ch := line[rx]
			if ch == ".":
				continue
			var col: Color = art.pal.get(ch, Color.MAGENTA)
			var depth := 1   # distancia al vacío más cercano (en celdas, en cruz), hasta 3
			while depth < 3:
				var all_full := true
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = rx + d.x * depth
					var ny: int = ry + d.y * depth
					if nx < 0 or ny < 0 or ny >= h or nx >= w or rows[ny][nx] == ".":
						all_full = false
				if not all_full:
					break
				depth += 1
			depth = maxi(depth, 2)   # como mínimo 3 capas (la figura nunca es una lámina)
			var pos := Vector2(rx - w / 2, (h - 1) / 2 - ry)
			for z in range(-(depth - 1), depth):
				out.append({"x": pos.x, "y": pos.y, "z": z, "col": col})
	_models[id] = out
	return out


const STEPS := 120   # ángulos distintos en una vuelta: cada uno es una malla armada una sola vez (ver `_mesh`)
static var _meshes := {}   # "id|paso|a color" -> ArrayMesh


## La malla (triángulos de colores, con cubitos de lado 1) del ícono visto con el giro `step` (de 0 a STEPS - 1). Armar el ícono cubito por
## cubito en cada cuadro era carísimo (cientos de cubitos con sus tres caras, ordenados, por cada ícono en pantalla); así se arma una vez por
## ángulo y después sólo se dibuja la malla.
static func _mesh(id: String, step: int, owned: bool) -> ArrayMesh:
	var key := "%s|%d|%d" % [id, step, 1 if owned else 0]
	if _meshes.has(key):
		return _meshes[key]
	var angle := TAU * float(step) / float(STEPS)
	var ca := cos(angle)
	var sa := sin(angle)
	var a := Vector2(0.866, 0.5)     # eje x en pantalla
	var b := Vector2(-0.866, 0.5)    # eje z en pantalla
	var c := Vector2(0, -1.0)        # eje y en pantalla
	var items: Array = []
	for v in model(id):
		var rx: float = v.x * ca + v.z * sa
		var rz: float = -v.x * sa + v.z * ca
		var col: Color = v.col
		if not owned:
			var g := col.get_luminance() * 0.55 + 0.06
			col = Color(g, g, g * 1.05)
		items.append({"p": a * rx + b * rz + c * float(v.y), "depth": (rx + rz) * 10.0 + float(v.y), "col": col})
	items.sort_custom(func(m, n): return m.depth < n.depth)
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for it in items:
		var o: Vector2 = it.p - (a + b + c) * 0.5
		var col: Color = it.col
		_quad(verts, cols, [o + a, o + a + b, o + a + b + c, o + a + c], col)
		_quad(verts, cols, [o + b, o + a + b, o + a + b + c, o + b + c], col.darkened(0.3))
		_quad(verts, cols, [o + c, o + a + c, o + a + b + c, o + b + c], col.lightened(0.28))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[key] = mesh
	return mesh


static func _quad(verts: PackedVector3Array, cols: PackedColorArray, p: Array, col: Color) -> void:
	for i in [0, 1, 2, 0, 2, 3]:
		verts.append(Vector3(p[i].x, p[i].y, 0.0))
		cols.append(col)


## Dibuja el ícono centrado en `center`, con cubitos de lado `s`. `owned`: a color, girando y animado (con `t` en segundos); si no, gris y quieto.
static func draw(ci: CanvasItem, id: String, center: Vector2, s: float, owned: bool, t: float) -> void:
	var angle := t * SPIN if owned else START_ANGLE
	var step := int(round(fposmod(angle, TAU) / TAU * STEPS)) % STEPS
	var bob := sin(t * 2.2) * s * 0.35 if owned else 0.0
	ci.draw_set_transform(center + Vector2(0, bob), 0.0, Vector2(s, s))
	ci.draw_mesh(_mesh(id, step, owned), null)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if owned:   # chispas que giran alrededor
		for i in 4:
			var ph := fposmod(t * 0.9 + float(i) * 0.25, 1.0)
			var ang := float(i) * 1.7 + t * 0.6
			var pos := center + Vector2(cos(ang), sin(ang) * 0.9) * s * (7.0 + ph * 1.2)
			var sp := maxf(s * 0.3, 2.0)
			ci.draw_rect(Rect2(pos - Vector2(sp, sp) * 0.5, Vector2(sp, sp)), Color(1.0, 0.97, 0.7, sin(ph * PI)))
