extends SceneTree
## La pantalla del editor de modelos (model_editor.gd): abre, lista los modelos, elige y edita con las herramientas, guarda y muestra la vista 3D.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_editor_modelos.gd

const ModelLib := preload("res://scripts/personajes/model_lib.gd")
const BM := preload("res://scripts/personajes/block_models.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	ModelLib.dir = "user://test_modelos_ed"
	var d := DirAccess.open(ModelLib.dir)
	if d != null:
		for f in d.get_files():
			DirAccess.remove_absolute(ModelLib.dir + "/" + f)
	ModelLib.reload()
	var ed: Control = load("res://scenes/model_editor.tscn").instantiate()
	root.add_child(ed)
	await process_frame
	await process_frame
	check(ed.cur == null and ed.list.item_count == 0, "sin modelos guardados el editor abre vacío")
	# importar del código y listar
	ed._on_import("bloques")
	check(ed.models.size() > 30 and ed.cur != null and ed.list.item_count == ed.models.size(), "importar los bloques del código trae todas las variantes (%d)" % ed.models.size())
	ed.filter.select(1)
	ed._rebuild_list()
	check(ed.list.item_count == ed.models.size(), "el filtro de bloques los muestra")
	ed.filter.select(3)
	ed._rebuild_list()
	check(ed.list.item_count == 0, "el filtro de personajes no muestra bloques")
	ed._on_import("personajes")
	ed._on_import("cosmeticos")
	ed.filter.select(0)
	ed._rebuild_list()
	# editar un bloque con la herramienta
	var normal = ed.models.filter(func(m): return m.kind == "bloque" and m.block == "normal" and m.variant == 0 and m.state == "pure")[0]
	ed.open_model(normal)
	await process_frame
	await process_frame
	check(ed.mesh_cur.mesh != null and ed.mesh_cur.mesh.get_surface_count() == 1, "la vista 3D arma la malla del bloque")
	ed._on_tool("sacar")
	var before: int = normal.voxel_total()
	check(ed.apply_tool(Vector3i(2, 4, 2), Vector3i(-1000, 0, 0)) and normal.voxel_total() == before - 1, "Sacar quita el minibloque tocado")
	ed._on_tool("poner")
	check(ed.apply_tool(Vector3i(-1000, 0, 0), Vector3i(2, 4, 2)) and normal.voxel_total() == before, "Poner agrega en la celda de enfrente")
	ed._on_tool("gotero")
	ed.apply_tool(Vector3i(2, 4, 2), Vector3i(-1000, 0, 0))
	check(normal.color_index == int(normal.current_map()[Vector3i(2, 4, 2)]), "el cuentagotas elige el color del minibloque")
	# el rayo de la cámara encuentra el modelo
	await process_frame
	var vp_center: Vector2 = Vector2(ed.viewport.size) * 0.5
	var r: Dictionary = ed.pick(vp_center)
	check(r.hit.x != -1000 or r.prev.x != -1000, "el rayo desde el centro de la vista toca el modelo o el piso")
	# guardar
	ed._on_save()
	check(not normal.dirty and FileAccess.file_exists(ModelLib.dir + "/bloques.jsonl"), "Guardar escribe data/modelos/bloques.jsonl y limpia la marca")
	check(ModelLib.read_file(ModelLib.dir + "/bloques.jsonl").size() == 1, "sólo se guardó el modelo abierto")
	# un personaje se abre con sus partes y el selector de partes
	var gato = ed.models.filter(func(m): return m.kind == "personaje" and m.id == "gato")[0]
	ed.open_model(gato)
	await process_frame
	await process_frame
	check(ed.part_opt != null and ed.part_opt.item_count >= 5 and ed.pivot_spins.size() == 3, "el personaje muestra el selector de partes y el pivote")
	ed._select_part(1)
	check(gato.part == 1, "se elige otra parte")
	check(ed.mesh_other.mesh != null, "las otras partes se ven aparte (a medias)")
	# un cosmético muestra al personaje de referencia
	var corona = ed.models.filter(func(m): return m.kind == "cosmetico" and m.id == "corona")[0]
	ed.open_model(corona)
	await process_frame
	await process_frame
	check(ed.ref_node != null and is_instance_valid(ed.ref_node), "el cosmético se ve sobre el personaje de referencia")
	ed._on_new("cosmetico")
	check(ed.cur.kind == "cosmetico" and ed.cur.dirty and not ed.cur.verify().is_empty(), "un modelo nuevo está vacío y marcado como sin guardar")
	ed._on_delete()
	ed.queue_free()
	await process_frame
	d = DirAccess.open(ModelLib.dir)
	if d != null:
		for f in d.get_files():
			DirAccess.remove_absolute(ModelLib.dir + "/" + f)
	ModelLib.dir = ModelLib.DIR
	ModelLib.reload()
	BM.clear_cache()
	print("tests del editor de modelos terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
