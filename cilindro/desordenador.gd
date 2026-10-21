extends RefCounted
## Desordenador por contra-movimientos: parte de la torre RESUELTA (la escalera, con el jugador en la cima) y va hacia atrás.
## Cada paso hacia atrás es un estado anterior desde el cual UNA acción del motor lleva exactamente al estado actual (se comprueba
## simulando hacia adelante con cilindro/motor.gd), así que la torre que sale siempre se puede resolver (con ese camino al revés, o uno más corto).
## Sólo usa cilindro/motor.gd, cilindro/reglas.gd y cilindro/solucionador.gd.

const Motor := preload("res://cilindro/motor.gd")
const Reglas := preload("res://cilindro/reglas.gd")
const Sol := preload("res://cilindro/solucionador.gd")

const DIRS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


static func _igual(a, b) -> bool:
	return a.jugador == b.jugador and a.colgado == b.colgado and Sol.clave(a) == Sol.clave(b)


## ¿El estado es coherente (nada se cae, el jugador tiene dónde estar)?
static func estable(t) -> bool:
	if t.colgado != Vector3i.ZERO:
		if not t.bloques.has(t.jugador + t.colgado) or t.bloques.has(t.jugador):
			return false
	else:
		if not t.solido(t.jugador + Vector3i(0, -1, 0)) or t.bloques.has(t.jugador):
			return false
	var r := Reglas.asentar(t.bloques, t.alto, t.jugador)
	return r.caidos == 0 and r.perdidos == 0


static func _lleva_a(cand, d: Vector3i, m: int, destino) -> bool:
	var s = cand.duplicar()
	var r: Dictionary = s.actuar(d, m)
	return r.ok and not s.perdido and _igual(s, destino)


## Los estados anteriores de `t`: [{ "s": estado, "tipo": "caminar" | "bloque", "d": dir, "m": modo }]. radio = qué tan cerca del jugador se tocan bloques.
static func predecesores(t, radio := 3) -> Array:
	var out: Array = []
	var vistos := {}
	# a) el jugador se movió (caminar, colgarse, bordear, trepar...): el bloque queda igual
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for dy in range(-1, 2):
				for colg in [Vector3i.ZERO] + DIRS:
					var cand = t.duplicar()
					cand.ganado = false
					cand.jugador = t.jugador + Vector3i(dx, dy, dz)
					cand.colgado = colg
					if _igual(cand, t) or not estable(cand):
						continue
					for d in DIRS:
						for m in (3 if colg == Vector3i.ZERO else 1):
							if _lleva_a(cand, d, m, t):
								var k := Sol.clave(cand) ^ (hash([cand.jugador, cand.colgado]) * 7)
								if not vistos.has(k):
									vistos[k] = true
									out.append({"s": cand, "tipo": "caminar", "d": d, "m": m})
								break
	# b) se empujó o se tiró un bloque
	for c in t.bloques:
		if t.bloques[c] == "f":
			continue
		var rel: Vector3i = c - t.jugador
		if absi(rel.x) > radio or absi(rel.z) > radio or absi(rel.y) > 2:
			continue
		for d in DIRS:
			var antes: Vector3i = c - d
			if t.bloques.has(antes):
				continue
			for mover_jugador in [false, true]:
				var cand = t.duplicar()
				cand.ganado = false
				cand.bloques.erase(c)
				cand.bloques[antes] = t.bloques[c]
				if mover_jugador:
					cand.jugador = t.jugador - d
				if cand.bloques.has(cand.jugador) and cand.jugador != t.jugador:
					continue
				if not estable(cand):
					continue
				if _lleva_a(cand, d, 1, t):
					out.append({"s": cand, "tipo": "bloque", "d": d, "m": 1})
	return out


static func _k(t) -> int:
	return Sol.clave(t) ^ hash([t.jugador, t.colgado])


