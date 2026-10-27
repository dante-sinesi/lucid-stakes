extends RefCounted
## Dibuja una sala de la torre sin núcleo (un estado de torre/motor.gd) con los modelos de bloques del juego y pone la cámara DETRÁS del jugador.
## Lo usan el Estudio de salas y las capturas. Todo es 3D bajo un nodo padre; la cámara la maneja quien llama (o `camara_detras`).

const BlockModels := preload("res://scripts/personajes/block_models.gd")
const Escena := preload("res://torre/escena.gd")
const CuentaBomba := preload("res://torre/cuenta_bomba.gd")
const BlockArt := preload("res://scripts/personajes/block_art.gd")

## La etapa del run (0 = ninguna): decide cuánta corrupción tiene el arte de los bloques (block_art.gd). Lo pone torre_juego.gd antes de dibujar.
static var etapa_arte := 0
const VARIANTES_ARTE := 8   # diseños distintos del bloque de piedra (cada bloque toma uno según su celda)
const Reglas := preload("res://torre/reglas.gd")
const Tipos := preload("res://torre/tipos.gd")

const KIND_DE_LETRA := {"n": 0, "i": 1, "c": 4, "h": 5, "t": 6, "s": 7, "k": 3, "p": 0, "f": 0}


static func world_pos(c: Vector3i) -> Vector3:
	return Vector3(c.x + 0.5, c.y + 0.5, c.z + 0.5)


## Arma los bloques bajo `parent` (se borra lo que había). `t` es un Motor. `encendidos`: celdas de checkpoint con el farolito prendido.
static var _mats_glow := {}


## El material de un bloque con su brillo (los purificados emanan luz, las bombas activas brillan en rojo): como en el juego.
static func _material_brillo(tint: Color, ice: bool, glow: Color, energia: float) -> ShaderMaterial:
	var key := "%s|%s|%s|%.2f" % [tint.to_html(), str(ice), glow.to_html(), energia]
	if not _mats_glow.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = Escena.BLOCK_SHADER
		mat.set_shader_parameter("roughness_value", 0.15 if ice else 0.8)
		mat.set_shader_parameter("tint", tint)
		mat.set_shader_parameter("glow_color", glow)
		mat.set_shader_parameter("glow_energy", energia)
		mat.set_shader_parameter("shake", 0.0)
		_mats_glow[key] = mat
	return _mats_glow[key]


