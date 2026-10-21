extends SceneTree
## Junta las paredes que salieron de todas las corridas (bibliotecas/p2_*.rooms), las vuelve a medir y se queda con las mejores sin repetidas: bibliotecas/p2_elite.rooms (las siguientes corridas parten de ahí).
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/elite_paredes.gd -- [CUÁNTAS=40]
const RoomLib := preload("res://scripts/room_lib.gd")
const Pack := preload("res://scripts/room_pack.gd")
const Base := preload("res://scripts/pared_gen.gd")
const Gen := preload("res://scripts/pared_gen2.gd")


func _init() -> void:
	var keep := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 40
	var dir := ProjectSettings.globalize_path("bibliotecas")
	var seen := {}
	var scored: Array = []
	var total := 0
	for f in DirAccess.get_files_at(dir):
		if not f.begins_with("p2_") or not f.ends_with(".rooms"):
			continue
		for r in Pack.load_library(dir.path_join(f)):
			total += 1
			if seen.has(r.id):
				continue
			seen[r.id] = true
			r["mass"] = Base.mass("pared" if str(r.shape) == "P6" else "cilindro")
			var costs := Base.face_costs(r)
			var sc := Gen.total_score(r, costs, true)
			if sc < 0.0:
				continue
			r.opt["score"] = int(sc)
			scored.append(r)
	scored.sort_custom(func(a, b): return int(a.opt.score) > int(b.opt.score))
	var out: Array = scored.slice(0, keep)
	Pack.write_library(out, dir.path_join("p2_elite.rooms"), true)
	print("leídas %d, únicas y resolubles %d, elite %d (mejor puntaje %d, peor %d)" % [total, scored.size(), out.size(), int(out[0].opt.score) if not out.is_empty() else 0, int(out[out.size() - 1].opt.score) if not out.is_empty() else 0])
	quit(0)
