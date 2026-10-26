extends Node3D
## Prototipo jugable de la torre (aislado del juego actual). Arma una torre de salas del paquete (torre/torre.gd) y se juega
## desde atrás del personaje.
## Se ve como en el juego: cámara isométrica ortogonal que sigue al personaje (por defecto el gatito) y se puede girar.
## Teclas: WASD mueve (W es la dirección que más sube en la pantalla), Shift + dirección agarra (empuja o tira), Espacio + dirección se cuelga.
## Cámara (como en el juego): arrastrar con el mouse gira e inclina, la rueda acerca y aleja, las flechas giran e inclinan, Q / E vuelven al ángulo isométrico y giran 90°,
## + / - el zoom, Tab alterna la vista de toda la torre. R arma otra torre, Esc sale.
## Variables de entorno: SALAS_PAQUETE (archivo .jsonl, por defecto bibliotecas/paquete_salas.jsonl), SALAS_SEMILLA (para repetir una torre), SALAS_CANTIDAD (cuántas salas),
## SALAS_PERSONAJE (gato, perro, conejo, dante o gaby).

const Torre := preload("res://torre/torre.gd")
const Vista := preload("res://torre/vista.gd")
const Motor := preload("res://torre/motor.gd")
const Tipos := preload("res://torre/tipos.gd")
const Escena := preload("res://torre/escena.gd")
const Characters := preload("res://scripts/personajes/characters.gd")
const KeyDirs := preload("res://scripts/entrada/key_dirs.gd")
const Controls := preload("res://scripts/entrada/controls.gd")
const Falsos := preload("res://torre/falsos.gd")
const Solucionador := preload("res://torre/solucionador.gd")
const Nat := preload("res://torre/nativo.gd")
const Farolin := preload("res://scripts/personajes/farolin.gd")
const Animacion := preload("res://scripts/personajes/animacion.gd")
const Efectos := preload("res://torre/efectos.gd")
const Loc := preload("res://scripts/idioma/loc.gd")
const Profile := preload("res://scripts/datos/profile.gd")     # (el personaje y los cosméticos que eligió el jugador)
const Graphics := preload("res://scripts/ui/graphics.gd")   # (las teclas y el mando del juego, con sus reasignaciones: el mando entra como teclas, ver pad_bridge.gd)

const PITCH := -35.264        # ángulo isométrico (el del juego)
const PITCH_MIN := -86.0
const PITCH_MAX := 80.0
const MOUSE_SENS := 0.28      # grados por píxel
const ARROW_SPEED := 110.0    # grados por segundo con las flechas
const ZOOM_FACTOR := 1.1
const TOP_VIEW_PITCH := -52.0 # desde este ángulo (mirando desde arriba) se ocultan las salas de arriba, que taparían al personaje
const STEP_TIME := 0.14
const DURACION_ANIM := {"empujar": 0.3, "tirar": 0.4, "trepar": 0.38, "bajar": 0.26, "colgarse": 0.3, "desplazar": 0.3, "desactivar": 0.8}   # lo que duran las animaciones del personaje (las demás duran lo que el movimiento)

## Cuando la torre se juega dentro del juego (scripts/main.gd): el juego pasa el paquete, la semilla, la etapa y los boosts antes de agregarla, y escucha estas señales.
signal checkpoint_alcanzado(faltan: int, total: int)   ## se llegó a la salida de una sala (la anterior cae): cuántos checkpoints faltan (contando el portal) de cuántas salas
signal torre_completa                ## se llegó al portal
signal murio(motivo: String)         ## se perdió una vida (el juego descuenta la del run); la sala ya volvió a empezar
signal movimiento_hecho(accion: String, modo: int, agarre: String)   ## el jugador movió con una tecla de movimiento y salió bien (modo: 0 caminar, 1 empujar o tirar, 2 colgarse; agarre: "push", "pull" o "")
signal camara_usada(accion: String)   ## se movió la cámara con una de las teclas de cámara (el tutorial las dora)
signal accion_hecha                  ## después de cada acción que salió bien (el juego actualiza su HUD)
signal ganancia(texto: String, cantidad: int)   ## la claridad que dio la última acción (el juego muestra el cartel "+N claridad")
signal profundidad_pedida            ## se apretó la tecla de la ayuda de profundidad
signal falsos_cambiaron(quedan: int, permitidos: int, sin_salida: bool, hubo_falso: bool)   ## Sin piedad: lo que quedan de movimientos en falso en la sala
signal deshacer_pedido               ## se apretó deshacer (el juego decide si se puede en este escenario)
signal pista_cambiada(texto: String)   ## la pista que hay que mostrar arriba ("" = ninguna)
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
var silueta: Node3D          # su silueta (se ve a través de los bloques que lo tapan)
var animador: Node           # sus animaciones (animacion.gd)
var _tipo_anim := "caminar"   # la animación de la última acción
var _lento := 1.0            # cuánto se alarga lo que pasa en la última acción (cámara lenta cuando empujar o tirar un bloque hace perder la sala, para que se entienda por qué)
const CAMARA_LENTA := 3.0
const EMPUJE_LENTO := 8.0   # y el movimiento del bloque empujado o tirado (y del personaje que lo mueve) va más lento todavía: es lo que explica la derrota
var _lento_mov := 1.0
var mancha: MeshInstance3D   # la sombra de contacto del personaje: una mancha oscura en la cara de arriba del bloque que pisa (con vista isométrica sin perspectiva, es lo que dice en qué celda está)
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
var sala_inicial := 0           # >0: la torre empieza en el checkpoint de esa sala (continuar una partida guardada)
var banco_inicial := 0          # la claridad asegurada hasta ese checkpoint
var salas_fijas: Array = []         # las salas de una lección del tutorial (en lugar de armar la torre con el paquete)
var dificultad := "media"       # la dificultad del run (fácil, media, difícil o pesadilla)
var mov_run := 0             # movimientos de más por sala (mejoras permanentes del run)
var vidas_fn := Callable()   # () -> int: las vidas del run
var puede_jugar := Callable()   # () -> bool: false mientras hay un menú, un diálogo o una pausa
var falsos_permitidos := 0     # Sin piedad: movimientos en falso que permite cada sala (0 = el escenario no los usa)
var falsos = null              # el medidor (falsos.gd)
var _dur_empuje := 0.0          # lo que dura el movimiento de los bloques de la última acción (lo que cae por perder apoyo empieza después)
var _bloques_antes := {}      # id de cada bloque de la sala viva -> dónde se dibujó la última vez (para ver cómo se mueven)
var _sala_dibujada := -1
var ultimo_agarre := ""          # "push" o "pull" si la última acción movió un bloque
var _rastro_muerte: Array = []   # el camino de la última acción (si ésta termina en derrota se anima antes de caer)
var _tweens_derrota: Array = []   # las animaciones de la derrota en marcha (al reintentar se cortan)
var _cayendo := false   # la animación de la derrota está en marcha: la cámara no sigue al personaje que cae
var _pos_previa := Vector3.ZERO   # dónde estaba el personaje antes de la última acción (la caída de la derrota arranca de ahí)
var efectos                    # sonidos y efectos visuales de las acciones (efectos.gd)
var player_node: Node3D        # (para el juice: el personaje)
var cam_zoom: float:           # (para el juice: el zoom actual)
	get:
		return zoom
