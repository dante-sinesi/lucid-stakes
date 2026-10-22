extends RefCounted
## La torre de salas sin núcleo, lista para jugar (prototipo, aislado del juego actual): arma una torre apilando salas del paquete
## (herramientas/armar_paquete.py) y lleva la partida con las reglas de docs/torre_salas_reglas.md: checkpoints, temporizador de movimientos
## (el mínimo del solucionador más un margen), caída de la sala entera al agotarse, vidas y vuelta al checkpoint con la sala virgen.
##
## Cada sala se juega con su propio Motor (salas_nuevas/motor.gd) en las coordenadas del anillo de 11 x 11. La salida de una sala (el bloque
## fijo "f", el ancla) es la misma celda que la entrada de la siguiente ("p", un nivel más arriba de la siguiente sala), así que mientras se
## juega una sala las de arriba son decorado anclado: nada de lo que pasa en la sala actual las toca. Al llegar a la salida la sala anterior cae.

const Vista := preload("res://salas_nuevas/vista.gd")
const Motor := preload("res://salas_nuevas/motor.gd")

const LADO := 11
static var rechazos_choque := 0   # (estadística: placements descartados porque la sala de arriba tapaba el camino de la de abajo)
static var aceptados := 0
const VIDAS := 3
## Niveles de dificultad que admite cada sala de la torre (la curva sube de a poco); las dos primeras son de bloques comunes (se aprende a jugar).
const CURVA := [["facil"], ["facil", "media"], ["media"], ["media", "dificil"], ["dificil"], ["dificil", "pesadilla"]]

# --- la torre armada ---
var salas: Array = []   # de cada sala: { d: sala ya girada, off: desplazamiento vertical, max_mov: movimientos, sim: simetría, id: id de la sala en el paquete }
var vidas := VIDAS
var indice := 0
var motor            # el Motor de la sala actual
var movs := 0        # movimientos que lleva la sala actual
var encendidos := {} # checkpoints con el farolito prendido
var terminada := false   # llegó al portal
var perdida := false     # se quedó sin vidas
var muertes := 0
var ultima_caida := -1   # índice de la sala que acaba de caer por el checkpoint (para la animación)


# --- simetrías del anillo: las reglas son simétricas, así que una sala puede usarse girada o espejada ---

static func xz_sim(x: int, z: int, s: int) -> Vector2i:
	if s & 1:
		x = LADO - 1 - x
	if s & 2:
		z = LADO - 1 - z
	if s & 4:
		var t := x
		x = z
		z = t
	return Vector2i(x, z)


static func dir_sim(dx: int, dz: int, s: int) -> Vector2i:
	if s & 1:
		dx = -dx
	if s & 2:
		dz = -dz
	if s & 4:
		var t := dx
		dx = dz
		dz = t
	return Vector2i(dx, dz)


## La sala `d` (línea del paquete) con la simetría `s` aplicada a bloques, jugador, colgado y camino.
static func girar(d: Dictionary, s: int) -> Dictionary:
	var o := d.duplicate(true)
	var bl: Array = []
	for b in d.bloques:
		var p := xz_sim(int(b[0]), int(b[2]), s)
		bl.append([p.x, int(b[1]), p.y, b[3]])
	o["bloques"] = bl
	var j: Array = d.jugador
	var pj := xz_sim(int(j[0]), int(j[2]), s)
	o["jugador"] = [pj.x, int(j[1]), pj.y]
	var col = d.get("colgado", [0, 0])
	var pc := dir_sim(int(col[0]), int(col[1]), s)
	o["colgado"] = [pc.x, pc.y]
	var cam: Array = []
	for a in d.get("camino", []):
		var q := dir_sim(int(a[0]), int(a[1]), s)
		cam.append([q.x, q.y, int(a[2])])
	o["camino"] = cam
	return o


static func entrada_xz(d: Dictionary) -> Vector2i:
	return Vector2i(int(d.jugador[0]), int(d.jugador[2]))


static func salida_xz(d: Dictionary) -> Vector2i:
	for b in d.bloques:
		if str(b[3]) == "f":
			return Vector2i(int(b[0]), int(b[2]))
	return Vector2i(-1, -1)


