extends SceneTree
const Torre := preload("res://salas_nuevas/torre.gd")
func _init() -> void:
	var p := Torre.cargar_paquete(ProjectSettings.globalize_path("res://bibliotecas/paquete_salas.jsonl"))
	var t0 := Time.get_ticks_msec()
	for semilla in [1, 2, 3, 4, 5, 6]:
		var t = Torre.armar(p, semilla, 8)
		var rs := []
		for s in t.salas:
			rs.append(str(s.d.tipo) + str(Torre.huella(s.d)))
		print("semilla ", semilla, " salas ", t.salas.size(), " vueltas ", snapped(Torre.vueltas(t), 0.01), " pisos ", t.total_pisos())
	print("ms ", Time.get_ticks_msec() - t0)
	quit(0)
