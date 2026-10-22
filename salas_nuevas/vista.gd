extends RefCounted
## Dibuja una sala de la torre sin núcleo (un estado de salas_nuevas/motor.gd) con los modelos de bloques del juego y pone la cámara DETRÁS del jugador.
## Lo usan el Estudio de salas nuevas y las capturas. Todo es 3D bajo un nodo padre; la cámara la maneja quien llama (o `camara_detras`).

const BlockModels := preload("res://scripts/block_models.gd")
const RoomView := preload("res://scripts/room_view.gd")
const Reglas := preload("res://salas_nuevas/reglas.gd")

const KIND_DE_LETRA := {"n": 0, "i": 1, "c": 4, "h": 5, "t": 6, "s": 7, "k": 3, "p": 0, "f": 0}


static func world_pos(c: Vector3i) -> Vector3:
	return Vector3(c.x + 0.5, c.y + 0.5, c.z + 0.5)


## Arma los bloques bajo `parent` (se borra lo que había). `t` es un Motor. `encendidos`: celdas de checkpoint con el farolito prendido.
static func poblar(parent: Node3D, t, encendidos := {}, mostrar_referencia := true, con_jugador := true, omitir_p := false) -> void:
	RoomView.register_globals()
	for ch in parent.get_children():
		parent.remove_child(ch)
		ch.queue_free()
	var meta := float(maxi(t.meta, 1))
	for c in t.bloques:
		var letra: String = t.bloques[c]
		if omitir_p and letra == "p":
			continue   # (en la torre la entrada de una sala es la salida de la anterior: se dibuja una sola vez)
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
		m.mesh = BlockModels.mesh_for(model, estado_modelo, BlockModels.variant_for(c.x * 31 + c.y * 17 + c.z * 7, 0, model))
		m.material_override = RoomView.material(tint, kind == 1)
		m.position = world_pos(c)
		parent.add_child(m)
		if letra == "p" or letra == "f":
			parent.add_child(_farolito(c, encendidos.has(c)))
		if letra.length() >= 2 and letra[0] == "b":
			parent.add_child(_cuenta(c, int(letra.substr(1)), t.jugador))
			parent.add_child(_zona(c))
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


## La zona de una bomba: una esfera roja translúcida (radio² 5) alrededor del bloque; mientras el jugador está adentro corre la mecha.
static func _zona(c: Vector3i) -> MeshInstance3D:
	var sp := SphereMesh.new()
	sp.radius = sqrt(5.0)
	sp.height = sqrt(5.0) * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = sp
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.15, 0.1, 0.16)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.position = Vector3(c.x + 0.5, c.y + 0.5, c.z + 0.5)
	# el centro: una bolita brillante que se ve aunque otros bloques la tapen (la bomba suele quedar metida en la pila)
	var nucleo := MeshInstance3D.new()
	var ns := SphereMesh.new()
	ns.radius = 0.2
	ns.height = 0.4
	nucleo.mesh = ns
	var nm := StandardMaterial3D.new()
	nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nm.albedo_color = Color(1.0, 0.55, 0.1)
	nm.no_depth_test = true
	nm.render_priority = 10
	nucleo.material_override = nm
	mi.add_child(nucleo)
	return mi


## La cuenta de una bomba: un número grande flotando arriba (rojo si el jugador está dentro de su zona y la mecha corre).
static func _cuenta(c: Vector3i, mecha: int, jugador: Vector3i) -> Label3D:
	var l := Label3D.new()
	l.text = str(mecha)
	l.font_size = 96
	l.pixel_size = 0.012
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	var d := jugador - c
	l.modulate = Color(1.0, 0.25, 0.2) if d.x * d.x + d.y * d.y + d.z * d.z <= 5 else Color(0.95, 0.95, 0.95)
	l.outline_size = 12
	l.position = Vector3(c.x + 0.5, c.y + 1.25, c.z + 0.5)
	return l


## El farolito del bloque checkpoint: una esferita arriba (amarilla y brillante si está prendido, apagada si no).
static func _farolito(c: Vector3i, prendido: bool) -> MeshInstance3D:
	var s := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.13
	sp.height = 0.26
	s.mesh = sp
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.3) if prendido else Color(0.25, 0.22, 0.12)
	mat.emission_enabled = prendido
	mat.emission = Color(1.0, 0.8, 0.2)
	mat.emission_energy_multiplier = 2.2 if prendido else 0.0
	s.material_override = mat
	s.position = Vector3(c.x + 0.5, c.y + 1.18, c.z + 0.5)
	return s


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
	var Motor = load("res://salas_nuevas/motor.gd")
	var t = Motor.nueva(int(d.meta), Vector3i(int(d.jugador[0]), int(d.jugador[1]), int(d.jugador[2])))
	for b in d.bloques:
		t.poner(Vector3i(int(b[0]), int(b[1]), int(b[2])), str(b[3]))
	var col = d.get("colgado", [0, 0])
	t.colgado = Vector3i(int(col[0]), 0, int(col[1]))
	return t
