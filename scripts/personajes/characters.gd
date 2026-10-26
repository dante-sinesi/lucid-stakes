extends RefCounted
## Los personajes: animalitos de voxels (gatito, perrito, conejito). Todos juegan igual; sólo cambia el aspecto. El gatito es
## el de siempre; los otros se desbloquean con logros del juego (ver `unlock`). Cada uno lleva un gorro y una prenda (cosmetics.gd).
##
## `build(id, hat, outfit, ghost)` arma el modelo 3D: el origen está en los PIES, mira hacia +Z y mide unos 0,75 de alto y 0,45 de ancho
## (cabe en una celda de 0,96). Las partes que se mueven al caminar tienen nombre: "pata_i", "pata_d", "brazo_i", "brazo_d" y "cola".
## Con `ghost` las partes se arman con el material de la silueta (se ve a través de lo que tapa al personaje).

const Cosmetics := preload("res://scripts/personajes/cosmetics.gd")
const ModelLib := preload("res://scripts/personajes/model_lib.gd")
const Loc := preload("res://scripts/idioma/loc.gd")
const SILHOUETTE_SHADER := preload("res://shaders/silhouette.gdshader")
const SILHOUETTE_ALPHA := 0.55

const DEFAULT := "gato"

## unlock: cómo se consigue. "inicio" = desde el principio; "prueba" = superar cualquier prueba; "etapa4" / "etapa10" = llegar a esa etapa.
## Dante, Gaby, el gatito (el predeterminado) y el perrito se tienen desde el principio; el conejito se desbloquea.
## `kind` "humano" = personaje con pelo, ropa y manos (ver _build_human); sin `kind`, un animalito.
const ALL: Array[Dictionary] = [
	{"id": "dante", "name": "Dante", "unlock": "inicio", "how": "Desde el principio.", "kind": "humano", "style": "corto",
		"skin": Color(0.93, 0.74, 0.60), "hair": Color(0.22, 0.14, 0.10), "shirt": Color(0.20, 0.55, 0.36), "shirt_dark": Color(0.12, 0.38, 0.24),
		"pants": Color(0.20, 0.26, 0.42), "shoes": Color(0.95, 0.95, 0.97), "accent": Color(1.0, 0.82, 0.25),
		"fur": Color(0.93, 0.74, 0.60), "light": Color(0.97, 0.85, 0.75), "dark": Color(0.22, 0.14, 0.10)},
	{"id": "gaby", "name": "Gaby", "unlock": "inicio", "how": "Desde el principio.", "kind": "humano", "style": "largo",
		"skin": Color(0.96, 0.79, 0.66), "hair": Color(0.50, 0.22, 0.12), "shirt": Color(0.58, 0.32, 0.74), "shirt_dark": Color(0.40, 0.20, 0.55),
		"pants": Color(0.24, 0.26, 0.34), "shoes": Color(0.95, 0.95, 0.97), "accent": Color(1.0, 0.55, 0.65),
		"fur": Color(0.96, 0.79, 0.66), "light": Color(0.98, 0.88, 0.80), "dark": Color(0.50, 0.22, 0.12)},
	{"id": "gato", "name": "Gatito", "unlock": "inicio", "how": "Desde el principio.",
		"fur": Color(0.96, 0.62, 0.28), "light": Color(0.99, 0.95, 0.88), "dark": Color(0.55, 0.3, 0.12)},
	{"id": "perro", "name": "Perrito", "unlock": "inicio", "how": "Desde el principio.",
		"fur": Color(0.84, 0.62, 0.4), "light": Color(0.97, 0.9, 0.78), "dark": Color(0.4, 0.24, 0.12)},
	{"id": "conejo", "name": "Conejito", "unlock": "etapa10", "how": "Llega a la etapa 10.",
		"fur": Color(0.94, 0.93, 0.96), "light": Color(1.0, 1.0, 1.0), "dark": Color(0.62, 0.6, 0.68)},
]


static func get_character(id: String) -> Dictionary:
	for c in ALL:
		if c.id == id:
			return c
	for c in ALL:   # (un id raro cae en el personaje predeterminado)
		if c.id == DEFAULT:
			return c
	return ALL[0]


