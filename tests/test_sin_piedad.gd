extends SceneTree
## "Sin piedad" dentro del juego: el escenario arma el medidor con las salas de la torre, el indicador muestra los falsos que quedan, el camino perfecto no gasta ninguno,
## un movimiento que aleja gasta uno y al agotarlos se pierde (la torre se pierde como al morir: cuesta una vida al reintentar). No se puede deshacer.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_sin_piedad.gd

const Profile := preload("res://scripts/profile.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const Solver := preload("res://scripts/solver.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	Profile.path = "user://test_profile.json"
	Profile.reset()
	SaveGame.path = "user://test_save.json"
	await test_flow()
	Profile.reset()
	print("tests de Sin piedad terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func _wait_idle(main: Node) -> void:
	var frames := 0
	while main.busy and frames < 600:
		await process_frame
		frames += 1


func test_flow() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	Profile.add_luz(100)
	main.start_game("sin_piedad")
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	check(main.run.scenario_id == "sin_piedad" and int(main.run.scenario().mistakes) == 2, "se empezó una partida de Sin piedad")
	if main.room_segments.is_empty():
		print("(la torre de prueba no es de la biblioteca: no tiene salas para medir; se salta el resto)")
		main._cancel_jobs()
		main.queue_free()
		await process_frame
		return
	check(main.false_moves.active and main.false_moves.allowed == 2, "el medidor está activo con 2 falsos")
	check(main.hud_panel.mistakes.visible and main.hud_panel.mistakes.left == 2 and main.hud_panel.mistakes.total == 2, "el indicador muestra 2 cubitos")
	# el camino perfecto no gasta falsos
	# (el camino guardado de la torre es UNA solución, no siempre la más corta de cada sala: se juega el camino más corto de la sala, medido con el mismo solucionador)
	var fm = main.false_moves
	var room0: int = fm.room_of(main.logic.player.y)
	var target0: int = int(fm.rooms[room0].ey) + int(fm.rooms[room0].h) if room0 + 1 < fm.rooms.size() else main.logic.goal_y
	var best: Dictionary = Solver.solve(fm._trim(main.logic, int(fm.rooms[room0].ey), target0), target0, {"admissible": true, "max_states": 200000})
	check(best.status == "solved", "se puede medir la sala (camino más corto)")
	var steps := mini(best.path.size(), 12) if best.status == "solved" else 0
	for i in steps:
		var a: Dictionary = best.path[i]
		main._apply(a.dir, a.mode)
		await _wait_idle(main)
	var frames := 0
	while frames < 120:   # (las mediciones llegan unos instantes después)
		await process_frame
		frames += 1
	check(int(main.false_moves.counts.get(main.false_moves.room_of(main.logic.player.y), 0)) == 0 and not main.logic.lost, "los primeros pasos del camino más corto de la sala no gastan ningún falso")
	# no se puede deshacer
	var before: int = main.logic.moves_made
	main.undo_move()
	check(main.logic.moves_made == before, "no se puede deshacer en este escenario")
	# un movimiento que aleja gasta un falso y se agota al tercero (se fuerza el estado del medidor para no depender de la sala)
	var room: int = main.false_moves.room_of(main.logic.player.y)
	main.false_moves.counts[room] = 2
	main.hud_panel.set_mistakes(0, 2)
	main._on_mistake(3, 2, room, false)
	main._on_mistakes_exhausted(room)
	frames = 0
	while not main.logic.lost and frames < 200:
		await process_frame
		frames += 1
	check(main.logic.lost and main.logic.lost_reason == "Tercer movimiento en falso", "al agotarse los falsos se pierde la torre (como al morir)")
	main._cancel_jobs()
	main.queue_free()
	await process_frame
