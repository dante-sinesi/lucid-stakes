extends SceneTree
## La pantalla del tablón con contratos ya aceptados (se pueden elegir y cancelar). Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_tablon_activos.gd -- PREFIJO
const CasinoScene := preload("res://scripts/casino/casino_scene.gd")
const Contratos := preload("res://scripts/datos/contratos.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Profile := preload("res://scripts/datos/profile.gd")


func _init() -> void:
	var pref: String = OS.get_cmdline_user_args()[0]
	Profile.path = "user://test_profile_tablon.json"
	Profile.reset()
	var run := RunState.new()
	run.stage = 9
	run.claridad = 5000
	var sc := CasinoScene.new()
	root.add_child(sc)
	sc.setup(run, RandomNumberGenerator.new())
	await process_frame
	sc.cell = sc.lay.tablon + Vector2i(1, 0)
	sc.facing = Vector2i(-1, 0)
	sc.interact()
	await process_frame
	for i in 5:
		await process_frame
	var esc := InputEventKey.new()   # (la ayuda del tablón se abre sola la primera vez: se cierra con Esc)
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	for i in 5:
		await process_frame
	var s = sc.screen
	s.toggle_fianza()
	s.accept()
	s.select(1)
	s.toggle_fianza()
	s.accept()
	s.select(Contratos.cartelera(run).size() + 1)
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png(pref + "_tablon_activos.png")
	quit(0)