var portal: Node3D             # el cubo-portal del final de la torre (lo arma el juego); si no hay, el bloque de salida de la última sala es un bloque dorado común
var _rastro_pendiente: Array = []   # las celdas por las que pasó el personaje en la última acción (saltos y deslizamientos se animan celda por celda)
var farolin: Node3D            # Farolín espera en el próximo checkpoint (sólo en ése)
var faro_modelo: Node3D        # (su modelo, sentado)
var faro_tronco: Node3D        # (el tronquito en el que se apoya)
var _temblando := false      # la sala tiembla cuando quedan la mitad de los movimientos o menos


func _ready() -> void:
	Escena.register_globals()
	if not en_juego:
		Escena.add_lighting(self)   # (dentro del juego se usa su luz)
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
	# el personaje y los cosméticos que eligió el jugador (en el prototipo suelto, SALAS_PERSONAJE o el gatito)
	var personaje := OS.get_environment("SALAS_PERSONAJE")
	var id_personaje: String = Profile.character() if en_juego else (personaje if personaje != "" else "gato")
	var gorro: String = Profile.equipped_hat() if en_juego else ""
	var prenda: String = Profile.equipped_outfit() if en_juego else ""
	gato = Characters.build(id_personaje, gorro, prenda)
	gato_nodo.add_child(gato)
	animador = Animacion.new(gato)
	gato_nodo.add_child(animador)
	silueta = Characters.build(id_personaje, gorro, prenda, true)   # la silueta: sólo se dibuja donde algo lo tapa (como en el juego; Opciones > Gráficos > Transparencia del personaje)
	silueta.visible = bool(Graphics.value("silhouette")) if en_juego else true
	gato_nodo.add_child(silueta)
	animador.sombra = silueta   # (la silueta repite las animaciones)
	mancha = _crear_mancha()
	add_child(mancha)
	# Farolín espera sentado, apoyado en un tronquito, en una esquina del bloque de salida y mirando hacia el centro del cubo
	farolin = Node3D.new()
	farolin.visible = false
	add_child(farolin)
	var faro := Farolin.build(-1, true)
	faro_modelo = faro
	farolin.add_child(faro)
	var pivote := Node3D.new()
	faro_tronco = pivote
	farolin.add_child(pivote)
	var tronco := Farolin.tronco()
	tronco.position = Vector3(0.0, 0.065, -0.17)   # (detrás de Farolín, atravesado)
	pivote.add_child(tronco)
	player_node = gato_nodo
	efectos = Efectos.new(self)
	efectos.juice.body = gato
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
	var ruta := OS.get_environment("SALAS_PAQUETE")
	if ruta == "":
		ruta = ProjectSettings.globalize_path("res://bibliotecas/paquete_salas.jsonl")
	paquete = Torre.cargar_paquete(ruta)
	if paquete.is_empty():
		_aviso("No se encontró el paquete de salas: " + ruta, 0.0)
		return
	var s := OS.get_environment("SALAS_SEMILLA")
	semilla = int(s) if s != "" else int(Time.get_unix_time_from_system()) % 1000000
	_nueva_torre()


