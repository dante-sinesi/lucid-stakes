extends SceneTree
## Busca módulos de pared al azar, los resuelve con el solucionador nativo y los guarda con sus etiquetas de técnica.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s cilindro/probe_modulos.gd -- h=3 n=12 intentos=300 seed=1 tag=m3 min_pasos=8 esp=2
## Escribe capturas/cilindro_ETIQUETA.jsonl con las que pasan el filtro (resolubles, con al menos min_pasos).
const Mod := preload("res://cilindro/modulos.gd")
const Nat := preload("res://cilindro/nativo.gd")


func _celdas(t) -> Array:
	var out: Array = []
	for c in t.bloques:
		out.append([c.x, c.y, c.z, t.bloques[c]])
	return out


func _init() -> void:
	var o := {}
	for arg in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", true, 1)
		if kv.size() == 2:
			o[kv[0]] = kv[1]
	var h := int(o.get("h", 3))
	var n := int(o.get("n", 12))
	var intentos := int(o.get("intentos", 200))
	var semilla := int(o.get("seed", 1))
	var etiqueta: String = o.get("tag", "m")
	var min_pasos := int(o.get("min_pasos", 8))
	var espesor := int(o.get("esp", 2))
	var tope := int(o.get("tope", 200000))
	var tipos: String = o.get("tipos", "")
	var n_esp := int(o.get("nesp", 0))
	var suma_valor := 0.0
	var suma_libres := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var dump := FileAccess.open(ProjectSettings.globalize_path("capturas/cilindro_%s.jsonl" % etiqueta), FileAccess.WRITE)
	var resolubles := 0
	var guardadas := 0
	var t0 := Time.get_ticks_msec()
	for i in intentos:
		var t = Mod.al_azar(rng, h, rng.randi_range(maxi(n - 4, 4), n + 4), espesor, tipos, n_esp)
		if t == null:
			continue
		var sol := Nat.resolver(t, tope)
		if not sol.ok:
			continue
		resolubles += 1
		if sol.moves < min_pasos:
			continue
		var tags := Mod.analizar(t, sol.path)
		if n_esp > 0:
			var nec := Mod.necesidad(t, sol.moves, tope)
			tags["esp_total"] = nec.total
			tags["esp_necesarios"] = nec.necesarios
		suma_valor += sol.moves + 3 * sol.agarres
		suma_libres += float(tags.libres) / maxf(float(sol.moves), 1.0)
		guardadas += 1
		var etiquetas: Array = []
		for k in ["arana", "puente", "tala"]:
			if tags[k] > 0:
				etiquetas.append("%s %d" % [k, tags[k]])
		print("%s %d: %d bloques, %d pasos / %d agarres / %d bloques distintos, técnicas: %s, libres %d de %d, especiales necesarios %s" % [etiqueta, guardadas, t.bloques.size() - 20, sol.moves, sol.agarres, sol.distintos, ", ".join(etiquetas), tags.libres, sol.moves, "%d/%d" % [tags.get("esp_necesarios", 0), tags.get("esp_total", 0)]])
		dump.store_line(JSON.stringify({"etiqueta": "%s %d" % [etiqueta, guardadas], "alto": t.alto, "bloques": _celdas(t), "jugador": [t.jugador.x, t.jugador.y, t.jugador.z], "pasos": sol.moves, "agarres": sol.agarres, "deshechos": sol.distintos, "tocados": sol.distintos, "armado": sol.moves, "tags": tags}))
	dump.close()
	print("listo h=%d: %d diseños, %d resolubles (%.1f%%), %d guardadas, valor medio %.1f, fracción media de pasos libres %.2f, %d s" % [h, intentos, resolubles, 100.0 * resolubles / maxf(intentos, 1), guardadas, suma_valor / maxf(guardadas, 1), suma_libres / maxf(guardadas, 1), (Time.get_ticks_msec() - t0) / 1000])
	quit(0)
