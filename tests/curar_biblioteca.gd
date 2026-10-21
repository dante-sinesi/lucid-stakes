extends SceneTree
## Recorte curado de bibliotecas grandes, leyendo un archivo a la vez (casi no usa memoria): se queda con toda la biblioteca actual y, de las nuevas (3x3, 3x5 y 3x8: las L y las U hoy no se usan),
## con todas las de dificultad alta (las que usa la última etapa) y unas CUPO por cada (forma, altura, calificación de a 5 %), una por familia.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/curar_biblioteca.gd -- SALIDA.rooms ACTUAL.rooms CUPO ENTRADA1.rooms ENTRADA2.rooms ...
const Pack := preload("res://scripts/room_pack.gd")
const RoomPool := preload("res://scripts/room_pool.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var quota := int(args[2])
	var current: Array = Pack.load_library(args[1])
	var out: Array = current.duplicate()
	var keep := {}
	for r in current:
		keep[r.id] = true
	var fams := {}
	var counts := {}
	var hard := 0
	var added := 0
	for i in range(3, args.size()):
		var rooms: Array = Pack.load_library(args[i])
		for r in rooms:
			if keep.has(r.id) or r.shape == "L" or r.shape == "U":
				continue
			var take := false
			if float(r.opt.get("diff", 0.0)) >= RoomPool.FINAL_MIN_DIFF:
				take = true
				hard += 1
			else:
				var cell := "%s|%d|%d" % [r.shape, int(r.h), int(RoomPool.rating(r) * 20.0)]
				if int(counts.get(cell, 0)) < quota and not fams.has(r.family):
					counts[cell] = int(counts.get(cell, 0)) + 1
					take = true
			if take:
				keep[r.id] = true
				fams[r.family] = true
				out.append(r)
				added += 1
		print("%s: %d leídas, van %d nuevas" % [args[i].get_file(), rooms.size(), added])
	print("recorte: %d de la biblioteca actual + %d nuevas (%d de dificultad alta) = %d salas" % [current.size(), added, hard, out.size()])
	print("guardadas en %s: %s" % [args[0], str(Pack.write_library(out, ProjectSettings.globalize_path(args[0]), true))])
	quit(0)
