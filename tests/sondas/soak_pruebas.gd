extends SceneTree
## Juega torres enteras con cada prueba en el juego de verdad (con sus avisos y efectos en marcha) siguiendo la solución conocida de cada sala, y dice cuántas salas se pasaron y si algo quedó trabado o falló.
## Con el viento, el temblor y el mareo la solución puede no andar (es parte de las pruebas): lo que se busca acá son errores de código, no derrotas. Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/sondas/soak_pruebas.gd
##   Variables: PRUEBAS (lista separada por comas; por omisión, todas las nuevas), ETAPA (por omisión la de la prueba, mínimo 3).
const Profile := preload("res://scripts/datos/profile.gd")
const Trials := preload("res://scripts/datos/trials.gd")


func _init() -> void:
	Profile.path = "user://soak_profile.json"
	Profile.reset()
	Profile.mark_tutorial_done()
	var ids: Array = ["mareo", "corrupcion", "memoria_pez", "terremoto", "presupuesto", "solo_tres", "espalda_mala", "ventisca", "quebradizo", "a_oscuras", "pesadilla_despierta"]
	if OS.get_environment("PRUEBAS") != "":
		ids = OS.get_environment("PRUEBAS").split(",")
	Engine.time_scale = 6.0
	for id in ids:
		var etapa: int = int(OS.get_environment("ETAPA")) if OS.get_environment("ETAPA") != "" else maxi(3, int((Trials.CATALOG[id] as Dictionary).get("desde", 3)))
		await _soak(id, etapa)
	Engine.time_scale = 1.0
	quit()


func _soak(id: String, etapa: int) -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	for k in 4:
		await process_frame
	main.start_game("pesadilla", "media")
	for k in 4:
		await process_frame
	while main.generating or main.torre == null:
		await process_frame
	main.run.trial_schedule = {etapa: id}
	main.stage_number = etapa
	main.run.stage = etapa
	main.run.lives = 99
	main.new_tower(11 + etapa)
	for k in 6:
		await process_frame
	while main.generating or main.torre == null:
		await process_frame
	var torre = main.torre
	var salas_total: int = torre.t.salas.size()
	var acciones := 0
	var fallidas := 0
	var tope := 0
	while torre != null and is_instance_valid(torre) and not torre.t.terminada and tope < 2500:
		tope += 1
		if torre.gatito_actuando or torre._efecto_en_curso or torre.t.muerta:
			if torre.t.muerta:
				torre.t.reintentar_sala()
				torre._refrescar(false)
			await process_frame
			continue
		var d: Dictionary = torre.t.sala_actual().d
		var movs_hechos: int = torre.t.deshacer_pila.size()
		var camino: Array = d.get("camino", [])
		if movs_hechos >= camino.size():
			torre.t.reintentar_sala()   # (la solución conocida ya no alcanza: se vuelve a empezar la sala)
			torre._refrescar(false)
			fallidas += 1
			continue
		var a: Array = camino[movs_hechos]
		var r: Dictionary = torre.accion(Vector3i(int(a[0]), 0, int(a[1])), int(a[2]))
		acciones += 1
		if not bool(r.ok) and not torre._efecto_en_curso:
			torre.t.reintentar_sala()
			torre._refrescar(false)
			fallidas += 1
		await create_timer(0.4).timeout
	var viva: bool = torre != null and is_instance_valid(torre)
	var trabado: bool = viva and torre._efecto_en_curso
	var llego: bool = not viva or torre.t.terminada   # (al llegar al portal el juego cierra la torre)
	print("%s (etapa %d): salas %d, llegó al portal %s, acciones %d, salas rehechas %d, efecto trabado %s" % [id, etapa, salas_total, str(llego), acciones, fallidas, str(trabado)])
	main.queue_free()
	await process_frame
