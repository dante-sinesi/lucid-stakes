extends SceneTree
## El banco de torres de la demo (tower_bank.gd, data/torres_demo.torres): cada torre se gana con su camino, no hay repetidas, cada etapa de la demo tiene al menos 12 y el juego
## las usa al instante (sin generar).
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_banco.gd

const TowerBank := preload("res://scripts/tower_bank.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	TowerBank.path = TowerBank.PATH
	TowerBank.reload()
	test_contents()
	test_roundtrip()
	await test_game()
	print("tests del banco de torres terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_contents() -> void:
	for stage in [1, 2]:
		var n := TowerBank.count("pesadilla", stage)
		check(n >= 12, "la etapa %d tiene al menos 12 torres en el banco (%d)" % [stage, n])
		var seeds := {}
		var hashes := {}
		var bad := 0
		for i in n:
			var res := TowerBank.pick("pesadilla", stage, i)
			check(res.ok and res.logic != null and res.path.size() > 20 and res.logic.goal_y > 40, "etapa %d torre %d: es una torre alta con su camino" % [stage, i])
			if not TowerBank.replay_wins(res):
				bad += 1
			seeds[res.seed_used] = true
			hashes[str(res.logic.blocks.keys().size()) + ":" + str(res.path.size()) + ":" + str(res.logic.goal_cell)] = true
		check(bad == 0, "etapa %d: todas las torres se ganan con su camino (%d fallan)" % [stage, bad])
		check(seeds.size() == n and hashes.size() == n, "etapa %d: no hay torres repetidas (%d semillas, %d formas de %d)" % [stage, seeds.size(), hashes.size(), n])
	check(not TowerBank.has("pesadilla", 5) and TowerBank.pick("pesadilla", 5, 0).is_empty(), "las etapas que no están en el banco se generan como siempre")
	check(TowerBank.pick("pesadilla", 1, 3).seed_used == TowerBank.pick("pesadilla", 1, 3 + TowerBank.count("pesadilla", 1)).seed_used, "la elección es determinista (módulo la cantidad)")


func test_roundtrip() -> void:
	var res := TowerBank.pick("pesadilla", 1, 0)
	var rec := TowerBank.encode(res, res.seed_used)
	var back := TowerBank.decode(rec)
	check(back.logic.blocks == res.logic.blocks and back.logic.kind_of == res.logic.kind_of and back.logic.goal_cell == res.logic.goal_cell and back.logic.player == res.logic.player, "codificar y decodificar deja la misma torre")
	check(back.logic.collapse_every == res.logic.collapse_every and back.path == res.path, "y el mismo ritmo y camino")
	var tmp := "user://test_banco.torres"
	check(TowerBank.write(tmp, {"x|1": [rec]}) and TowerBank.read(tmp).has("x|1"), "el archivo se escribe y se lee (comprimido)")
	DirAccess.remove_absolute(tmp)


func test_game() -> void:
	TowerBank.forced = 1
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:   # (la que se generó al abrir, de otra etapa)
		await process_frame
	main._cancel_jobs()
	main.generating = false
	main.stage_number = 1
	main.run.stage = 1
	var t0 := Time.get_ticks_msec()
	main.new_tower(77)
	while main.generating:
		await process_frame
	var ms := Time.get_ticks_msec() - t0
	check(ms < 3000, "la torre de la etapa 1 sale del banco al instante (%d ms)" % ms)
	check(TowerBank.count("pesadilla", 1) > 0 and main.stage_start.goal_y > 40 and not main.solution.is_empty(), "el juego tiene su torre y su camino")
	var bank_seeds := {}
	for i in TowerBank.count("pesadilla", 1):
		bank_seeds[TowerBank.pick("pesadilla", 1, i).seed_used] = true
	check(bank_seeds.has(main.seed_value), "la torre es una del banco (semilla %d)" % main.seed_value)
	var s2 = main.stage_start.clone()
	var won := false
	for a in main.solution:
		s2.try_action(a.dir, a.mode)
		if s2.won:
			won = true
			break
	check(won, "se gana con el camino que trae")
	main._cancel_jobs()
	main.queue_free()
	await process_frame
	TowerBank.forced = -1
