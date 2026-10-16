extends RefCounted
## Pasos: piezas chicas de sala que se diseñan aparte (una fila de pinchos que hay que esquivar colgándose, un camino de hielo para patinar...) y se verifican solas.
## Un paso es una ventana de w x d celdas (y hasta h pisos) con bloques, una entrada (donde empieza parado el jugador), una salida (donde tiene que quedar parado) y, si se quiere, un
## TRAMO REPETIBLE: unas columnas del paso que se repiten entre `min` y `max` veces (así la fila de pinchos puede tener 1, 2, 3... pinchos). Cada largo se arma y se resuelve por separado con el solucionador exacto.
##
## Un paso es un Dictionary:
##   format, kind "paso", name, note, id (hash), stamp
##   w, d, h        ventana: x en 0..w-1, z en 0..d-1, bloques en y = 1..h
##   blocks         [[x, y, z, tipo], ...]  tipo = TowerLogic.Kind (0 común, 1 hielo, 2 bomba, 3 catapulta, 4 agrietado, 5 pesado, 6 trampa, 7 pinchos)
##   fixed          [[x, y, z], ...]  bloques inmóviles que no caen (el núcleo de la torre, por ejemplo); y desde 0
##   holes          [[x, z], ...]  celdas del piso que no existen (pozos: se cruza colgado o saltando)
##   entry, exit    [x, y, z]  celda donde está parado el jugador (y >= 1). La salida se apoya en un bloque fijo (la plataforma de salida); la entrada también si no hay nada abajo.
##   repeat         {on, axis ("x" | "z"), from, to, min, max}: las columnas from..to (a lo largo del eje) se repiten r veces, con r entre min y max
##   results        {largo: {ok, moves, grabs, hangs, slides, ...}} lo último que se probó (para mostrar en la lista)

const TowerLogic := preload("res://scripts/tower_logic.gd")
const Solver := preload("res://scripts/solver.gd")
const RoomLib := preload("res://scripts/room_lib.gd")
const K := TowerLogic.Kind

const FORMAT := 1
const MAX_SIDE := 14   # el solucionador nativo simula hasta 14 celdas de lado
const MAX_H := 20
const KIND_NAMES := {0: "común", 1: "hielo", 2: "bomba", 3: "catapulta", 4: "agrietado", 5: "pesado", 6: "trampa", 7: "pinchos"}


static func make_step(name := "Paso nuevo", w := 6, d := 3, h := 5) -> Dictionary:
	return {"format": FORMAT, "kind": "paso", "name": name, "note": "", "id": "", "stamp": 0, "w": w, "d": d, "h": h, "blocks": [], "fixed": [], "holes": [],
		"entry": [0, 1, 1], "exit": [w - 1, 1, 1], "repeat": {"on": false, "axis": "x", "from": 1, "to": 1, "min": 1, "max": 4}, "results": {}}


static func copy_step(step: Dictionary) -> Dictionary:
	return step.duplicate(true)


## "" si el paso es coherente, si no el motivo.
static func validate(step: Dictionary) -> String:
	var w: int = step.w
	var d: int = step.d
	var h: int = step.h
	if w < 2 or d < 1 or w > MAX_SIDE or d > MAX_SIDE or h < 1 or h > MAX_H:
		return "el tamaño de la ventana está fuera de rango"
	var seen := {}
	for b in step.blocks:
		var x := int(b[0])
		var y := int(b[1])
		var z := int(b[2])
		if x < 0 or x >= w or z < 0 or z >= d or y < 1 or y > h:
			return "hay un bloque fuera de la ventana"
		if not KIND_NAMES.has(int(b[3])):
			return "tipo de bloque desconocido"
		if seen.has(Vector3i(x, y, z)):
			return "dos bloques en la misma celda"
		seen[Vector3i(x, y, z)] = true
	for f in step.get("fixed", []):
		var fc := Vector3i(int(f[0]), int(f[1]), int(f[2]))
		if fc.x < 0 or fc.x >= w or fc.z < 0 or fc.z >= d or fc.y < 0 or fc.y > h + 1:
			return "hay un bloque fijo fuera de la ventana"
		if seen.has(fc):
			return "un bloque fijo está sobre otro bloque"
		seen[fc] = true
	for port in [step.entry, step.exit]:
		var p := Vector3i(int(port[0]), int(port[1]), int(port[2]))
		if p.x < 0 or p.x >= w or p.z < 0 or p.z >= d or p.y < 1 or p.y > h + 1:
			return "una puerta está fuera de la ventana"
		if seen.has(p):
			return "una puerta está sobre un bloque"
	var rep: Dictionary = step.repeat
	if bool(rep.on):
		var lim: int = w if rep.axis == "x" else d
		if int(rep.from) < 0 or int(rep.to) < int(rep.from) or int(rep.to) >= lim:
			return "el tramo repetible está fuera de la ventana"
		if int(rep.min) < 1 or int(rep.max) < int(rep.min):
			return "el rango de repeticiones no sirve"
		for port in [step.entry, step.exit]:
			var v := int(port[0]) if rep.axis == "x" else int(port[2])
			if v >= int(rep.from) and v <= int(rep.to):
				return "una puerta no puede estar dentro del tramo repetible"
	return ""


