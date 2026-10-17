extends RefCounted
## Cosméticos: ropa y gorros para el personaje (characters.gd). No cambian nada del juego. Hay dos huecos: el GORRO (cabeza) y la PRENDA
## (cuerpo), y se combinan libremente. Se ganan con los dados de la pantalla de carga (4 aciertos dan comunes y a veces raros; 5, raros y a
## veces épicos) y se eligen en el menú Personaje. Un cosmético es {id, name, slot ("gorro" o "prenda"), rarity}.
## `build_hat` y `build_outfit` arman el modelo 3D de una pieza; las medidas son las del personaje: la cabeza termina en y = 0,73 y el torso
## (de 0,30 de ancho) va de y = 0,15 a 0,41.

const ModelLib := preload("res://scripts/model_lib.gd")

const RARITIES := {
	"comun": {"name": "Común", "color": Color(0.78, 0.78, 0.84)},
	"raro": {"name": "Raro", "color": Color(0.42, 0.68, 1.0)},
	"epico": {"name": "Épico", "color": Color(0.78, 0.42, 1.0)},
}
const RARITY_ORDER: Array[String] = ["comun", "raro", "epico"]
const SLOTS: Array[String] = ["gorro", "prenda"]

const ALL: Array[Dictionary] = [
	# ---- comunes ----
	{"id": "gorra", "name": "Gorra", "slot": "gorro", "rarity": "comun"},
	{"id": "gorro_lana", "name": "Gorro de lana", "slot": "gorro", "rarity": "comun"},
	{"id": "cinta", "name": "Cinta", "slot": "gorro", "rarity": "comun"},
	{"id": "bufanda", "name": "Bufanda", "slot": "prenda", "rarity": "comun"},
	{"id": "remera", "name": "Remera", "slot": "prenda", "rarity": "comun"},
	{"id": "mochila", "name": "Mochila", "slot": "prenda", "rarity": "comun"},
	# ---- raros ----
	{"id": "copa", "name": "Sombrero de copa", "slot": "gorro", "rarity": "raro"},
	{"id": "brujo", "name": "Gorro de brujo", "slot": "gorro", "rarity": "raro"},
	{"id": "capa", "name": "Capa", "slot": "prenda", "rarity": "raro"},
	{"id": "chaleco", "name": "Chaleco dorado", "slot": "prenda", "rarity": "raro"},
	# ---- épicos ----
	{"id": "corona", "name": "Corona", "slot": "gorro", "rarity": "epico"},
	{"id": "halo", "name": "Halo", "slot": "gorro", "rarity": "epico"},
	{"id": "armadura", "name": "Armadura de obsidiana", "slot": "prenda", "rarity": "epico"},
]

## Los ids de cuando los cosméticos eran colores del cubo, y a qué pieza de ropa equivalen (para no perder lo ya ganado).
const OLD_IDS := {
	"capa_azul": "bufanda", "verde_bosque": "remera", "brasa": "gorra", "turquesa": "gorro_lana", "rosa": "cinta", "plateado": "mochila",
	"dorado": "chaleco", "fantasma": "capa", "obsidiana": "armadura",
}


static func get_cosmetic(id: String) -> Dictionary:
	for c in ALL:
		if c.id == id:
			return c
	return {}


