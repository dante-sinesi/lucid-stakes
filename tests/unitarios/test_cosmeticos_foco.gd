extends SceneTree
## El foco de la pantalla de personaje se mueve como se ve (izquierda/derecha en la fila, arriba/abajo entre filas y solapas).
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_cosmeticos_foco.gd

const Screen := preload("res://scripts/ui/cosmetics_screen.gd")
var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	var s = Screen.new()
	root.add_child(s)
	s.visible = true
	await process_frame
	for t in ["personajes", "gorros", "ropa"]:
		s.set_tab(t)
		await process_frame
		var list: Array = s.grid.get_children()
		var n := list.size()
		check(n > 0, t + ": hay casilleros")
		var last: Control = list[n - 1]
		check(last.get_node(last.focus_neighbor_right) == last, t + ": a la derecha del último no se sale")
		var first: Control = list[0]
		check(first.get_node(first.focus_neighbor_left) == first, t + ": a la izquierda del primero no se sale")
		check(first.get_node(first.focus_neighbor_top) == s.tab_buttons[t], t + ": desde la primera fila se sube a la solapa")
		if n > 1:
			check(list[0].get_node(list[0].focus_neighbor_right) == list[1], t + ": derecha = el casillero siguiente")
		if n > s.COLUMNS:
			check(list[0].get_node(list[0].focus_neighbor_bottom) == list[s.COLUMNS], t + ": abajo = la fila siguiente")
			check(list[s.COLUMNS - 1].get_node(list[s.COLUMNS - 1].focus_neighbor_right) == list[s.COLUMNS - 1], t + ": el borde derecho de la fila no pasa a la siguiente")
		check(s.tab_buttons[t].get_node(s.tab_buttons[t].focus_neighbor_bottom) == list[0], t + ": de la solapa se baja al primer casillero")
	print("tests del foco de personajes terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