## Arma el personaje `id` con el gorro y la prenda dados ("" = ninguno). Devuelve el Node3D raíz (origen en los pies).
static func build(id: String, hat := "", outfit := "", ghost := false) -> Node3D:
	var rec := ModelLib.character(id)   # (si el editor de modelos guardó un diseño para este personaje, se usa ese)
	if not rec.is_empty():
		var root := ModelLib.build_node(rec, "personaje", func(c: Color): return ghost_material(c) if ghost else null)
		_dress(root, hat, outfit, ghost)
		return root
	return build_from_code(id, hat, outfit, ghost)


## El gorro y la prenda sobre un personaje ya armado.
static func _dress(root: Node3D, hat: String, outfit: String, ghost: bool) -> void:
	_poner_cosmetico(root, Cosmetics.build_hat(hat, ghost))
	_poner_cosmetico(root, Cosmetics.build_outfit(outfit, ghost))


## Un gorro o una prenda sobre el personaje. Las partes del cosmético que se llaman como las del cuerpo que giran (mangas, hombreras y brazaletes en `brazo_i` y `brazo_d`)
## se cuelgan de esas partes del personaje: así se mueven con él.
static func _poner_cosmetico(root: Node3D, cosmetico: Node3D) -> void:
	if cosmetico == null:
		return
	for parte in cosmetico.get_children():
		var propia := root.get_node_or_null(str(parte.name)) as Node3D
		if propia != null and ModelLib.MOVING_PARTS.has(str(parte.name)):
			for malla in parte.get_children():
				parte.remove_child(malla)
				propia.add_child(malla)
			cosmetico.remove_child(parte)
			parte.queue_free()
	root.add_child(cosmetico)


## El diseño de siempre, armado con cajas en código (el que se pasa al editor con model_import.gd).
static func build_from_code(id: String, hat := "", outfit := "", ghost := false) -> Node3D:
	var ch := get_character(id)
	if str(ch.get("kind", "")) == "humano":
		return _build_human(ch, hat, outfit, ghost)
	var root := Node3D.new()
	root.name = "personaje"
	var fur: Color = ch.fur
	var light: Color = ch.light
	var dark: Color = ch.dark
	var eye := Color(0.06, 0.04, 0.08)
	# --- cuerpo base (igual en todos): cabeza grande, torso chico, patitas y bracitos ---
	_box(root, Vector3(0.3, 0.26, 0.24), Vector3(0, 0.28, 0), fur, ghost)                       # torso
	_box(root, Vector3(0.44, 0.32, 0.4), Vector3(0, 0.57, 0), fur, ghost)                       # cabeza
	for side in [-1, 1]:
		var n := "i" if side < 0 else "d"
		var leg := _pivot(root, "pata_" + n, Vector3(side * 0.08, 0.15, 0))                       # patas: giran desde la cadera
		_box(leg, Vector3(0.11, 0.15, 0.12), Vector3(0, -0.075, 0.01), dark, ghost)
		var arm := _pivot(root, "brazo_" + n, Vector3(side * 0.2, 0.39, 0))                       # brazos: giran desde el hombro
		_box(arm, Vector3(0.08, 0.18, 0.1), Vector3(0, -0.08, 0), fur, ghost)
	_box(root, Vector3(0.05, 0.07, 0.03), Vector3(-0.1, 0.6, 0.2), eye, ghost)                  # ojos
	_box(root, Vector3(0.05, 0.07, 0.03), Vector3(0.1, 0.6, 0.2), eye, ghost)
	# --- lo propio de cada animal ---
	match id:
		"perro":
			_box(root, Vector3(0.2, 0.14, 0.14), Vector3(0, 0.5, 0.26), light, ghost)           # hocico
			_box(root, Vector3(0.08, 0.06, 0.05), Vector3(0, 0.55, 0.34), eye, ghost)           # nariz
			_box(root, Vector3(0.06, 0.03, 0.04), Vector3(0, 0.44, 0.33), Color(0.95, 0.4, 0.5), ghost)   # lengua
			for side in [-1, 1]:
				_box(root, Vector3(0.07, 0.2, 0.13), Vector3(side * 0.255, 0.58, -0.02), dark, ghost)   # orejas caídas
			_box(root, Vector3(0.14, 0.12, 0.02), Vector3(0.0, 0.3, 0.125), light, ghost)       # pecho claro
			var tail := _pivot(root, "cola", Vector3(0, 0.22, -0.12))
			_box(tail, Vector3(0.06, 0.16, 0.06), Vector3(0, 0.06, -0.04), dark, ghost)
		"conejo":
			for side in [-1, 1]:
				_box(root, Vector3(0.09, 0.3, 0.06), Vector3(side * 0.1, 0.89, -0.02), fur, ghost)      # orejas largas
				_box(root, Vector3(0.045, 0.22, 0.02), Vector3(side * 0.1, 0.88, 0.015), Color(1.0, 0.7, 0.78), ghost)
			_box(root, Vector3(0.07, 0.05, 0.04), Vector3(0, 0.54, 0.21), Color(1.0, 0.6, 0.7), ghost)   # nariz
			_box(root, Vector3(0.07, 0.04, 0.03), Vector3(0, 0.49, 0.2), light, ghost)          # dientitos
			_box(root, Vector3(0.14, 0.12, 0.02), Vector3(0.0, 0.3, 0.125), light, ghost)       # pecho claro
			var tail := _pivot(root, "cola", Vector3(0, 0.22, -0.12))
			_box(tail, Vector3(0.13, 0.13, 0.12), Vector3(0, 0.02, -0.05), light, ghost)        # colita de algodón
		_:   # gato
			for side in [-1, 1]:
				_box(root, Vector3(0.11, 0.12, 0.07), Vector3(side * 0.14, 0.79, 0), fur, ghost)        # orejas en punta
				_box(root, Vector3(0.05, 0.07, 0.02), Vector3(side * 0.14, 0.79, 0.035), Color(1.0, 0.7, 0.75), ghost)
			_box(root, Vector3(0.14, 0.1, 0.06), Vector3(0, 0.5, 0.21), light, ghost)           # hocico claro
			_box(root, Vector3(0.06, 0.05, 0.04), Vector3(0, 0.54, 0.24), Color(1.0, 0.6, 0.7), ghost)   # nariz
			for side in [-1, 1]:
				for k in 2:
					_box(root, Vector3(0.12, 0.012, 0.012), Vector3(side * 0.28, 0.5 + k * 0.03 - 0.015, 0.2), light, ghost)   # bigotes
			_box(root, Vector3(0.14, 0.12, 0.02), Vector3(0.0, 0.3, 0.125), light, ghost)       # pecho claro
			var tail := _pivot(root, "cola", Vector3(0, 0.22, -0.12))
			_box(tail, Vector3(0.07, 0.07, 0.2), Vector3(0, 0.02, -0.1), fur, ghost)
			_box(tail, Vector3(0.07, 0.16, 0.07), Vector3(0, 0.1, -0.2), dark, ghost)
	# --- ropa ---
	_dress(root, hat, outfit, ghost)
	return root


