extends Node3D
## Galería de bloques (herramienta de desarrollo): el arte de 10 x 10 x 10 de cada tipo de bloque (block_art.gd), corrupto y purificado, en los cinco niveles de corrupción
## (una columna por cada tres etapas), con la luz del juego. Mouse: arrastrar con el botón izquierdo o derecho gira e inclina; rueda acerca. Teclas: las flechas giran e inclinan
## la cámara (izquierda y derecha giran, arriba y abajo inclinan; se mantienen apretadas), WASD mueven la cámara por el espacio (con Shift, más rápido; con Espacio sube y con Ctrl baja),
## + y - acercan y alejan, Q y E giran 45°,
## 1 a 5 ponen el fondo de esa etapa (para ver el contraste), F alterna el remolino del fondo, R vuelve la cámara, Esc sale.
## Abrir: herramientas\galeria_bloques.bat (o `godot --path . res://scenes/galeria_bloques.tscn`).

const Escena := preload("res://torre/escena.gd")
const Art := preload("res://scripts/personajes/block_art.gd")
const Main := preload("res://scripts/main.gd")
const FondoAnimado := preload("res://scripts/ui/fondo_animado.gd")

## Los tipos que ya tienen arte nuevo (se suman acá a medida que se hacen).
const TIPOS := {"piedra": "Piedra común", "hierro": "Pesado", "hielo": "Hielo", "arenisca": "Agrietado", "trampa": "Trampa", "pinchos": "Pinchos", "bomba": "Bomba", "catapulta": "Catapulta", "checkpoint": "Checkpoint", "portal": "Portal"}
const ETAPAS := [1, 4, 7, 10, 13]   # (la primera etapa de cada nivel)

var env: Environment
var fondo
var cam: Camera3D
var pivot: Node3D
var yaw := 45.0
var pitch := 35.264
var zoom := 9.0
var _etapa := 1
var _centro := Vector3.ZERO   # donde está el pivote al empezar (R vuelve acá)
const FLECHAS_VEL := 110.0   # grados por segundo con las flechas


func _ready() -> void:
	Escena.register_globals()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.7)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	add_child(sun)
	fondo = FondoAnimado.new(env)
	add_child(fondo)
	_poner_fondo(1)
	# las filas: cada tipo, corrupto y purificado; las columnas: los cinco niveles
	var fila := 0
	for tipo in TIPOS:
		for estado in [Art.Estado.CORRUPTO, Art.Estado.PURIFICADO]:
			for nivel in Art.NIVELES:
				if tipo == "portal":   # (con las ondas animadas arriba)
					var cubo := Escena.cubo_portal(nivel)
					cubo.position = _celda(nivel, fila)
					add_child(cubo)
					continue
				var m := MeshInstance3D.new()
				m.mesh = Art.malla_bloque(tipo, estado, nivel, 1 + nivel)
				m.material_override = Escena.material_translucido(tipo) if Art.es_translucido(tipo) else Escena.material(Color.WHITE, false)
				m.position = _celda(nivel, fila)
				add_child(m)
				if Art.es_translucido(tipo):   # (las caras de atrás, en otra malla que se dibuja antes)
					var atras := MeshInstance3D.new()
					atras.mesh = m.mesh
					atras.material_override = Escena.material_translucido(tipo, true)
					atras.position = m.position
					add_child(atras)
			_rotulo("%s · %s" % [TIPOS[tipo], "corrupto" if estado == Art.Estado.CORRUPTO else "purificado"], _celda(-0.55, fila) + Vector3(-0.6, 0.0, 0.6))
			fila += 1
	for nivel in Art.NIVELES:
		_rotulo("Etapas %d a %d" % [nivel * 3 + 1, nivel * 3 + 3], _celda(nivel, -0.8) + Vector3(0.0, 0.3, 0.0))
	pivot = Node3D.new()
	pivot.position = _celda((Art.NIVELES - 1) * 0.5, (fila - 1) * 0.5)
	_centro = pivot.position
	add_child(pivot)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.far = 200.0
	pivot.add_child(cam)
	_poner_camara()
	cam.make_current()


