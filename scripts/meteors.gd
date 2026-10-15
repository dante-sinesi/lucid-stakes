extends RefCounted
## Lluvia de meteoritos (la prueba del mismo nombre): cada vez que el jugador se mueve cae un meteorito y destruye un bloque, que se marca antes de caer.
## Para no arruinar la partida, el camino de la solución de la torre está GARANTIZADO: los bloques que ese camino usa (donde se para, de donde se cuelga,
## los que empuja o tira y los que pisa al resbalar) nunca se eligen, y tampoco un bloque cuya caída mueva a alguno de ellos (eso lo verifica
## TowerLogic._meteor_safe simulando la caída). Acá está el cálculo de ese camino; el resto (elegir el bloque y destruirlo) vive en TowerLogic.

const TowerLogic := preload("res://scripts/tower_logic.gd")
const _AROUND: Array[Vector3i] = [Vector3i(0, -1, 0), Vector3i(0, -2, 0), Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	Vector3i(1, -1, 0), Vector3i(-1, -1, 0), Vector3i(0, -1, 1), Vector3i(0, -1, -1)]


## Los ids de los bloques que usa `path` (la solución, una lista de {dir, mode}) partiendo del estado `start`.
static func guaranteed_ids(start, path: Array) -> Dictionary:
	var ids := {}
	var sim = start.clone()
	sim.meteors = false
	_mark_under(sim, ids)
	if sim.goal_block >= 0:
		ids[sim.goal_block] = true
	for step in path:
		var before: Dictionary = sim.positions.duplicate()
		var res: Dictionary = sim.try_action(step.dir, step.mode)
		if not res.ok:
			break
		for id in before:   # los bloques que se movieron (empujados o tirados; incluye los que se cayeron al vacío)
			if sim.positions.get(id) != before[id]:
				ids[id] = true
		for id in sim.removed_ids:   # los que se rompieron o cayeron durante el paso (un bloque agrietado que se pisa, una bomba que explota)
			ids[id] = true
		for c in sim.trail:   # lo que se pisó al resbalar, saltar o ser lanzado, con lo que mira el deslizamiento (el escalón de abajo y las paredes que lo frenan)
			for off in _AROUND:
				var bid: int = sim.blocks.get(c + off, -1)
				if bid >= 0:
					ids[bid] = true
		_mark_under(sim, ids)
		if sim.won or sim.lost:
			break
	return ids


static func _mark_under(sim, ids: Dictionary) -> void:
	var under: int = sim.blocks.get(sim.player + TowerLogic.DOWN, -1)
	if under >= 0:
		ids[under] = true
	if sim.hang_dir != Vector3i.ZERO:
		var hung: int = sim.blocks.get(sim.player + sim.hang_dir, -1)
		if hung >= 0:
			ids[hung] = true


## La solución como lista de números (para guardarla con la partida): dirección * 3 + modo.
static func encode(path: Array) -> Array:
	var out: Array = []
	for step in path:
		out.append(TowerLogic.DIRS.find(step.dir) * 3 + int(step.mode))
	return out


static func decode(codes: Array) -> Array:
	var out: Array = []
	for c in codes:
		var code := int(c)
		out.append({"dir": TowerLogic.DIRS[code / 3], "mode": code % 3})
	return out
