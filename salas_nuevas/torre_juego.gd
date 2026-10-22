extends Node3D
## Prototipo jugable de la torre de salas sin núcleo (aislado del juego actual). Arma una torre de salas del paquete (salas_nuevas/torre.gd) y se juega
## desde atrás del personaje.
## Se ve como en el juego: cámara isométrica ortogonal que sigue al personaje (por defecto el gatito) y se puede girar.
## Teclas: WASD mueve (W es la dirección que más sube en la pantalla), Shift + dirección agarra (empuja o tira), Espacio + dirección se cuelga.
## Cámara (como en el juego): arrastrar con el mouse gira e inclina, la rueda acerca y aleja, las flechas giran e inclinan, Q / E vuelven al ángulo isométrico y giran 90°,
## + / - el zoom, V alterna la vista de toda la torre. R arma otra torre, Esc sale.
## Variables de entorno: SN_PAQUETE (archivo .jsonl, por defecto bibliotecas/paquete_salas.jsonl), SN_SEMILLA (para repetir una torre), SN_SALAS (cuántas salas),
## SN_PERSONAJE (gato, perro, conejo, dante o gaby).

const Torre := preload("res://salas_nuevas/torre.gd")
const Vista := preload("res://salas_nuevas/vista.gd")
const Motor := preload("res://salas_nuevas/motor.gd")
const RoomView := preload("res://scripts/room_view.gd")
const Characters := preload("res://scripts/characters.gd")
const KeyDirs := preload("res://scripts/key_dirs.gd")

const PITCH := -35.264        # ángulo isométrico (el del juego)
const PITCH_MIN := -86.0
const PITCH_MAX := 80.0
const MOUSE_SENS := 0.28      # grados por píxel
const ARROW_SPEED := 110.0    # grados por segundo con las flechas
const ZOOM_FACTOR := 1.1
const TOP_VIEW_PITCH := -52.0 # desde este ángulo (mirando desde arriba) se ocultan las salas de arriba, que taparían al personaje
const STEP_TIME := 0.14

var t                     # la Torre
var paquete: Array = []
var semilla := 0
var cam: Camera3D
var pivot: Node3D            # la cámara cuelga de un pivote que gira (yaw) y sigue al personaje
var pitch_node: Node3D
var yaw_target := 45.0
var cam_pitch := PITCH
var zoom := 9.0
var gato: Node3D             # el personaje
var gato_nodo: Node3D        # su posición y orientación
var mira := Vector3i(0, 0, 1)
var _camara_tween: Tween
var _paso_tween: Tween
var estaticas: Array = []   # una por sala: la sala dibujada tal como empieza (decorado; la actual se dibuja viva aparte)
var vivo: Node3D            # la sala actual, dibujada con su estado
var texto_hud: Label
var texto_aviso: Label
var _aviso_id := 0
var panorama := false      # V: se ve la torre entera desde afuera


func _ready() -> void:
	RoomView.register_globals()
	RoomView.add_lighting(self)
	pivot = Node3D.new()
	pivot.rotation_degrees.y = yaw_target
	add_child(pivot)
	pitch_node = Node3D.new()
	pitch_node.rotation_degrees.x = cam_pitch
	pivot.add_child(pitch_node)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = zoom
	cam.far = 400.0
	cam.position = Vector3(0, 0, 60)
	pitch_node.add_child(cam)
	cam.make_current()
	gato_nodo = Node3D.new()
	add_child(gato_nodo)
	var personaje := OS.get_environment("SN_PERSONAJE")
	gato = Characters.build(personaje if personaje != "" else "gato")
	gato_nodo.add_child(gato)
	gato_nodo.add_child(Characters.build(personaje if personaje != "" else "gato", "", "", true))   # la silueta: sólo se dibuja donde algo lo tapa (como en el juego)
	vivo = Node3D.new()
	add_child(vivo)
	var capa := CanvasLayer.new()
	add_child(capa)
	texto_hud = Label.new()
	texto_hud.position = Vector2(18, 12)
	texto_hud.add_theme_font_size_override("font_size", 22)
	capa.add_child(texto_hud)
	texto_aviso = Label.new()
	texto_aviso.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	texto_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	texto_aviso.offset_top = -90
	texto_aviso.offset_bottom = -40
	texto_aviso.offset_left = -500
	texto_aviso.offset_right = 500
	texto_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_aviso.add_theme_font_size_override("font_size", 30)
	texto_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	texto_aviso.add_theme_constant_override("outline_size", 8)
	capa.add_child(texto_aviso)
	var ruta := OS.get_environment("SN_PAQUETE")
	if ruta == "":
		ruta = ProjectSettings.globalize_path("res://bibliotecas/paquete_salas.jsonl")
	paquete = Torre.cargar_paquete(ruta)
	if paquete.is_empty():
		_aviso("No se encontró el paquete de salas: " + ruta, 0.0)
		return
	var s := OS.get_environment("SN_SEMILLA")
	semilla = int(s) if s != "" else int(Time.get_unix_time_from_system()) % 1000000
	_nueva_torre()


