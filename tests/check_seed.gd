extends SceneTree
## Uso: ...console.exe --headless --path . -s tests/check_seed.gd -- SEMILLA FILAS ETAPA
## Genera la torre de esa semilla/etapa como lo hace el juego y reproduce el camino guardado paso a paso.
const Gen := preload("res://scripts/tower_gen.gd")
var GEN_OPTS := {"tries": 6, "climb": 0.5, "budget_states": 25000, "max_states": 2000}

func _init() -> void:
	if OS.get_cmdline_user_args().size() > 3:
		GEN_OPTS["budget_states"] = int(OS.get_cmdline_user_args()[3])
	var a := OS.get_cmdline_user_args()
	var s := int(a[0]); var rows := int(a[1]); var stage := int(a[2])
	var prof := Gen.profile_for_stage(stage)
	var opts := GEN_OPTS.duplicate()
	opts["pace"] = prof.pace; opts["combo"] = prof.combo; opts["bias"] = prof.bias; opts["cancel_token"] = [false]
	var r := Gen.generate_stage(s, rows, prof.difficulty, opts)
	if not r.ok:
		print("etapa %d: NO genera (%s)" % [stage, r.get("error", "")]); quit(1); return
	var lg = r.logic.clone()
	var steps := 0
	var bad := ""
	var names := {Vector3i(1,0,0): "E", Vector3i(-1,0,0): "O", Vector3i(0,0,1): "S", Vector3i(0,0,-1): "N"}
	var out: Array[String] = []
	for act in r.path:
		var res: Dictionary = lg.try_action(act.dir, act.mode)
		steps += 1
		out.append("%s%s" % [["", "g", "h"][act.mode], names.get(act.dir, str(act.dir))])
		if not res.ok or lg.lost:
			bad = "paso %d falla (%s) perdida=%s" % [steps, res.get("msg", ""), lg.lost]
			break
	print("estados ", r.get("states", 0), " ms ", r.get("ms", 0)); print("MODO ", prof.pace, " dificultad ", snappedf(prof.difficulty, 0.01), " N=", r.collapse_every, " intentos=", r.get("attempts", 1))
	print("etapa %d: %d pasos, gana=%s pierde=%s %s" % [stage, steps, lg.won, lg.lost, bad])
	print("filas: ", r.rows, " tipos: ", r.kinds.keys())
	print("camino: ", " ".join(out))
	quit(0 if lg.won and bad == "" else 1)
