extends SceneTree
## Captura de los dados con su botonera (con "Premios") y de la ventana de premios con distintas claridades.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_dados_ventana.gd -- PREFIJO
const Profile := preload("res://scripts/datos/profile.gd")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _foto(nombre: String) -> void:
	await _frames(25)
	root.get_viewport().get_texture().get_image().save_png(nombre)


func _init() -> void:
	var pref := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "capturas/dados"
	Profile.path = "user://shot_profile_dados.json"
	Profile.reset()
	Profile.mark_tutorial_done()
	load("res://scripts/ui/game_help.gd").auto_open = false   # (la ayuda se abre sola la primera vez: aquí no)
	var g = load("res://scripts/casino/dice_game.gd").new()
	root.add_child(g)
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.open(RandomNumberGenerator.new())
	g.set_ready(true)
	g.claridad_actual = 1200
	await _foto("%s_1_dados.png" % pref)
	g.open_prizes()
	await _foto("%s_2_premios_1200.png" % pref)
	g.prizes_window.close_window()
	g.claridad_actual = 40
	g.open_prizes()
	await _foto("%s_3_premios_40.png" % pref)
	quit()
