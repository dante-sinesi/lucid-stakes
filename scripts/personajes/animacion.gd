extends Node
## Las animaciones del personaje al hacer acciones (empujar, tirar, trepar, bajar, colgarse, desplazarse colgado, resbalar, catapulta, desactivar una bomba) y mientras espera
## (respira y, tras unos segundos quieto, hace algún pasatiempo). Se agrega como hijo del nodo del personaje y mueve las partes del modelo (pata_i/d, brazo_i/d, cola) y el modelo mismo
## (giro, altura, escala). Una pose es una función del tiempo normalizado `k` (0 a 1): `pose()`; las acciones la recorren con un tween y la galería de poses la usa para sacar fotos.
## Estilo: "exageradas" (poses grandes, saltitos, aplastar al agacharse) o "sutiles" (poses chicas, sin saltitos ni deformar el cuerpo): Opciones > General, ajuste `animaciones_exageradas`.
## Docs: docs/animaciones_personaje.md.

const Settings := preload("res://scripts/datos/settings.gd")

const TIPOS := ["caminar", "empujar", "tirar", "trepar", "bajar", "colgarse", "desplazar", "resbalar", "catapulta", "desactivar"]
const PASATIEMPOS := ["mirar", "estirar", "rascar", "saludar"]
const ESPERA_PASATIEMPO := 3.0   # segundos quieto antes del primer pasatiempo

var modelo: Node3D
var _tw: Tween
var _ocupado := false          # una acción está en marcha: nada de respirar ni pasatiempos
var _colgado := false
var _asustado := false
var _quieto := 0.0
var _pasatiempo := ""
var _pasatiempo_t := 0.0
var _t := 0.0


func _init(m: Node3D = null) -> void:
	modelo = m


## Las animaciones exageradas (el ajuste del jugador).
static func exageradas() -> bool:
	return bool(Settings.get_value("animaciones_exageradas"))


## Reproduce la animación de una acción (`dur`: lo que dura, en segundos). Al terminar el personaje vuelve a su pose de reposo (o de colgado).
func reproducir(tipo: String, dur: float) -> void:
	if modelo == null or not is_instance_valid(modelo):
		return
	_cortar()
	_ocupado = true
	_quieto = 0.0
	_pasatiempo = ""
	var amp := 1.0 if exageradas() else 0.45
	var deforma := exageradas()
	_tw = create_tween()
	_tw.tween_method(func(k: float) -> void: pose(modelo, tipo, k, amp, deforma), 0.0, 1.0, dur)
	_tw.tween_callback(_terminar)


## Colgado de un borde: los brazos arriba y las patitas sueltas (que se balancean un poco).
func colgado(on: bool) -> void:
	_colgado = on
	if not _ocupado:
		_reposo()


## Con una bomba cerca (dentro de su zona): tiembla un poco con los brazos medio levantados.
func asustado(on: bool) -> void:
	_asustado = on
	if not _ocupado and not on:
		_reposo()


func _cortar() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()


func _terminar() -> void:
	_ocupado = false
	_reposo()


## Deja al personaje en su pose de reposo: de pie con los brazos al costado, o colgado.
func _reposo() -> void:
	if modelo == null or not is_instance_valid(modelo):
		return
	pose(modelo, "colgado" if _colgado else "reposo", 1.0, 1.0, false)


func _process(delta: float) -> void:
	if modelo == null or not is_instance_valid(modelo) or _ocupado:
		return
	_t += delta
	if _colgado:   # (se balancea colgado)
		var s := sin(_t * 2.2)
		_pata(modelo, "pata_i").rotation.x = 0.18 + 0.12 * s
		_pata(modelo, "pata_d").rotation.x = 0.18 - 0.12 * s
		modelo.rotation.z = 0.04 * s
		return
	if _asustado:   # (tiembla)
		modelo.rotation.z = 0.05 * sin(_t * 38.0)
		_pata(modelo, "brazo_i").rotation.x = -0.9 + 0.1 * sin(_t * 31.0)
		_pata(modelo, "brazo_d").rotation.x = -0.9 + 0.1 * sin(_t * 29.0 + 1.0)
		return
	_quieto += delta
	if _pasatiempo == "" and _quieto > ESPERA_PASATIEMPO:
		_pasatiempo = PASATIEMPOS[randi() % PASATIEMPOS.size()]
		_pasatiempo_t = 0.0
	if _pasatiempo != "":
		_pasatiempo_t += delta
		var dur := 2.2
		var k := _pasatiempo_t / dur
		pose(modelo, _pasatiempo, minf(k, 1.0), 1.0, false)
		if k >= 1.0:
			_pasatiempo = ""
			_quieto = ESPERA_PASATIEMPO - 2.0 - randf() * 3.0   # (el siguiente, en unos segundos)
			_reposo()
		return
	modelo.position.y = 0.006 * sin(_t * 2.0)   # respira
	_pata(modelo, "brazo_i").rotation.z = -0.03 * sin(_t * 2.0)
	_pata(modelo, "brazo_d").rotation.z = 0.03 * sin(_t * 2.0)


