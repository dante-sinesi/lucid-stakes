extends SceneTree
## Sonda para diseñar lecciones del tutorial: resuelve una sala escrita en capas y dice si hace falta cada técnica.
## Uso: GAME_SANDBOX=1 LECCION=moverse godot --headless --path . -s tests/probe_leccion.gd   (el id de una lección; o LECCION="capa1|capa2|..." con el dibujo)
## Cada capa son filas separadas por "/" (la fila es z) y cada fila celdas separadas por "," (la celda es x); la primera capa es el nivel 1.
const Tutorial := preload("res://scripts/tutorial.gd")
const Solucionador := preload("res://salas_nuevas/solucionador.gd")
const Vista := preload("res://salas_nuevas/vista.gd")
func _init() -> void:
	var texto := OS.get_environment("LECCION")
	for l in Tutorial.lessons():
		if str(l.id) == texto:
			texto = str(l.capas)
	var d: Dictionary = Tutorial.sala_de_capas(texto)
	var m = Vista.motor_de(d)
	print("bloques ", d.bloques.size(), " meta ", d.meta, " jugador ", d.jugador)
	for prueba in [[[0, 1, 2], ""], [[0, 2], ""], [[0, 1], ""], [[0], ""], [[0, 1, 2], "push"], [[0, 1, 2], "pull"]]:
		var modos: Array = prueba[0]
		var r: Dictionary = Solucionador.resolver(m.duplicar(), 300000, modos, str(prueba[1]))
		print("modos ", modos, " sin ", prueba[1], ": ", ("resuelve en %d  %s" % [r.moves, str(r.path)]) if r.ok else "no resuelve")
	quit(0)
