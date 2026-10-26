extends RefCounted
## Los sonidos y los efectos visuales de las acciones en la torre (sonido de cada acción, purificar, explosión,
## el tic-tac de las bombas y los bloques que caen al vacío). Lee de la escena (`torre_juego.gd`) y del Motor lo que pasó en la última acción (`Motor.agarro`, `tipo_agarre`,
## `trampa_rota`, `resbalo`, `salto`, `desarmo`, `exploto`, `caidos_fuera`, `ultimas_celdas_purificadas`, `rastro`).

const Sfx := preload("res://scripts/sonido/sfx.gd")
const Graphics := preload("res://scripts/ui/graphics.gd")
const Juice := preload("res://scripts/ui/juice.gd")
const Vista := preload("res://torre/vista.gd")
const Motor := preload("res://torre/motor.gd")

var e: Node3D        # la escena de la torre
var juice            # el juice del juego (estirar y aplastar, polvo, temblor...), manejando el personaje de esta escena
var _tick_t := 0.0
var _tick_tock := false
var _luz: SphereMesh


func _init(escena: Node3D) -> void:
	e = escena
	juice = Juice.new(escena)
	_luz = SphereMesh.new()
	_luz.radius = 0.045
	_luz.height = 0.09
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.95, 0.7)
	_luz.material = m


## La posición en el mundo de la escena del centro de una celda de la sala (con el desplazamiento de altura de esa sala).
func _w(c: Vector3i, off: float) -> Vector3:
	return Vector3(c.x + 0.5, c.y + 0.5 + off, c.z + 0.5)


## Cada cuadro: el temblor de la cámara del juice y el tic-tac de las bombas con cuenta.
func proceso(delta: float, activa: bool) -> void:
	juice.process(delta)
	if not activa or e.t == null or e.t.terminada or e.t.perdida or e.t.muerta:
		return
	var m = e.t.motor
	if m.ganado or m.perdido:
		return
	var off := float(int(e.t.sala_actual().off))
	var soonest := 99
	for c in m.bloques:
		var tp := str(m.bloques[c])
		if tp.length() >= 2 and tp[0] == "b":
			if e.cam.is_position_in_frustum(e.to_global(_w(c, off))):
				soonest = mini(soonest, int(tp.substr(1)))
	if soonest == 99:
		return
	_tick_t += delta
	var interval := clampf(0.22 + 0.11 * float(soonest), 0.3, 1.0)
	if _tick_t >= interval:
		_tick_t = 0.0
		_tick_tock = not _tick_tock
		Sfx.play("tic" if _tick_tock else "tac", 1.0, -9.0 + clampf(float(8 - soonest), 0.0, 6.0))


## El sonido de la acción que se acaba de hacer: pisada, empujar, tirar, trepar, colgarse, resbalar... o lo que pasó (caída, pinchos, bomba).
func sonido(m, modo: int, antes_y: int) -> void:
	if m.desarmo:
		Sfx.play("defuse")
	if m.perdido:
		var why := str(m.motivo)
		Sfx.play("boom" if why.begins_with("Explotó") else ("spikes" if why.contains("pinchos") else "fall"))
		return
	if m.ganado:
		Sfx.play("portal")
		return
	if m.trampa_rota:
		Sfx.play("crumble")
	elif modo == Motor.Modo.AGARRAR and m.agarro:   # (Shift sin nada que mover es un paso común: suena a paso)
		Sfx.play("pull" if m.tipo_agarre == "pull" else "push")
	elif modo == Motor.Modo.COLGAR or m.colgado != Vector3i.ZERO:
		Sfx.play("hang")
	elif m.salto:
		Sfx.play("boing")
	elif m.resbalo:
		Sfx.play("slide")
	elif m.jugador.y > antes_y:
		Sfx.play("climb")
	else:
		Sfx.play("step")


