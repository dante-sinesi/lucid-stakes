extends SceneTree
## ¿El motor de GDScript y el nativo dan lo mismo con bloques especiales? Arma salas chicas al azar (una escalera en el 3x3 con algunos bloques de un tipo especial) y compara
## si se resuelven y en cuántos pasos. GAME_SANDBOX=1 godot --headless --path . -s salas_nuevas/test_especiales.gd -- [TIPOS=hcstik] [SALAS=25]
const Motor := preload("res://salas_nuevas/motor.gd")
const Reglas := preload("res://salas_nuevas/reglas.gd")
const Sol := preload("res://salas_nuevas/solucionador.gd")
const Nat := preload("res://salas_nuevas/nativo.gd")


func _sala(rng: RandomNumberGenerator, tipo: String, h: int):
	# camino al azar de h celdas en el 3x3 (de una esquina a un borde lejano), un bloque por piso; el último es el fijo de la salida
	var camino: Array = []
	for intento in 200:
		camino = [Vector2i([0, 2][rng.randi_range(0, 1)], [0, 2][rng.randi_range(0, 1)])]
		var usados := {camino[0]: true}
		var ok := true
		while camino.size() < h and ok:
			var opc: Array = []
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = camino[-1] + d
				if n.x >= 0 and n.x < 3 and n.y >= 0 and n.y < 3 and not usados.has(n):
					opc.append(n)
			if opc.is_empty():
				ok = false
			else:
				var n: Vector2i = opc[rng.randi_range(0, opc.size() - 1)]
				camino.append(n)
				usados[n] = true
		var fin: Vector2i = camino[-1]
		if ok and (absi(fin.x - camino[0].x) + absi(fin.y - camino[0].y) >= 3 or camino.size() < h):
			break
	var t = Motor.nueva(h, Vector3i(camino[0].x, 2, camino[0].y))
	for k in camino.size():
		var c := Vector3i(camino[k].x, k + 1, camino[k].y)
		t.poner(c, "p" if k == 0 else ("f" if k == camino.size() - 1 else "n"))
	# material extra y especiales
	var extras := 0
	for i in 200:
		if extras >= 5:
			break
		var base: Vector3i = t.bloques.keys()[rng.randi_range(0, t.bloques.size() - 1)]
		var c: Vector3i = base + Reglas.VECINOS[rng.randi_range(0, Reglas.VECINOS.size() - 1)]
		if c.x < 0 or c.x > 2 or c.z < 0 or c.z > 2 or c.y < 2 or c.y > h - 1 or t.bloques.has(c) or c == t.jugador:
			continue
		t.bloques[c] = tipo
		var r := Reglas.asentar(t.bloques, t.jugador)
		if r.caidos > 0 or r.perdidos > 0:
			t.bloques.erase(c)
			continue
		extras += 1
	return t


func _init() -> void:
	var o := {}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2:
			o[kv[0]] = kv[1]
	var tipos: String = o.get("TIPOS", "hcstik")
	var salas := int(o.get("SALAS", 25))
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var fallos := 0
	for tipo in tipos:
		var comparadas := 0
		var difieren := 0
		var solo_nativo := 0
		for n in salas:
			var t = _sala(rng, tipo, rng.randi_range(5, 7))
			var nat: Dictionary = Nat.resolver(t, 400000)
			var gd: Dictionary = Sol.resolver(t, 40000)
			if nat.ok and gd.ok:
				comparadas += 1
				if nat.moves != gd.moves:
					difieren += 1
					print("  DIFIEREN (%s): nativo %d, GDScript %d" % [tipo, nat.moves, gd.moves])
				# el camino nativo, jugado en GDScript, tiene que ganar
				var u = t.duplicar()
				for p in nat.path:
					u.actuar(p[0], p[1])
				if not u.ganado:
					difieren += 1
					print("  EL CAMINO NATIVO NO GANA EN GDSCRIPT (%s)" % tipo)
			elif nat.ok and not gd.ok and not gd.get("tope", false):
				difieren += 1
				print("  el nativo la resuelve y GDScript dice que no tiene solución (%s)" % tipo)
			elif nat.ok:
				solo_nativo += 1
		fallos += difieren
		print("tipo '%s': %d comparadas, %d difieren, %d sólo las resolvió el nativo (GDScript sin presupuesto)" % [tipo, comparadas, difieren, solo_nativo])
	print("fallos: ", fallos)
	quit(0)
