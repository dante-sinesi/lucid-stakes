extends RefCounted
## El arte de los contratos (docs/plan_casinos.md): el papel de la cartelera, el sello de rareza (gris, azul, violeta y negro), el sello "COBRADO" y los íconos de
## cada tipo de objetivo. Todo de cubitos, como el resto de la interfaz. Se dibuja sobre cualquier control con la esquina de arriba a la izquierda en `pos` y cubitos de lado `s`.

const Draw := preload("res://scripts/ui/voxel_draw.gd")
const VFont := preload("res://scripts/ui/voxel_font.gd")

enum Rareza { COMUN, RARA, EPICA, IMPOSIBLE }

const OUTLINE := Color(0.09, 0.04, 0.15)

# ---- el papel -------------------------------------------------------------------------------------------------------------------------
const PAPEL_COLS := 17
const PAPEL_ROWS := 22
const PAPEL := Color(0.93, 0.87, 0.72)
const PAPEL_SOMBRA := Color(0.78, 0.70, 0.54)
const TINTA := Color(0.30, 0.22, 0.16)

# ---- el sello de rareza (7 x 7): o = contorno, a = cera, b = brillo, m = marca ----------------------------------------------------------
const SELLO_FORMA := [
	"..ooo..",
	".oaaao.",
	"oabaaao",
	"oaaaaao",
	"oaaaaao",
	".oaaao.",
	"..ooo..",
]
# La marca en relieve (cabe en el interior de 5 x 5; las coordenadas son de la grilla de 7 x 7).
const SELLO_MARCA := {
	Rareza.COMUN: [Vector2i(3, 3)],
	Rareza.RARA: [Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4)],
	Rareza.EPICA: [Vector2i(2, 2), Vector2i(4, 2), Vector2i(3, 3), Vector2i(2, 4), Vector2i(4, 4)],
	Rareza.IMPOSIBLE: [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(3, 3), Vector2i(1, 4), Vector2i(2, 4), Vector2i(4, 4), Vector2i(5, 4)],
}
const SELLO_COLORES := {
	Rareza.COMUN: {"a": Color(0.60, 0.61, 0.68), "b": Color(0.85, 0.86, 0.93), "m": Color(0.36, 0.37, 0.44), "o": Color(0.20, 0.20, 0.27)},
	Rareza.RARA: {"a": Color(0.22, 0.48, 0.95), "b": Color(0.60, 0.78, 1.0), "m": Color(0.88, 0.95, 1.0), "o": Color(0.08, 0.18, 0.50)},
	Rareza.EPICA: {"a": Color(0.60, 0.26, 0.92), "b": Color(0.83, 0.64, 1.0), "m": Color(1.0, 0.92, 1.0), "o": Color(0.27, 0.08, 0.50)},
	Rareza.IMPOSIBLE: {"a": Color(0.09, 0.08, 0.12), "b": Color(0.33, 0.30, 0.40), "m": Color(1.0, 0.82, 0.30), "o": Color(0.62, 0.50, 0.16)},
}

# ---- íconos de los objetivos (9 x 9): o = contorno, a y b = colores del ícono, w = brillo ---------------------------------------------------
const OBJETIVOS := {
	"movimientos": {"a": Color(0.92, 0.92, 1.0), "b": Color(0.25, 0.20, 0.45), "rows": [
		"..ooooo..", ".oaaaaao.", "oaaabaaao", "oaaabaaao", "oaaabbbao", "oaaaaaaao", "oaaaaaaao", ".oaaaaao.", "..ooooo.."]},
	"deshacer": {"a": Color(0.75, 0.85, 1.0), "b": Color(0.95, 0.25, 0.25), "rows": [
		"...o.....", "..oao....", ".oaaaoooo", "oaaaaaaao", ".oaaaoooo", "..oao.b.b", "...o...b.", "......b.b", "........."]},
	"racha": {"a": Color(1.0, 0.50, 0.15), "b": Color(1.0, 0.88, 0.30), "rows": [
		"....o....", "...oao...", "..oaao...", ".oaabao..", ".oabbbao.", "oaabbbaao", "oaabbbaao", ".oaabaao.", "..ooooo.."]},
	"bomba": {"a": Color(0.30, 0.28, 0.36), "b": Color(0.95, 0.30, 0.20), "w": Color(0.78, 0.78, 0.90), "rows": [
		".....bb..", "....b....", "..ooooo..", ".oaaaaao.", "oaawaaaao", "oaaaaaaao", "oaaaaaaao", ".oaaaaao.", "..ooooo.."]},
	"especiales": {"a": Color(0.62, 0.42, 0.95), "b": Color(0.85, 0.75, 1.0), "rows": [
		"....o....", "...oao...", "..oabao..", "ooaabbaoo", "oaabbbbao", ".oaabbao.", "..oaaaao.", ".oaao.oao", ".oo.....o"]},
	"sin_empujar": {"a": Color(0.78, 0.74, 0.86), "b": Color(0.95, 0.25, 0.25), "rows": [
		"..bbbbb..", ".bb...bb.", "bbb....bb", "b..baa..b", "b..aba..b", "b..aab..b", "bb....bbb", ".bb...bb.", "..bbbbb.."]},
	"vidas": {"a": Color(0.92, 0.16, 0.27), "b": Color(1.0, 0.70, 0.75), "rows": [
		".oo...oo.", "oaaoooaao", "oabaaaaao", "oaaaaaaao", "oaaaaaaao", ".oaaaaao.", "..oaaao..", "...oao...", "....o...."]},
	"catapulta": {"a": Color(0.75, 0.78, 0.86), "b": Color(1.0, 0.60, 0.15), "rows": [
		"....bb...", "...bbbb..", "....bb...", ".oaaaaao.", "..ooooo..", ".oaaaaao.", "..ooooo..", ".oaaaaao.", "ooooooooo"]},
	"escalada": {"a": Color(0.93, 0.90, 0.83), "b": Color(0.95, 0.25, 0.25), "rows": [
		".......oo", "......oao", "....ooaao", "....oaaao", "..ooaaaao", "..oaaaaao", "ooaaaaaao", "oaaaaaaao", "ooooooooo"]},
	"claridad": {"a": Color(1.0, 0.85, 0.30), "b": Color(1.0, 0.97, 0.70), "rows": [
		"....o....", "....a....", "..o.a.o..", "...oao...", "aaaabaaaa", "...oao...", "..o.a.o..", "....a....", "....o...."]},
}


