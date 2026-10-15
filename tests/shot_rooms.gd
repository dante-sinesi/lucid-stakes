extends SceneTree
## Captura de una torre por salas: repite la solución de a tramos y saca una foto de cada uno. Correr con GAME_SANDBOX=1.
## Uso: ... --rendering-driver opengl3 --resolution 1280x720 -s tests/shot_rooms.gd -- SALIDA [etapa] [semilla] [escenario] [pasos...]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var main = load("res://scenes/main.tscn").instantiate()
	main.quit_game_override = true
	root.add_child(main)
	for i in 20: await process_frame
	var stage := int(args[1]) if args.size() > 1 else 5
	var sd := int(args[2]) if args.size() > 2 else 3
	var scen: String = args[3] if args.size() > 3 else "pesadilla"
	main.idea_mode = true
	main.dev_tower(stage, scen, sd)
	main.idea_mode = false
	var t := 0
	while main.generating and t < 40000:
		await process_frame
		t += 1
	for i in 30: await process_frame
	main.zoom_view(0.5)
	var steps: Array = []
	for i in range(4, args.size()):
		steps.append(int(args[i]))
	if steps.is_empty():
		steps = [0, 12, 30, 50, 70]
	var done := 0
	var sol: Array = main.solution
	for n in steps:
		while done < n and done < sol.size():
			var a: Dictionary = sol[done]
			main.logic.try_action(a.dir, a.mode)
			done += 1
		main._refresh()
		for i in 25: await process_frame
		root.get_texture().get_image().save_png("%s_%d.png" % [args[0], n])
	quit()
