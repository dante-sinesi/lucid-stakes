extends RefCounted
## Guardado de la partida en un archivo JSON (user://save.json). Se guarda solo (autoguardado) en estos momentos: cuando una torre
## nueva está lista, al hacer el primer movimiento o usar un consumible, al entrar al casino, al resolver cada giro de la ruleta y
## al volver al menú o cerrar el juego. Un archivo ilegible o de otra versión se ignora (no rompe nada).

const Seguro := preload("res://scripts/datos/archivo_seguro.gd")

const VERSION := 1

## Ruta del archivo (las pruebas la cambian para no tocar la partida real).
static var path := "user://save.json"


static func exists() -> bool:
	return Seguro.existe(path)


static func delete() -> void:
	Seguro.borrar(path)


static func write(data: Dictionary) -> bool:
	var d := data.duplicate()
	d["version"] = VERSION
	return Seguro.escribir(path, JSON.stringify(d))   # (a un temporal y con copia: un corte a mitad de escritura no deja el guardado roto)


## Lo guardado, o {} si no hay archivo, está dañado o es de otra versión. Si el archivo principal no sirve, se usa la copia anterior.
static func read() -> Dictionary:
	return Seguro.leer(path, _sirve)


static func _sirve(d: Dictionary) -> bool:
	return int(d.get("version", 0)) == VERSION and d.has("run") and d.has("phase") and d.has("stage")


## Etapa de la partida guardada (para el botón Continuar), o -1 si no hay nada que continuar.
static func peek_stage() -> int:
	var d := read()
	return int(d.stage) if not d.is_empty() else -1
