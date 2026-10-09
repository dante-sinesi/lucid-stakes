extends SceneTree
## Pruebas de la sala del casino: distribución, celdas caminables y modelo de minibloques.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_casino_room.gd

const Room := preload("res://scripts/casino_room.gd")
const VoxelMesh := preload("res://scripts/voxel_mesh.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_layout()
	test_walking()
	test_voxels()
	test_look()
	test_tiers()
	test_mesh()
	print("tests de la sala del casino terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_layout() -> void:
	check(Room.CELLS == Vector2i(11, 9), "la sala mide 11 x 9 celdas")
	var blocked := Room.blocked_cells()
	check(blocked.has(Room.DEALER) and blocked.has(Vector2i(3, 3)) and blocked.has(Vector2i(5, 4)), "la mesa y el crupier ocupan celdas")
	check(not blocked.has(Room.ENTRY) and not blocked.has(Room.EXIT), "la entrada y la salida no estan bloqueadas")
	check(Room.in_room(Room.ENTRY) and Room.in_room(Room.EXIT) and Room.ENTRY != Room.EXIT, "entrada y salida estan dentro de la sala y son distintas")
	var all_inside := true
	for c in blocked:
		all_inside = all_inside and Room.in_room(c)
	check(all_inside, "todo lo bloqueado esta dentro de la sala")
	check(Room.MACHINES.size() == 3, "3 tragamonedas")
	# nada se superpone con otra cosa
	var items := {}
	var overlap := false
	for x in range(Room.TABLE.position.x, Room.TABLE.end.x):
		for z in range(Room.TABLE.position.y, Room.TABLE.end.y):
			items[Vector2i(x, z)] = "mesa"
	for m in Room.MACHINES:
		overlap = overlap or items.has(m)
		items[m] = "maquina"
	for x in range(Room.CARD_TABLE.position.x, Room.CARD_TABLE.end.x):
		for z in range(Room.CARD_TABLE.position.y, Room.CARD_TABLE.end.y):
			overlap = overlap or items.has(Vector2i(x, z))
			items[Vector2i(x, z)] = "cartas"
	overlap = overlap or items.has(Room.DEALER)
	check(not overlap, "la mesa, las maquinas, la mesa de cartas y el crupier no se superponen")


func test_walking() -> void:
	check(Room.walkable(Room.ENTRY) and Room.walkable(Room.EXIT) and not Room.walkable(Vector2i(4, 3)) and not Room.walkable(Vector2i(-1, 0)), "walkable: entrada y salida si; mesa y fuera de la sala no")
	var reach := Room.reachable(Room.ENTRY)
	check(reach.has(Room.EXIT), "desde la entrada se llega a la salida caminando")
	var spots := Room.roulette_spots()
	check(spots.size() >= 4, "hay al menos 4 lugares para jugar a la ruleta (%d)" % spots.size())
	var all_reach := true
	var touching := true
	for s in spots:
		all_reach = all_reach and reach.has(s)
		var near := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			near = near or Room.TABLE.has_point(s + d)
		touching = touching and near and Room.walkable(s)
	check(all_reach, "todos los lugares de la ruleta son alcanzables desde la entrada")
	check(touching, "cada lugar de la ruleta es caminable y toca la mesa")
	check(not spots.has(Room.DEALER), "el crupier no es un lugar de juego")
	# todas las celdas libres son alcanzables: no hay rincones aislados
	var free := 0
	for x in Room.CELLS.x:
		for z in Room.CELLS.y:
			if Room.walkable(Vector2i(x, z)):
				free += 1
	check(reach.size() == free, "todas las celdas caminables estan conectadas (%d de %d)" % [reach.size(), free])


func test_voxels() -> void:
	var v := Room.build_voxels()
	var solid: Dictionary = v.solid
	var glow: Dictionary = v.glow
	check(solid.size() > 5000 and glow.size() > 50, "la sala tiene piso, paredes y cosas que brillan (%d / %d)" % [solid.size(), glow.size()])
	var W := Room.CELLS.x * Room.CELL_VOX
	var D := Room.CELLS.y * Room.CELL_VOX
	var inside := true
	for p in solid:
		inside = inside and p.x >= 0 and p.x < W and p.z >= 0 and p.z < D and p.y >= 0
	for p in glow:
		inside = inside and p.x >= 0 and p.x < W and p.z >= 0 and p.z < D and p.y >= 0
	check(inside, "ningun minibloque sale del rectangulo de la sala")
	var overlap := 0
	for p in glow:
		if solid.has(p):
			overlap += 1
	check(overlap == 0, "lo que brilla y lo solido no ocupan el mismo minibloque (%d)" % overlap)
	var floor_ok := true
	for x in W:
		for z in D:
			floor_ok = floor_ok and solid.has(Vector3i(x, 0, z)) and solid.has(Vector3i(x, 1, z))
	check(floor_ok, "el piso cubre toda la sala")
	# El crupier esta donde dice la distribucion: hay minibloques en su celda a la altura del cuerpo.
	var dx := Room.DEALER.x * Room.CELL_VOX + 2
	var dz := Room.DEALER.y * Room.CELL_VOX + 2
	check(solid.has(Vector3i(dx, 5, dz + 1)) and solid.has(Vector3i(dx, 8, dz + 1)) and solid.has(Vector3i(dx, 11, dz + 1)), "el crupier tiene cuerpo, cabeza y sombrero en su celda")
	# La mesa esta sobre sus celdas.
	var tx := Room.TABLE.position.x * Room.CELL_VOX
	var tz := Room.TABLE.position.y * Room.CELL_VOX
	check(solid.has(Vector3i(tx + 1, 5, tz + 1)) and solid.has(Vector3i(tx + 1, 2, tz)), "la mesa tiene tablero y patas sobre sus celdas")
	# La rueda: 13 sectores de 3 colores; el cero (violeta) esta al norte.
	var north_col: Color = solid.get(Vector3i(tx + 5, 7, tz + 2), Color.BLACK)
	check(north_col.is_equal_approx(Room.VIOLET), "el sector 0 (violeta) de la rueda mira al norte")
	var colors := {}
	for x in range(tx, tx + 11):
		for z in range(tz, tz + 11):
			var c = solid.get(Vector3i(x, 7, z))
			if c != null and Vector2(x + 0.5 - (tx + 5.0), z + 0.5 - (tz + 5.0)).length() < 3.8:
				colors[c] = true
	check(colors.size() == 3, "la rueda usa 3 colores (casa, claros, anaranjados): %d" % colors.size())
	# Las tragamonedas estan tapadas con su cartel "?"
	var signs := 0
	for m in Room.MACHINES:
		if glow.has(Vector3i(m.x * Room.CELL_VOX + 3, 9, m.y * Room.CELL_VOX + 2)):
			signs += 1
	check(signs == 3, "las 3 tragamonedas tienen su lampara")
	# Las dos puertas: portal en espiral dentro de un marco, mas claro a medida que pasan las etapas.
	var ez := Room.ENTRY.y * Room.CELL_VOX
	var sx := Room.EXIT.x * Room.CELL_VOX
	check(glow.has(Vector3i(0, 6, ez + 2)) and not solid.has(Vector3i(0, 6, ez + 2)), "la puerta de llegada (pared oeste) tiene su portal de luz")
	check(glow.has(Vector3i(sx + 2, 6, 0)) and not solid.has(Vector3i(sx + 2, 6, 0)), "la puerta de salida (pared norte) tiene su portal de luz")
	check(solid.has(Vector3i(0, 6, ez - 1)) and solid.has(Vector3i(sx - 1, 6, 0)), "las dos puertas tienen marco")
	var shades := {}
	for u in Room.CELL_VOX:
		for h in 10:
			shades[glow[Vector3i(sx + u, 2 + h, 0)]] = true
	check(shades.size() == 3, "el interior del portal es una espiral de 3 tonos (%d)" % shades.size())
	var lum := func(c: Color) -> float: return c.get_luminance()
	for st in [1, 10, 27]:
		check(lum.call(Room.portal_color(st, true)) > lum.call(Room.portal_color(st, false)), "etapa %d: la puerta de salida es mas clara que la de llegada" % st)
	check(lum.call(Room.portal_color(1, false)) < lum.call(Room.portal_color(14, false)) and lum.call(Room.portal_color(14, false)) < lum.call(Room.portal_color(27, false)), "las puertas se aclaran a medida que avanzan las etapas")
	var later := Room.build_voxels(20)
	check(later.glow[Vector3i(sx + 2, 6, 0)] != v.glow[Vector3i(sx + 2, 6, 0)], "el modelo de la sala usa el color de la etapa")


func test_look() -> void:
	var lum := func(c: Color) -> float: return c.get_luminance()
	var early := Room.look(1)
	var mid := Room.look(14)
	var late := Room.look(27)
	for key in ["floor_a", "floor_b", "wall", "wall_dark", "gold", "wood", "felt", "carpet", "lamp", "pillar"]:
		check(lum.call(early[key]) < lum.call(mid[key]) and lum.call(mid[key]) < lum.call(late[key]), "el casino se aclara con las etapas: %s" % key)
	check(early.corruption > mid.corruption and mid.corruption > late.corruption and late.corruption < 0.01 and early.corruption > 0.1, "el casino se limpia: la corrupcion baja a casi nada")


func test_tiers() -> void:
	# La sala cambia de diseño con la etapa: 4 niveles, cada uno mas grande y con mas cosas que el anterior.
	check(Room.tier_of(1) == 0 and Room.tier_of(6) == 0 and Room.tier_of(7) == 1 and Room.tier_of(13) == 1 and Room.tier_of(14) == 2 and Room.tier_of(20) == 2 and Room.tier_of(21) == 3 and Room.tier_of(27) == 3, "los niveles de la sala: 1-6, 7-13, 14-20, 21-27")
	var areas: Array = []
	var machines: Array = []
	for st in [1, 7, 14, 21]:
		var lay := Room.layout(st)
		areas.append(lay.cells.x * lay.cells.y)
		machines.append(lay.machines.size())
		check(lay.tier == Room.tier_of(st), "el layout de la etapa %d es del nivel %d" % [st, Room.tier_of(st)])
	check(areas[0] < areas[1] and areas[1] < areas[2] and areas[2] < areas[3], "la sala crece: %s celdas" % str(areas))
	check(machines[0] < machines[1] and machines[1] < machines[2], "cada nivel suma tragamonedas: %s" % str(machines))
	check(Room.layout(1).card_tables.is_empty() and Room.layout(21).card_tables.size() == 2 and Room.layout(14).card_tables.size() == 1, "las mesas de cartas aparecen en los ultimos niveles")
	check(Room.layout(21).heights.size() > 10 and Room.layout(1).heights.is_empty(), "el gran casino tiene tarima con escalones; la taberna no")
	var lay3 := Room.layout(25)
	var min_h := 99
	for s in Room.roulette_spots(lay3):
		min_h = mini(min_h, Room.height_of(s, lay3))
	check(min_h >= 2 and Room.height_of(lay3.dealer, lay3) == 4 and Room.height_of(Vector2i(0, 0), lay3) == 0, "en el gran casino la ruleta esta sobre los escalones")
	check(Room.world_of_cell(Vector2i(6, 6), lay3).y > Room.world_of_cell(Vector2i(0, 0), lay3).y, "el personaje sube con los escalones")
	for st in [1, 4, 7, 10, 14, 18, 21, 27]:
		var lay := Room.layout(st)
		var reach := Room.reachable(lay.entry, lay)
		var free := 0
		for x in lay.cells.x:
			for z in lay.cells.y:
				if Room.walkable(Vector2i(x, z), lay):
					free += 1
		check(reach.size() == free and reach.has(lay.exit), "etapa %d: todas las celdas libres son alcanzables y se llega a la salida" % st)
		var spots := Room.roulette_spots(lay)
		var all_reach := spots.size() >= 4
		for sp in spots:
			all_reach = all_reach and reach.has(sp)
		check(all_reach, "etapa %d: hay al menos 4 lugares de ruleta, todos alcanzables" % st)
		check(not Room.blocked_cells(lay).has(lay.entry) and not Room.blocked_cells(lay).has(lay.exit) and lay.entry != lay.exit, "etapa %d: entrada y salida libres" % st)
		var v := Room.build_voxels(st)
		var W: int = lay.cells.x * Room.CELL_VOX
		var D: int = lay.cells.y * Room.CELL_VOX
		var ok := true
		for x in W:
			for z in D:
				ok = ok and v.solid.has(Vector3i(x, 0, z)) and v.solid.has(Vector3i(x, 1, z))
		for p in v.solid:
			ok = ok and p.x >= 0 and p.x < W and p.z >= 0 and p.z < D and p.y >= 0
		for p in v.glow:
			ok = ok and p.x >= 0 and p.x < W and p.z >= 0 and p.z < D and p.y >= 0 and not v.solid.has(p)
		var ez: int = lay.entry.y * Room.CELL_VOX
		var sx: int = lay.exit.x * Room.CELL_VOX
		ok = ok and v.glow.has(Vector3i(sx + 2, 6, 0)) and v.glow.has(Vector3i(0, 6, ez + 2)) and v.solid.has(Vector3i(0, 6, ez - 1)) and v.solid.has(Vector3i(sx - 1, 6, 0))
		check(ok, "etapa %d: el piso esta completo, nada sale de la sala, las puertas estan intactas y nada solido pisa lo que brilla" % st)
	# El modelado se refina: las paredes de la taberna son irregulares, las del salon de piedra tienen ladrillos, las de
	# mas adelante son lisas (menos colores distintos por area de pared) y de marmol (pilastras mas altas).
	var h0 := Room.build_voxels(1)
	var h3 := Room.build_voxels(27)
	var top0 := 0
	var top3 := 0
	for p in h0.north.solid:
		top0 = maxi(top0, p.y)
	for p in h3.north.solid:
		top3 = maxi(top3, p.y)
	check(top0 < top3, "las paredes del gran casino son mas altas que las de la taberna (%d / %d)" % [top0, top3])
	var tall_col := 0
	for p in h3.solid:
		if p.y >= 12 and p.y <= 15 and h3.west.solid.has(p) == false and h3.north.solid.has(p) == false:
			tall_col += 1
	check(tall_col > 20, "en el gran casino hay columnas de marmol libres (%d minibloques altos)" % tall_col)


func test_mesh() -> void:
	var v := Room.build_voxels()
	var mesh := VoxelMesh.build(v.solid, Room.VOXEL)
	check(mesh.get_surface_count() == 1, "la sala se dibuja con una sola malla solida")
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	check(verts.size() > 20000 and verts.size() % 3 == 0, "la malla tiene muchas caras (%d vertices)" % verts.size())
	var outward := true
	var i := 0
	while i + 2 < verts.size():
		outward = outward and (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i]).dot(norms[i]) < 0.0
		i += 3
	check(outward, "todas las caras miran hacia afuera")
	var size := mesh.get_aabb().size
	check(absf(size.x - 11.0) < 0.01 and absf(size.z - 9.0) < 0.01, "la malla mide 11 x 9 unidades (%s)" % str(size))
	# un cubo solo: 6 caras = 36 vertices
	var one := VoxelMesh.build({Vector3i(0, 0, 0): Color.RED}, 1.0)
	check(one.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 36, "un minibloque suelto dibuja sus 6 caras")
	# dos juntos: se oculta la cara compartida
	var two := VoxelMesh.build({Vector3i(0, 0, 0): Color.RED, Vector3i(1, 0, 0): Color.RED}, 1.0)
	check(two.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 60, "dos minibloques pegados ocultan la cara compartida (60 vertices)")
