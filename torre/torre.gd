extends RefCounted
## La torre de salas sin núcleo, lista para jugar (prototipo, aislado del juego actual): arma una torre apilando salas del paquete
## (herramientas/armar_paquete.py) y lleva la partida con las reglas de docs/reglas_torre.md: checkpoints, temporizador de movimientos
## (el mínimo del solucionador más un margen), caída de la sala entera al agotarse, vidas y vuelta al checkpoint con la sala virgen.
##
## Cada sala se juega con su propio Motor (torre/motor.gd) en las coordenadas del anillo de 11 x 11. La salida de una sala (el bloque
## fijo "f", el ancla) es la misma celda que la entrada de la siguiente ("p", un nivel más arriba de la siguiente sala), así que mientras se
## juega una sala las de arriba son decorado anclado: nada de lo que pasa en la sala actual las toca. Al llegar a la salida la sala anterior cae.

const Vista := preload("res://torre/vista.gd")
const Motor := preload("res://torre/motor.gd")
const Cosecha := preload("res://torre/cosecha.gd")

const LADO := 11
static var rechazos_choque := 0   # (estadística: placements descartados porque la sala de arriba tapaba el camino de la de abajo)
static var aceptados := 0
const VIDAS := 3
## Niveles de dificultad que admite cada sala de la torre (la curva sube de a poco); las dos primeras son de bloques comunes (se aprende a jugar).
const CURVA := [["facil"], ["facil", "media"], ["media"], ["media", "dificil"], ["dificil"], ["dificil", "pesadilla"]]
## En qué etapa se habilita cada tipo de bloque especial (hielo 2, pesado 3, agrietado 4, trampa 5, pinchos 6, bomba 7, trampolín 8).
const ETAPA_ESPECIAL := {"i": 2, "h": 3, "c": 4, "t": 5, "s": 6, "b": 7, "k": 8}
const ETAPAS := 15
## Cómo corre la dificultad del run la curva de niveles de las salas: p' = p * a + b (p va de 0 a 1 a lo largo de las 15 etapas). Fácil no pasa de salas medias; Pesadilla arranca en medias y termina en pesadillas.
const PENDIENTE_DIFICULTAD := {"facil": [0.55, 0.0], "media": [1.0, 0.0], "dificil": [0.75, 0.25], "pesadilla": [0.5, 0.5]}
## Cuánto cambia el margen de movimientos de cada sala (el que pasa del mínimo).
const MARGEN_DIFICULTAD := {"facil": 1.25, "media": 1.0, "dificil": 0.85, "pesadilla": 0.7}

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
var cosecha = Cosecha.new()   # la claridad de la torre (ver cosecha.gd)
var dificultad := "media"     # la dificultad elegida para el run: fácil, media, difícil o pesadilla (ver niveles_para)
var etapa := 0                # 0: curva fija de prueba; si no, la etapa del run (sube la dificultad y se habilitan los especiales de a poco)
var externo := false          # las vidas son las del run (las lleva el juego): morir reinicia la sala y avisa, pero no resta
var perks := {}               # boosts del run
var mov_run := 0              # movimientos de más en cada sala por mejoras permanentes del run (Aire de más, Pies ligeros)
var mov_extra := 0            # movimientos de más para la sala actual (Freno, Reloj de arena)
var aliento_usado := false    # Segundo aliento: una vez por torre
var movs_total := 0           # movimientos de toda la torre (incluidos los de los intentos perdidos)
var muertes_sala := 0         # veces que se perdió la sala actual
var t0_sala := 0              # cuándo empezó el intento actual de la sala (ms)
var ultima_sala := {}         # lo que pasó en la última sala que terminó (superada o perdida): lo usa la telemetría
var muerta := false           # (con las vidas del run) se perdió la sala y espera a que el juego decida: reintentar o salir
var deshacer_pila: Array = []  # fotos de la sala actual antes de cada movimiento (para deshacer)
const DESHACER_MAX := 600
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


