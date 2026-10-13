extends SceneTree
## Mide el desafío de las torres generadas por etapa (ver scripts/tower_metrics.gd). Variables de entorno: SCEN, SEEDS (por etapa), STAGES ("3,6,9").
## Uso: tools/Godot...console.exe --headless --path . -s tests/probe_metrics.gd
const Rooms := preload("res://scripts/rooms.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
const Metrics := preload("res://scripts/tower_metrics.gd")


func _init() -> void:
	var scen := OS.get_environment("SCEN") if OS.get_environment("SCEN") != "" else "pesadilla"
	var seeds := int(OS.get_environment("SEEDS")) if OS.get_environment("SEEDS") != "" else 2
	var stages: Array = []
	for s in (OS.get_environment("STAGES") if OS.get_environment("STAGES") != "" else "3,6,9,12,15").split(","):
		stages.append(int(s))
	var sum := {}
	var count := 0
	var fails := 0
	var all_total := 0.0
	for stage in stages:
		var prof := Gen.profile_for_stage(stage, {}, Scenarios.get_scenario(scen))
		for sd in seeds:
			var t0 := Time.get_ticks_msec()
			var res: Dictionary = Rooms.generate_stage(100 * stage + sd + 7, 25, prof.difficulty, {"pace": prof.pace, "scenario": prof.scenario})
			var ms := Time.get_ticks_msec() - t0
			if not res.ok:
				fails += 1
				print("etapa %d semilla %d: FALLÓ" % [stage, sd])
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = sd + 1
			var m := Metrics.measure(res, prof.difficulty, rng)
			var p: Dictionary = m.parts
			print("etapa %2d s%d  %.0f pts  [mov %.2f grab %.2f movidos %.2f castigo %.2f ritmo %.2f var %.2f búsq %.2f]  agarres %d (salas %d/%d, bloques %d)  castigo %.2f  titubeos %d  %.0f s" % [
				stage, sd, m.score, p.movers, p.grabs, p.moved, p.punish, p.pressure, p.variety, p.effort, m.grabs, m.rooms_with, m.rooms, m.moved, m.punish, m.tolerance, ms / 1000.0])
			var nm: Array = []
			for r in res.rooms:
				nm.append("%s:%d" % [r.idea, m.grabs_in[nm.size()] if nm.size() < m.grabs_in.size() else -1])
			print("      salas: ", ", ".join(nm))
			for k in p:
				sum[k] = float(sum.get(k, 0.0)) + p[k]
			all_total += m.score
			count += 1
	if count > 0:
		var line := ""
		for k in sum:
			line += "%s %.2f  " % [k, sum[k] / count]
		print("PROMEDIO: %.1f pts  %s  (fallos de generación: %d)" % [all_total / count, line, fails])
	quit()