func _nueva_torre() -> void:
	for n in estaticas:
		if n != null and is_instance_valid(n):
			n.queue_free()
	estaticas.clear()
	var n_salas := int(OS.get_environment("SALAS_CANTIDAD")) if OS.get_environment("SALAS_CANTIDAD") != "" else 8
	if en_juego:
		if not salas_fijas.is_empty():
			t = Torre.desde_salas(salas_fijas, etapa, dificultad)
		else:
			t = Torre.armar(paquete, semilla, n_salas_fijo if n_salas_fijo > 0 else Torre.salas_de_etapa(etapa), true, etapa, dificultad)
		t.externo = true
		t.aplicar_boosts(boosts)
		t.mov_run = mov_run
		if sala_inicial > 0:
			t.saltar_a_sala(sala_inicial, banco_inicial)
	else:
		t = Torre.armar(paquete, semilla, n_salas)
	if t.salas.is_empty():
		_aviso("No se pudo armar la torre", 0.0)
		return
	Vista.etapa_arte = etapa if en_juego else 0   # (el arte de los bloques depende de la etapa)
	for i in t.salas.size():
		var nodo := Node3D.new()
		add_child(nodo)
		nodo.position = Vector3(0, int(t.salas[i].off), 0)
		Vista.poblar(nodo, Vista.motor_de(t.salas[i].d), {}, false, false, true, true, portal != null and i == t.salas.size() - 1)
		estaticas.append(nodo)
	_poner_portal()
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
	Vista.poblar(vivo, t.motor, t.encendidos, not en_juego, false, false, true, portal != null and t.indice == t.salas.size() - 1)   # (la grilla del anillo es del prototipo: dentro del juego no se dibuja)
	_animar_bloques(animar or t.muerta)
	_poner_gato(animar)
	_poner_camara(animar)
	if panorama:
		for i in estaticas.size():
			if estaticas[i] != null and is_instance_valid(estaticas[i]):
				estaticas[i].visible = i >= t.indice
		if portal != null and is_instance_valid(portal):
			portal.visible = true
	else:
		_ocultar_arriba()
	_poner_farolin()
	texto_hud.visible = not en_juego   # (dentro del juego no hay texto de depuración: el HUD es el del juego)
	texto_hud.text = "Sala %d de %d   ·   Movimientos %d / %d   ·   Vidas %d   ·   Claridad %d%s" % [t.indice + 1, t.salas.size(), t.movs, t.max_mov(), (int(vidas_fn.call()) if vidas_fn.is_valid() else t.vidas), t.cosecha.claridad(), ("  (racha ×%.1f)" % t.cosecha.streak_mult(t.cosecha.streak)) if t.cosecha.streak > 1 else ""]


