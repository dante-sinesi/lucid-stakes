extends SceneTree
## Variantes de bloques, formato y carga de modelos (model_lib.gd), la lógica del editor de modelos (model_editor_model.gd) y pasar los diseños de código al editor.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_modelos.gd

const BM := preload("res://scripts/personajes/block_models.gd")
const ModelLib := preload("res://scripts/personajes/model_lib.gd")
const EditorModel := preload("res://scripts/herramientas/model_editor_model.gd")
const ModelImport := preload("res://scripts/herramientas/model_import.gd")
const Characters := preload("res://scripts/personajes/characters.gd")
const Cosmetics := preload("res://scripts/personajes/cosmetics.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	ModelLib.dir = "user://test_modelos"
	_clean()
	test_variants()
	test_editor_logic()
	test_roundtrip()
	test_import()
	test_override()
	_clean()
	ModelLib.dir = ModelLib.DIR
	ModelLib.reload()
	BM.clear_cache()
	print("tests de modelos terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func _clean() -> void:
	var d := DirAccess.open(ModelLib.dir)
	if d != null:
		for f in d.get_files():
			DirAccess.remove_absolute(ModelLib.dir + "/" + f)
	ModelLib.reload()
	BM.clear_cache()


func test_variants() -> void:
	for kind in [0, 1, 2, 3, 4, 5, 6, 7]:
		check(BM.variant_count(kind) >= BM.VARIANTS, "tipo %d: tiene al menos %d variantes" % [kind, BM.VARIANTS])
		var sigs := {}
		for v in BM.variant_count(kind):
			var vox: Dictionary = BM._voxels(kind, BM.State.PURE, v)
			var sig := ""
			for p in vox:
				sig += "%d%d%d%s;" % [p.x, p.y, p.z, str(vox[p])]
			sigs[sig.hash()] = true
			# lo que se pisa se lee igual en todas
			if kind != 2 and kind != 7:
				check(BM.top_coverage(kind, BM.State.PURE, v) >= 16, "tipo %d variante %d: la cara de arriba está casi completa (%d)" % [kind, v, BM.top_coverage(kind, BM.State.PURE, v)])
				check(BM.top_coverage(kind, BM.State.CORRUPT, v) >= 9, "tipo %d variante %d corrupta: el centro de arriba se conserva" % [kind, v])
			check(BM.voxel_count(kind, BM.State.CORRUPT, v) <= BM.voxel_count(kind, BM.State.PURE, v), "tipo %d variante %d: el corrupto no tiene más minibloques" % [kind, v])
			check(BM.voxel_count(kind, BM.State.PURE, v) <= 125 and BM.mesh_for(kind, BM.State.PURE, v).get_surface_count() == 1, "tipo %d variante %d: la malla se arma" % [kind, v])
		check(sigs.size() == BM.variant_count(kind), "tipo %d: las %d variantes son distintas entre sí (%d)" % [kind, BM.variant_count(kind), sigs.size()])
	# la variante 0 es el diseño de siempre
	check(BM.voxel_count(0, BM.State.PURE) == BM.voxel_count(0, BM.State.PURE, 0), "la variante por omisión es la 0")
	# estable por bloque, y reparte entre las variantes
	var counts := {}
	for id in 400:
		var v := BM.variant_for(id, 1234, 0)
		check(v == BM.variant_for(id, 1234, 0) and v >= 0 and v < BM.variant_count(0), "la variante de un bloque es estable")
		counts[v] = int(counts.get(v, 0)) + 1
	check(counts.size() == BM.variant_count(0), "las torres usan todas las variantes (%s)" % str(counts))
	var diff := 0
	for id in 100:
		if BM.variant_for(id, 1, 0) != BM.variant_for(id, 2, 0):
			diff += 1
	check(diff > 30, "cada torre reparte las variantes distinto (%d de 100 cambian)" % diff)
	# la bomba desactivada conserva su forma en cada variante
	for v in BM.variant_count(2):
		check(BM.voxel_count(2, BM.State.CORRUPT, v) == BM.voxel_count(2, BM.State.DEFUSED, v), "bomba variante %d: activa y desactivada tienen la misma forma" % v)
	# el costo de armar todas las mallas
	var t0 := Time.get_ticks_msec()
	BM.clear_cache()
	for kind in [0, 1, 2, 3, 4, 5, 6, 7]:
		for v in BM.variant_count(kind):
			for st in 3:
				BM.mesh_for(kind, st, v)
	check(Time.get_ticks_msec() - t0 < 4000, "armar todas las mallas de todas las variantes es rápido (%d ms)" % (Time.get_ticks_msec() - t0))


func test_editor_logic() -> void:
	var m = EditorModel.new_model("bloque", "prueba")
	check(m.voxel_total() == 0 and not m.verify().is_empty(), "un modelo nuevo está vacío y no pasa la verificación")
	m.color_index = 2
	check(m.paint(Vector3i(1, 1, 1)) and m.current_map().has(Vector3i(1, 1, 1)) and int(m.current_map()[Vector3i(1, 1, 1)]) == 2, "pintar pone un minibloque del color elegido")
	check(not m.paint(Vector3i(1, 1, 1)), "pintar lo mismo otra vez no cambia nada")
	check(not m.paint(Vector3i(9, 0, 0)), "no se pinta fuera de la caja")
	m.undo()
	check(m.voxel_total() == 0, "deshacer saca lo pintado")
	m.redo()
	check(m.voxel_total() == 1, "rehacer lo vuelve")
	m.mirror_x = true
	m.paint(Vector3i(0, 2, 2))
	check(m.current_map().has(Vector3i(0, 2, 2)) and m.current_map().has(Vector3i(4, 2, 2)), "la simetría en x pinta también el espejo")
	m.mirror_z = true
	m.paint(Vector3i(1, 3, 0))
	check(m.current_map().has(Vector3i(1, 3, 4)) and m.current_map().has(Vector3i(3, 3, 0)) and m.current_map().has(Vector3i(3, 3, 4)), "con simetría en x y z salen cuatro")
	m.erase(Vector3i(1, 3, 0))
	check(not m.current_map().has(Vector3i(3, 3, 4)), "borrar también borra los espejos")
	m.mirror_x = false
	m.mirror_z = false
	check(m.pick(Vector3i(1, 1, 1)) and m.color_index == 2, "el cuentagotas elige el color")
	m.color_index = 3
	check(m.fill_layer(4) == 25 and m.current_map().size() >= 25, "rellenar una capa pone 25 minibloques")
	m.only_layer = 4
	check(not m.paint(Vector3i(2, 0, 2)), "con una sola capa visible no se pinta en otra")
	check(m.color_map().size() == 25, "con una capa visible sólo se muestra esa")
	m.only_layer = -1
	check(m.verify().is_empty(), "con la cara de arriba completa el bloque pasa la verificación (%s)" % str(m.verify()))
	m.erase(Vector3i(2, 4, 2))
	check(not m.verify().is_empty() and str(m.verify()[0]).contains("cara de arriba"), "un hueco en el centro de arriba se avisa")
	var before: Color = m.palette[3]
	m.set_palette_color(3, Color(0.1, 0.9, 0.1))
	check(m.color_map().values().has(Color(0.1, 0.9, 0.1)) and not m.color_map().values().has(before), "cambiar un color de la paleta cambia todos los minibloques que lo usan")
	m.flip_x()
	m.shift_part(Vector3i(0, 0, 0))
	m.resize(Vector3i(5, 3, 5))
	check(m.size.y == 3 and not m.current_map().has(Vector3i(0, 4, 0)), "achicar la caja descarta lo que queda afuera")
	# personaje: partes y pivotes
	var c = EditorModel.new_model("personaje", "x")
	check(c.parts.size() == 6 and not c.verify().is_empty(), "un personaje nuevo trae sus seis partes y le falta todo")
	for i in c.parts.size():
		c.part = i
		c.paint(Vector3i(12, 2 + i, 12))
	for i in c.parts.size():
		if ModelLib.MOVING_PARTS.has(c.parts[i].name):
			c.part = i
			c.set_pivot(Vector3(12, 10, 12))
	check(c.verify().is_empty(), "con todas las partes y los pivotes el personaje pasa (%s)" % str(c.verify()))
	# cosmético
	var k = EditorModel.new_model("cosmetico", "gorra_nueva")
	k.paint(Vector3i(12, 24, 12))
	k.slot = "sombrero"
	check(not k.verify().is_empty(), "un hueco que no existe se avisa")
	k.slot = "gorro"
	check(k.verify().is_empty(), "un cosmético con su hueco y su rareza pasa")


func test_roundtrip() -> void:
	var m = EditorModel.new_model("bloque", "normal_9")
	m.block = "normal"
	m.variant = 5
	m.color_index = 1
	for x in 5:
		for z in 5:
			m.paint(Vector3i(x, 4, z))
	m.paint(Vector3i(2, 2, 2))
	var rec: Dictionary = m.to_record()
	check(ModelLib.save_record(rec, "t.jsonl"), "se guarda en un archivo")
	ModelLib.reload()
	check(ModelLib.block_variant_count(0) == 6, "con la variante 5 guardada el tipo normal tiene 6 variantes (%d)" % ModelLib.block_variant_count(0))
	var back = EditorModel.from_record(ModelLib.read_file(ModelLib.dir + "/t.jsonl")[0])
	check(back.voxel_total() == m.voxel_total() and back.variant == 5 and back.block == "normal" and back.palette.size() == m.palette.size(), "se lee igual que se guardó")
	check(back.to_record().hash() == rec.hash(), "ida y vuelta idéntica")
	# la variante 5 de ese tipo usa el diseño guardado
	check(BM.variant_count(0) == 6 and BM.voxel_count(0, BM.State.PURE, 5) == 26, "el juego usa la variante guardada (%d minibloques)" % BM.voxel_count(0, BM.State.PURE, 5))
	# guardar de nuevo reemplaza (no duplica)
	m.paint(Vector3i(1, 1, 1))
	ModelLib.save_record(m.to_record(), "t.jsonl")
	check(ModelLib.read_file(ModelLib.dir + "/t.jsonl").size() == 1, "guardar de nuevo reemplaza el mismo modelo")
	ModelLib.delete_record(m.to_record())
	ModelLib.reload()
	check(ModelLib.block_variant_count(0) == 0, "borrar saca el modelo")
	BM.clear_cache()


func test_import() -> void:
	var blocks := ModelImport.blocks()
	check(blocks.size() == 9 * BM.VARIANTS + BM.VARIANTS, "se pasan %d modelos de bloque (9 tipos × %d variantes + las bombas desactivadas)" % [9 * BM.VARIANTS + BM.VARIANTS, BM.VARIANTS])
	var chars := ModelImport.characters()
	check(chars.size() == Characters.ALL.size(), "se pasan todos los personajes")
	for r in chars:
		var m = EditorModel.from_record(r)
		check(m.voxel_total() > 300 and m.parts.size() >= 5, "%s: tiene minibloques y sus partes (%d en %d partes)" % [r.id, m.voxel_total(), m.parts.size()])
		check(m.verify().is_empty(), "%s: pasa la verificación (%s)" % [r.id, str(m.verify())])
	var cosm := ModelImport.cosmetics()
	check(cosm.size() == Cosmetics.ALL.size(), "se pasan todos los cosméticos")
	for r in cosm:
		var m = EditorModel.from_record(r)
		check(m.voxel_total() > 5 and m.verify().is_empty(), "%s: tiene minibloques y pasa (%d, %s)" % [r.id, m.voxel_total(), str(m.verify())])


## Un personaje y un cosmético guardados reemplazan al diseño de código y se arman con sus partes.
func test_override() -> void:
	var before := Characters.build("gato", "corona", "capa")
	var before_parts: Array = before.get_children().map(func(c): return str(c.name))
	check(before_parts.has("pata_i") and before_parts.has("cola") and before_parts.has("gorro") and before_parts.has("prenda"), "el diseño de código trae sus partes que se mueven")
	before.free()
	for r in ModelImport.characters():
		if r.id == "gato":
			ModelLib.save_record(r, "p.jsonl")
	for r in ModelImport.cosmetics():
		if r.id == "corona":
			ModelLib.save_record(r, "c.jsonl")
	ModelLib.reload()
	var after := Characters.build("gato", "corona", "capa")
	var names: Array = after.get_children().map(func(c): return str(c.name))
	check(names.has("pata_i") and names.has("pata_d") and names.has("brazo_i") and names.has("brazo_d") and names.has("cola") and names.has("gorro") and names.has("prenda"), "el personaje del editor conserva los nombres de las partes que giran (%s)" % str(names))
	var leg := after.get_node_or_null("pata_i") as Node3D
	check(leg != null and leg.get_child_count() == 1 and leg.position.y > 0.1 and leg.position.y < 0.2, "la pata cuelga de su pivote, en la cadera")
	Characters.step_anim(after, 0.1)
	var ghost := Characters.build("gato", "corona", "", true)
	var ok := true
	for ch in ghost.get_children():
		if ch is MeshInstance3D:
			ok = ok and (ch as MeshInstance3D).material_override is ShaderMaterial
	check(ok, "la silueta del personaje del editor usa el material de la silueta")
	var colored := true
	for ch in after.get_children():
		if ch is MeshInstance3D:
			colored = colored and (ch as MeshInstance3D).material_override is StandardMaterial3D and ((ch as MeshInstance3D).material_override as StandardMaterial3D).vertex_color_use_as_albedo
	check(colored, "el personaje del editor lleva sus colores (material con color por vértice, no gris)")
	ghost.free()
	var crown: Node3D = Cosmetics.build_hat("corona")
	check(crown != null and crown.name == "gorro" and crown.get_child_count() == 1, "la corona del editor es un gorro de una sola malla")
	crown.free()
	after.free()
