extends Node3D
## El modelo 3D de Farolín (lo arma farolin.gd): la llama titila y la luz sube y baja con ella; la cara cambia entre contenta y triste.

var flame: MeshInstance3D
var light: OmniLight3D
var smile: Node3D
var frown: Node3D
var brazo_i: Node3D
var brazo_d: Node3D
var pata_i: Node3D
var pata_d: Node3D
var sentado := false
var _t := randf() * 10.0
var _base_energy := 1.6
var _accion := ""      # lo que hace ahora mientras espera ("" = nada: sólo respira y titila)
var _accion_t := 0.0
var _proxima := 1.5 + randf() * 2.5
var _hop := -1.0       # segundos desde que empezó el salto de celebrar (-1 = no está saltando)
var _punto := Vector3.ZERO   # dónde saltan las chispas cuando aterriza
var _soplar := false
var _chispeo := false
var _ya_alto := 0.0    # lo que el salto y los giros ya sumaron a la posición y al giro que le dieron de afuera
var _ya_gira := 0.0
var _ya_inclina := 0.0
var _pos_escrita := Vector3.INF
var _rot_escrita := Vector3.INF
const ACCIONES := ["patas", "saludo", "rascar", "mirar", "bostezo"]


func _process(delta: float) -> void:
	_t += delta
	var k := 1.0 + 0.18 * sin(_t * 7.3) + 0.1 * sin(_t * 12.1 + 1.3)
	if light != null:
		light.light_energy = 1.3 * k
	if flame != null:
		var mat := flame.material_override as StandardMaterial3D
		if mat != null:
			mat.emission_energy_multiplier = _base_energy * k
	_animar(delta)


## "contento" (sonríe) o "triste" (boca para abajo, la llama baja).
func set_mood(mood: String) -> void:
	var sad := mood == "triste"
	smile.visible = not sad
	frown.visible = sad
	_base_energy = 0.9 if sad else 1.6


## Salta y enciende (en el checkpoint, "enciende el farolito" con un chispazo; con `soplar`, en el portal, se inclina y sopla): las chispas salen en `punto` (global) al aterrizar.
func celebrar(punto: Vector3, soplar := false) -> void:
	_punto = punto
	_soplar = soplar
	_hop = 0.0
	_chispeo = false
	_accion = ""


## El pasatiempo de Farolín mientras espera, y el salto de celebrar. Cada pocos segundos hace algo al azar: balancea las patitas, saluda, se rasca la cabeza, mira alrededor o bosteza.
func _animar(delta: float) -> void:
	if brazo_i == null or not sentado:
		return   # (de pie, en el casino, quien lo coloca manda: no se mueve su posición ni su giro)
	var bi := 0.0   # rotación z de los hombros (a los lados: el izquierdo en negativo, el derecho en positivo)
	var bd := 0.0
	var gira := 0.0
	var llama := 1.0
	var patas := 0.0
	var inclina := 0.0
	var alto := 0.0
	if _hop >= 0.0:
		_hop += delta
		var k := _hop / 0.55
		if k < 1.0:
			alto = 0.16 * sin(PI * k)
			bi = -2.6 * sin(PI * minf(k * 1.4, 1.0))
			bd = 2.6 * sin(PI * minf(k * 1.4, 1.0))
			inclina = 0.5 * sin(PI * k) if _soplar else 0.0
		else:
			if not _chispeo:
				_chispeo = true
				_chispas()
			var r := (_hop - 0.55) / 0.6
			bi = -1.1 * (1.0 - minf(r, 1.0))
			bd = 1.1 * (1.0 - minf(r, 1.0))
			llama = 1.0 + 0.5 * (1.0 - clampf(r, 0.0, 1.0))
			if r >= 1.0:
				_hop = -1.0
				_proxima = 1.5 + randf() * 2.0
	elif _accion == "":
		_proxima -= delta
		if _proxima <= 0.0:
			_accion = ACCIONES[randi() % ACCIONES.size()]
			_accion_t = 0.0
	else:
		_accion_t += delta
		var d := 1.8 if _accion != "bostezo" else 2.2
		var f := _accion_t / d
		var env := sin(PI * clampf(f, 0.0, 1.0))
		match _accion:
			"patas":
				patas = 0.55 * sin(_accion_t * 9.0) * env
			"saludo":
				bd = (2.4 + 0.35 * sin(_accion_t * 14.0)) * env
			"rascar":
				bi = -(2.7 + 0.2 * sin(_accion_t * 16.0)) * env
			"mirar":
				gira = 0.7 * sin(_accion_t * 3.2) * env
			"bostezo":
				bi = -1.5 * env
				bd = 1.5 * env
				llama = 1.0 - 0.45 * env
		if f >= 1.0:
			_accion = ""
			_proxima = 1.8 + randf() * 3.0
	brazo_i.rotation.z = lerpf(brazo_i.rotation.z, bi - 0.08 * sin(_t * 2.1), minf(delta * 14.0, 1.0))
	brazo_d.rotation.z = lerpf(brazo_d.rotation.z, bd + 0.08 * sin(_t * 2.1 + 1.0), minf(delta * 14.0, 1.0))
	if pata_i != null:
		pata_i.rotation.x = patas
		pata_d.rotation.x = -patas
	# el salto y los giros se suman a donde lo puso quien lo coloca (la torre lo apoya y lo inclina); si lo movieron de afuera, se empieza de cero
	if not position.is_equal_approx(_pos_escrita) or not rotation.is_equal_approx(_rot_escrita):
		_ya_alto = 0.0
		_ya_gira = 0.0
		_ya_inclina = 0.0
	var gira_suave := lerpf(_ya_gira, gira, minf(delta * 8.0, 1.0))
	var inclina_suave := lerpf(_ya_inclina, inclina, minf(delta * 10.0, 1.0))
	position.y += alto - _ya_alto
	rotation.y += gira_suave - _ya_gira
	rotation.x += inclina_suave - _ya_inclina
	_ya_alto = alto
	_ya_gira = gira_suave
	_ya_inclina = inclina_suave
	_pos_escrita = position
	_rot_escrita = rotation
	if flame != null:
		flame.scale = Vector3(1.0, llama, 1.0)


## El chispazo del farolito (o del portal): un puñado de chispas doradas y un destello de luz.
func _chispas() -> void:
	var ch := CPUParticles3D.new()
	var cubo := BoxMesh.new()
	cubo.size = Vector3.ONE * 0.025
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.3)
	mat.emission_energy_multiplier = 2.5
	cubo.material = mat
	ch.mesh = cubo
	ch.amount = 28
	ch.lifetime = 0.9
	ch.one_shot = true
	ch.explosiveness = 1.0
	ch.direction = Vector3.UP
	ch.spread = 70.0
	ch.initial_velocity_min = 0.5
	ch.initial_velocity_max = 1.1
	ch.gravity = Vector3(0, -1.6, 0)
	ch.top_level = true
	add_child(ch)
	ch.global_position = _punto
	ch.emitting = true
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.85, 0.45)
	luz.omni_range = 2.5
	luz.light_energy = 0.0
	luz.top_level = true
	add_child(luz)
	luz.global_position = _punto + Vector3(0, 0.15, 0)
	var tw := luz.create_tween()
	tw.tween_property(luz, "light_energy", 3.0, 0.12)
	tw.tween_property(luz, "light_energy", 0.0, 0.9)
	tw.tween_callback(luz.queue_free)
	var limpiar := ch.create_tween()
	limpiar.tween_interval(1.2)
	limpiar.tween_callback(ch.queue_free)
