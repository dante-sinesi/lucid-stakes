extends SceneTree
## La tienda del casino se alcanza hablando con el tabernero: al terminar de hablar ofrece "Ver la tienda" (o "Nada, gracias", que vuelve a caminar).
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_tienda_tabernero.gd

const SaveGame := preload("res://scripts/datos/save_game.gd")

var fallos := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fallos += 1
		print("FAIL: ", label)


func _init() -> void:
	SaveGame.delete()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	await process_frame
	while main.generating or main.torre == null:
		await process_frame
	await main._torre_ganada()
	check(main.casino != null, "se llegó al casino")
	main.casino.quick = true
	main.dialogue.hide_box()
	main.casino.input_locked = false
	# se habla con el tabernero: cuenta sus cosas...
	main.casino.talk_to_keeper()
	check(main.dialogue.is_active() and main.casino.input_locked, "el tabernero habla y no se camina")
	main.dialogue.skip_all()
	await process_frame
	# ...y ofrece la tienda
	check(main.dialogue.is_choosing(), "al terminar de hablar el tabernero ofrece algo")
	check(main.dialogue._options.size() == 2 and str(main.dialogue._options[0].id) == "tienda", "las opciones son ver la tienda y no querer nada")
	main._on_dialogue_chosen(0)
	check(main.casino.screen != null and main.casino.screen.service_id == "tienda", "elegir 'Ver la tienda' abre la tienda")
	check(main.casino.screen.find_child("tienda", true, false) == null, "y es la pantalla de la tienda sola (sin botón ni pestañas hacia otro lado)")
	main.casino.close_roulette()
	# la tienda sólo se alcanza así: el tablón y el Taller no tienen ningún botón hacia ella
	for id in ["tablon", "taller"]:
		var servicio: Control = main.casino.ServiceScreens.make(id)
		main.casino.add_child(servicio)
		servicio.setup(main.run, RandomNumberGenerator.new(), true)
		check(servicio.find_child("tienda", true, false) == null and not servicio.has_signal("open_shop"), "la pantalla de %s no tiene nada de la tienda" % id)
		servicio.queue_free()
	# "Nada, gracias": se vuelve a caminar
	main.dialogue.hide_box()
	main.casino.talk_to_keeper()
	main.dialogue.skip_all()
	await process_frame
	check(main.dialogue.is_choosing(), "la oferta aparece cada vez que se le habla")
	main._on_dialogue_chosen(1)
	check(main.casino.screen == null and not main.casino.input_locked, "'Nada, gracias' vuelve al casino sin abrir nada")
	main.dialogue.hide_box()
	main.casino.talk_to_keeper()
	main.dialogue.skip_all()
	await process_frame
	main._on_dialogue_chosen(-1)   # (Esc)
	check(main.casino.screen == null and not main.casino.input_locked, "con Esc también se vuelve a caminar")
	main.queue_free()
	await process_frame
	SaveGame.delete()
	print("tests de la tienda del tabernero terminados, fallos: ", fallos)
	quit(1 if fallos > 0 else 0)
