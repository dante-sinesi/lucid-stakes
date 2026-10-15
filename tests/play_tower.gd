extends SceneTree
## Juega de punta a punta la solución de una sala reja dentro del juego (con animaciones) y saca fotos cada tanto. Correr con GAME_SANDBOX=1.
## Uso: ... --rendering-driver opengl3 --resolution 1280x720 -s tests/_play_reja.gd -- SALIDA [semilla] [dificultad] [cada_n_pasos] [filas]
const Rooms := preload("res://scripts/rooms.gd")


func _init() -> void:
	if OS.get_environment("IDEA") != "mix":
		OS.set_environment("IDEA_ONLY", OS.get_environment("IDEA") if OS.get_environment("IDEA") != "" else "reja")
		OS.set_environment("NO_FALLBACK", "1")
	var args := OS.get_cmdline_user_args()
	var sd := int(args[1]) if args.size() > 1 else 0
	var d := float(args[2]) if args.size() > 2 else 0.6
	var every := int(args[3]) if args.size() > 3 else 10
	var rows := int(args[4]) if args.size() > 4 else 5
	var res: Dictionary = Rooms.generate_stage(1000 + sd, rows, d, {"pace": "normal", "scenario": "pesadilla"})
	if not res.ok:
		print("no se generó")
		quit()
		return
	OS.set_environment("IDEA_ONLY", "")   # (el juego genera sus torres con las reglas de siempre)
	OS.set_environment("NO_FALLBACK", "")
	var main = load("res://scenes/main.tscn").instantiate()
	main.quit_game_override = true
	main.quick_portal = true
	main.test_mode = true
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	main.in_menu = false
	paused = false
	main.main_menu.visible = false
	main.trial = {}
	main.stage_number = 4
	main.stage_start = res.logic
	main.solution = res.path
	main.restart()
	main.hud_layer.visible = false
	main.dialogue.hide_box()
	main.banner.text = ""
	for i in 30: await process_frame
	main.zoom_view(0.6)
	main._cancel_jobs()
	main.generating = false
	print("antes: generating=%s busy=%s won=%s lost=%s" % [str(main.generating), str(main.busy), str(main.logic.won), str(main.logic.lost)])
	var n := 0
	for a in main.solution:
		main.generating = false
		main._apply(a.dir, a.mode, true)   # (el solucionador suelta con la dirección contraria: en el juego es Espacio)
		var guard := 0
		while main.busy and guard < 600:
			await process_frame
			guard += 1
		n += 1
		if n <= 3:
			print("paso %d: guard=%d busy=%s moves=%d jugador=%s tween=%s" % [n, guard, str(main.busy), main.logic.moves_made, str(main.logic.player), str(main.anim_tween != null and main.anim_tween.is_valid())])
		if n % every == 0 or n == 1:
			for i in 6: await process_frame
			root.get_texture().get_image().save_png("%s_%03d.png" % [args[0], n])
		if main.logic.lost:
			print("PERDIÓ en el paso %d: %s" % [n, main.logic.lost_reason])
			break
	for i in 10: await process_frame
	root.get_texture().get_image().save_png("%s_fin.png" % args[0])
	print("jugador %s meta %s altura meta %d moves %d piso %d colapso %d/%d toll %d" % [str(main.logic.player), str(main.logic.goal_cell), main.logic.goal_y, main.logic.moves_made, main.logic.floor_y, main.logic.moves_to_collapse, main.logic.collapse_every, main.logic.toll])
	print("resultado: ganó=%s perdió=%s pasos=%d de %d" % [str(main.logic.won), str(main.logic.lost), n, main.solution.size()])
	quit()
