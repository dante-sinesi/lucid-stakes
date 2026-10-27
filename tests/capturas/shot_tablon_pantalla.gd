extends SceneTree
## Captura la pantalla del tablón de contratos y la sala con los papeles colgados. Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1500x1000 -s tests/capturas/shot_tablon_pantalla.gd -- PREFIJO [etapa]
const CasinoScene := preload("res://scripts/casino/casino_scene.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Profile := preload("res://scripts/datos/profile.gd")
const GameHelp := preload("res://scripts/ui/game_help.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	Profile.path = "user://test_profile.json"
	Profile._loaded_from = ""
	Profile.mark_tutorial_done()
	GameHelp.auto_open = false   # (que la ayuda no se abra sola y tape la pantalla)
	var run := RunState.new()
	run.stage = int(args[1]) if args.size() > 1 else 9
	run.claridad = 800
	var sc := CasinoScene.new()
	root.add_child(sc)
	sc.quick = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	sc.setup(run, rng)
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png("%s_sala.png" % args[0])
	sc.open_tablon()
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png("%s_pantalla.png" % args[0])
	quit(0)
