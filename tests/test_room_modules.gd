extends SceneTree
## Salas altas por módulos (scripts/room_modules.gd): salen, son estables, se resuelven con el solucionador exacto y los especiales hacen falta.
const RoomModules := preload("res://scripts/room_modules.gd")
const StepLib := preload("res://scripts/step_lib.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	var made := 0
	for i in 8:
		var gen := RoomModules.new(2000 + i)
		var r := gen.build("3x8", 9, ["pinchos", "hielo", "transporte", "escalera"])
		if r.is_empty():
			continue
		made += 1
		var step: Dictionary = r.step
		check(StepLib.validate(step) == "", "la sala armada es válida (%s)" % StepLib.validate(step))
		check(StepLib.unsupported_cells(step).is_empty(), "la sala armada es estable")
		check(int(step.exit[1]) - 1 >= 9, "llega a la altura pedida (%d)" % (int(step.exit[1]) - 1))
		check(step.holes.size() == 64 and step.fixed.size() > 0, "sin piso y con el núcleo")
		check(r.modules.size() >= 2, "tiene al menos dos módulos")
		var ev := StepLib.evaluate(step, 1500000, 30000, true)
		check(bool(ev.ok), "el solucionador exacto la resuelve (%s)" % StepLib.describe(ev))
		if bool(ev.ok):
			check(int(ev.moves) <= r.path.size(), "el camino más corto no es más largo que el armado (%d contra %d)" % [int(ev.moves), r.path.size()])
		if made >= 2:
			break
	check(made >= 1, "salió al menos una sala")
	# la 3x3 no toca el núcleo: sin núcleo
	var g3 := RoomModules.new(5)
	g3.build("3x3", 5, ["escalera"])
	check(not g3.with_core, "la 3x3 no usa el núcleo")
	print("tests de los módulos terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
