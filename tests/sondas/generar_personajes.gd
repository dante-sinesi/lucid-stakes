extends SceneTree
## Genera los diseños de minibloques de los cinco personajes y los guarda en data/modelos/personajes.jsonl (ver scripts/herramientas/generar_personajes.gd).
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/sondas/generar_personajes.gd
const Generador := preload("res://scripts/herramientas/generar_personajes.gd")


func _init() -> void:
	Generador.guardar()
	print("personajes guardados: ", Generador.todos().size())
	quit(0)
