extends SceneTree
## Captura el juego con el fondo y la luz de varias etapas (para revisar que los bloques se lean). Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_fondo.gd -- PREFIJO
const Profile := preload("res://scripts/datos/profile.gd")
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var pref: String = args[0]
	Profile.path = "user://test_profile_shot.json"
	Profile.reset()
	Profile.mark_tutorial_done()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	main.start_game("pesadilla", "media")
	await create_timer(0.5).timeout
	main.dice.auto_start = true
	main.dice.set_ready(true)
	await create_timer(1.5).timeout
	var cam: Array = main.torre.t.salas[0].d.camino
	for i in mini(9, cam.size() - 1):
		main.torre.accion(Vector3i(int(cam[i][0]), 0, int(cam[i][1])), int(cam[i][2]))
	main.dialogue.hide_box()
	await create_timer(1.0).timeout
	for etapa in [1, 5, 9, 13]:
		main.stage_number = etapa
		main._apply_stage_look()
		await create_timer(0.4).timeout
		root.get_texture().get_image().save_png("%s_etapa%d.png" % [pref, etapa])
	quit(0)