func _nueva_torre() -> void:
	for n in estaticas:
		if n != null and is_instance_valid(n):
			n.queue_free()
	estaticas.clear()
	var n_salas := int(OS.get_environment("SN_SALAS")) if OS.get_environment("SN_SALAS") != "" else 8
	t = Torre.armar(paquete, semilla, n_salas)
	if t.salas.is_empty():
		_aviso("No se pudo armar la torre", 0.0)
		return
	for i in t.salas.size():
		var nodo := Node3D.new()
		add_child(nodo)
		nodo.position = Vector3(0, int(t.salas[i].off), 0)
		Vista.poblar(nodo, Vista.motor_de(t.salas[i].d), {}, false, false, true, true)
		estaticas.append(nodo)
	_refrescar()
	_aviso("Torre %d: %d salas, %d pisos" % [semilla, t.salas.size(), t.total_pisos()], 3.0)


func _refrescar(animar := false) -> void:
	for i in estaticas.size():
		var n = estaticas[i]
		if n == null or not is_instance_valid(n):
			continue
		n.visible = i > t.indice   # la actual se dibuja viva; las de abajo ya cayeron
	vivo.position = Vector3(0, int(t.sala_actual().off), 0)
	Vista.poblar(vivo, t.motor, t.encendidos, true, false, false, true)
	_poner_gato(animar)
	_poner_camara(animar)
	if panorama:
		for i in estaticas.size():
			if estaticas[i] != null and is_instance_valid(estaticas[i]):
				estaticas[i].visible = i >= t.indice
	else:
		_ocultar_arriba()
	texto_hud.text = "Sala %d de %d   ·   Movimientos %d / %d   ·   Vidas %d   ·   Claridad %d%s" % [t.indice + 1, t.salas.size(), t.movs, t.max_mov(), t.vidas, t.cosecha.claridad(), ("  (racha ×%.1f)" % t.cosecha.streak_mult(t.cosecha.streak)) if t.cosecha.streak > 1 else ""]


## Dónde están los pies del personaje (colgado, el cuerpo se arrima al bloque del que se agarra).
func _pos_gato() -> Vector3:
	var j: Vector3i = t.motor.jugador
	var off := float(int(t.sala_actual().off))
	return Vector3(j.x + 0.5, j.y + off, j.z + 0.5) + Vector3(t.motor.colgado) * 0.22


func _poner_gato(animar: bool) -> void:
	var destino := _pos_gato()
	if _paso_tween != null and _paso_tween.is_valid():
		_paso_tween.kill()
	if animar:
		_paso_tween = create_tween()
		_paso_tween.tween_property(gato_nodo, "position", destino, STEP_TIME)
		Characters.step_anim(gato, STEP_TIME)
	else:
		gato_nodo.position = destino
	var cara: Vector3i = t.motor.colgado if t.motor.colgado != Vector3i.ZERO else mira
	gato_nodo.rotation.y = atan2(cara.x, cara.z)


func _poner_camara(animar: bool) -> void:
	var foco := _pos_gato() + Vector3(0, 0.5, 0)
	var tam := zoom
	if panorama:
		var alto := float(t.total_pisos())
		foco = Vector3(5.5, alto * 0.5, 5.5)
		tam = maxf(alto * 0.75, 24.0)
	if _camara_tween != null and _camara_tween.is_valid():
		_camara_tween.kill()
	if animar:
		_camara_tween = create_tween().set_parallel(true)
		_camara_tween.tween_property(pivot, "position", foco, 0.25).set_trans(Tween.TRANS_SINE)
		_camara_tween.tween_property(pivot, "rotation_degrees:y", yaw_target, 0.25).set_trans(Tween.TRANS_SINE)
		_camara_tween.tween_property(pitch_node, "rotation_degrees:x", cam_pitch, 0.25).set_trans(Tween.TRANS_SINE)
		_camara_tween.tween_property(cam, "size", tam, 0.25).set_trans(Tween.TRANS_SINE)
	else:
		pivot.position = foco
		pivot.rotation_degrees.y = yaw_target
		pitch_node.rotation_degrees.x = cam_pitch
		cam.size = tam


func _aviso(msg: String, segundos := 2.2) -> void:
	_aviso_id += 1
	var mi_id := _aviso_id
	texto_aviso.text = msg
	if segundos <= 0.0:
		return
	await get_tree().create_timer(segundos).timeout
	if mi_id == _aviso_id:
		texto_aviso.text = ""


## Gira (x) e inclina (y) la cámara según un desplazamiento en píxeles del mouse (o las flechas).
func orbitar(rel: Vector2) -> void:
	yaw_target -= rel.x * MOUSE_SENS
	cam_pitch = clampf(cam_pitch - rel.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)
	if _camara_tween != null and _camara_tween.is_valid():
		_camara_tween.kill()
	pivot.rotation_degrees.y = yaw_target
	pitch_node.rotation_degrees.x = cam_pitch
	_ocultar_arriba()


