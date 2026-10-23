extends RefCounted
## Guardado de la partida en un archivo JSON (user://save.json). Se guarda solo (autoguardado) en estos momentos: cuando una torre
## nueva está lista, al hacer el primer movimiento o usar un consumible, al entrar al casino, al resolver cada giro de la ruleta y
## al volver al menú o cerrar el juego. Un archivo ilegible o de otra versión se ignora (no rompe nada).

const VERSION := 1

## Ruta del archivo (las pruebas la cambian para no tocar la partida real).
static var path := "user://save.json"


static func exists() -> bool:
	return FileAccess.file_exists(path)


static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)


static func write(data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	var d := data.duplicate()
	d["version"] = VERSION
	f.store_string(JSON.stringify(d))
	return true


## Lo guardado, o {} si no hay archivo, está dañado o es de otra versión.
static func read() -> Dictionary:
	if not exists():
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var json := JSON.new()   # (JSON.parse_string imprime un error en la consola si el archivo esta danado)
	if json.parse(f.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var parsed: Dictionary = json.data
	if int(parsed.get("version", 0)) != VERSION:
		return {}
	if not parsed.has("run") or not parsed.has("phase") or not parsed.has("stage"):
		return {}
	return parsed


## Etapa de la partida guardada (para el botón Continuar), o -1 si no hay nada que continuar.
static func peek_stage() -> int:
	var d := read()
	return int(d.stage) if not d.is_empty() else -1
