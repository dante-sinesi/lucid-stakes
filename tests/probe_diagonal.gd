extends SceneTree
## ¿Una diagonal de bloques (uno más alto por celda) se sostiene? Desde el bloque fijo de arriba, o apoyada en el borde del piso.
const RoomLib := preload("res://scripts/room_lib.gd")
const Base := preload("res://scripts/pared_gen.gd")


func _sala(h: int, salida: Vector2i, bloques: Array) -> Dictionary:
	var room := Base.make(RandomNumberGenerator.new(), "cilindro", h, 0, 1)
	room.exit = salida
	room["exits_extra"] = []
	room.entry = Base.entry_for(salida)
	var set := {}
	for b in bloques:
		set[b] = true
	room["cols"] = Base.cols_from_set(set)
	return room


func _init() -> void:
	# diagonal que sube hacia +x por la cara z=1: (1,1)n1 (2,1)n2 ... (6,1)n6, salida arriba del último
	var d: Array = []
	for i in 6:
		d.append(Vector3i(1 + i, i + 1, 1))
	var a := _sala(7, Vector2i(6, 1), d)
	print("A) cuelga de la salida (el bajo toca el borde del piso en x=0): caen ", RoomLib.unsupported_cells(a).size(), " de ", d.size())
	# lo mismo pero la salida está lejos: sólo el borde del piso puede sostener
	var b := _sala(7, Vector2i(3, 6), d)
	print("B) sin salida cerca, solo apoyada en el piso: caen ", RoomLib.unsupported_cells(b).size(), " de ", d.size())
	# diagonal que baja desde la salida hacia -x lejos del piso: sale de (6,1)n6 hacia (2..5): sin el tramo bajo
	var c: Array = [Vector3i(3, 3, 1), Vector3i(4, 4, 1), Vector3i(5, 5, 1), Vector3i(6, 6, 1)]
	var cc := _sala(7, Vector2i(6, 1), c)
	print("C) cuelga solo de la salida, diagonal hacia abajo sin tocar el piso: caen ", RoomLib.unsupported_cells(cc).size(), " de ", c.size())
	quit(0)
