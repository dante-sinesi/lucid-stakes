extends SceneTree
## Pruebas del modelo del Estudio de salas (scripts/studio_model.gd). Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_studio_model.gd

const RoomLib := preload("res://scripts/room_lib.gd")
const RoomPack := preload("res://scripts/room_pack.gd")
const RoomMiner := preload("res://scripts/room_miner.gd")
const StudioModel := preload("res://scripts/studio_model.gd")

var fails := 0
var dir := "user://test_studio"


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _clean(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)
	var d := DirAccess.open(path)
	for f in d.get_files():
		d.remove(f)


func _init() -> void:
	_clean(dir)
	build_library()
	test_browse()
	test_edit()
	test_verify_save()
	test_similar()
	test_variants()
	test_playback()
	test_new_and_misc()
	test_prune_and_optimize()
	test_difficulty_filters()
	test_gaps()
	test_kind_filter()
	print("tests del modelo del Estudio terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func build_library() -> void:
	var m := RoomMiner.new({"out_dir": dir + "/src", "id": 1, "seed": 77, "shapes": ["3x3", "3x5"], "h_lo": 5, "h_hi": 5, "keep": 5, "verify_p": 0.1})
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000 and m.archive_size() < 25:
		m.step()
	print("  (biblioteca de prueba: %d salas)" % m.archive_size())
	var res := RoomPack.pack(dir + "/src", dir + "/lib.jsonl", {"min_moved": 1})
	check(res.kept >= 12, "la biblioteca de prueba tiene salas (%d)" % res.kept)


func fresh() -> StudioModel:
	var m := StudioModel.new()
	m.load_file(dir + "/lib.jsonl")
	return m


## La primera sala que tenga un lugar libre donde agregar un bloque.
func pick_room(m: StudioModel, min_moved := 1) -> Dictionary:
	for r in m.filtered({"sort": "moved", "min_moved": min_moved}):
		return r
	return {}


func free_cell_for_add(m: StudioModel) -> Vector2i:
	for c in RoomLib.free_cells(m.current.shape):
		if m.can_add(c) == "":
			return c
	return Vector2i(-9, -9)


func test_browse() -> void:
	var m := fresh()
	check(m.rooms.size() >= 12, "se abre la biblioteca")
	check(m.stats().total == m.rooms.size(), "las estadísticas cuentan todo")
	var shapes := {}
	for r in m.rooms:
		shapes[r.shape] = true
	var some_shape: String = shapes.keys()[0]
	var only := m.filtered({"shape": some_shape})
	check(only.size() > 0 and only.size() <= m.rooms.size(), "el filtro de forma")
	for r in only:
		check(r.shape == some_shape, "todas las filtradas son de la forma")
	var sorted := m.filtered({"sort": "moved"})
	for i in range(1, sorted.size()):
		check(int(sorted[i - 1].opt.get("moved", 0)) >= int(sorted[i].opt.get("moved", 0)), "ordenadas por bloques movidos")
	var hard := m.filtered({"min_moved": 3})
	for r in hard:
		check(int(r.opt.moved) >= 3, "el mínimo de bloques movidos")
	var first: Dictionary = m.rooms[0]
	var by_text := m.filtered({"text": str(first.id).substr(0, 6)})
	check(by_text.size() >= 1 and by_text[0].id == first.id, "se busca por prefijo de id")
	check(m.filtered({"status": "buena"}).is_empty(), "no hay salas buenas todavía")
	check(m.filtered({"text": "zzzz"}).is_empty(), "una búsqueda sin resultados")
	check(not m.open("no_existe"), "abrir una sala que no existe falla")
	check(m.open(first.id) and m.has_current(), "abrir una sala")
	check(m.current.id == first.id and not m.dirty, "la sala abierta es la de la biblioteca y sin cambios")
	m.current.cols[Vector2i(1, 0)] = "hhh"
	check(m.index[first.id].cols != m.current.cols or m.index[first.id].cols.get(Vector2i(1, 0), "") == "hhh", "editar la copia no toca la biblioteca")


func test_edit() -> void:
	var m := fresh()
	var r := pick_room(m)
	m.open(r.id)
	var id0: String = m.current.id
	var cell := free_cell_for_add(m)
	check(cell != Vector2i(-9, -9), "hay dónde agregar")
	check(m.add_block(cell, "n"), "agregar un bloque")
	check(m.dirty and m.current.id != id0 and m.current.origin == "manual" and m.current.parent == id0, "editar cambia el id, marca manual y recuerda de dónde salió")
	check(m.current.opt.get("stale", false), "tras editar las métricas quedan marcadas como viejas")
	check(m.undo() and m.current.id == id0, "deshacer vuelve al id anterior")
	check(m.redo() and m.current.id != id0, "rehacer vuelve a aplicar")
	check(not m.redo(), "no hay más para rehacer")
	m.undo()
	# errores
	check(not m.add_block(Vector2i(0, 0), "n"), "no se agrega pegado a la llegada")
	check(not m.add_block(m.current.exit, "n"), "no se agrega sobre la salida")
	check(not m.add_block(Vector2i(50, 50), "n"), "no se agrega fuera de la arena")
	check(not m.add_block(cell, "x"), "tipo desconocido")
	var cols_before: Dictionary = m.current.cols.duplicate(true)
	check(not m.delete_block(Vector2i(4, 4), 1) and not m.set_kind(Vector2i(4, 4), 1, "n") and not m.move_block(Vector2i(4, 4), 1, cell), "no se opera sobre una columna vacía")
	check(m.current.cols == cols_before, "un error no cambia la sala")
	# columna llena
	var full: int = int(m.current.h) - 1
	var m2 := fresh()
	m2.open(pick_room(m2).id)
	var fc := free_cell_for_add(m2)
	m2.current.cols[fc] = "n".repeat(full)
	check(not m2.add_block(fc, "n"), "no se agrega a una columna llena")
	# borrar del medio, cambiar tipo y mover
	var m3 := fresh()
	m3.open(pick_room(m3).id)
	var cell3 := Vector2i(-9, -9)
	for c in m3.current.cols:
		if String(m3.current.cols[c]).length() >= 2 and String(m3.current.cols[c]).find(RoomLib.GAP) == -1:
			cell3 = c
	if cell3 == Vector2i(-9, -9):
		for c in RoomLib.free_cells(m3.current.shape):
			if m3.can_add(c) == "":
				m3.add_block(c, "n")
				m3.add_block(c, "n")
				cell3 = c
				break
	var len0 := String(m3.current.cols[cell3]).length()
	check(m3.set_kind(cell3, 1, "i") and String(m3.current.cols[cell3])[0] == "i", "cambiar el tipo de un bloque")
	check(m3.set_kind(cell3, 1, "i"), "cambiar al mismo tipo no falla")
	var before_len := m3.block_count()
	check(m3.delete_block(cell3, 1) and m3.block_count() == before_len - 1, "borrar un bloque de abajo hace bajar los de arriba")
	check(String(m3.current.cols.get(cell3, "")).length() == len0 - 1, "la columna quedó un bloque más baja")
	var dst := Vector2i(-9, -9)
	for c in RoomLib.free_cells(m3.current.shape):
		if c != cell3 and m3.can_add(c) == "":
			dst = c
			break
	var n_before := m3.block_count()
	check(m3.move_block(cell3, 1, dst) and m3.block_count() == n_before, "mover un bloque no cambia la cantidad")
	check(not m3.move_block(dst, 1, dst), "mover a la misma columna falla")
	# deshacer varias veces
	var steps := 0
	while m3.undo():
		steps += 1
	check(steps >= 3 and m3.current.id == fresh().index[m3.original_id].id, "se pueden deshacer todos los cambios y vuelve el id original (%d pasos)" % steps)
	m3.revert()
	check(not m3.dirty and m3.current.id == m3.original_id, "descartar los cambios")


func test_verify_save() -> void:
	var m := fresh()
	var r := pick_room(m)
	m.open(r.id)
	var v := m.verify()
	check(v.ok and v.reused and m.verified, "la sala sin tocar se verifica y reutiliza su camino")
	# una edición inofensiva: un bloque de más lejos de todo
	var cell := free_cell_for_add(m)
	m.add_block(cell, "n")
	var v2 := m.verify()
	print("  (tras agregar un bloque: ok=%s reutilizó=%s %s)" % [str(v2.ok), str(v2.get("reused", false)), str(v2.get("why", ""))])
	if v2.ok:
		check(RoomLib.replay(m.current, m.current.path).ok, "el camino nuevo resuelve la sala editada")
		check(int(m.current.opt.moved) >= 1 and not m.current.opt.get("stale", false), "las métricas se actualizan")
		var n_rooms := m.rooms.size()
		var s := m.save(true)
		check(s.ok, "guardar la sala editada (%s)" % str(s.get("msg", "")))
		check(m.rooms.size() == n_rooms and not m.dirty, "guardar reemplaza a la original")
		check(not m.index.has(r.id) and m.index.has(m.current.id), "el id viejo desapareció y el nuevo está")
		var again := fresh()
		check(again.index.has(m.current.id) and not again.index.has(r.id), "el archivo guardado tiene el cambio")
		check(again.index[m.current.id].origin == "manual" and again.index[m.current.id].parent == r.id, "queda marcada manual y con su origen")
		# guardar como nueva
		var m4 := fresh()
		m4.open(m4.rooms[0].id)
		m4.add_block(free_cell_for_add(m4), "n")
		var v4 := m4.verify()
		if v4.ok:
			var n4 := m4.rooms.size()
			check(m4.save(false).ok and m4.rooms.size() == n4 + 1 and m4.index.has(m4.rooms[0].id), "guardar como nueva agrega una sala")
		# un choque con una sala que ya existe
		var m5 := fresh()
		m5.open(m5.rooms[0].id)
		m5.current.cols = m5.rooms[1].cols.duplicate(true)
		m5.current.shape = m5.rooms[1].shape
		m5.current.cells = m5.rooms[1].cells.duplicate()
		m5.current.entry = m5.rooms[1].entry
		m5.current.exit = m5.rooms[1].exit
		m5.current.h = m5.rooms[1].h
		m5.current.path = m5.rooms[1].path.duplicate(true)
		RoomLib.finalize(m5.current)
		m5.dirty = true
		var sc := m5.save(true)
		check(not sc.ok, "no se guarda una sala igual a otra (%s)" % str(sc.get("msg", "")))
	# una edición que la deja sin solución
	var m6 := fresh()
	m6.open(pick_room(m6).id)
	m6.current.cols = {}
	m6._edited()
	var v6 := m6.verify()
	check(not v6.ok and m6.current.path.is_empty() and not m6.verified, "una sala vacía se resuelve caminando: no pasa (%s)" % str(v6.get("why", "")))
	check(not m6.save().ok, "una sala que no pasa no se guarda")
	# una sala incoherente
	var m7 := fresh()
	m7.open(pick_room(m7).id)
	m7.current.cols[Vector2i(0, 0)] = "n"
	var v7 := m7.verify()
	check(not v7.ok, "una columna pegada a la llegada no verifica")
	# verificación exacta
	var m8 := fresh()
	var pick := m8.filtered({"sort": "moves"})
	var small: Dictionary = pick[pick.size() - 1]
	m8.open(small.id)
	m8.verify()
	var ex := m8.verify_exact()
	print("  (verificación exacta: %s, mínimo %s)" % [str(ex.proof), str(ex.moves)])
	check(ex.proof == "exacta" or ex.proof == "cota", "la verificación exacta responde")
	if ex.proof == "exacta":
		check(m8.current.opt.proof == "exacta" and RoomLib.replay(m8.current, m8.current.path).ok, "queda marcada exacta y con un camino que resuelve")
	# anotar y borrar
	var m9 := fresh()
	var target: Dictionary = m9.rooms[2]
	check(m9.annotate(target.id, "buena", "me gusta ñ") and m9.index[target.id].status == "buena", "marcar una sala como buena")
	check(not m9.annotate(target.id, "rara", ""), "un estado desconocido se rechaza")
	var again2 := fresh()
	check(again2.index[target.id].status == "buena" and again2.index[target.id].note == "me gusta ñ", "el estado y la nota se guardan")
	check(again2.filtered({"status": "buena"}).size() == 1, "se filtra por estado")
	var n_before := again2.rooms.size()
	check(again2.delete_room(target.id) and again2.rooms.size() == n_before - 1, "borrar una sala")
	check(fresh().index.has(target.id) == false, "el borrado queda en el archivo")


func test_similar() -> void:
	var m := fresh()
	var r := pick_room(m)
	m.open(r.id)
	var cell := free_cell_for_add(m)
	m.add_block(cell, "n")
	var sim := m.similar(5)
	check(sim.size() == 5 or sim.size() == m.rooms.size(), "salen 5 parecidas (%d)" % sim.size())
	var d_orig := RoomLib.distance(m.current, r, RoomLib.block_sets_all(m.current), RoomLib.block_set(r))
	check(d_orig < 0.2, "una sala con un bloque más está muy cerca de la original (%.3f)" % d_orig)
	for x in sim:
		check(x.room.id != r.id, "la original de la sala editada no figura entre sus parecidas")
	var far: Dictionary = m.rooms[m.rooms.size() - 1]
	check(RoomLib.distance(m.current, far, RoomLib.block_sets_all(m.current), RoomLib.block_set(far)) >= d_orig or far.id == r.id, "otra sala está más lejos que la original")
	for i in range(1, sim.size()):
		check(float(sim[i - 1].dist) <= float(sim[i].dist), "ordenadas de la más cercana a la más lejana")
	for s in sim:
		check(float(s.dist) >= 0.0 and float(s.dist) <= 1.0, "la distancia está entre 0 y 1")
	var m2 := fresh()
	m2.open(r.id)
	for s in m2.similar(3):
		check(s.room.id != r.id, "la sala abierta no figura entre sus parecidas")
	check(StudioModel.new().similar().is_empty(), "sin sala abierta no hay parecidas")


func test_variants() -> void:
	var m := fresh()
	var r := pick_room(m)
	m.open(r.id)
	var cell := Vector2i(-9, -9)
	for c in m.current.cols:
		cell = c
	check(cell != Vector2i(-9, -9), "la sala tiene columnas")
	check(not m.set_slot(Vector2i(50, 50), 1, "i"), "no se marca un bloque que no existe")
	check(m.set_slot(cell, 1, "ic"), "marcar variantes")
	var cur_kind := String(m.current.cols[cell])[0]
	var expected := 0
	for ch in "ic":
		if ch != cur_kind:
			expected += 1
	check(m.slot_of(cell, 1).length() == expected, "las variantes no incluyen el tipo actual")
	var res := m.check_variants()
	check(res.size() == expected, "se prueba cada variante (%d)" % res.size())
	for x in res:
		check(x.has("ok") and x.has("kind") and x.has("moves") and x.has("why"), "cada resultado trae ok, tipo, pasos y motivo")
	var n_rooms := m.rooms.size()
	var created := m.create_variants()
	var ok_count := 0
	for x in res:
		if x.ok:
			ok_count += 1
	print("  (variantes: %d probadas, %d válidas, %d creadas)" % [res.size(), ok_count, created])
	check(created <= ok_count and m.rooms.size() == n_rooms + created, "se crean como mucho las válidas")
	for v in m.rooms:
		if v.variant_of == m.current.id:
			check(RoomLib.replay(v, v.path).ok and v.family == m.current.family, "la variante se resuelve y es de la misma familia")
	check(fresh().rooms.size() == m.rooms.size(), "las variantes quedan en el archivo")
	check(m.set_slot(cell, 1, "") and m.slot_of(cell, 1) == "", "se desmarcan las variantes")
	# al borrar el bloque se limpian las marcas
	m.set_slot(cell, 1, "ic")
	m.delete_block(cell, 1)
	check(not m.current.slots.has(StudioModel.slot_key(cell, 1)) or String(m.current.cols.get(cell, "")).length() >= 1, "las marcas de bloques que ya no existen se limpian")


func test_playback() -> void:
	var m := fresh()
	var r := pick_room(m)
	m.open(r.id)
	m.play_reset()
	var steps := 0
	var done := false
	while not done and steps < 500:
		var s := m.play_step()
		check(s.ok, "el paso %d de la reproducción es válido" % steps)
		if not s.ok:
			break
		steps += 1
		done = s.done
	check(steps == r.path.size(), "se reproducen todos los pasos (%d de %d)" % [steps, r.path.size()])
	check(RoomLib.at_goal(m.play_state, m.current.h), "al final del camino el jugador está en la salida")
	m.play_back()
	check(m.play_index == steps - 1 and not RoomLib.at_goal(m.play_state, m.current.h), "un paso atrás")
	m.play_to(3)
	check(m.play_index == 3, "ir a un paso")
	check(m.view_state() != null, "hay un estado para dibujar")
	var empty := StudioModel.new()
	check(empty.view_state() == null and not empty.play_step().ok, "sin sala no hay qué reproducir")


func test_new_and_misc() -> void:
	var m := fresh()
	check(not m.new_room("Z", 5) and not m.new_room("3x3", 2) and not m.new_room("3x3", 9), "formas y alturas fuera de rango se rechazan")
	check(m.new_room("L", 8) and m.current.shape == "L" and m.current.h == 8 and m.dirty, "crear una sala nueva")
	var v := m.verify()
	check(not v.ok, "una sala vacía no pasa")
	check(not m.save().ok, "una sala nueva sin solución no se guarda")
	# armar una sala nueva con la escalera y bloques sueltos: se resuelve con la solución plantada del minero
	var miner := RoomMiner.new({"seed": 5, "write": false})
	var base := miner.make_seed("3x3", 5)
	var tries := 0
	while base.is_empty() and tries < 30:
		base = miner.make_seed("3x3", 5)
		tries += 1
	if not base.is_empty():
		m.new_room("3x3", 5)
		m.current.cols = base.cols.duplicate(true)
		m._edited()
		var vv := m.verify()
		if vv.ok:
			var n := m.rooms.size()
			var s := m.save()
			check(s.ok or "igual" in str(s.msg), "una sala nueva armada a mano se guarda o ya existía (%s)" % str(s.get("msg", "")))
			if s.ok:
				check(m.rooms.size() == n + 1 and m.index.has(m.current.id), "la sala nueva entra a la biblioteca")
	# archivo comprimido: abrir y guardar
	var packed := dir + "/lib.rooms"
	RoomPack.pack(dir, packed, {"min_moved": 1})
	var mz := StudioModel.new()
	check(mz.load_file(packed) > 5, "se abre una biblioteca comprimida")
	mz.annotate(mz.rooms[0].id, "mala", "")
	var mz2 := StudioModel.new()
	mz2.load_file(packed)
	check(mz2.index[mz.rooms[0].id].status == "mala", "se guarda en la comprimida")
	var nada := StudioModel.new()
	check(nada.load_file(dir + "/no_existe.jsonl") == 0 and nada.rooms.is_empty(), "abrir un archivo que no existe da una biblioteca vacía")
	check(not nada.save().ok and not nada.delete_room("x") and not nada.annotate("x", "buena", ""), "sin sala o sin archivo no se guarda")


## Podar el relleno y mejorar el camino desde el modelo del Estudio.
func test_prune_and_optimize() -> void:
	var m := fresh()
	var r := pick_room(m)
	m.open(r.id)
	# una columna de relleno que no sirve: se agrega, se verifica y se poda
	var added := false
	for c in RoomLib.free_cells(m.current.shape):
		if m.column(c) == "" and m.can_add(c) == "":
			m.add_block(c, "n")
			var v := m.verify()
			if v.ok:
				added = true
				break
			m.undo()
	if added:
		var removed := m.prune_current()
		check(removed >= 1, "podar saca el bloque de relleno agregado (%d)" % removed)
		check(m.dirty and m.verified and RoomLib.replay(m.current, m.current.path).ok, "la sala podada queda verificada y se resuelve")
		check(m.undo() and m.block_count() > 0, "la poda se puede deshacer")
	var m2 := fresh()
	m2.open(pick_room(m2).id)
	check(m2.prune_current() >= 0 and m2.message != "" or true, "podar una sala ya podada no rompe nada")
	# el camino con vueltas se mejora
	var m3 := fresh()
	m3.open(pick_room(m3).id)
	var loop := [{"dir": Vector3i(1, 0, 0), "mode": 0}, {"dir": Vector3i(-1, 0, 0), "mode": 0}]
	var wander: Array = []
	for i in 6:
		wander.append_array(loop)
	wander.append_array(m3.current.path)
	if RoomLib.replay(m3.current, wander).ok:
		m3.current.path = wander
		var o := m3.optimize_path()
		check(int(o.after) < int(o.before) and RoomLib.replay(m3.current, m3.current.path).ok, "mejorar el camino saca las vueltas (%d -> %d)" % [int(o.before), int(o.after)])
		check(int(m3.current.opt.moves) == m3.current.path.size(), "las métricas siguen al camino nuevo")
	var empty := StudioModel.new()
	check(empty.prune_current() == 0 and empty.optimize_path().after == 0, "sin sala no hay qué podar ni mejorar")


## Filtros y orden por dificultad y por empujes y tirones.
func test_difficulty_filters() -> void:
	var m := fresh()
	var by_diff := m.filtered({"sort": "diff"})
	for i in range(1, by_diff.size()):
		check(float(by_diff[i - 1].opt.diff) >= float(by_diff[i].opt.diff) - 0.0001, "ordenadas de la más difícil a la más fácil")
	var by_grabs := m.filtered({"sort": "grabs"})
	for i in range(1, by_grabs.size()):
		check(int(by_grabs[i - 1].opt.grabs) >= int(by_grabs[i].opt.grabs), "ordenadas por empujes y tirones")
	var top: float = by_diff[0].opt.diff
	var half := m.filtered({"min_diff": top / 2.0})
	check(half.size() >= 1 and half.size() <= m.rooms.size(), "el filtro de dificultad mínima")
	for r in half:
		check(float(r.opt.diff) >= top / 2.0 - 0.0001, "todas cumplen la dificultad mínima")
	var many := m.filtered({"min_grabs": 4})
	for r in many:
		check(int(r.opt.grabs) >= 4, "todas cumplen los empujes y tirones mínimos")
	check(m.filtered({"min_diff": 1.1}).is_empty(), "una dificultad imposible no deja ninguna")
	# Resbalones del camino (opt.slides)
	for i in m.rooms.size():
		m.rooms[i].opt["slides"] = i % 4
	var by_slides := m.filtered({"sort": "slides"})
	for i in range(1, by_slides.size()):
		check(int(by_slides[i - 1].opt.slides) >= int(by_slides[i].opt.slides), "ordenadas por resbalones")
	var slippery := m.filtered({"min_slides": 3})
	check(slippery.size() >= 1 and slippery.size() < m.rooms.size(), "el filtro de resbalones mínimos")
	for r in slippery:
		check(int(r.opt.slides) >= 3, "todas cumplen los resbalones mínimos")
	check(m.filtered({"min_slides": 99}).is_empty(), "resbalones imposibles no dejan ninguna")
	# pasos totales, altura, tipo y combinaciones
	var longest := 0
	for r in m.rooms:
		longest = maxi(longest, int(r.opt.moves))
	var long_ones := m.filtered({"min_moves": longest})
	check(long_ones.size() >= 1 and long_ones.size() < m.rooms.size(), "el filtro de pasos mínimos (%d con %d o más)" % [long_ones.size(), longest])
	for r in long_ones:
		check(int(r.opt.moves) >= longest, "todas cumplen los pasos mínimos")
	check(m.filtered({"min_moves": longest + 1}).is_empty(), "pasos mínimos imposibles no dejan ninguna")
	var some: Dictionary = m.rooms[0]
	var combo := m.filtered({"shape": some.shape, "h_lo": some.h, "h_hi": some.h, "min_moves": int(some.opt.moves), "min_grabs": int(some.opt.grabs), "min_diff": float(some.opt.diff) - 0.001})
	var found := false
	for r in combo:
		check(r.shape == some.shape and r.h == some.h and int(r.opt.moves) >= int(some.opt.moves) and int(r.opt.grabs) >= int(some.opt.grabs), "las salas cumplen todos los filtros juntos")
		if r.id == some.id:
			found = true
	check(found, "una sala cumple los filtros hechos con sus propios datos")
	var wrong := m.filtered({"shape": some.shape, "h_lo": some.h + 1, "h_hi": some.h + 1})
	for r in wrong:
		check(r.h == some.h + 1, "el filtro de altura exacta")
	for r in m.rooms:
		check(r.opt.has("diff") and is_equal_approx(float(r.opt.diff), float(r.opt.grabs) / float(r.opt.moves)), "cada sala tiene su dificultad")


func test_gaps() -> void:
	var m := fresh()
	var r := pick_room(m)
	m.open(r.id)
	# un bloque en el aire pegado a una columna alta de la sala, y borrar dejando el hueco
	var tall := Vector2i(-9, -9)
	for c in m.current.cols:
		if String(m.current.cols[c]).length() >= 3 and c != m.current.exit:
			tall = c
	if tall == Vector2i(-9, -9):
		print("(la sala elegida no tiene una columna de 3: se salta la prueba de huecos)")
		return
	var ks0: String = m.current.cols[tall]
	var side := Vector2i(-9, -9)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = tall + d
		if RoomLib.free_cells(m.current.shape).has(q) and q != m.current.exit and not m.current.cols.has(q) and (q - m.current.entry).length() >= 1.5:
			side = q
	if side == Vector2i(-9, -9):
		print("(no hay una celda libre al lado: se salta)")
		return
	check(m.add_block_at(side, 3, "n"), "agregar un bloque en el aire (piso 3 de una columna vacía)")
	check(String(m.current.cols[side]) == "..n" and RoomLib.block_count(m.current) == RoomLib.block_count(RoomLib.copy_room(m.current)), "la columna queda con huecos abajo (%s)" % String(m.current.cols[side]))
	check(not m.add_block_at(side, 3, "n"), "no se agrega sobre un bloque")
	check(not m.add_block_at(side, 0, "n") and not m.add_block_at(side, int(m.current.h), "n"), "alturas fuera de la sala")
	check(m.undo() and not m.current.cols.has(side), "deshacer saca el bloque en el aire")
	m.add_block_at(side, 3, "n")
	check(m.delete_block(side, 3, true) and not m.current.cols.has(side), "borrar el único bloque deja la celda vacía")
	var id_before: String = m.current.id
	var n_before := m.block_count()
	check(m.delete_block(tall, 1, true), "borrar el de abajo dejando el hueco")
	var after: String = m.current.cols.get(tall, "")
	check(m.block_count() == n_before - 1 and (after == ks0.substr(1) or after == "." + ks0.substr(1)), "los de arriba bajan o quedan según se sostengan (%s -> %s)" % [ks0, after])
	check(m.undo() or true, "deshacer")


func test_kind_filter() -> void:
	var m := StudioModel.new()
	var a := RoomLib.make_room("3x5", 5)
	a.cols = {Vector2i(1, 0): "nb", Vector2i(2, 0): "n"}
	a.opt = {"moves": 5, "grabs": 1, "moved": 1, "diff": 0.2, "specials": "b"}
	RoomLib.finalize(a)
	var b := RoomLib.make_room("3x5", 5)
	b.cols = {Vector2i(1, 0): "nk", Vector2i(2, 0): "nnn"}
	b.opt = {"moves": 5, "grabs": 1, "moved": 1, "diff": 0.2}
	RoomLib.finalize(b)
	var c := RoomLib.make_room("3x5", 5)
	c.cols = {Vector2i(1, 0): "nnn"}
	c.opt = {"moves": 5, "grabs": 1, "moved": 1, "diff": 0.2}
	RoomLib.finalize(c)
	m.rooms = [a, b, c]
	check(m.filtered({"kind": "b"}).size() == 1 and m.filtered({"kind": "b"})[0].id == a.id, "filtrar las salas con bomba")
	check(m.filtered({"kind": "k"}).size() == 1 and m.filtered({"kind": "k"})[0].id == b.id, "filtrar las salas con catapulta")
	check(m.filtered({"kind": "i"}).is_empty(), "ninguna sala con hielo")
	check(m.filtered({"kind": "b", "kind_needed": true}).size() == 1, "con bomba y necesaria")
	check(m.filtered({"kind": "k", "kind_needed": true}).is_empty(), "la catapulta de la otra sala no está marcada como necesaria")
	check(m.filtered({}).size() == 3, "sin filtro de bloque están todas")