## Las celdas de la sala `g` (la que sigue) que caen al alcance de la sala de abajo, en las alturas de ésta (la entrada de `g`, su nivel 1, es la salida de la de abajo):
## son bloques anclados que no se mueven y que pueden tapar el camino (por ejemplo, la cabeza del jugador al trepar a la salida).
static func obstaculos_de(g: Dictionary, meta_abajo: int) -> Array:
	var out: Array = []
	for b in g.bloques:
		var nivel := int(b[1])
		if nivel < 2:
			continue
		var y := nivel + meta_abajo - 1
		if y > meta_abajo + 6:
			continue
		out.append(Vector3i(int(b[0]), y, int(b[2])))
	return out


## La huella de la sala: el rectángulo (en celdas x, z) que ocupan sus bloques.
static func huella(d: Dictionary) -> Rect2i:
	var x0 := 99
	var z0 := 99
	var x1 := -99
	var z1 := -99
	for b in d.bloques:
		x0 = mini(x0, int(b[0]))
		x1 = maxi(x1, int(b[0]))
		z0 = mini(z0, int(b[2]))
		z1 = maxi(z1, int(b[2]))
	return Rect2i(x0, z0, x1 - x0 + 1, z1 - z0 + 1)


## Celdas de huella que comparten dos salas (una sala que sigue por el mismo lado del anillo comparte mucho; doblar la esquina, sólo la esquina).
static func solape(a: Rect2i, b: Rect2i) -> int:
	var c := a.intersection(b)
	return c.size.x * c.size.y if c.has_area() else 0


