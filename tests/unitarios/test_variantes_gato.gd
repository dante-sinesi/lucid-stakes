extends SceneTree
## Revisa las variantes del gatito travieso (data/variantes_gato.jsonl, ver herramientas/variantes_gato.py): cada una mueve los bloques que dice de una sala de la biblioteca (comunes, una celda,
## a una celda libre de la huella), deja la sala apoyada y con el jugador sobre su checkpoint, se resuelve con el camino que trae en los pasos que dice (jugado en el motor de GDScript), y se nota:
## el camino de la sala original deja de servir. También comprueba cuántos bloques mueve según la altura.
## Uso: GAME_SANDBOX=1 [VARIANTES_ARCHIVO=archivo.jsonl] godot --headless --path . -s tests/unitarios/test_variantes_gato.gd
const Vista := preload("res://torre/vista.gd")
const Reglas := preload("res://torre/reglas.gd")
const Torre := preload("res://torre/torre.gd")

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var fallos := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fallos += 1
		print("FALLA: ", label)


## Cuántos bloques mueve el gato según los pisos de la sala (de 4 a 7: 1 o 2; de 8 a 11: 2; de 12 a 15: 3; de 16 a 19: 4; de 20 en adelante: 5).
static func rango_de_bloques(pisos: int) -> Vector2i:
	if pisos <= 7:
		return Vector2i(1, 2)
	if pisos <= 11:
		return Vector2i(2, 2)
	if pisos <= 15:
		return Vector2i(3, 3)
	if pisos <= 19:
		return Vector2i(4, 4)
	return Vector2i(5, 5)


## El camino en texto (una letra por acción: 'a' + modo * 4 + índice de DIRS) como lista de [dx, dz, modo].
static func decodificar(texto: String) -> Array:
	var out: Array = []
	for i in texto.length():
		var a := texto.unicode_at(i) - 97
		var dir: Vector2i = DIRS[a % 4]
		out.append([dir.x, dir.y, a / 4])
	return out


func _jugar(d: Dictionary, camino: Array) -> bool:
	var t = Vista.motor_de(d)
	for a in camino:
		if not t.actuar(Vector3i(int(a[0]), 0, int(a[1])), int(a[2])).ok:   # (una acción que no se puede hacer corta el camino: ya no sirve)
			return false
	return t.ganado


func _init() -> void:
	var ruta := OS.get_environment("VARIANTES_ARCHIVO")
	if ruta == "":
		ruta = ProjectSettings.globalize_path("res://data/variantes_gato.jsonl")
	var salas := {}
	for d in Torre.cargar_paquete_del_juego():
		salas[int(d.id)] = d
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		print("no se pudo abrir ", ruta)
		quit(1)
		return
	var n_salas := 0
	var n_var := 0
	var sin_variantes := 0
	while not f.eof_reached():
		var l := f.get_line().strip_edges()
		if l == "":
			continue
		var r = JSON.parse_string(l)
		if not r is Dictionary or not salas.has(int(r.id)):
			continue
		n_salas += 1
		if r.variantes.is_empty():
			sin_variantes += 1
			continue
		var d: Dictionary = salas[int(r.id)]
		var pisos := int(d.meta) - 1
		var rango := rango_de_bloques(pisos)
		for v in r.variantes:
			n_var += 1
			var etiqueta := "sala %d variante %d" % [int(r.id), n_var]
			var d2: Dictionary = d.duplicate(true)
			var celdas := {}
			for b in d2.bloques:
				celdas[Vector3i(int(b[0]), int(b[1]), int(b[2]))] = b
			var ok := true
			check(int(v.k) >= rango.x and int(v.k) <= rango.y and v.mov.size() == int(v.k), "%s: mueve %d bloques y a %d pisos tocan de %d a %d" % [etiqueta, v.mov.size(), pisos, rango.x, rango.y])
			for m in v.mov:
				var de := Vector3i(int(m[0]), int(m[1]), int(m[2]))
				var a := Vector3i(int(m[3]), int(m[1]), int(m[4]))
				if not celdas.has(de) or str(celdas[de][3]) != "n":
					check(false, "%s: en %s no hay un bloque común" % [etiqueta, de])
					ok = false
					break
				if celdas.has(a) or absi(a.x - de.x) + absi(a.z - de.z) != 1:
					check(false, "%s: el destino %s no es una celda libre contigua" % [etiqueta, a])
					ok = false
					break
				var b = celdas[de]
				celdas.erase(de)
				b[0] = a.x
				b[2] = a.z
				celdas[a] = b
			if not ok:
				continue
			var t = Vista.motor_de(d2)
			var r2 := Reglas.asentar(t.bloques, t.jugador)
			check(r2.caidos == 0 and r2.perdidos == 0, "%s: la sala queda apoyada" % etiqueta)
			check(str(t.tipo_en(t.jugador + Vector3i(0, -1, 0))) == "p", "%s: el jugador sigue sobre su checkpoint" % etiqueta)
			var camino := decodificar(str(v.camino))
			check(camino.size() == int(v.pasos), "%s: los pasos coinciden (%d contra %d)" % [etiqueta, camino.size(), int(v.pasos)])
			check(_jugar(d2, camino), "%s: el camino de la variante llega a la salida" % etiqueta)
			check(not _jugar(d2, d.camino), "%s: se nota: el camino de la sala original ya no sirve" % etiqueta)
	print("salas: %d (sin variantes: %d), variantes: %d, fallos: %d" % [n_salas, sin_variantes, n_var, fallos])
	quit(1 if fallos > 0 else 0)
