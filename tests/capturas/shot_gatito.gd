extends SceneTree
## El gatito travieso en acción: la primera sala de una torre de la prueba, con el gato saltando de bloque en bloque y moviéndolos.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_gatito.gd -- PREFIJO [SEMILLA] [ETAPA]
const Profile := preload("res://scripts/datos/profile.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var pref: String = args[0]
	var semilla := int(args[1]) if args.size() > 1 else 77
	var etapa := int(args[2]) if args.size() > 2 else 1
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
	main.run.trial_schedule = {etapa: "travesuras"}
	main.stage_number = etapa
	main.run.stage = etapa
	main.new_tower(semilla)
	while main.generating or main.torre == null:
		await process_frame
	for c in main.find_children("*", "Control", true, false):
		if "ialog" in str(c.name):
			c.visible = false
	var torre = main.torre
	print("camara: ", torre.cam.size, "  zoom: ", torre.zoom)
	print("gato pendiente: ", not torre.t.gato_pendiente().is_empty(), "  movs: ", torre.t.gato_pendiente().get("mov", []).size())
	for i in 8:
		await create_timer(0.7).timeout
		root.get_texture().get_image().save_png("%s_%d.png" % [pref, i])
	print("actuando: ", torre.gatito_actuando, "  camara: ", torre.cam.size)
	quit(0)
