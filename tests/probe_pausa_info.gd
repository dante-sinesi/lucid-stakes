extends SceneTree
const Profile := preload("res://scripts/profile.gd")
func _init() -> void:
	Profile.path = "user://test_profile.json"   # (el perfil de pruebas, nunca el real)
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
	print("story=", main.casino.story if main.casino != null else "-", " tutorial_forced=", main.tutorial_forced, " tidx=", main.tutorial_index)
	for i in 1:
		print("t=", i, " casino=", main.casino != null, " nueva=", main.nueva != null, " generating=", main.generating, " dice=", main.dice.visible, " puede=", main.nueva.puede_jugar.call() if main.nueva != null else "-")
		await create_timer(1.0).timeout
	print("info_pausa ", main._info_pausa, " nueva ", main.nueva != null, " casino ", main.casino != null)
	main.pause_game()
	await create_timer(0.5).timeout
	var inf = main.pause_menu.info
	print("info visible ", inf.visible, " hijos ", inf.get_child_count(), " pos ", inf.position, " size ", inf.size, " global ", inf.global_position)
	for c in inf.get_children():
		print(c.name, " ", c.text, " ", c.size, " ", c.visible)
	quit(0)