## Cuántas repeticiones tiene el paso al armarlo con el largo `r` (sin tramo repetible, siempre 1).
static func lengths(step: Dictionary) -> Array:
	var out: Array = []
	var rep: Dictionary = step.repeat
	if not bool(rep.on):
		return [1]
	for r in range(int(rep.min), int(rep.max) + 1):
		out.append(r)
	return out


## El paso armado con el tramo repetido `r` veces: otro paso (sin tramo repetible) con la ventana más larga.
static func instantiate(step: Dictionary, r: int) -> Dictionary:
	var rep: Dictionary = step.repeat
	if not bool(rep.on):
		return copy_step(step)
	var axis: String = rep.axis
	var a := int(rep.from)
	var b := int(rep.to)
	var k := b - a + 1
	var out := copy_step(step)
	out.repeat = {"on": false, "axis": axis, "from": 0, "to": 0, "min": 1, "max": 1}
	var shift := (r - 1) * k
	var ax := 0 if axis == "x" else 2
	var blocks: Array = []
	for bl in step.blocks:
		var v := int(bl[ax])
		if v < a:
			blocks.append(bl.duplicate())
		elif v > b:
			var c: Array = bl.duplicate()
			c[ax] = v + shift
			blocks.append(c)
		else:
			for i in r:
				var c2: Array = bl.duplicate()
				c2[ax] = v + i * k
				blocks.append(c2)
	var holes: Array = []
	for ho in step.holes:
		var hv := int(ho[0]) if axis == "x" else int(ho[1])
		var hi := 0 if axis == "x" else 1
		if hv < a:
			holes.append(ho.duplicate())
		elif hv > b:
			var c3: Array = ho.duplicate()
			c3[hi] = hv + shift
			holes.append(c3)
		else:
			for i in r:
				var c4: Array = ho.duplicate()
				c4[hi] = hv + i * k
				holes.append(c4)
	var fixed: Array = []
	for fb in step.get("fixed", []):
		var fv := int(fb[ax])
		if fv < a:
			fixed.append(fb.duplicate())
		elif fv > b:
			var cf: Array = fb.duplicate()
			cf[ax] = fv + shift
			fixed.append(cf)
		else:
			for i in r:
				var cf2: Array = fb.duplicate()
				cf2[ax] = fv + i * k
				fixed.append(cf2)
	out.fixed = fixed
	out.blocks = blocks
	out.holes = holes
	for key in ["entry", "exit"]:
		var p: Array = step[key].duplicate()
		if int(p[ax]) > b:
			p[ax] = int(p[ax]) + shift
		out[key] = p
	if axis == "x":
		out.w = int(step.w) + shift
	else:
		out.d = int(step.d) + shift
	return out


## El simulador del paso (sin tramo repetible): piso fijo (menos los pozos), los bloques, la plataforma de salida (fija, con la marca de meta) y el jugador en la entrada.
static func build_state(step: Dictionary):
	var t = TowerLogic.new()
	t.size = Vector2i(int(step.w), int(step.d))
	t.collapse_every = RoomLib.BIG
	t.moves_to_collapse = RoomLib.BIG
	var holes := {}
	for ho in step.holes:
		holes[Vector2i(int(ho[0]), int(ho[1]))] = true
	var exit := Vector3i(int(step.exit[0]), int(step.exit[1]), int(step.exit[2]))
	var entry := Vector3i(int(step.entry[0]), int(step.entry[1]), int(step.entry[2]))
	var platforms := {}   # celdas fijas sobre el piso: la plataforma de salida y, si no hay nada abajo, la de entrada
	platforms[exit + Vector3i(0, -1, 0)] = true
	if not _supported_by_block(step, entry) and entry.y - 1 >= 1:
		platforms[entry + Vector3i(0, -1, 0)] = true
	for x in int(step.w):
		for z in int(step.d):
			if not holes.has(Vector2i(x, z)):
				t.add_block(Vector3i(x, 0, z), true)
	var goal_cell := exit + Vector3i(0, -1, 0)
	for f in step.get("fixed", []):
		var fc := Vector3i(int(f[0]), int(f[1]), int(f[2]))
		if not t.blocks.has(fc):
			t.add_block(fc, true)
	for b in step.blocks:
		var c := Vector3i(int(b[0]), int(b[1]), int(b[2]))
		if platforms.has(c):
			continue   # (ese bloque pasa a ser la plataforma fija)
		var kd := int(b[3])
		t.add_block(c, false, kd, RoomLib.BOMB_FUSE if kd == K.BOMB else 0)
	for c in platforms:
		if c.y >= 1:
			t.add_block(c, true)
	for support in [goal_cell, entry + Vector3i(0, -1, 0)]:
		if support.y == 0 and not t.blocks.has(support):
			t.add_block(support, true)   # (el bloque de inicio o de fin sobre un pozo: esa celda del piso igual existe)
	t.player = entry
	t.goal_y = exit.y
	t.goal_ids = {int(t.blocks[goal_cell]): true}
	return t


