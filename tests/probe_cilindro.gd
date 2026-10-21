extends SceneTree
## EXPERIMENTO del cilindro (scripts/cilindro_gen.gd), aislado del juego: arma masas al azar, las resuelve con el A* exacto y mide pasos, empujes, empujes por piso y bloques distintos movidos.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/probe_cilindro.gd -- [INTENTOS=60] [SEMILLA=1] [IDEAS=muro,mixto,capas] [ALTURAS=5,6,7] [MS_TOTAL=240000]
const RoomLib := preload("res://scripts/room_lib.gd")
const Pack := preload("res://scripts/room_pack.gd")
const Gen := preload("res://scripts/cilindro_gen.gd")
const Conv := preload("res://scripts/convoy_gen.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var tries := int(args[0]) if args.size() > 0 else 60
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args[1]) if args.size() > 1 else 1
	var ideas: Array = Array(args[2].split(",")) if args.size() > 2 else Gen.IDEAS.duplicate()
	var hs: Array = []
	for t in (args[3] if args.size() > 3 else "5,6,7").split(","):
		hs.append(int(t))
	var budget := int(args[4]) if args.size() > 4 else 240000
	var t0 := Time.get_ticks_msec()
	var solved_all: Array = []
	for idea in ideas:
		var n := 0
		var valid := 0
		var solved: Array = []
		var states_sum := 0
		var limit := 0
		var unsolv := 0
		for i in tries:
			if Time.get_ticks_msec() - t0 > budget:
				break
			var h: int = hs[i % hs.size()]
			var room := Gen.make(rng, h, idea)
			n += 1
			if RoomLib.validate_structure(room) != "":
				continue
			valid += 1
			var ver := RoomLib.verify_exact(room, int(OS.get_environment("CAP")) if OS.get_environment("CAP") != "" else 150000, int(OS.get_environment("MS")) if OS.get_environment("MS") != "" else 3000)
			states_sum += int(ver.states)
			if ver.proof == "imposible":
				unsolv += 1
				continue
			if ver.proof != "exacta":
				limit += 1
				continue
			room["path"] = ver.path
			RoomLib.apply_result(room, ver.path, "exacta", int(ver.moves), int(ver.states))
			var m := Conv.metrics(room)
			for k in m:
				room.opt[k] = m[k]
			room.opt["grabs_por_piso"] = float(room.opt.grabs) / float(h)
			solved.append(room)
		var moves := 0.0
		var grabs := 0.0
		var per_floor := 0.0
		var blocks := 0.0
		var best: Dictionary = {}
		for r in solved:
			moves += float(r.opt.moves)
			grabs += float(r.opt.grabs)
			per_floor += float(r.opt.grabs_por_piso)
			blocks += float(r.opt.blocks)
			if best.is_empty() or float(r.opt.grabs) > float(best.opt.grabs):
				best = r
		var cnt := float(maxi(solved.size(), 1))
		print("%s: %d armadas · %d válidas · %d resueltas · %d imposibles · %d sin probar (tope de estados) · estados medios %d" % [idea, n, valid, solved.size(), unsolv, limit, states_sum / maxi(valid, 1)])
		print("    pasos %.1f · empujes %.1f · empujes por piso %.2f · bloques distintos movidos %.1f" % [moves / cnt, grabs / cnt, per_floor / cnt, blocks / cnt])
		if not best.is_empty():
			print("    la de más empujes: h=%d pasos %d empujes %d bloques %d cambios %d" % [int(best.h), int(best.opt.moves), int(best.opt.grabs), int(best.opt.blocks), int(best.opt.switches)])
			print(Gen.top_view(best))
			print("    camino " + RoomLib.path_string(best.path))
		solved_all.append_array(solved)
	Pack.write_library(solved_all, ProjectSettings.globalize_path("bibliotecas/cilindro_prueba.rooms"), true)
	print("guardadas %d salas resueltas en bibliotecas/cilindro_prueba.rooms (%.0f s)" % [solved_all.size(), float(Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)
