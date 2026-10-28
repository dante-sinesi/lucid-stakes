extends SceneTree
## Arma torres con las reglas de las pruebas nuevas (Quebradizo, Solo tres bloques, Espalda mala, Presupuesto compartido, A oscuras) en varias etapas y semillas, y dice cuántas salas salieron
## (tienen que ser todas las de la etapa) y cuánto tardó el armado. Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/sondas/probe_reglas_pruebas.gd
const Torre := preload("res://torre/torre.gd")


func _init() -> void:
	var paquete: Array = Torre.cargar_paquete_del_juego()
	for nombre in [["quebradizo", {"quebradizo": true}], ["solo_tres", {"solo_bloques": 3}], ["espalda_mala", {"espalda_mala": true}], ["presupuesto", {"presupuesto": true}], ["a_oscuras", {"a_oscuras": true}]]:
		for etapa in [3, 6, 9, 12, 15]:
			var faltan := 0
			var t0 := Time.get_ticks_msec()
			for semilla in 4:
				var t = Torre.armar(paquete, 100 + semilla * 7 + etapa, Torre.salas_de_etapa(etapa), true, etapa, "media", nombre[1])
				if t.salas.size() < Torre.salas_de_etapa(etapa):
					faltan += 1
			print("%s etapa %d: torres incompletas %d de 4 (%d ms)" % [nombre[0], etapa, faltan, Time.get_ticks_msec() - t0])
	quit()
