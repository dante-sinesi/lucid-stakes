extends RefCounted
## Puente al solucionador nativo (tools/cilindro.exe, se arma con native/cilindro.cpp). Misma respuesta que cilindro/solucionador.gd, mucho más rápido.

const Motor := preload("res://cilindro/motor.gd")


static func exe() -> String:
	return ProjectSettings.globalize_path("res://tools/cilindro.exe")


static func disponible() -> bool:
	return FileAccess.file_exists(exe())


## El estado en el formato de texto de cilindro.exe.
static func a_texto(t, tope := 1500000) -> String:
	var s := "alto %d\njugador %d %d %d\ncolgado %d 0 %d\ntope %d\n" % [t.alto, t.jugador.x, t.jugador.y, t.jugador.z, t.colgado.x, t.colgado.z, tope]
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
