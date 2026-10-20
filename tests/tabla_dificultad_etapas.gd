extends SceneTree
## Tabla de la dificultad de las salas que usa cada etapa de La Pesadilla: la dificultad de la torre (tower_gen), la calificación que se busca (room_pool.target) y qué salas de la biblioteca
## quedan elegidas (cuántas hay disponibles, su calificación, su "dificultad" = agarres sobre pasos, pasos y empujes).
## Ejecutar: GAME_SANDBOX=1 godot --headless --path . -s tests/tabla_dificultad_etapas.gd
const RoomPool := preload("res://scripts/room_pool.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const RoomLib := preload("res://scripts/room_lib.gd")

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	print("etapa | dificultad torre | calificación buscada (1ª sala -> última) | salas disponibles | dificultad de las elegidas % (media, mín-máx) | pasos (media) | empujes (media) | formas")
	for stage in range(1, 16):
		var d := Gen.difficulty_for_stage(stage)
		var total := 18
		var avail := 0
		for e in RoomPool.all():
			if float(e.unlock) <= d + 0.0001 and not (d >= 0.999 and float(e.room.opt.get("diff", 0.0)) < RoomPool.FINAL_MIN_DIFF - 0.0001):
				avail += 1
		var diffs: Array = []
		var moves := 0.0
		var grabs := 0.0
		var n := 0
		var shapes := {}
		for index in [0, 5, 9, 13, 17]:
			var picks := RoomPool.pick(rng, d, index, total, 20, {}, 10)
			for e in picks.slice(0, 4):   # (las primeras: las que más cerca están de lo buscado)
				diffs.append(float(e.room.opt.get("diff", 0.0)) * 100.0)
				moves += float(e.room.opt.get("moves", 0))
				grabs += float(e.room.opt.get("grabs", 0))
				n += 1
				shapes[e.room.shape] = int(shapes.get(e.room.shape, 0)) + 1
		var mean := 0.0
		var lo := 999.0
		var hi := 0.0
		for v in diffs:
			mean += v
			lo = minf(lo, v)
			hi = maxf(hi, v)
		mean /= float(maxi(n, 1))
		print("%2d | %3d %% | %2d %% -> %2d %% | %4d | %4.1f (%3.0f-%3.0f) | %4.1f | %4.1f | %s" % [stage, int(round(d * 100.0)), int(round(RoomPool.target(d, 0, total) * 100.0)), int(round(RoomPool.target(d, total - 1, total) * 100.0)), avail, mean, lo, hi, moves / float(maxi(n, 1)), grabs / float(maxi(n, 1)), str(shapes)])
	quit(0)
