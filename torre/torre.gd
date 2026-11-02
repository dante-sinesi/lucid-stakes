extends RefCounted
## La torre de salas sin núcleo, lista para jugar (prototipo, aislado del juego actual): arma una torre apilando salas del paquete
## (herramientas/sumar_salas.py) y lleva la partida con las reglas de docs/reglas_torre.md: checkpoints, temporizador de movimientos
## (el mínimo del solucionador más un margen), caída de la sala entera al agotarse, vidas y vuelta al checkpoint con la sala virgen.
##
## Cada sala se juega con su propio Motor (torre/motor.gd) en las coordenadas del anillo de 11 x 11. La salida de una sala (el bloque
## fijo "f", el ancla) es la misma celda que la entrada de la siguiente ("p", un nivel más arriba de la siguiente sala), así que mientras se
## juega una sala las de arriba son decorado anclado: nada de lo que pasa en la sala actual las toca. Al llegar a la salida la sala anterior cae.

const Vista := preload("res://torre/vista.gd")
const Motor := preload("res://torre/motor.gd")
const Cosecha := preload("res://torre/cosecha.gd")
const RunState := preload("res://scripts/datos/run_state.gd")

const LADO := 11
static var rechazos_choque := 0   # (estadística: placements descartados porque la sala de arriba tapaba el camino de la de abajo)
static var aceptados := 0
const VIDAS := 3
## Niveles de dificultad que admite cada sala de la torre (la curva sube de a poco); las dos primeras son de bloques comunes (se aprende a jugar).
const CURVA := [["facil"], ["facil", "media"], ["media"], ["media", "dificil"], ["dificil"], ["dificil", "pesadilla"]]
const ETAPAS := 15

## Las salas demasiado sencillas (una escalera casi directa donde sólo hay que tirar de un bloque y seguir) no entran en las torres. El filtro mira cuántos bloques distintos mueve la solución
## de la sala: "A" pide al menos 2; "B" (el de siempre) pide además más cuanto más alta es la sala (un bloque más cada 3 pisos); "ninguno" no filtra (sólo para comparar). Para probar otro se
## define la variable de entorno SALAS_FILTRO con una de esas tres palabras.
const FILTRO_A := "A"
const FILTRO_B := "B"
const FILTRO_NINGUNO := "ninguno"
const MUESTRA_SALAS := 1500   # cuántas candidatas se puntúan por sala al armar una torre
static var _paquete_juego: Array = []   # la biblioteca del juego, ya leída (se lee una sola vez)
static var _info_de: Array = []   # el paquete del que se calculó `_info_cache` (para reconocerlo)
static var _info_n := 0
static var _info_cache: Array = []
static var filtro_sencillas := _filtro_por_omision()


static func _filtro_por_omision() -> String:
	var v := OS.get_environment("SALAS_FILTRO")
	if v.to_lower() == "a":
		return FILTRO_A
	if v.to_lower() == "ninguno":
		return FILTRO_NINGUNO
	return FILTRO_B


## Los bloques distintos que como mínimo tiene que mover la solución de una sala de `pisos` pisos con el filtro `modo` (0 = sin mínimo).
static func minimo_distintos(pisos: int, modo := filtro_sencillas) -> int:
	if modo == FILTRO_A:
		return 2
	if modo == FILTRO_B:
		return maxi(2, int(round(float(pisos) / 3.0)))
	return 0
## Cómo corre la dificultad del run la curva de niveles de las salas: p' = p * a + b (p va de 0 a 1 a lo largo de las 15 etapas). Fácil no pasa de salas medias; Pesadilla arranca en medias y termina en pesadillas.
## Cuántas salas tiene cada torre (todas igual: la dificultad la ponen las salas, no el largo).
const SALAS_POR_TORRE := 7
## La dificultad que busca una sala, en bits de complejidad (ver docs/generador.md), según su progreso `p` (0 a 1: etapa y lugar en la torre): [p, bits].
const BITS_OBJETIVO := [[0.0, 12.0], [0.1, 20.0], [0.2, 32.0], [0.4, 58.0], [0.6, 85.0], [0.75, 110.0], [0.9, 150.0], [1.0, 190.0]]
## Los bits típicos de cada nivel (para una sala del paquete que no trae su complejidad medida).
const BITS_DEL_NIVEL := {"facil": 31.0, "media": 83.0, "dificil": 136.0, "pesadilla": 214.0}
const PENDIENTE_DIFICULTAD := {"facil": [0.55, 0.0], "media": [1.0, 0.0], "dificil": [0.75, 0.25], "pesadilla": [0.5, 0.5]}
## Cuánto cambia el margen de movimientos de cada sala (el que pasa del mínimo).
const MARGEN_DIFICULTAD := {"facil": 1.25, "media": 0.75, "dificil": 0.65, "pesadilla": 0.5}   # (Fácil no tiene límite: ese número no se usa)

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
var dificultad := "media"     # la dificultad elegida para el run: fácil, media, difícil o pesadilla (ver `progreso`)
var etapa := 0                # 0: curva fija de prueba; si no, la etapa del run (sube la dificultad y se habilitan los especiales de a poco)
var externo := false          # las vidas son las del run (las lleva el juego): morir reinicia la sala y avisa, pero no resta
var perks := {}               # boosts del run
var reglas := {}              # las reglas de la torre (las del escenario y las de la prueba): Solo tres bloques, Quebradizo, Espalda mala, Presupuesto compartido... (ver trials.gd)
var presupuesto_total := 0    # Presupuesto compartido: los movimientos de toda la torre son un solo fondo (0: cada sala tiene los suyos)
var gastado_antes := 0        # Presupuesto compartido: lo que gastaron las salas que ya se superaron
var _temblores: Array = []    # Terremoto: los corrimientos de la sala actual ({en: acciones que llevaba, id: del bloque, delta}), para comprobar que la solución conocida siga andando
var mov_run := 0              # movimientos de más en cada sala por mejoras permanentes del run (Aire de más, Pies ligeros)
var mov_extra := 0            # movimientos de más para la sala actual (Freno, Reloj de arena)
var aliento_usado := false    # Segundo aliento: una vez por torre
var movs_total := 0           # movimientos de toda la torre (incluidos los de los intentos perdidos)
var muertes_sala := 0         # veces que se perdió la sala actual
var t0_sala := 0              # cuándo empezó el intento actual de la sala (ms)
var ultima_sala := {}         # lo que pasó en la última sala que terminó (superada o perdida): lo usa la telemetría
var muerta := false           # (con las vidas del run) se perdió la sala y espera a que el juego decida: reintentar o salir
var deshacer_pila: Array = []  # fotos de la sala actual antes de cada movimiento (para deshacer)
var _deshacer_resto := 0      # deshacer devuelve la mitad de lo que costó el movimiento: si quedó medio movimiento sin devolver, se junta con el próximo
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
		if not bool(t.actuar(Vector3i(int(a[0]), 0, int(a[1])), int(a[2])).ok):
			return false   # (un paso que no se puede jugar: ni en la sala girada ni con la de arriba tapando; antes se ignoraba si igual se llegaba a la salida)
	return t.ganado


