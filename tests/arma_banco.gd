extends SceneTree
## Arma (o completa) el banco de torres de la demo: genera torres con el generador del juego, comprueba que su camino las gana y las guarda en data/torres_demo.torres.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/arma_banco.gd -- ETAPAS CANTIDAD [SEMILLA_BASE] [ARCHIVO] [escenario]
##      ej.: ... -- 1,2 12 5000        (12 torres por etapa para las etapas 1 y 2; si ya había, se agregan)
## Sólo se agregan las que salen bien; los topes son de trabajo (contadores), no de tiempo.
const Rooms := preload("res://scripts/rooms.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const RunState := preload("res://scripts/run_state.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
const TowerBank := preload("res://scripts/tower_bank.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var stages: PackedStringArray = (args[0] if args.size() > 0 else "1,2").split(",")
	var per_stage := int(args[1]) if args.size() > 1 else 12
	var base := int(args[2]) if args.size() > 2 else 5000
	var file: String = args[3] if args.size() > 3 else TowerBank.PATH
	var scenario: String = args[4] if args.size() > 4 else "pesadilla"
	var bank := TowerBank.read(file)
	for st in stages:
		var stage := int(st)
		var key := TowerBank.key_of(scenario, stage)
		var list: Array = bank.get(key, [])
		var made := 0
		var tries := 0
		var scn := Scenarios.get_scenario(scenario)
		var prof := Gen.profile_for_stage(stage, {}, scn)
		var rows := RunState.rows_for(stage)
		while made < per_stage and tries < per_stage * 3:
			tries += 1
			var seed_value := base + stage * 100003 + (list.size() + tries) * 7919
			var opts := {"tries": 6, "climb": 0.5, "budget_states": 25000, "max_states": 2000}
			opts["pace"] = prof.pace
			opts["combo"] = prof.combo
			opts["bias"] = prof.bias
			opts["scenario"] = prof.get("scenario", "")
			var t0 := Time.get_ticks_msec()
			var res := Rooms.generate_stage(seed_value, rows, prof.difficulty, opts)
			if not res.ok:
				print("etapa %d semilla %d: no salió (%s)" % [stage, seed_value, str(res.get("error", ""))])
				continue
			res["seed_used"] = seed_value
			var rec := TowerBank.encode(res, seed_value)
			if not TowerBank.replay_wins(TowerBank.decode(rec)):
				print("etapa %d semilla %d: el camino no gana la torre restaurada: se descarta" % [stage, seed_value])
				continue
			list.append(rec)
			made += 1
			print("etapa %d: torre %d/%d (semilla %d, %d filas, %d pasos, %d ms)" % [stage, made, per_stage, seed_value, int(res.logic.goal_y), res.path.size(), Time.get_ticks_msec() - t0])
		bank[key] = list
		TowerBank.write(file, bank)   # (se guarda después de cada etapa)
	var total := 0
	for k in bank:
		total += (bank[k] as Array).size()
	print("banco listo: ", total, " torres en ", file)
	quit(0)
