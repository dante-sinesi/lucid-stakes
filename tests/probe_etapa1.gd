extends SceneTree
## Sonda: ¿se pueden armar torres de las etapas 1 y 2 con los límites de aprendizaje? Cuánto tardan y cómo son.
const Torre := preload("res://salas_nuevas/torre.gd")
func _init() -> void:
	var paquete := Torre.cargar_paquete_del_juego()
	for etapa in [1, 2, 3]:
		var ok := 0
		var fallas := 0
		var t0 := Time.get_ticks_msec()
		var pasos := 0
		var salas := 0
		var pisos_max := 0
		for sem in 30:
			var t = Torre.armar(paquete, sem * 17 + 1, Torre.salas_de_etapa(etapa), true, etapa)
			if t.salas.size() >= Torre.salas_de_etapa(etapa):
				ok += 1
				for e in t.salas:
					pasos += int(e.d.pasos)
					salas += 1
					pisos_max = maxi(pisos_max, int(e.d.meta) - 1)
			else:
				fallas += 1
		print("etapa ", etapa, " torres completas ", ok, "/30  pasos medios/sala ", float(pasos) / maxf(salas, 1), " pisos máx ", pisos_max, "  ", (Time.get_ticks_msec() - t0) / 30, " ms por torre")
	quit(0)
