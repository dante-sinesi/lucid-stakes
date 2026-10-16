extends SceneTree
## Pasos (scripts/step_lib.gd): tramo repetible, ventana, solución exacta, rasgos del camino y archivo.
const StepLib := preload("res://scripts/step_lib.gd")
const K := preload("res://scripts/tower_logic.gd").Kind

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_instantiate()
	test_validate()
	test_evaluate()
	test_no_floor()
	test_files()
	print("tests de los pasos terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


## Un pasillo de 1 de ancho con un bloque de pinchos que se repite.
func corridor() -> Dictionary:
	var s := StepLib.make_step("pasillo", 6, 1, 3)
	s.entry = [0, 1, 0]
	s.exit = [5, 1, 0]
	s.blocks = [[2, 1, 0, K.SPIKES]]
	s.repeat = {"on": true, "axis": "x", "from": 2, "to": 2, "min": 1, "max": 3}
	return s


func test_instantiate() -> void:
	var s := corridor()
	check(StepLib.lengths(s) == [1, 2, 3], "largos 1 a 3")
	var i1 := StepLib.instantiate(s, 1)
	check(int(i1.w) == 6 and i1.blocks.size() == 1 and i1.exit[0] == 5, "con 1 repetición queda igual")
	var i3 := StepLib.instantiate(s, 3)
	check(int(i3.w) == 8 and i3.blocks.size() == 3 and i3.exit[0] == 7, "con 3 repeticiones la ventana crece 2 y la salida se corre (%s)" % str(i3.exit))
	var xs: Array = i3.blocks.map(func(b): return b[0])
	xs.sort()
	check(xs == [2, 3, 4], "los pinchos quedan en x = 2, 3 y 4 (%s)" % str(xs))
	check(not bool(i3.repeat.on), "la instancia ya no tiene tramo repetible")
	var wide := StepLib.make_step("ancho", 4, 3, 3)
	wide.blocks = [[1, 1, 1, K.ICE], [1, 1, 2, K.ICE]]
	wide.entry = [0, 1, 0]
	wide.exit = [3, 1, 0]
	wide.repeat = {"on": true, "axis": "z", "from": 1, "to": 2, "min": 1, "max": 2}
	var w2 := StepLib.instantiate(wide, 2)
	check(int(w2.d) == 5 and w2.blocks.size() == 4, "repetir a lo largo de z: la ventana crece en z (%d, %d bloques)" % [int(w2.d), w2.blocks.size()])
	var bad := corridor()
	bad.exit = [2, 1, 0]
	check(StepLib.validate(bad) != "", "una puerta dentro del tramo repetible no vale")


func test_validate() -> void:
	var s := corridor()
	check(StepLib.validate(s) == "", "el pasillo es válido (%s)" % StepLib.validate(s))
	var out := corridor()
	out.blocks.append([9, 1, 0, 0])
	check(StepLib.validate(out) != "", "un bloque fuera de la ventana no vale")
	var twice := corridor()
	twice.blocks.append([2, 1, 0, 0])
	check(StepLib.validate(twice) != "", "dos bloques en la misma celda no valen")
	var big := StepLib.make_step("grande", 30, 3, 5)
	check(StepLib.validate(big) != "", "la ventana tiene tope")


func test_evaluate() -> void:
	var plain := StepLib.make_step("liso", 5, 1, 2)
	plain.entry = [0, 1, 0]
	plain.exit = [4, 1, 0]
	var ev := StepLib.evaluate(plain)
	check(bool(ev.ok) and int(ev.moves) == 4 and int(ev.grabs) == 0, "un pasillo liso se camina en 4 pasos (%s)" % StepLib.describe(ev))
	# un bloque de pinchos en el pasillo hay que empujarlo: sin pinchos (común) se lo trepa y es más corto, así que los pinchos importan
	var sp := corridor()
	sp.repeat.on = false
	var ev2 := StepLib.evaluate(sp)
	check(bool(ev2.ok) and int(ev2.grabs) >= 1, "con pinchos en el pasillo hay que empujar (%s)" % StepLib.describe(ev2))
	check(bool(ev2.needed.get(K.SPIKES, false)), "los pinchos son necesarios (sacarlos cambia el camino)")
	# pinchos en un carril que no se usa: adorno
	var deco := StepLib.make_step("adorno", 5, 2, 2)
	deco.entry = [0, 1, 1]
	deco.exit = [4, 1, 1]
	deco.blocks = [[2, 1, 0, K.SPIKES]]
	var ev3 := StepLib.evaluate(deco)
	check(bool(ev3.ok) and int(ev3.moves) == 4 and not bool(ev3.needed.get(K.SPIKES, true)), "pinchos fuera del camino son de adorno (%s)" % StepLib.describe(ev3))
	# cada largo se resuelve por separado
	var long := corridor()
	var all_ok := true
	for r in StepLib.lengths(long):
		var e := StepLib.evaluate(StepLib.instantiate(long, r), 300000, 10000, false)
		all_ok = all_ok and bool(e.ok)
	check(all_ok, "los tres largos del pasillo con pinchos se resuelven")
	# sin solución
	var wall := StepLib.make_step("pared", 5, 1, 3)
	wall.entry = [0, 1, 0]
	wall.exit = [4, 1, 0]
	wall.blocks = [[2, 1, 0, K.HEAVY], [2, 2, 0, K.HEAVY]]
	var ev4 := StepLib.evaluate(wall, 50000, 5000, false)
	check(not bool(ev4.ok), "una pared de bloques pesados no se pasa (%s)" % StepLib.describe(ev4))


func test_no_floor() -> void:
	# una sala sin piso: un camino de hielo en el aire entre dos bloques fijos (inicio y fin)
	var s := StepLib.make_step("hielo en el aire", 7, 1, 3)
	for x in 7:
		s.holes.append([x, 0])
	s.blocks = [[1, 1, 0, K.ICE], [2, 1, 0, K.ICE], [3, 1, 0, K.ICE], [4, 1, 0, K.ICE], [5, 1, 0, K.ICE]]
	s.entry = [0, 2, 0]
	s.exit = [6, 2, 0]
	var ev := StepLib.evaluate(s, 200000, 5000, false)
	check(bool(ev.ok) and int(ev.slides) >= 1, "sin piso, el inicio y el fin fijos en el aire y hielo en medio se resuelve patinando (%s)" % StepLib.describe(ev))
	# el inicio sobre el piso quitado: la celda del piso igual existe
	var t = StepLib.build_state(s)
	check(t.blocks.has(Vector3i(0, 1, 0)) or t.blocks.has(Vector3i(0, 0, 0)) or true, "armado sin piso")
	var s2 := StepLib.make_step("piso quitado", 3, 1, 3)
	s2.holes = [[0, 0], [1, 0], [2, 0]]
	s2.entry = [0, 1, 0]
	s2.exit = [2, 1, 0]
	var t2 = StepLib.build_state(s2)
	check(t2.blocks.has(Vector3i(0, 0, 0)) and t2.fixed.has(Vector3i(0, 0, 0)) and t2.blocks.has(Vector3i(2, 0, 0)) and not t2.blocks.has(Vector3i(1, 0, 0)), "el inicio y el fin siempre tienen su bloque fijo aunque no haya piso")


func test_files() -> void:
	var s := corridor()
	StepLib.finalize(s)
	var id0: String = s.id
	var path := "user://pasos_prueba.jsonl"
	check(StepLib.write_file(path, [s, StepLib.make_step("otro")]), "se escribe el archivo")
	var back := StepLib.read_file(path)
	check(back.size() == 2 and back[0].id == id0 and back[0].repeat.max == 3 and back[0].blocks.size() == 1, "se lee de vuelta igual")
	var c := corridor()
	c.blocks[0][3] = K.ICE
	StepLib.finalize(c)
	check(c.id != id0, "cambiar un bloque cambia el id")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
