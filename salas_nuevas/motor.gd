extends RefCounted
## Motor de la torre de salas sin núcleo: el jugador y los movimientos (ver docs/torre_salas_reglas.md). Módulo aislado: sólo usa salas_nuevas/reglas.gd.
## Las reglas de movimiento son las del juego actual (empujar, tirar, colgarse, bordear, trepar) con el sostén nuevo y sin suelo.
## Un bloque es { Vector3i: tipo } con tipo "n" común, "p" checkpoint (se comporta como uno común; lleva el farolito), "f" fijo, y los especiales
## "i" hielo, "h" pesado, "c" agrietado, "t" trampa, "s" pinchos, "k" catapulta (todavía no se usan: las salas son de bloques básicos).
## El jugador está parado en y cuando hay un bloque en y-1. No hay suelo: sin bloque abajo cae, y si cae por debajo del nivel 1 muere.
## Se gana parado sobre el checkpoint de la salida, que es el único bloque fijo de la sala (el ancla): a la altura `meta` (el nivel del bloque).

const Reglas := preload("res://salas_nuevas/reglas.gd")

enum Modo { MOVER, AGARRAR, COLGAR }

const UP := Vector3i(0, 1, 0)
const DOWN := Vector3i(0, -1, 0)
const DIRS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const MAX_FILA := 3
const SUBE_CATAPULTA := 4
const ALCANCE_CATAPULTA := 2
const LIMITE_RESBALON := 40
const NINGUNA := Vector3i(-999, -999, -999)
const BOMBA_R2 := 5   # zona de una bomba: celdas con dx² + dy² + dz² <= 5
const LADO := 11   # la torre: un anillo de 11 x 11 alrededor de un vacío de 5 x 5

var meta := 8   # nivel del bloque checkpoint de la salida
var bloques := {}
var jugador := Vector3i(0, 2, 0)
var colgado := Vector3i.ZERO   # ZERO = de pie; si no, dirección hacia el bloque del que cuelga
var perdido := false
var ganado := false
var motivo := ""
var pasos := 0
var ids := {}            # la identidad de cada bloque (celda -> número): sigue al bloque cuando lo empujan o cae
var sig_id := 0
var obstaculos := {}      # celdas de la sala de arriba que están en el alcance de ésta: bloques fijos (tipo "f") que no se dibujan acá (la torre los dibuja con su sala)
var luz_propia := false  # boost Luz propia: también se purifican los vecinos de lo que se pisa
var ultimos_purificados: Array = []   # las letras de los bloques que se purificaron en la última acción (para la claridad)
var agarro := false      # en la última acción se movió un bloque (empujar o tirar)
var purificados := {}    # los bloques que el jugador ya pisó o de los que se colgó (número -> true): el aspecto de la torre lo usa


func duplicar():
	var t = get_script().new()
	t.meta = meta
	t.bloques = bloques.duplicate()
	t.jugador = jugador
	t.colgado = colgado
	t.perdido = perdido
	t.ganado = ganado
	t.motivo = motivo
	t.pasos = pasos
	t.ids = ids.duplicate()
	t.sig_id = sig_id
	t.purificados = purificados.duplicate()
	t.obstaculos = obstaculos.duplicate()
	t.luz_propia = luz_propia
	return t


static func nueva(meta_: int, inicio: Vector3i):
	var t = load("res://salas_nuevas/motor.gd").new()
	t.meta = meta_
	t.jugador = inicio
	return t


func poner(c: Vector3i, tipo := "n") -> void:
	bloques[c] = tipo
	ids[c] = sig_id
	sig_id += 1


## Los bloques de la sala de arriba que quedan al alcance de esta sala (están anclados y no se mueven): se agregan como fijos.
func agregar_obstaculos(celdas: Array) -> void:
	for c in celdas:
		if not bloques.has(c):
			bloques[c] = "f"
			ids[c] = sig_id
			sig_id += 1
			obstaculos[c] = true


