extends SceneTree
## EXPERIMENTO del cilindro al revés (scripts/cilindro_gen.gd, `scramble`): desordena una masa resuelta, busca una solución con el A* (con peso: rápido pero no siempre la más corta) y mide empujes, empujes por piso y bloques distintos movidos.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/probe_cilindro_rev.gd -- [SALAS=6] [SEMILLA=1] [PASOS=120] [ALTURAS=6,7] [MS_TOTAL=420000] [PESO=2.5]
const RoomLib := preload("res://scripts/room_lib.gd")
const Pack := preload("res://scripts/room_pack.gd")
const Gen := preload("res://scripts/cilindro_gen.gd")
const Conv := preload("res://scripts/convoy_gen.gd")
const Solver := preload("res://scripts/solver.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var want := int(args[0]) if args.size() > 0 else 6
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args[1]) if args.size() > 1 else 1
	var steps := int(args[2]) if args.size() > 2 else 120
	var hs: Array = []
	for t in (args[3] if args.size() > 3 else "6,7").split(","):
		hs.append(int(t))
	var budget := int(args[4]) if args.size() > 4 else 420000
	var weight := float(args[5]) if args.size() > 5 else 2.5
	var t0 := Time.get_ticks_msec()
	var solved: Array = []
	var tried := 0
	var unsolved := 0
	while solved.size() < want and Time.get_ticks_msec() - t0 < budget and tried < want * 4:
		tried += 1
		var h: int = hs[tried % hs.size()]
		var t1 := Time.get_ticks_msec()
		var room := Gen.scramble(rng, h, steps)
		if room.is_empty() or RoomLib.validate_structure(room) != "":
			print("(intento %d: la masa no sirve)" % tried)
			continue
		var sc_steps := int(room.opt.scramble_steps)
		var sc_pushes := int(room.opt.scramble_pushes)
		var ver := RoomLib.verify_exact(room, 500000, 10000)
		var res: Dictionary = {"status": "solved" if ver.proof == "exacta" else str(ver.proof), "path": ver.path, "moves": ver.moves, "states": ver.states}
		if res.status != "solved":
			unsolved += 1
			print("intento %d (h=%d): sin solución hallada (%s) tras %d estados, desorden %d pasos (%d empujes) en %.0f s" % [tried, h, str(res.status), int(res.states), sc_steps, sc_pushes, float(Time.get_ticks_msec() - t1) / 1000.0])
			continue
		room["path"] = res.path
		RoomLib.apply_result(room, res.path, "exacta", int(res.moves), int(res.states))
		room.opt["scramble_steps"] = sc_steps
		room.opt["scramble_pushes"] = sc_pushes
		var m := Conv.metrics(room)
		for k in m:
			room.opt[k] = m[k]
		room.opt["grabs_por_piso"] = float(room.opt.grabs) / float(h)
		solved.append(room)
		print("intento %d (h=%d): resuelta en %d pasos, %d empujes (%.2f por piso), %d bloques distintos, %d cambios; desorden %d pasos (%d empujes) · %.0f s" % [tried, h, int(res.moves), int(room.opt.grabs), float(room.opt.grabs_por_piso), int(m.blocks), int(m.switches), int(room.opt.scramble_steps), int(room.opt.scramble_pushes), float(Time.get_ticks_msec() - t1) / 1000.0])
	if not solved.is_empty():
		var best: Dictionary = solved[0]
		for r in solved:
			if float(r.opt.grabs) > float(best.opt.grabs):
				best = r
		print("\nla de más empujes (h=%d, %d empujes):" % [int(best.h), int(best.opt.grabs)])
		print(Gen.top_view(best))
		print("camino " + RoomLib.path_string(best.path))
	Pack.write_library(solved, ProjectSettings.globalize_path("bibliotecas/cilindro_rev.rooms"), true)
	print("resueltas %d de %d intentos (%d sin solución hallada) en %.0f s" % [solved.size(), tried, unsolved, float(Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)
