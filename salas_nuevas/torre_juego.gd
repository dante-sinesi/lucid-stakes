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
const Controls := preload("res://scripts/controls.gd")
const Falsos := preload("res://salas_nuevas/falsos.gd")   # (las teclas y el mando del juego, con sus reasignaciones: el mando entra como teclas, ver pad_bridge.gd)

const PITCH := -35.264        # ángulo isométrico (el del juego)
const PITCH_MIN := -86.0
const PITCH_MAX := 80.0
const MOUSE_SENS := 0.28      # grados por píxel
const ARROW_SPEED := 110.0    # grados por segundo con las flechas
const ZOOM_FACTOR := 1.1
const TOP_VIEW_PITCH := -52.0 # desde este ángulo (mirando desde arriba) se ocultan las salas de arriba, que taparían al personaje
const STEP_TIME := 0.14

## Cuando la torre se juega dentro del juego (scripts/main.gd): el juego pasa el paquete, la semilla, la etapa y los boosts antes de agregarla, y escucha estas señales.
signal checkpoint_alcanzado          ## se llegó a la salida de una sala (la anterior cae)
signal torre_completa                ## se llegó al portal
signal murio(motivo: String)         ## se perdió una vida (el juego descuenta la del run); la sala ya volvió a empezar
signal accion_hecha                  ## después de cada acción que salió bien (el juego actualiza su HUD)
signal falsos_cambiaron(quedan: int, permitidos: int, sin_salida: bool, hubo_falso: bool)   ## Sin piedad: lo que quedan de movimientos en falso en la sala
signal deshacer_pedido               ## se apretó deshacer (el juego decide si se puede en este escenario)
signal reintentar_pedido             ## se apretó reintentar la torre
signal aviso(texto: String)          ## algo para mostrar en el cartel del juego (Segundo aliento, etc.)

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
var en_juego := false      # se juega dentro del juego (main.gd): vidas, claridad y boosts son los del run
var etapa := 0
var n_salas_fijo := 0         # >0: cuántas salas tiene la torre (el tutorial); si no, las que le tocan a la etapa
var boosts: Array = []
var vidas_fn := Callable()   # () -> int: las vidas del run
var puede_jugar := Callable()   # () -> bool: false mientras hay un menú, un diálogo o una pausa
var falsos_permitidos := 0     # Sin piedad: movimientos en falso que permite cada sala (0 = el escenario no los usa)
var falsos = null              # el medidor (falsos.gd)
var contador: Label3D          # los movimientos que quedan, sobre el personaje, cuando son pocos (no hay texto de depuración en el HUD)


func _ready() -> void:
	RoomView.register_globals()
	if not en_juego:
		RoomView.add_lighting(self)   # (dentro del juego se usa su luz)
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
	contador = Label3D.new()
	contador.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	contador.no_depth_test = true
	contador.font_size = 96
	contador.pixel_size = 0.012
	contador.outline_size = 14
	contador.position = Vector3(0, 1.45, 0)
	contador.visible = false
	gato_nodo.add_child(contador)
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
	if en_juego:
		if paquete.is_empty():
			paquete = Torre.cargar_paquete_del_juego()
		_nueva_torre()
		if falsos_permitidos > 0 and t != null:
			falsos = Falsos.new()
			falsos.configurar(falsos_permitidos)
			falsos.falso.connect(func(cuenta: int, perm: int, sin_salida: bool): falsos_cambiaron.emit(falsos.quedan(), perm, sin_salida, true))
			falsos.agotado.connect(_falsos_agotados)
			falsos.sala_nueva(t.motor)
			falsos_cambiaron.emit(falsos.quedan(), falsos_permitidos, false, false)
		return
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
	if en_juego:
		t = Torre.armar(paquete, semilla, n_salas_fijo if n_salas_fijo > 0 else Torre.salas_de_etapa(etapa), true, etapa)
		t.externo = true
		t.aplicar_boosts(boosts)
	else:
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
	if not en_juego:
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
	_poner_contador()
	texto_hud.visible = not en_juego   # (dentro del juego no hay texto de depuración: el HUD es el del juego)
	texto_hud.text = "Sala %d de %d   ·   Movimientos %d / %d   ·   Vidas %d   ·   Claridad %d%s" % [t.indice + 1, t.salas.size(), t.movs, t.max_mov(), (int(vidas_fn.call()) if vidas_fn.is_valid() else t.vidas), t.cosecha.claridad(), ("  (racha ×%.1f)" % t.cosecha.streak_mult(t.cosecha.streak)) if t.cosecha.streak > 1 else ""]


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


## Los últimos 5 movimientos de la sala se ven como un número sobre el personaje (rojo cuando quedan 3 o menos).
func _poner_contador() -> void:
	if contador == null or t == null:
		return
	var quedan: int = t.max_mov() - t.movs
	contador.visible = quedan <= 5 and quedan > 0
	contador.text = str(quedan)
	contador.modulate = Color(1.0, 0.25, 0.2) if quedan <= 3 else Color(1.0, 0.85, 0.3)


func _aviso(msg: String, segundos := 2.2) -> void:
	if en_juego:   # (dentro del juego los avisos salen por el cartel del juego, no por un texto propio)
		aviso.emit(msg)
		return
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
	if en_juego and puede_jugar.is_valid() and not puede_jugar.call():
		return
	var ax := int(Controls.held("camara_derecha")) - int(Controls.held("camara_izquierda"))
	var ay := int(Controls.held("camara_abajo")) - int(Controls.held("camara_arriba"))
	if ax != 0 or ay != 0:
		orbitar(Vector2(ax, ay) * ARROW_SPEED * delta / MOUSE_SENS)


