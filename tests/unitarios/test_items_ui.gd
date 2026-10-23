extends SceneTree
## Pruebas de la barra de items: iconos, casilleros que dependen de los boosts (acumulables) y uso con clic o tecla.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_items_ui.gd

const Items := preload("res://scripts/datos/items.gd")
const Icons := preload("res://scripts/ui/item_icons.gd")
const ItemBar := preload("res://scripts/ui/item_bar.gd")
const RunState := preload("res://scripts/datos/run_state.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_icons()
	test_capacity()
	await test_bars()
	print("tests de la barra de items terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_icons() -> void:
	var missing := ""
	for it in Items.ALL:
		if it.type != Items.Type.CLARITY and not Icons.has_icon(it.id):
			missing += it.id + " "
	check(missing == "", "todo boost y consumible tiene icono (faltan: %s)" % missing)
	var shape_ok := true
	var colors_ok := true
	var lit_ok := true
	for id in Icons.ICONS:
		var icon: Dictionary = Icons.ICONS[id]
		var rows: Array = icon.rows
		shape_ok = shape_ok and rows.size() == Icons.SIZE
		var lit := 0
		var used := {}
		for r in rows:
			shape_ok = shape_ok and r.length() == Icons.SIZE
			for ch in r:
				if ch != ".":
					lit += 1
					used[ch] = true
		lit_ok = lit_ok and lit >= 20
		colors_ok = colors_ok and icon.has("a")
		for ch in used:
			colors_ok = colors_ok and ch in ["o", "a", "b", "w"]
	check(shape_ok, "todos los iconos miden 9 x 9")
	check(lit_ok, "ningun icono es casi vacio")
	check(colors_ok, "los iconos usan solo las letras o, a, b y w (el brillo y el color secundario tienen valor por defecto)")
	var distinct := {}
	for id in Icons.ICONS:
		distinct[str(Icons.ICONS[id].rows) + str(Icons.ICONS[id].get("a", "")) + str(Icons.ICONS[id].get("b", ""))] = true   # (dos premios pueden compartir el dibujo con otros colores)
	check(distinct.size() == Icons.ICONS.size(), "no hay dos iconos iguales")


func test_capacity() -> void:
	var r := RunState.new()
	check(r.boost_capacity() == 5 and r.consumable_capacity() == 4, "de base: 5 casilleros de boosts y 4 de consumibles")
	check(r.take(Items.get_item("bolsillo_hondo")) and r.consumable_capacity() == 5, "Bolsillo hondo suma 1 casillero de consumibles")
	check(r.take(Items.get_item("bolsillo_hondo")) and r.consumable_capacity() == 6, "...y es acumulable (se puede tener dos)")
	check(r.take(Items.get_item("mente_abierta")) and r.boost_capacity() == 7, "Mente abierta suma 2 casilleros de boosts")
	check(r.take(Items.get_item("mente_abierta")) and r.boost_capacity() == 9, "...tambien acumulable")
	check(r.boosts.size() == 4 and r.boosts.count("mente_abierta") == 2 and r.boosts.count("bolsillo_hondo") == 2, "los repetidos ocupan un casillero cada uno")
	check(r.take(Items.get_item("aire_extra")) and not r.take(Items.get_item("aire_extra")), "un boost normal se guarda una vez y no se repite")
	# con los casilleros llenos no entra nada, ni Mente abierta
	var fresh := RunState.new()
	for id in ["aire_extra", "ahorro", "pies_de_luz", "paso_firme", "reflejos"]:
		fresh.take(Items.get_item(id))
	check(fresh.boosts.size() == fresh.boost_capacity() and not fresh.has_room_for(Items.get_item("mente_abierta")), "con los casilleros llenos no entra ni Mente abierta")
	var c := RunState.new()
	for i in 4:
		c.take(Items.get_item("freno"))
	check(not c.has_room_for(Items.get_item("freno")), "con 4 consumibles no entra un quinto")
	c.boosts.append("bolsillo_hondo")
	check(c.has_room_for(Items.get_item("freno")), "con Bolsillo hondo entra uno mas")


func test_bars() -> void:
	var run := RunState.new()
	var layer := Control.new()
	root.add_child(layer)
	var left = ItemBar.new()
	var right = ItemBar.new()
	layer.add_child(left)
	layer.add_child(right)
	var tip: Control = load("res://scripts/ui/voxel_label.gd").new()
	layer.add_child(tip)
	left.tip = tip
	left.setup(run, ItemBar.Kind.CONSUMABLE, true)
	right.setup(run, ItemBar.Kind.BOOST)
	await process_frame
	check(left.slots.size() == 4 and right.slots.size() == 5, "la barra izquierda tiene 4 casilleros y la derecha 5")
	var empty_ok := true
	for s in left.slots + right.slots:
		empty_ok = empty_ok and s.is_empty()
	check(empty_ok, "al empezar todos los casilleros estan vacios")
	check(left.slots[0].key_label == "1" and left.slots[3].key_label == "4" and right.slots[0].key_label == "", "los de consumibles muestran su tecla (1 a 4); los de boosts no")
	run.take(Items.get_item("freno"))
	run.take(Items.get_item("desarmar"))
	run.take(Items.get_item("racha_larga"))
	left.refresh()
	right.refresh()
	check(left.slots[0].item_id == "freno" and left.slots[1].item_id == "desarmar" and left.slots[2].is_empty(), "los consumibles ocupan los casilleros en orden")
	check(right.slots[0].item_id == "racha_larga" and right.slots[1].is_empty(), "los boosts tambien")
	run.take(Items.get_item("bolsillo_hondo"))
	run.take(Items.get_item("mente_abierta"))
	left.refresh()
	right.refresh()
	await process_frame
	check(left.slots.size() == 5 and right.slots.size() == 7, "las barras crecen: 5 de consumibles y 7 de boosts")
	run.take(Items.get_item("bolsillo_hondo"))
	left.refresh()
	check(left.slots.size() == 6, "y siguen creciendo si se acumulan")
	run.use_consumable("freno")
	left.refresh()
	check(left.slots[0].item_id == "desarmar" and left.slots[1].is_empty(), "al gastar un consumible los demas se corren")
	var pressed := []
	left.slot_pressed.connect(func(i): pressed.append(i))
	left.slots[0].pressed.emit()
	check(pressed == [0], "el clic en un casillero lo usa")
	left.slots[0].hovered.emit(true)
	check(tip.visible and tip.text.contains("Desarmar") and tip.text.contains("bomba"), "al pasar el mouse se muestra el nombre y la descripcion")
	left.slots[0].hovered.emit(false)
	check(not tip.visible, "...y se oculta al salir")
	layer.queue_free()
