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


## ¿El camino de la sala (ya girada) llega a la salida en el motor? (se comprueba al armar, por si alguna simetría cambia el resultado)
static func camino_ok(d: Dictionary) -> bool:
	var t = Vista.motor_de(d)
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


## Arma una torre de `n` salas con la curva de dificultad CURVA (si n es mayor se repite el último tramo). Devuelve un Torre; si no pudo encadenar una sala, queda más corta.
static func armar(paquete: Array, semilla: int, n := 6):
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var t = load("res://salas_nuevas/torre.gd").new()
	var off := 0
	var prev_salida := Vector2i(-1, -1)
	var usadas := {}
	# celdas donde puede caer la entrada de alguna sala (con cualquier simetría): la salida de cada sala tiene que dejar una continuación posible
	var alcanzables := {}
	for d in paquete:
		var e := entrada_xz(d)
		for s in 8:
			alcanzables[xz_sim(e.x, e.y, s)] = true
	for i in n:
		var niveles: Array = CURVA[mini(i, CURVA.size() - 1)]
		var elegida := {}
		for relajar in 2:
			var cand: Array = []
			for d in paquete:
				if usadas.has(int(d.id)):
					continue
				if relajar == 0 and not niveles.has(str(d.nivel)):
					continue
				if i < 2 and str(d.get("categoria", "base")) != "base":
					continue   # (las dos primeras salas son de bloques comunes)
				cand.append(d)
			# se mezclan los candidatos y se toma el primero que se pueda girar para que su entrada caiga en la salida anterior
			for k in range(cand.size() - 1, 0, -1):
				var j := rng.randi_range(0, k)
				var tmp = cand[k]
				cand[k] = cand[j]
				cand[j] = tmp
			for d in cand:
				var sims := [0, 1, 2, 3, 4, 5, 6, 7]
				for k in range(7, 0, -1):
					var j := rng.randi_range(0, k)
					var tmp2 = sims[k]
					sims[k] = sims[j]
					sims[j] = tmp2
				for s in sims:
					var g := girar(d, s)
					if i > 0 and entrada_xz(g) != prev_salida:
						continue
					if i < n - 1 and not alcanzables.has(salida_xz(g)):
						continue
					if not camino_ok(g):
						continue
					elegida = {"d": g, "sim": s, "id": int(d.id)}
					break
				if not elegida.is_empty():
					break
			if not elegida.is_empty():
				break
		if elegida.is_empty():
			break
		var g: Dictionary = elegida.d
		elegida["off"] = off
		elegida["max_mov"] = max_movimientos(int(g.pasos), str(g.nivel))
		t.salas.append(elegida)
		usadas[elegida.id] = true
		prev_salida = salida_xz(g)
		off += int(g.meta) - 1   # la entrada de la siguiente (nivel 1) queda en el nivel de salida de ésta
	if not t.salas.is_empty():
		t._entrar(0)
	return t


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
