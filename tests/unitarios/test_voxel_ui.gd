extends SceneTree
## Pruebas de la interfaz de cubitos: fuente, diseño del texto, etiquetas y botones.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_voxel_ui.gd

const VFont := preload("res://scripts/ui/voxel_font.gd")
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const UI := preload("res://scripts/ui/menu_ui.gd")
const VoxelLabel := preload("res://scripts/ui/voxel_label.gd")
const VoxelButton := preload("res://scripts/ui/voxel_button.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_font()
	test_layout()
	await test_controls()
	print("tests de la interfaz de cubitos terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_font() -> void:
	# Todas las letras, digitos y signos que usa el juego tienen glifo.
	var missing := ""
	var all_text: String = UI.TITLE + UI.SUBTITLE + _story_text() + "Ruleta de la Luz Claridad Ficha: GIRAR Salir del casino ¡Cayó el 0! ¿Cuánto arriesgas? 1234567890 ×·«»%+-*/()[]=<>_|'\".,;:!?"
	for it in preload("res://scripts/datos/items.gd").ALL:
		all_text += it.name + it.desc
	for line in preload("res://scripts/datos/story.gd").GREETINGS:
		all_text += line
	for msg in ["Freno: la fila de abajo se detiene 5 movimientos", "No hay bombas para desarmar", "El hielo se volvió roca", "El bloque de enfrente es ahora una catapulta", "Bloque anclado: no cae en esta etapa", "¡Segundo aliento!", "Generando la torre de la etapa 3... 12 s", "No se pudo generar la torre.", "¡Completaste la torre!", "¡Escapaste de la pesadilla!", "Explotó una bomba: la torre se derrumbó", "Caíste al vacío", "No se puede tirar: no hay piso atrás", "Tragamonedas: próximamente"]:
		all_text += msg
	for i in all_text.length():
		var ch := all_text[i]
		if ch == "\n" or ch == "\r" or ch == " ":
			continue
		if not VFont.G.has(ch) and not VFont.ACCENTED.has(ch):
			missing += ch
	check(missing == "", "todos los caracteres del juego tienen glifo (faltan: '%s')" % missing)
	# Forma de cada glifo: 5 de ancho, 7 filas de cuerpo (9 con cola).
	var shape_ok := true
	for ch in VFont.G:
		var rows: Array = VFont.G[ch]
		shape_ok = shape_ok and (rows.size() == 7 or rows.size() == 9)
		for r in rows:
			shape_ok = shape_ok and (r.length() == 5 or (ch == "∞" and r.length() == 9))   # (el infinito es más ancho: va al final del texto)
	check(shape_ok, "cada glifo mide 5 de ancho y 7 u 9 filas")
	# Celdas dentro del casillero
	var inside := true
	for ch in "AaBbgjpqyÁéíñÜ¿?":
		for c in VFont.glyph_cells(ch):
			inside = inside and c.x >= 0 and c.x < VFont.W and c.y >= 0 and c.y < VFont.H
	check(inside, "las celdas de cada glifo caen dentro del casillero de 5 x 11")
	check(VFont.glyph_cells("A").size() == 18 and VFont.glyph_cells(" ").is_empty(), "A tiene 18 cubitos y el espacio ninguno")
	# Acentos: la i con acento no tiene punto y la vocal acentuada tiene cubitos arriba
	var top := func(ch: String) -> int:
		var n := 0
		for c in VFont.glyph_cells(ch):
			if c.y < VFont.ACCENT_ROWS:
				n += 1
		return n
	check(top.call("á") == 2 and top.call("a") == 0 and top.call("Ñ") > 0 and top.call("ü") == 2, "los acentos usan las dos filas de arriba")
	var i_dot := VFont.glyph_cells("i").filter(func(c): return c.y == VFont.ACCENT_ROWS)
	var i_acc_dot := VFont.glyph_cells("í").filter(func(c): return c.y == VFont.ACCENT_ROWS)
	check(i_dot.size() == 1 and i_acc_dot.is_empty(), "la i con acento pierde el punto")
	check(VFont.glyph_cells("ß") == VFont.glyph_cells("?"), "un caracter desconocido se dibuja como ?")


func test_layout() -> void:
	check(VFont.line_width("") == 0 and VFont.line_width("A") == 5 and VFont.line_width("AB") == 11, "ancho de una linea: 6 por letra menos la separacion final")
	var l := VFont.layout(["AB", "C"])
	check(l.size == Vector2i(11, VFont.LINE_H + VFont.H), "alto de dos lineas (%s)" % str(l.size))
	var any_second := false
	for c in l.cells:
		any_second = any_second or c.y >= VFont.LINE_H
	check(any_second, "la segunda linea queda mas abajo")
	var centered := VFont.layout(["AAAA", "A"], 1)
	var min_x := 99
	for c in centered.cells:
		if c.y >= VFont.LINE_H:
			min_x = mini(min_x, c.x)
	check(min_x >= 9, "una linea centrada se corre hacia el medio (x minima %d)" % min_x)
	# Cortar por palabras
	var w := VFont.wrap("hola mundo cruel", 6 * 10 - 1)   # entran 10 letras
	check(w == ["hola mundo", "cruel"], "wrap corta por palabras: %s" % str(w))
	check(VFont.wrap("a\n\nb", 100) == ["a", "", "b"], "wrap respeta los saltos de linea")
	var long := VFont.wrap("supercalifragilistico", 6 * 8 - 1)
	check(long.size() == 3 and long[0].length() == 8, "una palabra mas larga que la linea se corta")
	# Ruido estable y distribuido
	check(Draw.noise(3, 4, 5) == Draw.noise(3, 4, 5) and Draw.noise(3, 4, 5) != Draw.noise(4, 3, 5), "el ruido es estable")
	var low := 0
	for i in 1000:
		if Draw.noise(i, i * 3, 7) < 0.3:
			low += 1
	check(low > 200 and low < 400, "el ruido se reparte parejo (%d de 1000 por debajo de 0,3)" % low)


func test_controls() -> void:
	var lab: Control = UI.label(null, "Hola", 3, Color.WHITE)
	root.add_child(lab)
	await process_frame
	check(lab.get_combined_minimum_size().x == (4 * 6 - 1) * 3, "la etiqueta mide su texto en cubitos (ancho %s)" % str(lab.get_combined_minimum_size()))
	var w0 := lab.get_combined_minimum_size().x
	lab.text = "Hola mundo"
	check(lab.get_combined_minimum_size().x > w0, "al cambiar el texto se vuelve a medir")
	var wrapped: Control = UI.label(null, _story_text(), 2, Color.WHITE, false, 800)
	root.add_child(wrapped)
	await process_frame
	check(wrapped.get_combined_minimum_size().x <= 800 and wrapped.get_combined_minimum_size().y > 200, "el texto largo se corta para entrar en su ancho")
	# Botón
	var b: Button = UI.button("Salir", true, 3.0, 40)
	root.add_child(b)
	await process_frame
	check(b.custom_minimum_size.x >= 40 * 3 and b.custom_minimum_size.y > VFont.H * 3, "el boton tiene un tamano minimo")
	var small: float = b.custom_minimum_size.x
	b.set_label("Volver al menú principal")
	check(b.custom_minimum_size.x > small and b.text == "Volver al menú principal", "al cambiar el texto del boton se vuelve a medir")
	var pressed := []
	b.pressed.connect(func(): pressed.append(1))
	b.pressed.emit()
	check(pressed.size() == 1 and b.focus_mode == Control.FOCUS_ALL, "es un Button de verdad: senal y foco")
	b.disabled = true
	check(b._state() == 3, "desactivado se dibuja apagado")
	b.disabled = false
	b.toggle_mode = true
	b.button_pressed = true
	check(b._state() == 2, "un boton de dos estados apretado se ve apretado")
	# Los botones nunca quedan chicos respecto del texto: el texto entra con margen (al menos 5 cubitos a cada lado y 2 arriba y abajo)
	var all_ok := true
	var ratios := ""
	var MainMenu := preload("res://scripts/ui/main_menu.gd")
	var PauseMenu := preload("res://scripts/ui/pause_menu.gd")
	var mm := MainMenu.new()
	var pm := PauseMenu.new()
	root.add_child(mm)
	root.add_child(pm)
	await process_frame
	for menu in [mm, pm]:
		for id in menu.buttons:
			var bt: Button = menu.buttons[id]
			var lines: PackedStringArray = bt.text.split("
")
			var tw := 0
			for ln in lines:
				tw = maxi(tw, VFont.line_width(ln))
			var need_w: float = (tw + 10) * bt.cube + bt.frame_cube() * 2.0
			var need_h: float = (VFont.layout(lines, 1).size.y + 4) * bt.cube + bt.frame_cube() * 2.0
			var cs: Vector2 = bt.card_size()
			all_ok = all_ok and cs.x >= need_w and cs.y >= need_h and bt.custom_minimum_size.y > cs.y
			ratios += "%s %.2f  " % [id, cs.x / (tw * bt.cube)]
	check(all_ok, "los botones de los menus son mas grandes que su texto con margen (ancho de carta / ancho de texto: %s)" % ratios)
	mm.queue_free()
	pm.queue_free()
	# Dibujar no rompe (se fuerza un redibujado con el arbol activo)
	b.queue_redraw()
	lab.queue_redraw()
	await process_frame
	lab.queue_free()
	wrapped.queue_free()
	b.queue_free()


## Todo el texto de la historia del tutorial (sirve para comprobar que la fuente tiene todas las letras y para probar un texto largo).
func _story_text() -> String:
	var Story := preload("res://scripts/datos/story.gd")
	var out := ""
	for l in Story.intro():
		out += (l if typeof(l) == TYPE_STRING else str(l.text)) + " "
	for l in Story.outro():
		out += (l if typeof(l) == TYPE_STRING else str(l.text)) + " "
	for id in Story.LESSONS:
		out += Story.LESSONS[id] + " "
	return out
