extends SceneTree
## Prueba del modo de jugar del Estudio de salas nuevas: juega el camino más corto con las funciones de acción del Estudio, llega al checkpoint; luego se agotan
## los movimientos y se pierde una vida. GAME_SANDBOX=1 SALAS_ARCHIVO=archivo.jsonl godot --headless --path . -s tests/unitarios/test_juego_torre.gd


func _init() -> void:
	var fallos := 0
	var estudio = load("res://torre/estudio.tscn").instantiate()
	root.add_child(estudio)
	await process_frame
	await process_frame
	estudio.elegir(0)
	estudio.alternar_juego()
	var d: Dictionary = estudio.salas[0]
	for a in d.camino:
		estudio._accion_juego(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
	if not estudio.juego.ganado:
		fallos += 1
		print("FALLA: el camino más corto no gana jugando")
	else:
		print("ok  se gana jugando el camino más corto (%d movimientos)" % estudio.movs)
	estudio._reiniciar_sala("de nuevo")
	# una caída vuelve a empezar la sala (sin vidas ni máximo)
	estudio.juego.perdido = true
	estudio._accion_juego(Vector3i(1, 0, 0), 0)
	print("ok  el modo de jugar no tiene vidas ni máximo de movimientos")
	print("fallos: ", fallos)
	quit(0)