## Dónde va el bloque de la columna `col` (un nivel de corrupción) y la fila `fila`: las columnas van de izquierda a derecha de la pantalla y las filas, hacia abajo, vistas desde la cámara de siempre.
func _celda(col: float, fila: float) -> Vector3:
	return Vector3(0.5, 0.5, 0.5) + Vector3(1.0, 0.0, -1.0) * (col * 1.15) + Vector3(1.0, 0.0, 1.0) * (fila * 1.75)


func _rotulo(texto: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = texto
	l.pixel_size = 0.0035
	l.font_size = 48
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = Color(1, 1, 1, 0.9)
	l.outline_size = 8
	l.position = pos
	add_child(l)


## El fondo de la etapa dada, como en el juego (de un violeta medio a uno oscuro).
func _poner_fondo(etapa: int) -> void:
	_etapa = etapa
	var tono := clampf(float(etapa - 1) / 14.0, 0.0, 1.0)
	env.background_color = Main.BG_DARK.lerp(Main.BG_LIGHT, smoothstep(0.0, 0.43, tono))


func _process(delta: float) -> void:
	var ax := int(Input.is_physical_key_pressed(KEY_RIGHT)) - int(Input.is_physical_key_pressed(KEY_LEFT))
	var ay := int(Input.is_physical_key_pressed(KEY_DOWN)) - int(Input.is_physical_key_pressed(KEY_UP))
	var az := int(Input.is_physical_key_pressed(KEY_EQUAL) or Input.is_physical_key_pressed(KEY_KP_ADD)) - int(Input.is_physical_key_pressed(KEY_MINUS) or Input.is_physical_key_pressed(KEY_KP_SUBTRACT))
	var mx := int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A))
	var mz := int(Input.is_physical_key_pressed(KEY_W)) - int(Input.is_physical_key_pressed(KEY_S))
	var my := int(Input.is_physical_key_pressed(KEY_SPACE)) - int(Input.is_physical_key_pressed(KEY_CTRL))
	if mx != 0 or mz != 0 or my != 0:   # (WASD: se mueve el pivote por el espacio, según hacia dónde mira la cámara; más rápido cuanto más lejos está la cámara)
		var adelante := -pivot.global_transform.basis.z
		adelante.y = 0.0
		adelante = adelante.normalized() if adelante.length() > 0.001 else Vector3(0, 0, -1)
		var derecha := pivot.global_transform.basis.x
		derecha.y = 0.0
		derecha = derecha.normalized()
		var vel := zoom * 0.35 * (3.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
		pivot.position += (derecha * mx + adelante * mz + Vector3.UP * my) * vel * delta
	if ax != 0 or ay != 0 or az != 0:
		yaw -= ax * FLECHAS_VEL * delta
		pitch = clampf(pitch + ay * FLECHAS_VEL * 0.7 * delta, -80.0, 85.0)
		zoom = clampf(zoom * pow(0.6, az * delta), 2.0, 30.0)
		_poner_camara()


func _poner_camara() -> void:
	pivot.rotation_degrees = Vector3(-pitch, yaw, 0)
	cam.position = Vector3(0, 0, 30)
	cam.size = zoom


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and (ev.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)) != 0:
		yaw -= ev.relative.x * 0.3
		pitch = clampf(pitch + ev.relative.y * 0.3, -80.0, 85.0)
		_poner_camara()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = maxf(zoom / 1.1, 2.0)
			_poner_camara()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = minf(zoom * 1.1, 30.0)
			_poner_camara()
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = (ev as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_5:
			_poner_fondo(ETAPAS[k - KEY_1])
		elif k == KEY_Q:
			yaw += 45.0
			_poner_camara()
		elif k == KEY_E:
			yaw -= 45.0
			_poner_camara()
		elif k == KEY_F:
			fondo.visible = not fondo.visible
			env.background_mode = Environment.BG_CANVAS if fondo.visible else Environment.BG_COLOR
		elif k == KEY_R:
			pivot.position = _centro
			yaw = 45.0
			pitch = 35.264
			zoom = 9.0
			_poner_camara()
		elif k == KEY_ESCAPE:
			get_tree().quit()
