extends RefCounted
## Íconos de cubitos (9 x 9) de cada boost y consumible. Letras: o = contorno, a y b = colores del ícono, w = brillo.
## `draw` dibuja el ícono con una sombra dura, igual que el resto de la interfaz.

const Draw := preload("res://scripts/ui/voxel_draw.gd")

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
	"ahorro": {"a": Color(1.0, 0.82, 0.25), "b": Color(0.78, 0.55, 0.12), "rows": [
		".........", "..ooooo..", ".oaaaaao.", ".obbbbbo.", ".oaaaaao.", ".obbbbbo.", ".oaaaaao.", "..ooooo..", "........."]},
	"bolsillo_hondo": {"a": Color(0.62, 0.42, 0.22), "b": Color(1.0, 0.82, 0.25), "rows": [
		"...ooo...", "..oaaao..", "...ooo...", "..oaaao..", ".oaaaaao.", "oaabbbaao", "oaabbbaao", "oaaaaaaao", ".ooooooo."]},
	"mente_abierta": {"a": Color(0.55, 0.30, 0.80), "w": Color(1.0, 0.95, 0.80), "rows": [
		".ooooooo.", ".oaaaaao.", ".oaawaao.", ".oaawaao.", ".owwwwwo.", ".oaawaao.", ".oaawaao.", ".oaaaaao.", ".ooooooo."]},
	# ---- consumibles ----
	"freno": {"a": Color(0.95, 0.30, 0.30), "rows": [
		".........", ".ooo.ooo.", ".oao.oao.", ".oao.oao.", ".oao.oao.", ".oao.oao.", ".oao.oao.", ".ooo.ooo.", "........."]},
	# ---- otros consumibles ----
	"totem": {"a": Color(0.62, 0.40, 0.20), "b": Color(1.0, 0.82, 0.25), "rows": [
		"..ooooo..", ".oaaaaao.", ".oabaabo.", ".oaaaaao.", "..ooooo..", ".oabbbao.", ".oaaaaao.", ".oabbbao.", "..ooooo.."]},
	"vida_extra": {"a": Color(0.92, 0.16, 0.27), "w": Color(1.0, 0.7, 0.75), "rows": [
		".oo...oo.", "oaaoooaao", "oawaaaaao", "oaaaaaaao", "oaaaaaaao", ".oaaaaao.", "..oaaao..", "...oao...", "....o...."]},
	"desarmar": {"a": Color(0.35, 0.33, 0.40), "b": Color(0.95, 0.30, 0.20), "w": Color(0.80, 0.80, 0.90), "rows": [
		".....bb..", "....b....", "..ooooo..", ".oaaaaao.", "oaawaaaao", "oaaaaaaao", "oaaaaaaao", ".oaaaaao.", "..ooooo.."]},
	# ---- los que disparan la ganancia (docs/diseno.md §47) ----
	"cosecha_doble": {"a": Color(1.00, 0.82, 0.25), "b": Color(0.85, 0.50, 0.10), "rows": [
		"..ooooo..", ".oaaaaao.", "oaabbbaao", "oaabaaaao", "oaabbaaao", "oaaaabaao", "oaabbbaao", ".oaaaaao.", "..ooooo.."]},
	"cosecha": {"a": Color(0.55, 0.85, 0.35), "b": Color(0.25, 0.50, 0.15), "rows": [
		"..ooooo..", ".oaaaaao.", "oaabbbaao", "oaabaaaao", "oaabbaaao", "oaaaabaao", "oaabbbaao", ".oaaaaao.", "..ooooo.."]},
	"racha_imparable": {"a": Color(1.00, 0.35, 0.20), "b": Color(1.00, 0.85, 0.30), "rows": [
		"....o....", "...oao...", "..oaao...", ".oaabao..", ".oabbbao.", "oaabbbaao", "oaabbbaao", ".oaabaao.", "..ooooo.."]},
	"midas": {"a": Color(1.00, 0.85, 0.20), "rows": [
		".o.o.o...", "oaoaoaoo.", "oaaaaaaao", "oaaaaaaao", ".oaaaaaao", ".oaaaaao.", "..oaaaao.", "..ooooo..", "........."]},
	"pies_de_oro": {"a": Color(1.00, 0.80, 0.20), "rows": [
		"..oo.oo..", ".oaaoaao.", ".oaaoaao.", "..oooooo.", ".oaaaaao.", ".oaaaaao.", "..oaaao..", "..oaaao..", "...ooo..."]},
	"buen_ojo": {"a": Color(0.75, 0.40, 0.95), "rows": [
		".........", "..ooooo..", ".owwwwwo.", "owwaaawwo", "owwaoawwo", "owwaaawwo", ".owwwwwo.", "..ooooo..", "........."]},
	"escalador": {"a": Color(0.95, 0.90, 0.70), "rows": [
		"........o", ".......oo", "......oao", ".....oaao", "....oaaao", "...oaaaao", "..oaaaaao", ".oaaaaaao", "ooooooooo"]},
	"empuje_rentable": {"a": Color(0.40, 0.80, 0.45), "rows": [
		"....o....", "...oao...", "..oaaao..", ".oaaaaao.", "ooo.a.ooo", "..oaaao..", "..oaaao..", "..oaaao..", "...ooo..."]},
	"interes": {"a": Color(0.50, 0.75, 1.00), "b": Color(0.20, 0.40, 0.80), "rows": [
		"..ooooo..", ".oaaaaao.", "oaabbbaao", "oaabaaaao", "oaabbaaao", "oaaaabaao", "oaabbbaao", ".oaaaaao.", "..ooooo.."]},
	"descuento_duende": {"a": Color(0.62, 0.16, 0.12), "b": Color(0.95, 0.90, 0.40), "rows": [
		"....o....", "...oao...", "..oaaao..", "..oaaao..", ".oaaaaao.", ".oaabbao.", "ooooooooo", "oaaaaaaao", ".ooooooo."]},
	"lluvia_de_luz": {"a": Color(1.00, 0.92, 0.50), "rows": [
		".ooooooo.", "oaaaaaaao", ".ooooooo.", "..a.a.a..", ".a.a.a.a.", "..a.a.a..", ".a.a.a.a.", "..a.a.a..", ".a.a.a.a."]},
	"soborno": {"a": Color(0.35, 0.60, 0.30), "b": Color(1.00, 0.85, 0.30), "rows": [
		"....o....", "...ooo...", "..oaaao..", ".oaaaaao.", "oaabbbaao", "oaabbbaao", "oaaaaaaao", ".oaaaaao.", "..ooooo.."]},
	"bolsillo_de_luz": {"a": Color(0.95, 0.85, 0.50), "b": Color(0.80, 0.60, 0.20), "rows": [
		"....o....", "...ooo...", "..oaaao..", ".oaaaaao.", "oaabbbaao", "oaabbbaao", "oaaaaaaao", ".oaaaaao.", "..ooooo.."]},
	"pocion_de_cosecha": {"a": Color(0.85, 0.90, 0.95), "b": Color(1.00, 0.80, 0.20), "rows": [
		"...ooo...", "....o....", "...oao...", "..oaaao..", ".oabbbao.", "oabbbbbao", "oabbbbbao", ".oaaaaao.", "..ooooo.."]},
	"iman_de_luz": {"a": Color(0.90, 0.25, 0.25), "rows": [
		"oo.....oo", "oaoo.ooao", "oao...oao", "oao...oao", "oao...oao", "oaaoooaao", ".oaaaaao.", "..oaaao..", "...ooo..."]},
	"baraja_de_racha": {"a": Color(0.95, 0.95, 0.90), "b": Color(0.90, 0.30, 0.30), "rows": [
		"..ooooo..", ".oaaaaao.", ".oabbbao.", ".oabaaao.", ".oabbbao.", ".oaaaabo.", ".oabbbao.", ".oaaaaao.", "..ooooo.."]},
	"reloj_de_arena": {"a": Color(0.95, 0.85, 0.50), "b": Color(0.90, 0.70, 0.25), "rows": [
		"ooooooooo", "oaaaaaaao", ".oaabaao.", "..oaabo..", "...oao...", "..oabao..", ".oabbbao.", "oaaaaaaao", "ooooooooo"]},
	"bolsa_de_luz": {"a": Color(0.95, 0.90, 0.60), "b": Color(0.85, 0.70, 0.30), "rows": [
		"....o....", "...ooo...", "..oaaao..", ".oaaaaao.", "oaabbbaao", "oaabbbaao", "oaaaaaaao", ".oaaaaao.", "..ooooo.."]},
	"bolsa_pesada": {"a": Color(0.62, 0.42, 0.22), "b": Color(1.00, 0.82, 0.25), "rows": [
		"....o....", "...ooo...", "..oaaao..", ".oaaaaao.", "oaabbbaao", "oaabbbaao", "oaaaaaaao", ".oaaaaao.", "..ooooo.."]},
	"saquito_de_oro": {"a": Color(1.00, 0.80, 0.20), "b": Color(0.80, 0.50, 0.10), "rows": [
		"....o....", "...ooo...", "..oaaao..", ".oaaaaao.", "oaabbbaao", "oaabbbaao", "oaaaaaaao", ".oaaaaao.", "..ooooo.."]},
	"cofre_de_luz": {"a": Color(0.55, 0.38, 0.20), "b": Color(1.00, 0.85, 0.30), "rows": [
		".ooooooo.", "oaaaaaaao", "oaaaaaaao", "ooooooooo", "oaabbbaao", "oaabbbaao", "oaaaaaaao", "oaaaaaaao", "ooooooooo"]},
	"tesoro": {"a": Color(0.60, 0.35, 0.90), "b": Color(1.00, 0.95, 0.50), "rows": [
		".ooooooo.", "oaaaaaaao", "oaaaaaaao", "ooooooooo", "oaabbbaao", "oaabbbaao", "oaaaaaaao", "oaaaaaaao", "ooooooooo"]},
	# ---- del casino (docs/diseno.md §49) ----
	"mano_23": {"a": Color(1.00, 0.85, 0.30), "b": Color(0.90, 0.30, 0.30), "rows": [
		"..ooooo..", ".oaaaaao.", ".oabbbao.", ".oabaaao.", ".oabbbao.", ".oaaaabo.", ".oabbbao.", ".oaaaaao.", "..ooooo.."]},
	"mesa_caliente": {"a": Color(1.00, 0.45, 0.15), "b": Color(1.00, 0.90, 0.35), "rows": [
		"....o....", "...oao...", "..oaao...", ".oaabao..", ".oabbbao.", "oaabbbaao", "oaabbbaao", ".oaabaao.", "..ooooo.."]},
	"blackjack_de_oro": {"a": Color(0.15, 0.15, 0.20), "b": Color(1.00, 0.82, 0.25), "rows": [
		"..ooooo..", ".oaaaaao.", ".oabbbao.", ".oabaaao.", ".oabbbao.", ".oaaaabo.", ".oabbbao.", ".oaaaaao.", "..ooooo.."]},
	"ficha_barata": {"a": Color(0.45, 0.85, 0.50), "b": Color(0.20, 0.50, 0.25), "rows": [
		"..ooooo..", ".oaaaaao.", "oaabbbaao", "oaabaaaao", "oaabbaaao", "oaaaabaao", "oaabbbaao", ".oaaaaao.", "..ooooo.."]},
	"casilla_de_regalo": {"a": Color(0.70, 0.95, 0.75), "rows": [
		"....o....", "...oao...", "...oao...", "ooooaoooo", "oaaaaaaao", ".oaaaaao.", ".oaaoaao.", "oaao.oaao", "oo.....oo"]},
	"red_de_seguridad": {"a": Color(0.50, 0.70, 1.00), "b": Color(0.20, 0.40, 0.80), "rows": [
		"....o....", "...ooo...", "..oaaao..", ".oaaaaao.", "oaabbbaao", "oaabbbaao", "oaaaaaaao", ".oaaaaao.", "..ooooo.."]},
	"giro_de_cortesia": {"a": Color(0.75, 0.55, 1.00), "b": Color(0.45, 0.30, 0.80), "rows": [
		"ooooooooo", "oaaaaaaao", ".oaabaao.", "..oaabo..", "...oao...", "..oabao..", ".oabbbao.", "oaaaaaaao", "ooooooooo"]},
	"llave_de_la_vitrina": {"a": Color(0.60, 0.60, 0.70), "b": Color(1.00, 0.85, 0.30), "rows": [
		".ooooooo.", "oaaaaaaao", "oaaaaaaao", "ooooooooo", "oaabbbaao", "oaabbbaao", "oaaaaaaao", "oaaaaaaao", "ooooooooo"]},
	"doble_o_nada": {"a": Color(1.00, 0.85, 0.30), "b": Color(0.90, 0.20, 0.20), "rows": [
		"..ooooo..", ".oaaaaao.", "oaabbbaao", "oaabaaaao", "oaabbaaao", "oaaaabaao", "oaabbbaao", ".oaaaaao.", "..ooooo.."]},
	"ficha_gratis": {"a": Color(0.95, 0.95, 1.00), "b": Color(0.60, 0.60, 0.90), "rows": [
		"..ooooo..", ".oaaaaao.", "oaabbbaao", "oaabaaaao", "oaabbaaao", "oaaaabaao", "oaabbbaao", ".oaaaaao.", "..ooooo.."]},
	"rayos_x": {"a": Color(0.40, 0.95, 0.95), "rows": [
		".........", "..ooooo..", ".owwwwwo.", "owwaaawwo", "owwaoawwo", "owwaaawwo", ".owwwwwo.", "..ooooo..", "........."]},
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
