extends SceneTree
## Junta varias bibliotecas en una sola sin repetidas (la primera que aparece se queda: poné primero la que ya viaja con el juego). Repetida = mismo id (la misma sala, girada o espejada).
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/fusionar_biblioteca.gd -- SALIDA.rooms ENTRADA1.rooms ENTRADA2.rooms ...
const Pack := preload("res://scripts/room_pack.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seen := {}
	var all: Array = []
	var dup := 0
	for i in range(1, args.size()):
		var rooms: Array = Pack.load_library(args[i])
		var added := 0
		for r in rooms:
			if seen.has(r.id):
				dup += 1
				continue
			seen[r.id] = true
			all.append(r)
			added += 1
		print("%s: %d salas, %d nuevas" % [args[i].get_file(), rooms.size(), added])
	var shapes := {}
	for r in all:
		shapes[r.shape] = int(shapes.get(r.shape, 0)) + 1
	print("total %d salas únicas (%d repetidas descartadas) %s" % [all.size(), dup, str(shapes)])
	print("guardadas en %s: %s" % [args[0], str(Pack.write_library(all, ProjectSettings.globalize_path(args[0]), true))])
	quit(0)
