extends RefCounted
## Puente al solucionador nativo (tools/salas_nuevas.exe, se arma con native/salas_nuevas.cpp). Misma respuesta que salas_nuevas/solucionador.gd, mucho más rápido.

const Motor := preload("res://salas_nuevas/motor.gd")


static func exe() -> String:
	var alt := OS.get_environment("SN_EXE")   # (para probar otra versión del ejecutable)
	if alt != "":
		return ProjectSettings.globalize_path(alt) if not alt.is_absolute_path() else alt
	return ProjectSettings.globalize_path("res://tools/salas_nuevas.exe")


static func disponible() -> bool:
	return FileAccess.file_exists(exe())


## El estado en el formato de texto de salas_nuevas.exe.
static func a_texto(t, tope := 1500000) -> String:
	var s := "meta %d\njugador %d %d %d\ncolgado %d 0 %d\ntope %d\n" % [t.meta, t.jugador.x, t.jugador.y, t.jugador.z, t.colgado.x, t.colgado.z, tope]
	for c in t.bloques:
		s += "b %d %d %d %s\n" % [c.x, c.y, c.z, t.bloques[c]]
	return s


## { ok, moves, path:[[dir, modo]], states, agarres, distintos } igual que Solucionador.resolver. tope = nodos como mucho.
static func resolver(t, tope := 1500000) -> Dictionary:
	var dir := OS.get_environment("TEMP")
	var entrada := dir.path_join("cil_%d_%d.txt" % [OS.get_process_id(), randi()])
	var f := FileAccess.open(entrada, FileAccess.WRITE)
	f.store_string(a_texto(t, tope))
	f.close()
	var out: Array = []
	OS.execute("cmd", ["/c", "\"%s\" < \"%s\"" % [exe().replace("/", "\\"), entrada.replace("/", "\\")]], out, true)
	DirAccess.remove_absolute(entrada)
	var texto := String(out[0]) if out.size() > 0 else ""
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


## Las métricas de complejidad (ver docs/metrica_dificultad.md).
static func medir(t, tope := 3000000) -> Dictionary:
	return correr(["--medir", "tope=%d" % tope], t, tope)
