extends SceneTree
## Las animaciones del personaje (scripts/personajes/animacion.gd): cada acción tiene su pose, vuelve al reposo y la acción correcta se elige según lo que pasó en la torre.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/unitarios/test_animacion.gd
const Characters := preload("res://scripts/personajes/characters.gd")
const Animacion := preload("res://scripts/personajes/animacion.gd")
const Settings := preload("res://scripts/datos/settings.gd")
const Profile := preload("res://scripts/datos/profile.gd")
const Motor := preload("res://torre/motor.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _en_reposo(m: Node3D) -> bool:
	for n in ["brazo_i", "brazo_d", "pata_i", "pata_d"]:
		if not (m.get_node(n) as Node3D).rotation.is_zero_approx():
			return false
	return m.rotation.is_zero_approx() and m.position.is_zero_approx() and m.scale.is_equal_approx(Vector3.ONE)


## Casi en reposo (respirando un poco): ningún giro grande ni escala distinta.
func _casi_reposo(m: Node3D) -> bool:
	for n in ["brazo_i", "brazo_d", "pata_i", "pata_d"]:
		if (m.get_node(n) as Node3D).rotation.length() > 0.1:
			return false
	return m.rotation.length() < 0.1 and m.position.length() < 0.05 and m.scale.is_equal_approx(Vector3.ONE)


func _init() -> void:
	Settings.set_value("animaciones_exageradas", true)
	check(Animacion.exageradas(), "por defecto las animaciones son exageradas")
	for id in ["dante", "gaby", "gato", "perro", "conejo"]:
		var m := Characters.build(id, "", "")
		var raiz := Node3D.new()
		root.add_child(raiz)
		raiz.add_child(m)
		for tipo in Animacion.TIPOS + Animacion.PASATIEMPOS:
			Animacion.pose(m, tipo, 0.25, 1.0, true)
			var se_movio := not _en_reposo(m)
			check(se_movio, "%s: la pose '%s' cambia algo del cuerpo" % [id, tipo])
			Animacion.pose(m, tipo, 0.0, 1.0, true)
			Animacion.pose(m, "reposo", 1.0)
			check(_en_reposo(m), "%s: después de '%s' el reposo deja todo en su sitio" % [id, tipo])
		# sutiles: poses más chicas y el cuerpo no se deforma
		Animacion.pose(m, "trepar", 0.1, 0.45, false)
		check(m.scale.is_equal_approx(Vector3.ONE), "%s: sutil no aplasta ni estira el cuerpo" % id)
		Animacion.pose(m, "trepar", 0.15, 1.0, true)
		check(not m.scale.is_equal_approx(Vector3.ONE), "%s: exagerada sí se aplasta al agacharse" % id)
		Animacion.pose(m, "empujar", 0.5, 0.45, false)
		var chico: float = m.rotation.x
		Animacion.pose(m, "empujar", 0.5, 1.0, true)
		check(m.rotation.x > chico, "%s: la pose sutil es más chica que la exagerada" % id)
		Animacion.pose(m, "colgado", 1.0)
		check((m.get_node("brazo_i") as Node3D).rotation.x < -2.5 and (m.get_node("brazo_i") as Node3D).rotation.z < 0.0, "%s: colgado tiene los brazos arriba y abiertos" % id)
		raiz.queue_free()
	# el animador vuelve al reposo cuando termina la acción
	var modelo := Characters.build("dante", "", "")
	var anim := Animacion.new(modelo)
	root.add_child(modelo)
	root.add_child(anim)
	anim.reproducir("empujar", 0.2)
	await create_timer(0.5).timeout
	check(_casi_reposo(modelo), "al terminar la acción el personaje vuelve al reposo")
	anim.colgado(true)
	check((modelo.get_node("brazo_d") as Node3D).rotation.x < -2.5, "colgado(true) deja los brazos arriba")
	anim.reproducir("desplazar", 0.2)
	await create_timer(0.5).timeout
	check((modelo.get_node("brazo_d") as Node3D).rotation.x < -2.5, "después de una acción colgado sigue colgado")
	anim.colgado(false)
	check(_casi_reposo(modelo), "colgado(false) vuelve al reposo")
	# las acciones de la torre eligen la animación que corresponde
	Profile.path = "user://test_profile_anim.json"
	Profile.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	for i in 4:
		await process_frame
	main.start_game()
	for i in 4:
		await process_frame
	var tj = main.torre
	check(tj.animador != null and tj.animador.modelo == tj.gato, "la torre tiene el animador del personaje")
	var cam: Array = tj.t.salas[0].d.camino
	tj.accion(Vector3i(int(cam[0][0]), 0, int(cam[0][1])), int(cam[0][2]))
	check(tj._tipo_anim in ["caminar", "trepar", "bajar", "empujar", "tirar", "colgarse", "desplazar", "resbalar", "catapulta", "desactivar"], "la primera acción de la sala tiene su animación (%s)" % tj._tipo_anim)
	var obj := _Falso.new()
	obj.desarmo = true
	check(tj._tipo_animacion(obj, Motor.Modo.MOVER, 0, Vector3i.ZERO) == "desactivar", "desarmar una bomba: desactivar")
	obj.desarmo = false
	obj.salto = true
	check(tj._tipo_animacion(obj, Motor.Modo.MOVER, 0, Vector3i.ZERO) == "catapulta", "un salto: catapulta")
	obj.salto = false
	obj.resbalo = true
	check(tj._tipo_animacion(obj, Motor.Modo.MOVER, 0, Vector3i.ZERO) == "resbalar", "resbalar por hielo")
	obj.resbalo = false
	obj.agarro = true
	obj.tipo_agarre = "pull"
	check(tj._tipo_animacion(obj, Motor.Modo.AGARRAR, 0, Vector3i.ZERO) == "tirar", "tirar un bloque")
	obj.tipo_agarre = "push"
	check(tj._tipo_animacion(obj, Motor.Modo.AGARRAR, 0, Vector3i.ZERO) == "empujar", "empujar un bloque")
	obj.agarro = false
	obj.jugador = Vector3i(0, 5, 0)
	check(tj._tipo_animacion(obj, Motor.Modo.MOVER, 3, Vector3i.ZERO) == "trepar", "subir: trepar")
	check(tj._tipo_animacion(obj, Motor.Modo.MOVER, 8, Vector3i.ZERO) == "bajar", "bajar un escalón")
	check(tj._tipo_animacion(obj, Motor.Modo.MOVER, 5, Vector3i.ZERO) == "caminar", "sobre el mismo piso: caminar")
	print("tests de las animaciones del personaje terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


## Lo mínimo de un motor para probar qué animación se elige.
class _Falso:
	var desarmo := false
	var salto := false
	var resbalo := false
	var agarro := false
	var tipo_agarre := ""
	var jugador := Vector3i.ZERO
