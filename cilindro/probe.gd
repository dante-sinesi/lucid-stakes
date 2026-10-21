extends SceneTree
## Sonda del generador del cilindro: escalera -> desordenado hacia atrás (haz) -> solucionador exacto.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s cilindro/probe.gd -- ALTO OBJETIVO_BLOQUES ANCHO SEMILLAS [PRIMERA_SEMILLA=1] [ETIQUETA=probe]
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
	var a := OS.get_cmdline_user_args()
	var alto := int(a[0]) if a.size() > 0 else 6
	var objetivo := int(a[1]) if a.size() > 1 else 6
	var ancho := int(a[2]) if a.size() > 2 else 12
	var cuantas := int(a[3]) if a.size() > 3 else 3
	var primera := int(a[4]) if a.size() > 4 else 1
	var etiqueta := a[5] if a.size() > 5 else "probe"
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
		var fin = Esc.resuelta(e)
		if fin == null:
			print("semilla %d: la escalera no se resuelve" % semilla)
			continue
		var r := Des.desordenar_haz(rng, fin, objetivo, ancho, 60)
		if r.is_empty():
			print("semilla %d: el haz no llegó al anillo" % semilla)
			continue
		var s = r.estado
		var sol := Sol.resolver(s, 300000)
		var agarres := 0
		if sol.ok:
			var u = s.duplicar()
			for p in sol.path:
				var antes: int = u.bloques.hash()
				u.actuar(p[0], p[1])
				if p[1] == 1 and u.bloques.hash() != antes:
					agarres += 1
		print("semilla %d: alto %d, deshechos %d, camino armado %d, solución exacta %s pasos / %d agarres (%d estados) en %d ms" % [semilla, alto, r.bloques, r.profundidad, str(sol.moves) if sol.ok else "?", agarres, sol.states, Time.get_ticks_msec() - t0])
		dump.store_line(JSON.stringify({"etiqueta": "%s %d" % [etiqueta, semilla], "alto": alto, "bloques": _celdas(s), "jugador": [s.jugador.x, s.jugador.y, s.jugador.z], "pasos": sol.moves if sol.ok else -1, "agarres": agarres, "armado": r.profundidad, "deshechos": r.bloques}))
	dump.close()
	quit(0)
