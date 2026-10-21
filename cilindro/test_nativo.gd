extends SceneTree
## Compara el solucionador nativo con el de GDScript sobre estados desordenados. GAME_SANDBOX=1 godot --headless --path . -s cilindro/test_nativo.gd
const Esc := preload("res://cilindro/escalera.gd")
const Des := preload("res://cilindro/desordenador.gd")
const Sol := preload("res://cilindro/solucionador.gd")
const Nat := preload("res://cilindro/nativo.gd")


func _init() -> void:
	var fallos := 0
	for semilla in range(1, 9):
		var rng := RandomNumberGenerator.new()
		rng.seed = semilla
		var e = Esc.construir(6, rng.randi_range(0, 27), 1 if rng.randf() < 0.5 else -1)
		if e == null:
			continue
		Esc.ramas(rng, e, 8)
		var fin = Esc.resuelta(e)
		if fin == null:
			continue
		var r := Des.desordenar_haz(rng, fin, 4, 8, 40, 4.0, 3, 2, 3)
		if r.is_empty():
			continue
		var s = r.estado
		var a := Sol.resolver(s, 100000)
		var t0 := Time.get_ticks_msec()
		var b := Nat.resolver(s)
		var ms := Time.get_ticks_msec() - t0
		# el camino nativo, jugado en el motor de GDScript, tiene que ganar
		var u = s.duplicar()
		for p in b.path:
			u.actuar(p[0], p[1])
		var coincide: bool = a.ok == b.ok and (not a.ok or a.moves == b.moves) and u.ganado == b.ok
		if not coincide:
			fallos += 1
		print("semilla %d: GD %s/%d  nativo %s/%d (%d ms, %d nodos, %d agarres, %d distintos), camino nativo gana en GD: %s -> %s" % [semilla, str(a.ok), a.moves, str(b.ok), b.moves, ms, b.states, b.agarres, b.distintos, str(u.ganado), "ok" if coincide else "FALLA"])
	print("fallos: ", fallos)
	quit(0)