static func _pata(m: Node3D, nombre: String) -> Node3D:
	var p := m.get_node_or_null(nombre) as Node3D
	return p if p != null else Node3D.new()   # (si el modelo no la tiene, un nodo suelto que nadie ve)


## La pose de `m` en el instante `k` (0 a 1) de la animación `tipo`. `amp` escala las poses (1 = exageradas), `deforma` permite aplastar y estirar el cuerpo.
## "reposo" y "colgado" son poses fijas. Los ángulos: rotation.x de un brazo o una pata es negativo hacia adelante; rotation.z de un brazo es negativo hacia afuera a la izquierda
## y positivo hacia afuera a la derecha; rotation.x del modelo es positivo hacia adelante.
static func pose(m: Node3D, tipo: String, k: float, amp := 1.0, deforma := true) -> void:
	var bi := _pata(m, "brazo_i")
	var bd := _pata(m, "brazo_d")
	var pi := _pata(m, "pata_i")
	var pd := _pata(m, "pata_d")
	bi.rotation = Vector3.ZERO
	bd.rotation = Vector3.ZERO
	pi.rotation = Vector3.ZERO
	pd.rotation = Vector3.ZERO
	m.rotation = Vector3.ZERO
	m.position = Vector3.ZERO
	m.scale = Vector3.ONE
	k = clampf(k, 0.0, 1.0)
	var e := sin(PI * k)   # sube y vuelve
	var s := e * amp
	match tipo:
		"caminar":   # el paso de siempre (patas y brazos cruzados) y, en las exageradas, un rebotito
			pi.rotation.x = 0.7 * e
			pd.rotation.x = -0.7 * e
			bi.rotation.x = -0.7 * e
			bd.rotation.x = 0.7 * e
			m.position.y = 0.03 * s
			m.rotation.x = 0.1 * s
		"empujar":   # se inclina hacia el bloque con los brazos estirados y las patas de esfuerzo
			var f := smoothstep(0.0, 0.3, k) * smoothstep(1.0, 0.7, k) * amp
			m.rotation.x = 0.5 * f
			bi.rotation.x = -1.5 * f
			bd.rotation.x = -1.5 * f
			pi.rotation.x = 0.55 * f
			pd.rotation.x = -0.35 * f
		"tirar":   # agarra con las dos manos y se echa hacia atrás con las patas separadas
			var alcanza := smoothstep(0.0, 0.35, k)
			var tira := smoothstep(0.35, 0.7, k) * smoothstep(1.0, 0.8, k)
			var f := smoothstep(0.0, 0.2, k) * smoothstep(1.0, 0.85, k) * amp
			bi.rotation.x = (-1.4 * alcanza + 1.0 * tira) * f
			bd.rotation.x = (-1.4 * alcanza + 1.0 * tira) * f
			m.rotation.x = -0.4 * tira * amp
			pi.rotation.x = 0.5 * f
			pd.rotation.x = -0.45 * f
		"trepar":   # se agacha, salta con los brazos arriba y aterriza
			var agacha := smoothstep(0.0, 0.2, k) * smoothstep(0.3, 0.2, k)
			var aire := sin(PI * clampf((k - 0.25) / 0.6, 0.0, 1.0))
			m.position.y = 0.3 * aire * amp
			if deforma:
				m.scale = Vector3(1.0 + 0.1 * agacha, 1.0 - 0.25 * agacha, 1.0 + 0.1 * agacha)
			bi.rotation.x = -2.9 * maxf(aire, agacha * 0.0) * amp + 0.6 * agacha * amp
			bd.rotation.x = bi.rotation.x
			pi.rotation.x = -1.0 * aire * amp
			pd.rotation.x = -0.6 * aire * amp
			m.rotation.x = 0.15 * aire * amp
		"bajar":   # un saltito corto con los brazos abiertos para el equilibrio
			m.position.y = 0.14 * s
			bi.rotation.z = -1.1 * s
			bd.rotation.z = 1.1 * s
			pi.rotation.x = -0.6 * s
			pd.rotation.x = -0.3 * s
		"colgarse":   # se agarra con un saltito y los brazos arriba
			var sube := smoothstep(0.0, 0.5, k)
			m.position.y = 0.12 * s
			bi.rotation.x = -3.0 * sube * amp
			bd.rotation.x = -3.0 * sube * amp
			pi.rotation.x = 0.18 * sube
			pd.rotation.x = 0.18 * sube
		"desplazar":   # mano tras mano por el borde
			bi.rotation.x = -3.0 + 0.5 * sin(TAU * k) * amp
			bd.rotation.x = -3.0 - 0.5 * sin(TAU * k) * amp
			pi.rotation.x = 0.2 + 0.25 * sin(TAU * k) * amp
			pd.rotation.x = 0.2 - 0.25 * sin(TAU * k) * amp
			m.rotation.z = 0.1 * sin(TAU * k) * amp
		"resbalar":   # patina con los brazos abiertos y las patas juntas, bamboleándose
			var f := smoothstep(0.0, 0.15, k) * smoothstep(1.0, 0.85, k) * amp
			bi.rotation.z = -1.1 * f
			bd.rotation.z = 1.1 * f
			pi.rotation.x = -0.3 * f
			pd.rotation.x = -0.3 * f
			m.rotation.x = -0.18 * f
			m.rotation.y = 0.35 * sin(TAU * k * 2.0) * f
			m.rotation.z = 0.08 * sin(TAU * k * 3.0) * f
		"catapulta":   # se agacha y sale disparado con los brazos arriba y las patas estiradas
			var agacha := smoothstep(0.0, 0.15, k) * smoothstep(0.3, 0.15, k)
			var vuela := smoothstep(0.2, 0.35, k) * smoothstep(1.0, 0.85, k)
			if deforma:
				m.scale = Vector3(1.0 + 0.12 * agacha, 1.0 - 0.3 * agacha + 0.1 * vuela, 1.0 + 0.12 * agacha)
			bi.rotation.x = (0.5 * agacha - 3.1 * vuela) * amp
			bd.rotation.x = bi.rotation.x
			pi.rotation.x = 0.3 * vuela * amp
			pd.rotation.x = 0.3 * vuela * amp
		"desactivar":   # se seca la frente, aliviado
			var f := smoothstep(0.0, 0.25, k) * smoothstep(1.0, 0.75, k)
			bd.rotation.x = (-2.7 + 0.15 * sin(k * 28.0)) * f * amp
			bd.rotation.z = 0.5 * f * amp
			m.position.y = -0.02 * f * amp
			m.rotation.x = 0.1 * f * amp
		"mirar":   # pasatiempo: mira a un lado y al otro
			m.rotation.y = 0.8 * sin(TAU * k) * e
		"estirar":   # pasatiempo: se estira con los brazos arriba
			bi.rotation.x = -3.0 * e
			bd.rotation.x = -3.0 * e
			m.rotation.x = -0.12 * e
			m.position.y = 0.03 * e
		"rascar":   # pasatiempo: se rasca la cabeza
			bd.rotation.x = (-2.7 + 0.2 * sin(k * 40.0)) * e
			bd.rotation.z = 0.6 * e
		"saludar":   # pasatiempo: saluda con la mano
			bd.rotation.z = 2.4 * e
			bd.rotation.x = 0.3 * sin(k * 36.0) * e
		"colgado":
			bi.rotation.x = -3.0
			bd.rotation.x = -3.0
			pi.rotation.x = 0.18
			pd.rotation.x = 0.18
		_:   # "reposo"
			pass
	# con los brazos muy arriba se abren un poco hacia afuera: pegados al cuerpo quedarían escondidos dentro de la cabeza
	for par in [[bi, -1.0], [bd, 1.0]]:
		var brazo: Node3D = par[0]
		var alto := clampf((-brazo.rotation.x - 1.9) / 0.8, 0.0, 1.0)
		brazo.rotation.z += float(par[1]) * 0.6 * alto
