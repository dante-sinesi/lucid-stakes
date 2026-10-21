extends SceneTree
## EXPERIMENTO del cilindro con escalada de colinas guiada por el solucionador: se parte de una masa escasa desordenada y se la va cambiando quedándose con los cambios que dejan una sala resoluble de mayor puntaje
## (pasos, empujes, bloques distintos movidos y cambios de bloque, medidos con el A* exacto).
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/probe_cilindro_climb.gd -- [SALAS=4] [SEMILLA=1] [MS_POR_SALA=90000] [ALTURAS=5,6,7] [EXTRAS=6]
const RoomLib := preload("res://scripts/room_lib.gd")
const Pack := preload("res://scripts/room_pack.gd")
const Gen := preload("res://scripts/cilindro_gen.gd")
const Conv := preload("res://scripts/convoy_gen.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var want := int(args[0]) if args.size() > 0 else 4
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args[1]) if args.size() > 1 else 1
	var budget := int(args[2]) if args.size() > 2 else 90000
	var hs: Array = []
	for t in (args[3] if args.size() > 3 else "5,6,7").split(","):
		hs.append(int(t))
	var extras := int(args[4]) if args.size() > 4 else 6
	var out: Array = []
	var guard := 0
	while out.size() < want and guard < want * 5:
		guard += 1
		var h: int = hs[guard % hs.size()]
		var start := Gen.scramble(rng, h, 150, true, extras)
		if start.is_empty():
			continue
		var first := Conv.evaluate(start, 300000, 4000)
		if first.is_empty():
			print("(intento %d: la masa inicial no se pudo resolver)" % guard)
			continue
		var best := Gen.climb(rng, first, budget)
		if best.is_empty():
			continue
		var o0: Dictionary = first.opt
		var o1: Dictionary = best.opt
		best.origin = "cilindro"
		out.append(best)
		print("sala %d (h=%d): antes pasos %d empujes %d bloques %d -> ahora pasos %d empujes %d (%.2f por piso) bloques %d cambios %d · %d pruebas, %d mejoras" % [out.size(), h, int(o0.moves), int(o0.grabs), int(o0.blocks), int(o1.moves), int(o1.grabs), float(o1.grabs) / float(h), int(o1.blocks), int(o1.switches), int(o1.tries), int(o1.accepted)])
		print(Gen.top_view(best))
		print("camino " + RoomLib.path_string(best.path))
	Pack.write_library(out, ProjectSettings.globalize_path("bibliotecas/cilindro_climb.rooms"), true)
	print("guardadas %d" % out.size())
	quit(0)
