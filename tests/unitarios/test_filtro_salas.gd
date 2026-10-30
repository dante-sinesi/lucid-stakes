extends SceneTree
## El filtro de salas sencillas (una escalera donde sólo hay que tirar de un bloque): ninguna torre trae una sala que mueva menos bloques distintos que el mínimo del filtro, y las torres se arman igual.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_filtro_salas.gd

const Torre := preload("res://torre/torre.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	check(Torre.minimo_distintos(9, Torre.FILTRO_NINGUNO) == 0, "sin filtro no hay mínimo")
	check(Torre.minimo_distintos(4, Torre.FILTRO_A) == 2 and Torre.minimo_distintos(23, Torre.FILTRO_A) == 2, "el filtro A pide 2 bloques distintos, sea cual sea la altura")
	check(Torre.minimo_distintos(4, Torre.FILTRO_B) == 2 and Torre.minimo_distintos(9, Torre.FILTRO_B) == 3 and Torre.minimo_distintos(15, Torre.FILTRO_B) == 5, "el filtro B pide un bloque más cada 3 pisos (y nunca menos de 2)")
	check(Torre.filtro_sencillas == Torre.FILTRO_B or OS.get_environment("SALAS_FILTRO") != "", "el filtro de siempre es el B")
	var paquete := Torre.cargar_paquete_del_juego()
	check(paquete.size() > 1000, "hay paquete de salas (%d)" % paquete.size())
	for modo in [Torre.FILTRO_A, Torre.FILTRO_B]:
		var salas := 0
		var mal := 0
		var sin_armar := 0
		for dif in ["facil", "media", "pesadilla"]:
			for etapa in [1, 4, 9]:
				for semilla in range(1, 9):
					Torre.filtro_sencillas = modo
					var t = Torre.armar(paquete, semilla * 131 + etapa, 7, true, etapa, dif)
					if t.salas.size() != 7:
						sin_armar += 1
					for e in t.salas:
						salas += 1
						if int(e.d.get("distintos", 99)) < Torre.minimo_distintos(int(e.d.get("pisos", int(e.d.meta) - 1)), modo):
							mal += 1
		check(sin_armar == 0, "con el filtro %s siempre se arman las 7 salas (%d torres sin armar)" % [modo, sin_armar])
		check(mal == 0, "con el filtro %s ninguna sala mueve menos bloques distintos que el mínimo (%d de %d)" % [modo, mal, salas])
	Torre.filtro_sencillas = Torre._filtro_por_omision()
	print("tests del filtro de salas terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