## `aspecto_juego`: los bloques se ven como en el juego: corruptos (oscuros, violetas) hasta que el jugador los pisa o se cuelga de ellos, y entonces se purifican
## (el color de la etapa y una luz suave); las bombas activas brillan en rojo.
static func poblar(parent: Node3D, t, encendidos := {}, mostrar_referencia := true, con_jugador := true, omitir_p := false, aspecto_juego := false, omitir_f := false) -> void:
	Escena.register_globals()
	for ch in parent.get_children():
		parent.remove_child(ch)
		ch.queue_free()
	var meta := float(maxi(t.meta, 1))
	for c in t.bloques:
		var letra: String = t.bloques[c]
		if t.obstaculos.has(c):
			continue   # (es de la sala de arriba: la torre la dibuja con su sala)
		if omitir_p and letra == "p":
			continue
		if omitir_f and letra == "f":
			continue   # (el bloque de salida de la torre es el cubo-portal, que dibuja la escena)   # (en la torre la entrada de una sala es la salida de la anterior: se dibuja una sola vez)
		var kind: int = KIND_DE_LETRA.get(letra.substr(0, 1), 0)
		if letra.begins_with("b"):
			kind = 2   # bomba (con la mecha pegada: "b7")
		elif letra == "d":
			kind = 2   # bomba desactivada
		var tint := Color.from_hsv(lerpf(0.62, 0.05, clampf(float(c.y) / meta, 0.0, 1.0)), 0.55, 1.0)
		tint = Color(tint.r * 1.15, tint.g * 1.15, tint.b * 1.15)
		var model := kind
		var estado_modelo := BlockModels.State.PURE
		if letra == "d":
			estado_modelo = BlockModels.State.DEFUSED
		if letra == "p" or letra == "f":   # los checkpoint (entrada común, salida fija) son dorados con su farolito
			tint = Color(1.9, 1.55, 0.55)
		if kind == 2:   # la bola oscura de la bomba se pierde contra el fondo con el color de la altura: se la aclara
			tint = Color(3.2, 3.2, 3.4) if letra != "d" else Color(2.2, 2.4, 2.2)
		var m := MeshInstance3D.new()
		var glow := Color.BLACK
		var energia := 0.0
		if aspecto_juego and letra != "p" and letra != "f":
			var pura: bool = t.purificados.has(t.ids.get(c, -1))
			var base := Color.from_hsv(0.62, 0.65, 0.85)   # el color de la etapa 1 (sólo los bloques normales purificados)
			tint = Color.WHITE
			if letra.begins_with("b"):
				estado_modelo = BlockModels.State.CORRUPT   # la bomba activa: bola oscura con brillo rojo
				glow = Color(0.9, 0.1, 0.05)
				energia = 0.35
			elif letra == "d":
				estado_modelo = BlockModels.State.DEFUSED
				glow = Color(1.0, 0.95, 0.7)
				energia = 0.12
			else:
				estado_modelo = BlockModels.State.PURE if pura else BlockModels.State.CORRUPT
				if pura:
					if letra == "n":
						tint = base
						glow = base.lightened(0.3)
						energia = 0.22
					else:
						glow = Color(1.0, 0.95, 0.7)
						energia = 0.12
		if aspecto_juego and (letra == "p" or letra == "f"):   # el checkpoint dorado con su farolito: encendido (limpio) si ya se pisó
			m.mesh = BlockArt.malla_bloque("checkpoint", BlockArt.Estado.PURIFICADO if encendidos.has(c) else BlockArt.Estado.CORRUPTO, BlockArt.nivel_de_etapa(maxi(etapa_arte, 1)), absi(c.x * 31 + c.y * 17 + c.z * 7) % VARIANTES_ARTE)
			m.material_override = Escena.material(Color.WHITE, false)
		elif aspecto_juego and letra == "k":   # la catapulta
			m.mesh = BlockArt.malla_bloque("catapulta", BlockArt.Estado.PURIFICADO if t.purificados.has(t.ids.get(c, -1)) else BlockArt.Estado.CORRUPTO, BlockArt.nivel_de_etapa(maxi(etapa_arte, 1)), absi(c.x * 31 + c.y * 17 + c.z * 7) % VARIANTES_ARTE)
			m.material_override = Escena.material(Color.WHITE, false)
		elif aspecto_juego and (letra.begins_with("b") or letra == "d"):   # la bomba: activa (corrupta) o desactivada (purificada)
				m.mesh = BlockArt.malla_bloque("bomba", BlockArt.Estado.PURIFICADO if letra == "d" else BlockArt.Estado.CORRUPTO, BlockArt.nivel_de_etapa(maxi(etapa_arte, 1)), absi(c.x * 31 + c.y * 17 + c.z * 7) % VARIANTES_ARTE)
				m.material_override = Escena.material(Color.WHITE, false)
		elif aspecto_juego and (letra == "n" or letra == "h" or letra == "i" or letra == "c" or letra == "t" or letra == "s"):   # la piedra común, el pesado, el hielo, la arenisca agrietada, la trampa y los pinchos: el arte de 10 x 10 x 10 (corrupto hasta que se pisa, después purificado)
			var pura_n: bool = t.purificados.has(t.ids.get(c, -1))
			m.mesh = BlockArt.malla_bloque("hierro" if letra == "h" else ("hielo" if letra == "i" else ("arenisca" if letra == "c" else ("trampa" if letra == "t" else ("pinchos" if letra == "s" else "piedra")))), BlockArt.Estado.PURIFICADO if pura_n else BlockArt.Estado.CORRUPTO, BlockArt.nivel_de_etapa(maxi(etapa_arte, 1)), absi(c.x * 31 + c.y * 17 + c.z * 7) % VARIANTES_ARTE)
			m.material_override = Escena.material_translucido("hielo" if letra == "i" else "trampa") if (letra == "i" or letra == "t") else Escena.material(Color.WHITE, false)   # (el hielo y la trampa son translúcidos)
			if letra == "i" or letra == "t":   # (las caras de atrás, en otra malla igual que se dibuja antes)
				var atras := MeshInstance3D.new()
				atras.mesh = m.mesh
				atras.material_override = Escena.material_translucido("hielo" if letra == "i" else "trampa", true)
				atras.position = world_pos(c)
				parent.add_child(atras)
		else:
			m.mesh = BlockModels.mesh_for(model, estado_modelo, BlockModels.variant_for(c.x * 31 + c.y * 17 + c.z * 7, 0, model))
			m.material_override = _material_brillo(tint, kind == 1, glow, energia) if energia > 0.0 else Escena.material(tint, kind == 1)
		m.position = world_pos(c)
		parent.add_child(m)
		if letra.length() >= 2 and letra[0] == "b":
			parent.add_child(_cuenta(c, int(letra.substr(1)), t.jugador, t.bloques.has(c + Vector3i(0, 1, 0))))
			parent.add_child(_zona(c, t))
	if con_jugador:
		parent.add_child(_figura_jugador(t))
	if mostrar_referencia:
		parent.add_child(_referencia())


