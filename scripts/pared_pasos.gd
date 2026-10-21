extends RefCounted
## EXPERIMENTO (aislado del juego): convierte una pared colgante (scripts/pared_gen.gd) en un "paso" (scripts/step_lib.gd) y de vuelta, para poder mejorarla con el excavador nativo (scripts/step_excavator.gd:
## el solucionador explora el grafo de estados alrededor del camino y propone las disposiciones de bloques más lejanas de la meta).
## El piso es el anillo (o la franja) de 1 bloque: el resto de la ventana son pozos (`holes`). La salida es la plataforma fija sobre la que hay que quedar parado.

const RoomLib := preload("res://scripts/room_lib.gd")
const StepLib := preload("res://scripts/step_lib.gd")
const Base := preload("res://scripts/pared_gen.gd")


static func to_step(room: Dictionary) -> Dictionary:
	var kind := "pared" if str(room.shape) == "P6" else "cilindro"
	var h: int = room.h
	var depth := 4 if kind == "pared" else 8
	var step := StepLib.make_step("pared", 8, depth, h)
	var floor_set := {}
	for c in room.floor_cells:
		floor_set[c] = true
	var holes: Array = []
	for x in 8:
		for z in depth:
			if not floor_set.has(Vector2i(x, z)):
				holes.append([x, z])
	step.holes = holes
	var blocks: Array = []
	for c in room.cols:
		var text: String = room.cols[c]
		for i in text.length():
			if text[i] != RoomLib.GAP:
				blocks.append([c.x, i + 1, c.y, int(RoomLib.KIND_OF_CHAR.get(text[i], 0))])
	step.blocks = blocks
	var ex: Vector2i = room.exit
	step.exit = [ex.x, h + 1, ex.y]
	# la entrada: la celda de piso pegada a donde llega el jugador
	var en: Vector2i = room.entry
	var ring_entry := Vector2i(clampi(en.x, 0, 7), clampi(en.y, 0, depth - 1))
	step.entry = [ring_entry.x, 1, ring_entry.y]
	return step


## La pared que corresponde a un paso mejorado (mismas salidas, piso y entrada que `template`; los bloques salen del paso).
static func from_step(step: Dictionary, template: Dictionary) -> Dictionary:
	var room := RoomLib.copy_room(template)
	var rows := {}
	for b in step.blocks:
		var c := Vector2i(int(b[0]), int(b[2]))
		if not rows.has(c):
			rows[c] = {}
		rows[c][int(b[1])] = String(RoomLib.CHAR_OF_KIND.get(int(b[3]), "n"))
	var cols := {}
	for c in rows:
		var top := 0
		for y in rows[c]:
			top = maxi(top, int(y))
		var text := ""
		for y in range(1, top + 1):
			text += str(rows[c].get(y, RoomLib.GAP))
		cols[c] = text
	room["cols"] = cols
	return room
