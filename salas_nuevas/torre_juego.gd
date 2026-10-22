extends Node3D
## Prototipo jugable de la torre de salas sin núcleo (aislado del juego actual). Arma una torre de salas del paquete (salas_nuevas/torre.gd) y se juega
## desde atrás del personaje.
## Teclas: flechas o WASD mueven (relativas a la cámara), Shift + dirección agarra (empuja o tira), Espacio + dirección se cuelga, R arma otra torre, Esc sale.
## Variables de entorno: SN_PAQUETE (archivo .jsonl, por defecto bibliotecas/paquete_salas.jsonl), SN_SEMILLA (para repetir una torre), SN_SALAS (cuántas salas).

const Torre := preload("res://salas_nuevas/torre.gd")
const Vista := preload("res://salas_nuevas/vista.gd")
const Motor := preload("res://salas_nuevas/motor.gd")
const RoomView := preload("res://scripts/room_view.gd")

var t                     # la Torre
var paquete: Array = []
var semilla := 0
var cam: Camera3D
var estaticas: Array = []   # una por sala: la sala dibujada tal como empieza (decorado; la actual se dibuja viva aparte)
var vivo: Node3D            # la sala actual, dibujada con su estado
var texto_hud: Label
var texto_aviso: Label
var _aviso_id := 0
var panorama := false      # V: se ve la torre entera desde afuera


func _ready() -> void:
	RoomView.register_globals()
	RoomView.add_lighting(self)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
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
		Vista.poblar(nodo, Vista.motor_de(t.salas[i].d), {}, false, false, true)
		estaticas.append(nodo)
	_refrescar()
	_aviso("Torre %d: %d salas, %d pisos" % [semilla, t.salas.size(), t.total_pisos()], 3.0)


func _refrescar() -> void:
	for i in estaticas.size():
		var n = estaticas[i]
		if n == null or not is_instance_valid(n):
			continue
		n.visible = i > t.indice   # la actual se dibuja viva; las de abajo ya cayeron
	vivo.position = Vector3(0, int(t.sala_actual().off), 0)
	Vista.poblar(vivo, t.motor, t.encendidos, true)
	if panorama:
		var alto := float(t.total_pisos())
		var centro := Vector3(5.5, alto * 0.5, 5.5)
		cam.look_at_from_position(centro + Vector3(0, 0.0, 1.0) * (alto * 1.25 + 8.0) + Vector3(0, alto * 0.1, 0), centro, Vector3.UP)
		for i in estaticas.size():
			if estaticas[i] != null and is_instance_valid(estaticas[i]):
				estaticas[i].visible = i >= t.indice
	else:
		Vista.camara_detras(cam, t.motor, 6.8, 3.2, 1.8)
		cam.global_translate(Vector3(0, int(t.sala_actual().off), 0))
	texto_hud.text = "Sala %d de %d   ·   Movimientos %d / %d   ·   Vidas %d" % [t.indice + 1, t.salas.size(), t.movs, t.max_mov(), t.vidas]


func _aviso(msg: String, segundos := 2.2) -> void:
	_aviso_id += 1
	var mi_id := _aviso_id
	texto_aviso.text = msg
	if segundos <= 0.0:
		return
	await get_tree().create_timer(segundos).timeout
	if mi_id == _aviso_id:
		texto_aviso.text = ""


## El eje horizontal hacia donde mira la cámara (para que las flechas sean relativas a ella).
func _adelante_camara() -> Vector3i:
	var v := -cam.global_transform.basis.z
	v.y = 0.0
	if v.length() < 0.01:
		return Vector3i(0, 0, -1)
	if absf(v.x) > absf(v.z):
		return Vector3i(int(signf(v.x)), 0, 0)
	return Vector3i(0, 0, int(signf(v.z)))


func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	var k: int = (ev as InputEventKey).keycode
	if k == KEY_ESCAPE:
		get_tree().quit()
		return
	if k == KEY_V:
		panorama = not panorama
		_refrescar()
		return
	if k == KEY_R:
		semilla = (semilla * 7 + 13) % 1000000
		_nueva_torre()
		return
	if t == null or t.salas.is_empty():
		return
	var f := _adelante_camara()
	var der := Vector3i(-f.z, 0, f.x)
	var dir := Vector3i.ZERO
	match k:
		KEY_UP, KEY_W:
			dir = f
		KEY_DOWN, KEY_S:
			dir = -f
		KEY_LEFT, KEY_A:
			dir = -der
		KEY_RIGHT, KEY_D:
			dir = der
	if dir == Vector3i.ZERO:
		return
	var modo := Motor.Modo.MOVER
	if Input.is_key_pressed(KEY_SHIFT):
		modo = Motor.Modo.AGARRAR
	elif Input.is_key_pressed(KEY_SPACE):
		modo = Motor.Modo.COLGAR
	accion(dir, modo)


## Una acción del jugador (también la usan las pruebas).
func accion(dir: Vector3i, modo: int) -> Dictionary:
	var r: Dictionary = t.actuar(dir, modo)
	if not r.ok:
		_aviso(str(r.msg), 1.4)
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
	_refrescar()
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
