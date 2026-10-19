extends SceneTree
## Captura la ruleta, las tragamonedas y el blackjack con la barra de botones del mando. Correr con GAME_SANDBOX=1.
## Uso: ... --rendering-driver opengl3 --resolution 1280x720 -s tests/shot_juegos_mando.gd -- SALIDA
const Controls := preload("res://scripts/controls.gd")
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var pad := OS.get_cmdline_user_args().size() < 2   # con un segundo argumento se captura con teclado
	Controls.using_pad = pad
	var run := preload("res://scripts/run_state.gd").new()
	run.claridad = 600
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var i := 0
	for path in ["roulette_screen", "slots_screen", "blackjack_screen"]:
		var s = load("res://scripts/%s.gd" % path).new()
		root.add_child(s)
		s.setup(run, rng, false)
		for f in 40:
			await process_frame
		root.get_texture().get_image().save_png("%s_%d.png" % [out, i])
		s.queue_free()
		await process_frame
		i += 1
	quit()
