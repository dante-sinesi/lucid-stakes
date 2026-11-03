extends SceneTree
## Capturas de la torre con la opción de daltonismo prendida (SALIDA.png) y apagada (SALIDA_sin.png): el filtro que lleva los verdes al azul, los símbolos sobre los bloques especiales, el peaje y los movimientos.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_daltonismo.gd -- SALIDA.png
const Profile := preload("res://scripts/datos/profile.gd")
const Settings := preload("res://scripts/datos/settings.gd")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var salida: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "capturas/daltonismo.png"
	Profile.path = "user://shot_profile_dalto.json"
	Profile.reset()
	Profile.mark_tutorial_done()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	await _frames(8)
	main.start_game("pesadilla", "media")
	await _frames(30)
	Settings.headless_io = true
	var m = main.torre.t.motor
	var j: Vector3i = m.jugador
	var letras := ["i", "h", "c", "t", "s", "k"]
	for k in letras.size():
		m.poner(j + Vector3i(1 + k % 3, -1, -1 + k / 3 * 2 - 1 if false else (k / 3) * 2), letras[k])
	main.torre._refrescar()
	main.hud_panel.set_toll(245, false)
	main.hud_panel.set_moves("Movimientos 12/15", true)
	await _frames(40)
	root.get_texture().get_image().save_png(salida.replace(".png", "_sin.png"))
	Settings.set_value("daltonismo", true)
	main.hud_panel.set_toll(245, false)
	await _frames(40)
	root.get_texture().get_image().save_png(salida)
	Settings.set_value("daltonismo", false)
	quit(0)
