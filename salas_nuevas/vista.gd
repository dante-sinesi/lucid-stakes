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
static func poblar(parent: Node3D, t, encendidos := {}, mostrar_referencia := true) -> void:
	RoomView.register_globals()
	for ch in parent.get_children():
		parent.remove_child(ch)
		ch.queue_free()
	var meta := float(maxi(t.meta, 1))
	for c in t.bloques:
		var letra: String = t.bloques[c]
		var kind: int = KIND_DE_LETRA.get(letra, 0)
		var tint := Color.from_hsv(lerpf(0.62, 0.05, clampf(float(c.y) / meta, 0.0, 1.0)), 0.55, 1.0)
		tint = Color(tint.r * 1.15, tint.g * 1.15, tint.b * 1.15)
		var model := kind
		if letra == "p" or letra == "f":   # los checkpoint (entrada común, salida fija) son dorados con su farolito
			tint = Color(1.9, 1.55, 0.55)
		var m := MeshInstance3D.new()
		m.mesh = BlockModels.mesh_for(model, BlockModels.State.PURE, BlockModels.variant_for(c.x * 31 + c.y * 17 + c.z * 7, 0, model))
		m.material_override = RoomView.material(tint, kind == 1)
		m.position = world_pos(c)
		parent.add_child(m)
		if letra == "p" or letra == "f":
			parent.add_child(_farolito(c, encendidos.has(c)))
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
	parent.add_child(p)
	if mostrar_referencia:
		parent.add_child(_referencia())


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
			# se dibuja sólo lo que toca el anillo (no el vacío del medio)
			var vac := (i >= 3 and i <= 8)
			if vac and false:
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


## Un Motor desde la línea de una sala del archivo (jsonl).
static func motor_de(d: Dictionary):
	var Motor = load("res://salas_nuevas/motor.gd")
	var t = Motor.nueva(int(d.meta), Vector3i(int(d.jugador[0]), int(d.jugador[1]), int(d.jugador[2])))
	for b in d.bloques:
		t.poner(Vector3i(int(b[0]), int(b[1]), int(b[2])), str(b[3]))
	var col = d.get("colgado", [0, 0])
	t.colgado = Vector3i(int(col[0]), 0, int(col[1]))
	return t
