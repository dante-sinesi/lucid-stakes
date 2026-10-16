extends SceneTree
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_solver.gd

const TowerLogic := preload("res://scripts/tower_logic.gd")
const Solver := preload("res://scripts/solver.gd")
const E := Vector3i(1, 0, 0)

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func fresh() -> RefCounted:
	var t := TowerLogic.new()
	t.size = Vector2i(5, 5)
	t.collapse_every = 1000
	t.moves_to_collapse = 1000
	for x in 5:
		for z in 5:
			t.add_block(Vector3i(x, 0, z))
	t.player = Vector3i(2, 1, 2)
	return t


func _init() -> void:
	var t := fresh()
	t.add_block(Vector3i(3, 1, 2))
	var r := Solver.solve(t, 2)
	check(r.status == "solved" and r.moves == 1, "un escalon: 1 movimiento")
	check(r.path.size() == 1 and r.path[0].dir == E, "el camino es ir al este")

	# Bloque de abajo con otro encima: no se puede trepar; hay que empujarlo (y el de arriba cae).
	t = fresh()
	t.add_block(Vector3i(3, 1, 2))
	t.add_block(Vector3i(3, 2, 2))
	r = Solver.solve(t, 2)
	check(r.status == "solved" and r.moves == 2, "columna de 2: empujar y trepar = 2 movimientos")
	check(r.path.size() == 2 and r.path[0].mode == TowerLogic.Mode.GRAB, "el primer paso es empujar")

	# Con caída cada 1 movimiento, la fila base se cae bajo los pies antes de terminar.
	t.collapse_every = 1
	t.moves_to_collapse = 1
	r = Solver.solve(t, 2, {"use_collapse": true})
	check(r.status == "unsolvable", "con caida cada 1 movimiento es imposible")
	r = Solver.solve(t, 2, {"use_collapse": false})
	check(r.status == "solved" and r.moves == 2, "sin simular la caida sigue siendo 2")

	# Sin bloques para subir: el espacio de estados se agota.
	t = fresh()
	r = Solver.solve(t, 3)
	check(r.status == "unsolvable", "sin bloques no se puede subir")

	r = Solver.solve(t, 3, {"max_states": 5})
	check(r.status == "limit", "respeta el tope de estados")

	# Torre generada: perfil por filas.
	var tower := TowerLogic.new()
	tower.generate(3)
	var t0 := Time.get_ticks_msec()
	var prof := Solver.solve_rows(tower)
	var ms := Time.get_ticks_msec() - t0
	var sum := 0
	for m in prof.rows:
		sum += m
	print("perfil global seed 3: ", prof.rows, " estados: ", prof.states, " tiempo(ms): ", ms)
	check(prof.status == "solved" and prof.total == 9 and sum == 9, "torre generada: el minimo total es 9 y el perfil suma 9")
	check(prof.rows.size() == 8, "una entrada por cada subida de altura (de y=1 a y=9)")

	var greedy := Solver.solve_rows_greedy(tower)
	print("perfil codicioso seed 3: ", greedy.rows, " total: ", greedy.total)
	check(greedy.status == "solved" and greedy.total >= prof.total, "el codicioso nunca baja del minimo global")

	# La solucion con caida de la fila base tambien existe para la torre generada (N = 6).
	var tw := Solver.solve(tower, tower.goal_y, {"use_collapse": true})
	check(tw.status == "solved" and tw.moves == 9, "con caida cada 6, el minimo sigue siendo 9")

	test_prefer_plain()
	test_kinds()
	print("tests del solucionador terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_kinds() -> void:
	var ICE := TowerLogic.Kind.ICE
	var BOMB := TowerLogic.Kind.BOMB
	var CAT := TowerLogic.Kind.CATAPULT

	# Hielo: caminar por una fila de hielo es un solo movimiento (resbala hasta el final).
	var t := fresh()
	t.player = Vector3i(0, 1, 2)
	for x in range(1, 4):
		t.kind_of[t.blocks[Vector3i(x, 0, 2)]] = ICE
	t.add_block(Vector3i(4, 1, 2))  # al final hay un bloque; el hielo termina antes
	var r := Solver.solve(t, 2)
	check(r.status == "solved" and r.moves == 2, "hielo: resbalar hasta (3,1,2) y trepar = 2 movimientos")
	check(r.path.size() == 2, "hielo: el camino tiene 2 pasos")

	# Bomba: la cuenta limita el plan. Escalon que exige empujar un bloque: 2 movimientos.
	t = fresh()
	t.add_block(Vector3i(3, 1, 2))
	t.add_block(Vector3i(3, 2, 2))
	t.add_block(Vector3i(1, 1, 1), false, BOMB, 1)  # explota despues del 1.er movimiento
	r = Solver.solve(t, 2)
	check(r.status == "unsolvable", "bomba con cuenta 1: explota antes de terminar el plan de 2 movimientos -> imposible")
	t = fresh()
	t.add_block(Vector3i(3, 1, 2))
	t.add_block(Vector3i(3, 2, 2))
	t.add_block(Vector3i(1, 1, 1), false, BOMB, 2)
	r = Solver.solve(t, 2)
	check(r.status == "solved" and r.moves == 2, "bomba con cuenta 2: se llega a la meta en el movimiento 2, antes de que explote (ganar tiene prioridad)")

	# Purificar desactiva la bomba: con cuenta 1 el plan solo sirve si el primer paso es pararse sobre ella.
	t = fresh()
	t.add_block(Vector3i(3, 1, 2), false, BOMB, 1)
	t.add_block(Vector3i(4, 1, 2))
	t.add_block(Vector3i(4, 2, 2))
	r = Solver.solve(t, 3)
	check(r.status == "solved" and r.moves == 2 and r.path[0].dir == Vector3i(1, 0, 0), "bomba con cuenta 1: se desactiva pisandola y se llega en 2 movimientos")
	# Si la bomba esta fuera de camino pero con el jugador en su zona y con cuenta 1, cualquier primer movimiento la hace explotar.
	t = fresh()
	t.add_block(Vector3i(3, 1, 2))
	t.add_block(Vector3i(3, 2, 2))
	t.add_block(Vector3i(1, 1, 1), false, BOMB, 1)
	r = Solver.solve(t, 2)
	check(r.status == "unsolvable", "bomba lejana con cuenta 1: sigue siendo imposible")

	# Catapulta: con una pared de 6 al lado, llegar a la altura 7 cuesta 2 movimientos (subir y agarrarse, trepar).
	t = fresh()
	t.player = Vector3i(0, 1, 2)
	for y in range(1, 7):
		t.add_block(Vector3i(2, y, 2))
	var w = t.clone()
	w.add_block(Vector3i(1, 1, 2), false, CAT)
	r = Solver.solve(w, 7)
	check(r.status == "solved" and r.moves == 2, "catapulta: una pared de 6 se supera en 2 movimientos")
	# Sin la catapulta esa altura no se alcanza (la pared no se puede trepar).
	r = Solver.solve(t, 7, {"max_states": 100000})  # con empujar hacia afuera, tirar colgado y el apoyo por arista hay muchos estados que explorar
	check(r.status != "solved", "sin catapulta la pared no se puede superar (no hay solucion; con el apoyo por arista el espacio es enorme y puede cortar por el tope) (estado: %s, estados explorados: %d)" % [r.status, r.states])

	# La heuristica con catapultas no sobrestima: el optimo con y sin heuristica coincide.
	var a := Solver.solve(w, 7)
	var b := Solver.solve(w, 7, {"heuristic": false})
	check(a.moves == b.moves, "A* con heuristica y BFS puro dan el mismo minimo con catapultas")
	check(Solver._max_gain(w) == 5 and Solver._max_gain(t) == 1, "la ganancia maxima por accion es 5 con catapultas y 1 sin ellas")

	# La clave del estado distingue celdas fuera de la huella (los bloques empujados pueden salir): sin choques.
	var seen := {}
	var unique := true
	for x in range(-4, 14):
		for z in range(-4, 14):
			for y in range(0, 60, 7):
				var e := Solver._enc(Vector3i(x, y, z))
				unique = unique and not seen.has(e)
				seen[e] = true
	check(unique, "_enc da un numero distinto a cada celda, tambien con coordenadas negativas o fuera de la huella")

	# Mismo estado con distinto tipo de bloque no se confunde en el visitado.
	t = fresh()
	t.add_block(Vector3i(3, 1, 2), false, ICE)
	var ta = fresh()
	ta.add_block(Vector3i(3, 1, 2))
	check(Solver._key(t, false) != Solver._key(ta, false), "la clave del estado distingue el tipo de bloque")


## Con "prefer_plain", entre dos caminos del mismo largo se elige el que no arrastra bloques de balde.
func test_prefer_plain() -> void:
	var t := fresh()
	t.player = Vector3i(1, 1, 2)
	t.add_block(Vector3i(0, 1, 2))   # un bloque atras: tirar de el (Shift + E) avanza igual que caminar
	t.add_block(Vector3i(3, 1, 2))   # el escalon que hay que trepar
	var goal := {t.blocks[Vector3i(3, 1, 2)]: true}   # hay que terminar parado sobre el escalon
	var plain := Solver.solve(t, 2, {"prefer_plain": true, "goal_ids": goal})
	var any := Solver.solve(t, 2, {"goal_ids": goal})
	check(plain.status == "solved" and any.status == "solved" and plain.moves == any.moves and plain.moves == 2, "con o sin desempate el largo es el mismo (2 movimientos)")
	var grabs := 0
	for a in plain.path:
		if a.mode != TowerLogic.Mode.MOVE:
			grabs += 1
	check(grabs == 0, "con desempate no se arrastra un bloque que no hace falta")
	# Si el empujar hace falta, se usa igual (un bloque encima del escalon).
	t = fresh()
	t.add_block(Vector3i(3, 1, 2))
	t.add_block(Vector3i(3, 2, 2))
	var need := Solver.solve(t, 2, {"prefer_plain": true})
	check(need.status == "solved" and need.moves == 2 and need.path[0].mode == TowerLogic.Mode.GRAB, "cuando hay que empujar, se empuja (el desempate no cambia el minimo)")
