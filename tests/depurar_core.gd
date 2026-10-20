extends SceneTree
## Saca de una biblioteca las salas cuyo camino ya no se repite con el core sólido en el hueco de la L y la U (usaban ese hueco para resolverse).
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/depurar_core.gd -- ENTRADA.rooms [SALIDA.rooms]
const RoomLib := preload("res://scripts/room_lib.gd")
const Pack := preload("res://scripts/room_pack.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var rooms: Array = Pack.load_library(args[0])
	var kept: Array = []
	var bad := {}
	var tot := {}
	for r in rooms:
		tot[r.shape] = int(tot.get(r.shape, 0)) + 1
		if RoomLib.replay(r, r.path).ok:
			kept.append(r)
		else:
			bad[r.shape] = int(bad.get(r.shape, 0)) + 1
	print("%s: %d salas · %d dejan de resolverse con el core sólido %s (de %s)" % [args[0], rooms.size(), rooms.size() - kept.size(), str(bad), str(tot)])
	if args.size() > 1:
		print("guardadas %d en %s: %s" % [kept.size(), args[1], str(Pack.write_library(kept, ProjectSettings.globalize_path(args[1]), args[1].ends_with(".rooms")))])
	quit(0)
