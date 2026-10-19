extends SceneTree
## Arma el banco de torres para el bot (scripts/bot.gd): genera torres con el generador del juego y las guarda en bibliotecas/torres/torres_<proceso>.jsonl (una línea por torre).
## Variables: STAGES ("1,2,...,15"), COUNT (torres por etapa, 6), SEED0 (1000), OUT (bibliotecas/torres).
## Cada torre tarda de 10 a 45 s: conviene correr varios procesos con STAGES y SEED0 distintos (herramientas\\bot_banco.bat).
const Rooms := preload("res://scripts/rooms.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const RunState := preload("res://scripts/run_state.gd")
const Bot := preload("res://scripts/bot.gd")


func _env(name: String, def: String) -> String:
	return OS.get_environment(name) if OS.get_environment(name) != "" else def


func _init() -> void:
	var stages: PackedStringArray = _env("STAGES", "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15").split(",")
	var count := int(_env("COUNT", "6"))
	var seed0 := int(_env("SEED0", "1000"))
	var out_dir := _env("OUT", "bibliotecas/torres")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path := out_dir.path_join("torres_%d.jsonl" % OS.get_process_id())
	var f := FileAccess.open(path, FileAccess.WRITE)
	var made := 0
	for sg in stages:
		var stage := int(sg)
		var prof := Gen.profile_for_stage(stage)
		for k in count:
			var seed_value := seed0 + stage * 977 + k * 7919
			var t0 := Time.get_ticks_msec()
			var res: Dictionary = Rooms.generate_stage(seed_value, RunState.rows_for(stage), prof.difficulty, {"pace": prof.pace, "combo": prof.combo, "bias": prof.bias, "scenario": ""})
			if not res.ok:
				print("etapa %d semilla %d: no se generó" % [stage, seed_value])
				continue
			f.store_line(Bot.entry_line(stage, seed_value, res))
			f.flush()
			made += 1
			print("etapa %d torre %d/%d: %d pisos, %d movimientos, %.0f s" % [stage, k + 1, count, int(res.logic.goal_y), res.path.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	f.close()
	print("banco: %d torres en %s" % [made, path])
	quit(0)