## Los bloques que se movieron en la última acción (empujados, tirados, deslizados o caídos) se ven recorrer el camino desde donde estaban hasta donde quedaron.
func _animar_bloques(animar: bool) -> void:
	var ahora := {}   # id del bloque -> su posición
	var mallas := {}  # id del bloque -> su malla
	for h in vivo.get_children():
		var mi := h as Node3D
		if mi == null:
			continue
		var celda := Vector3i(floori(mi.position.x), floori(mi.position.y), floori(mi.position.z))
		if t.motor.ids.has(celda) and not ahora.has(t.motor.ids[celda]):
			ahora[t.motor.ids[celda]] = mi.position
			mallas[t.motor.ids[celda]] = mi
	_dur_empuje = 0.0
	if animar and _sala_dibujada == t.indice:
		var cayendo: Array = []
		for id in ahora:   # primero se ve cómo se mueve el bloque (empujado, tirado o deslizado)...
			if not _bloques_antes.has(id) or _bloques_antes[id].is_equal_approx(ahora[id]):
				continue
			var desde: Vector3 = _bloques_antes[id]
			var hasta: Vector3 = ahora[id]
			var mi: Node3D = mallas[id]
			mi.position = desde
			if absf(desde.x - hasta.x) < 0.01 and absf(desde.z - hasta.z) < 0.01 and hasta.y < desde.y:
				cayendo.append([mi, desde, hasta])
				continue
			var dur := maxf(STEP_TIME, 0.07 * desde.distance_to(hasta)) * _lento_mov
			mi.create_tween().tween_property(mi, "position", hasta, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_dur_empuje = maxf(_dur_empuje, dur)
		for c in cayendo:   # ...y recién cuando termina empiezan a caer los que perdieron el apoyo
			var mi: Node3D = c[0]
			var tw := mi.create_tween()
			tw.tween_interval(_dur_empuje)
			tw.tween_property(mi, "position", c[2], (0.12 + 0.07 * c[1].distance_to(c[2])) * _lento).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_bloques_antes = ahora
	_sala_dibujada = t.indice


## El cubo-portal sobre el bloque de salida de la última sala.
func _poner_portal() -> void:
	if portal == null or t == null or t.salas.is_empty():
		return
	var ultima: Dictionary = t.salas[t.salas.size() - 1]
	var s: Vector2i = Torre.salida_xz(ultima.d)
	if portal.get_parent() == null:
		add_child(portal)
	portal.position = Vector3(s.x + 0.5, int(ultima.off) + int(ultima.d.meta) + 0.5, s.y + 0.5)


## Dónde están los pies del personaje (colgado, el cuerpo se arrima al bloque del que se agarra).
func _pos_gato() -> Vector3:
	var j: Vector3i = t.motor.jugador
	var off := float(int(t.sala_actual().off))
	return Vector3(j.x + 0.5, j.y + off, j.z + 0.5) + Vector3(t.motor.colgado) * 0.22


## La mancha de sombra: un disco difuso y oscuro que se apoya sobre el bloque que pisa el personaje.
func _crear_mancha() -> MeshInstance3D:
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;\nvoid fragment() {\n\tfloat d = length(UV - vec2(0.5)) * 2.0;\n\tALBEDO = vec3(0.0);\n\tALPHA = 0.85 * (1.0 - smoothstep(0.4, 1.0, d));\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.render_priority = 2
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var m := MeshInstance3D.new()
	m.mesh = q
	m.material_override = mat
	m.rotation_degrees.x = -90.0
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	return m


## Cada cuadro: la mancha va bajo los pies del personaje, sobre la cara de arriba del bloque que pisa (se esconde si cuelga, se cae o no hay bloque debajo).
func _poner_mancha() -> void:
	if mancha == null or t == null:
		return
	var j: Vector3i = t.motor.jugador
	var tope := -1000
	if not (t.muerta or _cayendo) and t.motor.colgado == Vector3i.ZERO:
		for y in range(j.y, j.y - 12, -1):
			if t.motor.bloques.has(Vector3i(j.x, y - 1, j.z)):
				tope = y
				break
	mancha.visible = tope > -1000
	if mancha.visible:
		mancha.position = Vector3(gato_nodo.position.x, float(tope) + float(int(t.sala_actual().off)) + 0.02, gato_nodo.position.z)


func _poner_gato(animar: bool) -> void:
	if en_juego and t.muerta:   # (perdió la sala: la animación de la derrota lleva al personaje; no se lo acomoda en su sitio)
		return
	var destino := _pos_gato()
	if _paso_tween != null and _paso_tween.is_valid():
		_paso_tween.kill()
	var rastro := _rastro_pendiente
	_rastro_pendiente = []
	if animar and rastro.size() > 2:   # un salto, un deslizamiento o una caída: se anima celda por celda, para que se vea cómo sube, avanza y cae
		var off := float(int(t.sala_actual().off))
		var pts: Array[Vector3] = [gato_nodo.position]
		for i in range(1, rastro.size()):
			var c: Vector3i = rastro[i]
			pts.append(Vector3(c.x + 0.5, c.y + off, c.z + 0.5))
		pts[pts.size() - 1] = destino   # (al final, colgado o parado)
		var seg := minf(0.07, 0.6 / float(pts.size() - 1))
		_paso_tween = create_tween()
		_paso_tween.tween_method(func(k: float) -> void: gato_nodo.position = _punto_en(pts, k), 0.0, 1.0, seg * float(pts.size() - 1))
		animador.colgado(t.motor.colgado != Vector3i.ZERO)
		animador.reproducir(_tipo_anim, maxf(STEP_TIME, seg * float(pts.size() - 1)))
	elif animar:
		_paso_tween = create_tween()
		_paso_tween.tween_property(gato_nodo, "position", destino, STEP_TIME)
		animador.colgado(t.motor.colgado != Vector3i.ZERO)
		animador.reproducir(_tipo_anim, float(DURACION_ANIM.get(_tipo_anim, STEP_TIME)) * _lento)
	else:
		gato_nodo.position = destino
		animador.colgado(t.motor.colgado != Vector3i.ZERO)
	animador.asustado(_cerca_de_bomba())
	var cara: Vector3i = t.motor.colgado if t.motor.colgado != Vector3i.ZERO else mira
	gato_nodo.rotation.y = atan2(cara.x, cara.z)


## ¿El personaje está dentro de la zona de una bomba con la mecha en marcha?
func _cerca_de_bomba() -> bool:
	var j: Vector3i = t.motor.jugador
	for c in t.motor.bloques:
		if str(t.motor.bloques[c]).begins_with("b"):
			var d: Vector3i = c - j
			if d.x * d.x + d.y * d.y + d.z * d.z <= Tipos.BOMBA_R2:
				return true
	return false


## La animación que corresponde a lo que pasó en la última acción (`m`: el motor de antes, que guarda lo que pasó; `colgado_antes`: de dónde colgaba antes).
func _tipo_animacion(m, modo: int, antes_y: int, colgado_antes: Vector3i) -> String:
	var colgado_ahora: Vector3i = t.motor.colgado
	if m.desarmo:
		return "desactivar"
	if m.salto:
		return "catapulta"
	if m.resbalo:
		return "resbalar"
	if modo == Motor.Modo.AGARRAR and m.agarro:
		return "tirar" if m.tipo_agarre == "pull" else "empujar"
	if colgado_ahora != Vector3i.ZERO and colgado_antes == Vector3i.ZERO:
		return "colgarse"
	if colgado_ahora != Vector3i.ZERO:
		return "desplazar"
	if m.jugador.y > antes_y:
		return "trepar"
	if m.jugador.y < antes_y:
		return "bajar"
	return "caminar"


## El punto de la poligonal a lo largo de k (0 = el primero, 1 = el último).
func _punto_en(pts: Array[Vector3], k: float) -> Vector3:
	var u := clampf(k, 0.0, 1.0) * float(pts.size() - 1)
	var i := mini(int(u), pts.size() - 2)
	return pts[i].lerp(pts[i + 1], u - i)


func _poner_camara(animar: bool) -> void:
	var foco := (gato_nodo.position if en_juego and t.muerta else _pos_gato()) + Vector3(0, 0.5, 0)   # (al perder el personaje sigue donde estaba: la cámara no salta hasta donde caería)
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


## Farolín está parado sobre el bloque de salida de la sala actual (el próximo checkpoint), en una esquina de la cara de arriba, mirando hacia la cámara.
func _poner_farolin() -> void:
	if farolin == null or t == null:
		return
	var sala: Dictionary = t.sala_actual()
	var s: Vector2i = Torre.salida_xz(sala.d)
	farolin.visible = s.x >= 0
	var meta: int = int(sala.d.meta)
	farolin.position = Vector3(s.x + 0.5, int(sala.off) + meta + 1, s.y + 0.5)
	# se sienta en la esquina de la cara de arriba que tiene menos bloques al lado (la sala de arriba empieza justo ahí y lo taparía); a igualdad, la de atrás de la cámara
	var mejor := Vector2i(-1, -1)
	var mejor_puntaje := 1 << 20
	for esq in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var p := 0
		for nivel in [meta + 1, meta + 2]:
			for celda in [Vector3i(s.x + esq.x, nivel, s.y), Vector3i(s.x, nivel, s.y + esq.y), Vector3i(s.x + esq.x, nivel, s.y + esq.y)]:
				if t.motor.bloques.has(celda):
					p += 1
		if p < mejor_puntaje:
			mejor_puntaje = p
			mejor = esq
	var ang := atan2(-float(mejor.x), -float(mejor.y))   # (de la esquina hacia el centro del cubo)
	var pos := Vector3(0.27 * mejor.x, 0.0, 0.27 * mejor.y)
	faro_modelo.position = pos
	faro_modelo.rotation = Vector3(deg_to_rad(-10.0), ang, 0.0)   # (apenas echado hacia atrás, contra el tronco)
	faro_tronco.position = pos
	faro_tronco.rotation.y = ang


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
	if portal != null and is_instance_valid(portal):   # (el portal está sobre la última sala: si todavía no se llegó a ella, se oculta con las demás)
		portal.visible = not (desde_arriba and t.indice < t.salas.size() - 1)


func _process(delta: float) -> void:
	if t == null or pivot == null:
		return
	if silueta != null and en_juego:   # (Opciones > Gráficos > Transparencia del personaje: vale en cuanto se cambia)
		silueta.visible = bool(Graphics.value("silhouette"))
	var activa: bool = not (en_juego and puede_jugar.is_valid() and not puede_jugar.call())
	efectos.proceso(delta, activa)
	if not panorama and not _cayendo:   # la cámara sigue siempre al personaje (también mientras camina o se desliza), aunque algo la haya movido
		var foco := gato_nodo.position + Vector3(0, 0.5, 0)
		pivot.position = pivot.position.lerp(foco, 1.0 - exp(-14.0 * delta))
	_temblar()
	_poner_mancha()
	_pista_proceso()
	if not activa:
		return
	var ax := int(Controls.held("camara_derecha")) - int(Controls.held("camara_izquierda"))
	var ay := int(Controls.held("camara_abajo")) - int(Controls.held("camara_arriba"))
	if ax != 0 or ay != 0:
		orbitar(Vector2(ax, ay) * ARROW_SPEED * delta / MOUSE_SENS)
		for id in ["camara_derecha", "camara_izquierda", "camara_abajo", "camara_arriba"]:
			if Controls.held(id):
				camara_usada.emit(id)


## Con la mitad de los movimientos de la sala gastados o más, los bloques de la sala tiemblan (cada uno a su modo): casi nada al principio y cada vez más fuerte hacia el límite.
func _temblar() -> void:
	var amp := 0.0
	if en_juego and not t.muerta and not t.terminada and not _cayendo:
		var f := float(t.movs) / maxf(float(t.max_mov()), 1.0)
		var k := clampf((f - 0.5) / 0.5, 0.0, 1.0)
		if k > 0.0:
			amp = lerpf(0.004, 0.045, pow(k, 1.5))
	if amp <= 0.0 and not _temblando:
		return
	_temblando = amp > 0.0
	for h in vivo.get_children():
		var mi := h as MeshInstance3D
		if mi == null or not (mi.material_override is ShaderMaterial):
			continue
		if not mi.has_meta("unico"):   # (los materiales de los bloques se comparten: cada bloque de la sala viva tiene el suyo para temblar solo)
			mi.material_override = mi.material_override.duplicate()
			mi.set_meta("unico", true)
		(mi.material_override as ShaderMaterial).set_shader_parameter("shake", amp)


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
	if accion_id == "profundidad":   # la ayuda de profundidad es del juego (main.gd)
		profundidad_pedida.emit()
		return
	if k == KEY_TAB:   # la vista de toda la torre
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
	if accion_id == "pista":
		alternar_pista()
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
	if t.motor.colgado != Vector3i.ZERO and dir == -t.motor.colgado and modo != Motor.Modo.COLGAR:
		return   # colgado, la única forma de soltarse de la cornisa es la tecla de colgarse (la barra): la dirección contraria no hace nada
	var r: Dictionary = accion(dir, modo)
	if r.ok:
		movimiento_hecho.emit(accion_id, modo, ultimo_agarre)


## Una acción del jugador (también la usan las pruebas).
func accion(dir: Vector3i, modo: int) -> Dictionary:
	var motor_antes = t.motor
	var antes_y: int = motor_antes.jugador.y
	var off_antes := float(int(t.sala_actual().off))
	var colgado_antes: Vector3i = motor_antes.colgado
	_pos_previa = gato_nodo.position
	var r: Dictionary = t.actuar(dir, modo)
	mira = dir
	if not r.ok:
		_aviso(str(r.msg), 1.4)
		_poner_gato(false)   # (aunque no se mueva, gira hacia donde se lo intentó llevar)
		return r
	_tipo_anim = _tipo_animacion(motor_antes, modo, antes_y, colgado_antes)
	var explica := str(r.evento) == "muerte" and (_tipo_anim == "empujar" or _tipo_anim == "tirar")
	_lento = CAMARA_LENTA if explica else 1.0
	_lento_mov = EMPUJE_LENTO if explica else 1.0   # (si el bloque que movió te hace perder, se ve despacio)
	if _tipo_anim == "tirar":
		mira = -dir   # (al tirar camina hacia atrás: sigue de frente al bloque que trae)
	_rastro_pendiente = motor_antes.rastro
	ultimo_agarre = motor_antes.tipo_agarre
	_rastro_muerte = motor_antes.rastro.duplicate()
	_procesar(r)
	if not motor_antes.ultimos_movidos.is_empty():   # (un bloque que empujaste o tiraste y que se perdió no queda en la sala: se lo anima igual antes de que caiga)
		for p in motor_antes.caidos_fuera:
			if motor_antes.ultimos_movidos.has(p[0]):
				_dur_empuje = maxf(_dur_empuje, maxf(STEP_TIME, 0.07) * _lento_mov)
	efectos.sonido(motor_antes, modo, antes_y)   # (el motor de antes guarda lo que pasó en la acción, aunque la sala haya cambiado)
	efectos.visuales(motor_antes, antes_y, off_antes, _dur_empuje, _lento, str(r.evento) == "muerte")
	if str(r.evento) == "torre":
		efectos.juice.gold_burst(portal.position if portal != null else gato_nodo.position)
		efectos.juice.zoom_punch(0.05)
	if t.cosecha.last_gain > 0 and str(r.evento) != "muerte" and str(r.evento) != "fin":   # el cartel "+N claridad" (con la racha y la cosecha)
		var mult: float = t.cosecha.streak_mult(t.cosecha.streak)
		var texto := Loc.f("+%d claridad", [t.cosecha.last_gain])
		if t.cosecha.streak >= 2:
			texto += Loc.f("   racha ×%.1f", [mult])
		if t.cosecha.harvest_mult() > 1.0:
			texto += Loc.f("   cosecha ×%.1f", [t.cosecha.harvest_mult()])
		ganancia.emit(texto, t.cosecha.last_gain)
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
	var muerte_pendiente := ""
	match str(r.evento):
		"checkpoint":
			_caer_sala(t.ultima_caida)
			_aviso("¡Checkpoint!", 1.8)
			checkpoint_alcanzado.emit(t.salas.size() - t.indice, t.salas.size())
		"torre":
			if en_juego:
				torre_completa.emit()
			else:
				_aviso("¡Llegaste al portal! Pulsa R para otra torre.", 0.0)
		"muerte":
			if en_juego:
				muerte_pendiente = str(r.msg)   # (el juego muestra la pantalla de derrota con el motivo, después de dibujar lo que pasó)
			else:
				_aviso("%s. Pierdes una vida (te quedan %d)." % [str(r.msg), t.vidas], 3.0)
		"aliento":
			_aviso("Segundo aliento: la sala vuelve a empezar y no pierdes la vida.", 3.0)
		"fin":
			_aviso("%s. Te quedaste sin vidas. Pulsa R para otra torre." % str(r.msg), 0.0)
	var punto_checkpoint := farolin.global_position if farolin != null else Vector3.ZERO   # (el bloque que se acaba de encender: donde saltan las chispas)
	if str(r.evento) == "checkpoint":
		_rastro_pendiente = []   # (el camino es de la sala de abajo: el último paso hasta el checkpoint se anima en línea recta, y la cámara lo acompaña)
	_refrescar(str(r.evento) == "" or str(r.evento) == "checkpoint")   # (tras una muerte el personaje aparece de golpe en su sitio)
	if str(r.evento) == "checkpoint" and en_juego and farolin != null and farolin.visible:
		faro_modelo.celebrar(punto_checkpoint)   # (Farolín salta de alegría en el próximo checkpoint y las chispas encienden el farolito del que se pisó)
	if muerte_pendiente != "":
		murio.emit(muerte_pendiente)
	accion_hecha.emit()


## Sin piedad: se pasó del último movimiento en falso de la sala: se pierde como si se hubiera caído.
func _falsos_agotados() -> void:
	if t == null or t.terminada or t.perdida:
		return
	perder("Tercer movimiento en falso")
	if falsos != null:
		falsos.sala_nueva(t.motor)
		falsos_cambiaron.emit(falsos.quedan(), falsos_permitidos, false, false)


## Se pierde la sala por un motivo que no es un movimiento (Sin piedad, las pruebas): igual que caerse, sin camino que animar.
func perder(motivo: String) -> void:
	if t == null or t.terminada or t.perdida:
		return
	_rastro_muerte = []
	_procesar(t.forzar_muerte(motivo))


## La animación de perder: el personaje se cae dando vueltas (y, si se acabaron los movimientos, la sala entera se derrumba con él) y la cámara tiembla.
## Devuelve cuántos segundos dura el movimiento que causó la derrota (el juego espera ese tiempo antes de mostrar la pantalla de derrota, para que se vea por qué se perdió).
func animar_derrota(motivo: String) -> float:
	const LENTO := 2.0   # las animaciones de muerte van a la mitad de velocidad
	if _paso_tween != null and _paso_tween.is_valid():
		_paso_tween.kill()
	gato_nodo.visible = true
	var off := float(int(t.sala_actual().off))
	var pts: Array[Vector3] = []
	if _pos_previa != Vector3.ZERO:
		pts.append(_pos_previa)   # (se ve el movimiento que hizo: el paso hasta el borde, la caída del piso...)
		for i in range(1, _rastro_muerte.size()):
			var c: Vector3i = _rastro_muerte[i]
			pts.append(Vector3(c.x + 0.5, c.y + off, c.z + 0.5))
	_rastro_muerte = []
	var previo := 0.0
	var espera := _dur_empuje   # (primero se ve moverse el bloque; el personaje cae cuando éste termina)
	_tweens_derrota = []
	if pts.size() > 1:
		gato_nodo.position = pts[0]
		var seg := 0.14 * _lento_mov
		var lento_mov := _lento_mov > 1.0   # (en cámara lenta el personaje y el bloque se mueven a la vez: se ve cómo lo empuja o lo trae)
		var demora := 0.0 if lento_mov else espera
		previo = maxf(espera, demora + seg * float(pts.size() - 1)) + (0.8 if lento_mov else 0.35)   # (y una pausa para ver dónde quedó)
		var mov := create_tween()
		mov.tween_interval(demora)
		mov.tween_method(func(k: float) -> void: gato_nodo.position = _punto_en(pts, k), 0.0, 1.0, seg * float(pts.size() - 1))
		mov.parallel().tween_callback(animador.reproducir.bind(_tipo_anim, seg * float(pts.size() - 1) if _lento_mov > 1.0 else float(DURACION_ANIM.get(_tipo_anim, 0.14)))).set_delay(0.0)
		_tweens_derrota.append(mov)
	elif espera > 0.0:   # (empujó un bloque sin moverse: el personaje empuja mientras el bloque recorre su camino, y recién después cae)
		previo = espera + (0.8 if _lento_mov > 1.0 else 0.35)
		gato_nodo.position = _pos_previa if _pos_previa != Vector3.ZERO else gato_nodo.position
		animador.reproducir(_tipo_anim, espera)
	get_tree().create_timer(previo).timeout.connect(_caer_derrota.bind(motivo, LENTO))
	return previo


func _caer_derrota(motivo: String, lento: float) -> void:
	if t == null or not t.muerta:
		return   # (ya se reintentó)
	_cayendo = true
	var tw := create_tween().set_parallel(true)
	_tweens_derrota.append(tw)
	tw.tween_property(gato_nodo, "position:y", gato_nodo.position.y - 14.0, 1.4 * lento).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(gato_nodo, "rotation:x", gato_nodo.rotation.x + TAU * 1.5, 1.4 * lento)
	tw.tween_property(gato_nodo, "rotation:z", gato_nodo.rotation.z + TAU * 0.75, 1.4 * lento)
	if motivo.contains("movimientos"):   # (se acabó el tiempo: cae la sala entera)
		tw.tween_property(vivo, "position:y", vivo.position.y - 30.0, 1.6 * lento).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var temblor := create_tween()   # (el temblor mueve el encuadre de la cámara, no el pivote que la sigue)
	for i in 8:
		temblor.tween_property(cam, "h_offset", randf_range(-0.12, 0.12), 0.04 * lento)
		temblor.parallel().tween_property(cam, "v_offset", randf_range(-0.12, 0.12), 0.04 * lento)
	temblor.tween_property(cam, "h_offset", 0.0, 0.05 * lento)
	temblor.parallel().tween_property(cam, "v_offset", 0.0, 0.05 * lento)
	_tweens_derrota.append(temblor)


## Volver a empezar la sala perdida (reintentar): se acomoda todo como al entrar a ella.
func reiniciar_sala() -> void:
	if t == null:
		return
	t.reintentar_sala()
	for tw in _tweens_derrota:   # (si se reintenta antes de que termine la caída, ésta se corta: si no, seguiría moviendo al personaje y la sala)
		if tw != null and tw.is_valid():
			tw.kill()
	_tweens_derrota.clear()
	_cayendo = false
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	gato_nodo.rotation = Vector3.ZERO
	vivo.position = Vector3(0, int(t.sala_actual().off), 0)
	if falsos != null:
		falsos.sala_nueva(t.motor)
		falsos_cambiaron.emit(falsos.quedan(), falsos_permitidos, false, false)
	_refrescar(false)
	accion_hecha.emit()


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
	if _pista_hilo != null:
		_pista_hilo.wait_to_finish()


func _caer_sala(i: int) -> void:
	if i < 0 or i >= estaticas.size():
		return
	var n = estaticas[i]
	if n != null and is_instance_valid(n):
		n.queue_free()   # (el dibujo virgen de la sala: lo que cae es la sala tal como quedó)
	estaticas[i] = null
	var cae := Node3D.new()
	add_child(cae)
	cae.position = vivo.position
	var centro := Vector3.ZERO   # el bloque de salida (donde se está parado) no cae: pasa a ser la entrada de la sala siguiente
	var salida := Vector3.ZERO
	for b in t.salas[i].d.bloques:
		if str(b[3]) == "f":
			salida = Vector3(int(b[0]) + 0.5, int(b[1]) + 0.5, int(b[2]) + 0.5)
	centro = salida + Vector3(0, 1, 0)
	var hijos := vivo.get_children()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var ultimo := 0.0
	for h in hijos:   # los bloques vivos de la sala se pasan al nodo que cae, antes de que se redibuje la siguiente
		var mi := h as Node3D
		if mi == null:
			continue
		if mi.position.distance_to(salida) < 0.1:
			continue   # (se queda en vivo y se redibuja con la sala nueva)
		mi.reparent(cae, false)
		# cada bloque cae a su modo: la caída se propaga desde donde estás, con demora, velocidad, giro y deriva propios
		var d := mi.position.distance_to(centro)
		var demora := d * 0.045 + rng.randf_range(0.0, 0.35)
		var dur := rng.randf_range(1.1, 2.0)
		var tw := mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "position:y", mi.position.y - 40.0, dur).set_delay(demora).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(mi, "position:x", mi.position.x + rng.randf_range(-0.8, 0.8), dur).set_delay(demora)
		tw.tween_property(mi, "position:z", mi.position.z + rng.randf_range(-0.8, 0.8), dur).set_delay(demora)
		tw.tween_property(mi, "rotation", Vector3(rng.randf_range(-1.6, 1.6), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.6, 1.6)), dur).set_delay(demora).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		ultimo = maxf(ultimo, demora + dur)
	get_tree().create_timer(ultimo + 0.2).timeout.connect(cae.queue_free)


