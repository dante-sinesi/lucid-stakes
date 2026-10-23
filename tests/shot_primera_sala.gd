extends SceneTree
## Captura la primera sala de la etapa 1 (¿se entiende qué hay que hacer?). Uso: GAME_SANDBOX=1 godot --path . -s tests/shot_primera_sala.gd -- PREFIJO
const Profile := preload("res://scripts/profile.gd")
func _init() -> void:
	var pref: String = OS.get_cmdline_user_args()[0]
	Profile.path = "user://test_profile.json"
	Profile._loaded_from = ""
	Profile.mark_tutorial_done()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	main.start_game()
	await create_timer(0.5).timeout
	main.dice.auto_start = true
	main.dice.set_ready(true)
	await create_timer(1.5).timeout
	print("sala 1: pasos ", main.nueva.t.salas[0].d.pasos, " pisos ", int(main.nueva.t.salas[0].d.meta) - 1, " max_mov ", main.nueva.t.max_mov())
	root.get_texture().get_image().save_png(pref + "_1.png")
	var cam: Array = main.nueva.t.salas[0].d.camino
	for i in cam.size() - 1:
		main.nueva.accion(Vector3i(int(cam[i][0]), 0, int(cam[i][1])), int(cam[i][2]))
		await create_timer(0.4).timeout
	root.get_texture().get_image().save_png(pref + "_2.png")
	quit(0)