## ¿El camino de la sala (ya girada) llega a la salida en el motor? (se comprueba al armar, por si alguna simetría cambia el resultado)
static func camino_ok(d: Dictionary, obstaculos: Array = []) -> bool:
	var t = Vista.motor_de(d)
	t.agregar_obstaculos(obstaculos)
	for a in d.get("camino", []):
		t.actuar(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
	return t.ganado


# --- armado ---

## El paquete de salas que viaja con el juego (data/salas_torre.jsonl); si no está, el de bibliotecas/ (desarrollo).
static func cargar_paquete_del_juego() -> Array:
	var p := cargar_paquete("res://data/salas_torre.jsonl")
	if p.is_empty():
		p = cargar_paquete(ProjectSettings.globalize_path("res://bibliotecas/paquete_salas.jsonl"))
	return p


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
## En las primeras etapas el margen es la mitad (etapa 1) y crece hasta el completo en la etapa 8; `etapa` 0 (el prototipo) usa el completo.
static func max_movimientos(pasos: int, nivel: String, etapa := 0, dif := "media") -> int:
	var idx := ["facil", "media", "dificil", "pesadilla"].find(nivel)
	var factores: Array = [1.9, 1.6, 1.4, 1.25]
	var extras: Array = [10, 8, 6, 5]
	var k: float = factores[maxi(idx, 0)]
	var extra: int = extras[maxi(idx, 0)]
	var s := 1.0 if etapa <= 0 else lerpf(0.5, 1.0, clampf(float(etapa - 1) / 7.0, 0.0, 1.0))
	s *= float(MARGEN_DIFICULTAD.get(dif, 1.0))
	return int(ceil(pasos * (1.0 + (k - 1.0) * s))) + int(round(float(extra) * s))


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
static func armar(paquete: Array, semilla: int, n := 6, espiral := true, etapa_run := 0, dificultad := "media"):
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var info := _info(paquete)
	var ctx := {"rng": rng, "info": info, "n": n, "elegidas": [], "usadas": {}, "presupuesto": 6000, "sentido": 1.0 if rng.randf() < 0.5 else -1.0, "espiral": espiral, "etapa": etapa_run, "dif": dificultad}
	var ok := _extender(ctx, 0)
	if not ok and espiral:
		ctx = {"rng": rng, "info": info, "n": n, "elegidas": [], "usadas": {}, "presupuesto": 6000, "sentido": 1.0, "espiral": false, "etapa": etapa_run, "dif": dificultad}
		ok = _extender(ctx, 0)
	var t = load("res://torre/torre.gd").new()
	t.etapa = etapa_run
	t.dificultad = dificultad
	var off := 0
	for e in ctx.elegidas:
		var g: Dictionary = e.d
		e["off"] = off
		e["max_mov"] = max_movimientos(int(g.pasos), str(g.nivel), etapa_run, dificultad)
		t.salas.append(e)
		off += int(g.meta) - 1   # la entrada de la siguiente (nivel 1) queda en el nivel de salida de ésta
	if not t.salas.is_empty():
		t._entrar(0)
	return t


## Cuántas salas tiene la torre de una etapa: de 5 en la primera a 14 en la última.
static func salas_de_etapa(etapa_run: int) -> int:
	return int(round(lerpf(5.0, 14.0, clampf(float(etapa_run - 1) / float(ETAPAS - 1), 0.0, 1.0))))


## Niveles de dificultad que admite la sala `i` de `n` en la etapa dada: la etapa sube la dificultad de toda la torre y, dentro de ella, cada sala es más difícil que la anterior.
static func niveles_para(i: int, n: int, etapa_run: int, dif := "media") -> Array:
	var p := clampf(float(etapa_run - 1) / float(ETAPAS - 1), 0.0, 1.0) * 0.6 + (float(i) / float(maxi(n - 1, 1))) * 0.4
	p = p * float(PENDIENTE_DIFICULTAD.get(dif, [1.0, 0.0])[0]) + float(PENDIENTE_DIFICULTAD.get(dif, [1.0, 0.0])[1])   # (la dificultad del run corre toda la curva)
	if p < 0.2:
		return ["facil"]
	if p < 0.4:
		return ["facil", "media"]
	if p < 0.6:
		return ["media"]
	if p < 0.75:
		return ["media", "dificil"]
	if p < 0.9:
		return ["dificil"]
	return ["dificil", "pesadilla"]


## Las primeras torres enseñan: salas bajas, cortas y con un solo bloque que mover; después se suman pisos y bloques. Devuelve {pisos, pasos, distintos} máximos
## (vacío = sin límite). La etapa 1 sube de a poco, y las etapas 2 a 4 son escalones más; desde la 5 manda sólo la curva de dificultad.
static func limites_aprendizaje(etapa_run: int, i: int, n: int, dif := "media") -> Dictionary:
	if dif == "pesadilla":
		return {}   # (quien elige Pesadilla ya sabe jugar)
	if dif == "dificil":
		return {"pisos": 8, "pasos": 18, "distintos": 2} if etapa_run == 1 else {}
	if etapa_run == 1:
		if i < 2:
			return {"pisos": 5, "pasos": 10, "distintos": 1}
		if i < 4:
			return {"pisos": 6, "pasos": 12, "distintos": 1}
		return {"pisos": 7, "pasos": 15, "distintos": 2}
	if etapa_run == 2:
		return {"pisos": 8, "pasos": 16, "distintos": 2}
	if etapa_run == 3:
		return {"pisos": 11, "pasos": 20, "distintos": 3}
	if etapa_run == 4:
		return {"pisos": 15, "pasos": 28, "distintos": 4}
	if etapa_run == 5 and dif == "facil":
		return {"pisos": 18, "pasos": 34, "distintos": 4}
	return {}


## ¿Entra la sala en los límites de aprendizaje?
static func dentro_de_limites(d: Dictionary, lim: Dictionary) -> bool:
	if lim.is_empty():
		return true
	return int(d.get("pisos", int(d.meta) - 1)) <= int(lim.pisos) and int(d.pasos) <= int(lim.pasos) and int(d.get("distintos", 1)) <= int(lim.distintos)


## ¿Todos los especiales de la sala están habilitados en esa etapa?
static func especiales_habilitados(d: Dictionary, etapa_run: int) -> bool:
	for b in d.bloques:
		var l := str(b[3]).substr(0, 1)
		if l == "d":
			l = "b"
		if ETAPA_ESPECIAL.has(l) and etapa_run < int(ETAPA_ESPECIAL[l]):
			return false
	return true


## Busca (con vuelta atrás) la sala número i y las que siguen. Devuelve true si se armaron las n.
static func _extender(ctx: Dictionary, i: int) -> bool:
	if i >= ctx.n:
		return true
	var rng: RandomNumberGenerator = ctx.rng
	var niveles: Array = CURVA[mini(i, CURVA.size() - 1)] if int(ctx.etapa) <= 0 else niveles_para(i, int(ctx.n), int(ctx.etapa), str(ctx.dif))
	var info: Array = ctx.info
	var orden: Array = []
	for k in info.size():
		var d: Dictionary = info[k].d
		if ctx.usadas.has(int(d.id)):
			continue
		if i < 2 and str(d.get("categoria", "base")) != "base":
			continue   # (las dos primeras salas son de bloques comunes)
		if int(ctx.etapa) > 0 and not especiales_habilitados(d, int(ctx.etapa)):
			continue
		if not dentro_de_limites(d, limites_aprendizaje(int(ctx.etapa), i, int(ctx.n), str(ctx.dif))):
			continue
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


## Una torre con salas ya armadas (las lecciones del tutorial): `salas_d` son salas en el formato del paquete; no se encadenan ni se colocan en el anillo y no tienen temporizador.
static func desde_salas(salas_d: Array, etapa_run := 0, dificultad_run := "media"):
	var t = load("res://torre/torre.gd").new()
	t.etapa = etapa_run
	t.dificultad = dificultad_run
	var off := 0
	for d in salas_d:
		t.salas.append({"d": d, "id": int(d.get("id", 0)), "off": off, "max_mov": 99999})
		off += int(d.meta) - 1
	if not t.salas.is_empty():
		t._entrar(0)
	return t


## Una copia de la torre con las mismas salas (el bot arma un banco de torres una vez y juega copias; las salas no se modifican al jugar).
static func copia(o):
	var t = load("res://torre/torre.gd").new()
	t.salas = o.salas
	t.etapa = o.etapa
	t.dificultad = o.dificultad
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


## Los boosts del run que actúan sobre el temporizador de movimientos de cada sala.
func aplicar_boosts(ids: Array) -> void:
	perks = {}
	for id in ids:
		perks[id] = true
	cosecha.aplicar_boosts(ids)
	if motor != null:
		motor.luz_propia = perks.has("luz_propia")


## Movimientos que tiene la sala actual: el margen sobre el mínimo, y con Madrugada (x1,25), Aire extra (+4) y lo que sumaron Freno y Reloj de arena.
func max_mov() -> int:
	var m := float(salas[indice].max_mov)
	if perks.has("madrugada"):
		m *= 1.25
	if perks.has("aire_extra"):
		m += 4.0
	return int(ceil(m)) + mov_extra + mov_run


func _entrar(i: int) -> void:
	indice = i
	motor = Vista.motor_de(salas[i].d)
	motor.luz_propia = cosecha.perks.has("luz_propia")
	if i + 1 < salas.size():   # (los bloques de la sala de arriba que quedan al alcance de ésta)
		motor.agregar_obstaculos(obstaculos_de(salas[i + 1].d, int(salas[i].d.meta)))
	movs = 0
	mov_extra = 0
	t0_sala = Time.get_ticks_msec()
	deshacer_pila.clear()
	encendidos = {}
	if perks.has("reflejos"):   # las bombas empiezan 3 movimientos más altas
		for c in motor.bloques:
			var tp := str(motor.bloques[c])
			if tp.length() >= 2 and tp[0] == "b":
				motor.bloques[c] = "b%d" % (int(tp.substr(1)) + 3)
	for c in motor.bloques:
		if str(motor.bloques[c]) == "p":
			encendidos[c] = true


## Una acción del jugador. Devuelve { ok, msg, evento }: evento = "" | "checkpoint" | "muerte" | "torre" | "fin".
func actuar(dir: Vector3i, modo: int) -> Dictionary:
	ultima_caida = -1
	if terminada or perdida or muerta:
		return {"ok": false, "msg": "", "evento": ""}
	var antes_y: int = motor.jugador.y
	var foto := {"motor": motor.duplicar(), "movs": movs, "cosecha": cosecha.estado(), "encendidos": encendidos.duplicate()}
	var r: Dictionary = motor.actuar(dir, modo)
	if not r.ok:
		r["evento"] = ""
		return r
	deshacer_pila.append(foto)
	if deshacer_pila.size() > DESHACER_MAX:
		deshacer_pila.pop_front()
	if not (perks.has("paso_firme") and not motor.agarro and absi(motor.jugador.y - antes_y) == 1):   # Paso firme: trepar y bajar un piso no gasta movimiento
		movs += 1
	movs_total += 1
	cosecha.despues_de_accion(motor.ultimos_purificados, motor.agarro, int(salas[indice].off) + motor.jugador.y)
	if motor.ganado:
		ultima_sala = _info_sala("ganada", "")
		muertes_sala = 0
		cosecha.asegurar()
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
		return _morir("Se acabaron los movimientos")
	r["evento"] = ""
	return r


## La sala se pierde por algo que decide el juego (por ejemplo el último movimiento en falso de Sin piedad): cuenta como una muerte.
## Reintentar la sala perdida: vuelve a su checkpoint con la sala virgen.
## Empieza en el checkpoint de la sala `i` (al continuar una partida guardada), con la claridad asegurada hasta ahí.
func saltar_a_sala(i: int, banco: int) -> void:
	if i <= 0 or i >= salas.size():
		return
	cosecha.banco = banco
	cosecha.sala = 0
	_entrar(i)


func reintentar_sala() -> void:
	muerta = false
	_entrar(indice)


func forzar_muerte(motivo: String) -> Dictionary:
	if terminada or perdida:
		return {"ok": false, "msg": "", "evento": ""}
	return _morir(motivo)


## Lo que pasó en la sala actual (para la telemetría y el bot): cuál era, cuánto costó y cómo terminó.
func _info_sala(resultado: String, causa: String) -> Dictionary:
	var s: Dictionary = salas[indice]
	var d: Dictionary = s.d
	return {"resultado": resultado, "causa": causa, "indice": indice, "total": salas.size(), "id": int(s.id), "nivel": str(d.nivel), "tipo": str(d.tipo), "pisos": int(d.meta) - 1,
		"categoria": str(d.get("categoria", "base")), "pasos_minimos": int(d.pasos), "movs": movs, "max_mov": max_mov(), "muertes_previas": muertes_sala,
		"segundos": int((Time.get_ticks_msec() - t0_sala) / 1000), "claridad": cosecha.sala}


func _morir(motivo: String) -> Dictionary:
	ultima_sala = _info_sala("perdida", motivo)
	muertes_sala += 1
	cosecha.perder_intento()
	if perks.has("segundo_aliento") and not aliento_usado:   # Segundo aliento: una vez por torre se vuelve a empezar la sala sin perder la vida
		aliento_usado = true
		_entrar(indice)
		return {"ok": true, "msg": motivo, "evento": "aliento"}
	muertes += 1
	if externo:   # (las vidas las lleva el juego: la sala queda perdida hasta que el juego la reinicie con reintentar_sala)
		muerta = true
		return {"ok": true, "msg": motivo, "evento": "muerte"}
	vidas -= 1
	if vidas <= 0:
		perdida = true
		return {"ok": true, "msg": motivo, "evento": "fin"}
	_entrar(indice)   # vuelve al checkpoint con la sala virgen
	return {"ok": true, "msg": motivo, "evento": "muerte"}


## Deshace el último movimiento de la sala actual (con lo que se había juntado y la cuenta de movimientos). false si no hay nada que deshacer.
func deshacer() -> bool:
	if deshacer_pila.is_empty() or terminada or perdida or muerta:
		return false
	var f: Dictionary = deshacer_pila.pop_back()
	motor = f.motor
	movs = int(f.movs)
	cosecha.restaurar(f.cosecha)
	encendidos = f.encendidos
	return true


## Un consumible del run. Devuelve { ok, msg }. No gasta un movimiento. Los que no tienen sentido en la torre (o todavía no están) devuelven ok = false y no se gastan.
func usar_item(id: String) -> Dictionary:
	if terminada or perdida or muerta:
		return {"ok": false, "msg": ""}
	var pila_antes := deshacer_pila.duplicate()
	var r := _usar_item(id)
	if bool(r.ok):
		deshacer_pila.clear()   # (lo que hizo un consumible no se deshace: no se puede volver atrás de él)
	else:
		deshacer_pila = pila_antes
	return r


func _usar_item(id: String) -> Dictionary:
	match id:
		"pocion_de_cosecha":
			if cosecha.harvest_potion:
				return {"ok": false, "msg": "Ya tienes la cosecha doble en esta torre"}
			cosecha.harvest_potion = true
			return {"ok": true, "msg": "Poción de cosecha: la claridad de esta torre vale el doble"}
		"baraja_de_racha":
			cosecha.streak = maxi(cosecha.streak, 7)
			return {"ok": true, "msg": "Racha ×4"}
		"freno":
			mov_extra += 5
			return {"ok": true, "msg": "Freno: 5 movimientos más en esta sala"}
		"reloj_de_arena":
			mov_extra += 10
			return {"ok": true, "msg": "Reloj de arena: 10 movimientos más en esta sala"}
		"iman_de_luz", "lluvia_de_luz":
			var celdas: Array = []
			for c in motor.bloques:
				var d: Vector3i = c - motor.jugador
				if id == "iman_de_luz":
					if d.x * d.x + d.y * d.y + d.z * d.z <= 4:
						celdas.append(c)
				elif c.y == motor.jugador.y - 1:
					celdas.append(c)
			var letras: Array = motor.purificar_celdas(celdas)
			if letras.is_empty():
				return {"ok": false, "msg": "No hay nada por purificar"}
			var got: int = cosecha.extra(letras)
			return {"ok": true, "msg": "+%d de claridad (%d bloques)" % [got, letras.size()]}
		"desarmar":
			var mejor := Vector3i(-999, -999, -999)
			var mejor_d := 1 << 30
			for c in motor.bloques:
				var tp := str(motor.bloques[c])
				if tp.length() >= 2 and tp[0] == "b":
					var dd: Vector3i = (c - motor.jugador).abs()
					if dd.x + dd.y + dd.z < mejor_d:
						mejor_d = dd.x + dd.y + dd.z
						mejor = c
			if mejor_d == 1 << 30:
				return {"ok": false, "msg": "No hay bombas para desarmar"}
			motor.bloques[mejor] = "d"
			return {"ok": true, "msg": "Bomba desarmada"}
	return {"ok": false, "msg": "Todavía no funciona en la torre"}
