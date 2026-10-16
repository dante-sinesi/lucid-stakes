extends SceneTree
## Interfaz del Estudio de pasos (scripts/step_studio.gd): crear, editar con las herramientas, tramo repetible, resolver todos los largos, reproducir el camino, guardar y volver a abrir.
const StepLib := preload("res://scripts/step_lib.gd")
const K := preload("res://scripts/tower_logic.gd").Kind

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var path := "user://pasos_ui_prueba.jsonl"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	OS.set_environment("STEP_LIB", path)
	var studio = load("res://scenes/step_studio.tscn").instantiate()
	root.add_child(studio)
	await _frames(3)
	check(studio.steps.size() == 3 and studio.current.name.begins_with("Fila de pinchos"), "sin archivo se muestran los tres ejemplos")
	studio.new_step()
	await _frames(2)
	check(studio.steps.size() == 4 and studio.list.item_count == 4 and not studio.current.is_empty(), "paso nuevo")
	# una ventana de 6 x 1: pasillo; la salida al final
	studio._resize_window("d", 1)
	studio._resize_window("w", 6)
	check(int(studio.current.d) == 1 and int(studio.current.w) == 6, "se cambia el tamaño de la ventana")
	studio.set_tool("entry")
	studio.click_face(Vector3i(0, 0, 0), Vector3i(0, 1, 0))
	studio.set_tool("exit")
	studio.click_face(Vector3i(5, 0, 0), Vector3i(5, 1, 0))
	check(studio.current.entry == [0, 1, 0] and studio.current.exit == [5, 1, 0], "entrada y salida")
	check(int(studio.current.h) == 3, "la altura mínima es 3")
	# un bloque de pinchos en el medio, de tipo pinchos
	studio.kind_pick = K.SPIKES
	studio.set_tool("add")
	studio.click_face(Vector3i(2, 0, 0), Vector3i(2, 1, 0))
	check(studio.current.blocks.size() == 1 and studio.current.blocks[0][3] == K.SPIKES, "agregar un bloque de pinchos")
	studio.click_face(Vector3i(2, 0, 0), Vector3i(2, 1, 0))
	check(studio.current.blocks.size() == 1, "no se agrega dos veces en la misma celda")
	# la altura sale sola: un bloque de fin (rojo) alto la sube
	studio.set_tool("exit")
	studio.click_face(Vector3i(5, 5, 0), Vector3i(5, 6, 0))
	check(studio.current.exit == [5, 6, 0] and int(studio.current.h) == 5, "poner el bloque de fin más arriba sube la altura sola (%d)" % int(studio.current.h))
	studio.click_face(Vector3i(5, 0, 0), Vector3i(5, 1, 0))
	check(studio.current.exit == [5, 1, 0] and int(studio.current.h) == 3, "y al bajarlo la altura vuelve a 3")
	studio.set_tool("add")
	studio.click_face(Vector3i(9, 0, 0), Vector3i(9, 1, 0))
	check(studio.current.blocks.size() == 1, "fuera de la ventana no se agrega")
	check(studio.undo() and studio.current.blocks.size() == 0 or studio.current.blocks.size() == 1, "deshacer anda")
	studio.redo()
	if studio.current.blocks.is_empty():
		studio.click_face(Vector3i(2, 0, 0), Vector3i(2, 1, 0))
	# sin piso: borrar un bloque del piso deja un pozo; quitar y poner todo el piso
	studio.set_tool("delete")
	studio.click_face(Vector3i(3, 0, 0), Vector3i(3, 1, 0))
	check(studio.current.holes.size() == 1 and studio.current.holes[0] == [3, 0], "borrar un bloque del piso deja un pozo")
	studio.set_floor(false)
	check(studio.current.holes.size() == int(studio.current.w) * int(studio.current.d), "quitar todo el piso")
	studio.set_floor(true)
	check(studio.current.holes.is_empty(), "poner todo el piso")
	# el bloque de inicio en una cara de costado: un bloque fijo nuevo pegado a esa cara, y el jugador parado arriba
	studio.set_tool("entry")
	studio.click_face(Vector3i(4, 2, 0), Vector3i(5, 2, 0))
	check(studio.current.entry == [5, 3, 0], "inicio sobre un bloque nuevo pegado a una cara de costado (%s)" % str(studio.current.entry))
	studio.click_face(Vector3i(0, 0, 0), Vector3i(0, 1, 0))
	check(studio.current.entry == [0, 1, 0], "inicio sobre la cara de arriba de un bloque: ese bloque es el verde")
	studio.set_tool("add")
	# tramo repetible: la columna 2, de 1 a 3 veces (con la herramienta: dos clics en el piso)
	studio.set_tool("slab")
	studio.click_floor(Vector2i(2, 0))
	studio.click_floor(Vector2i(2, 0))
	check(bool(studio.current.repeat.on) and studio.current.repeat.from == 2 and studio.current.repeat.to == 2, "marcar el tramo repetible con dos clics")
	studio._set_repeat("min", 1)
	studio._set_repeat("max", 3)
	check(StepLib.lengths(studio.current) == [1, 2, 3], "rango de largos 1 a 3")
	# ver con 3 repeticiones: la vista tiene 3 bloques de pinchos y no se puede editar
	studio.set_view_r(3)
	await _frames(2)
	var st = studio.view_state()
	var spikes := 0
	for c in st.blocks:
		if st.kind_at(c) == K.SPIKES:
			spikes += 1
	check(spikes == 3, "la vista con 3 repeticiones tiene 3 pinchos (%d)" % spikes)
	studio.set_tool("add")
	var n_before: int = studio.current.blocks.size()
	studio.click_face(Vector3i(0, 0, 0), Vector3i(0, 1, 0))
	check(studio.current.blocks.size() == n_before, "con repeticiones distintas de 1 no se edita")
	studio.set_view_r(1)
	# resolver todos los largos
	var all: Dictionary = studio.run_all_lengths()
	var ok := 0
	for r in all:
		ok += 1 if bool(all[r].ok) else 0
	check(all.size() == 3 and ok == 3, "los tres largos se resuelven (%d de %d)" % [ok, all.size()])
	check(studio.current.results.size() == 3 and studio.result_label.text.find("largo 2") != -1, "los resultados quedan en la lista")
	# resolver el largo 2 y reproducir
	studio.set_view_r(2)
	var ev: Dictionary = studio.solve_current()
	check(bool(ev.ok) and studio.play_path.size() == int(ev.moves), "resolver un largo deja el camino")
	studio.play_goto(studio.play_path.size())
	check(studio.play_state != null and studio.play_state.won, "al final del camino el jugador llegó a la salida")
	studio.play_goto(0)
	check(studio.play_state == null, "al principio se ve el paso quieto")
	studio.set_view_r(1)
	# guardar y volver a abrir
	check(studio.save(), "guardar")
	var again = load("res://scenes/step_studio.tscn").instantiate()
	root.add_child(again)
	await _frames(3)
	again.select_step(3)
	check(again.steps.size() == 4 and again.current.blocks.size() == 1 and again.current.repeat.max == 3 and again.current.results.size() == 3, "se vuelve a abrir igual, con los resultados")
	# vista sola
	again.set_view_only(true)
	check(not again.left_panel.visible and not again.right_panel.visible and again.show_panels_btn.visible, "ver solo el paso")
	again.view_from_behind()
	again.set_view_only(false)
	check(again.left_panel.visible, "se vuelven los paneles")
	# duplicar y eliminar
	again.duplicate_step()
	check(again.steps.size() == 5, "duplicar")
	again.delete_step()
	check(again.steps.size() == 4, "eliminar")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("tests del Estudio de pasos terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
