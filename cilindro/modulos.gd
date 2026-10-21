extends RefCounted
## Módulos de pared del cilindro: trozos de pared de la cara de adelante (6 de ancho, 2 de espesor, `h` pisos) colgando de la cima,
## buscados al azar y clasificados por la técnica que usa su solución exacta (araña, puente, tala...), siguiendo la guía de Babel de Catherine.
## Usa el solucionador nativo (tools/cilindro.exe) para resolver cada diseño.

const Motor := preload("res://cilindro/motor.gd")
const Reglas := preload("res://cilindro/reglas.gd")
const Nat := preload("res://cilindro/nativo.gd")


## Un diseño al azar: `n` bloques que crecen desde la cima por contactos (caras y aristas horizontales) dentro de la banda x 1..6, z 1..2 (o 1..espesor), niveles 1..h.
static func al_azar(rng: RandomNumberGenerator, h: int, n: int, espesor := 2, tipos := "", n_esp := 0):
	var alto := h + 1
	var x0 := rng.randi_range(1, 6)
	var t = Motor.nueva(alto, Vector3i(x0, 1, 0))
	var lista: Array = []
	for c in t.bloques:
		if c.z == 1 and c.y == alto:
			lista.append(c)   # (de la fila de la cima que da a la pared)
	var puestos := 0
	var guardia := 0
	while puestos < n and guardia < n * 80:
		guardia += 1
		var base: Vector3i = lista[rng.randi_range(0, lista.size() - 1)]
		var d: Vector3i = Reglas.VECINOS[rng.randi_range(0, Reglas.VECINOS.size() - 1)]
		var c: Vector3i = base + d
		if c.y < 1 or c.y > h or c.x < 1 or c.x > 6 or c.z < 1 or c.z > espesor or t.bloques.has(c):
			continue
		t.bloques[c] = "n"
		lista.append(c)
		puestos += 1
	var r := Reglas.asentar(t.bloques, alto, t.jugador)
	if r.caidos > 0 or r.perdidos > 0:
		return null
	# bloques especiales (n_esp de los tipos pedidos) en lugar de bloques comunes
	if tipos != "" and n_esp > 0:
		var comunes: Array = []
		for c in t.bloques:
			if t.bloques[c] == "n":
				comunes.append(c)
		comunes.shuffle()
		for i in mini(n_esp, comunes.size()):
			t.bloques[comunes[i]] = tipos[rng.randi_range(0, tipos.length() - 1)]
	return t


## ¿Cada especial es necesario? Se cambia cada uno por un bloque común y se vuelve a resolver: es necesario si la solución cambia o deja de existir.
static func necesidad(t, pasos: int, tope := 200000) -> Dictionary:
	var total := 0
	var necesarios := 0
	for c in t.bloques.keys():
		var k: String = t.bloques[c]
		if k == "n" or k == "f":
			continue
		total += 1
		var u = t.duplicar()
		u.bloques[c] = "n"
		var s := Nat.resolver(u, tope)
		if not s.ok or s.moves != pasos:
			necesarios += 1
	return {"total": total, "necesarios": necesarios}


## Qué técnicas usa el camino: { arana (pasos colgado hacia un costado), puente (bloques empujados sobre un vacío en los que luego se pisa),
## tala (acciones en las que algo se cae), empujes, tiradas, distintos (bloques distintos movidos) }.
static func analizar(t, path: Array) -> Dictionary:
	var u = t.duplicar()
	var r := {"arana": 0, "puente": 0, "tala": 0, "empujes": 0, "tiradas": 0, "libres": 0, "de_bloque": 0}
	var puentes := {}
	for a in path:
		var antes: Dictionary = u.bloques.duplicate()
		var estaba_colgado: bool = u.colgado != Vector3i.ZERO
		var pos_antes: Vector3i = u.jugador
		u.actuar(a[0], a[1])
		var quito: Array = []
		var puso: Array = []
		for c in antes:
			if not u.bloques.has(c):
				quito.append(c)
		for c in u.bloques:
			if not antes.has(c):
				puso.append(c)
		if not quito.is_empty() or not puso.is_empty():
			r.de_bloque += 1
		elif not estaba_colgado and u.jugador.y == pos_antes.y and u.colgado == Vector3i.ZERO:
			r.libres += 1   # un paso por el piso, sin mover nada ni subir
		if estaba_colgado and a[1] == 0 and u.jugador.y == pos_antes.y and u.jugador != pos_antes:
			r.arana += 1
		var cayo := false
		for p in puso:
			for q in quito:
				if q.x == p.x and q.z == p.z and q.y > p.y:
					cayo = true
		if quito.size() > puso.size():
			cayo = true
		if cayo:
			r.tala += 1
		if a[1] == 1 and not puso.is_empty():
			if u.jugador == pos_antes:
				r.empujes += 1
				for p in puso:
					if not u.solido(p + Vector3i(0, -1, 0)):
						puentes[p] = true
			else:
				r.tiradas += 1
		if u.colgado == Vector3i.ZERO and puentes.has(u.jugador + Vector3i(0, -1, 0)):
			r.puente += 1
			puentes.erase(u.jugador + Vector3i(0, -1, 0))
	return r
