extends RefCounted
## Un rótulo en el mundo 3D con la fuente de cubitos del juego (la de las cuentas de las bombas), nunca con la tipografía por omisión de Godot: un Sprite3D de cara a la cámara con el texto dibujado pixel a pixel
## y su sombra dura. Con `cartel`, el texto va sobre una placa oscura con borde (los "CERRADO" del casino torcido); sin él, son sólo las letras (los rótulos de la galería de bloques).
## `pixel` es el lado de un pixel del dibujo en el mundo.

const VFont := preload("res://scripts/ui/voxel_font.gd")

const PIXEL := 0.03
const ROJO := Color(1.0, 0.3, 0.22)

static var _cache := {}


## El Sprite3D del rótulo `texto`, de color `color` (con `cartel`, el borde es de ese color y el texto crema).
static func crear(texto: String, color: Color, cartel := false, pixel := PIXEL) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = textura(texto, color, cartel)
	s.pixel_size = pixel
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.double_sided = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	return s


static func textura(texto: String, color: Color, cartel: bool) -> ImageTexture:
	var k := "%s|%s|%s" % [texto, color.to_html(), cartel]
	if not _cache.has(k):
		_cache[k] = ImageTexture.create_from_image(dibujo(texto, color, cartel))
	return _cache[k]


static func _punto(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


## La imagen del rótulo. Con acentos o colas (letras como é, ñ o g) se dibujan todas las filas de la fuente; si no, sólo las 7 del cuerpo, como en las bombas.
static func dibujo(texto: String, color: Color, cartel: bool) -> Image:
	var completo := false
	for i in texto.length():
		if texto.unicode_at(i) > 127 or "gjpqy,;".contains(texto[i]):
			completo = true
	var fila0 := 0 if completo else VFont.ACCENT_ROWS
	var filas := VFont.H if completo else VFont.BODY_ROWS
	var ancho_texto := texto.length() * VFont.ADVANCE - 1
	var margen := 4 if cartel else 1
	var ancho := ancho_texto + margen * 2 + 1
	var alto := filas + margen * 2 + 1
	var img := Image.create_empty(ancho, alto, false, Image.FORMAT_RGBA8)
	if cartel:
		img.fill_rect(Rect2i(0, 0, ancho - 1, alto - 1), Color(0.14, 0.04, 0.05))
		for x in ancho - 1:
			_punto(img, x, 0, color)
			_punto(img, x, alto - 2, color)
		for y in alto - 1:
			_punto(img, 0, y, color)
			_punto(img, ancho - 2, y, color)
		for x in ancho:   # (la sombra dura de la placa)
			_punto(img, x, alto - 1, Color(0, 0, 0, 1))
		for y in alto:
			_punto(img, ancho - 1, y, Color(0, 0, 0, 1))
	var tinta := Color(1.0, 0.95, 0.85) if cartel else color
	for pasada in [1, 0]:
		var col := Color(0, 0, 0, 1) if pasada == 1 else tinta
		for i in texto.length():
			for cel in VFont.glyph_cells(texto[i]):
				_punto(img, margen + i * VFont.ADVANCE + cel.x + pasada, margen + cel.y - fila0 + pasada, col)
	return img