func tipo_en(c: Vector3i) -> String:
	return bloques.get(c, "")


## ¿Hay algo sólido en la celda? Un bloque (no hay suelo).
func solido(c: Vector3i) -> bool:
	return bloques.has(c)


func en_limites(c: Vector3i) -> bool:
	return c.x >= -3 and c.x <= LADO + 2 and c.z >= -3 and c.z <= LADO + 2 and c.y >= 0 and c.y <= meta + 6


func en_huella(c: Vector3i) -> bool:
	return c.x >= 0 and c.x < LADO and c.z >= 0 and c.z < LADO and c.y >= 0


func _alcance_cuelgue(c: Vector3i) -> bool:
	return c.x >= -4 and c.x <= LADO + 3 and c.z >= -4 and c.z <= LADO + 3 and c.y >= 0


func actuar(d: Vector3i, modo: Modo = Modo.MOVER) -> Dictionary:
	if ganado or perdido:
		return {"ok": false, "msg": ""}
	ultimos_purificados = []
	agarro = false
	var grieta := NINGUNA   # el agrietado sobre el que estabas al empezar la acción
	if colgado == Vector3i.ZERO and tipo_en(jugador + DOWN) == "c":
		grieta = jugador + DOWN
	var r: Dictionary
	if colgado != Vector3i.ZERO:
		r = _colgado(d)
	elif modo == Modo.AGARRAR:
		r = _agarrar(d)
	elif modo == Modo.COLGAR:
		r = _colgar(d)
	else:
		r = _caminar(d)
	if r.ok:
		_despues(grieta)
	return r


func _ok() -> Dictionary:
	return {"ok": true, "msg": ""}


func _no(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg}


func _caminar(d: Vector3i) -> Dictionary:
	var t := jugador + d
	if not en_limites(t):
		return _no("Borde")
	if bloques.has(t):
		if bloques.has(t + UP) or bloques.has(jugador + UP):
			return _no("Bloqueado")
		jugador = t + UP
		_llegar(d)
		return _ok()
	if solido(t + DOWN):
		jugador = t
		_llegar(d)
		return _ok()
	if solido(t + DOWN * 2):   # bajar un escalón
		jugador = t + DOWN
		_llegar(d)
		return _ok()
	return _no("Borde")


func _agarrar(d: Vector3i) -> Dictionary:
	var t := jugador + d
	if bloques.has(t):
		var dest := t + d
		if tipo_en(t) == "f":
			return _no("Bloque fijo")
		if tipo_en(t) == "h":
			return _no("Bloque pesado")
		if bloques.has(dest):
			return _empujar_fila(t, d)
		if tipo_en(t) == "i":   # el hielo se desliza hasta chocar con algo o salir de la huella
			while en_huella(dest):
				var n := dest + d
				if bloques.has(n) or n == jugador:
					break
				dest = n
		_mover(t, dest)
		return _ok()
	if bloques.has(jugador - d):
		if tipo_en(jugador - d) == "f":
			return _no("Bloque fijo")
		if tipo_en(jugador - d) == "h":
			return _no("Bloque pesado")
		if not en_limites(t):
			return _no("Borde")
		if not solido(t + DOWN):
			var h := t + DOWN
			if solido(h + DOWN):   # un escalón más abajo: se baja
				_mover(jugador - d, jugador)
				jugador = h
				_llegar(d)
				return _ok()
			# sin piso atrás: el bloque viene a donde estabas y quedás colgado del bloque donde estabas parado
			if bloques.has(jugador + DOWN) and not bloques.has(h) and _alcance_cuelgue(h):
				if tipo_en(jugador + DOWN) == "i":
					return _no("Hielo: no hay de dónde agarrarse")
				_mover(jugador - d, jugador)
				jugador = h
				colgado = -d
				return _ok()
			return _no("No se puede tirar")
		_mover(jugador - d, jugador)
		jugador = t
		_llegar(d)
		return _ok()
	return _caminar(d)   # sin nada que empujar ni tirar, Shift es un paso común


