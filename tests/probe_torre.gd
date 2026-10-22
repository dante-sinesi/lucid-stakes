extends SceneTree
const Torre := preload("res://salas_nuevas/torre.gd")
func _init() -> void:
	var p := Torre.cargar_paquete(ProjectSettings.globalize_path("res://bibliotecas/paquete_salas.jsonl"))
	var tot := {}
	for semilla in [3, 4, 5, 6, 7, 8, 9, 10]:
		var t = Torre.armar(p, semilla, 6)
		var tam := []
		for s in t.salas:
			tam.append(str(s.d.tipo) + "/" + str(s.d.nivel).substr(0, 3) + "/" + str(s.d.categoria).substr(0, 4))
			tot[str(s.d.tipo)] = tot.get(str(s.d.tipo), 0) + 1
		print(semilla, " ", tam)
	print(tot)
	quit(0)
