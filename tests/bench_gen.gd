extends SceneTree
## Mide el generador con las opciones del juego (las de main.gd): una etapa, 4 semillas, una tras otra (en el juego corren a la vez y gana la primera).
## Uso: STAGE=8 SIT=1 ROWS=25 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/bench_gen.gd
const Gen := preload("res://scripts/tower_gen.gd")
const GEN_OPTS := {"tries": 6, "climb": 0.5, "budget_states": 25000, "max_states": 2000}

func _init() -> void:
	var stage := int(OS.get_environment("STAGE"))
	var sit := OS.get_environment("SIT") != "0"
	var rows := int(OS.get_environment("ROWS")) if OS.get_environment("ROWS") != "" else 25
	var prof := Gen.profile_for_stage(stage)
	var times: Array = []
	for k in 4:
		var opts := GEN_OPTS.duplicate()
		opts["pace"] = prof.pace
		opts["combo"] = prof.combo
		opts["bias"] = prof.bias
		opts["situations"] = sit
		var t0 := Time.get_ticks_msec()
		var res := Gen.generate_stage(1000 + k * 7919, rows, prof.difficulty, opts)
		var ms := Time.get_ticks_msec() - t0
		times.append(ms)
		var detail := "FALLÓ " + str(res.get("error", "")) if not res.ok else "intentos %d, estados %d, mov/fila %.1f" % [res.attempts, res.states, float(res.path.size()) / rows]
		print("etapa %d situaciones=%s semilla %d: %.1f s  %s" % [stage, str(sit), k, ms / 1000.0, detail])
	times.sort()
	print("RESUMEN etapa %d situaciones=%s: mejor de 4 = %.1f s, mediana = %.1f s, peor = %.1f s" % [stage, str(sit), times[0] / 1000.0, (times[1] + times[2]) / 2000.0, times[3] / 1000.0])
	quit()