func _empujar_fila(t: Vector3i, d: Vector3i) -> Dictionary:
	var fila: Array[Vector3i] = []
	var c := t
	while bloques.has(c):
		if tipo_en(c) == "f":
			return _no("Bloque fijo")
		if tipo_en(c) == "h":
			return _no("Bloque pesado")
		fila.append(c)
		if fila.size() > MAX_FILA:
			return _no("Demasiados bloques")
		c += d
	for i in range(fila.size() - 1, -1, -1):
		_mover(fila[i], fila[i] + d)
	return _ok()


func _colgar(d: Vector3i) -> Dictionary:
	var t := jugador + d
	var h := t + DOWN
	if tipo_en(jugador + DOWN) == "i":
		return _no("Hielo: no hay de dónde agarrarse")
	if not _alcance_cuelgue(t) or bloques.has(t):
		return _no("No hay borde")
	if solido(h) or solido(h + DOWN):
		return _no("Ahí se puede caminar")
	if not bloques.has(jugador + DOWN):
		return _no("No hay de dónde colgarse")
	jugador = h
	colgado = -d
	return _ok()


func _colgado(d: Vector3i) -> Dictionary:
	var w := colgado
	if d == w:   # trepar al bloque
		var s := jugador + w + UP
		if bloques.has(s) or bloques.has(jugador + UP):
			return _no("No hay espacio para trepar")
		jugador = s
		colgado = Vector3i.ZERO
		return _ok()
	if d == -w:   # soltarse
		colgado = Vector3i.ZERO
		return _ok()
	var h2 := jugador + d
	var g2 := h2 + w
	if not _alcance_cuelgue(h2):
		return _no("No se puede avanzar por el borde")
	if bloques.has(h2):   # esquina hacia adentro (también si tiene otro encima: se avanza agarrado de su costado)
		if tipo_en(h2) == "i":
			return _no("Hielo")
		colgado = d
		return _ok()
	if bloques.has(g2):   # tramo recto
		if tipo_en(g2) == "i":
			return _no("Hielo")
		jugador = h2
		return _ok()
	if _alcance_cuelgue(g2) and not bloques.has(jugador + w + UP):   # esquina hacia afuera: se rodea el bloque
		jugador = g2
		colgado = -d
		return _ok()
	if solido(g2 + DOWN):   # del otro lado hay piso: se sube y se queda parado
		colgado = Vector3i.ZERO
		jugador = g2
		_llegar(d)
		return _ok()
	return _no("No se puede avanzar por el borde")


func _llegar(d: Vector3i) -> void:
	var k := tipo_en(jugador + DOWN)
	if k == "i":
		_resbalar(d)
	elif k == "k":
		_lanzar(d)


func _resbalar(d: Vector3i) -> void:
	for _i in LIMITE_RESBALON:
		var t := jugador + d
		if bloques.has(t):
			return
		if not en_huella(t):
			perdido = true
			motivo = "Caíste al vacío"
			jugador = Vector3i(t.x, maxi(t.y - 3, -3), t.z)
			return
		jugador = t
		if tipo_en(jugador + DOWN) != "i":
			return


func _lanzar(d: Vector3i) -> void:
	var origen := jugador
	for _i in SUBE_CATAPULTA:
		var c := jugador + UP
		if not en_limites(c) or bloques.has(c):
			break
		jugador = c
	if jugador == origen:
		return
	var tope := jugador.y
	for _i in ALCANCE_CATAPULTA:
		var arriba := Vector3i(jugador.x, tope + 1, jugador.z)
		if not en_limites(arriba) or bloques.has(arriba):
			break
		tope += 1
	for y in range(tope, origen.y, -1):
		for g_dir in [d, Vector3i(-d.z, 0, d.x), Vector3i(d.z, 0, -d.x), -d]:
			var g: Vector3i = Vector3i(jugador.x, y, jugador.z) + g_dir
			if bloques.has(g) and not bloques.has(g + UP) and tipo_en(g) != "i":
				jugador = Vector3i(jugador.x, y, jugador.z)
				colgado = g_dir
				return


