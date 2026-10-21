extends SceneTree
## Sonda del generador del cilindro: escalera -> desordenado hacia atrás (haz) -> solucionador exacto.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s cilindro/probe.gd -- alto=6 obj=8 dist=3 ancho=12 n=3 seed=1 tag=probe ramas=0 tope=2 prof=60
## Escribe capturas/cilindro_ETIQUETA.jsonl (una línea por torre) para dibujarlas.
const Esc := preload("res://cilindro/escalera.gd")
const Des := preload("res://cilindro/desordenador.gd")
const Sol := preload("res://cilindro/solucionador.gd")
const Reglas := preload("res://cilindro/reglas.gd")


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
	var alto := int(o.get("alto", 6))
	var objetivo := int(o.get("obj", 6))
	var distintos := int(o.get("dist", 1))
	var ancho := int(o.get("ancho", 12))
	var cuantas := int(o.get("n", 3))
	var primera := int(o.get("seed", 1))
	var etiqueta: String = o.get("tag", "probe")
	var n_ramas := int(o.get("ramas", 0))
	var tope_bloque := int(o.get("tope", 2))
	var prof := int(o.get("prof", 60))
	Des.peso_y = float(o.get("py", 0.5))
	var dump := FileAccess.open(ProjectSettings.globalize_path("capturas/cilindro_%s.jsonl" % etiqueta), FileAccess.WRITE)
	for semilla in range(primera, primera + cuantas):
		var rng := RandomNumberGenerator.new()
		rng.seed = semilla
		var t0 := Time.get_ticks_msec()
		var inicio := rng.randi_range(0, 27)
		var sentido := 1 if rng.randf() < 0.5 else -1
		var e = Esc.construir(alto, inicio, sentido)
		if e == null:
			print("semilla %d: la escalera no engancha (inicio %d, sentido %d)" % [semilla, inicio, sentido])
			continue
		if n_ramas > 0:
			Esc.ramas(rng, e, n_ramas)
		var fin = Esc.resuelta(e)
		if fin == null:
			print("semilla %d: la escalera no se resuelve" % semilla)
			continue
		var r := Des.desordenar_exacto(rng, fin, ancho, prof, int(o.get("pre", 30)), int(o.get("meta", 9999)))
		if r.is_empty():
			print("semilla %d: el haz no llegó al anillo" % semilla)
			continue
		var s = r.estado
		var sol_pasos: int = r.pasos
		var agarres: int = r.agarres
		var distintos_mov := 0
		print("semilla %d: alto %d, valor %d: solución exacta %d pasos / %d agarres (camino armado %d) en %d ms" % [semilla, alto, r.valor, r.pasos, r.agarres, r.profundidad, Time.get_ticks_msec() - t0])
		dump.store_line(JSON.stringify({"etiqueta": "%s %d" % [etiqueta, semilla], "alto": alto, "bloques": _celdas(s), "jugador": [s.jugador.x, s.jugador.y, s.jugador.z], "pasos": r.pasos, "agarres": r.agarres, "armado": r.profundidad, "deshechos": 0, "tocados": 0}))
	dump.close()
	quit(0)
