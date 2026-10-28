extends RefCounted
## Ama y Farolín (docs/gatito_travieso.md, segunda etapa): lo que hace la gata mientras espera en el checkpoint, junto a Farolín (prueba Travesuras). Cada travesura es una corutina que usa
## las partes del juego (`j` es `torre_juego.gd`: sus nodos `gatito_nodo`, `gatito_modelo`, `farolin` y `faro_modelo`) y se corta sola si `vivo` deja de valer (se cambió de sala); al cortarse
## deja todo en su sitio (`limpiar`). Las travesuras: `mirar_llama` (persigue la llama con la mirada), `frotarse` (se frota contra él y ronronea) y `sombrero` (le roba el sombrero, que es la
## tapa del farol, y se lo devuelve); `acurrucarse` es el final de la espera: se duerme apoyada en él y Farolín baja la llama.
## Geometría: Farolín se sienta en la esquina `_faro_esquina` del bloque de salida (a 0,27 de cada eje del centro) y Ama espera del otro lado (a -0,17).

const GatitoAnim := preload("res://scripts/personajes/gatito_anim.gd")
const Sfx := preload("res://scripts/sonido/sfx.gd")

const TRAVESURAS := ["mirar_llama", "frotarse", "sombrero"]


## Hace la travesura `nombre`. Devuelve false si se cortó.
static func hacer(nombre: String, j, vivo: Callable) -> bool:
	var ok := true
	match nombre:
		"mirar_llama":
			ok = await mirar_llama(j, vivo)
		"frotarse":
			ok = await frotarse(j, vivo)
		"sombrero":
			ok = await sombrero(j, vivo)
	if not ok:
		limpiar(j)
	return ok


## Lo deja todo como estaba: el sombrero en Farolín, contento y despierto.
static func limpiar(j) -> void:
	if j.faro_modelo != null and is_instance_valid(j.faro_modelo):
		j.faro_modelo.sombrero_devolver()
		j.faro_modelo.set_mood("contento")
		j.faro_modelo.dormir(false)


# --- geometría y ayudas -------------------------------------------------------------------------------------------------------------------

static func _esq(j) -> Vector3:
	return Vector3(j._faro_esquina.x, 0.0, j._faro_esquina.y)


## Dónde espera Ama (su sitio de siempre, del otro lado del bloque).
static func sitio(j) -> Vector3:
	return j.farolin.position - 0.17 * _esq(j)


## Un lugar junto a Farolín, a `dist` de él hacia el centro del bloque.
static func junto_a_farolin(j, dist: float) -> Vector3:
	return j.farolin.position + 0.27 * _esq(j) - _esq(j).normalized() * dist


static func _llama(j) -> Vector3:
	return j.faro_modelo.global_position + Vector3(0, 0.2, 0)


static func _mirando_a_farolin(j) -> float:
	return atan2(float(j._faro_esquina.x), float(j._faro_esquina.y))


## Corre `f(k, t)` (k de 0 a 1, t en segundos) durante `dur` segundos, un cuadro a la vez. false si `vivo` dejó de valer.
static func _durante(j, dur: float, f: Callable, vivo: Callable) -> bool:
	var t := 0.0
	while t < dur:
		if not vivo.call():
			return false
		await j.get_tree().process_frame
		t += j.get_process_delta_time()
		f.call(minf(t / dur, 1.0), t)
	return vivo.call()


## Lleva a Ama de donde está a `destino` trotando (y mirando hacia adónde va); al llegar mira hacia `mirada` (giro en y).
static func _trotar_a(j, destino: Vector3, dur: float, mirada: float, vivo: Callable) -> bool:
	var origen: Vector3 = j.gatito_nodo.position
	var d := destino - origen
	var rumbo: float = j.gatito_nodo.rotation.y
	if absf(d.x) + absf(d.z) > 0.01:
		rumbo = atan2(d.x, d.z)
	var ok: bool = await _durante(j, dur, func(k: float, t: float) -> void:
		j.gatito_nodo.position = origen.lerp(destino, smoothstep(0.0, 1.0, k)) + Vector3(0, absf(sin(t * 14.0)) * 0.02, 0)
		j.gatito_nodo.rotation.y = lerp_angle(j.gatito_nodo.rotation.y, rumbo if k < 0.85 else mirada, 0.3)
		GatitoAnim.trotar(j.gatito_modelo, t * 14.0), vivo)
	j.gatito_nodo.position = destino
	return ok


static func _pose(j, nombre: String, ajustes := {}) -> void:
	var p := GatitoAnim.pose(nombre)
	for parte in ajustes:
		if parte == "ojos":
			p["ojos"] = ajustes[parte]
		else:
			for campo in ajustes[parte]:
				p[parte][campo] = ajustes[parte][campo]
	GatitoAnim.aplicar(j.gatito_modelo, p)


