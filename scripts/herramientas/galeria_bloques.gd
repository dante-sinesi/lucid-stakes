extends Node3D
## Galería de bloques (herramienta de desarrollo): el arte de 10 x 10 x 10 de cada tipo de bloque (block_art.gd), corrupto y purificado (Farolín espera sentado sobre el checkpoint y el portal corruptos), en los cinco niveles de corrupción
## (una columna por cada tres etapas), con la luz del juego. Mouse: arrastrar con el botón izquierdo o derecho gira e inclina; rueda acerca. Teclas: las flechas giran e inclinan
## la cámara (izquierda y derecha giran, arriba y abajo inclinan; se mantienen apretadas), WASD mueven la cámara por el espacio (con Shift, más rápido; con Espacio sube y con Ctrl baja),
## + y - acercan y alejan, Q y E giran 45°, T hace que Farolín salte y encienda el farolito (la última fila lleva además a Ama esperando junto a él, en las poses de las fotos),
## 1 a 5 ponen el fondo de esa etapa (para ver el contraste), F alterna el remolino del fondo, R vuelve la cámara, Esc sale.
## Abrir: herramientas\galeria_bloques.bat (o `godot --path . res://scenes/galeria_bloques.tscn`).

const Escena := preload("res://torre/escena.gd")
const Art := preload("res://scripts/personajes/block_art.gd")
const Farolin := preload("res://scripts/personajes/farolin.gd")
const Main := preload("res://scripts/main.gd")
const FondoAnimado := preload("res://scripts/ui/fondo_animado.gd")
const RotuloPixel := preload("res://scripts/ui/rotulo_pixel.gd")
const GatitoTravieso := preload("res://scripts/personajes/gatito_travieso.gd")
const GatitoAnim := preload("res://scripts/personajes/gatito_anim.gd")

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
var _farolines: Array[Dictionary] = []   # los Farolín de la galería: {nodo, punto, soplar}
var _amas: Array[Dictionary] = []   # las Ama de la última fila: {modelo, pose}
var _t := 0.0
var _centro := Vector3.ZERO   # donde está el pivote al empezar (R vuelve acá)
const FLECHAS_VEL := 110.0   # grados por segundo con las flechas


## Farolín sentado en una esquina de la cara de arriba del bloque (como espera en el checkpoint y en el bloque de salida): sólo con los bloques corruptos, porque al purificarse se va.
func _poner_farolin(centro: Vector3, soplar := false) -> Node3D:
	var esq := Vector2(-1.0, -1.0)
	var ang := atan2(-esq.x, -esq.y)   # (de la esquina hacia el centro del bloque)
	var pos := centro + Vector3(0.27 * esq.x, 0.5, 0.27 * esq.y)
	var base := Node3D.new()
	base.position = pos
	base.rotation = Vector3(deg_to_rad(-10.0), ang, 0.0)   # (apenas echado hacia atrás, contra el tronco)
	add_child(base)
	var faro := Farolin.build(-1, true)
	base.add_child(faro)
	_farolines.append({"nodo": faro, "punto": centro + Vector3(0.0, 0.5, 0.0), "soplar": soplar})
	var tronco := Farolin.tronco()
	tronco.position = Vector3(0.0, 0.065, -0.17)   # (detrás de Farolín, atravesado)
	base.add_child(tronco)
	return faro


