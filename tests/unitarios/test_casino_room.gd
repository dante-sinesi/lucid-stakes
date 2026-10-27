extends SceneTree
## Pruebas de la sala del casino: distribución, celdas caminables y modelo de minibloques.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_casino_room.gd

const Room := preload("res://scripts/casino/casino_room.gd")
const VoxelMesh := preload("res://scripts/ui/voxel_mesh.gd")

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
	test_rediseno()
	test_paredes()
	test_detalle()
	print("tests de la sala del casino terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_layout() -> void:
	check(Room.CELLS == Vector2i(11, 9), "la sala mide 11 x 9 celdas")
	var blocked := Room.blocked_cells()
	check(blocked.has(Room.DEALER) and blocked.has(Vector2i(4, 3)) and blocked.has(Vector2i(6, 4)) and blocked.has(Room.TABLON), "la mesa, el crupier y el tablón ocupan celdas")
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
		var lampara := Vector3i(m.x * Room.CELL_VOX + 3, 9, m.y * Room.CELL_VOX + 2) if m.x == 0 else Vector3i(m.x * Room.CELL_VOX + 2, 9, m.y * Room.CELL_VOX + 3)   # (las de la pared norte están giradas)
		if glow.has(lampara):
			signs += 1
	check(signs == 3, "las 3 tragamonedas tienen su lampara")
	# Las dos puertas: portal en espiral dentro de un marco, mas claro a medida que pasan las etapas.
	var ez := Room.ENTRY.y * Room.CELL_VOX
	var sx := Room.EXIT.x * Room.CELL_VOX
	check(not solid.has(Vector3i(0, 6, ez + 2)), "la puerta de llegada (pared oeste) tiene el vano libre (el portal de ondas es un shader)")
	check(not solid.has(Vector3i(sx + 2, 6, 0)), "la puerta de salida (pared norte) tiene el vano libre (el portal de ondas es un shader)")
	check(solid.has(Vector3i(0, 6, ez - 1)) and solid.has(Vector3i(sx - 1, 6, 0)), "las dos puertas tienen marco")
	var lum := func(c: Color) -> float: return c.get_luminance()
	for st in [1, 8, 15]:
		check(lum.call(Room.portal_color(st, true)) > lum.call(Room.portal_color(st, false)), "etapa %d: la puerta de salida es mas clara que la de llegada" % st)
	check(lum.call(Room.portal_color(1, false)) < lum.call(Room.portal_color(8, false)) and lum.call(Room.portal_color(8, false)) < lum.call(Room.portal_color(15, false)), "las puertas se aclaran a medida que avanzan las etapas")


func test_look() -> void:
	var lum := func(c: Color) -> float: return c.get_luminance()
	var early := Room.look(1)
	var salon := Room.look(7)
	var casino := Room.look(8)
	var gran := Room.look(15)
	for key in ["floor_a", "floor_b", "wall", "wall_dark", "gold", "wood", "felt", "carpet", "lamp", "pillar"]:
		check(lum.call(early[key]) < lum.call(salon[key]), "la taberna se aclara hasta el salón: %s" % key)
	check(early.corruption > salon.corruption and salon.corruption > 0.0 and casino.corruption == 0.0 and gran.corruption == 0.0, "la suciedad baja con los niveles y el casino y el gran casino no tienen")
	# el casino y el gran casino: mármol cálido con valores medios y buen contraste (nada se quema hasta el blanco)
	for lk in [casino, gran, Room.look(11), Room.look(12)]:
		for key in ["floor_a", "wall", "pillar", "stone"]:
			check(lum.call(lk[key]) < 0.93, "el casino de nivel alto no se quema: %s (%.2f)" % [key, lum.call(lk[key])])
		check(lum.call(lk.floor_a) - lum.call(lk.floor_b) > 0.25, "el damero del piso tiene contraste (%.2f)" % (lum.call(lk.floor_a) - lum.call(lk.floor_b)))
		check(lum.call(lk.wall) > lum.call(lk.wall_dark) and lum.call(lk.pillar) > lum.call(lk.wall), "las columnas se distinguen de la pared")
	check(Room.look(1, 3).floor_a == Room.look(15, 3).floor_a or absf(lum.call(Room.look(1, 3).floor_a) - lum.call(Room.look(15, 3).floor_a)) < 0.12, "con el escenario Gran Casino la paleta es la del gran casino aunque la etapa sea baja")
	check(Room.look(8, 3).gold != Room.look(8, 2).gold, "el gran casino y el casino tienen paletas propias")


func test_tiers() -> void:
	# La sala cambia de diseño con la etapa: 4 niveles, cada uno mas grande y con mas cosas que el anterior.
	check(Room.tier_of(1) == 0 and Room.tier_of(3) == 0 and Room.tier_of(4) == 1 and Room.tier_of(7) == 1 and Room.tier_of(8) == 2 and Room.tier_of(11) == 2 and Room.tier_of(12) == 3 and Room.tier_of(15) == 3, "los niveles de la sala: 1-3, 4-7, 8-11, 12-15")
	var areas: Array = []
	var machines: Array = []
	for st in [1, 4, 8, 12]:
		var lay := Room.layout(st)
		areas.append(lay.cells.x * lay.cells.y)
		machines.append(lay.machines.size())
		check(lay.tier == Room.tier_of(st), "el layout de la etapa %d es del nivel %d" % [st, Room.tier_of(st)])
	check(areas[0] < areas[1] and areas[1] < areas[2] and areas[2] < areas[3], "la sala crece: %s celdas" % str(areas))
	check(machines == [0, 2, 3, 3], "la taberna no tiene tragamonedas y el salón, el casino y el gran casino tienen 2, 3 y 3: %s" % str(machines))
	check(Room.layout(1).card_tables.is_empty() and Room.layout(1).machines.is_empty() and Room.layout(4).card_tables.size() == 1 and Room.layout(12).card_tables.size() == 2 and Room.layout(8).card_tables.size() == 1, "la taberna sólo tiene la ruleta y el tablón; el salón suma una mesa de cartas y el gran casino tiene dos")
	check(Room.layout(12).heights.size() > 10 and Room.layout(1).heights.is_empty(), "el gran casino tiene tarima con escalones; la taberna no")
	var lay3 := Room.layout(14)
	var min_h := 99
	for s in Room.roulette_spots(lay3):
		min_h = mini(min_h, Room.height_of(s, lay3))
	check(min_h >= 2 and Room.height_of(lay3.dealer, lay3) == 4 and Room.height_of(Vector2i(0, 0), lay3) == 0, "en el gran casino la ruleta esta sobre los escalones")
	check(Room.world_of_cell(Vector2i(6, 6), lay3).y > Room.world_of_cell(Vector2i(0, 0), lay3).y, "el personaje sube con los escalones")
	for st in [1, 2, 4, 6, 8, 10, 12, 15]:
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
		ok = ok and not v.solid.has(Vector3i(sx + 2, 6, 0)) and not v.solid.has(Vector3i(0, 6, ez + 2)) and v.solid.has(Vector3i(0, 6, ez - 1)) and v.solid.has(Vector3i(sx - 1, 6, 0))
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


## Los planos de docs/plan_casinos.md: el tablón siempre en la pared oeste junto a la esquina del norte, las tragamonedas contra las paredes del fondo (oeste o norte), sin Caja
## fuerte, y todo a la vista: se puede llegar caminando a cada mueble.
func test_rediseno() -> void:
	for st in [1, 5, 9, 13]:
		var lay := Room.layout(st)
		check(lay.tablon == Vector2i(0, 1), "etapa %d: el tablón está en la pared oeste, a una celda de la esquina del norte" % st)
		check(not Room.walkable(lay.tablon, lay) and Room.in_room(lay.tablon, lay), "etapa %d: el tablón ocupa su celda" % st)
		check(not lay.has("station") or lay.station.id == "taller", "etapa %d: no queda ninguna Caja fuerte" % st)
		var reach := Room.reachable(lay.entry, lay)
		var muebles: Array = [lay.tablon]
		muebles.append_array(lay.machines)
		if lay.has("station"):
			muebles.append(lay.station.cell)
		for m in muebles:
			var cerca := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				cerca = cerca or reach.has(m + d)
			check(cerca, "etapa %d: se llega caminando hasta el mueble de %s" % [st, str(m)])
		for m in lay.machines:
			check(m.x == 0 or m.y == 0, "etapa %d: la tragamonedas de %s está contra una pared del fondo" % [st, str(m)])
			check(Room._frente_de_maquina(m) == ("este" if m.x == 0 else "sur"), "etapa %d: la tragamonedas de %s mira hacia adentro de la sala" % [st, str(m)])
		check(reach.has(lay.exit) or reach.has(lay.exit + Vector2i(0, 1)), "etapa %d: se llega a la salida" % st)
	check(Room.layout(9).station.get("id", "") == "" if Room.layout(9).has("station") else true, "el casino no tiene estación")


## El modelo con el doble de resolución (`build_detalle`): mismas medidas en el mundo, más minibloques, y el tablón con sus papeles.
func test_detalle() -> void:
	for st in [1, 5, 9, 13]:
		var base := Room.build_voxels(st)
		var d := Room.build_detalle(st)
		check(d.solid.size() > base.solid.size() * 4, "etapa %d: el modelo detallado tiene muchos más minibloques" % st)
		check(d.fino.is_empty(), "etapa %d: el tablón vacío no tiene papeles" % st)
		var con := Room.build_detalle(st, -1, {"papeles": [{"rareza": 0, "objetivo": "racha"}, {"rareza": 3, "objetivo": "bomba"}]})
		check(con.fino.size() > 100, "etapa %d: con contratos cuelgan papeles en detalle" % st)
		var x_max := 0
		for p in d.solid:
			x_max = maxi(x_max, p.x)
		check(x_max < Room.layout(st).cells.x * Room.CELL_FINO + 1, "etapa %d: la sala detallada mide lo mismo" % st)
		var lay_d := Room.layout(st)
		var ex: int = lay_d.exit.x * Room.CELL_FINO + 5
		var ez: int = lay_d.entry.y * Room.CELL_FINO + 5
		check(not d.solid.has(Vector3i(ex, 14, 1)) and not d.west.solid.has(Vector3i(1, 14, ez)) and d.north.solid.has(Vector3i(ex - 8, 14, 1)) and d.west.solid.has(Vector3i(1, 14, ez - 8)), "etapa %d: las paredes finas tienen el vano de las puertas libre y marco al lado" % st)
		check(d.north.solid.size() > 1500 and d.west.solid.size() > 1500 and d.north.glow.size() > 3, "etapa %d: las paredes finas tienen material y luces" % st)
		var west_x := 0
		for p in con.fino:   # (los papeles del tablón están contra la pared oeste)
			west_x = maxi(west_x, p.x)
		check(west_x < 12 * 3, "etapa %d: los papeles están pegados a la pared oeste" % st)


## Las paredes del fondo: ninguna decoración pisa a otra ni a un mueble, una puerta o un farol, y los faroles de pie y las columnas no cierran el paso.
func test_paredes() -> void:
	for st in [1, 5, 9, 13]:
		var lay := Room.layout(st)
		for tardio in [false, true]:
			var deco := Room.paredes(lay, tardio)
			for pared in ["norte", "oeste"]:
				var tramos: Array = []
				for d in deco[pared].decor:
					check(int(d.desde) < int(d.hasta), "etapa %d %s: el tramo de %s tiene sentido" % [st, pared, d.tipo])
					tramos.append([int(d.desde), int(d.hasta), str(d.tipo)])
				for i in tramos.size():
					for j in range(i + 1, tramos.size()):
						check(tramos[i][1] <= tramos[j][0] or tramos[j][1] <= tramos[i][0], "etapa %d %s: %s y %s no se pisan" % [st, pared, tramos[i][2], tramos[j][2]])
					for m in deco[pared].muebles:
						check(tramos[i][1] <= int(m[0]) or int(m[1]) <= tramos[i][0], "etapa %d %s: %s no pisa un mueble ni una puerta (%s)" % [st, pared, tramos[i][2], str(m)])
		var libre := Room.reachable(lay.entry, lay)
		for lamp in lay.get("lamps", []):
			check(Room.in_room(lamp, lay) and not Room.walkable(lamp, lay), "etapa %d: el farol de %s ocupa su celda" % [st, str(lamp)])
			var junto := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				junto = junto or libre.has(lamp + d)
			check(junto, "etapa %d: se llega caminando hasta el farol de %s" % [st, str(lamp)])
		for o in lay.obstacles:
			if st == 13:
				check(o.x != 0 and o.y != 0, "el gran casino no tiene columnas contra las paredes del fondo: %s" % str(o))