# --- Modo pista (Fácil): la tecla de la pista muestra arriba el próximo movimiento de la solución de la sala, con los botones que hay que apretar ---

const TECLAS_DIR := ["mover_adelante", "mover_derecha", "mover_atras", "mover_izquierda"]   # (en el orden de KeyDirs.assign: W, D, S, A)
const PISTA_TOPE := 400000        # estados que explora el solucionador nativo para la pista
const PISTA_TOPE_GDSCRIPT := 20000

var pista_permitida := false      # el juego la habilita sólo en Fácil
var pista_activa := false
var _pista_hilo: Thread
var _pista_clave := ""            # el estado de la sala para el que está lista la pista
var _pista_res := {}              # { estado: "ok" | "sin_salida" | "tope", dir, modo, suelta }
var _pista_texto := ""            # lo que se muestra ahora (para avisar sólo cuando cambia)


## Enciende o apaga el modo pista.
func alternar_pista() -> void:
	if not pista_permitida:
		return
	pista_activa = not pista_activa
	_pista_clave = ""
	_pista_res = {}
	if not pista_activa:
		_publicar_pista("")


func _clave_pista() -> String:
	if t == null or t.motor == null:
		return ""
	return "%d:%d" % [t.indice, Solucionador.clave(t.motor)]


func _pista_proceso() -> void:
	if not pista_activa or not pista_permitida or t == null or t.terminada or t.perdida or t.muerta:
		if _pista_texto != "":
			_publicar_pista("")
		return
	if _pista_hilo != null:
		if _pista_hilo.is_alive():
			return
		var r: Dictionary = _pista_hilo.wait_to_finish()
		_pista_hilo = null
		if str(r.clave) == _clave_pista():
			_pista_clave = str(r.clave)
			_pista_res = r
		return
	var c := _clave_pista()
	if c != _pista_clave:
		_pista_res = {}
		_pista_hilo = Thread.new()
		_pista_hilo.start(_pista_calcular.bind(t.motor.duplicar(), c))
		return
	_publicar_pista(_texto_pista())