func _input(ev: InputEvent) -> void:
	if en_juego and puede_jugar.is_valid() and not puede_jugar.call():
		return
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
	var accion_id := Controls.action_of(ev)
	if ev.echo and accion_id != "zoom_mas" and accion_id != "zoom_menos":
		return
	var k: int = (ev as InputEventKey).keycode
	if k == KEY_ESCAPE and not en_juego:   # (dentro del juego Esc abre la pausa del juego)
		get_tree().quit()
		return
	if k == KEY_V:
		panorama = not panorama
		_refrescar(true)
		return
	if accion_id == "reintentar":
		if en_juego:
			reintentar_pedido.emit()
		else:
			semilla = (semilla * 7 + 13) % 1000000
			_nueva_torre()
		return
	if accion_id == "deshacer":
		if en_juego:
			deshacer_pedido.emit()
		else:
			deshacer()
		return
	if accion_id == "vista_izquierda" or accion_id == "vista_derecha":   # (vuelve al ángulo isométrico y gira 90° desde la diagonal más cercana)
		var base := roundf((yaw_target - 45.0) / 90.0) * 90.0 + 45.0
		yaw_target = base + (90.0 if accion_id == "vista_izquierda" else -90.0)
		cam_pitch = PITCH
		_poner_camara(true)
		_ocultar_arriba()
		return
	if accion_id == "zoom_mas" or accion_id == "zoom_menos":
		acercar(1.0 / ZOOM_FACTOR if accion_id == "zoom_mas" else ZOOM_FACTOR)
		return
	if t == null or t.salas.is_empty():
		return
	var sx := 0
	var sy := 0
	match accion_id:
		"mover_adelante":
			sx = 1; sy = 1
		"mover_derecha":
			sx = 1; sy = -1
		"mover_atras":
			sx = -1; sy = -1
		"mover_izquierda":
			sx = -1; sy = 1
		"colgarse":
			if t.motor.colgado != Vector3i.ZERO:   # estando colgado, la tecla de colgarse te suelta
				accion(-t.motor.colgado, Motor.Modo.COLGAR)
			return
	if sx == 0:
		return
	var d2 := KeyDirs.dir_for(yaw_target, float(sx), float(sy))   # (W es la dirección que más sube en pantalla)
	var dir := Vector3i(d2.x, 0, d2.y)
	var modo := Motor.Modo.MOVER
	if Controls.modifier_held(ev, "empujar"):
		modo = Motor.Modo.AGARRAR
	elif Controls.held("colgarse"):
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
	_procesar(r)
	if falsos != null:
		var ev := str(r.evento)
		if ev == "":
			falsos.despues_de_mover(t.motor)
		elif ev == "checkpoint" or ev == "muerte" or ev == "aliento":
			falsos.sala_nueva(t.motor)
			falsos_cambiaron.emit(falsos.quedan(), falsos_permitidos, false, false)
		elif ev == "torre":
			falsos.apagar()
	return r


## Lo que pasó con una acción (también el último movimiento en falso): avisos, señales y volver a dibujar.
func _procesar(r: Dictionary) -> void:
	match str(r.evento):
		"checkpoint":
			_caer_sala(t.ultima_caida)
			_aviso("¡Checkpoint!", 1.8)
			checkpoint_alcanzado.emit()
		"torre":
			if en_juego:
				torre_completa.emit()
			else:
				_aviso("¡Llegaste al portal! Pulsa R para otra torre.", 0.0)
		"muerte":
			if en_juego:
				_aviso("%s. Pierdes una vida." % str(r.msg), 3.0)
				murio.emit(str(r.msg))
			else:
				_aviso("%s. Pierdes una vida (te quedan %d)." % [str(r.msg), t.vidas], 3.0)
		"aliento":
			_aviso("Segundo aliento: la sala vuelve a empezar y no pierdes la vida.", 3.0)
		"fin":
			_aviso("%s. Te quedaste sin vidas. Pulsa R para otra torre." % str(r.msg), 0.0)
	_refrescar(str(r.evento) == "")   # (tras un checkpoint o una muerte el personaje aparece de golpe en su sitio)
	accion_hecha.emit()


## Sin piedad: se pasó del último movimiento en falso de la sala: se pierde como si se hubiera caído.
func _falsos_agotados() -> void:
	if t == null or t.terminada or t.perdida:
		return
	var r: Dictionary = t.forzar_muerte("Tercer movimiento en falso")
	_procesar(r)
	if falsos != null:
		falsos.sala_nueva(t.motor)
		falsos_cambiaron.emit(falsos.quedan(), falsos_permitidos, false, false)


## Vuelve a dibujar la sala actual (por ejemplo después de usar un consumible).
func actualizar() -> void:
	_refrescar(false)


## Deshace el último movimiento de la sala actual. true si había algo que deshacer.
func deshacer() -> bool:
	if t == null or not t.deshacer():
		return false
	if falsos != null:
		falsos.medir(t.motor)   # (después de deshacer se mide de nuevo sin contar)
	_refrescar(false)
	accion_hecha.emit()
	return true


## La sala anterior cae por el checkpoint: se la ve hundirse y desaparece.
func _exit_tree() -> void:
	if falsos != null:
		falsos.cerrar()


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
