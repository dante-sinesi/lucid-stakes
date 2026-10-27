extends RefCounted
## Ilustración de cada escenario hecha de cubitos (una grilla de 9 x 9 con una letra por color; el punto es vacío).

const ART := {
	"tutorial": {   # la cara del tabernero con su sombrero de copa
		"pal": {"k": Color(0.07, 0.07, 0.09), "r": Color(0.72, 0.1, 0.16), "s": Color(0.86, 0.68, 0.55), "e": Color(0.12, 0.1, 0.1), "m": Color(0.82, 0.82, 0.8)},
		"rows": ["..kkkkk..", "..kkkkk..", "..rrrrr..", "kkkkkkkkk", "..sssss..", ".sessess.", ".sssssss.", ".smmmmms.", "..sssss.."]},
	"pesadilla": {
		"pal": {"a": Color(0.40, 0.17, 0.62), "d": Color(0.80, 0.55, 1.0), "c": Color(0.12, 0.04, 0.2), "b": Color(0.28, 0.1, 0.45)},
		"rows": ["aaaaaaaaa", "adddddddb", "ad.aaaabb", "adacccabb", "adacc.abb", "adaaaaabb", "ad.aaaabb", "abbbbbbbb", ".b.b.b.b."]},
	"sin_piedad": {   # el camino corto: un recorrido recto que sube hasta la meta dorada
		"pal": {"s": Color(0.55, 0.45, 0.7), "p": Color(0.9, 0.85, 1.0), "g": Color(1.0, 0.85, 0.3)},
		"rows": [".......gg", ".......gg", "......pp.", ".....pp..", "....pp...", "...pp....", "..pp.....", ".ppssssss", "pp......."]},
	"compromiso": {   # un solo corazón, entero
		"pal": {"r": Color(0.92, 0.16, 0.27), "h": Color(1.0, 0.62, 0.68), "d": Color(0.62, 0.06, 0.16)},
		"rows": [".........", ".rr...rr.", "rhrr.rrrr", "rrrrrrrrr", "rrrrrrrrr", ".rrrrrrd.", "..rrrrd..", "...rdd...", "....d...."]},
	"contratista": {   # un papel colgado con su sello
		"pal": {"p": Color(0.95, 0.88, 0.7), "d": Color(0.7, 0.55, 0.35), "k": Color(0.25, 0.15, 0.1), "r": Color(0.8, 0.15, 0.18), "n": Color(0.45, 0.3, 0.18)},
		"rows": ["....n....", "..n.n.n..", ".pppnpppp", ".pkkkkkpd", ".ppppppd.", ".pkkkkpd.", ".pppppdd.", ".pprrrpd.", ".ddddddd."]},
	"mundo_abierto": {   # una puerta abierta de par en par con bloques de todas las clases
		"pal": {"k": Color(0.08, 0.05, 0.12), "w": Color(0.6, 0.5, 0.75), "i": Color(0.5, 0.85, 0.95), "h": Color(0.5, 0.5, 0.56), "r": Color(0.9, 0.35, 0.2), "g": Color(1.0, 0.85, 0.3)},
		"rows": ["wwwwwwwww", "wkkkkkkkw", "wkkkgkkkw", "wkkkkkkkw", "ikkkkkkkr", "ikkkkkkkr", "hkkkkkkkr", "hkkkkkkkr", "wwwwwwwww"]},
	"usurero": {   # una moneda y la mano que la guarda
		"pal": {"g": Color(1.0, 0.85, 0.3), "o": Color(0.75, 0.55, 0.1), "w": Color(1.0, 0.97, 0.8), "b": Color(0.4, 0.25, 0.15)},
		"rows": ["..ggggg..", ".gwggggo.", "gwgogggoo", "gwggogooo", "gwgogggoo", ".gggggoo.", "..ooooo..", "bbbbbbbbb", ".bbbbbbb."]},
	"relojeria": {
		"pal": {"g": Color(0.9, 0.7, 0.25), "w": Color(0.95, 0.93, 0.85), "h": Color(0.15, 0.1, 0.2)},
		"rows": ["..ggggg..", ".gwwwwwg.", "gwwwhwwwg", "gwwwhwwwg", "gwwwhhhwg", "gwwwwwwwg", "gwwwwwwwg", ".gwwwwwg.", "..ggggg.."]},
	"gran_casino": {
		"pal": {"g": Color(1.0, 0.85, 0.4), "m": Color(0.95, 0.94, 0.98), "d": Color(0.7, 0.72, 0.85)},
		"rows": [".ggggggg.", "..mmmmm..", "...mdm...", "...mdm...", "...mdm...", "...mdm...", "...mdm...", "..mmmmm..", ".ggggggg."]},
}

## Color de fondo de la tarjeta de cada escenario.
const THEME := {
	"tutorial": Color(0.12, 0.26, 0.22),
	"pesadilla": Color(0.14, 0.07, 0.24), "sin_piedad": Color(0.16, 0.14, 0.30), "compromiso": Color(0.30, 0.08, 0.12),
	"relojeria": Color(0.18, 0.14, 0.26), "gran_casino": Color(0.30, 0.26, 0.38), "contratista": Color(0.26, 0.20, 0.12),
	"mundo_abierto": Color(0.10, 0.18, 0.26), "usurero": Color(0.28, 0.22, 0.08),
}


## Dibuja la ilustración centrada en `center`, con cubitos de lado `s`.
static func draw(ci: CanvasItem, id: String, center: Vector2, s: float) -> void:
	var art: Dictionary = ART.get(id, ART.pesadilla)
	var rows: Array = art.rows
	var origin := center - Vector2(rows[0].length(), rows.size()) * s * 0.5
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			var ch := line[x]
			if ch == ".":
				continue
			var col: Color = art.pal.get(ch, Color.MAGENTA)
			ci.draw_rect(Rect2(origin + Vector2(x, y) * s, Vector2(s, s)), col)
			ci.draw_rect(Rect2(origin + Vector2(x, y) * s, Vector2(s, maxf(s * 0.18, 1.0))), col.lightened(0.3))
			ci.draw_rect(Rect2(origin + Vector2(x, y) * s + Vector2(0, s * 0.82), Vector2(s, maxf(s * 0.18, 1.0))), col.darkened(0.35))