## Los efectos visuales de una acción: estirar al dar el paso, aplastar y polvo al aterrizar, polvo de los bloques que se movieron, partículas de lo que se purificó,
## la explosión de una bomba y los bloques que caen al vacío. `off`: el desplazamiento de altura de la sala donde pasó.
## `demora`: los bloques que se pierden empiezan a caer cuando termina de moverse el bloque que empujaste.
func visuales(m, antes_y: int, off: float, demora := 0.0, lento := 1.0) -> void:
	var fell := maxi(0, antes_y - m.jugador.y)
	juice.step(fell)
	if fell > 0:
		juice.land(fell)
	for c in m.ultimos_movidos:
		juice.dust(_w(c, off) + Vector3(0, -0.45, 0), 4, 0.6)
	for c in m.ultimas_celdas_purificadas:
		purificar(_w(c, off) + Vector3(0, 0.5, 0))
	if m.exploto:
		explosion(_w(m.celda_explosion, off))
	for p in m.caidos_fuera:
		caida_de_bloque(m, p[0], str(p[1]), off, demora, lento)


## Una explosión de partículas de luz sobre el bloque que se purificó.
func purificar(pos: Vector3) -> void:
	var b := CPUParticles3D.new()
	b.one_shot = true
	b.amount = maxi(int(14 * Graphics.particle_factor()), 1)
	b.lifetime = 0.8
	b.explosiveness = 1.0
	b.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	b.emission_sphere_radius = 0.25
	b.direction = Vector3.UP
	b.spread = 80.0
	b.initial_velocity_min = 0.8
	b.initial_velocity_max = 1.8
	b.gravity = Vector3(0, -1.2, 0)
	b.mesh = _luz
	e.add_child(b)
	b.position = pos
	b.emitting = Graphics.particle_factor() > 0.0
	e.get_tree().create_timer(1.2).timeout.connect(b.queue_free)


## La bomba explota: un destello que crece, llamas y escombros oscuros, y un sacudón.
func explosion(pos: Vector3) -> void:
	var flash := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	flash.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color = Color(1.0, 0.7, 0.2, 0.9)
	fm.no_depth_test = true
	flash.material_override = fm
	flash.position = pos
	flash.scale = Vector3.ONE * 0.3
	e.add_child(flash)
	var tw := e.create_tween().set_parallel(true)
	tw.tween_property(flash, "scale", Vector3.ONE * 3.2, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(fm, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(flash.queue_free)
	for spec in [[70, Color(1.0, 0.75, 0.2), 0.14, 6.0], [40, Color(0.25, 0.1, 0.1), 0.2, 4.0]]:   # llamas y escombros oscuros
		var p := CPUParticles3D.new()
		p.amount = maxi(int(float(spec[0]) * Graphics.particle_factor()), 1)
		p.one_shot = true
		p.explosiveness = 1.0
		p.lifetime = 0.9
		p.local_coords = false
		p.direction = Vector3.UP
		p.spread = 180.0
		p.initial_velocity_min = float(spec[3]) * 0.4
		p.initial_velocity_max = float(spec[3])
		p.gravity = Vector3(0, -9.0, 0)
		var box := BoxMesh.new()
		box.size = Vector3.ONE * float(spec[2])
		var bmat := StandardMaterial3D.new()
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bmat.albedo_color = spec[1]
		box.material = bmat
		p.mesh = box
		e.add_child(p)
		p.position = pos
		p.emitting = Graphics.particle_factor() > 0.0
		e.get_tree().create_timer(1.5).timeout.connect(p.queue_free)
	juice.add_shake(1.2)


## Un bloque que se perdió: se lo dibuja un instante donde estaba y se hunde en la oscuridad dando vueltas.
func caida_de_bloque(m, celda: Vector3i, letra: String, off: float, demora := 0.0, lento := 1.0) -> void:
	var falso = Motor.crear(int(m.meta), m.jugador)
	falso.poner(celda, letra)
	var pivote := Node3D.new()   # (gira alrededor del centro del bloque)
	pivote.position = _w(celda, off)
	e.add_child(pivote)
	var contenido := Node3D.new()
	contenido.position = -Vector3(celda.x + 0.5, celda.y + 0.5, celda.z + 0.5)
	pivote.add_child(contenido)
	Vista.poblar(contenido, falso, {}, false, false, false, true)
	var tw := pivote.create_tween().set_parallel(true)
	tw.tween_property(pivote, "position:y", pivote.position.y - 14.0, 0.8 * lento).set_delay(demora).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(pivote, "rotation:x", randf_range(-1.5, 1.5), 0.8 * lento).set_delay(demora)
	tw.tween_property(pivote, "rotation:z", randf_range(-1.5, 1.5), 0.8 * lento).set_delay(demora)
	tw.chain().tween_callback(pivote.queue_free)