static func by_slot(slot: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in ALL:
		if c.slot == slot:
			out.append(c)
	return out


## Elige al azar un cosmético que todavía no tengas ({} si ya los tenés todos).
static func draw_unowned(owned: Array, rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array[Dictionary] = []
	for c in ALL:
		if not owned.has(c.id):
			pool.append(c)
	if pool.is_empty():
		return {}
	return pool[rng.randi() % pool.size()]


## Los cosméticos de una rareza.
static func by_rarity(rarity: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in ALL:
		if c.rarity == rarity:
			out.append(c)
	return out


## Sortea un cosmético que todavía no tengas con la rareza que toca según `weights` ({"comun": 0.85, "raro": 0.15}). Si de esa rareza ya
## los tenés todos, prueba con la que le sigue en `weights` y, por último, con cualquier otra. {} si ya tenés todos.
static func roll(weights: Dictionary, owned: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var pick := ""
	var r := rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			pick = str(k)
			break
	var order: Array[String] = []
	if pick != "":
		order.append(pick)
	for k in weights:
		if not order.has(str(k)):
			order.append(str(k))
	for k in RARITY_ORDER:
		if not order.has(k):
			order.append(k)
	for k in order:
		var pool: Array[Dictionary] = []
		for c in by_rarity(k):
			if not owned.has(c.id):
				pool.append(c)
		if not pool.is_empty():
			return pool[rng.randi() % pool.size()]
	return {}


# --- los modelos ----------------------------------------------------------------------------------------------------------

## Una caja de color pegada a `parent` en `pos`. Con `ghost` lleva el material de la silueta (lo que se ve a través de lo que tapa al personaje).
static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, ghost := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	if ghost:
		mi.material_override = preload("res://scripts/characters.gd").ghost_material(color)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		# Las partes del personaje se dibujan en la pasada transparente (con profundidad) y DESPUÉS de la silueta: así la silueta, que
		# compara contra la profundidad de la escena, sólo ve las paredes y plataformas, no al propio personaje (si no, se veía lavado).
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		mat.render_priority = 20
		mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## El gorro `id` ("" = ninguno: devuelve null), apoyado sobre la cabeza.
static func build_hat(id: String, ghost := false) -> Node3D:
	if id == "":
		return null
	var rec := ModelLib.cosmetic(id)   # (si el editor de modelos guardó un diseño para este gorro, se usa ese)
	if not rec.is_empty():
		return ModelLib.build_node(rec, "gorro", func(c: Color): return preload("res://scripts/characters.gd").ghost_material(c) if ghost else null)
	return build_hat_from_code(id, ghost)


## El gorro de siempre, armado con cajas en código.
static func build_hat_from_code(id: String, ghost := false) -> Node3D:
	if id == "":
		return null
	var h := Node3D.new()
	h.name = "gorro"
	match id:
		"gorra":
			box(h, Vector3(0.47, 0.08, 0.43), Vector3(0, 0.77, 0), Color(0.86, 0.15, 0.2), ghost)
			box(h, Vector3(0.3, 0.025, 0.16), Vector3(0, 0.745, 0.27), Color(0.65, 0.1, 0.15), ghost)       # visera
			box(h, Vector3(0.08, 0.03, 0.03), Vector3(0, 0.78, 0.22), Color(1.0, 0.95, 0.9), ghost)         # botón
		"gorro_lana":
			box(h, Vector3(0.47, 0.1, 0.43), Vector3(0, 0.78, 0), Color(0.25, 0.45, 0.9), ghost)
			box(h, Vector3(0.47, 0.04, 0.43), Vector3(0, 0.75, 0), Color(0.95, 0.95, 1.0), ghost)          # puño blanco
			box(h, Vector3(0.36, 0.06, 0.32), Vector3(0, 0.86, 0), Color(0.25, 0.45, 0.9), ghost)
			box(h, Vector3(0.11, 0.11, 0.11), Vector3(0, 0.94, 0), Color(0.95, 0.95, 1.0), ghost)          # pompón
		"cinta":
			box(h, Vector3(0.47, 0.06, 0.43), Vector3(0, 0.68, 0), Color(1.0, 0.45, 0.7), ghost)
			box(h, Vector3(0.1, 0.1, 0.04), Vector3(-0.1, 0.7, 0.22), Color(1.0, 0.6, 0.8), ghost)        # moño
			box(h, Vector3(0.1, 0.1, 0.04), Vector3(0.1, 0.7, 0.22), Color(1.0, 0.6, 0.8), ghost)
			box(h, Vector3(0.05, 0.05, 0.05), Vector3(0, 0.7, 0.23), Color(0.9, 0.3, 0.55), ghost)
		"copa":
			box(h, Vector3(0.58, 0.04, 0.54), Vector3(0, 0.75, 0), Color(0.07, 0.07, 0.09), ghost)
			box(h, Vector3(0.34, 0.26, 0.32), Vector3(0, 0.9, 0), Color(0.07, 0.07, 0.09), ghost)
			box(h, Vector3(0.35, 0.06, 0.33), Vector3(0, 0.82, 0), Color(0.72, 0.1, 0.16), ghost)
		"brujo":
			box(h, Vector3(0.64, 0.04, 0.6), Vector3(0, 0.75, 0), Color(0.18, 0.08, 0.3), ghost)
			box(h, Vector3(0.4, 0.12, 0.38), Vector3(0, 0.83, 0), Color(0.3, 0.14, 0.5), ghost)
			box(h, Vector3(0.3, 0.12, 0.28), Vector3(0, 0.95, 0), Color(0.3, 0.14, 0.5), ghost)
			box(h, Vector3(0.2, 0.12, 0.18), Vector3(0, 1.07, 0), Color(0.3, 0.14, 0.5), ghost)
			box(h, Vector3(0.1, 0.1, 0.1), Vector3(0, 1.18, 0), Color(0.95, 0.8, 0.25), ghost)
		"corona":
			box(h, Vector3(0.46, 0.1, 0.42), Vector3(0, 0.78, 0), Color(1.0, 0.82, 0.25), ghost)
			for p in [Vector2(-0.17, -0.15), Vector2(0.17, -0.15), Vector2(-0.17, 0.15), Vector2(0.17, 0.15), Vector2(0, 0.0)]:
				box(h, Vector3(0.08, 0.1, 0.08), Vector3(p.x, 0.88, p.y), Color(1.0, 0.9, 0.4), ghost)
			box(h, Vector3(0.07, 0.07, 0.03), Vector3(0, 0.78, 0.215), Color(0.9, 0.2, 0.35), ghost)         # joya
		"halo":
			for k in 10:
				var ang := float(k) / 10.0 * TAU
				box(h, Vector3(0.1, 0.05, 0.1), Vector3(cos(ang) * 0.22, 0.98, sin(ang) * 0.22), Color(1.0, 0.92, 0.45), ghost)
	return h


## La prenda `id` ("" = ninguna: devuelve null) sobre el torso (x de -0,15 a 0,15, y de 0,15 a 0,41, z de -0,12 a 0,12).
static func build_outfit(id: String, ghost := false) -> Node3D:
	if id == "":
		return null
	var rec := ModelLib.cosmetic(id)   # (idem: un diseño del editor reemplaza al de código)
	if not rec.is_empty():
		return ModelLib.build_node(rec, "prenda", func(c: Color): return preload("res://scripts/characters.gd").ghost_material(c) if ghost else null)
	return build_outfit_from_code(id, ghost)


## La prenda de siempre, armada con cajas en código.
static func build_outfit_from_code(id: String, ghost := false) -> Node3D:
	if id == "":
		return null
	var o := Node3D.new()
	o.name = "prenda"
	match id:
		"bufanda":
			box(o, Vector3(0.36, 0.07, 0.3), Vector3(0, 0.43, 0), Color(0.9, 0.25, 0.25), ghost)
			box(o, Vector3(0.36, 0.02, 0.3), Vector3(0, 0.425, 0), Color(0.95, 0.9, 0.9), ghost)           # franja
			box(o, Vector3(0.08, 0.22, 0.04), Vector3(-0.1, 0.31, 0.16), Color(0.9, 0.25, 0.25), ghost)    # la punta que cuelga
		"remera":
			box(o, Vector3(0.33, 0.24, 0.27), Vector3(0, 0.28, 0), Color(0.25, 0.75, 0.4), ghost)
			box(o, Vector3(0.1, 0.1, 0.13), Vector3(-0.2, 0.36, 0), Color(0.25, 0.75, 0.4), ghost)         # mangas
			box(o, Vector3(0.1, 0.1, 0.13), Vector3(0.2, 0.36, 0), Color(0.25, 0.75, 0.4), ghost)
			box(o, Vector3(0.12, 0.08, 0.02), Vector3(0, 0.3, 0.14), Color(1.0, 0.95, 0.6), ghost)         # estampa
		"mochila":
			box(o, Vector3(0.24, 0.26, 0.1), Vector3(0, 0.29, -0.17), Color(0.55, 0.35, 0.18), ghost)
			box(o, Vector3(0.2, 0.08, 0.04), Vector3(0, 0.33, -0.23), Color(0.4, 0.24, 0.12), ghost)       # solapa
			box(o, Vector3(0.04, 0.22, 0.26), Vector3(-0.1, 0.3, -0.02), Color(0.4, 0.24, 0.12), ghost)    # tiras
			box(o, Vector3(0.04, 0.22, 0.26), Vector3(0.1, 0.3, -0.02), Color(0.4, 0.24, 0.12), ghost)
		"capa":
			box(o, Vector3(0.38, 0.34, 0.05), Vector3(0, 0.25, -0.16), Color(0.8, 0.12, 0.2), ghost)
			box(o, Vector3(0.38, 0.05, 0.3), Vector3(0, 0.42, 0), Color(1.0, 0.85, 0.3), ghost)            # cuello dorado
			box(o, Vector3(0.12, 0.05, 0.03), Vector3(0, 0.39, 0.15), Color(1.0, 0.85, 0.3), ghost)        # broche
		"chaleco":
			box(o, Vector3(0.33, 0.2, 0.27), Vector3(0, 0.27, 0), Color(1.0, 0.8, 0.25), ghost)
			box(o, Vector3(0.03, 0.2, 0.28), Vector3(0, 0.27, 0), Color(0.5, 0.35, 0.1), ghost)            # abertura
			for k in 3:
				box(o, Vector3(0.04, 0.04, 0.02), Vector3(0.06, 0.2 + k * 0.06, 0.14), Color(0.95, 0.95, 0.9), ghost)   # botones
		"armadura":
			box(o, Vector3(0.35, 0.25, 0.29), Vector3(0, 0.28, 0), Color(0.09, 0.07, 0.14), ghost)
			box(o, Vector3(0.12, 0.08, 0.12), Vector3(-0.21, 0.4, 0), Color(0.14, 0.1, 0.22), ghost)       # hombreras
			box(o, Vector3(0.12, 0.08, 0.12), Vector3(0.21, 0.4, 0), Color(0.14, 0.1, 0.22), ghost)
			box(o, Vector3(0.1, 0.1, 0.02), Vector3(0, 0.3, 0.15), Color(0.95, 0.3, 1.0), ghost)           # núcleo brillante
			box(o, Vector3(0.35, 0.025, 0.29), Vector3(0, 0.17, 0), Color(0.95, 0.3, 1.0), ghost)          # cinturón
	return o