static var _quebradizas := {}   # id de sala -> la sala con sus bloques quebradizos (se arma una vez por sala)


## Quebradizo (docs/pruebas.md): los bloques comunes de la sala que su solución conocida pisa una sola vez (y nunca mueve después) se vuelven agrietados: se rompen en cuanto te bajas de ellos. Los que la solución
## necesita más de una vez siguen siendo piedra común, así la sala se puede resolver siempre (y se ve cuáles son cuáles). Si la sala con los cambios no anda, queda como estaba.
static func quebrar(d: Dictionary) -> Dictionary:
	var id := int(d.get("id", -1))
	if id >= 0 and _quebradizas.has(id):
		return _quebradizas[id]
	var m = Vista.motor_de(d)   # (los bloques se numeran en el orden de `d.bloques`)
	var episodios := {}   # cuántas veces la solución se para en cada bloque (cada vez que llega a él desde otro lugar)
	var movidos := {}     # los bloques que la solución empuja o tira
	var ultimo := _piso_de(m)
	if ultimo >= 0:
		episodios[ultimo] = 1
	for a in d.get("camino", []):
		m.actuar(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
		for c in m.ultimos_movidos:
			if m.ids.has(c):
				movidos[m.ids[c]] = true
		var p := _piso_de(m)
		if p >= 0 and p != ultimo:
			episodios[p] = int(episodios.get(p, 0)) + 1
		ultimo = p
	var nueva := d.duplicate(true)
	for i in nueva.bloques.size():
		var b: Array = nueva.bloques[i]
		if str(b[3]) == "n" and int(episodios.get(i, 0)) <= 1 and not movidos.has(i):
			b[3] = "c"
	var resultado: Dictionary = nueva if camino_ok(nueva) else d
	if id >= 0:
		_quebradizas[id] = resultado
	return resultado


## El número del bloque sobre el que está parado el motor (-1 si está colgado o en el aire).
static func _piso_de(m) -> int:
	if m.colgado != Vector3i.ZERO:
		return -1
	return int(m.ids.get(m.jugador + Vector3i(0, -1, 0), -1))


## A oscuras: qué bloques de la sala se ven negros hasta que se pisan (más de la mitad de los bloques; nunca el checkpoint ni la salida): {número de bloque: true}.
static func oscuros_de(m, id_sala: int) -> Dictionary:
	var comunes := 0
	var especiales := 0
	for c in m.bloques:
		var letra := str(m.bloques[c])
		if letra == "f" or letra == "p" or letra == "d" or (letra.length() >= 2 and letra[0] == "b") or m.obstaculos.has(c):
			continue
		if letra == "n":
			comunes += 1
		else:
			especiales += 1
	# se esconde sobre todo lo especial (hielo, pesados, agrietados, trampas, pinchos, catapultas): casi todos; y de los comunes, los que hacen falta para llegar a más de la mitad de la sala (pero nunca menos del 25 %)
	var p_especial := 90
	var p_comun := 55
	if comunes > 0:
		p_comun = clampi(int(round((0.55 * float(comunes + especiales) - 0.9 * float(especiales)) / float(comunes) * 100.0)), 25, 55)
	var out := {}
	for c in m.bloques:
		var letra := str(m.bloques[c])
		if letra == "f" or letra == "p" or letra == "d" or (letra.length() >= 2 and letra[0] == "b") or m.obstaculos.has(c):
			continue   # (los checkpoint, las bombas y las desactivadas se ven siempre: la bomba tiene su cuenta)
		var h := absi(c.x * 73856093 ^ c.y * 19349663 ^ c.z * 83492791 ^ id_sala * 2654435761) % 100
		if h < (p_comun if letra == "n" else p_especial) and m.ids.has(c):
			out[m.ids[c]] = true
	return out


# --- armado ---

## Como `camino_ok`, pero un movimiento que no se puede hacer corta el camino (el de una variante del gato tiene que andar entero).
static func camino_estricto(d: Dictionary, obstaculos: Array = []) -> bool:
	var t = Vista.motor_de(d)
	t.agregar_obstaculos(obstaculos)
	for a in d.get("camino", []):
		if not t.actuar(Vector3i(int(a[0]), 0, int(a[1])), int(a[2])).ok:
			return false
	return t.ganado


# --- la prueba Travesuras (Ama, docs/gatito_travieso.md): los cambios seguros de cada sala se calcularon antes (herramientas/variantes_gato.py) y viajan en data/variantes_gato.jsonl ---

const DIRS_VARIANTE := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
static var _variantes := {}
static var _variantes_cargadas := false


## Las variantes de una sala de la biblioteca (por su id): [{k, mov: [[x, y, z, nx, nz]...], pasos, agarres, distintos, camino (texto)}]; [] si no tiene.
static func variantes_de(id: int) -> Array:
	if not _variantes_cargadas:
		_variantes_cargadas = true
		var f := FileAccess.open("res://data/variantes_gato.jsonl", FileAccess.READ)
		if f != null:
			while not f.eof_reached():
				var l := f.get_line().strip_edges()
				if l == "":
					continue
				var r = JSON.parse_string(l)
				if r is Dictionary and not (r.variantes as Array).is_empty():
					_variantes[int(r.id)] = r.variantes
	return _variantes.get(id, [])


## El camino de una variante (una letra por acción: 'a' + modo * 4 + índice de DIRS_VARIANTE) como lista de [dx, dz, modo].
static func decodificar_camino(texto: String) -> Array:
	var out: Array = []
	for i in texto.length():
		var a := texto.unicode_at(i) - 97
		var dir: Vector2i = DIRS_VARIANTE[a % 4]
		out.append([dir.x, dir.y, a / 4])
	return out


## El paquete de salas que viaja con el juego (data/salas_torre.jsonl); si no está, el de bibliotecas/ (desarrollo).
static func cargar_paquete_del_juego() -> Array:
	if not _paquete_juego.is_empty():   # (se lee una sola vez por partida: son más de 11 mil salas)
		return _paquete_juego
	var p := cargar_paquete("res://data/salas_torre.jsonl")
	if p.is_empty():
		p = cargar_paquete(ProjectSettings.globalize_path("res://bibliotecas/paquete_salas.jsonl"))
	_paquete_juego = p
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
static func max_movimientos(pasos: int, nivel: String, etapa := 0, dif := "media", margen_escenario := 1.0) -> int:
	var idx := ["facil", "media", "dificil", "pesadilla"].find(nivel)
	var factores: Array = [1.9, 1.6, 1.4, 1.25]
	var extras: Array = [10, 8, 6, 5]
	var k: float = factores[maxi(idx, 0)]
	var extra: int = extras[maxi(idx, 0)]
	var s := 1.0 if etapa <= 0 else lerpf(0.5, 1.0, clampf(float(etapa - 1) / 7.0, 0.0, 1.0))
	s *= float(MARGEN_DIFICULTAD.get(dif, 1.0)) * margen_escenario   # (Relojería recorta el margen)
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


## Datos de cada sala del paquete que no cambian al girarla: entrada, salida y huella (y si es de bloques comunes y cuántos bloques distintos mueve, para no volver a mirarlo en cada búsqueda).
## Se calcula una vez por paquete (el mismo arreglo): armar una torre no vuelve a recorrerlo.
static func _info(paquete: Array) -> Array:
	if _info_n == paquete.size() and is_same(_info_de, paquete):
		return _info_cache
	var out: Array = []
	for d in paquete:
		out.append({"d": d, "e": entrada_xz(d), "x": salida_xz(d), "r": huella(d), "base": str(d.get("categoria", "base")) == "base", "dist": int(d.get("distintos", 99)),
				"pisos": int(d.get("pisos", int(d.meta) - 1))})
	_info_de = paquete
	_info_n = paquete.size()
	_info_cache = out
	return out


static func _rect_sim(r: Rect2i, s: int) -> Rect2i:
	var a := xz_sim(r.position.x, r.position.y, s)
	var b := xz_sim(r.position.x + r.size.x - 1, r.position.y + r.size.y - 1, s)
	return Rect2i(mini(a.x, b.x), mini(a.y, b.y), absi(a.x - b.x) + 1, absi(a.y - b.y) + 1)


## Arma una torre de `n` salas con la curva de dificultad CURVA (si n es mayor se repite el último tramo). Cada sala se gira o espeja y se desliza por el anillo
## hasta que su entrada caiga en la salida de la anterior; con `espiral` la torre da vueltas siempre hacia el mismo lado (cada sala sigue por delante de la anterior).
## Si no se puede con espiral se arma sin esa condición. Devuelve un Torre; si no pudo encadenar una sala queda más corta.
## `reglas`: las reglas del escenario que importan acá (`peso_especiales`: la fracción de las salas que tienen
## especiales, entre las que se puedan poner; `margen_mov`: lo que multiplica el margen de movimientos); {} = las de siempre.
static func armar(paquete: Array, semilla: int, n := 6, espiral := true, etapa_run := 0, dificultad := "media", reglas := {}):
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var info := _info(paquete)
	var ctx := {"rng": rng, "info": info, "n": n, "elegidas": [], "usadas": {}, "presupuesto": 6000, "sentido": 1.0 if rng.randf() < 0.5 else -1.0, "espiral": espiral, "etapa": etapa_run, "dif": dificultad, "reglas": reglas}
	var ok := _extender(ctx, 0)
	if not ok and espiral:
		ctx = {"rng": rng, "info": info, "n": n, "elegidas": [], "usadas": {}, "presupuesto": 6000, "sentido": 1.0, "espiral": false, "etapa": etapa_run, "dif": dificultad, "reglas": reglas}
		ok = _extender(ctx, 0)
	var t = load("res://torre/torre.gd").new()
	t.etapa = etapa_run
	t.dificultad = dificultad
	var off := 0
	for e in ctx.elegidas:
		var g: Dictionary = e.d
		e["off"] = off
		var costo := int(g.pasos) + (int(g.get("agarres", 0)) if bool(reglas.get("espalda_mala", false)) else 0)   # (Espalda mala: cada agarre de la solución cuesta uno de más)
		e["max_mov"] = max_movimientos(costo, str(g.nivel), etapa_run, dificultad, float(reglas.get("margen_mov", 1.0)))
		t.salas.append(e)
		off += int(g.meta) - 1   # la entrada de la siguiente (nivel 1) queda en el nivel de salida de ésta
	t.reglas = reglas
	if bool(reglas.get("presupuesto", false)):   # la prueba "Presupuesto compartido": un solo fondo para toda la torre (el de las salas, un poco recortado, pero nunca menos que sus mínimos con un margen)
		var suma_max := 0
		var suma_pasos := 0
		for e in t.salas:
			suma_max += int(e.max_mov)
			suma_pasos += int(e.d.pasos) + (int(e.d.get("agarres", 0)) if bool(reglas.get("espalda_mala", false)) else 0)   # (con Espalda mala cada agarre de la solución cuesta uno más)
		var margen := float({"facil": 1.45, "media": 1.25, "dificil": 1.15, "pesadilla": 1.08}.get(dificultad, 1.25))   # (el fondo sólo da un poco más que los mínimos: hay que ir casi sin errores)
		t.presupuesto_total = mini(int(ceil(float(suma_pasos) * margen)) + t.salas.size(), suma_max)
	if bool(reglas.get("travesuras", false)):   # la prueba "Travesuras": cada sala trae (si se puede) lo que va a mover Ama
		t._poner_gatos(semilla, reglas)
	if not t.salas.is_empty():
		t._entrar(0)
	return t


## Cuántas salas tiene la torre de una etapa (las mismas en todas).
static func salas_de_etapa(_etapa_run: int) -> int:
	return SALAS_POR_TORRE


## El progreso de la sala `i` de `n` en la etapa dada, de 0 a 1: la etapa sube toda la torre y, dentro de ella, cada sala es más difícil que la anterior (más en las etapas altas:
## las primeras torres casi no suben dentro de sí). La dificultad del run corre toda la curva.
static func progreso(i: int, n: int, etapa_run: int, dif := "media") -> float:
	var f := clampf(float(etapa_run - 1) / float(ETAPAS - 1), 0.0, 1.0)
	var dentro := float(i) / float(maxi(n - 1, 1)) * 0.4 * (0.35 + 0.65 * f)
	var pd: Array = PENDIENTE_DIFICULTAD.get(dif, [1.0, 0.0])
	return (f * 0.6 + dentro) * float(pd[0]) + float(pd[1])


## Los bits de complejidad que busca una sala con ese progreso (la curva BITS_OBJETIVO, continua).
static func bits_objetivo(p: float) -> float:
	var q := clampf(p, 0.0, 1.0)
	for k in range(1, BITS_OBJETIVO.size()):
		var a: Array = BITS_OBJETIVO[k - 1]
		var b: Array = BITS_OBJETIVO[k]
		if q <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (q - float(a[0])) / (float(b[0]) - float(a[0])))
	return float(BITS_OBJETIVO[BITS_OBJETIVO.size() - 1][1])