## Un dibujo de letras (las filas de arriba) con su paleta; `dim` lo oscurece.
static func _dibujar_filas(ci: CanvasItem, rows: Array, pal: Dictionary, pos: Vector2, s: float, sombra := true) -> void:
	var off := Vector2(maxf(1.0, s * 0.45), maxf(1.0, s * 0.65))
	if sombra:
		for y in rows.size():
			var line: String = rows[y]
			for x in line.length():
				if line[x] != ".":
					ci.draw_rect(Rect2(pos + Vector2(x, y) * s + off, Vector2(s, s)), Color(0, 0, 0, 0.5))
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			if line[x] != ".":
				Draw.cube(ci, pos + Vector2(x, y) * s, s, pal[line[x]], true)


static func tiene_objetivo(id: String) -> bool:
	return OBJETIVOS.has(id)


## El ícono de un tipo de objetivo.
static func dibujar_objetivo(ci: CanvasItem, id: String, pos: Vector2, s: float) -> void:
	if not OBJETIVOS.has(id):
		return
	var ic: Dictionary = OBJETIVOS[id]
	_dibujar_filas(ci, ic.rows, {"o": OUTLINE, "a": ic.get("a", Color.WHITE), "b": ic.get("b", ic.get("a", Color.WHITE)), "w": ic.get("w", Color(1.0, 1.0, 0.95))}, pos, s)


## El sello de cera de una rareza (7 x 7 cubitos).
static func dibujar_sello(ci: CanvasItem, rareza: int, pos: Vector2, s: float) -> void:
	var c: Dictionary = SELLO_COLORES[rareza]
	var pal := {"o": c.o, "a": c.a, "b": c.b, "m": c.m}
	_dibujar_filas(ci, SELLO_FORMA, pal, pos, s)
	for p: Vector2i in SELLO_MARCA[rareza]:   # la marca, en relieve, encima de la cera
		Draw.cube(ci, pos + Vector2(p) * s, s, c.m, true)


