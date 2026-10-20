extends SceneTree
## Salas L y U con escalada de colinas guiada por el solucionador (scripts/convoy_gen.gd, `climb`): se parte de una sala desordenada al revés y se la va cambiando (mover bloques, intercambiar columnas,
## armar muros de dos pisos que cruzan el brazo) quedándose con los cambios que dejan una sala resoluble de mayor puntuación (camino largo, bloques distintos, cambios de bloque, espacio usado).
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/probe_acantilado.gd -- CARPETA [SALAS=4] [SEMILLA=1] [MS_POR_SALA=60000] [PASOS_INICIALES=120]
const RoomLib := preload("res://scripts/room_lib.gd")
const Pack := preload("res://scripts/room_pack.gd")
const Gen := preload("res://scripts/convoy_gen.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "bibliotecas/acantilado_prototipo"
	var want := int(args[1]) if args.size() > 1 else 4
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args[2]) if args.size() > 2 else 1
	var budget := int(args[3]) if args.size() > 3 else 60000
	var steps := int(args[4]) if args.size() > 4 else 120
	var out := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(out)
	var picked: Array = []
	var guard := 0
	while picked.size() < want and guard < want * 8:
		guard += 1
		var shape: String = ["L", "U"][guard % 2]
		var start := Gen.scramble(rng, shape, [5, 6, 7][rng.randi_range(0, 2)], "dispersion", steps)
		if start.is_empty():
			continue
		var first := Gen.evaluate(start)
		if first.is_empty():
			continue
		var best := Gen.climb(rng, first, 100000, budget)
		if best.is_empty():
			continue
		best.origin = "convoy"
		best.note = "Acantilado (puntaje %d, %d pruebas)" % [int(best.opt.score), int(best.opt.tries)]
		picked.append(best)
		var o0: Dictionary = first.opt
		var o1: Dictionary = best.opt
		print("sala %d (%s, %d pisos): antes pasos %d empujes %d bloques %d cambios %d espacio %d%% -> ahora pasos %d empujes %d bloques %d cambios %d espacio %d%% zonas %d primer agarre %d (puntaje %d)" % [picked.size(), best.shape, best.h, int(o0.moves), int(o0.grabs), int(o0.blocks), int(o0.switches), int(o0.spread100), int(o1.moves), int(o1.grabs), int(o1.blocks), int(o1.switches), int(o1.spread100), int(o1.zones), int(o1.first_grab), int(o1.score)])
	Pack.write_library(picked, out.path_join("acantilado_%d.rooms" % int(rng.seed)), true)
	print("guardadas ", picked.size())
	quit(0)
