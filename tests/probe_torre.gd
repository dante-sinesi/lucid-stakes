extends SceneTree
const Torre := preload("res://salas_nuevas/torre.gd")
func _init() -> void:
	var p := Torre.cargar_paquete(ProjectSettings.globalize_path("res://bibliotecas/paquete_salas.jsonl"))
	for semilla in [4, 5]:
		var t = Torre.armar_espiral(p, semilla, 8)
		print("semilla ", semilla, " salas ", t.salas.size(), " giros ", Torre.giros(t), " lugares ", Torre.lugares(t))
		for s in t.salas:
			print("  ", s.d.tipo, " ", Torre.huella(s.d), " ent ", Torre.entrada_xz(s.d), " sal ", Torre.salida_xz(s.d))
	quit(0)
