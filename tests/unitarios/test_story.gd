extends SceneTree
## Pruebas del tutorial narrativo: el cuadro de diálogo (escritura letra por letra, avanzar, saltar, íconos), la taberna del inicio
## (el tabernero cuenta la historia y hay que ir a la puerta de atrás), las lecciones en su voz y el cierre en el salón de piedra.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_story.gd

const DialogueBox := preload("res://scripts/ui/dialogue_box.gd")
const Story := preload("res://scripts/datos/story.gd")
const Tutorial := preload("res://scripts/datos/tutorial.gd")
const Room := preload("res://scripts/casino/casino_room.gd")

var fails := 0
var finished_count := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_texts()
	await test_dialogue_box()
	await test_intro_flow()
	await test_lessons_and_outro()
	print("tests de la historia terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func make_main() -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	return main


func wait_tower(main: Node) -> void:
	await process_frame
	while main.generating or main.torre == null:
		await process_frame


func line_text(l) -> String:
	return l if typeof(l) == TYPE_STRING else str(l.text)


func test_texts() -> void:
	var intro: Array = Story.intro()
	var joined := ""
	for l in intro:
		joined += line_text(l) + "\n"
	check(intro.size() >= 3 and joined.contains("pesadilla") and joined.contains("portal de atrás") and joined.contains("claridad"), "la bienvenida cuenta la pesadilla y manda al portal de atras")
	check(joined.find("portal de atrás") > joined.find("pesadilla"), "primero la historia y al final el portal")
	for l in Story.outro():
		var t := line_text(l)
		check(t.length() > 20, "el cierre tiene frases completas")
		check(not t.to_lower().contains("luz"), "el cierre habla de la moneda con el icono, sin nombrarla: %s" % t.substr(0, 30))
	var icons := []
	for l in Story.outro():
		if typeof(l) != TYPE_STRING and l.has("icon"):
			icons.append(l.icon)
	check(icons.has("luz"), "el cierre muestra el sol al hablar de la Luz")
	var outro_text := ""
	for l in Story.outro():
		outro_text += line_text(l).to_lower() + "\n"
	check(outro_text.contains("ruleta") and outro_text.contains("peaje"), "el cierre explica la ruleta y el peaje")
	check(not outro_text.contains("vitrina") and not outro_text.contains("tienda") and not outro_text.contains("habilidad") and not outro_text.contains("prueba"), "el cierre no suelta jerga: vitrina, tienda, habilidades y pruebas se explican cuando aparecen")
	for l in Tutorial.lessons():
		check(Story.lesson_say(l.id) != "", "el tabernero tiene su frase para la leccion %s" % l.id)
	# Todo entra en el cuadro de dialogo (hasta 5 renglones)
	var VFont := preload("res://scripts/ui/voxel_font.gd")
	var too_long := ""
	var every: Array = []
	every.append_array(Story.intro())
	every.append_array(Story.outro())
	for id in Story.LESSONS:
		every.append(Story.LESSONS[id])
	for l in every:
		var has_icon: bool = typeof(l) != TYPE_STRING and l.has("icon")
		if VFont.wrap(line_text(l), DialogueBox.TEXT_CELLS - (80 if has_icon else 0)).size() > 5:
			too_long = line_text(l).substr(0, 40)
	check(too_long == "", "cada frase entra en el cuadro de dialogo (%s)" % too_long)
	check(Room.tier_of(Story.INTRO_STAGE) == 0 and Room.tier_of(Story.OUTRO_STAGE) == 1, "la historia empieza en la taberna y termina en el salon de piedra")


func test_dialogue_box() -> void:
	var box := DialogueBox.new()
	root.add_child(box)
	await process_frame
	finished_count = 0
	box.finished.connect(func(): finished_count += 1)
	box.show_lines(["Hola, soñador.", {"text": "Esto brilla.", "icon": "luz"}, "Chau."], "Tabernero", true)
	check(box.visible and box.is_active() and box.blocking and box.name_label.text == "Tabernero", "el cuadro se muestra con el nombre")
	check(box.text_label.text == "", "al empezar la linea todavia no se escribio nada")
	for i in 6:
		await process_frame
	var partial: String = box.text_label.text
	check(partial.length() > 0 and partial.length() < "Hola, soñador.".length() and "Hola, soñador.".begins_with(partial.replace("\n", "")), "el texto va apareciendo letra por letra (%s)" % partial)
	box.advance()   # todavia escribiendo: muestra la linea entera
	check(box.text_label.text.replace("\n", "") == "Hola, soñador." and not box.is_typing() and box.index == 0, "avanzar mientras escribe completa la linea")
	box.advance()
	check(box.index == 1 and box._icon == "luz", "avanzar pasa a la linea siguiente, con su icono")
	box.advance()
	box.advance()
	check(box.index == 2 and box._icon == "", "la linea sin icono no muestra ninguno")
	box.advance()
	box.advance()
	check(finished_count == 1 and not box.visible and not box.is_active(), "al terminar la ultima linea se emite finished y se oculta")
	# Salto con Esc
	finished_count = 0
	box.show_lines(["Uno.", "Dos.", "Tres."], "Tabernero", true)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	box._unhandled_input(esc)
	check(finished_count == 0 and box.is_active(), "Esc no corta la charla")
	# Enter avanza
	box.show_lines(["Uno.", "Dos."], "Tabernero", true)
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	box._unhandled_input(enter)
	box._unhandled_input(enter)
	check(box.index == 1, "Enter completa la linea y despues avanza")
	# Modo consejo: no bloquea, no avanza con teclas y se queda
	box.show_lines(["Un consejo largo para jugar la leccion."], "Tabernero", false)
	check(not box.blocking and box.mouse_filter == Control.MOUSE_FILTER_IGNORE, "el consejo no tapa el juego ni pide avanzar")
	box._unhandled_input(enter)
	check(box.is_active() and box.index == 0, "el consejo no avanza con Enter")
	box.hide_box()
	check(not box.visible and not box.is_active(), "hide_box lo oculta")
	box.queue_free()
	await process_frame


func test_intro_flow() -> void:
	var main := make_main()
	await wait_tower(main)
	main.start_tutorial()   # empieza en la taberna
	check(main.training and not main.in_menu and main.casino != null and main.casino.story and main.casino.lay.tier == 0 and main.story_kind == "intro", "el tutorial empieza en la taberna")
	check(main.dialogue.blocking and main.dialogue.is_active() and main.dialogue.lines.size() == Story.intro().size() and main.casino.input_locked, "el tabernero habla y mientras tanto no se camina")
	check(not main.hud_layer.visible and not main.casino.hud_layer.visible, "sin interfaz de juego mientras cuenta la historia")
	# mientras habla no se camina
	check(main.casino.step(Vector2i(1, 0)) == "blocked", "no se camina mientras habla")
	# la historia entera (se avanza con Enter) y despues se puede ir a la puerta
	var guard := 0
	while main.dialogue.is_active() and guard < 100:
		main.dialogue.advance()
		guard += 1
	check(not main.dialogue.is_active() and not main.casino.input_locked and main.key_hint.visible and main.casino._arrow == null, "al terminar la historia se puede caminar y aparece la ayuda de WASD (la puerta todavía no se marca)")
	for i in Story.INTRO_PASOS:
		main._on_taberna_movida("mover_adelante")
	check(main.casino._arrow != null and not main.key_hint.visible, "después de unos pasos se marca la puerta de atras y la ayuda se va")
	# la ruleta todavia no se abre
	main.casino.quick = true
	main.casino.cell = Vector2i(2, 4)
	main.casino.facing = Vector2i(0, -1)
	check(main.casino.step(Vector2i(0, -1)) == "blocked" and main.casino.screen == null and main.dialogue.is_active() and not main.dialogue.blocking, "chocar contra la mesa no abre la ruleta: el tabernero avisa")
	check(str(main.dialogue.lines[0]) == Story.BLOCKED_TABLE, "...con la frase del tabernero")
	var t0 := Time.get_ticks_msec()
	while main.dialogue.is_active() and Time.get_ticks_msec() - t0 < 6000:   # (el aviso se va solo: antes se quedaba tapando la pantalla y no se podía seguir)
		await process_frame
	check(not main.dialogue.is_active() and not main.casino.input_locked, "el aviso del tabernero se va solo y se puede seguir caminando")
	# la puerta de atras empieza las lecciones
	main.casino.cell = main.casino.lay.exit
	main.casino.step(Vector2i(0, -1))
	while main.generating or main.torre == null or main.tutorial_index != 0:
		await process_frame
	check(main.casino == null and main.story_kind == "" and main.tutorial_index == 0 and main.hud_layer.visible, "al cruzar la puerta empiezan las lecciones")
	check(main.dialogue.is_active() and main.dialogue.blocking and main.dialogue.any_key and str(main.dialogue.lines[0]) == Story.lesson_say("camara"), "y la primera la explica el tabernero")
	main.queue_free()
	await process_frame
	# Si el cuadro se salta con Esc, igual hay que ir a la puerta
	main = make_main()
	await wait_tower(main)
	main.start_tutorial()
	main.dialogue.skip_all()
	check(not main.casino.input_locked and main.key_hint.visible, "saltear la historia tambien deja caminar y ver las teclas")
	main.open_main_menu()   # volver al menu desde la taberna lo limpia todo
	check(main.in_menu and main.casino == null and not main.dialogue.is_active() and main.story_kind == "" and not main.training, "volver al menu desde la taberna sale del tutorial")
	main.queue_free()
	await process_frame


func test_lessons_and_outro() -> void:
	var main := make_main()
	await wait_tower(main)
	# Cada leccion la dice el tabernero
	for i in Tutorial.count() - 1:
		await main.start_tutorial(i, true)
		check(main.dialogue.is_active() and main.dialogue.blocking and str(main.dialogue.lines[0]) == Story.lesson_say(Tutorial.lessons()[i].id), "la leccion %d la dice el tabernero" % (i + 1))
	# Despues de la ultima, el cierre en el salon de piedra
	await main.start_tutorial(Tutorial.count() - 1, true)
	await main._torre_ganada()
	check(main.story_kind == "outro" and main.casino != null and main.casino.story and main.casino.lay.tier == 1 and main.casino.input_locked, "el cierre es en el salon de piedra")
	check(main.dialogue.blocking and main.dialogue.lines.size() == Story.outro().size(), "con todo lo que el tabernero tiene para explicar")
	var seen_icons := {}
	var guard := 0
	while main.dialogue.is_active() and guard < 100:
		if main.dialogue._icon != "":
			seen_icons[main.dialogue._icon] = true
		main.dialogue.advance()
		guard += 1
	check(seen_icons.has("luz"), "durante el cierre se muestra el sol")
	check(main.story_kind == "outro" and main.casino != null and not main.casino.input_locked and main.casino.toll_base > 0, "al terminar de hablar se camina hasta Farolín, que está junto a la puerta")
	check(main.run.claridad >= main.casino.toll_now() and main.casino.lay.get("farolin_on", false), "el tabernero presta la claridad del peaje de práctica")
	main.casino.ask_toll()
	check(main.dialogue.is_choosing() and main.dialogue._options.size() == 1 and str(main.dialogue._options[0].id) == "pagar", "Farolín ofrece un solo peaje: pagar")
	main.dialogue.confirm_choice()
	await process_frame
	check(main.dialogue.is_active() and main.dialogue.speaker == "Farolín", "Farolín contesta")
	guard = 0
	while main.dialogue.is_active() and guard < 20:
		main.dialogue.advance()
		guard += 1
	check(main.in_menu and main.casino == null and main.tutorial_index == -1 and not main.training, "al terminar el peaje de práctica se vuelve al menu")
	main.queue_free()
	await process_frame
