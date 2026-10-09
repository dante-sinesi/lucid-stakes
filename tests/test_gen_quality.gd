extends SceneTree
## Calidad de la generacion con la BUSQUEDA COMPLETA (lento: varios minutos). Se corre a mano:
##   tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_gen_quality.gd
## Es la calidad que se espera de las torres generadas fuera de linea; el juego usa una busqueda mas liviana.

const Gen := preload("res://scripts/tower_gen.gd")
const K := preload("res://scripts/tower_logic.gd").Kind

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func std(a: Array) -> float:
	var m := 0.0
	for x in a:
		m += x
	m /= maxf(a.size(), 1)
	var v := 0.0
	for x in a:
		v += (x - m) * (x - m)
	return sqrt(v / maxf(a.size(), 1))


func _init() -> void:
	var d := 0.3
	var rows_all := []
	var ones := 0
	var target := lerpf(4.5, 2.6, d)
	for sd in 4:
		var r := Gen.generate_stage(sd, 6, d)
		check(r.ok, "d=0.3 semilla %d genera" % sd)
		if not r.ok:
			continue
		var ratio := float(r.logic.collapse_every) / (float(r.path.size()) / 6.0)
		check(ratio >= target * 0.95 and ratio <= target * 1.4, "margen de la caida parecido al objetivo (%.2f contra %.2f)" % [ratio, target])
		for m in r.rows:
			rows_all.append(m)
			if m <= 1:
				ones += 1
	print("calidad completa d=0.3: filas<=1 ", ones, "/", rows_all.size(), " desvio ", snappedf(std(rows_all), 0.01))
	check(float(ones) / maxf(rows_all.size(), 1) <= 0.1, "a lo sumo 10%% de filas triviales (hay %d de %d)" % [ones, rows_all.size()])
	check(std(rows_all) <= 2.0, "las filas no se dispersan demasiado (desvio %.2f)" % std(rows_all))

	# Etapa dificil: formas y mecanicas variadas
	var r := Gen.generate_stage(4, 6, 0.8)
	check(r.ok and r.kinds.has(K.ICE), "etapa dificil: hay hielo")
	var shapes := {}
	for sh in r.shapes:
		shapes[sh] = true
	check(shapes.size() >= 3, "etapa dificil: al menos 3 formas de plataforma (%d)" % shapes.size())
	print("tests de calidad del generador terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