static func _figura_jugador(t) -> MeshInstance3D:
	var p := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.42, 0.78, 0.42)
	p.mesh = box
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(1.0, 0.62, 0.15)
	pm.emission_enabled = true
	pm.emission = Color(1.0, 0.5, 0.1)
	pm.emission_energy_multiplier = 0.5
	p.material_override = pm
	var pc: Vector3i = t.jugador
	p.position = Vector3(pc.x + 0.5, pc.y + 0.39, pc.z + 0.5)
	p.name = "jugador"
	return p


## La zona de una bomba: bloques rojos translúcidos en el aire de su zona (radio² 5, donde no hay bloque) que se encienden y se apagan despacio sin llegar a desaparecer
## ni a quedar sólidos; mientras el jugador está adentro corre la mecha.
static var _mats_zona := {}   # "adelante" / "atras"


## Los dos materiales de la zona (igual que el hielo: las caras de atrás van en otra malla que se dibuja antes, si no las caras translúcidas se ordenan mal y se ve distinto según desde dónde se mira).
static func _material_zona(atras: bool) -> ShaderMaterial:
	var clave := "atras" if atras else "adelante"
	if not _mats_zona.has(clave):
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded, %s, shadows_disabled, depth_draw_never;\nvoid fragment() {\n\tfloat k = 0.5 - 0.5 * cos(TIME * 6.2832 * 0.45);\n\tALBEDO = vec3(1.0, 0.1, 0.06);\n\tALPHA = mix(0.03, 0.14, k);\n}\n" % ("cull_front" if atras else "cull_back")
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.render_priority = 0 if atras else 1
		_mats_zona[clave] = mat
	return _mats_zona[clave]


static func _zona(c: Vector3i, t) -> Node3D:
	var aire: Array[Vector3i] = []
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			for dz in range(-2, 3):
				var d := Vector3i(dx, dy, dz)
				if d != Vector3i.ZERO and dx * dx + dy * dy + dz * dz <= Tipos.BOMBA_R2 and not t.bloques.has(c + d):
					aire.append(d)
	var mi := Node3D.new()
	mi.position = Vector3(c.x + 0.5, c.y + 0.5, c.z + 0.5)
	var masa := MeshInstance3D.new()   # (una sola malla con la superficie de afuera de todas las celdas: sin caras de adentro, así no hay líneas entre los cubos y se ve como una masa)
	masa.mesh = _malla_masa(aire)
	masa.material_override = _material_zona(false)
	masa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(masa)
	var atras := MeshInstance3D.new()
	atras.mesh = masa.mesh
	atras.material_override = _material_zona(true)
	atras.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(atras)
	return mi


## La superficie de afuera de un conjunto de celdas (relativas a la bomba): sólo las caras que dan a una celda que no está en el conjunto, apenas metidas hacia adentro
## para que no se peleen con las caras de los bloques de al lado.
static func _malla_masa(celdas: Array[Vector3i]) -> ArrayMesh:
	var en := {}
	for d in celdas:
		en[d] = true
	var vs := PackedVector3Array()
	var idx := PackedInt32Array()
	var normales := PackedVector3Array()
	for d in celdas:
		for n: Vector3i in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]:
			if en.has(d + n):
				continue
			var nf := Vector3(n)
			var u := Vector3(n.y, n.z, n.x)   # (dos ejes perpendiculares a la cara)
			var v := nf.cross(u)
			var centro := Vector3(d) + nf * 0.49
			var base := vs.size()
			for q in [-u - v, u - v, u + v, -u + v]:
				vs.append(centro + q * 0.5)
				normales.append(nf)
			idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var m := ArrayMesh.new()
	if vs.is_empty():
		return m
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = normales
	arr[Mesh.ARRAY_INDEX] = idx
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## La cuenta de una bomba (ver `cuenta_bomba.gd`): roja si el jugador está dentro de su zona y la mecha corre.
## Con un bloque justo arriba de la bomba la cuenta quedaría adentro de él: en ese caso (`tapada`) se dibuja sin respetar la profundidad para que se pueda leer.
static func _cuenta(c: Vector3i, mecha: int, jugador: Vector3i, tapada := false) -> Sprite3D:
	var d := jugador - c
	return CuentaBomba.crear(c, mecha, d.x * d.x + d.y * d.y + d.z * d.z <= 5, tapada)


