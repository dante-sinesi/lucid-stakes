extends RefCounted
## El gatito travieso: el gato de la prueba "El gatito travieso" (docs/pruebas.md). Un gato de cuatro patas, de cuerpo largo y cabeza cuadrada como los de Minecraft, pero con personalidad propia:
## orejas desparejas (una con la punta doblada), ojos de distinto color, cascabel en el cuello, una mirada pícara y la cola con la punta en gancho.
## `build(variante)` arma el modelo 3D (origen en los PIES, mira hacia +Z, mide unos 0,5 de alto y 0,5 de largo: la mitad de un personaje). Las partes que se mueven tienen nombre:
## "cabeza", "oreja_i", "oreja_d", "pata_di", "pata_dd", "pata_ti", "pata_td" (delanteras y traseras, izquierda y derecha), "cola_1", "cola_2" y "cascabel".
## Hay tres diseños para elegir (`VARIANTES`): el atigrado gris, el de smoking y el siamés.

const Cosmetics := preload("res://scripts/personajes/cosmetics.gd")

## Los diseños: colores de cada parte y el dibujo del pelo. `ojo_i` y `ojo_d` son los ojos (distintos en el atigrado y en el siamés).
const VARIANTES := [
	{"id": "atigrado", "nombre": "Atigrado", "pelo": Color(0.55, 0.55, 0.6), "claro": Color(0.93, 0.92, 0.9), "oscuro": Color(0.3, 0.3, 0.35), "rayas": true, "medias": true, "pecho": true,
		"ojo_i": Color(0.35, 0.85, 0.4), "ojo_d": Color(1.0, 0.75, 0.2), "nariz": Color(1.0, 0.6, 0.65), "collar": Color(0.85, 0.15, 0.2)},
	{"id": "smoking", "nombre": "Smoking", "pelo": Color(0.13, 0.13, 0.16), "claro": Color(0.97, 0.97, 0.97), "oscuro": Color(0.06, 0.06, 0.08), "rayas": false, "medias": true, "pecho": true, "bigote": true,
		"ojo_i": Color(1.0, 0.85, 0.25), "ojo_d": Color(1.0, 0.85, 0.25), "nariz": Color(1.0, 0.6, 0.7), "collar": Color(0.2, 0.45, 0.9)},
	{"id": "siames", "nombre": "Siamés", "pelo": Color(0.93, 0.87, 0.76), "claro": Color(0.98, 0.95, 0.9), "oscuro": Color(0.38, 0.27, 0.2), "rayas": false, "medias": false, "pecho": false, "mascara": true,
		"ojo_i": Color(0.4, 0.7, 1.0), "ojo_d": Color(0.4, 0.7, 1.0), "nariz": Color(0.45, 0.3, 0.3), "collar": Color(0.2, 0.7, 0.4)},
]


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	return Cosmetics.box(parent, size, pos, color, false)


