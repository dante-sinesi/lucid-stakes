extends SceneTree
## La extensión de Godot del solucionador (native/extension, docs/solver_extension.md): da la misma respuesta que tools/salas.exe en salas de todos los niveles, la solución se juega y gana, y es mucho más rápida
## (no lanza un proceso por llamada). Si la extensión no está armada (native\construir_extension.bat) no hay nada que probar. Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/unitarios/test_solver_extension.gd
const Nat := preload("res://torre/nativo.gd")
const Torre := preload("res://torre/torre.gd")
const Vista := preload("res://torre/vista.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	if not Nat.extension():
		print("(la extensión SolverNativo no está cargada: native/construir_extension.bat la arma; no hay nada que probar)")
		print("tests de la extensión del solucionador terminados, fallos: 0")
		quit()
		return
	check(Nat.disponible(), "con la extensión el solucionador está disponible")
	var paquete: Array = Torre.cargar_paquete_del_juego()
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var hay_exe := FileAccess.file_exists(Nat.exe())
	var ms_ext := 0
	var ms_exe := 0
	var comparadas := 0
	var distintas := 0
	var jugadas := 0
	var ganan := 0
	for nivel in ["facil", "media", "dificil", "pesadilla"]:
		var cand: Array = paquete.filter(func(d): return str(d.nivel) == nivel)
		for k in 6:
			var d: Dictionary = cand[rng.randi() % cand.size()]
			var m = Vista.motor_de(d)
			var a := Time.get_ticks_msec()
			var re: Dictionary = Nat.resolver_extension(m, 200000)
			ms_ext += Time.get_ticks_msec() - a
			if hay_exe:
				a = Time.get_ticks_msec()
				var rx: Dictionary = Nat.resolver_exe(m, 200000)
				ms_exe += Time.get_ticks_msec() - a
				comparadas += 1
				if bool(re.ok) != bool(rx.ok) or int(re.moves) != int(rx.moves) or int(re.agarres) != int(rx.agarres) or int(re.distintos) != int(rx.distintos) or re.path != rx.path:
					distintas += 1
					print("  difiere (%s, sala %d): extensión %s/%d, exe %s/%d" % [nivel, int(d.id), str(re.ok), int(re.moves), str(rx.ok), int(rx.moves)])
			if bool(re.ok):   # la solución de la extensión, jugada en el motor, gana
				jugadas += 1
				var mj = Vista.motor_de(d)
				for p in re.path:
					mj.actuar(p[0], int(p[1]))
				if mj.ganado:
					ganan += 1
	check(jugadas > 0 and ganan == jugadas, "la solución de la extensión, jugada en el motor, gana (%d de %d)" % [ganan, jugadas])
	if hay_exe:
		check(comparadas > 0 and distintas == 0, "misma respuesta que salas.exe en %d salas (difieren %d)" % [comparadas, distintas])
		print("tiempo: extensión %d ms, ejecutable %d ms (%d salas)" % [ms_ext, ms_exe, comparadas])
		check(ms_ext <= ms_exe, "la extensión no es más lenta que el ejecutable (%d ms contra %d ms)" % [ms_ext, ms_exe])
	# desde varios hilos a la vez (El camino corto mide en un hilo y la pista en otro): cada uno recibe la misma respuesta que en el hilo principal
	var salas_hilos: Array = []
	var esperadas: Array = []
	for k in 4:
		var d: Dictionary = paquete[rng.randi() % paquete.size()]
		salas_hilos.append(Vista.motor_de(d))
		esperadas.append(Nat.resolver_extension(salas_hilos[k], 100000))
	var hilos: Array = []
	var resultados: Array = [{}, {}, {}, {}]
	for k in 4:
		var h := Thread.new()
		h.start(func(): resultados[k] = Nat.resolver_extension(salas_hilos[k], 100000))
		hilos.append(h)
	for h in hilos:
		h.wait_to_finish()
	var iguales := true
	for k in 4:
		iguales = iguales and bool(resultados[k].ok) == bool(esperadas[k].ok) and int(resultados[k].moves) == int(esperadas[k].moves) and resultados[k].path == esperadas[k].path
	check(iguales, "desde cuatro hilos a la vez la extensión da la misma respuesta que en el hilo principal")
	var sin_salida = Nat.resolver_extension(Vista.motor_de({"meta": 5, "jugador": [0, 2, 0], "colgado": [0, 0], "bloques": []}), 1000)
	check(not bool(sin_salida.ok), "una sala sin salida no se resuelve (y no se cuelga)")
	print("tests de la extensión del solucionador terminados, fallos: %d" % fails)
	quit(1 if fails > 0 else 0)
