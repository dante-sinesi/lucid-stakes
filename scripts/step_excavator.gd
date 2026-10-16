extends RefCounted
## Excavar una sala libre (un paso, ver scripts/step_lib.gd): el solucionador nativo explora el grafo de estados alrededor del camino de la sala y propone otras disposiciones de bloques sueltos alcanzables
## desde ella; cada una se resuelve con el solucionador exacto y se queda con la de más dificultad (empujes y tirones sobre pasos del camino más corto). Se repite desde la mejor.
## Los bloques especiales que tiene la sala tienen que seguir haciendo falta (si no, la disposición se descarta), y la sala tiene que seguir siendo estable.
## Es la misma idea que la excavación de salas con pilar (docs/solucionador_nativo_y_excavacion.md), pero sin piso ni pilar. Lo usa tests/exp_modulos_excavar.gd.

const StepLib := preload("res://scripts/step_lib.gd")
const NativeSolver := preload("res://scripts/native_solver.gd")
const TowerLogic := preload("res://scripts/tower_logic.gd")

var rng := RandomNumberGenerator.new()
var eval_cap := 600000
var log: Array = []


func _init(seed_value := 1) -> void:
	rng.seed = seed_value


func _path_text(path: Array) -> String:
	var dirs := {Vector3i(1, 0, 0): "E", Vector3i(-1, 0, 0): "W", Vector3i(0, 0, 1): "S", Vector3i(0, 0, -1): "N"}
	var out := ""
	for a in path:
		out += "mgh"[int(a.mode)] + String(dirs[a.dir])
	return out


## ¿Todos los bloques especiales de la sala hacen falta?
func _all_needed(ev: Dictionary) -> bool:
	for kd in ev.get("needed", {}):
		if not bool(ev.needed[kd]):
			return false
	return true


## Una variante con un cambio chico en los bloques comunes: agregar uno pegado a lo que hay, sacar uno o mover uno de lugar. {} si no se pudo.
func _mutate(step: Dictionary, arena: Array) -> Dictionary:
	var cand := StepLib.copy_step(step)
	var cells := {}
	for b in cand.blocks:
		cells[Vector3i(int(b[0]), int(b[1]), int(b[2]))] = int(b[3])
	var normals: Array = []
	for c in cells:
		if cells[c] == TowerLogic.Kind.NORMAL:
			normals.append(c)
	var arena_set := {}
	for a in arena:
		arena_set[Vector2i(a.x, a.y)] = true
	var op := rng.randi_range(0, 2)
	if op == 1 and normals.size() > 1:   # sacar
		cells.erase(normals[rng.randi_range(0, normals.size() - 1)])
	else:
		if op == 2 and not normals.is_empty():   # mover: sacar y poner en otro lado
			cells.erase(normals[rng.randi_range(0, normals.size() - 1)])
		var base: Array = cells.keys()
		if base.is_empty():
			return {}
		var anchor: Vector3i = base[rng.randi_range(0, base.size() - 1)]
		var d: Array = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]
		var c: Vector3i = anchor + d[rng.randi_range(0, d.size() - 1)]
		if cells.has(c) or c.y < 1 or c.y > int(step.h) or not arena_set.has(Vector2i(c.x, c.z)):
			return {}
		cells[c] = TowerLogic.Kind.NORMAL
	cand.blocks = []
	for c in cells:
		cand.blocks.append([c.x, c.y, c.z, int(cells[c])])
	return cand


