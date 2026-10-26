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
					arriba_ok = arriba_ok and v.has(Vector3i(x, Art.N - 1, z))
			check(arriba_ok, "estado %d semilla %d: el centro de la cara de arriba está completo" % [estado, semilla])
			check(v.size() > 600, "estado %d semilla %d: el bloque no queda hueco (%d minibloques)" % [estado, semilla, v.size()])
	check(Art.piedra(Art.Estado.CORRUPTO, 0, 3) == Art.piedra(Art.Estado.CORRUPTO, 0, 3), "el diseño es determinista")
	check(Art.piedra(Art.Estado.CORRUPTO, 0, 3) != Art.piedra(Art.Estado.CORRUPTO, 0, 4), "cada semilla da un bloque distinto")
	var luz := 0
	for c in Art.piedra(Art.Estado.CORRUPTO, 0, 1).values():
		if (c as Color).a < 1.0:
			luz += 1
	var luz_pura := 0
	for c in Art.piedra(Art.Estado.PURIFICADO, 0, 1).values():
		if (c as Color).a < 1.0:
			luz_pura += 1
	check(luz > 8 and luz_pura == 0, "el corrupto tiene vetas que brillan y el purificado ya no (%d y %d)" % [luz, luz_pura])
	check(Art.malla_piedra(Art.Estado.CORRUPTO, 0, 1).get_surface_count() == 1, "la malla se arma")
	print("tests del arte de bloques terminados, fallos: ", fallos)
	quit(1 if fallos > 0 else 0)
