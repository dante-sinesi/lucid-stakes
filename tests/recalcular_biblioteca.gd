extends SceneTree
## Pasa una biblioteca de salas por todos los parches vigentes: estructura, camino repetido con las reglas de hoy (core sólido en el hueco de la L y la U), que el camino no salga de la arena, métricas
## y hashes recalculados. Con CORTE y PARTES procesa sólo una parte (para repartir el trabajo entre procesos). Escribe las salas que quedan.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/recalcular_biblioteca.gd -- ENTRADA.rooms SALIDA.rooms [PARTE=0] [PARTES=1] [LIMITE=0]
const RoomLib := preload("res://scripts/room_lib.gd")
const Pack := preload("res://scripts/room_pack.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var t0 := Time.get_ticks_msec()
	var rooms: Array = Pack.load_library(args[0])
	var part := int(args[2]) if args.size() > 2 else 0
	var parts := int(args[3]) if args.size() > 3 else 1
	var limit := int(args[4]) if args.size() > 4 else 0
	var strict := OS.get_environment("ESTRICTO") != ""
	print("leídas %d salas en %.1f s" % [rooms.size(), float(Time.get_ticks_msec() - t0) / 1000.0])
	var why := {}
	var kept: Array = []
	var seen := {}
	var t1 := Time.get_ticks_msec()
	var n := 0
	for i in rooms.size():
		if i % parts != part:
			continue
		if limit > 0 and n >= limit:
			break
		n += 1
		var r: Dictionary = rooms[i]
		var bad := RoomLib.validate_structure(r)
		if bad != "":
			why["estructura"] = int(why.get("estructura", 0)) + 1
			continue
		if r.path.is_empty() or not RoomLib.replay(r, r.path).ok:
			why["no_se_resuelve"] = int(why.get("no_se_resuelve", 0)) + 1
			continue
		if strict and not RoomLib.outside_cells(r).is_empty():   # (con ESTRICTO: el camino no puede tocar casillas fuera de la arena; la torre ya lo comprueba al poner la sala, así que por defecto sólo se cuenta)
			why["sale_de_la_arena"] = int(why.get("sale_de_la_arena", 0)) + 1
			continue
		RoomLib.apply_result(r, r.path, "exacta", r.path.size(), int(r.opt.get("states", 0)))
		RoomLib.finalize(r)
		if seen.has(r.id):
			why["repetida"] = int(why.get("repetida", 0)) + 1
			continue
		seen[r.id] = true
		kept.append(r)
	var secs := float(Time.get_ticks_msec() - t1) / 1000.0
	print("parte %d/%d: %d procesadas en %.1f s (%.0f/s) · quedan %d · descartes %s" % [part, parts, n, secs, float(n) / maxf(secs, 0.001), kept.size(), str(why)])
	print("guardadas %d en %s: %s" % [kept.size(), args[1], str(Pack.write_library(kept, ProjectSettings.globalize_path(args[1]), args[1].ends_with(".rooms")))])
	quit(0)