static func _supported_by_block(step: Dictionary, p: Vector3i) -> bool:
	if p.y - 1 == 0:
		return true
	for f in step.get("fixed", []):
		if int(f[0]) == p.x and int(f[1]) == p.y - 1 and int(f[2]) == p.z:
			return true
	for b in step.blocks:
		if int(b[0]) == p.x and int(b[1]) == p.y - 1 and int(b[2]) == p.z:
			return true
	return false


# --- ejemplos ---------------------------------------------------------------------------------------------------------------

## Pasos de ejemplo (se muestran cuando la biblioteca de pasos está vacía): una fila de pinchos que se cruza colgado del borde y un camino de hielo.
static func examples() -> Array:
	var out: Array = []
	# Pinchos: una cornisa de bloques en la que unos son de pinchos (pisarlos es perder) con un pozo al lado: hay que colgarse del borde y avanzar por debajo.
	var sp := make_step("Fila de pinchos (colgarse)", 6, 2, 3)
	sp.holes = [[1, 0], [2, 0], [3, 0], [4, 0]]
	sp.blocks = [[0, 1, 1, K.NORMAL], [1, 1, 1, K.NORMAL], [2, 1, 1, K.SPIKES], [3, 1, 1, K.NORMAL], [4, 1, 1, K.NORMAL], [5, 1, 1, K.NORMAL]]
	sp.entry = [0, 2, 1]
	sp.exit = [5, 2, 1]
	sp.repeat = {"on": true, "axis": "x", "from": 2, "to": 2, "min": 1, "max": 5}
	sp.note = "El tramo repetible es la columna de pinchos: con 1 a 5 pinchos seguidos."
	finalize(sp)
	out.append(sp)
	# Hielo: un camino de bloques de hielo hasta una plataforma; se patina todo el camino.
	var ic := make_step("Camino de hielo", 8, 2, 3)
	ic.blocks = [[0, 1, 1, K.NORMAL], [1, 1, 1, K.ICE], [2, 1, 1, K.ICE], [3, 1, 1, K.ICE], [4, 1, 1, K.ICE], [5, 1, 1, K.NORMAL], [6, 2, 1, K.NORMAL], [6, 1, 1, K.NORMAL]]
	ic.entry = [0, 2, 1]
	ic.exit = [5, 2, 0]
	ic.repeat = {"on": true, "axis": "x", "from": 2, "to": 2, "min": 1, "max": 5}
	ic.note = "El tramo repetible es una celda del camino de hielo: se patina más o menos lejos."
	finalize(ic)
	out.append(ic)
	# Hielo sin piso: nada de suelo, bloques fijos de inicio y de fin en el aire y caminos de hielo en L; se patina hasta el primer bloque que no es hielo.
	var air := make_step("Hielo sin piso (patinar en L)", 6, 5, 3)
	for x in 6:
		for z in 5:
			air.holes.append([x, z])
	air.blocks = [[1, 1, 0, K.ICE], [2, 1, 0, K.ICE], [3, 1, 0, K.ICE], [4, 1, 0, K.ICE], [5, 1, 0, K.NORMAL], [5, 1, 1, K.ICE], [5, 1, 2, K.ICE], [5, 1, 3, K.ICE]]
	air.entry = [0, 2, 0]
	air.exit = [5, 2, 4]
	air.repeat = {"on": true, "axis": "x", "from": 2, "to": 2, "min": 1, "max": 5}
	air.note = "Sin piso: el bloque verde (inicio) y el rojo (fin) están en el aire. Se patina por el camino de hielo, se frena en el bloque común, y se vuelve a patinar."
	finalize(air)
	out.append(air)
	return out


