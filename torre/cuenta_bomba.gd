extends RefCounted
## La cuenta de una bomba: un dibujo de pixeles de una bomba (cuerpo redondo, mecha con chispa) con el número adentro, con la fuente del juego. Gris mientras la mecha está quieta y roja
## cuando corre (el jugador está dentro de su zona); la mecha es más corta cuanto menos queda. Lo pone `vista.gd` sobre el bloque y lo tapan los bloques de adelante, como a cualquier cosa del mundo.

const VFont := preload("res://scripts/ui/voxel_font.gd")

const ROJO := Color(1.0, 0.3, 0.22)
const ORO := Color(1.0, 0.85, 0.4)
const PIXEL := 0.045   # lado de un pixel del dibujo en el mundo

static var _cache := {}


## El Sprite3D de la cuenta, de cara a la cámara, sobre la celda `c`.
static func crear(c: Vector3i, mecha: int, activa: bool) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = textura(mecha, activa)
	s.pixel_size = PIXEL
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.double_sided = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.position = Vector3(c.x + 0.5, c.y + 1.3, c.z + 0.5)
	return s


static func textura(mecha: int, activa: bool) -> ImageTexture:
	var k := "%d_%s" % [mecha, activa]
	if not _cache.has(k):
		_cache[k] = ImageTexture.create_from_image(dibujo(mecha, activa))
	return _cache[k]


static func _punto(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


## El número (solo las filas del cuerpo de la fuente, 7), con su sombra dura de un pixel.
static func _texto(img: Image, texto: String, x0: int, y0: int, c: Color) -> void:
	for pasada in [1, 0]:
		var col := Color(0, 0, 0, 1) if pasada == 1 else c
		for i in texto.length():
			for cel in VFont.glyph_cells(texto[i]):
				_punto(img, x0 + i * VFont.ADVANCE + cel.x + pasada, y0 + cel.y - VFont.ACCENT_ROWS + pasada, col)


static func dibujo(mecha: int, activa: bool) -> Image:
	var t := str(mecha)
	var texto_ancho := t.length() * VFont.ADVANCE - 1
	var radio := 8 if t.length() > 1 else 7
	var ancho := radio * 2 + 8
	var alto := radio * 2 + 9
	var img := Image.create_empty(ancho, alto, false, Image.FORMAT_RGBA8)
	var cx := radio + 2
	var cy := alto - radio - 2
	var cuerpo := Color(0.42, 0.07, 0.07) if activa else Color(0.13, 0.13, 0.2)
	var borde := ROJO if activa else Color(0.55, 0.55, 0.7)
	for y in alto:
		for x in ancho:
			var d := Vector2(x - cx, y - cy).length()
			if d <= radio - 0.5:
				img.set_pixel(x, y, cuerpo)
			elif d <= radio + 0.5:
				img.set_pixel(x, y, borde)
	_punto(img, cx - radio + 3, cy - radio + 3, Color(0.8, 0.8, 0.85) if not activa else Color(1.0, 0.65, 0.6))   # el brillo
	_punto(img, cx - radio + 2, cy - radio + 4, Color(0.55, 0.55, 0.65) if not activa else Color(0.85, 0.35, 0.3))
	var largo := clampi(2 + mecha / 2, 2, 6)
	var bx := cx + radio - 4
	var by := cy - radio
	for i in largo:   # la mecha, en diagonal hacia arriba y a la derecha
		_punto(img, bx + i / 2, by - i, Color(0.62, 0.45, 0.25))
		_punto(img, bx + i / 2 + 1, by - i, Color(0.4, 0.28, 0.15))
	var sx := bx + largo / 2
	var sy := by - largo
	var chispa := Color(1.0, 0.55, 0.15) if activa else ORO
	for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1)]:
		_punto(img, sx + o.x, sy + o.y, chispa)
	_punto(img, sx, sy, Color(1, 1, 0.8))
	if activa:
		for o in [Vector2i(2, -1), Vector2i(-2, -1), Vector2i(0, -2)]:
			_punto(img, sx + o.x, sy + o.y, Color(1.0, 0.7, 0.2))
	_texto(img, t, cx - texto_ancho / 2, cy - 3, Color(1, 0.95, 0.85) if activa else Color(0.95, 0.95, 0.95))
	return img
