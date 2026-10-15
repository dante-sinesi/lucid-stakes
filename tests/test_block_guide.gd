extends SceneTree
## La guía de bloques: el catálogo, el descubrimiento (sólo al llegar a la fila del bloque), el cartel del tabernero que frena el juego y la pantalla
## (los bloques sin descubrir sólo dicen "Por descubrir"), accesible desde el menú principal y el de pausa.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_block_guide.gd

const BlockGuide := preload("res://scripts/block_guide.gd")
const BlockGuideScreen := preload("res://scripts/block_guide_screen.gd")
const Profile := preload("res://scripts/profile.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	Profile.path = "user://test_profile.json"
	Profile.reset()
	test_catalog()
	test_reached()
	test_profile()
	test_screen()
	await test_game()
	await test_menus()
	Profile.reset()
	print("tests de la guía de bloques terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_catalog() -> void:
	var ids := {}
	var kinds := {}
	for b in BlockGuide.ALL:
		ids[b.id] = true
		kinds[b.kind] = true
		check(b.name != "" and b.desc != "" and b.say != "", "el bloque %s trae nombre, descripción y lo que dice el tabernero" % b.id)
		check(BlockGuide.for_kind(b.kind).id == b.id and BlockGuide.get_block(b.id).kind == b.kind, "se busca por tipo y por id (%s)" % b.id)
	check(ids.size() == BlockGuide.ALL.size() and kinds.size() == TowerLogic.Kind.size(), "hay un bloque de la guía por cada tipo del juego (%d)" % kinds.size())


## Se descubre al llegar a la altura de la fila: un bloque más alto que el jugador no cuenta.
func test_reached() -> void:
	Profile.reset()
	var t := TowerLogic.new()
	t.size = Vector2i(4, 4)
	t.add_block(Vector3i(0, 0, 0))
	t.add_block(Vector3i(1, 0, 0), false, TowerLogic.Kind.ICE)
	t.add_block(Vector3i(2, 3, 0), false, TowerLogic.Kind.BOMB)
	t.player = Vector3i(0, 1, 0)
	var found := BlockGuide.newly_reached(t)
	var ids := []
	for b in found:
		ids.append(b.id)
	check(ids == ["normal", "hielo"], "parado en la primera fila se descubren los bloques de esa fila, no los de arriba (%s)" % str(ids))
	t.player = Vector3i(0, 3, 0)
	check(BlockGuide.newly_reached(t).size() == 2, "a la altura del bloque (pero no por encima) todavía no cuenta")
	t.player = Vector3i(0, 4, 0)
	var ids2 := []
	for b in BlockGuide.newly_reached(t):
		ids2.append(b.id)
	check(ids2 == ["normal", "hielo", "bomba"], "al estar por encima de la fila de la bomba, se descubre (%s)" % str(ids2))
	Profile.discover_block("normal")
	check(BlockGuide.newly_reached(t).size() == 2, "lo ya descubierto no vuelve a salir")
	Profile.reset()


func test_profile() -> void:
	Profile.reset()
	check(not Profile.has_block("hielo") and BlockGuide.count_discovered() == 0, "al principio no hay nada descubierto")
	check(Profile.discover_block("hielo") and Profile.has_block("hielo"), "descubrir un bloque lo anota")
	check(not Profile.discover_block("hielo"), "descubrirlo otra vez no es novedad")
	Profile._loaded_from = ""   # (se vuelve a leer el archivo)
	check(Profile.has_block("hielo") and BlockGuide.count_discovered() == 1, "se guarda en el perfil")
	Profile.reset()


func test_screen() -> void:
	Profile.reset()
	var s: Control = BlockGuideScreen.new()
	root.add_child(s)
	s.refresh()
	var all_hidden := true
	for b in BlockGuide.ALL:
		var r: Dictionary = s.rows[b.id]
		all_hidden = all_hidden and str(r.name.text) == "Por descubrir" and str(r.desc.text) == "" and not r.icon.discovered
		check(not str(r.name.text).contains(str(b.name)) and not str(r.desc.text).contains(str(b.name)), "el bloque %s sin descubrir no dice su nombre" % b.id)
	check(all_hidden, "sin descubrir: todos dicen sólo «Por descubrir», sin descripción y en gris")
	Profile.discover_block("hielo")
	s.refresh()
	check(s.rows.hielo.name.text == "Hielo" and str(s.rows.hielo.desc.text).contains("resbalar") and s.rows.hielo.icon.discovered, "el descubierto muestra su nombre y descripción, a color")
	check(s.rows.bomba.name.text == "Por descubrir" and s.rows.bomba.desc.text == "", "los demás siguen sin decir nada")
	check(str(s.count_label.text).contains("1") and str(s.count_label.text).contains(str(BlockGuide.ALL.size())), "dice cuántos van descubiertos")
	s.queue_free()
	Profile.reset()


func make_main() -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	return main


## En el juego: al llegar a una fila nueva el tabernero explica el bloque y frena al jugador; después puede seguir.
func test_game() -> void:
	Profile.reset()
	var main := make_main()
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	main.block_discovery = true
	main.dialogue.hide_box()
	main._check_discoveries()
	check(main.dialogue.is_active() and main.dialogue.blocking and Profile.has_block("normal"), "al llegar a la primera fila, el tabernero explica el bloque común (y se anota)")
	check(str(main.dialogue.lines[0]) == BlockGuide.get_block("normal").say, "con lo que dice de ese bloque")
	main.dialogue.skip_all()
	main._check_discoveries()
	check(not main.dialogue.is_active(), "después puede seguir: lo conocido no vuelve a salir")
	# un tipo nuevo a la altura del jugador
	var logic = main.logic
	logic.add_block(Vector3i(0, logic.player.y - 1, 2), false, TowerLogic.Kind.TRAP)
	main._check_discoveries()
	var said_trap: bool = main.dialogue.is_active() and main.dialogue.lines.has(BlockGuide.get_block("trampa").say)
	for _i in 8:   # (la torre generada puede traer otros tipos nuevos debajo: se van explicando de a uno)
		if said_trap:
			break
		main.dialogue.skip_all()
		main._check_discoveries()
		said_trap = main.dialogue.is_active() and main.dialogue.lines.has(BlockGuide.get_block("trampa").say)
	check(said_trap and Profile.has_block("trampa"), "una trampa en la fila alcanzada se explica")
	main.dialogue.skip_all()
	main.training = true
	logic.add_block(Vector3i(1, logic.player.y - 1, 2), false, TowerLogic.Kind.SPIKES)
	main._check_discoveries()
	check(not main.dialogue.is_active() and not Profile.has_block("pinchos"), "en el tutorial no se descubre nada")
	main.training = false
	main._cancel_jobs()
	main.queue_free()
	await process_frame
	Profile.reset()


func test_menus() -> void:
	var main := make_main()
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	check(main.main_menu.buttons.has("guia") and main.main_menu.guide != null, "el menú principal tiene la guía de bloques")
	main.main_menu.open()
	main.main_menu.buttons["guia"].pressed.emit()
	check(main.main_menu.guide.visible and not main.main_menu.main_center.visible, "el botón abre la guía")
	main.main_menu.guide.back.emit()
	check(main.main_menu.main_center.visible and not main.main_menu.guide.visible, "Volver regresa al menú")
	check(main.pause_menu.buttons.has("guia"), "el menú de pausa tiene la guía de bloques")
	main.pause_menu.open()
	main.pause_menu.buttons["guia"].pressed.emit()
	check(main.pause_menu.guide.visible and not main.pause_menu.center.visible, "en la pausa el botón abre la guía")
	main.pause_menu.guide.back.emit()
	check(not main.pause_menu.guide.visible and main.pause_menu.center.visible, "y Volver regresa a la pausa")
	main.pause_menu.close()
	main._cancel_jobs()
	main.queue_free()
	await process_frame
