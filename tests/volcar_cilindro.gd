extends SceneTree
## Escribe en JSON (una línea por sala) la masa del cilindro para dibujarla: la masa resuelta con la escalera tallada (la de partida del generador al revés) y las salas ya desordenadas y resueltas de bibliotecas/cilindro_rev.rooms.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/volcar_cilindro.gd -- SALIDA.jsonl [ALTURA=6] [SEMILLA=3]
const RoomLib := preload("res://scripts/room_lib.gd")
const Pack := preload("res://scripts/room_pack.gd")
const Gen := preload("res://scripts/cilindro_gen.gd")


func _line(titulo: String, room: Dictionary) -> String:
	var cols := {}
	for c in room.cols:
		cols["%d,%d" % [c.x, c.y]] = room.cols[c]
	return JSON.stringify({"titulo": titulo, "h": room.h, "exit": [room.exit.x, room.exit.y], "cols": cols, "path": RoomLib.path_string(room.path) if room.has("path") else "", "pasos": int(room.opt.get("moves", 0)), "empujes": int(room.opt.get("grabs", 0))})


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var h := int(args[1]) if args.size() > 1 else 6
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args[2]) if args.size() > 2 else 3
	var f := FileAccess.open(ProjectSettings.globalize_path(args[0]), FileAccess.WRITE)
	var g := Gen.goal_state(rng, h)
	f.store_line(_line("Masa resuelta (punto de partida del generador al revés)", g.room))
	var rooms: Array = Pack.load_library(ProjectSettings.globalize_path("bibliotecas/cilindro_rev.rooms"))
	var n := 0
	for r in rooms:
		f.store_line(_line("Masa desordenada y resuelta %d" % (n + 1), r))
		n += 1
		if n >= 4:
			break
	f.close()
	print("listo ", n + 1)
	quit(0)
