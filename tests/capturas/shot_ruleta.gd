extends SceneTree
## Captura de la ruleta de premios: la rueda quieta, el resultado de un giro (épico y común) y la ventana de premios. Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_ruleta.gd -- PREFIJO [ETAPA]
const Profile := preload("res://scripts/datos/profile.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Showcase := preload("res://scripts/casino/showcase.gd")
const Roulette := preload("res://scripts/casino/roulette.gd")
const RouletteScreen := preload("res://scripts/casino/roulette_screen.gd")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _foto(nombre: String) -> void:
	await _frames(20)
	root.get_viewport().get_texture().get_image().save_png(nombre)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var pref: String = args[0] if args.size() > 0 else "capturas/ruleta"
	var etapa := int(args[1]) if args.size() > 1 else 6
	Profile.path = "user://shot_profile_ruleta.json"
	Profile.reset()
	Profile.mark_tutorial_done()
	var run := RunState.new()
	run.stage = etapa
	run.claridad = 2000
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	Showcase.generate(run, rng)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var s = RouletteScreen.new()
	layer.add_child(s)
	s.setup(run, rng, true)
	s.fast = false
	await _foto("%s_1_rueda.png" % pref)
	s.fast = true
	s.forced_pocket = 0   # la casilla épica
	s.spin()
	await _frames(40)
	await _foto("%s_2_epico.png" % pref)
	s.forced_pocket = 2   # una común
	s.spin()
	await _frames(40)
	await _foto("%s_3_comun.png" % pref)
	s.forced_pocket = 1   # una bolsa
	s.spin()
	await _frames(40)
	await _foto("%s_4_bolsa.png" % pref)
	s.open_prizes()
	await _foto("%s_5_premios.png" % pref)
	quit()
