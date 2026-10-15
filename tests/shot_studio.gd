extends SceneTree
## Capturas del Estudio de salas con pantalla. Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1500x850 -s tests/shot_studio.gd -- BIBLIOTECA.jsonl PREFIJO
const RoomLib := preload("res://scripts/room_lib.gd")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var studio = load("res://scenes/studio.tscn").instantiate()
	root.add_child(studio)
	await _frames(5)
	studio.open_library(args[0])
	await _frames(5)
	# la sala con más bloques movidos
	var best: Dictionary = studio.model.filtered({"sort": "moved"})[0]
	studio.select_room(best.id)
	await _frames(40)
	root.get_texture().get_image().save_png("%s_1_vista.png" % args[1])
	print("sala: ", best.shape, " ", best.h, " pisos, ", best.opt.moved, " bloques; parecidas: ", studio.model.similar(5).size())
	# borrar un bloque con la herramienta
	studio.set_tool("delete")
	var cell := Vector2i(-9, -9)
	for c in studio.model.current.cols:
		cell = c
	studio.click_cell(Vector3i(cell.x, String(studio.model.current.cols[cell]).length(), cell.y))
	await _frames(30)
	root.get_texture().get_image().save_png("%s_2_borrado.png" % args[1])
	print("tras borrar: dirty=", studio.model.dirty, " verificada=", studio.model.verified, " info: ", studio.status.text)
	studio.do_undo()
	studio.set_tool("select")
	studio.click_cell(Vector3i(cell.x, 1, cell.y))
	await _frames(10)
	for k in studio.variant_checks:
		pass
	studio.variant_checks["i"].button_pressed = true
	await _frames(5)
	studio.do_check_variants()
	await _frames(60)
	root.get_texture().get_image().save_png("%s_3_variantes.png" % args[1])
	print("variantes: ", studio.model.current.variants)
	studio.play_goto(studio.model.current.path.size() / 2)
	await _frames(30)
	root.get_texture().get_image().save_png("%s_4_reproduccion.png" % args[1])
	quit()
