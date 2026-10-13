extends SceneTree
## Lluvia de meteoritos: cada movimiento destruye el bloque marcado, y el camino de la solución nunca se rompe.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_meteors.gd

const Gen := preload("res://scripts/tower_gen.gd")
const Meteors := preload("res://scripts/meteors.gd")
const Trials := preload("res://scripts/trials.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	check(Trials.CATALOG.has("meteoritos") and Trials.CATALOG.meteoritos.get("meteors", false), "la prueba existe")
	for s in [11, 29, 47]:
		var res: Dictionary = Gen.generate_stage(s, 6, 0.4, {})
		check(res.ok, "se generó la torre %d" % s)
		if not res.ok:
			continue
		check(Meteors.decode(Meteors.encode(res.path)) == res.path, "la solución se guarda y se recupera")
		var logic = res.logic.clone()
		logic.lazy_settle = false
		logic.meteors = true
		logic.protected_ids = Meteors.guaranteed_ids(res.logic, res.path)
		logic.meteor_rng.seed = s
		logic.meteor_prime()
		check(logic.meteor_cell != TowerLogic.NO_CELL, "hay un bloque marcado desde el principio")
		var hits := 0
		for step in res.path:
			var marked: Vector3i = logic.meteor_cell
			if not logic.try_action(step.dir, step.mode).ok:
				break
			if logic.meteor_hit != TowerLogic.NO_CELL:
				hits += 1
				check(logic.meteor_hit == marked, "cae el bloque que estaba marcado")
			if logic.won or logic.lost:
				break
		check(logic.won, "la solución sigue ganando con los meteoritos (torre %d)" % s)
		check(hits > 0, "cayeron meteoritos (torre %d: %d)" % [s, hits])
	print("tests de los meteoritos terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
