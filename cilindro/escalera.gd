extends RefCounted
## Paso 1 del generador del cilindro: la escalera mínima. Un bloque por piso, uno por celda del borde del anillo 8x8 (28 celdas), colgando de la cima por aristas.

const Motor := preload("res://cilindro/motor.gd")
const Reglas := preload("res://cilindro/reglas.gd")
const Sol := preload("res://cilindro/solucionador.gd")


## Las 28 celdas del borde de la 8x8 en orden (dando la vuelta).
static func borde() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(0, 8):
		out.append(Vector2i(x, 0))
	for z in range(1, 8):
		out.append(Vector2i(7, z))
	for x in range(6, -1, -1):
		out.append(Vector2i(x, 7))
	for z in range(6, 0, -1):
		out.append(Vector2i(0, z))
	return out


## La escalera de altura `alto` (alto - 1 bloques, de nivel 1 a alto - 1), empezando en la celda `inicio` del borde y yendo en `sentido` (1 o -1).
## El jugador empieza en la celda anterior (sobre el anillo). Devuelve el estado o null si la escalera no queda enganchada a la cima.
static func construir(alto: int, inicio: int, sentido: int):
	var b := borde()
	var n := b.size()
	if alto - 1 > n - 1:
		return null
	var celda_jugador: Vector2i = b[(inicio - sentido + n * 2) % n]
	var t = Motor.nueva(alto, Vector3i(celda_jugador.x, 1, celda_jugador.y))
	for i in alto - 1:
		var c: Vector2i = b[(inicio + sentido * i + n * 2) % n]
		t.poner(Vector3i(c.x, i + 1, c.y))
	var r := Reglas.asentar(t.bloques, alto, t.jugador)
	if r.caidos > 0 or r.perdidos > 0:
		return null
	return t


## Juega la escalera hasta ganar y devuelve el estado final (con `ganado`), o null si no se gana.
static func resuelta(t):
	var r := Sol.resolver(t, 20000)
	if not r.ok:
		return null
	var u = t.duplicar()
	for a in r.path:
		u.actuar(a[0], a[1])
	return u if u.ganado else null


## Ramas: `n` bloques extra colgando de lo que ya hay (de la cima o de la escalera), como raíces que salen de la escalera. Son material para el desordenador y señuelos.
static func ramas(rng: RandomNumberGenerator, t, n: int) -> void:
	var puestos := 0
	var intentos := 0
	var dirs := Reglas.VECINOS
	while puestos < n and intentos < n * 80:
		intentos += 1
		var base: Vector3i = t.bloques.keys()[rng.randi_range(0, t.bloques.size() - 1)]
		if t.bloques[base] == "f" and rng.randf() < 0.7:
			continue
		var c: Vector3i = base + dirs[rng.randi_range(0, dirs.size() - 1)]
		if c.y < 1 or c.y > t.alto - 1 or c.x < 0 or c.x > 7 or c.z < 0 or c.z > 7 or t.bloques.has(c):
			continue
		if c == t.jugador or c == t.jugador + Vector3i(0, 1, 0):
			continue
		t.bloques[c] = "n"
		var r := Reglas.asentar(t.bloques, t.alto, t.jugador)
		if r.caidos > 0 or r.perdidos > 0:
			t.bloques.erase(c)
			continue
		puestos += 1
