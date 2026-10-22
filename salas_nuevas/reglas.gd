extends RefCounted
## Reglas de sostén de la torre de salas sin núcleo (ver docs/torre_salas_reglas.md). Módulo aislado: no usa el motor viejo.
## Los bloques son un Dictionary { Vector3i: tipo }. Un bloque "f" es fijo (el portal de la torre o, al verificar una sala suelta, el bloque
## que representa lo que toca el bloque de salida en la sala de arriba). No hay suelo: lo que no está anclado cae y, si no encuentra apoyo, se pierde.

## Los 14 vecinos que sostienen: 4 laterales, 2 verticales y 8 diagonales de plano vertical (aristas horizontales).
static var VECINOS: Array[Vector3i] = _vecinos()


static func _vecinos() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
		out.append(d)
	for dy in [-1, 1]:
		for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			out.append(d + Vector3i(0, dy, 0))
	return out


## Los bloques anclados: los fijos y todo lo que los toca en cadena.
static func anclados(bloques: Dictionary) -> Dictionary:
	var vistos := {}
	var cola: Array[Vector3i] = []
	for c in bloques:
		if bloques[c] == "f":
			vistos[c] = true
			cola.append(c)
	while not cola.is_empty():
		var c: Vector3i = cola.pop_back()
		for d in VECINOS:
			var v: Vector3i = c + d
			if bloques.has(v) and not vistos.has(v):
				vistos[v] = true
				cola.append(v)
	return vistos


## Hace caer lo que no está anclado (de abajo hacia arriba) hasta apoyarse en algo que se sostiene; lo que no encuentra apoyo se pierde.
## `jugador`: un bloque suelto que cae sobre el jugador se queda ahí (se vuelve a mirar cuando éste se mueva).
## Devuelve { "bloques": diccionario nuevo, "caidos": cuántos se movieron, "perdidos": cuántos se perdieron }.
static func asentar(bloques: Dictionary, jugador := Vector3i(-999, -999, -999), ids := {}) -> Dictionary:
	var b := bloques.duplicate()
	var quietos := {}
	var caidos := 0
	var perdidos := 0
	var guard := 0
	while guard < 400:
		guard += 1
		var ok := anclados(b)
		var s := Vector3i(-999, 9999, -999)
		var hay := false
		for c in b:
			if ok.has(c) or quietos.has(c):
				continue
			if not hay or c.y < s.y or (c.y == s.y and (c.x < s.x or (c.x == s.x and c.z < s.z))):
				s = c
				hay = true
		if not hay:
			break
		var tipo = b[s]
		b.erase(s)
		var id = ids.get(s)   # (`ids`: la identidad de cada bloque, para que lo que cae lleve consigo lo suyo; se modifica en el lugar)
		ids.erase(s)
		var y := s.y
		var aterrizo := false
		while y > 0:
			y -= 1
			var abajo := Vector3i(s.x, y, s.z)
			if abajo == jugador:
				aterrizo = true
				y += 1
				break
			if b.has(abajo) and (ok.has(abajo) or quietos.has(abajo)):
				aterrizo = true
				y += 1
				break
		if aterrizo and y >= 1:
			b[Vector3i(s.x, y, s.z)] = tipo
			if id != null:
				ids[Vector3i(s.x, y, s.z)] = id
			if y != s.y:
				caidos += 1
			else:
				quietos[s] = true
		else:
			perdidos += 1
	return {"bloques": b, "caidos": caidos, "perdidos": perdidos}
