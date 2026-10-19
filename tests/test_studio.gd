extends SceneTree
## Pruebas de la interfaz del Estudio de salas (scripts/studio.gd): se usa como lo haría una persona (filtrar, elegir, editar con las herramientas, deshacer, guardar, variantes, reproducir).
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_studio.gd
const RoomLib := preload("res://scripts/room_lib.gd")
const RoomView := preload("res://scripts/room_view.gd")
const RoomPack := preload("res://scripts/room_pack.gd")
const RoomMiner := preload("res://scripts/room_miner.gd")
const StudioModel := preload("res://scripts/studio_model.gd")

var fails := 0
var dir := "user://test_studio_ui"


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _clean(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)
	var d := DirAccess.open(path)
	for f in d.get_files():
		d.remove(f)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	_clean(dir + "/src")
	var m := RoomMiner.new({"out_dir": dir + "/src", "id": 1, "seed": 91, "shapes": ["3x3", "3x5", "L"], "h_lo": 5, "h_hi": 5, "keep": 5, "verify_p": 0.1})
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 40000 and m.archive_size() < 30:
		m.step()
	var res := RoomPack.pack(dir + "/src", dir + "/lib.jsonl", {"min_moved": 1})
	print("  (biblioteca de prueba: %d salas)" % res.kept)
	check(res.kept >= 15, "hay salas para probar la interfaz")
	await test_ui()
	print("tests de la interfaz del Estudio terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_ui() -> void:
	var studio = load("res://scenes/studio.tscn").instantiate()
	root.add_child(studio)
	await _frames(3)
	check(studio.list != null and studio.info != null and studio.cam != null, "se arma la interfaz")
	check(studio.model.rooms.is_empty() and studio.info.text.find("Elige") != -1, "sin biblioteca invita a elegir una sala")
	var n: int = studio.open_library(dir + "/lib.jsonl")
	await _frames(3)
	check(n >= 15 and studio.list.item_count == n, "la lista muestra todas las salas (%d de %d)" % [studio.list.item_count, n])
	# filtros
	studio.f_shape.select(1)
	studio.refresh_list()
	var only: Array = studio.model.filtered(studio.filters())
	check(studio.list.item_count == only.size() and only.size() < n and only.size() > 0, "el filtro de forma achica la lista (%d)" % only.size())
	for r in only:
		check(r.shape == "3x3", "todas las de la lista son 3x3")
	studio.f_shape.select(0)
	studio.f_grabs.value = 3
	studio.refresh_list()
	check(studio.list.item_count <= n, "el filtro de bloques movidos")
	studio.f_grabs.value = 0
	studio.f_moves.value = 9999
	studio.refresh_list()
	check(studio.list.item_count == 0, "pasos mínimos imposibles dejan la lista vacía")
	studio.f_moves.value = 8
	studio.f_hlo.value = 5
	studio.f_hhi.value = 5
	studio.f_shape.select(1)
	studio.refresh_list()
	var combo: Array = studio.model.filtered(studio.filters())
	check(studio.list.item_count == combo.size() and studio.filters().min_moves == 8, "todos los filtros juntos")
	for r in combo:
		check(r.shape == "3x3" and r.h == 5 and int(r.opt.moves) >= 8, "las de la lista cumplen tipo, altura y pasos")
	studio.clear_filters()
	check(studio.list.item_count == n and studio.f_moves.value == 0 and studio.f_shape.selected == 0 and studio.f_hhi.value == 20, "Limpiar filtros los deja como al abrir")
	check(studio.f_shape.get_item_text(1).find("Chica") != -1 and studio.f_shape.get_item_text(2).find("Mediana") != -1 and studio.f_shape.get_item_text(3).find("Grande") != -1, "los tipos se llaman chica, mediana y grande")
	studio.f_diff.value = 99
	studio.refresh_list()
	check(studio.list.item_count <= n and studio.filters().min_diff > 0.98, "el filtro de dificultad mínima de la lista")
	studio.f_diff.value = 0
	studio.f_text.text = "zzzz"
	studio.refresh_list()
	check(studio.list.item_count == 0 and studio.count_label.text.begins_with("0 de"), "una búsqueda sin resultados")
	studio.f_text.text = ""
	studio.refresh_list()
	check(studio.list.item_count == n, "se restablecen los filtros")
	# elegir una sala
	var rooms: Array = studio.model.filtered({"sort": "moved", "shape": "3x5"})
	check(rooms.size() > 0, "hay salas 3x5")
	var r: Dictionary = rooms[0]
	check(studio.select_room(r.id) and studio.model.current.id == r.id, "elegir una sala")
	await _frames(3)
	check(studio.info.text.find("3x5") != -1 and studio.info.text.find("pasos") != -1, "el panel muestra la sala y su camino")
	check(studio.info.text.find("dificultad") != -1 and studio.info.text.find("empujes o tirones") != -1, "el panel muestra la dificultad")
	check(studio._row_text(r).find("%") != -1, "la fila de la lista muestra la dificultad")
	check(studio.blocks_root.get_child_count() > 10, "la vista dibuja bloques (%d nodos)" % studio.blocks_root.get_child_count())
	check(studio.similar_box.get_child_count() >= 1, "se listan salas parecidas")
	# clic con el mouse: el centro de la pantalla toca algún bloque
	studio.set_tool("select")
	var st = studio.model.view_state()
	var top := Vector3i(-1, -1, -1)
	for c in st.blocks:
		if c.y > top.y:
			top = c
	var screen: Vector2 = studio.cam.unproject_position(Vector3(top.x + 0.5, top.y + 0.5, top.z + 0.5))
	var got: Vector3i = studio.RoomView.pick(studio.cam, screen, st)
	check(got == top, "el rayo de la pantalla toca el bloque más alto %s (tocó %s)" % [str(top), str(got)])
	studio.click_at(screen)
	await _frames(2)
	check(not studio.sel.is_empty() and studio.sel.cell == Vector2i(top.x, top.z) and studio.sel.y == top.y, "un clic con el mouse selecciona ese bloque")
	# un bloque de una columna cualquiera, visto de arriba
	var any := Vector3i(-1, -1, -1)
	for c in st.blocks:
		if c.y >= 1 and not st.fixed.has(c):
			any = c
	var screen2: Vector2 = studio.cam.unproject_position(Vector3(any.x + 0.5, any.y + 1.0, any.z + 0.5))
	var got2: Vector3i = studio.RoomView.pick(studio.cam, screen2, st)
	check(got2.x == any.x and got2.z == any.z or got2.y >= any.y, "el rayo por la cara de arriba de un bloque toca esa columna o algo delante")
	var off := Vector2(-500, -500)
	check(studio.RoomView.pick(studio.cam, off, st).x == -1000, "un clic afuera de la sala no toca nada")
	# agregar un bloque
	var cell := Vector2i(-9, -9)
	for c in RoomLib.free_cells(r.shape):
		if studio.model.can_add(c) == "":
			cell = c
			break
	var b0: int = studio.model.block_count()
	studio.set_tool("add")
	studio.set_kind_pick("n")
	studio.click_cell(Vector3i(cell.x, 0, cell.y))
	await _frames(2)
	check(studio.model.block_count() == b0 + 1 and studio.model.dirty, "la herramienta Agregar suma un bloque")
	check(not studio.model.verified and studio.status.text.find("sin verificar") != -1, "editar NO verifica solo: avisa que falta verificar (%s)" % studio.status.text)
	studio.do_verify()
	check(studio.model.verified or studio.status.text.begins_with("Sin solución"), "Verificar resuelve la sala")
	var ks_before: String = studio.model.column(cell)
	# tipo
	studio.set_kind_pick("i")
	studio.set_tool("type")
	studio.click_cell(Vector3i(cell.x, ks_before.length(), cell.y))
	await _frames(2)
	check(String(studio.model.column(cell))[ks_before.length() - 1] == "i", "la herramienta Tipo cambia el bloque a hielo")
	# mover
	var dst := Vector2i(-9, -9)
	for c in RoomLib.free_cells(r.shape):
		if c != cell and studio.model.can_add(c) == "":
			dst = c
			break
	var count_move: int = studio.model.block_count()
	studio.set_tool("move")
	studio.click_cell(Vector3i(cell.x, String(studio.model.column(cell)).length(), cell.y))
	check(not studio.move_src.is_empty(), "el primer clic de Mover elige el bloque")
	studio.click_cell(Vector3i(dst.x, 0, dst.y))
	await _frames(2)
	check(studio.move_src.is_empty() and studio.model.block_count() == count_move, "el segundo clic lo mueve (misma cantidad de bloques)")
	# borrar
	studio.set_tool("delete")
	studio.click_cell(Vector3i(dst.x, String(studio.model.column(dst)).length(), dst.y))
	await _frames(2)
	check(studio.model.block_count() == count_move - 1, "la herramienta Borrar saca un bloque")
	# deshacer y rehacer con los botones y las teclas
	var steps := 0
	while studio.model.undo_stack.size() > 0 and steps < 20:
		studio.do_undo()
		steps += 1
	check(studio.model.current.id == r.id, "deshacer todo vuelve a la sala original (%d pasos)" % steps)
	studio.do_redo()
	check(studio.model.block_count() == b0 + 1, "rehacer vuelve a aplicar")
	var ev := InputEventKey.new()
	ev.keycode = KEY_Z
	ev.ctrl_pressed = true
	ev.pressed = true
	studio._unhandled_key_input(ev)
	check(studio.model.block_count() == b0, "Ctrl+Z deshace")
	ev.keycode = KEY_Y
	studio._unhandled_key_input(ev)
	check(studio.model.block_count() == b0 + 1, "Ctrl+Y rehace")
	# con cambios sin guardar no se abre otra sala
	var other: Dictionary = studio.model.rooms[0] if studio.model.rooms[0].id != r.id else studio.model.rooms[1]
	check(not studio.select_room(other.id) and studio.status.text.find("sin guardar") != -1, "con cambios sin guardar no se abre otra sala")
	# guardar
	var total: int = studio.model.rooms.size()
	studio.do_verify()
	var saved: bool = studio.model.verified
	studio.do_save()
	await _frames(2)
	if saved:
		check(not studio.model.dirty and studio.model.rooms.size() == total, "guardar deja la sala sin cambios pendientes: %s" % studio.status.text)
		check(RoomPack.load_library(dir + "/lib.jsonl").size() == total, "el archivo quedó con las mismas salas")
		check(studio.select_room(other.id), "ya sin cambios se puede abrir otra sala")
	else:
		print("  (la sala editada no se resolvió: %s)" % studio.status.text)
		studio.do_revert()
		check(not studio.model.dirty, "descartar los cambios")
	# estado y nota
	studio.select_room(other.id)
	studio.status_opt.select(1)
	studio.note_edit.text = "se ve bien"
	studio.do_annotate()
	check(studio.model.index[other.id].status == "buena" and studio.model.index[other.id].note == "se ve bien", "marcar como buena con una nota")
	studio.f_status.select(2)
	studio.refresh_list()
	check(studio.list.item_count >= 1, "se filtra por estado buena")
	studio.f_status.select(0)
	studio.refresh_list()
	# variantes
	studio.set_tool("select")
	var vcell := Vector2i(-9, -9)
	for c in studio.model.current.cols:
		if RoomLib.block_char(studio.model.current, c, 1) != "":   # (con un bloque sobre el piso: las salas pueden tener huecos)
			vcell = c
	studio.click_cell(Vector3i(vcell.x, 1, vcell.y))
	await _frames(2)
	check(studio.sel.cell == vcell and studio.sel.y == 1, "seleccionar un bloque")
	var cur_kind := String(studio.model.current.cols[vcell])[0]
	var want := "c" if cur_kind != "c" else "i"
	studio.variant_checks[want].button_pressed = true
	await _frames(2)
	check(studio.model.slot_of(vcell, 1).find(want) != -1, "marcar una variante la guarda en la sala")
	studio.do_check_variants()
	check(studio.model.current.variants.size() == 1, "se prueba la variante marcada")
	studio.do_save()   # (guarda las marcas)
	var rooms_before: int = studio.model.rooms.size()
	studio.do_create_variants()
	check(studio.model.rooms.size() >= rooms_before, "crear variantes no pierde salas")
	# poner un bloque con un clic en la cara de otro, como en Minecraft (también al costado, en el aire)
	studio.select_room(studio.model.rooms[0].id)
	studio.set_tool("add")
	studio.set_kind_pick("n")
	await _frames(3)
	var st0 = studio.model.view_state()
	var target := Vector3i(-1, -1, -1)
	for c in st0.blocks:   # un bloque suelto con la cara de arriba a la vista (no tapada por otro) y lugar encima
		if c.y < 1 or st0.fixed.has(c) or st0.blocks.has(c + Vector3i(0, 1, 0)) or c.y + 1 > int(studio.model.current.h) - 1:
			continue
		var f = RoomView.pick_face(studio.cam, studio.cam.unproject_position(Vector3(c.x + 0.5, c.y + 0.98, c.z + 0.5)), st0)
		if f.hit == c and f.prev == c + Vector3i(0, 1, 0):
			target = c
			break
	if target.x != -1:
		var n0: int = studio.model.block_count()
		studio.click_at(studio.cam.unproject_position(Vector3(target.x + 0.5, target.y + 0.98, target.z + 0.5)))
		await _frames(2)
		check(studio.model.block_count() == n0 + 1 and RoomLib.block_char(studio.model.current, Vector2i(target.x, target.z), target.y + 1) == "n", "un clic en la cara de arriba de un bloque pone otro encima")
		studio.do_undo()
	else:
		print("  (no hubo un bloque con la cara de arriba a la vista para probar el clic)")
	# filtro por tipo de bloque
	studio.f_kind.select(1 + studio.KIND_FILTERS.find("b"))
	studio.refresh_list()
	check(studio.filters().get("kind", "") == "b", "el filtro de bloque llega a los filtros")
	studio.clear_filters()
	check(studio.f_kind.selected == 0 and not studio.filters().has("kind"), "limpiar filtros saca el de bloque")
	# ver solo la sala y desde atrás del personaje
	studio.set_view_only(true)
	check(not studio.left_panel.visible and not studio.right_panel.visible and studio.show_panels_btn.visible, "ver solo la sala oculta los paneles")
	studio.view_from_behind()
	var rr: Dictionary = studio.model.current
	check(absf(studio.yaw - rad_to_deg(atan2(-float(rr.exit.x - rr.entry.x), -float(rr.exit.y - rr.entry.y)))) < 0.01, "la cámara queda detrás de la llegada")
	studio.set_view_only(false)
	check(studio.left_panel.visible and studio.right_panel.visible and not studio.show_panels_btn.visible, "se vuelven a mostrar los paneles")
	# podar el relleno y mejorar el camino con los botones
	studio.model.revert()
	studio.select_room(studio.model.rooms[0].id)
	var empty_cell := Vector2i(-9, -9)
	for c in RoomLib.free_cells(studio.model.current.shape):
		if studio.model.column(c) == "" and studio.model.can_add(c) == "":
			empty_cell = c
			break
	studio.set_tool("add")
	studio.click_cell(Vector3i(empty_cell.x, 0, empty_cell.y))
	await _frames(2)
	if studio.model.verified:
		var before_prune: int = studio.model.block_count()
		studio.do_prune()
		# (el bloque agregado puede servir para un camino más corto: entonces no hay relleno, y el botón lo dice)
		check((studio.status.text.find("Se sacaron") != -1 and studio.model.block_count() < before_prune) or studio.status.text.find("no hay nada que sacar") != -1, "el botón Podar relleno saca bloques o avisa que no hay: %s" % studio.status.text)
	studio.do_optimize()
	check(studio.status.text.find("Camino") != -1, "el botón Mejorar camino responde: %s" % studio.status.text)
	check(studio.info.text.find("camino") != -1, "el panel muestra el camino")
	studio.do_revert()
	# reproducción
	var back: Dictionary = studio.model.filtered({"sort": "moves"})[0]
	var okb: bool = studio.select_room(back.id)
	print("  (reproducción: abrió=%s dirty=%s estado=%s actual=%s)" % [str(okb), str(studio.model.dirty), studio.status.text, str(studio.model.current.id).substr(0, 6)])
	var np: int = studio.model.current.path.size()
	studio.play_goto(np / 2)
	check(studio.model.play_index == np / 2, "ir a la mitad del camino")
	studio.play_goto(0)
	check(studio.model.play_index == 0, "volver al principio")
	studio.play_timer.wait_time = 0.02
	studio.toggle_play()
	check(studio.playing, "empieza la reproducción")
	var waited := 0.0
	while studio.playing and waited < 30.0:
		await create_timer(0.1).timeout
		waited += 0.1
	print("  (tras reproducir: índice %d de %d, reproduciendo=%s, esperó %.1f s)" % [studio.model.play_index, np, str(studio.playing), waited])
	check(studio.model.play_index == np and RoomLib.at_goal(studio.model.play_state, studio.model.current.h), "la reproducción llega a la salida (%d pasos)" % np)
	check(studio.play_btn.text.find("Reproducir") != -1, "el botón vuelve a decir Reproducir")
	# una sala nueva
	studio.new_shape.select(0)
	studio.new_h.value = 5
	studio.do_new()
	check(studio.model.current.shape == "3x3" and studio.model.dirty and studio.tool == "add", "se crea una sala nueva y queda la herramienta Agregar")
	studio.click_cell(Vector3i(1, 0, 1))
	studio.click_cell(Vector3i(1, 1, 1))
	await _frames(2)
	check(studio.model.block_count() == 2, "se agregan bloques a la sala nueva")
	check(not studio.model.save().ok, "la sala nueva sin solución no se guarda")
	studio.do_new()
	check(studio.status.text.find("sin guardar") != -1, "con cambios sin guardar no se crea otra sala")
	studio.do_revert()
	# eliminar
	var victim: Dictionary = studio.model.filtered({"sort": "moved"})[0]
	studio.select_room(victim.id)
	var before_del: int = studio.model.rooms.size()
	studio.do_delete()
	check(studio.model.rooms.size() == before_del - 1 and not studio.model.index.has(victim.id), "eliminar una sala")
	check(studio.list.item_count == before_del - 1, "la lista se actualiza")
	# cámara
	var d0: float = studio.dist
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	studio._on_view_input(wheel)
	check(studio.dist < d0 and studio._user_cam, "la rueda acerca la cámara")
	var yaw0: float = studio.yaw
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	studio._on_view_input(press)
	var mv := InputEventMouseMotion.new()
	mv.relative = Vector2(30, 10)
	studio._on_view_input(mv)
	check(studio.yaw != yaw0, "arrastrar con el botón derecho gira la cámara")
	press.pressed = false
	studio._on_view_input(press)
	studio.queue_free()
	await _frames(2)