## Resultado de desordenar: { "estado": la torre inicial (jugador abajo), "inverso": acciones en orden de juego, "bloques": cuántos movimientos de bloque se deshicieron }.
## Si se queda sin salida retrocede un paso (y no vuelve a pasar por ahí).
static func desordenar(rng: RandomNumberGenerator, final, objetivo_bloques := 8, tope := 400, p_bloque := 0.5) -> Dictionary:
	var t = final.duplicar()
	var pila: Array = []   # [{ "t": estado, "hecho": [d, m], "bloque": bool }]
	var en_camino := {_k(t): true}
	var prohibidos := {}
	var bloques_movidos := 0
	var motivo := "tope"
	for _i in tope:
		var opts := predecesores(t)
		var bl: Array = []
		var wk: Array = []
		for o in opts:
			var k := _k(o.s)
			if en_camino.has(k) or prohibidos.has(k):
				continue
			(bl if o.tipo == "bloque" else wk).append(o)
		if bl.is_empty() and wk.is_empty():
			if pila.is_empty():
				motivo = "sin_salida"
				break
			var ultimo: Dictionary = pila.pop_back()
			prohibidos[_k(t)] = true
			en_camino.erase(_k(t))
			if ultimo.bloque:
				bloques_movidos -= 1
			t = ultimo.t
			continue
		var elegido: Dictionary = {}
		var es_bloque := false
		if bloques_movidos < objetivo_bloques and not bl.is_empty() and (wk.is_empty() or rng.randf() < p_bloque):
			elegido = bl[rng.randi_range(0, bl.size() - 1)]
			es_bloque = true
			bloques_movidos += 1
		else:
			var lista: Array = wk if not wk.is_empty() else bl
			var pesos: Array = []
			var suma := 0.0
			for o in lista:
				var w := 1.0 + 40.0 * maxf(0.0, float(t.jugador.y - o.s.jugador.y))
				if o.s.colgado != Vector3i.ZERO:
					w *= 0.3
				pesos.append(w)
				suma += w
			var r := rng.randf() * suma
			elegido = lista[lista.size() - 1]
			for j in lista.size():
				r -= pesos[j]
				if r <= 0.0:
					elegido = lista[j]
					break
			if wk.is_empty():
				es_bloque = true
				bloques_movidos += 1
		pila.append({"t": t, "hecho": [elegido.d, elegido.m], "bloque": es_bloque})
		t = elegido.s
		en_camino[_k(t)] = true
		if bloques_movidos >= objetivo_bloques and t.jugador.y == 1 and Reglas.es_anillo(t.jugador.x, t.jugador.z) and t.colgado == Vector3i.ZERO:
			motivo = "llego"
			break
	var hechos: Array = []
	for p in pila:
		hechos.append(p.hecho)
	hechos.append(null)
	hechos.pop_back()
	hechos.reverse()
	return {"estado": t, "inverso": hechos, "bloques": bloques_movidos, "fin": motivo, "llego": t.jugador.y == 1 and Reglas.es_anillo(t.jugador.x, t.jugador.z)}


## Búsqueda en haz hacia atrás: en cada capa se queda con los `ancho` estados anteriores más prometedores (el jugador más abajo y más
## movimientos de bloque deshechos, con algo de azar) hasta que alguno llega al anillo con al menos `objetivo_bloques` deshechos.
## Devuelve igual que desordenar (y "profundidad" = largo del camino al revés), o {} si no llegó.
static func desordenar_haz(rng: RandomNumberGenerator, final, objetivo_bloques := 8, ancho := 12, profundidad := 40, ruido := 4.0) -> Dictionary:
	var nodos: Array = [{"t": final.duplicar(), "padre": -1, "hecho": null, "bl": 0}]
	var capa: Array = [0]
	var vistos := {_k(nodos[0].t): true}
	var mejor := -1
	for nivel in profundidad:
		var siguientes: Array = []
		for idx in capa:
			var nodo: Dictionary = nodos[idx]
			for o in predecesores(nodo.t):
				var k := _k(o.s)
				if vistos.has(k):
					continue
				vistos[k] = true
				var bl: int = nodo.bl + (1 if o.tipo == "bloque" else 0)
				nodos.append({"t": o.s, "padre": idx, "hecho": [o.d, o.m], "bl": bl})
				var j := nodos.size() - 1
				siguientes.append(j)
				var en_anillo: bool = o.s.jugador.y == 1 and Reglas.es_anillo(o.s.jugador.x, o.s.jugador.z) and o.s.colgado == Vector3i.ZERO
				if en_anillo and bl >= objetivo_bloques and (mejor < 0 or bl > nodos[mejor].bl):
					mejor = j
		if mejor >= 0:
			break
		if siguientes.is_empty():
			break
		var puntuados: Array = []
		for j in siguientes:
			var n: Dictionary = nodos[j]
			var p: float = float(n.bl) * 10.0 - float(n.t.jugador.y) * 4.0 + rng.randf() * ruido - (2.0 if n.t.colgado != Vector3i.ZERO else 0.0)
			puntuados.append([p, j])
		puntuados.sort_custom(func(a, b): return a[0] > b[0])
		capa = []
		for i in mini(ancho, puntuados.size()):
			capa.append(puntuados[i][1])
	if mejor < 0:
		return {}
	var hechos: Array = []
	var i: int = mejor
	while nodos[i].padre >= 0:
		hechos.append(nodos[i].hecho)
		i = nodos[i].padre
	# (se recorrió de la torre armada hacia la final: el orden de juego es el de la cadena, del jugador abajo hacia la cima)
	hechos.reverse()
	hechos.reverse()
	return {"estado": nodos[mejor].t, "inverso": hechos, "bloques": nodos[mejor].bl, "profundidad": hechos.size(), "fin": "haz", "llego": true}
