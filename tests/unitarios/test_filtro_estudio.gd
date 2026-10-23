extends SceneTree
## El filtro por cubos especiales del Estudio de salas. Uso: GAME_SANDBOX=1 SALAS_ARCHIVO=bibliotecas/paquete_salas.jsonl godot --headless --path . -s tests/unitarios/test_filtro_estudio.gd
var fallos := 0
func _ok(c: bool, m: String) -> void:
	print(("ok  " if c else "FALLA ") + m)
	if not c:
		fallos += 1
func _frames(n: int) -> void:
	for i in n:
		await process_frame
func _init() -> void:
	var e = load("res://torre/estudio.tscn").instantiate()
	root.add_child(e)
	await _frames(4)
	var total: int = e.salas.size()
	_ok(total > 100 and e.visibles.size() == total, "sin filtro se ven todas (%d)" % total)
	# a mano: cuántas tienen hielo, cuántas hielo y pinchos, cuántas sin especiales
	var hielo := 0
	var hielo_pinchos := 0
	var solo_hielo := 0
	var ninguno := 0
	for d in e.salas:
		var esp: String = e.especiales_de(d)
		if esp.contains("i"):
			hielo += 1
		if esp.contains("i") and esp.contains("s"):
			hielo_pinchos += 1
		if esp == "i":
			solo_hielo += 1
		if esp == "":
			ninguno += 1
	e.filtro["i"] = true
	e._filtro_cambio()
	_ok(e.visibles.size() == hielo and hielo > 0, "hielo: %d salas" % hielo)
	e.filtro["s"] = true
	e.filtro_modo = 0
	e._filtro_cambio()
	_ok(e.visibles.size() >= hielo, "hielo o pinchos: %d (>= las de hielo)" % e.visibles.size())
	e.filtro_modo = 1
	e._filtro_cambio()
	_ok(e.visibles.size() == hielo_pinchos, "hielo y pinchos a la vez: %d" % hielo_pinchos)
	e.filtro["s"] = false
	e.filtro_modo = 2
	e._filtro_cambio()
	_ok(e.visibles.size() == solo_hielo, "exactamente hielo: %d" % solo_hielo)
	e.filtro["i"] = false
	e.filtro["-"] = true
	e._filtro_cambio()
	_ok(e.visibles.size() == ninguno and ninguno > 0, "sin especiales: %d" % ninguno)
	_ok(e.visibles.has(e.actual), "la sala elegida es una de las visibles")
	e.filtro["-"] = false
	e._filtro_cambio()
	_ok(e.visibles.size() == total, "al desmarcar todo vuelven todas")
	print("fallos: ", fallos)
	quit(1 if fallos > 0 else 0)
