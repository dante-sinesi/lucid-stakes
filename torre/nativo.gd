extends RefCounted
## Puente al solucionador nativo (native/salas.cpp). Misma respuesta que torre/solucionador.gd, mucho más rápido. Tiene dos formas, con la misma respuesta: la **extensión de Godot** (`SolverNativo`, extension/solver.gdextension, que se
## arma con native/construir_extension.bat: se llama directo, sin lanzar un proceso, y es la que viaja con el juego) y el **ejecutable** tools/salas.exe (se arma con native/construir.bat: lo usan las herramientas de desarrollo y es el
## respaldo si no está la extensión). `resolver` prefiere la extensión; el resto (`minimo`, `medir`, `conocido`...) son del ejecutable. Ver docs/solver_extension.md.

const Motor := preload("res://torre/motor.gd")


static func exe() -> String:
	var alt := OS.get_environment("SALAS_EXE")   # (para probar otra versión del ejecutable)
	if alt != "":
		return ProjectSettings.globalize_path(alt) if not alt.is_absolute_path() else alt
	return ProjectSettings.globalize_path("res://tools/salas.exe")


## ¿Está cargada la extensión de Godot del solucionador?
static func extension() -> bool:
	return ClassDB.class_exists("SolverNativo")


## ¿Se puede resolver? Con la extensión o con el ejecutable.
static func disponible() -> bool:
	return extension() or FileAccess.file_exists(exe())


## El estado en el formato de texto de salas.exe.
static func a_texto(t, tope := 1500000) -> String:
	var s := "meta %d\njugador %d %d %d\ncolgado %d 0 %d\ntope %d\n" % [t.meta, t.jugador.x, t.jugador.y, t.jugador.z, t.colgado.x, t.colgado.z, tope]
	for c in t.bloques:
		s += "b %d %d %d %s\n" % [c.x, c.y, c.z, t.bloques[c]]
	return s


## { ok, moves, path:[[dir, modo]], states, agarres, distintos } igual que Solucionador.resolver. tope = nodos como mucho. Con la extensión se llama directo; si no, se lanza el ejecutable.
static func resolver(t, tope := 1500000) -> Dictionary:
	if extension():
		return resolver_extension(t, tope)
	return resolver_exe(t, tope)


## Lo mismo con la extensión de Godot (hay que comprobar antes `extension()`).
static func resolver_extension(t, tope := 1500000) -> Dictionary:
	var solver = ClassDB.instantiate("SolverNativo")
	return _interpretar(String(solver.resolver_texto(a_texto(t, tope))))


## Lo mismo lanzando tools/salas.exe (por la entrada, con un archivo temporal).
static func resolver_exe(t, tope := 1500000) -> Dictionary:
	var dir := OS.get_environment("TEMP")
	var entrada := dir.path_join("cil_%d_%d.txt" % [OS.get_process_id(), randi()])
	var f := FileAccess.open(entrada, FileAccess.WRITE)
	f.store_string(a_texto(t, tope))
	f.close()
	var out: Array = []
	OS.execute("cmd", ["/c", "\"%s\" < \"%s\"" % [exe().replace("/", "\\"), entrada.replace("/", "\\")]], out, true)
	DirAccess.remove_absolute(entrada)
	return _interpretar(String(out[0]) if out.size() > 0 else "")


## Las líneas RESULT y PATH del solucionador (de la extensión o del ejecutable) como diccionario.
static func _interpretar(texto: String) -> Dictionary:
	var res := {"ok": false, "moves": 0, "path": [], "states": 0, "agarres": 0, "distintos": 0}
	for linea in texto.split("\n"):
		var p := linea.strip_edges().split(" ")
		if p[0] == "RESULT":
			if p[1] == "ok":
				res.ok = true
				res.moves = int(p[2])
				res.states = int(p[3])
				res.agarres = int(p[5])
				res.distintos = int(p[6])
			else:
				res.states = int(p[2])
				res.tope = p[1] == "budget"
		elif p[0] == "PATH":
			var i := 1
			while i + 2 < p.size() + 0 and i + 2 <= p.size() - 1 + 0:
				var d := Vector3i(int(p[i]), 0, int(p[i + 1]))
				res.path.append([d, int(p[i + 2])])
				i += 3
	return res


## Corre un modo del ejecutable nativo (por ejemplo ["--medir", "tope=500000"]) con la sala `t` por la entrada y devuelve el JSON de la primera línea que lo sea ({} si falla).
static func correr(args: Array, t, tope := 1500000) -> Dictionary:
	var dir := OS.get_environment("TEMP")
	var entrada := dir.path_join("cil_%d_%d.txt" % [OS.get_process_id(), randi()])
	var f := FileAccess.open(entrada, FileAccess.WRITE)
	f.store_string(a_texto(t, tope))
	f.close()
	var out: Array = []
	var linea := "\"%s\" %s < \"%s\"" % [exe().replace("/", "\\"), " ".join(args), entrada.replace("/", "\\")]
	OS.execute("cmd", ["/c", linea], out, true)
	DirAccess.remove_absolute(entrada)
	var texto := String(out[0]) if out.size() > 0 else ""
	for l in texto.split("\n"):
		var p := l.strip_edges()
		if p.begins_with("{"):
			var d = JSON.parse_string(p)
			if d is Dictionary:
				return d
	return {}


## El camino más corto real (A* exacto) sin pasar de `ub` (un camino conocido): { exacto, minimo, cota_inferior, cota_superior, agarres, distintos, camino }.
static func minimo(t, ub: int, tope := 6000000) -> Dictionary:
	return correr(["--minimo", "ub=%d" % ub, "tope=%d" % tope], t, tope)


## Las métricas de complejidad (ver docs/generador.md).
static func medir(t, tope := 3000000) -> Dictionary:
	return correr(["--medir", "tope=%d" % tope], t, tope)


## El mejor camino que se consigue sin demostrar el mínimo (lonjas de 3 a 6 pisos acortadas por ventanas): { ok, lonjas, mejor, salto, agarres, distintos, camino }.
static func conocido(t, tope_lonja := 300000) -> Dictionary:
	return correr(["--conocido", "tope_lonja=%d" % tope_lonja], t)
