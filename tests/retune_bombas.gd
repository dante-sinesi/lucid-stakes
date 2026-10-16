extends SceneTree
## Repasa las salas con bomba de data/salas.rooms con la regla de zona esférica (ver TowerLogic.in_bomb_zone): afina la cuenta (lo mínimo + 1), vuelve a resolver con el
## verificador exacto y descarta las que ya no sirven; las bombas de adorno pasan a bloques comunes (RoomLib.audit_specials).
## Por partes: SHARD=i/n escribe bibliotecas/bombas/parte_i.jsonl.  MERGE=1 arma data/salas.rooms con lo que dejaron las partes (las salas con bomba que no están en ninguna se descartan).
## Variables: IN (data/salas.rooms), OUT (data/salas.rooms), LIMIT (sólo las primeras N salas con bomba, para probar).
const RoomLib := preload("res://scripts/room_lib.gd")
const RoomPack := preload("res://scripts/room_pack.gd")


func _env(name: String, def: String) -> String:
	return OS.get_environment(name) if OS.get_environment(name) != "" else def


func _init() -> void:
	var inp := _env("IN", "data/salas.rooms")
	var rooms: Array = RoomPack.load_library(inp)
	DirAccess.make_dir_recursive_absolute("bibliotecas/bombas")
	if _env("MERGE", "") != "":
		_merge(rooms)
		quit(0)
		return
	var parts := _env("SHARD", "0/1").split("/")
	var si := int(parts[0])
	var sn := int(parts[1])
	var limit := int(_env("LIMIT", "0"))
	var out_path := "bibliotecas/bombas/parte_%d.jsonl" % si
	if FileAccess.file_exists(out_path):
		DirAccess.remove_absolute(out_path)
	var seen := 0
	var kept := 0
	var dropped := 0
	var t0 := Time.get_ticks_msec()
	for r in rooms:
		if not RoomLib.has_bomb(r):
			continue
		seen += 1
		if limit > 0 and seen > limit:
			break
		if int(("0x" + String(r.id).substr(0, 8)).hex_to_int()) % sn != si:
			continue
		var au := RoomLib.audit_specials(r, 600000, 20000)
		if au.is_empty():
			dropped += 1
			continue
		var nr: Dictionary = au.room
		var src: String = str(r.opt.get("source", ""))
		if src != "":
			nr.opt["source"] = src
		nr.opt["specials"] = "".join(au.needed)
		if not RoomLib.has_bomb(nr):
			nr.erase("fuse")
		nr.origin = r.origin
		RoomLib.append_line(out_path, nr)
		kept += 1
		if (kept + dropped) % 20 == 0:
			print("[bombas %d/%d] %d buenas, %d descartadas, %.0f s" % [si, sn, kept, dropped, (Time.get_ticks_msec() - t0) / 1000.0])
	print("[bombas %d/%d] listo: %d buenas, %d descartadas de %d con bomba (%.0f s)" % [si, sn, kept, dropped, seen, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)


func _merge(rooms: Array) -> void:
	var tuned := {}
	var files := 0
	for f in DirAccess.get_files_at("bibliotecas/bombas"):
		if f.ends_with(".jsonl"):
			files += 1
			for r in RoomLib.read_file("bibliotecas/bombas/" + f).rooms:
				tuned[r.id] = r
	var out: Array = []
	var replaced := 0
	var lost := 0
	var seen := {}
	for r in rooms:
		if RoomLib.has_bomb(r):
			continue   # (las salas con bomba vuelven afinadas, con su id nuevo si cambiaron)
		out.append(r)
		seen[r.id] = true
	for id in tuned:
		if not seen.has(id):
			out.append(tuned[id])
			seen[id] = true
			replaced += 1
	for r in rooms:
		if RoomLib.has_bomb(r):
			lost += 1
	var dest := _env("OUT", "data/salas.rooms")
	RoomPack.write_library(out, dest, dest.ends_with(".rooms"))
	print("[bombas] %d partes: %d salas con bomba antes, %d afinadas o convertidas, %d salas en total -> %s" % [files, lost, replaced, out.size(), dest])
