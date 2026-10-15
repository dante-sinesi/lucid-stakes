extends Node
## Banco de tiempos: genera la torre de una etapa y muestra cuánto tarda. Variables: SEED, STAGE (la cantidad de filas sale de RunState.rows_for).
## Se corre como escena (tests/bench_gen.tscn) para que sirva igual con el motor de editor y con el de lanzamiento.
const Rooms := preload("res://scripts/rooms.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
const RunState := preload("res://scripts/run_state.gd")


func _ready() -> void:
	var seed_v := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 42633
	var stage := int(OS.get_environment("STAGE")) if OS.get_environment("STAGE") != "" else 10
	var prof := Gen.profile_for_stage(stage, {}, Scenarios.get_scenario("pesadilla"))
	var rows := RunState.rows_for(stage)
	var t0 := Time.get_ticks_msec()
	var res: Dictionary = Rooms.generate_stage(seed_v, rows, prof.difficulty, {"pace": prof.pace, "scenario": prof.scenario})
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	var names: Array = []
	if res.ok:
		for r in res.rooms:
			names.append(str(r.idea))
	print("BENCH etapa %d (%d filas) semilla %d: %s en %.1f s, %d intentos | %s | %s" % [stage, rows, seed_v, "ok" if res.ok else "FALLÓ", secs, int(res.get("attempts", 0)), ",".join(names), "debug" if OS.is_debug_build() else "release"])
	get_tree().quit()