## Un personaje humano (Dante o Gaby), con las mismas medidas que los animalitos: cabeza grande, pelo, torso con remera, manos y zapatillas.
## Las partes que se mueven al caminar tienen los mismos nombres (pata_i/d, brazo_i/d); Gaby lleva una colita de pelo que se balancea ("cola").
static func _build_human(ch: Dictionary, hat: String, outfit: String, ghost: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "personaje"
	var skin: Color = ch.skin
	var hair: Color = ch.hair
	var shirt: Color = ch.shirt
	var long_hair: bool = str(ch.style) == "largo"
	var eye := Color(0.06, 0.04, 0.08)
	_box(root, Vector3(0.3, 0.26, 0.24), Vector3(0, 0.28, 0), shirt, ghost)                       # torso (remera)
	_box(root, Vector3(0.32, 0.04, 0.26), Vector3(0, 0.155, 0), ch.shirt_dark, ghost)               # borde de la remera
	_box(root, Vector3(0.44, 0.32, 0.4), Vector3(0, 0.57, 0), skin, ghost)                          # cabeza
	for side in [-1, 1]:
		var n := "i" if side < 0 else "d"
		var leg := _pivot(root, "pata_" + n, Vector3(side * 0.08, 0.15, 0))
		_box(leg, Vector3(0.11, 0.1, 0.12), Vector3(0, -0.05, 0.0), ch.pants, ghost)                # pantalón
		_box(leg, Vector3(0.12, 0.05, 0.16), Vector3(0, -0.125, 0.025), ch.shoes, ghost)             # zapatilla
		var arm := _pivot(root, "brazo_" + n, Vector3(side * 0.2, 0.39, 0))
		_box(arm, Vector3(0.08, 0.12, 0.1), Vector3(0, -0.06, 0), shirt, ghost)                      # manga
		_box(arm, Vector3(0.07, 0.06, 0.09), Vector3(0, -0.15, 0), skin, ghost)                      # mano
	_box(root, Vector3(0.05, 0.07, 0.03), Vector3(-0.1, 0.6, 0.2), eye, ghost)                    # ojos
	_box(root, Vector3(0.05, 0.07, 0.03), Vector3(0.1, 0.6, 0.2), eye, ghost)
	_box(root, Vector3(0.1, 0.02, 0.03), Vector3(0, 0.5, 0.2), skin.darkened(0.3), ghost)           # boca
	_box(root, Vector3(0.05, 0.05, 0.03), Vector3(0, 0.55, 0.21), skin.darkened(0.12), ghost)       # nariz
	# --- pelo ---
	_box(root, Vector3(0.47, 0.05, 0.43), Vector3(0, 0.745, 0), hair, ghost)                        # arriba
	_box(root, Vector3(0.47, 0.07 if not long_hair else 0.09, 0.06), Vector3(0, 0.715, 0.2), hair, ghost)   # flequillo
	if long_hair:
		_box(root, Vector3(0.5, 0.42, 0.1), Vector3(0, 0.5, -0.18), hair, ghost)                     # larga, por la espalda
		for side in [-1, 1]:
			_box(root, Vector3(0.05, 0.3, 0.3), Vector3(side * 0.245, 0.57, 0.0), hair, ghost)      # mechones a los costados
		var tail := _pivot(root, "cola", Vector3(0, 0.66, -0.24))
		_box(tail, Vector3(0.1, 0.2, 0.09), Vector3(0, -0.04, -0.03), hair, ghost)                  # colita
		_box(tail, Vector3(0.12, 0.04, 0.11), Vector3(0, 0.05, -0.02), ch.accent, ghost)            # el hebillo
	else:
		_box(root, Vector3(0.47, 0.2, 0.08), Vector3(0, 0.65, -0.18), hair, ghost)                   # nuca
		for side in [-1, 1]:
			_box(root, Vector3(0.04, 0.12, 0.28), Vector3(side * 0.235, 0.66, 0.02), hair, ghost)   # patillas
		for x in [-0.14, 0.0, 0.14]:
			_box(root, Vector3(0.08, 0.07, 0.08), Vector3(x, 0.8, 0.02 - absf(x) * 0.2), hair, ghost)   # mechones de punta
		_box(root, Vector3(0.3, 0.09, 0.07), Vector3(0, 0.43, -0.15), ch.shirt_dark, ghost)         # la capucha del buzo
	_dress(root, hat, outfit, ghost)
	return root


## Una caja de color (con el material de la silueta si es `ghost`).
static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, ghost: bool) -> MeshInstance3D:
	return Cosmetics.box(parent, size, pos, color, ghost)