## ¿El camino de la sala (ya girada) llega a la salida en el motor? (se comprueba al armar, por si alguna simetría cambia el resultado)
static func camino_ok(d: Dictionary, obstaculos: Array = []) -> bool:
	var t = Vista.motor_de(d)
	t.agregar_obstaculos(obstaculos)
	for a in d.get("camino", []):
		t.actuar(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
	return t.ganado


# --- armado ---

static func cargar_paquete(ruta: String) -> Array:
	var out: Array = []
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var l := f.get_line().strip_edges()
		if l == "":
			continue
		var d = JSON.parse_string(l)
		if d is Dictionary and d.has("camino"):
			out.append(d)
	return out


## Movimientos que se le dan a una sala de `pasos` movimientos mínimos (o conocidos): un margen proporcional que baja con el nivel de la sala.
static func max_movimientos(pasos: int, nivel: String) -> int:
	var idx := ["facil", "media", "dificil", "pesadilla"].find(nivel)
	var factores: Array = [1.9, 1.6, 1.4, 1.25]
	var extras: Array = [10, 8, 6, 5]
	var k: float = factores[maxi(idx, 0)]
	var extra: int = extras[maxi(idx, 0)]
	return int(ceil(pasos * k)) + extra


## ¿La celda (x, z) es del anillo? (11 x 11 con el vacío de 5 x 5 en el medio)
static func es_anillo(x: int, z: int) -> bool:
	return x >= 0 and x < LADO and z >= 0 and z < LADO and not (x >= 3 and x <= 7 and z >= 3 and z <= 7)


static func huella_valida(r: Rect2i) -> bool:
	for x in range(r.position.x, r.position.x + r.size.x):
		for z in range(r.position.y, r.position.y + r.size.y):
			if not es_anillo(x, z):
				return false
	return true


## La sala `d` corrida (dx, dz) celdas (las salas no dependen del lugar del anillo donde estén: se deslizan hasta que su entrada cae en la salida de la anterior).
static func mover(d: Dictionary, dx: int, dz: int) -> Dictionary:
	var o := d.duplicate(true)
	var bl: Array = []
	for b in d.bloques:
		bl.append([int(b[0]) + dx, int(b[1]), int(b[2]) + dz, b[3]])
	o["bloques"] = bl
	o["jugador"] = [int(d.jugador[0]) + dx, int(d.jugador[1]), int(d.jugador[2]) + dz]
	return o


## El ángulo (alrededor del centro del anillo) del centro de una huella.
static func angulo(r: Rect2i) -> float:
	return atan2(r.position.y + r.size.y * 0.5 - 5.5, r.position.x + r.size.x * 0.5 - 5.5)


## Datos de cada sala del paquete que no cambian al girarla: entrada, salida y huella.
static func _info(paquete: Array) -> Array:
	var out: Array = []
	for d in paquete:
		out.append({"d": d, "e": entrada_xz(d), "x": salida_xz(d), "r": huella(d)})
	return out


static func _rect_sim(r: Rect2i, s: int) -> Rect2i:
	var a := xz_sim(r.position.x, r.position.y, s)
	var b := xz_sim(r.position.x + r.size.x - 1, r.position.y + r.size.y - 1, s)
	return Rect2i(mini(a.x, b.x), mini(a.y, b.y), absi(a.x - b.x) + 1, absi(a.y - b.y) + 1)


## Arma una torre de `n` salas con la curva de dificultad CURVA (si n es mayor se repite el último tramo). Cada sala se gira o espeja y se desliza por el anillo
## hasta que su entrada caiga en la salida de la anterior; con `espiral` la torre da vueltas siempre hacia el mismo lado (cada sala sigue por delante de la anterior).
## Si no se puede con espiral se arma sin esa condición. Devuelve un Torre; si no pudo encadenar una sala queda más corta.
static func armar(paquete: Array, semilla: int, n := 6, espiral := true):
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var info := _info(paquete)
	var ctx := {"rng": rng, "info": info, "n": n, "elegidas": [], "usadas": {}, "presupuesto": 6000, "sentido": 1.0 if rng.randf() < 0.5 else -1.0, "espiral": espiral}
	var ok := _extender(ctx, 0)
	if not ok and espiral:
		ctx = {"rng": rng, "info": info, "n": n, "elegidas": [], "usadas": {}, "presupuesto": 6000, "sentido": 1.0, "espiral": false}
		ok = _extender(ctx, 0)
	var t = load("res://salas_nuevas/torre.gd").new()
	var off := 0
	for e in ctx.elegidas:
		var g: Dictionary = e.d
		e["off"] = off
		e["max_mov"] = max_movimientos(int(g.pasos), str(g.nivel))
		t.salas.append(e)
		off += int(g.meta) - 1   # la entrada de la siguiente (nivel 1) queda en el nivel de salida de ésta
	if not t.salas.is_empty():
		t._entrar(0)
	return t


## Busca (con vuelta atrás) la sala número i y las que siguen. Devuelve true si se armaron las n.
static func _extender(ctx: Dictionary, i: int) -> bool:
	if i >= ctx.n:
		return true
	var rng: RandomNumberGenerator = ctx.rng
	var niveles: Array = CURVA[mini(i, CURVA.size() - 1)]
	var info: Array = ctx.info
	var orden: Array = []
	for k in info.size():
		var d: Dictionary = info[k].d
		if ctx.usadas.has(int(d.id)):
			continue
		if i < 2 and str(d.get("categoria", "base")) != "base":
			continue   # (las dos primeras salas son de bloques comunes)
		orden.append(k)
	# primero las del nivel que toca (mezcladas) y después las otras
	for k in range(orden.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp = orden[k]
		orden[k] = orden[j]
		orden[j] = tmp
	var buenas: Array = []
	var otras: Array = []
	for k in orden:
		(buenas if niveles.has(str(info[k].d.nivel)) else otras).append(k)
	var prev_salida: Vector2i = Vector2i(-1, -1)
	var prev_ang := 0.0
	if i > 0:
		var pe: Dictionary = ctx.elegidas[i - 1]
		prev_salida = salida_xz(pe.d)
		prev_ang = angulo(huella(pe.d))
	for k in buenas + otras:
		var datos: Dictionary = info[k]
		var sims := [0, 1, 2, 3, 4, 5, 6, 7]
		for q in range(7, 0, -1):
			var j := rng.randi_range(0, q)
			var tmp2 = sims[q]
			sims[q] = sims[j]
			sims[j] = tmp2
		for s in sims:
			if ctx.presupuesto <= 0:
				return false
			var e := xz_sim(datos.e.x, datos.e.y, s)
			var r := _rect_sim(datos.r, s)
			var dx := 0
			var dz := 0
			if i == 0:   # la primera: un lugar cualquiera del anillo
				var lugar := Vector2i(rng.randi_range(0, LADO - 1), rng.randi_range(0, LADO - 1))
				dx = lugar.x - e.x
				dz = lugar.y - e.y
			else:
				dx = prev_salida.x - e.x
				dz = prev_salida.y - e.y
			var rr := Rect2i(r.position.x + dx, r.position.y + dz, r.size.x, r.size.y)
			if not huella_valida(rr):
				continue
			if i > 0 and ctx.espiral:
				var dif := wrapf(angulo(rr) - prev_ang, -PI, PI) * float(ctx.sentido)
				if dif < deg_to_rad(12.0) or dif > deg_to_rad(150.0):
					continue
			ctx.presupuesto -= 1
			var g := mover(girar(datos.d, s), dx, dz)
			if not camino_ok(g):
				continue
			if i > 0:   # la sala nueva queda sobre la anterior: el camino de la anterior tiene que seguir andando con sus bloques al alcance
				var prev: Dictionary = ctx.elegidas[i - 1].d
				if not camino_ok(prev, obstaculos_de(g, int(prev.meta))):
					rechazos_choque += 1
					continue
			aceptados += 1
			ctx.elegidas.append({"d": g, "sim": s, "id": int(datos.d.id)})
			ctx.usadas[int(datos.d.id)] = true
			if _extender(ctx, i + 1):
				return true
			ctx.elegidas.pop_back()
			ctx.usadas.erase(int(datos.d.id))
			if ctx.presupuesto <= 0:
				return false
	return false


## Cuántas vueltas al anillo da la torre (suma de los avances angulares entre salas consecutivas).
static func vueltas(t) -> float:
	var total := 0.0
	for i in range(1, t.salas.size()):
		total += absf(wrapf(angulo(huella(t.salas[i].d)) - angulo(huella(t.salas[i - 1].d)), -PI, PI))
	return total / TAU


# --- partida ---

func total_pisos() -> int:
	if salas.is_empty():
		return 0
	var u: Dictionary = salas[salas.size() - 1]
	return int(u.off) + int(u.d.meta)


func sala_actual() -> Dictionary:
	return salas[indice]


func max_mov() -> int:
	return int(salas[indice].max_mov)


func _entrar(i: int) -> void:
	indice = i
	motor = Vista.motor_de(salas[i].d)
	if i + 1 < salas.size():   # (los bloques de la sala de arriba que quedan al alcance de ésta)
		motor.agregar_obstaculos(obstaculos_de(salas[i + 1].d, int(salas[i].d.meta)))
	movs = 0
	encendidos = {}
	for c in motor.bloques:
		if str(motor.bloques[c]) == "p":
			encendidos[c] = true


## Una acción del jugador. Devuelve { ok, msg, evento }: evento = "" | "checkpoint" | "muerte" | "torre" | "fin".
func actuar(dir: Vector3i, modo: int) -> Dictionary:
	ultima_caida = -1
	if terminada or perdida:
		return {"ok": false, "msg": "", "evento": ""}
	var r: Dictionary = motor.actuar(dir, modo)
	if not r.ok:
		r["evento"] = ""
		return r
	movs = motor.pasos
	if motor.ganado:
		for c in motor.bloques:
			if str(motor.bloques[c]) == "f":
				encendidos[c] = true
		if indice == salas.size() - 1:
			terminada = true
			r["evento"] = "torre"
			return r
		ultima_caida = indice
		_entrar(indice + 1)   # (la sala anterior cae; la entrada de la nueva es la celda de la salida de la anterior)
		r["evento"] = "checkpoint"
		return r
	if motor.perdido:
		return _morir(str(motor.motivo) if str(motor.motivo) != "" else "Caíste")
	if movs >= max_mov():
		return _morir("Se acabaron los movimientos: la sala se derrumbó")
	r["evento"] = ""
	return r


func _morir(motivo: String) -> Dictionary:
	vidas -= 1
	muertes += 1
	if vidas <= 0:
		perdida = true
		return {"ok": true, "msg": motivo, "evento": "fin"}
	_entrar(indice)   # vuelve al checkpoint con la sala virgen
	return {"ok": true, "msg": motivo, "evento": "muerte"}
