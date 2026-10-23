extends RefCounted
## Íconos de los símbolos del casino (tragamonedas y palos de las cartas), hechos de cubitos: un dibujo de 9 x 9 casillas donde cada
## letra es un color. `draw(ci, id, center, size)` los pinta en cualquier control.

const PALETTE := {
	"o": Color(0.10, 0.05, 0.16),   # contorno
	"a": Color(0.62, 0.40, 0.95),   # lila
	"b": Color(0.82, 0.68, 1.0),    # lila claro
	"c": Color(0.36, 0.20, 0.60),   # lila oscuro
	"w": Color(0.84, 0.97, 1.0),    # hielo
	"i": Color(0.55, 0.82, 1.0),    # hielo oscuro
	"y": Color(1.0, 0.85, 0.30),    # oro
	"h": Color(1.0, 0.95, 0.65),    # oro claro
	"r": Color(1.0, 0.30, 0.20),    # rojo
	"d": Color(0.17, 0.17, 0.22),   # cuerpo de la bomba
	"g": Color(0.60, 0.62, 0.72),   # brillo de la bomba
}

const PATTERNS := {
	"cubo": [
		".ooooooo.",
		"obbbbbbao",
		"obbbbbaao",
		"obbbbaaao",
		"obbaaaaao",
		"obaaaaaco",
		"oaaaaaaco",
		"occccccco",
		".ooooooo.",
	],
	"hielo": [
		"....w....",
		".i..w..i.",
		"..i.w.i..",
		"...www...",
		"wwwwwwwww",
		"...www...",
		"..i.w.i..",
		".i..w..i.",
		"....w....",
	],
	"bomba": [
		"......h.y",
		".....r.h.",
		"....or...",
		"..ooddoo.",
		".odggdddo",
		".odgdddd.",
		".odddddd.",
		"..oddddo.",
		"...oooo..",
	],
	"sol": [
		"....y....",
		".y..y..y.",
		"..yhhhy..",
		".yhhyyyy.",
		"yyhyyyyyy",
		".yyyyyyy.",
		"..yyyyy..",
		".y..y..y.",
		"....y....",
	],
	"corona": [
		".........",
		"y...y...y",
		"yy.yyy.yy",
		"yhyyyyyhy",
		"yyyyyyyyy",
		"yryyyyyry",
		"yyyyyyyyy",
		"ooooooooo",
		".........",
	],
}


## Pinta el ícono `id` centrado en `center`, de `size` píxeles de lado (cada casilla mide size / 9).
static func draw(ci: CanvasItem, id: String, center: Vector2, size: float, tint := Color.WHITE) -> void:
	if not PATTERNS.has(id):
		return
	var rows: Array = PATTERNS[id]
	var s := size / 9.0
	var origin := center - Vector2(size, size) * 0.5
	for y in 9:
		var row: String = rows[y]
		for x in 9:
			var ch := row[x]
			if ch == ".":
				continue
			var col: Color = PALETTE.get(ch, Color.WHITE) * tint
			var p := origin + Vector2(x, y) * s
			ci.draw_rect(Rect2(p, Vector2(s, s)), col)
			ci.draw_rect(Rect2(p, Vector2(s, maxf(s * 0.25, 1.0))), col.lightened(0.25))   # un filo claro arriba: se lee como cubito
			ci.draw_rect(Rect2(p + Vector2(0, s * 0.8), Vector2(s, maxf(s * 0.2, 1.0))), col.darkened(0.25))