## Un cambio suave de la pose actual del modelo a otra (en `dur` segundos).
static func _a_pose(j, nombre: String, dur: float, vivo: Callable) -> bool:
	var desde := GatitoAnim.pose("sentada")   # (casi siempre se sale de una pose sentada)
	var hasta := GatitoAnim.pose(nombre)
	return await _durante(j, dur, func(k: float, _t: float) -> void: GatitoAnim.aplicar(j.gatito_modelo, GatitoAnim.mezclar(desde, hasta, smoothstep(0.0, 1.0, k))), vivo)


# --- las travesuras ------------------------------------------------------------------------------------------------------------------------

## Persigue la llama con la mirada: la cabeza sigue el titilar del farol, los ojos bien abiertos y la colita inquieta; Farolín la mira de vuelta.
static func mirar_llama(j, vivo: Callable) -> bool:
	var d: Vector3 = _llama(j) - j.gatito_nodo.global_position
	var rel := rad_to_deg(wrapf(atan2(d.x, d.z) - j.gatito_nodo.rotation.y, -PI, PI))
	j.faro_modelo.reaccionar("mirar")
	return await _durante(j, 3.2, func(k: float, t: float) -> void:
		var env := minf(minf(k * 6.0, (1.0 - k) * 6.0), 1.0)
		var p := GatitoAnim.pose("sentada")
		(p["cabeza"] as Dictionary).rot = Vector3(lerpf(8.0, -8.0 + sin(t * 5.0) * 5.0, env), lerpf(28.0, rel + sin(t * 3.7) * 16.0, env), 0.0)
		(p["cola_1"] as Dictionary).rot = (p["cola_1"].rot as Vector3) + Vector3(0, sin(t * 9.0) * 24.0 * env, 0)
		(p["cuerpo"] as Dictionary).rot = (p["cuerpo"].rot as Vector3) + Vector3(0, 0, sin(t * 7.0) * 4.0 * env)
		p["ojos"] = lerpf(0.62, 1.35, env)
		GatitoAnim.aplicar(j.gatito_modelo, p), vivo)


## Se frota contra Farolín yendo y viniendo, con la cola en alto y los ojitos cerrados, y ronronea (el cuerpo vibra y la llama brilla más).
static func frotarse(j, vivo: Callable) -> bool:
	var esq := _esq(j)
	var cerca := junto_a_farolin(j, 0.2)
	var tangente := Vector3(-esq.z, 0.0, esq.x).normalized()
	var mirada := _mirando_a_farolin(j)
	if not await _trotar_a(j, cerca, 0.7, mirada, vivo):
		return false
	j.faro_modelo.reaccionar("mirar")
	j.faro_modelo.ronronear(2.8)
	var ok: bool = await _durante(j, 2.8, func(k: float, t: float) -> void:
		var env := minf(minf(k * 5.0, (1.0 - k) * 5.0), 1.0)
		var vaiven := sin(t * 4.2)
		j.gatito_nodo.position = cerca + tangente * vaiven * 0.11 * env
		j.gatito_nodo.rotation.y = mirada + vaiven * 0.5 * env
		var p := GatitoAnim.pose("reposo")
		(p["cabeza"] as Dictionary).rot = Vector3(14.0 * env, -vaiven * 22.0 * env, 0.0)
		(p["cola_1"] as Dictionary).rot = Vector3(-62.0 * env, sin(t * 3.0) * 12.0 * env, 0.0)
		(p["cola_2"] as Dictionary).rot = Vector3(-24.0 * env, 0, 0)
		(p["cuerpo"] as Dictionary).esc = Vector3(1.0, 1.0 + sin(t * 70.0) * 0.012 * env, 1.0)   # (el ronroneo)
		p["ojos"] = lerpf(1.0, 0.2, env)
		GatitoAnim.aplicar(j.gatito_modelo, p), vivo)
	if not ok:
		return false
	return await _volver_a_su_sitio(j, vivo)


static func _volver_a_su_sitio(j, vivo: Callable) -> bool:
	if not await _trotar_a(j, sitio(j), 0.7, _mirando_a_farolin(j), vivo):
		return false
	return await _a_pose(j, "sentada", 0.5, vivo)


