extends SceneTree
## Prueba del Estudio de salas nuevas sin ventana: abre una biblioteca, crea una sala, la resuelve con el solucionador nativo, edita y guarda.
## GAME_SANDBOX=1 SN_LIB=ruta.jsonl godot --headless --path . -s tests/test_estudio_salas_nuevas.gd


func _init() -> void:
	var fallos := 0
	var estudio = load("res://salas_nuevas/estudio.tscn").instantiate()
	root.add_child(estudio)
	await process_frame
	await process_frame
	estudio.sala_nueva()
	await process_frame
	var d: Dictionary = estudio.salas[estudio.actual]
	if int(d.pasos) <= 0 or d.camino.is_empty():
		fallos += 1
		print("FALLA: la sala nueva no se resolvió")
	else:
		print("ok  la sala nueva se resuelve en %d pasos" % int(d.pasos))
	estudio.ir_a(estudio.cuadros.size() - 1)
	if not estudio.cuadros[estudio.cuadros.size() - 1].ganado:
		fallos += 1
		print("FALLA: el camino no gana")
	else:
		print("ok  el camino gana")
	estudio.guardar()
	estudio.cargar(estudio.archivo)
	if estudio.salas.size() < 1:
		fallos += 1
		print("FALLA: no se guardó")
	else:
		print("ok  guardado y vuelto a abrir (%d salas)" % estudio.salas.size())
	print("fallos: ", fallos)
	quit(0)
