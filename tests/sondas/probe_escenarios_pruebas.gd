extends SceneTree
## Arma torres con cada prueba nueva dentro de cada escenario (las reglas del escenario más las de la prueba), en la primera etapa en que puede caer y en la 12, y dice cuáles salen incompletas y cuánto tardó:
## sirve para ver si una prueba no se lleva bien con un escenario (por ejemplo, si le quita tantas salas al armado que la torre no se completa).
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/sondas/probe_escenarios_pruebas.gd   (ESCENARIOS=pesadilla,usurero para elegir)
const Torre := preload("res://torre/torre.gd")
const Trials := preload("res://scripts/datos/trials.gd")
const Scenarios := preload("res://scripts/datos/scenarios.gd")


func _init() -> void:
	var paquete: Array = Torre.cargar_paquete_del_juego()
	var ids: Array = []
	for s in Scenarios.ALL:
		ids.append(str(s.id))
	if OS.get_environment("ESCENARIOS") != "":
		ids = OS.get_environment("ESCENARIOS").split(",")
	for sid in ids:
		var sc: Dictionary = Scenarios.get_scenario(sid)
		for tid in Trials.CATALOG:
			var tr: Dictionary = Trials.CATALOG[tid]
			if not tr.has("reglas") or tid == Trials.FINAL_TRIAL:
				continue
			var reglas: Dictionary = sc.duplicate()
			reglas.merge(tr.reglas, true)
			var malas := 0
			var t0 := Time.get_ticks_msec()
			for etapa in [int(tr.get("desde", 3)), 12]:
				for semilla in 2:
					var t = Torre.armar(paquete, 900 + semilla * 17 + etapa, Torre.salas_de_etapa(etapa), true, etapa, "media", reglas)
					if t.salas.size() < Torre.salas_de_etapa(etapa):
						malas += 1
			print("%s + %s: torres incompletas %d de 4 (%d ms)" % [sid, tid, malas, Time.get_ticks_msec() - t0])
	quit()
