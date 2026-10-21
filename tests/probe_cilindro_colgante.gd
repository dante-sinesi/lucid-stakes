extends SceneTree
## EXPERIMENTO: paredes colgantes (scripts/cilindro_gen.gd, `colgante`): la estructura cuelga de la salida (un bloque fijo arriba). Arma paredes al azar con N bloques, mira cuáles se sostienen y se resuelven (A* exacto)
## y mide empujes, bloques distintos y pasos.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/probe_cilindro_colgante.gd -- [INTENTOS=200] [SEMILLA=1] [BLOQUES=10,14,18] [ALTURAS=5,6,7] [MS_TOTAL=300000]
const RoomLib := preload("res://scripts/room_lib.gd")
const Pack := preload("res://scripts/room_pack.gd")
const Gen := preload("res://scripts/cilindro_gen.gd")
const Conv := preload("res://scripts/convoy_gen.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var tries := int(args[0]) if args.size() > 0 else 200
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args[1]) if args.size() > 1 else 1
	var ns: Array = []
	for t in (args[2] if args.size() > 2 else "10,14,18").split(","):
		ns.append(int(t))
	var hs: Array = []
	for t in (args[3] if args.size() > 3 else "5,6,7").split(","):
		hs.append(int(t))
	var budget := int(args[4]) if args.size() > 4 else 300000
	var t0 := Time.get_ticks_msec()
	var stats := {}
	var good: Array = []
	for i in tries:
		if Time.get_ticks_msec() - t0 > budget:
			break
		var n: int = ns[i % ns.size()]
		var h: int = hs[(i / ns.size()) % hs.size()]
		var room := Gen.colgante(rng, h, n)
		var key := "n=%d" % n
		if not stats.has(key):
			stats[key] = {"armadas": 0, "validas": 0, "resueltas": 0, "imposibles": 0, "sin_probar": 0, "empujes": 0, "bloques": 0, "pasos": 0}
		var st: Dictionary = stats[key]
		st.armadas += 1
		if RoomLib.validate_structure(room) != "":
			continue
		st.validas += 1
		var ver := RoomLib.verify_exact(room, 300000, 4000)
		if ver.proof == "imposible":
			st.imposibles += 1
			continue
		if ver.proof != "exacta":
			st.sin_probar += 1
			continue
		room["path"] = ver.path
		RoomLib.apply_result(room, ver.path, "exacta", int(ver.moves), int(ver.states))
		var m := Conv.metrics(room)
		for k in m:
			room.opt[k] = m[k]
		st.resueltas += 1
		st.empujes += int(room.opt.grabs)
		st.bloques += int(room.opt.blocks)
		st.pasos += int(room.opt.moves)
		good.append(room)
	for key in stats:
		var st: Dictionary = stats[key]
		var c := float(maxi(int(st.resueltas), 1))
		print("%s: %d armadas · %d sostenidas · %d resueltas · %d imposibles · %d sin probar · pasos %.1f · empujes %.1f · bloques distintos %.1f" % [key, st.armadas, st.validas, st.resueltas, st.imposibles, st.sin_probar, float(st.pasos) / c, float(st.empujes) / c, float(st.bloques) / c])
	good.sort_custom(func(a, b): return int(a.opt.grabs) > int(b.opt.grabs))
	Pack.write_library(good.slice(0, 12), ProjectSettings.globalize_path("bibliotecas/cilindro_colgante.rooms"), true)
	if not good.is_empty():
		print("la de más empujes: h=%d, %d bloques, pasos %d, empujes %d, bloques distintos %d" % [int(good[0].h), RoomLib.block_count(good[0]), int(good[0].opt.moves), int(good[0].opt.grabs), int(good[0].opt.blocks)])
		print("camino " + RoomLib.path_string(good[0].path))
	print("guardadas %d (%.0f s)" % [mini(good.size(), 12), float(Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)
