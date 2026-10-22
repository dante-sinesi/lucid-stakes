extends SceneTree
const Torre := preload("res://salas_nuevas/torre.gd")
func _init() -> void:
	var p := Torre.cargar_paquete(ProjectSettings.globalize_path("res://bibliotecas/paquete_salas.jsonl"))
	for semilla in range(1, 31):
		Torre.armar(p, semilla, 8)
	print("colocaciones aceptadas ", Torre.aceptados, " descartadas por tapar el camino de la sala de abajo ", Torre.rechazos_choque)
	quit(0)