func _mover(de: Vector3i, a: Vector3i) -> void:
	var tipo = bloques[de]
	bloques.erase(de)
	bloques[a] = tipo
	agarro = true
	if ids.has(de):
		ids[a] = ids[de]
		ids.erase(de)


func _despues(grieta: Vector3i) -> void:
	pasos += 1
	if grieta != NINGUNA and bloques.has(grieta) and jugador != grieta + UP and tipo_en(grieta) == "c":
		bloques.erase(grieta)   # el agrietado se rompe al bajarte de él
	_asentar()
	_peligros()
	if perdido:
		return
	_purificar()
	# meta: parado sobre el bloque checkpoint de la salida
	if colgado == Vector3i.ZERO and jugador.y == meta + 1 and tipo_en(jugador + DOWN) == "f":
		ganado = true
		return   # (ganar en el mismo movimiento tiene prioridad sobre la explosión)
	# bombas: la mecha ("b7") baja un movimiento por acción mientras el jugador está dentro de su zona; al llegar a 0 cae la sala entera
	for c in bloques.keys():
		var tp: String = bloques[c]
		if tp.length() < 2 or tp[0] != "b":
			continue
		var d: Vector3i = jugador - c
		if d.x * d.x + d.y * d.y + d.z * d.z > BOMBA_R2:
			continue
		var mecha := int(tp.substr(1)) - 1
		if mecha <= 0:
			perdido = true
			motivo = "Explotó una bomba: la sala se derrumbó"
			return
		bloques[c] = "b%d" % mecha


func _asentar() -> void:
	var cambio := true
	var guardia := 0
	while cambio and guardia < 50:
		guardia += 1
		var r := Reglas.asentar(bloques, jugador, ids)
		bloques = r.bloques
		var antes := jugador
		var antes_colgado := colgado
		_asentar_jugador()
		cambio = jugador != antes or colgado != antes_colgado or r.caidos > 0 or r.perdidos > 0
		if perdido:
			return


func _asentar_jugador() -> void:
	if perdido:
		return
	if colgado != Vector3i.ZERO:
		if bloques.has(jugador + colgado):
			return
		colgado = Vector3i.ZERO
	while not solido(jugador + DOWN):
		if jugador.y <= 1:
			perdido = true
			motivo = "Caíste al vacío"
			jugador += Vector3i(0, -3, 0)
			return
		jugador += DOWN


## Purifica esas celdas (consumibles). Devuelve las letras de los bloques que se purificaron.
func purificar_celdas(celdas: Array) -> Array:
	var letras: Array = []
	for k in celdas:
		if bloques.has(k) and ids.has(k) and not purificados.has(ids[k]):
			purificados[ids[k]] = true
			letras.append(str(bloques[k]))
	return letras


## Pisar un bloque (o colgarse de él) lo purifica: sólo cambia cómo se ve.
func _purificar() -> void:
	var c := jugador + DOWN if colgado == Vector3i.ZERO else jugador + colgado
	var celdas: Array = [c]
	if luz_propia:
		for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
			celdas.append(c + d)
	for k in celdas:
		if bloques.has(k) and ids.has(k) and not purificados.has(ids[k]):
			purificados[ids[k]] = true
			ultimos_purificados.append(str(bloques[k]))


## Trampa (se desarma al pisarla y cae con ella) y pinchos (se pierde).
func _peligros() -> void:
	for _i in 8:
		if perdido or colgado != Vector3i.ZERO:
			return
		var k := tipo_en(jugador + DOWN)
		if k.length() >= 2 and k[0] == "b":
			bloques[jugador + DOWN] = "d"   # pararse encima de una bomba la desactiva (queda como un bloque común)
			return
		if k == "t":
			bloques.erase(jugador + DOWN)
			_asentar()
		elif k == "s":
			perdido = true
			motivo = "Caíste sobre los pinchos"
			return
		else:
			return
