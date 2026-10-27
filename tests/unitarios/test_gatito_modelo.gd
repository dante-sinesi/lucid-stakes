extends SceneTree
## El modelo del gatito travieso (inspirado en Ama) y sus poses: tiene todas las partes que se mueven, mide lo que tiene que medir, las poses de espera (las de las fotos) y los movimientos se aplican sin
## errores y quedan dentro de una caja razonable, y mezclar poses va de una a otra (headless).
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_gatito_modelo.gd

const Gatito := preload("res://scripts/personajes/gatito_travieso.gd")
const Anim := preload("res://scripts/personajes/gatito_anim.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


## La caja que ocupa el modelo (en el espacio del modelo), mirando todas las partes con malla.
func _caja(nodo: Node3D) -> AABB:
	var out := AABB()
	var primero := true
	var pila: Array = [nodo]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		for h in n.get_children():
			pila.append(h)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var rel := Transform3D.IDENTITY   # (la transformación de la malla respecto del modelo: se multiplican las locales hasta llegar a él)
		var m: Node = mi
		while m != nodo and m is Node3D:
			rel = (m as Node3D).transform * rel
			m = m.get_parent()
		var caja: AABB = rel * mi.mesh.get_aabb()
		out = caja if primero else out.merge(caja)
		primero = false
	return out


func _init() -> void:
	var raiz := Node3D.new()
	root.add_child(raiz)
	var g := Gatito.build()
	raiz.add_child(g)
	for p in Anim.PARTES:
		var ruta: String = "cola_1/cola_2" if p == "cola_2" else ("cabeza/" + p if p.begins_with("oreja") else p)
		check(g.get_node_or_null(NodePath(ruta)) != null, "el gato tiene la parte %s" % p)
	check(g.find_child("ojo_i", true, false) != null and g.find_child("ojo_d", true, false) != null and g.find_child("cascabel", true, false) != null, "tiene ojos y cascabel")
	var reposo := _caja(g)
	check(reposo.size.y > 0.45 and reposo.size.y < 0.7 and reposo.size.z > 0.8 and reposo.size.z < 1.0 and reposo.size.x < 0.55, "mide lo que debe: cabe en un bloque, con la cola en alto (%s)" % str(reposo.size))
	check(absf(reposo.position.y) < 0.03, "los pies están en el piso (%.3f)" % reposo.position.y)
	# las poses de espera: se aplican y el gato queda apoyado (sin hundirse en el piso) y dentro de una caja razonable
	check(Anim.ESPERAS == ["sentada", "esfinge", "estirada", "bollito"], "las cuatro poses de espera de las fotos")
	for nombre in Anim.ESPERAS + ["reposo"]:
		Anim.esperar(g, nombre, 1.3)
		var c := _caja(g)
		check(c.position.y > -0.03 and c.end.y < 0.75 and c.size.x < 0.9 and c.size.z < 1.2, "pose %s: queda apoyado y dentro de una caja chica (%s %s)" % [nombre, str(c.position), str(c.size)])
	# los ojos: cerrados en las poses dormidas, abiertos en las despiertas
	Anim.esperar(g, "bollito", 0.0)
	var cerrado: float = (g.find_child("ojo_i", true, false) as Node3D).scale.y
	Anim.esperar(g, "sentada", 0.0)
	var abierto: float = (g.find_child("ojo_i", true, false) as Node3D).scale.y
	check(cerrado < 0.3 and abierto > 0.4 and abierto > cerrado, "dormido tiene los ojos cerrados (%.2f) y despierto abiertos (%.2f)" % [cerrado, abierto])
	# los movimientos
	for k in [0.0, 0.25, 0.5, 0.75, 1.0]:
		Anim.saltar(g, k)
		Anim.empujar(g, k)
	for t in [0.0, 1.0, 2.0, 3.0]:
		Anim.trotar(g, t)
		var c2 := _caja(g)
		check(c2.size.y < 0.8 and c2.size.z < 1.1, "trotar (fase %.0f) queda chico" % t)
	Anim.aplicar(g, Anim.pose("reposo"))
	var caja_reposo := _caja(g)
	check(caja_reposo.size.is_equal_approx(reposo.size), "volver al reposo deja el gato como estaba")
	# mezclar
	var a := Anim.pose("sentada")
	var b := Anim.pose("bollito")
	check((Anim.mezclar(a, b, 0.0)["cabeza"].pos as Vector3).is_equal_approx(a["cabeza"].pos) and (Anim.mezclar(a, b, 1.0)["cabeza"].pos as Vector3).is_equal_approx(b["cabeza"].pos), "mezclar va de una pose a la otra")
	var mitad: Dictionary = Anim.mezclar(a, b, 0.5)
	check(is_equal_approx(float(mitad.ojos), (float(a.ojos) + float(b.ojos)) * 0.5), "y los ojos también")
	print("tests del modelo del gatito terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