## En un hilo: la solución de la sala desde ese estado. Con el solucionador nativo si está, y si no con el de GDScript (más lento y con menos tope).
func _pista_calcular(motor, clave: String) -> Dictionary:
	var res := {"clave": clave, "estado": "tope"}
	var s: Dictionary = Nat.resolver(motor, PISTA_TOPE) if Nat.disponible() else Solucionador.resolver(motor, PISTA_TOPE_GDSCRIPT)
	if bool(s.get("ok", false)) and not (s.path as Array).is_empty():
		var paso: Array = s.path[0]
		res["estado"] = "ok"
		res["dir"] = paso[0]
		res["modo"] = int(paso[1])
		res["suelta"] = int(paso[1]) == Motor.Modo.COLGAR and motor.colgado != Vector3i.ZERO and paso[0] == -motor.colgado
	elif not bool(s.get("tope", false)):
		res["estado"] = "sin_salida"
	return res


## La frase de la pista con las teclas entre llaves (la dibuja key_hint.gd); depende de hacia dónde mira la cámara.
func _texto_pista() -> String:
	match str(_pista_res.get("estado", "")):
		"sin_salida":
			return "Esta sala ya no tiene salida: deshaz o reintenta."
		"tope":
			return "Esta sala es muy complicada para calcular la pista."
		"ok":
			if bool(_pista_res.suelta):
				return "Pulsa {colgarse}"
			var dirs := KeyDirs.assign(yaw_target)
			var i := dirs.find(Vector2i(_pista_res.dir.x, _pista_res.dir.z))
			if i < 0:
				return ""
			var tecla: String = TECLAS_DIR[i]
			match int(_pista_res.modo):
				Motor.Modo.AGARRAR:
					return "Mantén {empujar} y pulsa {%s}" % tecla
				Motor.Modo.COLGAR:
					return "Mantén {colgarse} y pulsa {%s}" % tecla
			return "Pulsa {%s}" % tecla
	return ""


func _publicar_pista(texto: String) -> void:
	if texto == _pista_texto:
		return
	_pista_texto = texto
	pista_cambiada.emit(texto)
