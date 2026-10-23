extends SceneTree
## Sonda: en la pantalla de derrota, Espacio reintenta y Shift vuelve al menú principal (con el juego real, sin atajos de prueba).
const Profile := preload("res://scripts/profile.gd")
func _tecla(code: int) -> void:
	for pr in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code as Key
		ev.physical_keycode = code as Key
		ev.pressed = pr
		Input.parse_input_event(ev)
		await create_timer(0.08).timeout
func _morir(main) -> void:
	var cam: Array = main.nueva.t.salas[0].d.camino
	main.nueva.t.movs = main.nueva.t.max_mov() - 1
	main.nueva.accion(Vector3i(int(cam[0][0]), 0, int(cam[0][1])), int(cam[0][2]))
func _init() -> void:
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
	_morir(main)
	await _tecla(KEY_SPACE)   # (durante la caída no debe hacer nada)
	print("durante la caída: muerta=", main.nueva.t.muerta, " menú=", main.in_menu)
	await create_timer(4.0).timeout
	var vidas0: int = main.run.lives
	print("lost visible=", main.lost_screen.visible, " alpha=", main.lost_screen.box.modulate.a, " hints visible=", main.lost_screen.hints.is_visible_in_tree(), " items=", main.lost_screen.hints.items.size())
	await _tecla(KEY_SPACE)
	await create_timer(0.3).timeout
	print("Espacio: muerta=", main.nueva.t.muerta, " vidas ", vidas0, "->", main.run.lives)
	_morir(main)
	await create_timer(4.0).timeout
	await _tecla(KEY_SHIFT)
	await create_timer(0.3).timeout
	print("Shift: en menú=", main.in_menu)
	quit(0)
