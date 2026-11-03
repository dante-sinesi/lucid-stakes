extends SceneTree
## Captura de la pantalla de fin de la demo y de la de derrota (con la línea de las vidas). Uso: GAME_SANDBOX=1 GAME_DEMO=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_fin_demo.gd -- PREFIJO
const Profile := preload("res://scripts/datos/profile.gd")
const RunState := preload("res://scripts/datos/run_state.gd")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var pref := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "capturas/fin"
	Profile.path = "user://shot_profile_fin.json"
	Profile.reset()
	Profile.mark_tutorial_done()
	var fin = load("res://scripts/ui/demo_end_screen.gd").new()
	root.add_child(fin)
	var run = RunState.new()
	run.stage = 6
	run.max_stage = 6
	run.towers_cleared = 6
	run.claridad_earned = 2480
	run.retries = 2
	run.lives = 2
	run.boosts.assign(["pies_de_oro", "cosecha", "bolsillo_hondo"])
	fin.show_summary(run, true)
	await _frames(90)
	root.get_viewport().get_texture().get_image().save_png("%s_1_fin.png" % pref)
	fin.visible = false
	var lost = load("res://scripts/ui/lost_screen.gd").new()
	root.add_child(lost)
	lost.fast = true
	lost.show_loss("Caíste al vacío", false, 2)
	await _frames(20)
	root.get_viewport().get_texture().get_image().save_png("%s_2_derrota.png" % pref)
	quit()
