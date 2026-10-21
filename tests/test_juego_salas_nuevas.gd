extends SceneTree
## Prueba del modo de jugar del Estudio de salas nuevas: juega el camino más corto con las funciones de acción del Estudio, llega al checkpoint; luego se agotan
## los movimientos y se pierde una vida. GAME_SANDBOX=1 SN_LIB=archivo.jsonl godot --headless --path . -s tests/test_juego_salas_nuevas.gd


func _init() -> void:
	var fallos := 0
	var estudio = load("res://salas_nuevas/estudio.tscn").instantiate()
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
		print("ok  se gana jugando el camino más corto (%d de %d movimientos)" % [estudio.movs, estudio.maximo])
	estudio._reiniciar_sala("de nuevo")
	var vidas0: int = estudio.vidas
	for i in estudio.maximo + 2:
		estudio._accion_juego(Vector3i(1, 0, 0), 0)
		estudio._accion_juego(Vector3i(-1, 0, 0), 0)
		if estudio.vidas < vidas0:
			break
	if estudio.vidas < vidas0:
		print("ok  al agotarse los movimientos (o caer) se pierde una vida")
	else:
		fallos += 1
		print("FALLA: no se perdió ninguna vida")
	print("fallos: ", fallos)
	quit(0)
