extends SceneTree
## Sonda: cómo queda la dificultad de las torres en cada etapa y dificultad. Por etapa: salas, bits de complejidad (media y de la última sala), pasos mínimos, bloques distintos movidos
## y porcentaje de salas con especiales (mediana de las primeras / últimas salas en la tabla de abajo). Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/sondas/probe_dificultad.gd [-- DIF [SEMILLAS]]
const Torre := preload("res://torre/torre.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var difs: Array = [args[0]] if args.size() > 0 else ["facil", "media", "dificil", "pesadilla"]
	var semillas := int(args[1]) if args.size() > 1 else 24
	var paquete := Torre.cargar_paquete_del_juego()
	for dif in difs:
		print("== %s" % dif)
		print("etapa salas  bits(media/ult)  pasos  distintos  especiales")
		for etapa in range(1, 16):
			var bits := 0.0
			var bits_ult := 0.0
			var pasos := 0.0
			var dist := 0.0
			var esp := 0
			var salas := 0
			var torres := 0
			for sem in semillas:
				var t = Torre.armar(paquete, sem * 31 + 5, Torre.salas_de_etapa(etapa), true, etapa, dif)
				torres += 1
				for k in t.salas.size():
					var d: Dictionary = t.salas[k].d
					bits += float(d.get("complejidad", 0.0))
					pasos += float(d.pasos)
					dist += float(d.get("distintos", 1))
					esp += 0 if str(d.get("categoria", "base")) == "base" else 1
					salas += 1
					if k == t.salas.size() - 1:
						bits_ult += float(d.get("complejidad", 0.0))
			print("%5d %5d  %5.0f / %4.0f  %5.1f  %9.1f  %9.0f %%" % [etapa, salas / maxi(torres, 1), bits / maxf(salas, 1), bits_ult / maxf(torres, 1), pasos / maxf(salas, 1), dist / maxf(salas, 1), 100.0 * esp / maxf(salas, 1)])
	quit(0)
