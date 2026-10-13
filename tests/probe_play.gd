extends SceneTree
## Juega la solución de una torre dentro del juego de verdad (main.tscn) y mira que gane. Correr con GAME_SANDBOX=1.
## Uso: ... -s tests/probe_play.gd -- escenario etapa semilla
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var scen: String = args[0] if args.size() > 0 else "pesadilla"
	var stage := int(args[1]) if args.size() > 1 else 5
	var sd := int(args[2]) if args.size() > 2 else 3
	var main = load("res://scenes/main.tscn").instantiate()
	main.quit_game_override = true
	root.add_child(main)
	for i in 20: await process_frame
	main.idea_mode = true
	print(main.dev_tower(stage, scen, sd))
	main.idea_mode = false
	var t := 0
	while main.generating and t < 6000:
		await process_frame
		t += 1
	print("generada tras %d cuadros; solución de %d movimientos, caída cada %d" % [t, main.solution.size(), main.logic.collapse_every])
	var ok := true
	var n := 0
	for a in main.solution:
		var res: Dictionary = main.logic.try_action(a.dir, a.mode)
		n += 1
		if not res.ok or main.logic.lost:
			print("FALLA en el movimiento %d: %s" % [n, str(res)])
			ok = false
			break
		if main.logic.won:
			break
	print("ganó: %s en %d movimientos (perdió: %s)" % [str(main.logic.won), n, str(main.logic.lost)])
	quit(0 if ok and main.logic.won else 1)
