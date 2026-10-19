extends SceneTree
## Auditoría de textos: abre las pantallas del menú y de Opciones (en español e inglés) y lista las etiquetas y los botones cuyo texto se sale de la ventana
## (o queda debajo de otro control que lo tapa). Correr con GAME_SANDBOX=1 y con ventana (necesita dibujar para medir).
## Uso: ... --rendering-driver opengl3 --resolution 1280x720 -s tests/audit_texto.gd

var found := {}


func _visible_in_tree(c: Control) -> bool:
	var n: Node = c
	while n != null:
		if n is CanvasItem and not (n as CanvasItem).visible:
			return false
		n = n.get_parent()
	return true


func _scan(screen: String) -> void:
	var view := root.get_visible_rect()
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is Control) or not _visible_in_tree(n):
			continue
		var text := ""
		if "text" in n and n.text is String:
			text = n.text
		if text.strip_edges() == "" or not (n.get_class() == "Control" or n is Button or n is Label or n.get_script() != null):
			continue
		var r: Rect2 = (n as Control).get_global_rect()
		if r.size.x <= 1.0 or r.size.y <= 1.0:
			continue
		var clipped := r.position.x < -2.0 or r.end.x > view.size.x + 2.0
		# ¿lo corta un contenedor con desplazamiento? (el borde del contenedor)
		var p: Node = n.get_parent()
		var scroll_clip := false
		while p != null:
			if p is ScrollContainer:
				var pr: Rect2 = (p as Control).get_global_rect()
				if r.end.x > pr.end.x + 2.0:
					scroll_clip = true
				break
			p = p.get_parent()
		if clipped or scroll_clip:
			var key := screen + "|" + text.substr(0, 60)
			if not found.has(key):
				found[key] = "%s: «%s» (%dx%d en %d,%d)" % [screen, text.replace("\n", " ").substr(0, 70), r.size.x, r.size.y, r.position.x, r.position.y]


func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.quit_game_override = true
	root.add_child(main)
	for i in 20:
		await process_frame
	for lang in ["es", "en"]:
		var mm = main.main_menu
		if lang == "en":
			mm.options.lang_buttons.en.pressed.emit()
			for i in 10:
				await process_frame
			mm = main.main_menu
		_scan("menu " + lang)
		mm.buttons["opciones"].pressed.emit()
		for t in ["general", "graficos", "sonido", "controles"]:
			mm.options.show_tab(t)
			for i in 20:
				await process_frame
			_scan("opciones/%s %s" % [t, lang])
		for id in ["despertar", "cosmeticos", "creditos"]:
			main.open_main_menu()
			for i in 10:
				await process_frame
			mm = main.main_menu
			mm.buttons[id].pressed.emit()
			for i in 25:
				await process_frame
			_scan("%s %s" % [id, lang])
		main.open_main_menu()
		for i in 10:
			await process_frame
	var keys := found.keys()
	keys.sort()
	for k in keys:
		print("SE SALE  ", found[k])
	print("auditoría de textos terminada: ", keys.size(), " textos fuera de su espacio")
	quit()
