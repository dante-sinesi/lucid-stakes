extends RefCounted
## Números grandes legibles: el juego puede romperse con los puntos (hasta 10^12 y más), así que a partir de 10 mil se abrevian
## ("12,3 mil", "1,23 M", "4,5 B"; en inglés "12.3k", "1.23M", "4.5B"). Hasta 9999 se escribe entero. Todo lo que muestra claridad pasa por acá.

const Loc := preload("res://scripts/loc.gd")

const STEPS := [[1e18, "Q"], [1e15, "P"], [1e12, "T"], [1e9, "B"], [1e6, "M"], [1e3, "mil"]]


## `n` abreviado: 9999 → "9999", 12345 → "12,3 mil", 1234567 → "1,23 M".
static func fmt(n) -> String:
	var v := float(n)
	var neg := v < 0.0
	var a := absf(v)
	if a < 10000.0:
		return str(int(n))
	var out := ""
	for step in STEPS:
		if a >= float(step[0]):
			var num := _num(a / float(step[0]))
			if Loc.lang == "es":
				out = num + " " + str(step[1])
			else:
				out = num + ("k" if step[1] == "mil" else str(step[1]))
			break
	return ("-" if neg else "") + out


## Tres cifras significativas: 123 → "123", 12,3 → "12,3", 1,23 → "1,23" (con coma en español y punto en inglés).
static func _num(x: float) -> String:
	var s: String
	if x >= 100.0:
		s = "%d" % int(x)
	elif x >= 10.0:
		s = "%.1f" % x
	else:
		s = "%.2f" % x
	if "." in s:
		s = s.rstrip("0").rstrip(".")
	if Loc.lang == "es":
		s = s.replace(".", ",")
	return s
