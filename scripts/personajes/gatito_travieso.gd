extends RefCounted
## El gatito travieso: el gato de la prueba "El gatito travieso" (docs/pruebas.md y docs/gatito_travieso.md). Está inspirado en Ama, la gata de Dante: un gato de pelo largo, gris atigrado
## (rayas finas en los costados, las patas y la cola con anillos), pechera blanca, cachetes crema, "M" en la frente, orejas en punta con mechones, ojos verde claro entornados, nariz durazno
## y la cola esponjada. Es de cuatro patas, de cuerpo largo y cabeza cuadrada como los gatos de Minecraft, y lleva un collar con cascabel (la oreja derecha tiene la punta doblada).
## `build()` arma el modelo 3D (origen en los PIES, mira hacia +Z, unos 0,5 de alto y 0,55 de largo: la mitad de un personaje). Las partes que se mueven tienen nombre: `cuerpo`, `cabeza`,
## `oreja_i`, `oreja_d`, `pata_di`, `pata_dd`, `pata_ti`, `pata_td` (delanteras y traseras, izquierda y derecha), `cola_1`, `cola_2`, `cascabel`, `ojo_i` y `ojo_d`.
## Las poses y movimientos están en `gatito_anim.gd` (las poses de espera salen de las fotos de Ama).

const Cosmetics := preload("res://scripts/personajes/cosmetics.gd")

const PELO := Color(0.58, 0.56, 0.6)
const OSCURO := Color(0.33, 0.32, 0.38)
const CLARO := Color(0.94, 0.92, 0.88)
const CREMA := Color(0.82, 0.74, 0.64)
const OJO := Color(0.72, 0.84, 0.45)
const NARIZ := Color(0.88, 0.62, 0.6)
const ROSA := Color(0.92, 0.72, 0.7)
const COLLAR := Color(0.2, 0.32, 0.55)
const ORO := Color(1.0, 0.82, 0.25)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	return Cosmetics.box(parent, size, pos, color, false)