## Qué tan lejos está una sala de lo que se busca (0 = justo): la distancia en bits (relativa), más un castigo suave si mueve más bloques distintos o necesita más pasos de lo que
## corresponde a ese progreso (las primeras torres enseñan: pocos bloques y salas cortas; después los topes se aflojan solos, sin saltos).
static func distancia_a_objetivo(d: Dictionary, objetivo: float, p: float) -> float:
	var bits := float(d.get("complejidad", BITS_DEL_NIVEL.get(str(d.get("nivel", "media")), 83.0)))
	var s := absf(bits - objetivo) / maxf(objetivo, 25.0)
	s += maxf(float(d.get("distintos", 1)) - (1.0 + 14.0 * p), 0.0) * 0.5
	s += maxf(float(d.pasos) - (9.0 + 90.0 * p), 0.0) * 0.03
	return s


## Las candidatas con las preferidas primero (con especiales o sin ellos), sin cambiar el orden entre las del mismo grupo.
static func _preferir(lista: Array, info: Array, con_especiales: bool) -> Array:
	var primero: Array = []
	var despues: Array = []
	for k in lista:
		var tiene := str(info[k].d.get("categoria", "base")) != "base"
		(primero if tiene == con_especiales else despues).append(k)
	return primero + despues


## Busca (con vuelta atrás) la sala número i y las que siguen. Devuelve true si se armaron las n.
static func _extender(ctx: Dictionary, i: int) -> bool:
	if i >= ctx.n:
		return true
	var rng: RandomNumberGenerator = ctx.rng
	var info: Array = ctx.info
	var con_etapa: bool = int(ctx.etapa) > 0
	var niveles: Array = [] if con_etapa else CURVA[mini(i, CURVA.size() - 1)]
	var p := progreso(i, int(ctx.n), int(ctx.etapa), str(ctx.dif)) if con_etapa else 0.0
	var objetivo := bits_objetivo(p)
	var orden: Array = []
	var modo := filtro_sencillas
	for k in info.size():
		var inf: Dictionary = info[k]
		var d: Dictionary = inf.d
		if ctx.usadas.has(int(d.id)):
			continue
		if i < 2 and not inf.base:
			continue   # (las dos primeras salas son de bloques comunes)
		if int(inf.dist) < minimo_distintos(int(inf.pisos), modo):
			continue   # (una escalera donde sólo hay que tirar de un bloque no es un puzzle: ver el filtro de salas sencillas)
		if int(ctx.reglas.get("solo_bloques", -1)) >= 0 and (int(d.get("distintos", 99)) > int(ctx.reglas.solo_bloques) or int(d.get("distintos", 0)) < int(ctx.reglas.solo_bloques) - 1):
			continue   # (Solo tres bloques: sólo salas cuya solución conocida mueve dos o tres bloques distintos: se pueden resolver con la regla y la regla se nota; con uno solo no cambiaría nada)
		if bool(ctx.reglas.get("terremoto", false)) and int(d.get("distintos", 1)) < 3:
			continue   # (Terremoto: sólo salas con al menos tres bloques que se mueven: con menos casi no hay nada que correr)
		if bool(ctx.reglas.get("espalda_mala", false)) and int(d.get("agarres", 0)) < 4:
			continue   # (Espalda mala: sólo salas en las que la solución empuja o tira al menos cuatro veces: si no, el doble costo casi no se nota)
		orden.append(k)
	if orden.size() > MUESTRA_SALAS:   # (con una biblioteca grande no se mira todo en cada sala: alcanza con una muestra al azar, de la que se eligen las más cercanas a lo que se busca)
		for k in MUESTRA_SALAS:
			var j := rng.randi_range(k, orden.size() - 1)
			var tmp = orden[k]
			orden[k] = orden[j]
			orden[j] = tmp
		orden.resize(MUESTRA_SALAS)
	var buenas: Array = []
	var otras: Array = []
	if con_etapa:   # primero las más cercanas a lo que busca esta sala (con un poco de azar para que no salgan siempre las mismas)
		var puntuadas: Array = []
		for k in orden:
			puntuadas.append([distancia_a_objetivo(info[k].d, objetivo, p) + rng.randf() * 0.3, k])
		puntuadas.sort_custom(func(x, y): return x[0] < y[0])
		for x in puntuadas:
			buenas.append(x[1])
	else:   # (sin etapa: la curva por niveles de siempre; primero las del nivel que toca, mezcladas, y después las otras)
		for k in range(orden.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var tmp = orden[k]
			orden[k] = orden[j]
			orden[j] = tmp
		for k in orden:
			(buenas if niveles.has(str(info[k].d.nivel)) else otras).append(k)
	var peso := float(ctx.reglas.get("peso_especiales", 0.0))
	if peso > 0.0 and i >= 2:   # Mundo abierto: se tira una moneda y esta sala sale, si se puede, con especiales o sin ellos (así la fracción de salas con especiales es `peso`)
		var con_especiales := rng.randf() < peso
		buenas = _preferir(buenas, info, con_especiales)
		otras = _preferir(otras, info, con_especiales)
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
			var g := mover(girar(quebrar(datos.d) if bool(ctx.reglas.get("quebradizo", false)) else datos.d, s), dx, dz)
			if not camino_ok(g):
				continue

			if i > 0:   # la sala nueva queda sobre la anterior: el camino de la anterior tiene que seguir andando con sus bloques al alcance
				var prev: Dictionary = ctx.elegidas[i - 1].d
				if not camino_ok(prev, obstaculos_de(g, int(prev.meta))):
					rechazos_choque += 1
					continue
			aceptados += 1
			ctx.elegidas.append({"d": g, "sim": s, "id": int(datos.d.id), "dx": dx, "dz": dz, "orig": datos.d})
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
	if perks.has("ahorro"):
		cosecha.banco += RunState.ahorro_inicial(maxi(etapa, 1))
	if perks.has("bolsillo_de_luz"):
		cosecha.banco += RunState.bolsillo_inicial(maxi(etapa, 1))
	if motor != null:
		motor.luz_propia = perks.has("luz_propia")


## Los movimientos que se dan en Fácil: sin límite.
const SIN_LIMITE := 999999


## Movimientos que tiene la sala actual: el margen sobre el mínimo, y con Madrugada (x1,25), Aire extra (+4) y lo que sumaron Freno y Reloj de arena. En Fácil no hay límite.
func max_mov() -> int:
	if dificultad == "facil":
		return SIN_LIMITE
	if presupuesto_total > 0:   # (Presupuesto compartido: lo que queda del fondo de toda la torre)
		return maxi(presupuesto_total - gastado_antes, 0) + mov_extra + mov_run
	var m := float(salas[indice].max_mov)
	if perks.has("madrugada"):
		m *= 1.25
	if perks.has("aire_extra"):
		m += 4.0
	return int(ceil(m)) + mov_extra + mov_run


## Lo que va a hacer el gato al entrar a la sala actual ({} si no hace nada o ya lo hizo): {d (la sala ya cambiada), mov: [[desde, hasta]...] (celdas de la sala), max_mov}.
func gato_pendiente() -> Dictionary:
	var e: Dictionary = salas[indice]
	return e.gato if e.has("gato") and not bool(e.get("gato_hecho", false)) else {}


## El gato ya movió los bloques: la sala pasa a ser la cambiada (con su límite de movimientos) y se entra de nuevo, sin haber jugado nada.
func aplicar_gato() -> void:
	var g := gato_pendiente()
	if g.is_empty():
		return
	var e: Dictionary = salas[indice]
	e["d"] = g.d
	e["max_mov"] = g.max_mov
	e["gato_hecho"] = true
	_entrar(indice)


## Elige para cada sala una variante del gato que se pueda jugar en la torre: los bloques movidos caen en el anillo y el camino anda entero con los bloques de la sala de arriba al alcance.
func _poner_gatos(semilla: int, reglas: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla * 31 + 17
	for i in salas.size():
		var e: Dictionary = salas[i]
		if not e.has("orig"):
			continue
		var vs: Array = variantes_de(int(e.id)).duplicate()
		for k in range(vs.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var tmp = vs[k]
			vs[k] = vs[j]
			vs[j] = tmp
		var obstaculos: Array = obstaculos_de(salas[i + 1].d, int(e.d.meta)) if i + 1 < salas.size() else []
		for v in vs:
			var g := _sala_con_gato(e, v)
			if g.is_empty() or not camino_estricto(g.d, obstaculos):
				continue
			e["gato"] = {"d": g.d, "mov": g.mov, "max_mov": max_movimientos(int(v.pasos), str(e.d.nivel), etapa, dificultad, float(reglas.get("margen_mov", 1.0)))}
			break


## La sala `e` de la torre con una variante del gato aplicada (en el sistema de la torre: girada y corrida como la sala), o {} si no se puede.
func _sala_con_gato(e: Dictionary, v: Dictionary) -> Dictionary:
	var vd: Dictionary = (e.orig as Dictionary).duplicate(true)
	var s := int(e.sim)
	var dx := int(e.dx)
	var dz := int(e.dz)
	var movs: Array = []
	for m in v.mov:
		var y := int(m[1])
		var hallado := false
		for b in vd.bloques:
			if int(b[0]) == int(m[0]) and int(b[1]) == y and int(b[2]) == int(m[2]) and str(b[3]) == "n":
				b[0] = int(m[3])
				b[2] = int(m[4])
				hallado = true
				break
		if not hallado:
			return {}
		var a := xz_sim(int(m[0]), int(m[2]), s) + Vector2i(dx, dz)
		var h := xz_sim(int(m[3]), int(m[4]), s) + Vector2i(dx, dz)
		if not es_anillo(a.x, a.y) or not es_anillo(h.x, h.y):
			return {}
		movs.append([Vector3i(a.x, y, a.y), Vector3i(h.x, y, h.y)])
	vd["camino"] = decodificar_camino(str(v.camino))
	vd["pasos"] = int(v.pasos)
	vd["agarres"] = int(v.agarres)
	vd["distintos"] = int(v.distintos)
	return {"d": mover(girar(vd, s), dx, dz), "mov": movs}


func _entrar(i: int) -> void:
	indice = i
	motor = Vista.motor_de(salas[i].d)
	motor.luz_propia = cosecha.perks.has("luz_propia")
	if i + 1 < salas.size():   # (los bloques de la sala de arriba que quedan al alcance de ésta)
		motor.agregar_obstaculos(obstaculos_de(salas[i + 1].d, int(salas[i].d.meta)))
	motor.limite_movibles = int(reglas.get("solo_bloques", -1))
	if bool(reglas.get("a_oscuras", false)):
		motor.oscuros = oscuros_de(motor, int(salas[i].id))
	movs = 0
	mov_extra = 0
	_temblores.clear()
	t0_sala = Time.get_ticks_msec()
	deshacer_pila.clear()
	_deshacer_resto = 0
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
		movs += 2 if (motor.agarro and bool(reglas.get("espalda_mala", false))) else 1   # (Espalda mala: empujar o tirar cuesta doble)
	movs_total += 1
	return _tras_efecto(r, true)


## Lo que pasa después de que algo movió al jugador o a un bloque (una acción, el viento o un terremoto): la claridad, ganar la sala, perderla o seguir. `limite`: también se comprueba el temporizador.
func _tras_efecto(r: Dictionary, limite: bool) -> Dictionary:
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
		gastado_antes += movs   # (Presupuesto compartido)
		_entrar(indice + 1)   # (la sala anterior cae; la entrada de la nueva es la celda de la salida de la anterior)
		r["evento"] = "checkpoint"
		return r
	if motor.perdido:
		return _morir(str(motor.motivo) if str(motor.motivo) != "" else "Caíste")
	if limite and movs >= max_mov():
		return _morir("Se acabaron los movimientos")
	r["evento"] = ""
	return r


## Ventisca: el viento empuja al jugador una celda hacia `dir` (no gasta movimientos). Devuelve como `actuar` ({ok: false} si no lo movió).
func viento(dir: Vector3i) -> Dictionary:
	if terminada or perdida or muerta or not motor.viento(dir):
		return {"ok": false, "msg": "", "evento": ""}
	return _tras_efecto({"ok": true, "msg": ""}, false)


## Terremoto: un bloque suelto (común, sin nada encima, que no sea el que pisas ni del que te cuelgas) se corre una celda hacia donde haya lugar dentro del anillo.
## Devuelve {ok, evento, de, a}; ok es false si no había ninguno que se pudiera correr.
func terremoto(rng: RandomNumberGenerator, cuantos := 3) -> Dictionary:
	if terminada or perdida or muerta:
		return {"ok": false, "msg": "", "evento": ""}
	var movidos: Array = []
	for n in cuantos:
		var par := _terremoto_uno(rng)
		if par.is_empty():
			break
		movidos.append(par)
	if movidos.is_empty():
		return {"ok": false, "msg": "", "evento": ""}
	var r := _tras_efecto({"ok": true, "msg": ""}, false)
	r["movidos"] = movidos
	return r


## Corre un bloque suelto una celda y devuelve {de, a} ({} si no hay ninguno que se pueda correr sin romper la solución).
func _terremoto_uno(rng: RandomNumberGenerator) -> Dictionary:
	var candidatos: Array = []
	var prohibido: Vector3i = motor.jugador + Vector3i(0, -1, 0) if motor.colgado == Vector3i.ZERO else motor.jugador + motor.colgado
	for c in motor.bloques:
		if str(motor.bloques[c]) != "n" or c == prohibido or motor.obstaculos.has(c) or motor.bloques.has(c + Vector3i(0, 1, 0)):
			continue
		if motor.jugador == c + Vector3i(0, 1, 0) or (motor.colgado != Vector3i.ZERO and motor.jugador == c):
			continue
		for d in Motor.DIRS:
			var a: Vector3i = c + d
			if motor.bloques.has(a) or not es_anillo(a.x, a.z) or a == motor.jugador:
				continue
			candidatos.append([c, a])
	var cerca := func(e: Array) -> float: return Vector2(e[0].x - motor.jugador.x, e[0].z - motor.jugador.z).length() + float(absi(e[0].y - motor.jugador.y)) + rng.randf() * 2.5
	var puntuados: Array = []
	for e in candidatos:   # (los más cercanos al jugador primero, con algo de azar: se nota más)
		puntuados.append([cerca.call(e), e])
	puntuados.sort_custom(func(a, b): return a[0] < b[0])
	for p in puntuados.slice(0, 14):   # (el primero que no tire ningún otro bloque y no rompa la solución conocida de la sala)
		var e: Array = p[1]
		if not _corrimiento_limpio(motor, e[0], e[1]) or not _terremoto_seguro(e[0], e[1]):
			continue
		_temblores.append({"en": deshacer_pila.size(), "id": int(motor.ids.get(e[0], -1)), "delta": e[1] - e[0]})
		motor.desplazar(e[0], e[1])
		return {"de": e[0], "a": e[1]}
	return {}


## ¿Correr el bloque de `de` a `a` deja todo lo demás donde estaba? Si con el corrimiento cae un bloque (o más), o se mueve algo más que ése, no vale: el temblor tiene que molestar, no desarmar el puzzle.
static func _corrimiento_limpio(m, de: Vector3i, a: Vector3i) -> bool:
	var copia = m.duplicar()
	copia.desplazar(de, a)
	if not copia.caidos_fuera.is_empty() or copia.perdido or copia.bloques.size() != m.bloques.size() or copia.jugador != m.jugador or copia.colgado != m.colgado:
		return false
	var id_movido := int(m.ids.get(de, -1))
	for c in m.ids:
		var id := int(m.ids[c])
		if id == id_movido:
			continue
		if not copia.ids.has(c) or int(copia.ids[c]) != id:
			return false   # (algún otro bloque cambió de lugar: cayó)
	return true


## ¿La solución conocida de la sala sigue andando si ese bloque se corre en este momento? Se repite desde el principio con el corrimiento hecho después de las acciones que lleva el jugador: si se juega siguiendo la
## solución, el temblor no la rompe (el bloque que se corre es en la práctica uno de los que sobran). Si el jugador ya se pasó de la solución conocida, no hay nada que comprobar.
func _terremoto_seguro(de: Vector3i, a: Vector3i) -> bool:
	var s: Dictionary = salas[indice]
	var camino: Array = s.d.get("camino", [])
	var hechas := deshacer_pila.size()
	if hechas >= camino.size():
		return true
	var m = Vista.motor_de(s.d)
	if indice + 1 < salas.size():
		m.agregar_obstaculos(obstaculos_de(salas[indice + 1].d, int(s.d.meta)))
	var corrimientos: Array = _temblores.duplicate()
	corrimientos.append({"en": hechas, "id": int(motor.ids.get(de, -1)), "delta": a - de})
	for i in camino.size():
		for c in corrimientos:   # (los temblores de antes y éste, cada uno después de las acciones que llevaba el jugador)
			if int(c.en) != i:
				continue
			var celda := Vector3i(-999, -999, -999)
			for k in m.ids:
				if int(m.ids[k]) == int(c.id):
					celda = k
			if celda.x == -999 or m.bloques.has(celda + c.delta) or m.jugador == celda + c.delta:
				return false
			if not _corrimiento_limpio(m, celda, celda + c.delta):
				return false
			m.desplazar(celda, celda + c.delta)
		if not m.actuar(Vector3i(int(camino[i][0]), 0, int(camino[i][1])), int(camino[i][2])).ok:
			return false
	return m.ganado


## Corrupción que vuelve: el bloque purificado más viejo (que no sea el que pisas o del que te cuelgas, ni los checkpoint) se corrompe otra vez y se pierde la claridad que dio en esta sala.
## Pisarlo de nuevo la vuelve a dar. Devuelve {ok, celda, perdida}; ok es false si no hay ninguno.
func corromper() -> Dictionary:
	var pisado := -1
	if motor.colgado == Vector3i.ZERO and motor.ids.has(motor.jugador + Vector3i(0, -1, 0)):
		pisado = int(motor.ids[motor.jugador + Vector3i(0, -1, 0)])
	elif motor.colgado != Vector3i.ZERO and motor.ids.has(motor.jugador + motor.colgado):
		pisado = int(motor.ids[motor.jugador + motor.colgado])
	for id in motor.purificados.keys():   # (en el orden en que se purificaron: el más viejo primero)
		if int(id) == pisado:
			continue
		var celda := Vector3i(-999, -999, -999)
		for c in motor.ids:
			if int(motor.ids[c]) == int(id):
				celda = c
		var letra := str(motor.bloques.get(celda, ""))
		if letra == "" or letra == "f" or letra == "p":
			if letra == "":
				motor.purificados.erase(id)   # (el bloque ya no está)
			continue
		motor.purificados.erase(id)
		return {"ok": true, "celda": celda, "perdida": cosecha.perder_bloque(letra)}
	return {"ok": false, "celda": Vector3i.ZERO, "perdida": 0}


## La sala se pierde por algo que decide el juego (por ejemplo el último movimiento en falso de El camino corto): cuenta como una muerte.
## Reintentar la sala perdida: vuelve a su checkpoint con la sala virgen.
## Empieza en el checkpoint de la sala `i` (al continuar una partida guardada), con la claridad asegurada hasta ahí.
func saltar_a_sala(i: int, banco: int) -> void:
	if i <= 0 or i >= salas.size():
		return
	if presupuesto_total > 0:   # (al continuar una partida el fondo no se guardó: se calcula lo que habrían gastado las salas de antes)
		gastado_antes = 0
		for j in i:
			gastado_antes += int(ceil(float(salas[j].d.pasos) * 1.15))
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


## La sala actual tal como está (para guardarla): dónde está el jugador, los bloques, los movimientos y la claridad de la sala. Sólo datos simples: `restaurar_sala` la vuelve a poner.
func estado_sala() -> Dictionary:
	var m = motor
	var datos := {"bloques": m.bloques, "jugador": m.jugador, "colgado": m.colgado, "pasos": m.pasos, "ids": m.ids, "sig_id": m.sig_id, "purificados": m.purificados, "movidos": m.movidos}
	return {"sala": indice, "motor": var_to_str(datos), "movs": movs, "mov_extra": mov_extra, "cosecha": var_to_str(cosecha.estado()), "pocion": cosecha.harvest_potion,
		"encendidos": var_to_str(encendidos), "aliento": aliento_usado, "muertes_sala": muertes_sala}


## Vuelve a poner la sala que guardó `estado_sala` (la torre tiene que estar ya en esa sala). false si no coincide y no se tocó nada.
func restaurar_sala(e: Dictionary) -> bool:
	if e.is_empty() or int(e.get("sala", -1)) != indice or not e.has("motor"):
		return false
	var datos = str_to_var(str(e.motor))
	var cos = str_to_var(str(e.get("cosecha", "")))
	var enc = str_to_var(str(e.get("encendidos", "")))
	if typeof(datos) != TYPE_DICTIONARY or typeof(cos) != TYPE_DICTIONARY or typeof(enc) != TYPE_DICTIONARY or not datos.has("bloques") or not datos.has("jugador"):
		return false
	motor.bloques = datos.bloques
	motor.jugador = datos.jugador
	motor.colgado = datos.get("colgado", Vector3i.ZERO)
	motor.pasos = int(datos.get("pasos", 0))
	motor.ids = datos.get("ids", {})
	motor.sig_id = int(datos.get("sig_id", 0))
	motor.purificados = datos.get("purificados", {})
	motor.movidos = datos.get("movidos", {})
	movs = int(e.get("movs", 0))
	mov_extra = int(e.get("mov_extra", 0))
	cosecha.restaurar(cos)
	cosecha.harvest_potion = bool(e.get("pocion", false))
	encendidos = enc
	aliento_usado = bool(e.get("aliento", false))
	muertes_sala = int(e.get("muertes_sala", 0))
	deshacer_pila.clear()
	return true


## Deshace el último movimiento de la sala actual (con lo que se había juntado y la cuenta de movimientos). false si no hay nada que deshacer.
func deshacer() -> bool:
	if deshacer_pila.is_empty() or terminada or perdida or muerta:
		return false
	var f: Dictionary = deshacer_pila.pop_back()
	while not _temblores.is_empty() and int(_temblores[_temblores.size() - 1].en) > deshacer_pila.size():
		_temblores.pop_back()   # (los temblores que vinieron después de la acción deshecha también se deshacen)
	motor = f.motor
	var costo := movs - int(f.movs)   # (deshacer devuelve sólo la mitad de lo que costó: el medio movimiento que sobra se junta con el del próximo deshacer)
	var mitades := costo + _deshacer_resto
	movs = int(f.movs) + costo - mitades / 2
	_deshacer_resto = mitades % 2
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
			return {"ok": true, "msg": "+%d de claridad (%d bloques)" % [got, letras.size()], "claridad": got}
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
