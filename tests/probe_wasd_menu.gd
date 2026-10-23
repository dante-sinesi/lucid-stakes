extends SceneTree
## Sonda: en los menús las flechas y WASD mueven el foco igual.
const Profile := preload("res://scripts/profile.gd")
func _tecla(code: int) -> void:
	for pr in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code as Key
		ev.physical_keycode = code as Key
		ev.pressed = pr
		Input.parse_input_event(ev)
		await create_timer(0.08).timeout
func _foco(main) -> String:
	var f = main.get_viewport().gui_get_focus_owner()
	return str(f.name) if f != null else "-"
func _init() -> void:
	Profile.path = "user://test_profile.json"
	Profile._loaded_from = ""
	Profile.mark_tutorial_done()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.2).timeout
	var f0 := _foco(main)
	await _tecla(KEY_S)
	var f1 := _foco(main)
	await _tecla(KEY_W)
	var f2 := _foco(main)
	await _tecla(KEY_DOWN)
	var f3 := _foco(main)
	await _tecla(KEY_UP)
	var f4 := _foco(main)
	print("menú: inicio=", f0, " S=", f1, " W=", f2, " abajo=", f3, " arriba=", f4)
	main.main_menu.show_panel("opciones")
	await create_timer(0.5).timeout
	var o0 := _foco(main)
	await _tecla(KEY_D)
	var o1 := _foco(main)
	await _tecla(KEY_A)
	var o2 := _foco(main)
	await _tecla(KEY_RIGHT)
	var o3 := _foco(main)
	await _tecla(KEY_S)
	var o4 := _foco(main)
	print("opciones: inicio=", o0, " D=", o1, " A=", o2, " derecha=", o3, " S=", o4)
	quit(0)