static func _pivot(parent: Node3D, nombre: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = nombre
	n.position = pos
	parent.add_child(n)
	return n


static func build() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "gatito_travieso"
	# --- el cuerpo largo y esponjoso ---
	var cuerpo := _pivot(raiz, "cuerpo", Vector3(0, 0.24, -0.02))
	_box(cuerpo, Vector3(0.21, 0.19, 0.42), Vector3(0, 0, 0), PELO)
	_box(cuerpo, Vector3(0.235, 0.15, 0.13), Vector3(0, -0.01, -0.17), PELO)   # las ancas, más anchas
	_box(cuerpo, Vector3(0.15, 0.03, 0.34), Vector3(0, -0.095, 0), CLARO)   # la panza
	for z in [-0.14, -0.05, 0.04]:   # las rayas finas del costado y del lomo
		for lado in [-1, 1]:
			_box(cuerpo, Vector3(0.014, 0.13, 0.03), Vector3(lado * 0.108, 0, z), OSCURO)
		_box(cuerpo, Vector3(0.215, 0.014, 0.03), Vector3(0, 0.097, z), OSCURO)
	_box(cuerpo, Vector3(0.17, 0.14, 0.06), Vector3(0, -0.03, 0.225), CLARO)   # la pechera esponjosa
	_box(cuerpo, Vector3(0.1, 0.06, 0.03), Vector3(0, -0.1, 0.27), CLARO)
	# --- las cuatro patas (giran desde el hombro y la cadera): grises, con una rayita y las patitas claras ---
	for z in [0.15, -0.17]:
		for lado in [-1, 1]:
			var n := "pata_%s%s" % ["d" if z > 0 else "t", "i" if lado < 0 else "d"]
			var pata := _pivot(raiz, n, Vector3(lado * 0.07, 0.15, z))
			_box(pata, Vector3(0.075, 0.15, 0.075), Vector3(0, -0.075, 0), PELO)
			_box(pata, Vector3(0.078, 0.014, 0.078), Vector3(0, -0.06, 0.002), OSCURO)
			_box(pata, Vector3(0.08, 0.045, 0.085), Vector3(0, -0.128, 0.006), CLARO)
	# --- la cabeza: cuadrada, con cachetes, "M" en la frente, ojos entornados y hocico claro ---
	var cabeza := _pivot(raiz, "cabeza", Vector3(0, 0.355, 0.235))
	_box(cabeza, Vector3(0.25, 0.21, 0.2), Vector3(0, 0, 0.06), PELO)
	for lado in [-1, 1]:   # los cachetes esponjosos
		_box(cabeza, Vector3(0.05, 0.08, 0.1), Vector3(lado * 0.145, -0.045, 0.05), CREMA)
	for k in 3:   # las rayas de la frente (la "M")
		_box(cabeza, Vector3(0.022, 0.05, 0.205), Vector3(-0.045 + 0.045 * k, 0.095, 0.06), OSCURO)
	for lado in [-1, 1]:   # las marcas a los costados de los ojos
		_box(cabeza, Vector3(0.05, 0.016, 0.02), Vector3(lado * 0.1, 0.02, 0.162), OSCURO)
	_box(cabeza, Vector3(0.11, 0.075, 0.05), Vector3(0, -0.05, 0.16), CLARO)   # el hocico
	_box(cabeza, Vector3(0.045, 0.03, 0.02), Vector3(0, -0.02, 0.19), NARIZ)   # la nariz
	for lado in [-1, 1]:   # los ojos verde claro, con la pupila vertical y el párpado a medio cerrar
		var ojo := _pivot(cabeza, "ojo_i" if lado < 0 else "ojo_d", Vector3(lado * 0.067, 0.03, 0.166))
		_box(ojo, Vector3(0.058, 0.05, 0.02), Vector3(0, 0, 0), OJO)
		_box(ojo, Vector3(0.02, 0.05, 0.022), Vector3(0, 0, 0.006), Color(0.05, 0.04, 0.06))
		_box(ojo, Vector3(0.066, 0.022, 0.024), Vector3(0, 0.022, 0.003), OSCURO)   # el párpado
	for lado in [-1, 1]:   # los bigotes
		for k in 3:
			_box(cabeza, Vector3(0.13, 0.008, 0.008), Vector3(lado * 0.19, -0.04 + 0.028 * k, 0.15), CLARO)
	# las orejas en punta, con mechones; la derecha tiene la punta doblada
	var oreja_i := _pivot(cabeza, "oreja_i", Vector3(-0.085, 0.1, 0.03))
	_box(oreja_i, Vector3(0.085, 0.11, 0.05), Vector3(0, 0.055, 0), PELO)
	_box(oreja_i, Vector3(0.045, 0.07, 0.02), Vector3(0, 0.05, 0.027), ROSA)
	_box(oreja_i, Vector3(0.02, 0.045, 0.03), Vector3(0, 0.125, 0), CLARO)   # el mechón de la punta
	var oreja_d := _pivot(cabeza, "oreja_d", Vector3(0.085, 0.1, 0.03))
	_box(oreja_d, Vector3(0.085, 0.08, 0.05), Vector3(0, 0.04, 0), PELO)
	_box(oreja_d, Vector3(0.06, 0.04, 0.05), Vector3(0.03, 0.095, 0), PELO)   # la punta doblada
	_box(oreja_d, Vector3(0.045, 0.05, 0.02), Vector3(0, 0.035, 0.027), ROSA)
	# --- el collar con su cascabel ---
	_box(cabeza, Vector3(0.265, 0.035, 0.215), Vector3(0, -0.125, 0.055), COLLAR)
	var cascabel := _pivot(cabeza, "cascabel", Vector3(0, -0.145, 0.168))
	_box(cascabel, Vector3(0.05, 0.05, 0.04), Vector3(0, -0.02, 0), ORO)
	_box(cascabel, Vector3(0.015, 0.02, 0.045), Vector3(0, -0.025, 0), Color(0.5, 0.35, 0.05))
	# --- la cola esponjada, con anillos y la punta oscura, en dos tramos ---
	var cola_1 := _pivot(raiz, "cola_1", Vector3(0, 0.28, -0.26))
	_box(cola_1, Vector3(0.09, 0.09, 0.18), Vector3(0, 0, -0.09), PELO)
	for z in [-0.05, -0.12]:
		_box(cola_1, Vector3(0.094, 0.094, 0.026), Vector3(0, 0, z), OSCURO)
	var cola_2 := _pivot(cola_1, "cola_2", Vector3(0, 0, -0.18))
	_box(cola_2, Vector3(0.09, 0.2, 0.09), Vector3(0, 0.1, 0), PELO)
	for y in [0.05, 0.12]:
		_box(cola_2, Vector3(0.094, 0.026, 0.094), Vector3(0, y, 0), OSCURO)
	_box(cola_2, Vector3(0.094, 0.06, 0.094), Vector3(0, 0.195, 0), OSCURO)
	return raiz