## Las celdas de los bloques sueltos del paso que se caerían al empezar (el paso no es estable).
static func unsupported_cells(step: Dictionary) -> Array:
	var t = build_state(step)
	var before: Dictionary = t.positions.duplicate()
	var fixed_ids := {}
	for c in t.fixed:
		fixed_ids[int(t.blocks[c])] = true
	t._settle()
	var out: Array = []
	for id in before:
		if fixed_ids.has(id):
			continue
		if not t.positions.has(id) or t.positions[id] != before[id]:
			out.append(before[id])
	return out


# --- resolver y medir --------------------------------------------------------------------------------------------------------

## Resuelve el paso (ya armado, sin tramo repetible) con el solucionador exacto y mide lo que hace el camino más corto.
## {ok, why, moves, grabs, moved, hangs, slides, launches, kinds (tipos de bloque que pisa o mueve), path, states, needed ({tipo: bool}: si sacar ese tipo cambia el camino)}.
static func evaluate(inst: Dictionary, cap := 600000, max_ms := 20000, check_needed := true) -> Dictionary:
	var err := validate(inst)
	if err != "":
		return {"ok": false, "why": err}
	var t = build_state(inst)
	var res: Dictionary = Solver.solve(t.clone(), int(inst.exit[1]), {"max_states": cap, "goal_ids": t.goal_ids, "admissible": true, "prefer_plain": true, "max_ms": max_ms})
	if res.status != "solved":
		return {"ok": false, "why": "sin solución" if res.status == "unsolvable" else "no se llegó a resolver (más de %d estados)" % cap, "states": int(res.states)}
	var out := measure(inst, res.path)
	out.ok = true
	out.why = ""
	out.moves = int(res.moves)
	out["diff"] = float(out.grabs) / maxf(float(res.moves), 1.0)
	out["tech"] = int(out.grabs) + int(out.hangs) + int(out.slides) + int(out.launches)   # acciones de técnica: empujar, tirar, colgarse, patinar, saltar con catapulta
	out["diff_tec"] = float(out.tech) / maxf(float(res.moves), 1.0)
	out.states = int(res.states)
	out.path = res.path
	out.needed = {}
	if check_needed:
		for kd in out.present_kinds:
			if kd == K.NORMAL or kd == K.HEAVY:
				continue
			var plain := copy_step(inst)
			var nb: Array = []
			for b in plain.blocks:
				var c: Array = b.duplicate()
				if int(c[3]) == kd:
					c[3] = K.NORMAL
				nb.append(c)
			plain.blocks = nb
			var t2 = build_state(plain)
			var r2: Dictionary = Solver.solve(t2.clone(), int(plain.exit[1]), {"max_states": cap, "goal_ids": t2.goal_ids, "admissible": true, "prefer_plain": true, "max_ms": max_ms})
			var same: bool = r2.status == "solved" and int(r2.moves) == int(res.moves) and int(measure(plain, r2.path).grabs) == int(out.grabs)
			out.needed[kd] = not same
	return out


## Lo que hace un camino sobre el paso: empujes y tirones, bloques distintos movidos, veces que se cuelga, patinazos, saltos de catapulta y tipos de bloque que pisa o mueve.
static func measure(inst: Dictionary, path: Array) -> Dictionary:
	var t = build_state(inst)
	var grabs := 0
	var hangs := 0
	var slides := 0
	var launches := 0
	var moved := {}
	var kinds := {}
	for a in path:
		var before: Vector3i = t.player
		var below: int = t.kind_at(before + Vector3i(0, -1, 0))
		var pos_before: Dictionary = t.positions.duplicate() if a.mode == TowerLogic.Mode.GRAB else {}
		if below > 0:
			kinds[below] = true
		t.try_action(a.dir, a.mode)
		if a.mode == TowerLogic.Mode.GRAB:
			grabs += 1
			for id in t.positions:
				if pos_before.get(id, t.positions[id]) != t.positions[id]:
					moved[id] = true
					kinds[int(t.kind_of.get(id, 0))] = true
		if a.mode == TowerLogic.Mode.HANG or (t.hang_dir != Vector3i.ZERO and before != t.player):
			hangs += 1
		if a.mode == TowerLogic.Mode.MOVE and t.hang_dir == Vector3i.ZERO and absi(t.player.x - before.x) + absi(t.player.z - before.z) >= 2 and t.player.y == before.y:
			slides += 1
		if t.player.y - before.y >= 3:
			launches += 1
	var present := {}
	for b in inst.blocks:
		present[int(b[3])] = true
	kinds.erase(0)
	return {"grabs": grabs, "moved": moved.size(), "hangs": hangs, "slides": slides, "launches": launches, "kinds": kinds.keys(), "present_kinds": present.keys()}


