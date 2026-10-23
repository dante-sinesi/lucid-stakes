extends RefCounted
## Dibujo de la interfaz con cubitos. Vista de frente: cada cubito tiene luz arriba/izquierda, sombra abajo/derecha y una sombra
## dura sobre lo que tiene atrás; el volumen sale de los niveles (placa, borde, letras) y de cómo se inclinan las cartas.
## Estilo híbrido: algo que era limpio (mármol, dorado) y se está corrompiendo (cubitos violetas, huecos y chorreras oscuras
## que crecen con `corruption` y se concentran hacia abajo).

const VFont := preload("res://scripts/ui/voxel_font.gd")

const MARBLE := Color(0.93, 0.90, 0.83)
const GOLD := Color(1.0, 0.85, 0.40)
const PLATE := Color(0.13, 0.07, 0.22)
const PLATE_HOVER := Color(0.22, 0.12, 0.34)
const CORRUPT_A := Color(0.38, 0.10, 0.54)
const CORRUPT_B := Color(0.64, 0.22, 0.80)
const VOID := Color(0.04, 0.02, 0.07)

## Corrupción por defecto de la interfaz (se puede cambiar según la etapa).
static var default_corruption := 0.45
## Modo de lectura (Opciones): letras sin corrupción, más claras y con contorno oscuro.
static var reading := false
## Alto contraste (Opciones): cartas más oscuras y de borde blanco, sin ruido ni corrupción.
static var high_contrast := false