## Le roba el sombrero: se hace la distraída, se acerca, se para en dos patas, se lo saca y se lo lleva puesto; después de lucirlo se lo devuelve.
static func sombrero(j, vivo: Callable) -> bool:
	var faro = j.faro_modelo
	if faro.sombrero == null:
		return true
	var mirada := _mirando_a_farolin(j)
	# la distraída: mira para otro lado, silbando con la cola
	if not await _durante(j, 1.1, func(k: float, t: float) -> void:
		var env := minf(minf(k * 5.0, (1.0 - k) * 5.0), 1.0)
		var p := GatitoAnim.pose("sentada")
		(p["cabeza"] as Dictionary).rot = Vector3(-6.0 * env + 8.0, lerpf(28.0, -75.0, env), 0.0)
		(p["cola_1"] as Dictionary).rot = (p["cola_1"].rot as Vector3) + Vector3(0, sin(t * 10.0) * 30.0 * env, 0)
		p["ojos"] = lerpf(0.62, 0.9, env)
		GatitoAnim.aplicar(j.gatito_modelo, p), vivo):
		return false
	var al_lado := junto_a_farolin(j, 0.17)
	if not await _trotar_a(j, al_lado, 0.65, mirada, vivo):
		return false
	# se para en dos patas y estira la patita hasta el sombrero
	if not await _durante(j, 0.55, func(k: float, _t: float) -> void:
		var p := GatitoAnim.pose("sentada")
		(p["pata_dd"] as Dictionary).rot = Vector3(-150.0 * smoothstep(0.0, 1.0, k), 0, 0)
		(p["cabeza"] as Dictionary).rot = Vector3(-12.0 * k, 0, 0)
		p["ojos"] = 1.2
		GatitoAnim.aplicar(j.gatito_modelo, p), vivo):
		return false
	# el robo: el sombrero vuela hasta la cabeza de Ama y Farolín se sorprende
	faro.reaccionar("saludo")
	faro.set_mood("triste")
	var cabeza: Node3D = j.gatito_modelo.get_node("cabeza")
	if not await _volar(j, faro.sombrero, cabeza, Vector3(0, 0.12, 0.05), 0.65, 0.4, vivo):
		return false
	Sfx.play("ding", 1.9, -12.0)
	# se lo lleva puesto, orgullosa
	if not await _trotar_a(j, sitio(j), 0.75, mirada, vivo):
		return false
	if not await _durante(j, 2.4, func(k: float, t: float) -> void:
		var env := minf(minf(k * 6.0, (1.0 - k) * 6.0), 1.0)
		var p := GatitoAnim.pose("sentada")
		(p["cabeza"] as Dictionary).rot = Vector3(-10.0 * env + 8.0, lerpf(28.0, sin(t * 2.0) * 22.0, env), 0.0)
		(p["cola_1"] as Dictionary).rot = (p["cola_1"].rot as Vector3) + Vector3(0, sin(t * 6.0) * 22.0, 0)
		p["ojos"] = lerpf(0.62, 0.5, env)
		GatitoAnim.aplicar(j.gatito_modelo, p), vivo):
		return false
	# se lo devuelve (Farolín vuelve a estar contento y se rasca la cabeza)
	if not await _trotar_a(j, al_lado, 0.65, mirada, vivo):
		return false
	var origen: Vector3 = faro.sombrero_origen()
	if not await _volar(j, faro.sombrero, faro, origen, 1.0, 0.4, vivo):
		return false
	faro.sombrero_devolver()
	faro.set_mood("contento")
	faro.reaccionar("rascar")
	return await _volver_a_su_sitio(j, vivo)


## El sombrero vuela de donde está a `destino` (local del nuevo padre) en un arco; `esc` es su tamaño al llegar.
static func _volar(j, sombrero_nodo: Node3D, nuevo_padre: Node3D, destino: Vector3, esc: float, dur: float, vivo: Callable) -> bool:
	sombrero_nodo.reparent(nuevo_padre, true)   # (sigue donde está y se mueve desde ahí)
	var desde := sombrero_nodo.position
	var esc0 := sombrero_nodo.scale
	var rot0 := sombrero_nodo.rotation
	var ok: bool = await _durante(j, dur, func(k: float, _t: float) -> void:
		var s := smoothstep(0.0, 1.0, k)
		sombrero_nodo.position = desde.lerp(destino, s) + Vector3(0, sin(PI * k) * 0.14, 0)
		sombrero_nodo.scale = esc0.lerp(Vector3.ONE * esc, s)
		sombrero_nodo.rotation = rot0.lerp(Vector3.ZERO, s) + Vector3(0, 0, sin(PI * k) * 0.5), vivo)
	if ok:
		sombrero_nodo.position = destino
		sombrero_nodo.rotation = Vector3.ZERO
		sombrero_nodo.scale = Vector3.ONE * esc
	return ok


## El final de la espera: Ama se acomoda pegada a Farolín y se duerme apoyada en él (hecha un bollito); Farolín baja la llama y se queda quieto con ella.
static func acurrucarse(j, vivo: Callable) -> bool:
	var pegada := junto_a_farolin(j, 0.15)
	if not await _trotar_a(j, pegada, 0.8, _mirando_a_farolin(j), vivo):
		return false
	j.faro_modelo.dormir(true)
	return true
