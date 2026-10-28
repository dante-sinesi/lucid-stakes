extends SceneTree
## El casino torcido (los carteles de CERRADO sobre las mesas que no se pueden usar) o el peaje por adelantado (solo: "adelanto"), con el diálogo del anuncio. Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_casino_evento.gd -- ARCHIVO.png [ETAPA] [solo: ruleta|tragamonedas|blackjack]
const Profile := preload("res://scripts/datos/profile.gd")
const Eventos := preload("res://scripts/casino/casino_eventos.gd")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var etapa := int(args[1]) if args.size() > 1 else 13
	var solo: String = args[2] if args.size() > 2 else "ruleta"
	Profile.path = "user://shot_profile_evento.json"
	Profile.reset()
	Profile.mark_tutorial_done()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	await _frames(6)
	main.start_game("pesadilla", "media")
	await _frames(20)
	main.stage_number = etapa
	main.run.stage = etapa
	main.run.casino_evento = {"stage": etapa, "id": "", "solo": ""}   # (sin evento sorteado: el que se ve es el que se pone abajo)
	main.enter_casino()
	await _frames(20)
	var ev: Dictionary
	var cobrado := 0
	if solo == "adelanto":
		main.run.claridad = 300
		ev = {"stage": etapa, "id": "peaje_adelantado", "solo": "", "nuevo": true}
		cobrado = Eventos.aplicar_entrada(main.run, ev, main.run.toll_after_discounts(main.casino.toll_base if main.casino.toll_base > 0 else 80))
	else:
		ev = {"stage": etapa, "id": "torcido", "solo": solo, "nuevo": true}
	main.run.casino_evento = ev.duplicate()
	main.casino.poner_evento(ev)
	main.casino._refresh_hud()
	var a := Eventos.anuncio(ev, cobrado, "Tabernero", "Farolín")
	main.dialogue.show_lines(a.lines, str(a.speaker), true)
	await _frames(60)
	root.get_viewport().get_texture().get_image().save_png(args[0])
	quit()