## Una línea de texto con el resultado de un largo.
static func describe(ev: Dictionary) -> String:
	if not bool(ev.get("ok", false)):
		return "✗ " + str(ev.get("why", ""))
	var parts: Array = ["%d pasos" % int(ev.moves)]
	if int(ev.grabs) > 0:
		parts.append("%d empujes/tirones" % int(ev.grabs))
	if int(ev.hangs) > 0:
		parts.append("%d colgadas" % int(ev.hangs))
	if int(ev.slides) > 0:
		parts.append("%d patinazos" % int(ev.slides))
	if int(ev.launches) > 0:
		parts.append("%d saltos de catapulta" % int(ev.launches))
	var s := "✓ " + ", ".join(parts) + (" · dificultad %d %%" % roundi(100.0 * float(ev.get("diff", 0.0))) if float(ev.get("diff", 0.0)) > 0.0 else "")
	var req: Array = []
	var dec: Array = []
	for kd in ev.get("needed", {}):
		(req if bool(ev.needed[kd]) else dec).append(str(KIND_NAMES.get(int(kd), "?")))
	if not req.is_empty():
		s += " · necesarios: " + ", ".join(req)
	if not dec.is_empty():
		s += " · de adorno: " + ", ".join(dec)
	return s


# --- hash y archivo ---------------------------------------------------------------------------------------------------------

static func finalize(step: Dictionary) -> void:
	var bs: Array = []
	for b in step.blocks:
		bs.append("%d,%d,%d,%d" % [int(b[0]), int(b[1]), int(b[2]), int(b[3])])
	bs.sort()
	var fs: Array = []
	for f in step.get("fixed", []):
		fs.append("%d,%d,%d" % [int(f[0]), int(f[1]), int(f[2])])
	fs.sort()
	var hs: Array = []
	for ho in step.holes:
		hs.append("%d,%d" % [int(ho[0]), int(ho[1])])
	hs.sort()
	var rep: Dictionary = step.repeat
	var text := "w%d d%d h%d|B%s|F%s|H%s|E%s|X%s|R%s" % [int(step.w), int(step.d), int(step.h), ";".join(bs), ";".join(fs), ";".join(hs), str(step.entry), str(step.exit), ("%s%d-%d:%d-%d" % [rep.axis, int(rep.from), int(rep.to), int(rep.min), int(rep.max)]) if bool(rep.on) else "-"]
	step.id = text.sha256_text().substr(0, 32)
	step.format = FORMAT


static func to_line(step: Dictionary) -> String:
	return JSON.stringify(step)


static func from_dict(d: Dictionary) -> Dictionary:
	var s := make_step(str(d.get("name", "Paso")), int(d.get("w", 6)), int(d.get("d", 3)), int(d.get("h", 5)))
	s.note = str(d.get("note", ""))
	s.stamp = int(d.get("stamp", 0))
	for b in d.get("blocks", []):
		s.blocks.append([int(b[0]), int(b[1]), int(b[2]), int(b[3])])
	for f in d.get("fixed", []):
		s.fixed.append([int(f[0]), int(f[1]), int(f[2])])
	for ho in d.get("holes", []):
		s.holes.append([int(ho[0]), int(ho[1])])
	var e: Array = d.get("entry", s.entry)
	s.entry = [int(e[0]), int(e[1]), int(e[2])]
	var x: Array = d.get("exit", s.exit)
	s.exit = [int(x[0]), int(x[1]), int(x[2])]
	var r: Dictionary = d.get("repeat", {})
	s.repeat = {"on": bool(r.get("on", false)), "axis": str(r.get("axis", "x")), "from": int(r.get("from", 1)), "to": int(r.get("to", 1)), "min": int(r.get("min", 1)), "max": int(r.get("max", 4))}
	var res: Dictionary = d.get("results", {})
	for k in res:
		s.results[str(k)] = res[k]
	finalize(s)
	return s


static func read_file(path: String) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(path):
		return out
	for line in FileAccess.get_file_as_string(path).split("\n"):
		line = line.strip_edges()
		if line == "":
			continue
		var d = JSON.parse_string(line)
		if typeof(d) == TYPE_DICTIONARY and str(d.get("kind", "")) == "paso":
			out.append(from_dict(d))
	return out


static func write_file(path: String, steps: Array) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	for s in steps:
		f.store_line(to_line(s))
	f.close()
	return true
