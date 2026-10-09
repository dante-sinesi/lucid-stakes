extends RefCounted
## Íconos de cubitos (9 x 9) de cada boost y consumible. Letras: o = contorno, a y b = colores del ícono, w = brillo.
## `draw` dibuja el ícono con una sombra dura, igual que el resto de la interfaz.

const Draw := preload("res://scripts/voxel_draw.gd")

const SIZE := 9
const OUTLINE := Color(0.09, 0.04, 0.15)
const SHINE := Color(1.0, 1.0, 0.95)

const ICONS := {
	# ---- boosts ----
	"segundo_aliento": {"a": Color(0.92, 0.28, 0.40), "rows": [
		".........", ".oo...oo.", "oaaoooaao", "oawaaaaao", "oaaaaaaao", ".oaaaaao.", "..oaaao..", "...oao...", "....o...."]},
	"madrugada": {"a": Color(1.0, 0.85, 0.30), "b": Color(0.95, 0.50, 0.20), "rows": [
		"....a....", ".a..a..a.", "..aaaaa..", ".aabbbaa.", ".abbbbba.", "ooooooooo", ".bbbbbbb.", "..bbbbb..", "........."]},
	"luz_propia": {"a": Color(1.0, 0.90, 0.35), "rows": [
		"....a....", "....a....", "...aaa...", "aaaawaaaa", ".aawwwaa.", "aaaawaaaa", "...aaa...", "....a....", "....a...."]},
	"mano_de_oro": {"a": Color(1.0, 0.80, 0.25), "rows": [
		".o.o.o...", "oaoaoaoo.", "oaaaaaaao", "oaaaaaaao", ".oaaaaaao", ".oaaaaao.", "..oaaaao.", "..ooooo..", "........."]},
	"pies_de_luz": {"a": Color(0.98, 0.88, 0.45), "rows": [
		"..oo.oo..", ".oaaoaao.", ".oaaoaao.", "..oooooo.", ".oaaaaao.", ".oaaaaao.", "..oaaao..", "..oaaao..", "...ooo..."]},
	"paso_firme": {"a": Color(0.93, 0.90, 0.83), "rows": [
		".........", ".....oooo", ".....oaao", "...oooaao", "...oaaaao", ".oooaaaao", ".oaaaaaao", ".oaaaaaao", ".ooooooo."]},
	"reflejos": {"a": Color(1.0, 0.92, 0.30), "rows": [
		"....ooo..", "...oaao..", "..oaao...", ".oaaaaao.", "..ooaao..", "....oao..", "...oao...", "..oao....", "..oo....."]},
	"racha_larga": {"a": Color(0.98, 0.50, 0.15), "b": Color(1.0, 0.88, 0.30), "rows": [
		"....o....", "...oao...", "..oaao...", ".oaabao..", ".oabbbao.", "oaabbbaao", "oaabbbaao", ".oaabaao.", "..ooooo.."]},
	"aire_extra": {"a": Color(0.85, 0.92, 1.0), "rows": [
		".........", "...ooo...", "..oaaao..", ".oaaaaaoo", "oaaaaaaao", "oaaaaaaao", ".ooooooo.", ".........", "........."]},
	"ojo_de_hielo": {"a": Color(0.45, 0.80, 1.0), "w": Color(0.95, 0.97, 1.0), "rows": [
		".........", "..ooooo..", ".owwwwwo.", "owwaaawwo", "owwaoawwo", "owwaaawwo", ".owwwwwo.", "..ooooo..", "........."]},
	"ahorro": {"a": Color(1.0, 0.82, 0.25), "b": Color(0.78, 0.55, 0.12), "rows": [
		".........", "..ooooo..", ".oaaaaao.", ".obbbbbo.", ".oaaaaao.", ".obbbbbo.", ".oaaaaao.", "..ooooo..", "........."]},
	"bolsillo_hondo": {"a": Color(0.62, 0.42, 0.22), "b": Color(1.0, 0.82, 0.25), "rows": [
		"...ooo...", "..oaaao..", "...ooo...", "..oaaao..", ".oaaaaao.", "oaabbbaao", "oaabbbaao", "oaaaaaaao", ".ooooooo."]},
	"mente_abierta": {"a": Color(0.55, 0.30, 0.80), "w": Color(1.0, 0.95, 0.80), "rows": [
		".ooooooo.", ".oaaaaao.", ".oaawaao.", ".oaawaao.", ".owwwwwo.", ".oaawaao.", ".oaawaao.", ".oaaaaao.", ".ooooooo."]},
	# ---- consumibles ----
	"freno": {"a": Color(0.95, 0.30, 0.30), "rows": [
		".........", ".ooo.ooo.", ".oao.oao.", ".oao.oao.", ".oao.oao.", ".oao.oao.", ".oao.oao.", ".ooo.ooo.", "........."]},
	# ---- conversores (un cubo con la marca de cada tipo) ----
	"conv_roca": {"a": Color(0.62, 0.58, 0.55), "b": Color(0.42, 0.40, 0.40), "rows": [
		"ooooooooo", "oaaaaaaao", "oaabaaaao", "oaaaaabao", "oabaaaaao", "oaaaabaao", "oaabaaaao", "oaaaaaaao", "ooooooooo"]},
	"conv_hielo": {"a": Color(0.50, 0.82, 1.0), "w": Color(0.96, 0.99, 1.0), "rows": [
		"ooooooooo", "oaaaaawwo", "oaaaawwao", "oaaawwaao", "oaawwaaao", "oawwaaaao", "owwaaaaao", "oaaaaaaao", "ooooooooo"]},
	"conv_agrietado": {"a": Color(0.66, 0.52, 0.36), "rows": [
		"ooooooooo", "oaaaoaaao", "oaaoaaaao", "oaaaoaaao", "oaaaaoooo", "oaaaaaaoo", "oaaaaoaao", "oaaaoaaao", "ooooooooo"]},
	"conv_trampa": {"a": Color(0.88, 0.72, 0.36), "b": Color(0.42, 0.30, 0.14), "rows": [
		"ooooooooo", "oabababao", "obabababo", "oabababao", "obabababo", "oabababao", "obabababo", "oabababao", "ooooooooo"]},
	"conv_pinchos": {"a": Color(0.74, 0.74, 0.80), "b": Color(0.45, 0.45, 0.52), "rows": [
		"....o.o..", "...oao.o.", "..oaaoaoo", ".oaaaoaao", "oaaaaaaao", "oabbabbao", "oaaaaaaao", "oabbabbao", "ooooooooo"]},
	"conv_pesado": {"a": Color(0.36, 0.36, 0.44), "w": Color(0.72, 0.72, 0.80), "rows": [
		"ooooooooo", "owaaaaawo", "oaaaaaaao", "oaaaaaaao", "oaaaaaaao", "oaaaaaaao", "oaaaaaaao", "owaaaaawo", "ooooooooo"]},
	"conv_bomba": {"a": Color(0.24, 0.24, 0.30), "b": Color(0.98, 0.35, 0.20), "rows": [
		"ooooooooo", "oaaaaaabo", "oaaaaabbo", "oaaooaaao", "oaoaaoaao", "oaoaaoaao", "oaaooaaao", "oaaaaaaao", "ooooooooo"]},
	"conv_catapulta": {"a": Color(0.45, 0.85, 0.40), "b": Color(0.95, 0.95, 0.80), "rows": [
		"ooooooooo", "oaaaabaao", "oaaabbbao", "oaabbbbbo", "oaaaabaao", "oaaaabaao", "oaaaabaao", "oaaaaaaao", "ooooooooo"]},
	# ---- otros consumibles ----
	"escudo": {"a": Color(0.55, 0.70, 0.92), "b": Color(1.0, 0.82, 0.25), "rows": [
		".ooooooo.", "oaaaaaaao", "oabbbbbao", "oabaaabao", "oabaaabao", ".oabbbao.", "..oabao..", "...oao...", "....o...."]},
	"doble_salto": {"a": Color(1.0, 0.90, 0.30), "b": Color(0.75, 0.55, 0.15), "rows": [
		"....o....", "...oao...", "..oaaao..", "....a....", "...oao...", "..oaaao..", "....a....", "..obbbo..", ".ooooooo."]},
	"totem": {"a": Color(0.62, 0.40, 0.20), "b": Color(1.0, 0.82, 0.25), "rows": [
		"..ooooo..", ".oaaaaao.", ".oabaabo.", ".oaaaaao.", "..ooooo..", ".oabbbao.", ".oaaaaao.", ".oabbbao.", "..ooooo.."]},
	"vida_extra": {"a": Color(0.92, 0.16, 0.27), "w": Color(1.0, 0.7, 0.75), "rows": [
		".oo...oo.", "oaaoooaao", "oawaaaaao", "oaaaaaaao", "oaaaaaaao", ".oaaaaao.", "..oaaao..", "...oao...", "....o...."]},
	"teletransporte": {"a": Color(0.68, 0.42, 1.0), "b": Color(0.97, 0.93, 1.0), "rows": [
		".ooooooo.", "oaaaaaaao", "oabbbbbao", "oabaaabao", "oabaaabao", "oabaaabao", "oabbbbbao", "oaaaaaaao", ".ooooooo."]},
	"desarmar": {"a": Color(0.35, 0.33, 0.40), "b": Color(0.95, 0.30, 0.20), "w": Color(0.80, 0.80, 0.90), "rows": [
		".....bb..", "....b....", "..ooooo..", ".oaaaaao.", "oaawaaaao", "oaaaaaaao", "oaaaaaaao", ".oaaaaao.", "..ooooo.."]},
	"ancla_chica": {"a": Color(0.55, 0.70, 0.85), "b": Color(1.0, 0.82, 0.25), "rows": [
		"....o....", "...oao...", "....o....", ".ooooooo.", "....a....", "o...a...o", "oa..a..ao", ".oaaaaao.", "..ooooo.."]},
}


static func has_icon(id: String) -> bool:
	return ICONS.has(id)


## Dibuja el ícono de `id` con su esquina arriba a la izquierda en `pos` y cubitos de lado `s`.
static func draw(ci: CanvasItem, id: String, pos: Vector2, s: float, dim := 1.0) -> void:
	if not ICONS.has(id):
		return
	var icon: Dictionary = ICONS[id]
	var rows: Array = icon.rows
	var pal := {"o": OUTLINE, "a": icon.get("a", Color.WHITE), "b": icon.get("b", icon.get("a", Color.WHITE)), "w": icon.get("w", SHINE)}
	var off := Vector2(maxf(1.0, s * 0.45), maxf(1.0, s * 0.65))
	for y in rows.size():   # sombra dura
		var line: String = rows[y]
		for x in line.length():
			if line[x] != ".":
				ci.draw_rect(Rect2(pos + Vector2(x, y) * s + off, Vector2(s, s)), Color(0, 0, 0, 0.5 * dim))
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			if line[x] != ".":
				var col: Color = pal[line[x]]
				Draw.cube(ci, pos + Vector2(x, y) * s, s, col.darkened(1.0 - dim) if dim < 1.0 else col, true)
