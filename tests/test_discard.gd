extends SceneTree
## Pruebas de tirar boosts y consumibles (clic derecho en la barra, con confirmación, sin recuperar claridad) (headless).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_discard.gd

const RunState := preload("res://scripts/run_state.gd")
const ItemBar := preload("res://scripts/item_bar.gd")
const CasinoScene := preload("res://scripts/casino_scene.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_run()
	await test_bar()
	await test_casino()
	print("tests de tirar ítems terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_run() -> void:
	var run := RunState.new()
	run.claridad = 100
	run.boosts.assign(["aire_extra", "reflejos"])
	run.consumables.assign(["freno", "totem"])
	check(run.discard_error("boost", 0) == "" and run.discard_error("consumable", 1) == "", "se pueden tirar boosts y consumibles")
	check(run.discard_error("boost", 5) != "" and run.discard_error("consumable", -1) != "", "un lugar sin ítem no")
	check(run.discard("consumable", 0) == "freno" and run.consumables == ["totem"], "tirar un consumible lo saca")
	check(run.discard("boost", 1) == "reflejos" and run.boosts == ["aire_extra"], "y un boost")
	check(run.claridad == 100, "sin recuperar claridad")
	check(run.discard("boost", 7) == "" and run.boosts == ["aire_extra"], "un lugar vacío no hace nada")
	# un boost que agranda las barras no se tira si lo demás ya no entra
	var full := RunState.new()
	full.boosts.assign(["mente_abierta", "aire_extra", "reflejos", "ahorro", "ojo_de_hielo", "paso_firme", "pies_de_luz"])   # 7: 5 + 2 de Mente abierta
	check(full.boosts.size() == full.boost_capacity(), "(7 boosts con la barra ampliada)")
	check(full.discard_error("boost", 0) != "" and full.discard("boost", 0) == "" and full.boosts.size() == 7, "no se tira Mente abierta si los demás dejarían de entrar")
	check(full.discard_error("boost", 1) == "", "otros boosts sí")
	var pockets := RunState.new()
	pockets.boosts.assign(["bolsillo_hondo"])
	pockets.consumables.assign(["freno", "freno", "freno", "freno", "freno"])   # 5 consumibles: 4 + 1 de Bolsillo hondo
	check(pockets.discard_error("boost", 0) != "", "ni el Bolsillo hondo si los consumibles ya no entrarían")


func test_bar() -> void:
	var run := RunState.new()
	run.boosts.assign(["aire_extra"])
	run.consumables.assign(["freno", "escudo"])
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var bar := ItemBar.new()
	layer.add_child(bar)
	bar.setup(run, ItemBar.Kind.CONSUMABLE, false)
	var got := []
	bar.discarded.connect(func(k, id): got.append([k, id]))
	await process_frame
	# el clic derecho pide confirmación
	bar.slots[0].discard.emit()
	check(bar._prompt != null and run.consumables == ["freno", "escudo"], "el clic derecho pregunta antes de tirar (todavía no se tiró)")
	bar._prompt.no_button.pressed.emit()
	await process_frame
	check(bar._prompt == null and run.consumables == ["freno", "escudo"] and got.is_empty(), "Cancelar no tira nada")
	bar.ask_discard(1)
	bar._prompt.yes_button.pressed.emit()
	await process_frame
	check(run.consumables == ["freno"] and got == [[ItemBar.Kind.CONSUMABLE, "escudo"]] and bar.slots[1].is_empty(), "Tirar saca el ítem, la barra se actualiza y avisa")
	check(bar._prompt == null, "y se cierra la pregunta")
	# sin ítem en el casillero no pasa nada
	bar.slots[3].discard.emit()
	check(bar._prompt == null, "un casillero vacío no pregunta")
	# un boost que no se puede tirar: la pregunta lo dice y no deja confirmar
	var full := RunState.new()
	full.boosts.assign(["mente_abierta", "aire_extra", "reflejos", "ahorro", "ojo_de_hielo", "paso_firme", "pies_de_luz"])
	var bar2 := ItemBar.new()
	layer.add_child(bar2)
	bar2.setup(full, ItemBar.Kind.BOOST, false)
	await process_frame
	bar2.ask_discard(0)
	check(bar2._prompt != null and bar2._prompt.yes_button.disabled, "si no se puede tirar, la pregunta no deja confirmar")
	bar2._prompt.no_button.pressed.emit()
	layer.queue_free()
	await process_frame


func test_casino() -> void:
	var run := RunState.new()
	run.stage = 8
	run.consumables.assign(["freno", "totem"])
	run.boosts.assign(["aire_extra"])
	var c := CasinoScene.new()
	root.add_child(c)
	c.quick = true
	c.setup(run, RandomNumberGenerator.new())
	await process_frame
	var saved := [0]
	c.changed.connect(func(): saved[0] += 1)
	check(c.left_bar.do_discard(0) and run.consumables == ["totem"] and saved[0] == 1, "en el casino también se tiran ítems (y se guarda)")
	check(c.right_bar.do_discard(0) and run.boosts.is_empty() and saved[0] == 2, "boosts también")
	c.free()
