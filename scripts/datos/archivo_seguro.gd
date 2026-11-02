extends RefCounted
## Escritura y lectura a prueba de cortes (un apagón, un cierre a la fuerza, un disco lleno): el texto se escribe entero en un archivo temporal (`.tmp`), la versión anterior queda de copia (`.bak`)
## y recién entonces el temporal pasa a ser el archivo. Si el archivo principal está dañado o no se puede leer, se lee la copia. Lo usan el guardado, el perfil y las opciones.


## Guarda `texto` en `ruta` sin dejar nunca un archivo a medias. false si no se pudo escribir.
static func escribir(ruta: String, texto: String) -> bool:
	var tmp := ruta + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(texto)
	var ok := f.get_error() == OK
	f.close()
	if not ok:
		DirAccess.remove_absolute(_abs(tmp))
		return false
	if FileAccess.file_exists(ruta):
		var viejo := FileAccess.open(ruta, FileAccess.READ)   # (la copia sólo vale si lo que había se podía leer)
		var contenido := viejo.get_as_text() if viejo != null else ""
		if viejo != null:
			viejo.close()
		if contenido != "":
			var copia := FileAccess.open(ruta + ".bak", FileAccess.WRITE)
			if copia != null:
				copia.store_string(contenido)
				copia.close()
		DirAccess.remove_absolute(_abs(ruta))
	return DirAccess.rename_absolute(_abs(tmp), _abs(ruta)) == OK


## El diccionario JSON de `ruta`, o el de su copia si el principal falta o está dañado; {} si ninguno sirve. `valido` (opcional) decide si un diccionario leído sirve: Callable(Dictionary) -> bool.
static func leer(ruta: String, valido := Callable()) -> Dictionary:
	for candidato in [ruta, ruta + ".bak"]:
		var d := _leer_uno(candidato)
		if not d.is_empty() and (not valido.is_valid() or bool(valido.call(d))):
			return d
	return {}


## ¿Hay algo escrito (el archivo o su copia)?
static func existe(ruta: String) -> bool:
	return FileAccess.file_exists(ruta) or FileAccess.file_exists(ruta + ".bak")


## Borra el archivo, su copia y su temporal.
static func borrar(ruta: String) -> void:
	for r in [ruta, ruta + ".bak", ruta + ".tmp"]:
		if FileAccess.file_exists(r):
			DirAccess.remove_absolute(_abs(r))


static func _leer_uno(ruta: String) -> Dictionary:
	if not FileAccess.file_exists(ruta):
		return {}
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return {}
	var json := JSON.new()   # (JSON.parse_string imprime un error en la consola si el archivo está dañado)
	if json.parse(f.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


static func _abs(ruta: String) -> String:
	return ProjectSettings.globalize_path(ruta) if ruta.begins_with("user://") or ruta.begins_with("res://") else ruta
