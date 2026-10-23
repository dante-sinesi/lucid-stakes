extends RefCounted
## Datos de juego sólo en la máquina del jugador (user://telemetria.jsonl, una línea JSON por evento): nada se envía a ningún lado. Sirven para calibrar el balance
## con las pruebas de jugadores reales (cuántos mueren en cada torre, qué compran, cuánto sobra en cada casino). En Opciones hay un botón que abre la carpeta
## para que el jugador pueda mandar el archivo si quiere.
##   torre      {stage, outcome ("ganada"|"muerta"|"reintento"), seconds, moves, claridad, retries, lives, cause}
##   sala       {stage, resultado ("ganada"|"perdida"), causa, indice, total, id, nivel, tipo, pisos, categoria, pasos_minimos, movs, max_mov, muertes_previas, segundos, claridad, lives}   (la torre nueva: una por sala)
##   casino     {stage, claridad_in, claridad_out, lives, boosts}
##   peaje      {stage, price, claridad, choice ("pagar"|"rehacer"|"abandonar"|"cancelar")}
##   run_fin    {victory, stage, towers, trials, earned, lives}

const VERSION := 1

static var path := "user://telemetria.jsonl"
static var enabled := true


## Anota un evento (si la escritura falla, no pasa nada).
static func log_event(kind: String, data: Dictionary = {}) -> void:
	if not enabled:
		return
	var rec := {"t": int(Time.get_unix_time_from_system()), "v": VERSION, "kind": kind}
	rec.merge(data)
	var f: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(rec))
	f.close()


## Todos los eventos anotados (para las pruebas y para resumir).
static func read_all() -> Array:
	var out: Array = []
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		var parsed = JSON.parse_string(line)
		if typeof(parsed) == TYPE_DICTIONARY:
			out.append(parsed)
	return out


static func clear() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## La carpeta donde quedan el archivo, los ajustes y los registros del juego.
static func folder() -> String:
	return ProjectSettings.globalize_path("user://")


static func open_folder() -> void:
	OS.shell_open(folder())