## Un nodo vacío en `pos` del que cuelgan las partes que giran (patas, brazos, cola).
static func _pivot(parent: Node3D, node_name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	parent.add_child(n)
	return n


## Material de la silueta con el color dado (se ve sólo donde algo tapa al personaje).
static func ghost_material(color: Color) -> ShaderMaterial:
	var gm := ShaderMaterial.new()
	gm.shader = SILHOUETTE_SHADER
	gm.set_shader_parameter("tint", Color(color, SILHOUETTE_ALPHA))
	gm.set_shader_parameter("compat_depth", RenderingServer.get_current_rendering_method() == "gl_compatibility")
	gm.render_priority = 10
	return gm


# --- animación -----------------------------------------------------------------------------------------------------------

## Un paso: las patas y los brazos se balancean (cada lado al revés) durante `duration` y vuelven; la cola se mueve. Usa un tween del nodo.
static func step_anim(model: Node3D, duration: float, swing := 0.7) -> void:
	if model == null or not is_instance_valid(model):
		return
	var tw := model.create_tween().set_parallel(true)
	for pair in [["pata_i", 1.0], ["pata_d", -1.0], ["brazo_i", -1.0], ["brazo_d", 1.0]]:
		var part := model.get_node_or_null(str(pair[0])) as Node3D
		if part == null:
			continue
		var a: float = swing * float(pair[1])
		part.rotation.x = 0.0
		tw.tween_property(part, "rotation:x", a, duration * 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(part, "rotation:x", 0.0, duration * 0.5).set_delay(duration * 0.5).set_trans(Tween.TRANS_SINE)
	var tail := model.get_node_or_null("cola") as Node3D
	if tail != null:
		tail.rotation.y = 0.0
		tw.tween_property(tail, "rotation:y", 0.5, duration * 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(tail, "rotation:y", 0.0, duration * 0.5).set_delay(duration * 0.5).set_trans(Tween.TRANS_SINE)
