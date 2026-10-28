extends SceneTree
## La primera sala de una torre con una de las pruebas (a_oscuras, quebradizo, memoria_pez, ventisca...) para ver cómo se ve. Con "pasos N" juega los primeros N movimientos de la solución.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_prueba.gd -- ARCHIVO.png PRUEBA [PASOS] [SEMILLA] [ETAPA]
const Profile := preload("res://scripts/datos/profile.gd")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var prueba: String = args[1]
	var pasos := int(args[2]) if args.size() > 2 else 0
	var semilla := int(args[3]) if args.size() > 3 else 77
	var etapa := int(args[4]) if args.size() > 4 else 1
	Profile.path = "user://shot_profile_prueba.json"
	Profile.reset()
	Profile.mark_tutorial_done()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	root.add_child(main)
	await _frames(6)
	main.start_game("pesadilla", "media")
	await _frames(10)
	while main.generating or main.torre == null:
		await process_frame
	main.run.trial_schedule = {etapa: prueba}
	main.stage_number = etapa
	main.run.stage = etapa
	main.new_tower(semilla)
	await _frames(10)
	while main.generating or main.torre == null:
		await process_frame
	for c in main.find_children("*", "Control", true, false):
		if "ialog" in str(c.name):
			c.visible = false
	var torre = main.torre
	for i in pasos:
		var a: Array = torre.t.sala_actual().d.camino[i]
		torre.accion(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
		await create_timer(0.5).timeout
	await create_timer(0.8).timeout
	root.get_viewport().get_texture().get_image().save_png(args[0])
	quit()