## Una referencia tenue del anillo de la torre (11 x 11 con el vacío de 5 x 5): no es suelo, sólo ayuda a ubicarse.
static func _referencia() -> MeshInstance3D:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(0, 12):
		for seg in [[Vector3(i, 0, 0), Vector3(i, 0, 11)], [Vector3(0, 0, i), Vector3(11, 0, i)]]:
			var a: Vector3 = seg[0]
			var b: Vector3 = seg[1]
			# se dibuja sólo lo que toca el anillo: el vacío de 5 x 5 del medio (celdas 3 a 7) queda sin grilla
			if i >= 4 and i <= 7:
				var uno := Vector3(a.x if a.x == b.x else 3.0, 0, a.z if a.z == b.z else 3.0)
				var dos := Vector3(a.x if a.x == b.x else 8.0, 0, a.z if a.z == b.z else 8.0)
				im.surface_add_vertex(a)
				im.surface_add_vertex(uno)
				im.surface_add_vertex(dos)
				im.surface_add_vertex(b)
				continue
			im.surface_add_vertex(a)
			im.surface_add_vertex(b)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.35, 0.38, 0.55, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.position = Vector3(0, 0.02, 0)
	mi.name = "referencia"
	return mi


## La dirección horizontal hacia donde "mira" la sala: del jugador al bloque checkpoint de la salida (si no hay, hacia el centro de la torre).
static func direccion_hacia_salida(t) -> Vector3:
	var salida := Vector3(-1, -1, -1)
	for c in t.bloques:
		if t.bloques[c] == "f" and c.y == t.meta:
			salida = world_pos(c)
	var hacia := Vector3(5.5, 0, 5.5) - Vector3(t.jugador.x + 0.5, 0, t.jugador.z + 0.5)
	if salida.x >= 0:
		hacia = Vector3(salida.x - (t.jugador.x + 0.5), 0, salida.z - (t.jugador.z + 0.5))
	if hacia.length() < 0.3:
		hacia = Vector3(0, 0, 1)
	return hacia.normalized()


## Cámara detrás del jugador: mira hacia donde queda la salida, desde atrás y un poco arriba, con la parte de adelante y de arriba de la sala a la vista.
static func camara_detras(cam: Camera3D, t, dist := 5.0, altura := 2.3, mirar_adelante := 1.4) -> void:
	var f := direccion_hacia_salida(t)
	var p := Vector3(t.jugador.x + 0.5, t.jugador.y + 0.5, t.jugador.z + 0.5)
	var falta := float(maxi(t.meta + 1 - t.jugador.y, 0))   # (pisos que faltan: en salas altas la cámara se aleja y mira más arriba)
	var objetivo := p + f * mirar_adelante + Vector3(0, 0.9 + minf(falta * 0.17, 2.0), 0)
	cam.look_at_from_position(p - f * (dist + minf(falta * 0.1, 1.2)) + Vector3(0, altura + minf(falta * 0.05, 0.8), 0), objetivo, Vector3.UP)
	cam.fov = 66.0


## Cámara fija para ver TODA la sala: mismo ángulo que `camara_detras` (desde atrás de la entrada, hacia la salida, un poco elevada) pero alejada hasta encuadrar la sala entera.
## `t` es el estado de partida: la cámara no se mueve mientras se reproduce el camino.
static func camara_sala(cam: Camera3D, t) -> void:
	var f := direccion_hacia_salida(t)
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	var celdas: Array = t.bloques.keys()
	celdas.append(t.jugador)
	celdas.append(Vector3i(t.jugador.x, t.meta + 1, t.jugador.z))
	for c in celdas:
		lo = Vector3(minf(lo.x, c.x), minf(lo.y, c.y), minf(lo.z, c.z))
		hi = Vector3(maxf(hi.x, c.x + 1.0), maxf(hi.y, c.y + 1.0), maxf(hi.z, c.z + 1.0))
	var centro := (lo + hi) * 0.5
	var radio := (hi - lo).length() * 0.5
	cam.fov = 66.0
	var d := radio / sin(deg_to_rad(cam.fov * 0.5)) * 0.88
	var elev := deg_to_rad(18.0)
	cam.look_at_from_position(centro - f * d * cos(elev) + Vector3(0, d * sin(elev), 0), centro, Vector3.UP)


## Un Motor desde la línea de una sala del archivo (jsonl).
static func motor_de(d: Dictionary):
	var Motor = load("res://torre/motor.gd")
	var t = Motor.crear(int(d.meta), Vector3i(int(d.jugador[0]), int(d.jugador[1]), int(d.jugador[2])))
	for b in d.bloques:
		t.poner(Vector3i(int(b[0]), int(b[1]), int(b[2])), str(b[3]))
	var col = d.get("colgado", [0, 0])
	t.colgado = Vector3i(int(col[0]), 0, int(col[1]))
	return t