## Número pseudoaleatorio estable en 0..1 para una celda (no cambia entre cuadros).
static func noise(x: int, y: int, seed_value: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (seed_value * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(absi(h) % 10000) / 10000.0


## Un cubito de lado `s` en `pos`: cara + luz arriba y a la izquierda + sombra abajo y a la derecha.
static func cube(ci: CanvasItem, pos: Vector2, s: float, col: Color, simple := false) -> void:
	if s >= 5.0:  # un píxel de junta entre cubitos para que se lea la grilla
		s -= 1.0
	ci.draw_rect(Rect2(pos, Vector2(s, s)), col)
	if s < 2.0:
		return
	var b := maxf(1.0, floorf(s * 0.22))
	if simple:  # menos rectángulos: para superficies con muchísimos cubitos (la rueda de la ruleta, el remolino)
		ci.draw_rect(Rect2(pos, Vector2(s, b)), col.lightened(0.38))
		ci.draw_rect(Rect2(pos + Vector2(0, s - b), Vector2(s, b)), col.darkened(0.42))
		return
	var light := col.lightened(0.38)
	var dark := col.darkened(0.42)
	ci.draw_rect(Rect2(pos, Vector2(s, b)), light)
	ci.draw_rect(Rect2(pos, Vector2(b, s)), light.darkened(0.15))
	ci.draw_rect(Rect2(pos + Vector2(0, s - b), Vector2(s, b)), dark)
	ci.draw_rect(Rect2(pos + Vector2(s - b, 0), Vector2(b, s)), dark.lightened(0.1))


## Color de un cubito corrompido (dos violetas según el ruido).
static func corrupt_color(n: float) -> Color:
	return CORRUPT_A.lerp(CORRUPT_B, fmod(n * 7.0, 1.0))


## Dibuja celdas de texto (de VFont.layout). `height_cells`: alto del texto en celdas (la corrupción crece hacia abajo).
## Cada cubito proyecta una sombra dura abajo a la derecha, así las letras se leen sobre cualquier fondo.
static func text_cells(ci: CanvasItem, origin: Vector2, cells: Array, height_cells: int, s: float, color: Color, corruption: float, seed_value: int, shadow := true) -> void:
	var lit := {}
	for c in cells:
		lit[c] = true
	var h := float(maxi(height_cells, 1))
	if reading:
		corruption = 0.0
		color = color.lerp(Color.WHITE, 0.35)
		var o := maxf(1.0, s * 0.4)
		for c in cells:   # contorno oscuro: el texto se despega de cualquier fondo
			ci.draw_rect(Rect2(origin + Vector2(c.x, c.y) * s - Vector2(o, o), Vector2(s + o * 2.0, s + o * 2.0)), Color(0.0, 0.0, 0.02, 0.92))
	if shadow and s >= 2.0:
		var off := Vector2(maxf(1.0, s * 0.45), maxf(1.0, s * 0.65))
		for c in cells:
			ci.draw_rect(Rect2(origin + Vector2(c.x, c.y) * s + off, Vector2(s, s)), Color(0, 0, 0, 0.55))
	for c in cells:
		var n := noise(c.x, c.y, seed_value)
		var k := corruption * (0.35 + 0.65 * float(c.y) / h)
		var col := color
		if n < k * 0.08:
			continue  # hueco
		if n < k * 0.26:
			col = corrupt_color(n)
		cube(ci, origin + Vector2(c.x, c.y) * s, s, col)
		# chorrera: una celda de corrupción que cuelga de la parte de abajo de una letra
		if not lit.has(Vector2i(c.x, c.y + 1)) and noise(c.x, c.y, seed_value + 17) < k * 0.10:
			cube(ci, origin + Vector2(c.x, c.y + 1) * s, s, corrupt_color(n + 0.13))


## Carta (botón o panel): sombra dura, placa lisa y borde de cubitos (mármol o dorado) con corrupción en el borde de abajo y una
## franja de brillo que la cruza (`shine` en 0..1; -1 = sin brillo). `rect` es la carta; se dibuja con la transformación activa.
## `state`: 0 normal, 1 resaltado (hover/foco), 2 apretado, 3 desactivado.
static func card(ci: CanvasItem, rect: Rect2, s: float, state: int, corruption: float, seed_value: int, gold := false, shine := -1.0) -> void:
	var cols := maxi(int(rect.size.x / s), 3)
	var rows := maxi(int(rect.size.y / s), 3)
	var plate := PLATE_HOVER if state == 1 else PLATE
	if gold:
		plate = Color(0.50, 0.34, 0.09) if state != 1 else Color(0.66, 0.46, 0.13)
	if high_contrast:
		corruption = 0.0
		plate = plate.darkened(0.55)
	if state == 2:
		plate = plate.darkened(0.2)
	if state == 3:
		plate = plate.darkened(0.3)
	var rim := GOLD if gold else MARBLE
	if high_contrast:
		rim = rim.lightened(0.4)
	if state == 1:
		rim = rim.lightened(0.12)
	if state == 3:
		rim = rim.darkened(0.2 if high_contrast else 0.45)
	var origin := rect.position + Vector2((rect.size.x - cols * s) * 0.5, 0)
	var body := Rect2(origin, Vector2(cols * s, rows * s))
	ci.draw_rect(Rect2(body.position + Vector2(s * 0.8, s * 1.2), body.size), Color(0, 0, 0, 0.6))   # sombra dura
	ci.draw_rect(body, plate)
	for y in range(1, rows - 1):   # textura de la placa: unos pocos cubitos un poco más claros
		for x in range(1, cols - 1):
			var n := noise(x, y, seed_value + 5)
			if n < 0.025 and not high_contrast:
				cube(ci, origin + Vector2(x, y) * s, s, plate.lightened(0.10 + n), true)
	for y in rows:   # borde
		for x in cols:
			if x != 0 and y != 0 and x != cols - 1 and y != rows - 1:
				continue
			var n := noise(x, y, seed_value)
			var k := corruption * (0.30 + 0.70 * float(y) / float(rows))
			if n < k * 0.10:
				continue  # el borde se rompió
			var col := rim.darkened(noise(x, y, seed_value + 3) * 0.2)
			if n < k * 0.34:
				col = corrupt_color(n)
			cube(ci, origin + Vector2(x, y) * s, s, col)
	for x in range(1, cols - 1):   # chorreras que cuelgan del borde de abajo
		if noise(x, rows, seed_value + 9) < corruption * 0.14:
			var len := 1 + int(noise(x, rows, seed_value + 11) * 2.0)
			for i in len:
				cube(ci, origin + Vector2(x, rows + i) * s, s, corrupt_color(noise(x, i, seed_value + 13)))
	if shine >= 0.0 and state != 3:   # franja de brillo en diagonal
		var w := body.size.x
		var sx := body.position.x + shine * (w + 80.0) - 40.0
		var poly := PackedVector2Array([Vector2(sx, body.position.y), Vector2(sx + 22, body.position.y), Vector2(sx + 2, body.end.y), Vector2(sx - 20, body.end.y)])
		var clipped := Geometry2D.intersect_polygons(poly, PackedVector2Array([body.position, Vector2(body.end.x, body.position.y), body.end, Vector2(body.position.x, body.end.y)]))
		for p in clipped:
			ci.draw_colored_polygon(p, Color(1, 1, 1, 0.10))
