extends SceneTree
## Sonda: cómo reparte los niveles de sala cada dificultad a lo largo de las 15 etapas.
const Torre := preload("res://salas_nuevas/torre.gd")
func _init() -> void:
	var paquete := Torre.cargar_paquete_del_juego()
	for dif in ["facil", "media", "dificil", "pesadilla"]:
		var linea: String = str(dif).rpad(10)
		for etapa in [1, 3, 6, 9, 12, 15]:
			var cont := {"facil": 0, "media": 0, "dificil": 0, "pesadilla": 0}
			var pasos := 0
			var salas := 0
			var margen := 0.0
			for sem in 8:
				var t = Torre.armar(paquete, sem * 31 + 5, Torre.salas_de_etapa(etapa), true, etapa, dif)
				for e in t.salas:
					cont[str(e.d.nivel)] += 1
					pasos += int(e.d.pasos)
					margen += float(e.max_mov) / maxf(float(e.d.pasos), 1.0)
					salas += 1
			linea += "  e%d: f%d m%d d%d p%d (%.0f pasos, x%.2f)" % [etapa, 100 * cont.facil / maxi(salas, 1), 100 * cont.media / maxi(salas, 1), 100 * cont.dificil / maxi(salas, 1), 100 * cont.pesadilla / maxi(salas, 1), float(pasos) / maxf(salas, 1), margen / maxf(salas, 1)]
		print(linea)
	quit(0)
