extends SceneTree
## El arte de 10 x 10 x 10 del bloque de piedra (block_art.gd): la cara de arriba que se pisa está completa y plana, es determinista, los dos estados se distinguen
## y las vetas corruptas brillan (alfa menor que 1). Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/unitarios/test_block_art.gd
const Art := preload("res://scripts/personajes/block_art.gd")
var fallos := 0


func check(c: bool, m: String) -> void:
	if not c:
		fallos += 1
		print("FAIL: ", m)


func _init() -> void:
	for estado in [Art.Estado.CORRUPTO, Art.Estado.PURIFICADO]:
		for semilla in 12:
			var v: Dictionary = Art.piedra(estado, 0, semilla)
			var arriba_ok := true
			for x in range(1, Art.N - 1):
				for z in range(1, Art.N - 1):
					var sup := Vector3i(x, Art.N - 1, z)
					arriba_ok = arriba_ok and (v.has(sup) or (v.has(sup + Vector3i(0, -1, 0)) and (v[sup + Vector3i(0, -1, 0)] as Color).a < 1.0))   # (o una ranura de magma de un minibloque)
			check(arriba_ok, "estado %d semilla %d: el centro de la cara de arriba está completo" % [estado, semilla])
			check(v.size() > 600, "estado %d semilla %d: el bloque no queda hueco (%d minibloques)" % [estado, semilla, v.size()])
	check(Art.piedra(Art.Estado.CORRUPTO, 0, 3) == Art.piedra(Art.Estado.CORRUPTO, 0, 3), "el diseño es determinista")
	check(Art.piedra(Art.Estado.CORRUPTO, 0, 3) != Art.piedra(Art.Estado.CORRUPTO, 0, 4), "cada semilla da un bloque distinto")
	var luz := 0
	for c in Art.piedra(Art.Estado.CORRUPTO, 0, 1).values():
		if (c as Color).a < 1.0:
			luz += 1
	var luz_pura := 0
	for c in Art.piedra(Art.Estado.PURIFICADO, 4, 1).values():
		if (c as Color).a < 1.0:
			luz_pura += 1
	check(luz > 8 and luz_pura == 0, "el corrupto tiene vetas que brillan y el purificado final ya no (%d y %d)" % [luz, luz_pura])
	var brillo_nivel: Array[float] = []
	for nivel in Art.NIVELES:
		var total := 0.0
		for semilla in 12:
			for c in Art.piedra(Art.Estado.CORRUPTO, nivel, semilla).values():
				total += 1.0 - (c as Color).a
		brillo_nivel.append(total)
	check(brillo_nivel[0] > brillo_nivel[1] and brillo_nivel[1] > brillo_nivel[2] and brillo_nivel[2] >= brillo_nivel[3] and brillo_nivel[3] >= brillo_nivel[4], "el magma que brilla baja nivel a nivel (%s)" % str(brillo_nivel))
	# una sola escala de corrupción: el corrupto de la última etapa es como el purificado de la primera, y el purificado de la primera es más corrupto que el de la segunda
	check(is_equal_approx(Art.corrupcion(Art.Estado.CORRUPTO, 4), Art.corrupcion(Art.Estado.PURIFICADO, 0)), "el corrupto de la última etapa parece el purificado de la primera")
	check(Art.piedra(Art.Estado.CORRUPTO, 4, 2) == Art.piedra(Art.Estado.PURIFICADO, 0, 2), "...y es el mismo diseño")
	var lum := func(estado: int, nivel: int) -> float:
		var tot := 0.0
		var n := 0
		for semilla in 12:
			for c in Art.piedra(estado, nivel, semilla).values():
				tot += (c as Color).get_luminance()
				n += 1
		return tot / float(n)
	check(lum.call(Art.Estado.PURIFICADO, 0) < lum.call(Art.Estado.PURIFICADO, 1) and lum.call(Art.Estado.PURIFICADO, 1) < lum.call(Art.Estado.PURIFICADO, 4), "el purificado de cada etapa es más claro que el de la anterior")
	check(lum.call(Art.Estado.CORRUPTO, 0) < lum.call(Art.Estado.CORRUPTO, 2) and lum.call(Art.Estado.CORRUPTO, 2) < lum.call(Art.Estado.CORRUPTO, 4), "y el corrupto también se aclara con las etapas")
	check(Art.corrupcion(Art.Estado.PURIFICADO, 4) == 0.0 and Art.corrupcion(Art.Estado.CORRUPTO, 0) == 1.0, "los extremos de la escala")
	check(Art.nivel_de_etapa(1) == 0 and Art.nivel_de_etapa(3) == 0 and Art.nivel_de_etapa(4) == 1 and Art.nivel_de_etapa(15) == 4, "un nivel cada tres etapas")
	check(Art.malla_piedra(Art.Estado.CORRUPTO, 0, 1).get_surface_count() == 1, "la malla se arma")
	# el bloque pesado (hierro): la misma escala, la cara de arriba completa y se distingue de la piedra
	for estado in [Art.Estado.CORRUPTO, Art.Estado.PURIFICADO]:
		for semilla in 8:
			var h: Dictionary = Art.bloque("hierro", estado, 0, semilla)
			var arriba_h := true
			for x in range(1, Art.N - 1):
				for z in range(1, Art.N - 1):
					var sup_h := Vector3i(x, Art.N - 1, z)
					arriba_h = arriba_h and (h.has(sup_h) or (h.has(sup_h + Vector3i(0, -1, 0)) and (h[sup_h + Vector3i(0, -1, 0)] as Color).a < 1.0))
			check(arriba_h and h.size() > 700, "hierro estado %d semilla %d: arriba completo y sin huecos (%d)" % [estado, semilla, h.size()])
	for estado in [Art.Estado.CORRUPTO, Art.Estado.PURIFICADO]:
		for semilla in 8:
			var hi: Dictionary = Art.bloque("hielo", estado, 0, semilla)
			var arriba_hi := true
			for x in range(1, Art.N - 1):
				for z in range(1, Art.N - 1):
					var sup_hi := Vector3i(x, Art.N - 1, z)
					arriba_hi = arriba_hi and (hi.has(sup_hi) or (hi.has(sup_hi + Vector3i(0, -1, 0)) and (hi[sup_hi + Vector3i(0, -1, 0)] as Color).a < 1.0))
			check(arriba_hi and hi.size() > 600, "hielo estado %d semilla %d: arriba completo y sin huecos (%d)" % [estado, semilla, hi.size()])
	check(Art.bloque("hielo", Art.Estado.CORRUPTO, 4, 2) == Art.bloque("hielo", Art.Estado.PURIFICADO, 0, 2), "en el hielo también el corrupto del final es el purificado del principio")
	for estado in [Art.Estado.CORRUPTO, Art.Estado.PURIFICADO]:
		for semilla in 8:
			var ar: Dictionary = Art.bloque("arenisca", estado, 0, semilla)
			var arriba_ar := true
			for x in range(1, Art.N - 1):
				for z in range(1, Art.N - 1):
					var sup_ar := Vector3i(x, Art.N - 1, z)
					arriba_ar = arriba_ar and (ar.has(sup_ar) or (ar.has(sup_ar + Vector3i(0, -1, 0)) and (ar[sup_ar + Vector3i(0, -1, 0)] as Color).a < 1.0))
			check(arriba_ar and ar.size() > 500, "arenisca estado %d semilla %d: arriba completo y sin huecos (%d)" % [estado, semilla, ar.size()])
	check(Art.bloque("arenisca", Art.Estado.CORRUPTO, 4, 2) == Art.bloque("arenisca", Art.Estado.PURIFICADO, 0, 2), "en la arenisca también el corrupto del final es el purificado del principio")
	for tipo_t in ["trampa", "trampa2"]:
		for estado in [Art.Estado.CORRUPTO, Art.Estado.PURIFICADO]:
			for semilla in 8:
				var tr: Dictionary = Art.bloque(tipo_t, estado, 0, semilla)
				var marcas := 0
				var esperadas := 0
				for x in range(1, Art.N - 1):
					for z in range(1, Art.N - 1):
						var q := Vector3i(x, Art.N - 1, z)
						if Art._es_marca(q, tipo_t == "trampa2"):
							esperadas += 1
							if tr.has(q) and tr[q] == Art._color_marca(q, Art.corrupcion(estado, 0)):
								marcas += 1
				check(marcas == esperadas and esperadas >= 8 and tr.size() > 700, "%s estado %d semilla %d: las marcas de arriba se ven enteras (%d de %d) y no hay huecos (%d)" % [tipo_t, estado, semilla, marcas, esperadas, tr.size()])
	check(Art.bloque("trampa", Art.Estado.CORRUPTO, 4, 2) == Art.bloque("trampa", Art.Estado.PURIFICADO, 0, 2), "en la trampa también el corrupto del final es el purificado del principio")
	check(Art.bloque("hierro", Art.Estado.PURIFICADO, 2, 1) != Art.bloque("piedra", Art.Estado.PURIFICADO, 2, 1), "el hierro no es la piedra")
	check(Art.bloque("hierro", Art.Estado.CORRUPTO, 4, 2) == Art.bloque("hierro", Art.Estado.PURIFICADO, 0, 2), "en el hierro también el corrupto del final es el purificado del principio")
	check(Art.malla_bloque("hierro", Art.Estado.CORRUPTO, 0, 1).get_surface_count() == 1, "la malla del hierro se arma")
	print("tests del arte de bloques terminados, fallos: ", fallos)
	quit(1 if fallos > 0 else 0)
