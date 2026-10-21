extends RefCounted
## Reglas del cilindro (ver docs/cilindro_reglas.md). Módulo aislado: no usa el motor viejo.
## Los bloques son un Dictionary { Vector3i: true }. y = 0 es el anillo de piso; la cima está en y = alto.

const N := 8

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


static func es_anillo(x: int, z: int) -> bool:
	return x >= 0 and x < N and z >= 0 and z < N and (x == 0 or x == N - 1 or z == 0 or z == N - 1)


static func es_masa(x: int, z: int) -> bool:
	return x >= 1 and x <= 6 and z >= 1 and z <= 6 and not (x >= 3 and x <= 4 and z >= 3 and z <= 4)


## Las celdas de la cima (todas fijas).
static func cima(alto: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for x in range(1, 7):
		for z in range(1, 7):
			if es_masa(x, z):
				out.append(Vector3i(x, alto, z))
	return out


## Los bloques anclados: los de la cima y todo lo que los toca en cadena.
static func anclados(bloques: Dictionary, alto: int) -> Dictionary:
	var vistos := {}
	var cola: Array[Vector3i] = []
	for c in bloques:
		if c.y == alto:
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


## Los bloques que se sostienen: anclados, o apoyados por abajo en el anillo o en otro que se sostiene.
static func sostenidos(bloques: Dictionary, alto: int) -> Dictionary:
	var ok := anclados(bloques, alto)
	var cambio := true
	while cambio:
		cambio = false
		for c in bloques:
			if ok.has(c):
				continue
			var abajo: Vector3i = c + Vector3i(0, -1, 0)
			if (c.y == 1 and es_anillo(c.x, c.z)) or ok.has(abajo):
				ok[c] = true
				cambio = true
	return ok


## Hace caer lo que no se sostiene (de abajo hacia arriba) hasta apoyarse; lo que no encuentra apoyo se pierde.
## Devuelve { "bloques": nuevo diccionario, "caidos": cuántos se movieron, "perdidos": cuántos se perdieron }.
static func asentar(bloques: Dictionary, alto: int) -> Dictionary:
	var b := bloques.duplicate()
	var caidos := 0
	var perdidos := 0
	var guard := 0
	while guard < 200:
		guard += 1
		var ok := sostenidos(b, alto)
		var sueltos: Array = []
		for c in b:
			if not ok.has(c):
				sueltos.append(c)
		if sueltos.is_empty():
			break
		sueltos.sort_custom(func(p, q): return p.y < q.y)
		var s: Vector3i = sueltos[0]   # el más bajo cae primero
		b.erase(s)
		var y := s.y
		var aterrizo := false
		while y > 0:
			y -= 1
			var abajo := Vector3i(s.x, y, s.z)
			if b.has(abajo) and ok.has(abajo) or b.has(abajo) and not sueltos.has(abajo):
				aterrizo = true
				y += 1
				break
			if y == 0 and es_anillo(s.x, s.z):
				aterrizo = true
				y = 1
				break
		if aterrizo and y >= 1:
			b[Vector3i(s.x, y, s.z)] = true
			if y != s.y:
				caidos += 1
		else:
			perdidos += 1
	return {"bloques": b, "caidos": caidos, "perdidos": perdidos}