static func _pivot(parent: Node3D, nombre: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = nombre
	n.position = pos
	parent.add_child(n)
	return n


static func build(variante := 0) -> Node3D:
	var v: Dictionary = VARIANTES[clampi(variante, 0, VARIANTES.size() - 1)]
	var pelo: Color = v.pelo
	var claro: Color = v.claro
	var oscuro: Color = v.oscuro
	var raiz := Node3D.new()
	raiz.name = "gatito_travieso"
	# --- el cuerpo largo, horizontal ---
	_box(raiz, Vector3(0.2, 0.17, 0.42), Vector3(0, 0.235, -0.02), pelo)
	if bool(v.get("rayas", false)):   # las rayas del lomo
		for k in 3:
			_box(raiz, Vector3(0.205, 0.025, 0.05), Vector3(0, 0.325, -0.12 + 0.1 * k), oscuro)
	if bool(v.get("pecho", false)):   # el pecho claro
		_box(raiz, Vector3(0.12, 0.1, 0.03), Vector3(0, 0.22, 0.2), claro)
	# --- las cuatro patas (giran desde la cadera y el hombro) ---
	for z in [0.15, -0.17]:
		for lado in [-1, 1]:
			var n := "pata_%s%s" % ["d" if z > 0 else "t", "i" if lado < 0 else "d"]
			var pata := _pivot(raiz, n, Vector3(lado * 0.07, 0.15, z))
			_box(pata, Vector3(0.07, 0.15, 0.07), Vector3(0, -0.075, 0), pelo)
			if bool(v.get("medias", false)):   # las medias
				_box(pata, Vector3(0.075, 0.05, 0.075), Vector3(0, -0.125, 0.003), claro)
			elif bool(v.get("mascara", false)):   # el siamés tiene las patas oscuras
				_box(pata, Vector3(0.075, 0.1, 0.075), Vector3(0, -0.1, 0.003), oscuro)
	# --- la cabeza (cuadrada, con orejas, ojos y hocico) ---
	var cabeza := _pivot(raiz, "cabeza", Vector3(0, 0.34, 0.24))
	_box(cabeza, Vector3(0.24, 0.2, 0.2), Vector3(0, 0, 0.06), pelo)
	if bool(v.get("rayas", false)):   # las rayitas de la frente
		for k in 3:
			_box(cabeza, Vector3(0.025, 0.04, 0.205), Vector3(-0.04 + 0.04 * k, 0.1, 0.06), oscuro)
	if bool(v.get("mascara", false)):   # la máscara oscura
		_box(cabeza, Vector3(0.14, 0.12, 0.03), Vector3(0, -0.02, 0.165), oscuro)
	_box(cabeza, Vector3(0.11, 0.075, 0.05), Vector3(0, -0.045, 0.16), claro if not bool(v.get("mascara", false)) else oscuro)   # el hocico
	_box(cabeza, Vector3(0.045, 0.03, 0.02), Vector3(0, -0.015, 0.19), v.nariz)   # la nariz
	# los ojos (de distinto color en el atigrado), medio entornados: una mirada pícara
	for lado in [-1, 1]:
		var color_ojo: Color = v.ojo_i if lado < 0 else v.ojo_d
		_box(cabeza, Vector3(0.05, 0.05, 0.02), Vector3(lado * 0.065, 0.035, 0.165), color_ojo)
		_box(cabeza, Vector3(0.022, 0.05, 0.022), Vector3(lado * 0.065, 0.035, 0.172), Color(0.05, 0.03, 0.06))   # la pupila vertical
		_box(cabeza, Vector3(0.06, 0.018, 0.022), Vector3(lado * 0.065, 0.065, 0.168), oscuro)   # el párpado: la mirada de reojo
	for lado in [-1, 1]:   # los bigotes
		for k in 2:
			_box(cabeza, Vector3(0.12, 0.01, 0.01), Vector3(lado * 0.17, -0.03 + 0.03 * k, 0.15), claro)
	if bool(v.get("bigote", false)):   # el bigote blanco del smoking
		_box(cabeza, Vector3(0.16, 0.03, 0.025), Vector3(0, -0.075, 0.17), claro)
	# las orejas desparejas: la derecha tiene la punta doblada (una oreja que se rompió en alguna travesura)
	var oreja_i := _pivot(cabeza, "oreja_i", Vector3(-0.08, 0.1, 0.03))
	_box(oreja_i, Vector3(0.08, 0.09, 0.05), Vector3(0, 0.045, 0), oscuro if bool(v.get("mascara", false)) else pelo)
	_box(oreja_i, Vector3(0.04, 0.05, 0.02), Vector3(0, 0.04, 0.026), Color(1.0, 0.7, 0.75))
	var oreja_d := _pivot(cabeza, "oreja_d", Vector3(0.08, 0.1, 0.03))
	_box(oreja_d, Vector3(0.08, 0.07, 0.05), Vector3(0, 0.035, 0), oscuro if bool(v.get("mascara", false)) else pelo)
	_box(oreja_d, Vector3(0.06, 0.035, 0.05), Vector3(0.025, 0.085, 0), oscuro if bool(v.get("mascara", false)) else pelo)   # la punta doblada
	_box(oreja_d, Vector3(0.04, 0.04, 0.02), Vector3(0, 0.03, 0.026), Color(1.0, 0.7, 0.75))
	# --- el collar con su cascabel ---
	_box(cabeza, Vector3(0.25, 0.04, 0.205), Vector3(0, -0.12, 0.05), v.collar)
	var cascabel := _pivot(cabeza, "cascabel", Vector3(0, -0.14, 0.16))
	_box(cascabel, Vector3(0.05, 0.05, 0.04), Vector3(0, -0.02, 0), Color(1.0, 0.82, 0.2))
	_box(cascabel, Vector3(0.015, 0.02, 0.045), Vector3(0, -0.025, 0), Color(0.5, 0.35, 0.05))
	# --- la cola larga, en dos tramos, con la punta en gancho ---
	var cola_1 := _pivot(raiz, "cola_1", Vector3(0, 0.27, -0.23))
	_box(cola_1, Vector3(0.06, 0.06, 0.16), Vector3(0, 0, -0.08), pelo)
	var cola_2 := _pivot(cola_1, "cola_2", Vector3(0, 0, -0.16))
	_box(cola_2, Vector3(0.06, 0.16, 0.06), Vector3(0, 0.08, 0), pelo)
	_box(cola_2, Vector3(0.062, 0.06, 0.062), Vector3(0, 0.165, 0), claro if bool(v.get("rayas", false)) or bool(v.get("medias", false)) else oscuro)   # la punta
	_box(cola_2, Vector3(0.06, 0.06, 0.06), Vector3(0, 0.185, 0.05), claro if bool(v.get("rayas", false)) or bool(v.get("medias", false)) else oscuro)   # el gancho
	return raiz