## Ama sentada en el bloque, del otro lado de Farolín y mirándolo (como espera en el checkpoint), en la pose de espera `pose` (una de `GatitoAnim.ESPERAS`) y, con `pegada`, acurrucada contra él.
func _poner_ama(centro: Vector3, pose: String, pegada := false) -> Node3D:
	var esq := Vector2(-1.0, -1.0)
	var modelo := GatitoTravieso.build()
	var dist := 0.08 if pegada else 0.17   # (del centro hacia el lado de Farolín: -esq apunta hacia él)
	var nodo := Node3D.new()
	nodo.position = centro + Vector3(-dist * esq.x, 0.5, -dist * esq.y)
	nodo.rotation.y = atan2(esq.x, esq.y)   # (mirando a Farolín)
	nodo.add_child(modelo)
	add_child(nodo)
	GatitoAnim.aplicar(modelo, GatitoAnim.pose(pose))
	_amas.append({"modelo": modelo, "pose": pose})
	return modelo


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
					if estado == Art.Estado.CORRUPTO:
						_poner_farolin(_celda(nivel, fila), true)
					continue
				var m := MeshInstance3D.new()
				m.mesh = Art.malla_bloque(tipo, estado, nivel, 1 + nivel)
				m.material_override = Escena.material_translucido(tipo) if Art.es_translucido(tipo) else Escena.material(Color.WHITE, false)
				m.position = _celda(nivel, fila)
				add_child(m)
				if tipo == "checkpoint" and estado == Art.Estado.CORRUPTO:
					_poner_farolin(m.position)
				if Art.es_translucido(tipo):   # (las caras de atrás, en otra malla que se dibuja antes)
					var atras := MeshInstance3D.new()
					atras.mesh = m.mesh
					atras.material_override = Escena.material_translucido(tipo, true)
					atras.position = m.position
					add_child(atras)
			_rotulo("%s · %s" % [TIPOS[tipo], "corrupto" if estado == Art.Estado.CORRUPTO else "purificado"], _celda(-0.55, fila) + Vector3(-0.6, 0.0, 0.6))
			fila += 1
	# la última fila: el checkpoint con Farolín y Ama esperando, de la más despierta a la más dormida (las cuatro poses de las fotos); la última, con el sombrero de Farolín puesto
	var poses := GatitoAnim.ESPERAS.duplicate()
	poses.append("sombrero")
	for nivel in Art.NIVELES:
		var bloque := MeshInstance3D.new()
		bloque.mesh = Art.malla_bloque("checkpoint", Art.Estado.CORRUPTO, nivel, 1 + nivel)
		bloque.material_override = Escena.material(Color.WHITE, false)
		bloque.position = _celda(nivel, fila)
		add_child(bloque)
		var faro := _poner_farolin(bloque.position)
		var pose: String = poses[nivel]
		var ama := _poner_ama(bloque.position, "sentada" if pose == "sombrero" else pose, pose == "bollito")
		if pose == "sombrero":   # (la travesura: Ama se llevó el sombrero de Farolín)
			faro.sombrero.reparent(ama.get_node("cabeza"), false)
			faro.sombrero.position = Vector3(0, 0.12, 0.05)
			faro.sombrero.scale = Vector3.ONE * 0.65
	_rotulo("Checkpoint · con Farolín y Ama", _celda(-0.55, fila) + Vector3(-0.6, 0.0, 0.6))
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
	var l := RotuloPixel.crear(texto, Color(1, 1, 1, 0.9), false, 0.014)   # (con la fuente de cubitos del juego)
	l.no_depth_test = true
	l.position = pos
	add_child(l)


## El fondo de la etapa dada, como en el juego (de un violeta medio a uno oscuro).
func _poner_fondo(etapa: int) -> void:
	_etapa = etapa
	var tono := clampf(float(etapa - 1) / 14.0, 0.0, 1.0)
	env.background_color = Main.BG_DARK.lerp(Main.BG_LIGHT, smoothstep(0.0, 0.43, tono))


func _process(delta: float) -> void:
	_t += delta
	for a in _amas:   # (Ama mueve la cola, las orejas y parpadea según su pose)
		GatitoAnim.esperar(a.modelo, a.pose, _t)
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
		elif k == KEY_T:   # Farolín salta y enciende el farolito (el checkpoint) o sopla (el portal)
			for f in _farolines:
				(f.nodo as Node3D).celebrar(f.punto, f.soplar)
		elif k == KEY_R:
			pivot.position = _centro
			yaw = 45.0
			pitch = 35.264
			zoom = 9.0
			_poner_camara()
		elif k == KEY_ESCAPE:
			get_tree().quit()