## El papel de la cartelera con su ícono de objetivo y su sello. `colgado`: con la chinche arriba; si no (activo), sin ella. `ancho`/`alto` en cubitos.
## Los textos los dibuja quien lo usa (`texto_cells`).
static func dibujar_papel(ci: CanvasItem, pos: Vector2, s: float, rareza: int, objetivo: String, semilla := 0, colgado := true) -> void:
	var cols := PAPEL_COLS
	var rows := PAPEL_ROWS
	ci.draw_rect(Rect2(pos + Vector2(s * 0.8, s * 1.2), Vector2(cols, rows) * s), Color(0, 0, 0, 0.55))   # sombra dura
	for y in rows:
		for x in cols:
			var n := Draw.noise(x, y, semilla + 3)
			if (x == 0 or x == cols - 1) and n < 0.35:
				continue   # borde roto
			if y == rows - 1 and n < 0.30:
				continue
			if x >= cols - 3 and y < 3 and (x - (cols - 3)) > y:
				continue   # la esquina doblada
			var col := PAPEL
			if x >= cols - 3 and y < 3:
				col = PAPEL_SOMBRA
			elif x == cols - 1 or y == rows - 1:
				col = PAPEL_SOMBRA
			elif n < 0.08:
				col = PAPEL.darkened(0.06)
			Draw.cube(ci, pos + Vector2(x, y) * s, s, col, true)
	if colgado:   # la chinche
		Draw.cube(ci, pos + Vector2(cols / 2 - 1, 1) * s, s, Color(0.85, 0.20, 0.20), true)
		Draw.cube(ci, pos + Vector2(cols / 2, 1) * s, s, Color(1.0, 0.55, 0.45), true)
		Draw.cube(ci, pos + Vector2(cols / 2 - 1, 2) * s, s, Color(0.55, 0.10, 0.12), true)
		Draw.cube(ci, pos + Vector2(cols / 2, 2) * s, s, Color(0.65, 0.12, 0.14), true)
	# el recuadro del ícono (lo pinta el objetivo) y las líneas de texto de relleno
	for x in range(3, 14):
		Draw.cube(ci, pos + Vector2(x, 4) * s, s, TINTA.lightened(0.25), true)
		Draw.cube(ci, pos + Vector2(x, 14) * s, s, TINTA.lightened(0.25), true)
	for y in range(4, 15):
		Draw.cube(ci, pos + Vector2(3, y) * s, s, TINTA.lightened(0.25), true)
		Draw.cube(ci, pos + Vector2(13, y) * s, s, TINTA.lightened(0.25), true)
	dibujar_objetivo(ci, objetivo, pos + Vector2(4, 5) * s, s)
	for i in 3:   # renglones de texto de relleno (escrito a mano: no dicen nada)
		var largo := 5 + int(Draw.noise(i, 7, semilla) * 5.0)
		for x in largo:
			ci.draw_rect(Rect2(pos + Vector2(3 + x, 16 + i * 2) * s + Vector2(0, s * 0.25), Vector2(s, s * 0.5)), TINTA.lightened(0.15))
	dibujar_sello(ci, rareza, pos + Vector2(cols - 8, rows - 8) * s, s)


## Un sello de tinta con una palabra ("CUMPLIDO", "FALLIDO"): la palabra dentro de un marco doble, inclinada, con la tinta fallando un poco como un sello de goma. `centro` es el centro del
## sello; `s` el lado del cubito; `fuerza` (0..1) lo hace más pálido (para animarlo al apoyarse).
static func dibujar_sello_texto(ci: CanvasItem, centro: Vector2, s: float, texto: String, tinta: Color, fuerza := 1.0, grados := -9.0) -> void:
	var lay: Dictionary = VFont.layout([texto])
	var celdas: Array = lay.cells
	var ancho: int = lay.size.x
	var alto: int = lay.size.y
	var col := Color(tinta.r, tinta.g, tinta.b, fuerza)
	ci.draw_set_transform(centro, deg_to_rad(grados), Vector2.ONE)
	var o := -Vector2(ancho + 6, alto + 6) * s * 0.5
	for x in range(ancho + 6):   # el marco doble
		for y in [0, 1, alto + 4, alto + 5]:
			ci.draw_rect(Rect2(o + Vector2(x, y) * s, Vector2(s, s)), col)
	for y in range(alto + 6):
		for x in [0, 1, ancho + 4, ancho + 5]:
			ci.draw_rect(Rect2(o + Vector2(x, y) * s, Vector2(s, s)), col)
	for c: Vector2i in celdas:
		if Draw.noise(c.x, c.y, 41) > 0.03:
			ci.draw_rect(Rect2(o + Vector2(c.x + 3, c.y + 3) * s, Vector2(s, s)), col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## El sello de mano, de minibloques (16 x 15): el pomo de madera, el cuello, la brida de metal y la base con la tinta abajo. La esquina de arriba a la izquierda va en `pos`; el punto que
## toca el papel es el medio del borde de abajo (`SELLO_MANO_CONTACTO`, en cubitos).
const SELLO_MANO_COLS := 16
const SELLO_MANO_ROWS := 15
const SELLO_MANO_CONTACTO := Vector2(8.0, 15.0)
static func dibujar_sello_mano(ci: CanvasItem, pos: Vector2, s: float, tinta: Color) -> void:
	var madera := Color(0.50, 0.30, 0.16)
	var metal := Color(0.66, 0.68, 0.76)
	var cuerpo: Array = []   # [x0, y0, x1, y1, color] (x1 e y1 no incluidos)
	cuerpo.append([4, 0, 12, 5, madera])
	cuerpo.append([5, 0, 7, 4, madera.lightened(0.18)])   # el brillo del pomo
	cuerpo.append([6, 5, 10, 9, madera.darkened(0.12)])
	cuerpo.append([2, 9, 14, 11, metal.lightened(0.1)])
	cuerpo.append([0, 11, 16, 14, metal])
	cuerpo.append([0, 14, 16, 15, tinta])
	var off := Vector2(maxf(1.0, s * 0.45), maxf(1.0, s * 0.65))
	for r in cuerpo:   # sombra dura
		ci.draw_rect(Rect2(pos + Vector2(r[0], r[1]) * s + off, Vector2(r[2] - r[0], r[3] - r[1]) * s), Color(0, 0, 0, 0.45))
	for r in cuerpo:
		for y in range(r[1], r[3]):
			for x in range(r[0], r[2]):
				Draw.cube(ci, pos + Vector2(x, y) * s, s, r[4], true)
