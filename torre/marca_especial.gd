extends RefCounted
## La marca de un bloque especial para quien no distingue bien los colores (Opciones > General > Daltonismo): un símbolo blanco de pixeles, con borde oscuro, flotando sobre el bloque y de cara a la cámara,
## igual que la cuenta de la bomba (`cuenta_bomba.gd`). Cada especial tiene su forma: hielo (copo), pesado (pesa), agrietado (rayo), trampa (equis), pinchos (púas) y catapulta (flecha hacia arriba).
## La bomba ya lleva su dibujo con el número.

const PIXEL := 0.05   # lado de un pixel del dibujo en el mundo

## La forma de cada marca (9 x 9): "#" es blanco. Se identifican por la letra de bloque del motor.
const FORMAS := {
	"i": ["....#....", ".#..#..#.", "..#.#.#..", "...###...", "#########", "...###...", "..#.#.#..", ".#..#..#.", "....#...."],
	"h": [".#######.", ".#######.", "..#####..", "...###...", "...###...", "..#####..", ".#######.", "#########", "#########"],
	"c": ["....##...", "...##....", "..##.....", ".#####...", "...##....", "..##.....", ".##......", "##.......", "#........"],
	"t": ["##.....##", "###...###", ".###.###.", "..#####..", "...###...", "..#####..", ".###.###.", "###...###", "##.....##"],
	"s": ["....#....", "...###...", "...###...", "..#####..", "..#####..", ".#######.", ".#######.", "#########", "#########"],
	"k": ["....#....", "...###...", "..#####..", ".#######.", "...###...", "...###...", "...###...", "...###...", "...###..."],
}

static var _cache := {}


## ¿Esta letra de bloque lleva marca?
static func tiene(letra: String) -> bool:
	return FORMAS.has(letra)


## El Sprite3D de la marca sobre la celda `c`.
static func crear(c: Vector3i, letra: String, sin_profundidad := false) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = textura(letra)
	s.pixel_size = PIXEL
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.double_sided = true
	s.no_depth_test = sin_profundidad
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.position = Vector3(c.x + 0.5, c.y + 1.3, c.z + 0.5)
	s.name = "marca_" + letra
	return s


static func textura(letra: String) -> ImageTexture:
	if not _cache.has(letra):
		_cache[letra] = ImageTexture.create_from_image(dibujo(letra))
	return _cache[letra]


## El dibujo: la forma en blanco con un borde negro de un pixel (11 x 11).
static func dibujo(letra: String) -> Image:
	var filas: Array = FORMAS[letra]
	var img := Image.create_empty(11, 11, false, Image.FORMAT_RGBA8)
	for y in 9:
		for x in 9:
			if String(filas[y])[x] == "#":
				for o in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1)]:
					var px: int = x + 1 + o.x
					var py: int = y + 1 + o.y
					if img.get_pixel(px, py).a == 0.0:
						img.set_pixel(px, py, Color(0.05, 0.03, 0.1, 1.0))
	for y in 9:
		for x in 9:
			if String(filas[y])[x] == "#":
				img.set_pixel(x + 1, y + 1, Color(1.0, 0.97, 0.88, 1.0))
	return img
