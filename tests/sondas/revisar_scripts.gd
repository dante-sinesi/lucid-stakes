extends SceneTree
## Comprueba que todos los scripts del proyecto compilan (los de scripts/, torre/ y tests/). Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/sondas/revisar_scripts.gd
func _recorrer(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with(".") and d != "tools" and d != "build" and d != "bibliotecas" and d != "capturas_" :
			_recorrer(dir + "/" + d, out)
func _init() -> void:
	var lista: Array = []
	for d in ["res://scripts", "res://torre", "res://tests"]:
		_recorrer(d, lista)
	var malos := 0
	for p in lista:
		if str(p).contains("/revisar_scripts"):
			continue
		var s = load(p)
		if s == null or not s.can_instantiate():
			print("FALLA ", p)
			malos += 1
	print("scripts revisados: ", lista.size(), " con problemas: ", malos)
	quit(0)