## Mejora la dificultad de la sala. `arena`: celdas (x, z) donde puede haber bloques sueltos. {step, ev, rounds}.
func improve(step: Dictionary, arena: Array, rounds := 6, nodes := 800000, top := 600, eval_n := 24, mutations := 16, patience := 3) -> Dictionary:
	var cur := StepLib.copy_step(step)
	var cur_ev := StepLib.evaluate(cur, eval_cap, 20000, true)
	if not bool(cur_ev.ok):
		return {"step": cur, "ev": cur_ev, "rounds": 0}
	var seen := {}
	seen[_key(cur)] = true
	var done := 0
	var stale := 0
	var top_step := cur
	var top_ev := cur_ev
	for r in rounds:
		var t = StepLib.build_state(cur)
		var ex := NativeSolver.excavate(t, Vector2i(int(cur.entry[0]), int(cur.entry[2])), Vector2i(-99, -99), _path_text(cur_ev.path), nodes, top, 0, false, int(cur.h), arena, true, true)
		if ex.is_empty() or ex.cands.is_empty():
			break
		var keep_specials := _specials_key(cur.blocks)
		var valid: Array = []
		for ci in ex.cands.size():
			if _specials_key(ex.cands[ci].blocks) == keep_specials:
				valid.append(ci)
		var order: Array = valid
		var head := mini(eval_n / 2, order.size())
		var tail: Array = order.slice(head)
		for i in range(tail.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = tail[i]
			tail[i] = tail[j]
			tail[j] = tmp
		order = order.slice(0, head) + tail
		var best_step: Dictionary = {}
		var best_ev: Dictionary = {}
		var tried := 0
		var why := {"inestable": 0, "sin_solucion": 0, "especial_adorno": 0, "valida": 0}
		for oi in order:
			if tried >= eval_n:
				break
			var cd: Dictionary = ex.cands[oi]
			var cand := StepLib.copy_step(cur)
			cand.blocks = []
			for b in cd.blocks:
				cand.blocks.append([int(b[0]), int(b[1]), int(b[2]), int(b[3])])
			if StepLib.validate(cand) != "":
				why.valida += 1
				continue
			var key := _key(cand)
			if seen.has(key):
				continue
			seen[key] = true
			tried += 1
			if not StepLib.unsupported_cells(cand).is_empty():
				why.inestable += 1
				continue
			var ev := StepLib.evaluate(cand, eval_cap, 8000, true)
			if not bool(ev.ok):
				why.sin_solucion += 1
				continue
			if not _all_needed(ev):
				why.especial_adorno += 1
				continue
			if best_ev.is_empty() or float(ev.diff) > float(best_ev.diff) or (is_equal_approx(float(ev.diff), float(best_ev.diff)) and int(ev.grabs) > int(best_ev.grabs)):
				best_step = cand
				best_ev = ev
		for m in mutations:
			var mc := _mutate(cur, arena)
			if mc.is_empty() or StepLib.validate(mc) != "":
				continue
			var mk := _key(mc)
			if seen.has(mk):
				continue
			seen[mk] = true
			if not StepLib.unsupported_cells(mc).is_empty():
				continue
			var mev := StepLib.evaluate(mc, eval_cap, 6000, true)
			if not bool(mev.ok) or not _all_needed(mev):
				continue
			if best_ev.is_empty() or float(mev.diff) > float(best_ev.diff) or (is_equal_approx(float(mev.diff), float(best_ev.diff)) and int(mev.grabs) > int(best_ev.grabs)):
				best_step = mc
				best_ev = mev
		log.append("ronda %d: %d nodos, %d candidatas (%d con los especiales en su lugar), %d evaluadas %s, mejor %s" % [r, int(ex.nodes), ex.cands.size(), valid.size(), tried, str(why), ("%d%% (%d de %d)" % [roundi(100.0 * float(best_ev.diff)), int(best_ev.grabs), int(best_ev.moves)]) if not best_ev.is_empty() else "ninguna"])
		if best_ev.is_empty():
			break
		var better: bool = float(best_ev.diff) > float(top_ev.diff) + 0.0001 or (is_equal_approx(float(best_ev.diff), float(top_ev.diff)) and int(best_ev.grabs) > int(top_ev.grabs))
		if better:
			top_step = best_step
			top_ev = best_ev
			stale = 0
			done += 1
		else:
			stale += 1
			if stale >= patience:
				break
		cur = best_step    # (se sigue desde lo mejor de la ronda aunque no supere al mejor de todos: así se sale de un óptimo local)
		cur_ev = best_ev
	StepLib.finalize(top_step)
	return {"step": top_step, "ev": top_ev, "rounds": done}


## Los bloques especiales (todos menos común y pesado) con su celda y su tipo: la excavación no los mueve de lugar.
func _specials_key(blocks: Array) -> String:
	var parts: Array = []
	for b in blocks:
		var kd := int(b[3])
		if kd != TowerLogic.Kind.NORMAL and kd != TowerLogic.Kind.HEAVY:
			parts.append("%d,%d,%d,%d" % [int(b[0]), int(b[1]), int(b[2]), kd])
	parts.sort()
	return ";".join(parts)


func _key(step: Dictionary) -> String:
	var parts: Array = []
	for b in step.blocks:
		parts.append("%d,%d,%d,%d" % [int(b[0]), int(b[1]), int(b[2]), int(b[3])])
	parts.sort()
	return ";".join(parts)
