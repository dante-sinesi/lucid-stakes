extends SceneTree
## El foco de Opciones se mueve en orden (fila a fila) en todas las pestañas, y la lista acompaña al foco.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_opciones_foco.gd

const Screen := preload("res://scripts/ui/options_screen.gd")
const Controls := preload("res://scripts/entrada/controls.gd")
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
	for t in s.TABS:
		s.show_tab(t)
		await process_frame
		var rows: Array = []
		s._collect_rows(s.pages[t], rows)
		check(rows.size() > 0, t + ": hay filas")
		var first: Control = rows[0][0]
		check(first.get_node(first.focus_neighbor_top) == s.tab_buttons[t], t + ": de la primera fila se sube a la solapa")
		check(s.tab_buttons[t].get_node(s.tab_buttons[t].focus_neighbor_bottom) == first, t + ": de la solapa se baja a la primera fila")
		# bajar siempre recorre todas las filas en orden, sin saltos ni vueltas
		var n: Control = first
		var visited := 1
		var guard := 0
		while guard < 300:
			var nxt: Control = n.get_node(n.focus_neighbor_bottom)
			if nxt == n:
				break
			n = nxt
			visited += 1
			guard += 1
		check(visited == rows.size(), t + ": bajando se recorren las %d filas (%d)" % [rows.size(), visited])
		var last_row: Array = rows[rows.size() - 1]
		var last: Control = last_row[last_row.size() - 1]
		check(last.get_node(last.focus_neighbor_right) == last, t + ": a la derecha del último no se sale")
	# Controles: una fila por acción
	s.show_tab("controles")
	await process_frame
	var crows: Array = []
	s._collect_rows(s.pages["controles"], crows)
	check(crows.size() >= Controls.ACTIONS.size() + 2, "Controles: una fila por acción más las dos de arriba (%d)" % crows.size())
	for k in s.pages.keys():
		if s.pages[k] is ScrollContainer:
			check(s.pages[k].follow_focus, k + ": la lista acompaña al foco")
	check(s.find_child("desplazamiento_controles", true, false).follow_focus, "Controles: la lista acompaña al foco")
	print("tests del foco de Opciones terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
