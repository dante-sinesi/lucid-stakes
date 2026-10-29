extends SceneTree
## Juega muchos runs con el bot (scripts/herramientas/bot.gd) sobre torres armadas con el paquete de salas y muestra las estadísticas de balance.
## Variables: TOWERS (10, torres armadas por etapa), CLARIDAD (multiplicador de la claridad), RUNS (200), SEED (1), SKILL (1.0), SPEND (0.8), FREE (0, jugadas gratis por visita), ROT (3, rotaciones de la vitrina), OUT (archivo .jsonl con cada run).
const Bot := preload("res://scripts/herramientas/bot.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Roulette := preload("res://scripts/casino/roulette.gd")


func _env(name: String, def: String) -> String:
	return OS.get_environment(name) if OS.get_environment(name) != "" else def


func _init() -> void:
	var Torre = load("res://torre/torre.gd")
	var rng_banco := RandomNumberGenerator.new()
	rng_banco.seed = int(_env("SEED", "1")) * 7919
	var bank: Dictionary = Bot.arm_bank(Torre.cargar_paquete_del_juego(), rng_banco, int(_env("TOWERS", "10")), _env("DIF", "media"))   # TOWERS: torres armadas por etapa; DIF: facil, media, dificil o pesadilla
	var have := 0
	for s in bank:
		have += bank[s].size()
	if have == 0:
		print("no hay torres: falta el paquete de salas")
		quit(1)
		return
	var runs := int(_env("RUNS", "200"))
	var cfg := Bot.default_config()
	cfg.skill = float(_env("SKILL", "1.0"))
	cfg.spend = float(_env("SPEND", "0.8"))
	cfg.free_plays = int(_env("FREE", "0"))
	cfg.max_rotations = int(_env("ROT", "3"))
	cfg.mistakes = int(_env("MISTAKES", "0"))   # Sin piedad: falsos permitidos por sala (0 = el escenario común)
	if OS.get_environment("HES") != "":
		cfg.hesitate = float(OS.get_environment("HES"))   # probabilidad de titubear (= movimiento en falso) en cada paso para habilidad 1,0
	# parámetros de balance que se pueden cambiar por variable de entorno (para probar curvas)
	var tuned := []
	for pair in [["WALL_GROWTH", "wall_growth"], ["WALL_MARGIN", "wall_margin"], ["WALL_FRAC", "wall_frac"], ["PRE_FROM", "pre_wall_from"], ["PRE_TO", "pre_wall_to"], ["INCOME_SCALE", "income_scale"], ["INCOME_CEIL", "income_ceil"], ["HILL_POWER", "hill_power"]]:
		if OS.get_environment(pair[0]) != "":
			var v := float(OS.get_environment(pair[0]))
			match pair[1]:
				"wall_growth": RunState.wall_growth = v
				"wall_margin": RunState.wall_margin = int(v)
				"wall_frac": RunState.wall_frac = v
				"pre_wall_from": RunState.pre_wall_from = v
				"pre_wall_to": RunState.pre_wall_to = v
				"income_scale": RunState.income_scale = v
				"income_ceil": RunState.income_ceil = v
				"hill_power": RunState.hill_power = v
			tuned.append("%s=%s" % [pair[0], OS.get_environment(pair[0])])
	if OS.get_environment("CLARIDAD") != "":   # multiplicador global de la claridad de la torre
		var Cosecha = load("res://torre/cosecha.gd")
		Cosecha.mult_global = float(OS.get_environment("CLARIDAD"))
		tuned.append("CLARIDAD=" + OS.get_environment("CLARIDAD"))
	if OS.get_environment("FICHA_BASE") != "":
		Roulette.base_price = int(OS.get_environment("FICHA_BASE"))
		tuned.append("FICHA_BASE=" + OS.get_environment("FICHA_BASE"))
	if OS.get_environment("FICHA_STEP") != "":
		Roulette.price_step = int(OS.get_environment("FICHA_STEP"))
		tuned.append("FICHA_STEP=" + OS.get_environment("FICHA_STEP"))
	if OS.get_environment("DIE_BIT") != "":
		cfg.die_per_bit = float(OS.get_environment("DIE_BIT"))
		tuned.append("DIE_BIT=" + OS.get_environment("DIE_BIT"))
	if not tuned.is_empty():
		print("PARAMETROS ", " ".join(tuned))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_env("SEED", "1"))
	var out_path := _env("OUT", "")
	var out: FileAccess = FileAccess.open(out_path, FileAccess.WRITE) if out_path != "" else null
	var wins := 0
	var reach := PackedFloat32Array()
	reach.resize(Bot.FINAL_STAGE + 2)
	var lives := 0.0
	var false_deaths := 0
	var attempts_total := 0
	var per := {}   # etapa -> {n, income, toll, before, attempts, boosts, first_ok}
	var por_nivel := {}   # nivel de sala -> {n, perdidas, movs, max, pasos}
	var builds := {}
	var t0 := Time.get_ticks_msec()
	for r in runs:
		var res := Bot.run_one(bank, rng, cfg)
		wins += 1 if res.won else 0
		for s in range(1, int(res.stage) + 1):
			reach[s] += 1.0
		lives += float(res.lives_lost)
		for rec in res.per_stage:
			var st := int(rec.stage)
			if not per.has(st):
				per[st] = {"n": 0, "income": 0.0, "toll": 0.0, "before": 0.0, "attempts": 0.0, "boosts": 0.0, "first_ok": 0.0}
			var p: Dictionary = per[st]
			p.n += 1
			p.income += float(rec.income)
			p.toll += float(rec.toll)
			p.before += float(rec.claridad_before)
			p.attempts += float(rec.attempts)
			p.boosts += float(rec.boosts)
			p.first_ok += 1.0 if int(rec.attempts) == 1 else 0.0
			false_deaths += int(rec.get("false_deaths", 0))
			for sala in rec.get("rooms", []):
				var pn: Dictionary = por_nivel.get(sala.nivel, {"n": 0, "perdidas": 0, "movs": 0.0, "max": 0.0, "pasos": 0.0})
				pn.n += 1
				pn.perdidas += 0 if sala.ok else 1
				pn.movs += float(sala.movs)
				pn.max += float(sala.max_mov)
				pn.pasos += float(sala.pasos)
				por_nivel[sala.nivel] = pn
			attempts_total += int(rec.attempts)
		for b in res.build:
			builds[b] = int(builds.get(b, 0)) + 1
		if out != null:
			out.store_line(JSON.stringify({"stage": res.stage, "won": res.won, "lives_lost": res.lives_lost, "build": res.build, "per_stage": res.per_stage, "skill": cfg.skill}))
	if out != null:
		out.close()
	print("RUNS %d (habilidad %.2f, torres en el banco: %d) en %.0f s: gana %.1f %% · vidas perdidas %.2f" % [runs, cfg.skill, have, (Time.get_ticks_msec() - t0) / 1000.0, 100.0 * wins / runs, lives / runs])
	if cfg.mistakes > 0:
		print("SIN PIEDAD (%d falsos por sala, titubeo %.3f): %d de %d intentos de torre se perdieron por falsos (%.1f %%)" % [cfg.mistakes, cfg.hesitate, false_deaths, attempts_total, 100.0 * false_deaths / maxi(attempts_total, 1)])
	var line := "pasan la etapa:"
	for s in [1, 3, 5, 7, 8, 9, 10, 12, 14, 15]:
		line += " %d:%3.0f%%" % [s, 100.0 * reach[s] / runs]
	print(line)
	print("etapa  runs  ingreso  boosts  claridad_al_llegar  precio  intentos  pasa_a_la_primera")
	for s in range(1, Bot.FINAL_STAGE + 1):
		if not per.has(s):
			continue
		var p: Dictionary = per[s]
		var n := float(p.n)
		print("%5d %5d %8.0f %7.1f %19.0f %7.0f %9.2f %17.0f %%" % [s, p.n, p.income / n, p.boosts / n, p.before / n, p.toll / n, p.attempts / n, 100.0 * p.first_ok / n])
	if not por_nivel.is_empty():
		print("salas por nivel     salas  perdidas  movs/mínimo  movs/máximo   (supuestos del bot: ver docs/bot.md)")
		for nv in ["facil", "media", "dificil", "pesadilla"]:
			if por_nivel.has(nv):
				var pn: Dictionary = por_nivel[nv]
				print("%-18s %6d %8.1f %% %12.2f %12.2f" % [nv, pn.n, 100.0 * pn.perdidas / pn.n, pn.movs / maxf(pn.pasos, 1.0), pn.movs / maxf(pn.max, 1.0)])
	var names: Array = builds.keys()
	names.sort_custom(func(a, b): return builds[a] > builds[b])
	var bl := "boosts más comunes al final:"
	for i in mini(10, names.size()):
		bl += " %s %d" % [names[i], builds[names[i]]]
	print(bl)
	quit(0)
