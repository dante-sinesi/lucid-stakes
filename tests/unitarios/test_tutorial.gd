extends SceneTree
## Pruebas del tutorial: cada lección es una sala chica que se resuelve y que obliga a usar la técnica que enseña (con el solucionador), y el flujo dentro del juego.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_tutorial.gd

const Tutorial := preload("res://scripts/datos/tutorial.gd")
const Solucionador := preload("res://torre/solucionador.gd")
const Vista := preload("res://torre/vista.gd")
const Story := preload("res://scripts/datos/story.gd")

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
	check(Tutorial.count() == 6 and Tutorial.lessons()[Tutorial.count() - 1].has("generated"), "hay 6 lecciones y la última es una torre de verdad")
	check(str(Tutorial.lessons()[0].id) == "camara", "moverse se aprende en la taberna: la primera lección es la cámara")
	for i in Tutorial.count():
		var l: Dictionary = Tutorial.lessons()[i]
		check(Story.lesson_say(str(l.id), "") != "" or str(l.id) == "torre", "la lección %s tiene lo que dice el tabernero" % l.id)
		check(not l.has("complete"), "ninguna lección se completa con las teclas: todas con llegar al portal")
		if l.has("generated"):
			check(Tutorial.sala(i) == null, "la torre de verdad no trae sala armada")
			continue
		var d: Dictionary = Tutorial.sala(i)
		check(not d.is_empty() and d.bloques.size() > 0 and d.jugador[1] >= 2, "la lección %s trae su sala" % l.id)
		var r := _resolver(d)
		check(r.ok and r.moves <= 14, "la lección %s se resuelve (%d pasos)" % [l.id, r.moves if r.ok else -1])
		for modo in l.get("needs", []):
			var sin: Array = [0, 1, 2]
			sin.erase(modo)
			check(not _resolver(d, sin).ok, "la lección %s no se resuelve sin la técnica que enseña" % l.id)
		match str(l.mode):
			"pull":
				check(not _resolver(d, [0, 1, 2], "pull").ok and _resolver(d, [0, 1, 2], "push").ok, "tirar es imprescindible en la lección de tirar (y empujar no sirve)")
		# el portal queda a la altura del personaje: al bloque dorado se llega subiendo un escalón desde un bloque de al lado (se entra de costado, no desde el suelo)
		var f: Array = []
		var bloques := {}
		for b in d.bloques:
			bloques[Vector3i(int(b[0]), int(b[1]), int(b[2]))] = str(b[3])
			if str(b[3]) == "f":
				f = b
		var fc := Vector3i(int(f[0]), int(f[1]), int(f[2]))
		var apoyo := false
		for dir in [Vector3i(1, -1, 0), Vector3i(-1, -1, 0), Vector3i(0, -1, 1), Vector3i(0, -1, -1)]:
			if bloques.has(fc + dir):
				apoyo = true
		check(apoyo, "la lección %s: el portal está un escalón más arriba del camino (a la altura del personaje)" % l.id)


func test_flow() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	await process_frame
	while main.generating or main.torre == null:
		await process_frame
	await main.start_tutorial(0, true)   # la lección de la cámara: se gana llegando al portal (no con las teclas)
	check(main.tutorial_index == 0 and main.torre != null and main.torre.salas_fijas.size() == 1, "la lección es una sala armada a mano")
	check(not main.has_method("tutorial_locked"), "no hay bloqueo por teclas: llegar al portal alcanza")
	var r0 := _resolver(Tutorial.sala(0))
	for a in r0.path:
		main.torre.accion(a[0], int(a[1]))
	for i in 4:
		await process_frame
	check(main.tutorial_index == 1, "al llegar al portal de la cámara, sin usar ninguna tecla de cámara, se pasa a la lección siguiente (no se repite)")
	check(main.torre != null and str(Tutorial.lessons()[main.tutorial_index].id) == "empujar", "ahora es la lección de empujar")
	var r := _resolver(Tutorial.sala(1))
	for a in r.path:
		main.torre.accion(a[0], int(a[1]))
	for i in 4:
		await process_frame
	check(main.tutorial_index == 2, "al llegar al portal de la lección se pasa a la siguiente")
	main.queue_free()
	await process_frame
