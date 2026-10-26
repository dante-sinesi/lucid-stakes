extends SceneTree
## Genera los diseños de minibloques de los cosméticos y los guarda en data/modelos/cosmeticos.jsonl (ver scripts/herramientas/generar_cosmeticos.gd).
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/sondas/generar_cosmeticos.gd
const Generador := preload("res://scripts/herramientas/generar_cosmeticos.gd")


func _init() -> void:
	Generador.guardar()
	print("cosméticos guardados: ", Generador.todos().size())
	quit(0)
