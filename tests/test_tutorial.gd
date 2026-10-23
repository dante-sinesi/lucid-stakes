extends SceneTree
## Pruebas del tutorial: cada lección es una sala chica que se resuelve y que obliga a usar la técnica que enseña (con el solucionador), y el flujo dentro del juego.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_tutorial.gd

const Tutorial := preload("res://scripts/tutorial.gd")
const Solucionador := preload("res://salas_nuevas/solucionador.gd")
const Vista := preload("res://salas_nuevas/vista.gd")
const Story := preload("res://scripts/story.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_lessons()
	await test_flow()
	print("tests del tutorial terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func _resolver(d: Dictionary, modos := [0, 1, 2], prohibir := "") -> Dictionary:
	return Solucionador.resolver(Vista.motor_de(d), 300000, modos, prohibir)


func test_lessons() -> void:
	check(Tutorial.count() == 7 and Tutorial.lessons()[Tutorial.count() - 1].has("generated"), "hay 7 lecciones y la última es una torre de verdad")
	for i in Tutorial.count():
		var l: Dictionary = Tutorial.lessons()[i]
		check(Story.lesson_say(str(l.id), "") != "" or str(l.id) == "torre", "la lección %s tiene lo que dice el tabernero" % l.id)
		if l.has("generated"):
			check(Tutorial.sala(i) == null, "la torre de verdad no trae sala armada")
			continue
		var d: Dictionary = Tutorial.sala(i)
		check(not d.is_empty() and d.bloques.size() > 0 and d.jugador[1] >= 2, "la lección %s trae su sala" % l.id)
		if l.get("complete", "") == "keys":
			check(not _resolver(d).ok, "la lección %s no se gana caminando: se completa con las teclas" % l.id)
			continue
		var r := _resolver(d)
		check(r.ok and r.moves <= 14, "la lección %s se resuelve (%d pasos)" % [l.id, r.moves if r.ok else -1])
		for modo in l.get("needs", []):
			var sin: Array = [0, 1, 2]
			sin.erase(modo)
			check(not _resolver(d, sin).ok, "la lección %s no se resuelve sin la técnica que enseña" % l.id)
		match str(l.mode):
			"pull":
				check(not _resolver(d, [0, 1, 2], "pull").ok and _resolver(d, [0, 1, 2], "push").ok, "tirar es imprescindible en la lección de tirar (y empujar no sirve)")
	# moverse obliga a usar las cuatro direcciones
	var dirs := {}
	for a in _resolver(Tutorial.sala(0), [0]).path:
		dirs[a[0]] = true
	check(dirs.size() == 4, "la primera lección obliga a usar las cuatro direcciones")


func test_flow() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	await process_frame
	while main.generating or main.nueva == null:
		await process_frame
	await main.start_tutorial(1, true)   # la lección de la cámara se completa con las teclas
	check(main.tutorial_index == 1 and main.nueva != null and main.nueva.salas_fijas.size() == 1, "la lección es una sala armada a mano")
	main.key_hint.show_help("Pulsa {camara_arriba} {camara_izquierda} {camara_abajo} {camara_derecha}", "camera")
	for id in ["camara_arriba", "camara_izquierda", "camara_abajo", "camara_derecha"]:
		main._tutorial_camara(id)
	for i in 4:
		await process_frame
	check(main.tutorial_index == 2, "al usar las cuatro teclas de la cámara se pasa a la lección siguiente")
	# la lección de empujar: se juega la solución y pasa a la siguiente
	check(main.nueva != null and str(Tutorial.lessons()[main.tutorial_index].id) == "empujar", "ahora es la lección de empujar")
	var r := _resolver(Tutorial.sala(2))
	for a in r.path:
		main.nueva.accion(a[0], int(a[1]))
	for i in 4:
		await process_frame
	check(main.tutorial_index == 3, "al llegar al portal de la lección se pasa a la siguiente")
	main.queue_free()
	await process_frame
