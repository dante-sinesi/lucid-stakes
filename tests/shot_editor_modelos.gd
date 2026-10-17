extends SceneTree
## Captura del editor de modelos: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1500x850 -s tests/shot_editor_modelos.gd -- SALIDA.png [tipo:id]
const ModelLib := preload("res://scripts/model_lib.gd")
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	ModelLib.dir = "user://shot_modelos"
	ModelLib.reload()
	var ed: Control = load("res://scenes/model_editor.tscn").instantiate()
	root.add_child(ed)
	await process_frame
	ed._on_import("todo")
	var want: String = args[1] if args.size() > 1 else "personaje:gato"
	var parts := want.split(":")
	for m in ed.models:
		if m.kind == parts[0] and (m.id == parts[1] or (m.kind == "bloque" and "%s_%d" % [m.block, m.variant] == parts[1] and m.state == "pure")):
			ed.open_model(m)
			break
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png(args[0] if args.size() > 0 else "capturas/editor_modelos.png")
	quit(0)
