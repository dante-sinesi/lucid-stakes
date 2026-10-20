extends SceneTree
## Pruebas de los personajes (animalitos), su ropa y los desbloqueos (headless).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_characters.gd

const Characters := preload("res://scripts/characters.gd")
const Cosmetics := preload("res://scripts/cosmetics.gd")
const Profile := preload("res://scripts/profile.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


## Caja que envuelve las cajas del modelo (en el espacio del modelo; sin rotaciones).
func bounds(n: Node, offset := Vector3.ZERO) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array = [[n, offset]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var node: Node = it[0]
		var off: Vector3 = it[1]
		if node is Node3D and node != n:
			off += (node as Node3D).position
		if node is MeshInstance3D and (node as MeshInstance3D).mesh is BoxMesh:
			var size: Vector3 = ((node as MeshInstance3D).mesh as BoxMesh).size
			var a := AABB(off - size * 0.5, size)
			box = a if first else box.merge(a)
			first = false
		for ch in node.get_children():
			stack.append([ch, off])
	return box


func _init() -> void:
	await process_frame
	test_models()
	test_unlocks()
	test_migration()
	await test_anim()
	print("tests de los personajes terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_models() -> void:
	check(Characters.ALL.size() == 5 and Characters.get_character("nope").id == "gato" and Characters.DEFAULT == "gato", "hay cinco personajes (Dante y Gaby y tres animalitos) y un id raro cae en el gatito")
	var seen := {}
	for c in Characters.ALL:
		var m := Characters.build(c.id)
		for part in ["pata_i", "pata_d", "brazo_i", "brazo_d"] + (["cola"] if c.id != "dante" else []):
			check(m.get_node_or_null(part) != null, "%s tiene %s" % [c.id, part])
		var b := bounds(m)
		check(b.position.y >= -0.001 and b.position.y < 0.01, "%s: los pies estan en el piso (y=%.3f)" % [c.id, b.position.y])
		check(b.size.x <= 0.72 and b.size.z <= 0.72, "%s: cabe en la celda (ancho %.2f, fondo %.2f)" % [c.id, b.size.x, b.size.z])
		check(b.end.y >= 0.7 and b.end.y <= 1.05, "%s: mide lo que corresponde (%.2f)" % [c.id, b.end.y])
		# mira hacia +Z: lo que sobresale al frente (hocico, pico, nariz) esta del lado positivo
		check(b.end.z > -b.position.z - 0.001 or b.end.z >= 0.22, "%s: la cara mira hacia +Z" % c.id)
		var sig := "%d:%.3f:%.3f" % [m.get_child_count(), b.size.y, b.size.x]
		for part in m.get_children():
			sig += str(part.name)
		check(not seen.has(sig), "%s se ve distinto de los demas" % c.id)
		seen[sig] = true
		# la silueta tiene las mismas partes
		var g := Characters.build(c.id, "", "", true)
		check(g.get_child_count() == m.get_child_count(), "%s: la silueta tiene las mismas partes" % c.id)
		var all_ghost := true
		for ch in g.get_children():
			if ch is MeshInstance3D:
				all_ghost = all_ghost and (ch as MeshInstance3D).material_override is ShaderMaterial
		check(all_ghost, "%s: la silueta usa el material de la silueta" % c.id)
		# con ropa
		var dressed := Characters.build(c.id, "copa", "capa")
		check(dressed.get_node_or_null("gorro") != null and dressed.get_node_or_null("prenda") != null, "%s se puede vestir" % c.id)
		check(bounds(dressed).size.y > b.size.y - 0.001, "%s: la copa lo hace mas alto" % c.id)
		m.free()
		g.free()
		dressed.free()
	# todos los gorros y prendas combinan con todos los animalitos y no se salen de lo razonable
	for c in Characters.ALL:
		for item in Cosmetics.ALL:
			var m2 := Characters.build(c.id, item.id if item.slot == "gorro" else "", item.id if item.slot == "prenda" else "")
			var b2 := bounds(m2)
			check(b2.size.x < 0.8 and b2.size.z < 0.8 and b2.end.y < 1.4, "%s con %s tiene un tamano razonable (%s)" % [c.id, item.id, str(b2.size)])
			m2.free()


func test_unlocks() -> void:
	Profile.path = "user://test_profile.json"
	Profile.reset()
	check(Profile.owned_characters() == ["dante", "gaby", "gato", "perro"] and Profile.character() == "gato", "al empezar se tienen Dante, Gaby, el gatito y el perrito, y se juega con el gatito")
	check(Profile.select_character("gaby") and Profile.character() == "gaby" and Profile.select_character("gato"), "se puede elegir entre ellos")
	check(not Profile.select_character("conejo") and Profile.character() == "gato", "no se puede elegir uno bloqueado")
	check(Profile.on_stage_reached(1).is_empty() and Profile.on_stage_reached(2).is_empty() and Profile.on_stage_reached(3).is_empty(), "el gatito ya no se gana por etapa (se tiene desde el principio)")
	check(Profile.on_stage_reached(5).is_empty() and Profile.on_stage_reached(6) == ["conejo"] and Profile.on_stage_reached(8).is_empty(), "llegar a la etapa 6 desbloquea al conejito (una sola vez)")
	check(Profile.on_ability("niebla").is_empty(), "ninguna habilidad desbloquea personajes")
	check(Profile.on_trial_cleared().is_empty(), "superar una prueba ya no desbloquea nada (el perrito se tiene desde el principio)")
	check(Profile.owned_characters().size() == 5, "ya estan los cinco")
	check(Profile.select_character("conejo") and Profile.character() == "conejo", "se elige uno desbloqueado")
	Profile.data = {}
	Profile._loaded_from = ""
	check(Profile.character() == "conejo" and Profile.has_character("conejo"), "se guarda en el perfil")
	check(not Profile.unlock_character("dragon"), "un personaje que no existe no se desbloquea")
	Profile.reset()


## Un perfil guardado con los cosmeticos de cuando el personaje era un cubo se pasa a la ropa equivalente.
func test_migration() -> void:
	Profile.path = "user://test_profile.json"
	var f := FileAccess.open(Profile.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": Profile.VERSION, "luz": 40, "cosmetics": {"capa_azul": true, "copa": true, "dorado": true, "viejo_inexistente": true}, "equipped": "capa_azul"}))
	f.close()
	Profile.data = {}
	Profile._loaded_from = ""
	var d := Profile.load_profile()
	check(int(d.luz) == 40, "se conserva lo demas del perfil")
	check(Profile.has_cosmetic("bufanda") and not Profile.has_cosmetic("capa_azul") and Profile.has_cosmetic("copa") and Profile.has_cosmetic("chaleco"), "los cosmeticos viejos pasan a su ropa equivalente")
	check(not d.cosmetics.has("viejo_inexistente"), "lo que ya no existe se descarta")
	check(Profile.equipped_outfit() == "bufanda" and Profile.equipped_hat() == "", "el aspecto elegido pasa al hueco que corresponde")
	check(Profile.character() == "gato", "y se juega con el gatito")
	Profile.reset()


func test_anim() -> void:
	var root := Node3D.new()
	self.root.add_child(root)
	var m := Characters.build("conejo")
	root.add_child(m)
	Characters.step_anim(m, 0.4)
	await create_timer(0.18).timeout
	check(absf((m.get_node("pata_i") as Node3D).rotation.x) > 0.1 and (m.get_node("pata_i") as Node3D).rotation.x * (m.get_node("pata_d") as Node3D).rotation.x < 0.0, "al dar un paso las patas se balancean cada una para un lado")
	await create_timer(0.5).timeout
	check(absf((m.get_node("pata_i") as Node3D).rotation.x) < 0.01, "y vuelven a su lugar")
	Characters.step_anim(null, 0.1)
	check(true, "sin modelo no falla")
	root.queue_free()
