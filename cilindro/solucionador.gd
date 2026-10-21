extends RefCounted
## Solucionador del cilindro (A* sobre el motor de cilindro/motor.gd). Lento (GDScript): sirve para validar y para salas chicas;
## el definitivo irá en C++. Sólo usa cilindro/motor.gd.

const Motor := preload("res://cilindro/motor.gd")

const ACCIONES := [
	[Vector3i(1, 0, 0), 0], [Vector3i(-1, 0, 0), 0], [Vector3i(0, 0, 1), 0], [Vector3i(0, 0, -1), 0],
	[Vector3i(1, 0, 0), 1], [Vector3i(-1, 0, 0), 1], [Vector3i(0, 0, 1), 1], [Vector3i(0, 0, -1), 1],
	[Vector3i(1, 0, 0), 2], [Vector3i(-1, 0, 0), 2], [Vector3i(0, 0, 1), 2], [Vector3i(0, 0, -1), 2],
]


static func _mezcla(c: Vector3i, tipo: String) -> int:
	var v := (c.x + 16) + 64 * ((c.z + 16) + 64 * ((c.y + 64) + 256 * tipo.unicode_at(0))) + 1
	v = (v ^ (v >> 30)) * -4658895280553007687
	v = (v ^ (v >> 27)) * -7723592293110705685
	return v ^ (v >> 31)


## Huella del estado (los bloques sueltos, el jugador y si está colgado).
static func clave(t) -> int:
	var h := 0
	for c in t.bloques:
		if t.bloques[c] != "f":
			h ^= _mezcla(c, t.bloques[c])
	h ^= _mezcla(t.jugador, "j") * 31 + _mezcla(t.colgado, "q") * 17
	return h


static func _heuristica(t, hay_catapulta: bool) -> int:
	var falta: int = t.alto + 1 - t.jugador.y
	if falta <= 0:
		return 0
	return ceili(float(falta) / 7.0) if hay_catapulta else falta


## { ok, moves, path:[[dir, modo]], grabs (agarres), blocks (bloques distintos movidos), states }. tope = estados como mucho.
static func resolver(inicial, tope := 200000) -> Dictionary:
	var hay_k := false
	for c in inicial.bloques:
		if inicial.bloques[c] == "k":
			hay_k = true
	var abiertos: Array = []   # cola de prioridad simple por cubos de f
	var cubos := {}
	var vistos := {}
	var k0 := clave(inicial)
	vistos[k0] = 0
	var nodos: Array = [{"t": inicial, "g": 0, "padre": -1, "accion": null}]
	cubos[_heuristica(inicial, hay_k)] = [0]
	var f_min := _heuristica(inicial, hay_k)
	var expandidos := 0
	while expandidos < tope:
		while not cubos.has(f_min) or cubos[f_min].is_empty():
			cubos.erase(f_min)
			if cubos.is_empty():
				return {"ok": false, "moves": 0, "states": expandidos, "path": []}
			f_min = cubos.keys().min()
		var idx: int = cubos[f_min].pop_back()
		var nodo: Dictionary = nodos[idx]
		var t = nodo.t
		if t.ganado:
			return _camino(nodos, idx, expandidos)
		expandidos += 1
		for a in ACCIONES:
			var d: Vector3i = a[0]
			var m: int = a[1]
			if t.colgado != Vector3i.ZERO and m != 0:
				continue
			var s = t.duplicar()
			var r: Dictionary = s.actuar(d, m)
			if not r.ok or s.perdido:
				continue
			var k := clave(s)
			var g: int = nodo.g + 1
			if vistos.has(k) and vistos[k] <= g:
				continue
			vistos[k] = g
			nodos.append({"t": s, "g": g, "padre": idx, "accion": [d, m]})
			var f := g + _heuristica(s, hay_k)
			if not cubos.has(f):
				cubos[f] = []
			cubos[f].append(nodos.size() - 1)
			if f < f_min:
				f_min = f
		nodo.t = null if idx != 0 else nodo.t   # (se libera la memoria de los ya expandidos)
	return {"ok": false, "moves": 0, "states": expandidos, "path": [], "tope": true}


static func _camino(nodos: Array, idx: int, expandidos: int) -> Dictionary:
	var path: Array = []
	var i := idx
	while nodos[i].padre >= 0:
		path.push_front(nodos[i].accion)
		i = nodos[i].padre
	return {"ok": true, "moves": path.size(), "path": path, "states": expandidos}
