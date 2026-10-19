extends SceneTree
## Capturas de la demo (GAME_DEMO=1, GAME_SANDBOX=1): selector de escenarios, personajes y gorros, el diálogo de Farolín en el casino y el fin de la demo.
## Uso: GAME_SANDBOX=1 GAME_DEMO=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/shot_demo.gd -- PREFIJO
const Demo := preload("res://scripts/demo.gd")


func _shot(path: String) -> void:
	for i in 14:
		await process_frame
	root.get_texture().get_image().save_png(path)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "capturas/demo"
	Demo.forced = 1
	var main = load("res://scenes/main.tscn").instantiate()
	main.quit_game_override = true
	main.test_mode = true
	main.quick_portal = true
	main.toll_in_tests = true
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	# 1. el selector de escenarios
	main.open_main_menu()
	main.main_menu.show_panel("escenarios")
	await _shot(prefix + "_escenarios.png")
	# 2. habilidades: el aviso
	main.main_menu.show_panel("principal")
	main.main_menu.buttons["despertar"].pressed.emit()
	await _shot(prefix + "_habilidades.png")
	# 3. personajes y gorros
	main.main_menu.show_panel("cosmeticos")
	main.main_menu.cosmetics.set_tab("gorros")
	main.main_menu.cosmetics.tiles["copa"].hovered.emit()
	await _shot(prefix + "_gorros.png")
	# 4. el casino 2 con Farolín y su diálogo
	main.main_menu.visible = false
	main.in_menu = false
	paused = false
	main.stage_number = 2
	main.run.stage = 2
	main.run.claridad = 200
	main.enter_casino(true)
	for i in 20:
		await process_frame
	main.casino.cell = main.casino.lay.exit
	main.casino.step(Vector2i(0, -1))
	for i in 5:
		await process_frame
	main.dialogue.advance()
	await _shot(prefix + "_farolin.png")
	# 5. el fin de la demo
	main.dialogue.hide_box()
	main.casino.input_locked = false
	main.run.claridad = 100000
	main.run.towers_cleared = 2
	main.run.claridad_earned = 4300
	main._on_dialogue_chosen(-1)
	main._toll_options = main.casino.toll_dialog().options
	main._on_dialogue_chosen(0)
	await _shot(prefix + "_fin.png")
	quit(0)