func acercar(factor: float) -> void:
	zoom = clampf(zoom * factor, 6.0, 36.0)
	if not panorama:
		cam.size = zoom


## Mirando desde arriba, las salas que están sobre el personaje lo taparían: se ocultan.
func _ocultar_arriba() -> void:
	var desde_arriba := cam_pitch <= TOP_VIEW_PITCH and not panorama
	for i in estaticas.size():
		var n = estaticas[i]
		if n != null and is_instance_valid(n):
			n.visible = i > t.indice and not desde_arriba


func _process(delta: float) -> void:
	if t == null or pivot == null:
		return
	var ax := int(Input.is_key_pressed(KEY_RIGHT)) - int(Input.is_key_pressed(KEY_LEFT))
	var ay := int(Input.is_key_pressed(KEY_DOWN)) - int(Input.is_key_pressed(KEY_UP))
	if ax != 0 or ay != 0:
		orbitar(Vector2(ax, ay) * ARROW_SPEED * delta / MOUSE_SENS)


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			acercar(1.0 / ZOOM_FACTOR)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			acercar(ZOOM_FACTOR)
		return
	if ev is InputEventMouseMotion:
		if (ev.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)) != 0 and pivot != null:
			orbitar(ev.relative)
		return
	if not (ev is InputEventKey) or not ev.pressed:
		return
	var k: int = (ev as InputEventKey).keycode
	if ev.echo and k != KEY_EQUAL and k != KEY_MINUS and k != KEY_KP_ADD and k != KEY_KP_SUBTRACT:
		return
	if k == KEY_ESCAPE:
		get_tree().quit()
		return
	if k == KEY_V:
		panorama = not panorama
		_refrescar(true)
		return
	if k == KEY_R:
		semilla = (semilla * 7 + 13) % 1000000
		_nueva_torre()
		return
	if k == KEY_Q or k == KEY_E:   # (como en el juego: vuelve al ángulo isométrico y gira 90° desde la diagonal más cercana)
		var base := roundf((yaw_target - 45.0) / 90.0) * 90.0 + 45.0
		yaw_target = base + (90.0 if k == KEY_Q else -90.0)
		cam_pitch = PITCH
		_poner_camara(true)
		_ocultar_arriba()
		return
	if k == KEY_EQUAL or k == KEY_PLUS or k == KEY_KP_ADD or k == KEY_MINUS or k == KEY_KP_SUBTRACT:
		acercar(0.9 if k == KEY_EQUAL or k == KEY_PLUS or k == KEY_KP_ADD else 1.1)
		return
	if t == null or t.salas.is_empty():
		return
	var sx := 0
	var sy := 0
	match k:
		KEY_W:
			sx = 1; sy = 1
		KEY_D:
			sx = 1; sy = -1
		KEY_S:
			sx = -1; sy = -1
		KEY_A:
			sx = -1; sy = 1
	if sx == 0:
		return
	var d2 := KeyDirs.dir_for(yaw_target, float(sx), float(sy))   # (W es la dirección que más sube en pantalla)
	var dir := Vector3i(d2.x, 0, d2.y)
	var modo := Motor.Modo.MOVER
	if Input.is_key_pressed(KEY_SHIFT):
		modo = Motor.Modo.AGARRAR
	elif Input.is_key_pressed(KEY_SPACE):
		modo = Motor.Modo.COLGAR
	accion(dir, modo)


## Una acción del jugador (también la usan las pruebas).
func accion(dir: Vector3i, modo: int) -> Dictionary:
	var r: Dictionary = t.actuar(dir, modo)
	mira = dir
	if not r.ok:
		_aviso(str(r.msg), 1.4)
		_poner_gato(false)   # (aunque no se mueva, gira hacia donde se lo intentó llevar)
		return r
	match str(r.evento):
		"checkpoint":
			_caer_sala(t.ultima_caida)
			_aviso("¡Checkpoint!", 1.8)
		"torre":
			_aviso("¡Llegaste al portal! Pulsa R para otra torre.", 0.0)
		"muerte":
			_aviso("%s. Pierdes una vida (te quedan %d)." % [str(r.msg), t.vidas], 3.0)
		"fin":
			_aviso("%s. Te quedaste sin vidas. Pulsa R para otra torre." % str(r.msg), 0.0)
	_refrescar(str(r.evento) == "")   # (tras un checkpoint o una muerte el personaje aparece de golpe en su sitio)
	return r


## La sala anterior cae por el checkpoint: se la ve hundirse y desaparece.
func _caer_sala(i: int) -> void:
	if i < 0 or i >= estaticas.size():
		return
	var n = estaticas[i]
	if n == null or not is_instance_valid(n):
		return
	n.visible = true
	var tw := create_tween()
	tw.tween_property(n, "position:y", n.position.y - 40.0, 1.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)
	estaticas[i] = null
