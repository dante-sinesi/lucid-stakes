extends SceneTree
## Pruebas de qué dirección de la grilla mueve cada tecla (W, D, S, A) según el giro de la cámara (headless).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_key_dirs.gd

const KeyDirs := preload("res://scripts/entrada/key_dirs.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	# la vista isométrica por defecto (45°): W arriba a la derecha, D abajo a la derecha, S abajo a la izquierda, A arriba a la izquierda
	var d45 := KeyDirs.assign(45.0)
	check(d45[0] == Vector2i(0, -1) and d45[1] == Vector2i(1, 0) and d45[2] == Vector2i(0, 1) and d45[3] == Vector2i(-1, 0), "en la isométrica por defecto W va al fondo, D a la derecha, S hacia la cámara y A a la izquierda")
	check(KeyDirs.dir_for(45.0, 1, 1) == d45[0] and KeyDirs.dir_for(45.0, 1, -1) == d45[1] and KeyDirs.dir_for(45.0, -1, -1) == d45[2] and KeyDirs.dir_for(45.0, -1, 1) == d45[3], "dir_for devuelve la de cada tecla")
	# con la cámara alineada a un eje (yaw 0, 90, 180, 270) W es la dirección que sube derecho en la pantalla, D la de la derecha...
	for yaw in [0.0, 90.0, 180.0, 270.0]:
		var d := KeyDirs.assign(yaw)
		check(absf(KeyDirs.screen_angle(d[0], yaw)) < 1.0 or absf(absf(KeyDirs.screen_angle(d[0], yaw)) - 360.0) < 1.0, "con la cámara en %d° W sube derecho (%.0f°)" % [int(yaw), KeyDirs.screen_angle(d[0], yaw)])
		check(is_equal_approx(KeyDirs.screen_angle(d[1], yaw), 90.0) and is_equal_approx(absf(KeyDirs.screen_angle(d[2], yaw)), 180.0) and is_equal_approx(KeyDirs.screen_angle(d[3], yaw), -90.0), "y D va a la derecha, S abajo y A a la izquierda (%d°)" % int(yaw))
	# en cualquier giro: W queda dentro de (-37°, 53°] de "arriba", las cuatro direcciones son distintas y siguen el sentido de las agujas
	var yaw := 0.0
	while yaw < 360.0:
		var d := KeyDirs.assign(yaw)
		var a := KeyDirs.screen_angle(d[0], yaw)
		check(a > -37.0 - 0.001 and a <= 53.0 + 0.001, "yaw %.0f: W queda arriba (%.1f°)" % [yaw, a])
		var set := {}
		for v in d:
			set[v] = true
		check(set.size() == 4, "yaw %.0f: las cuatro teclas van a cuatro ejes distintos" % yaw)
		for k in 4:
			var from := KeyDirs.screen_angle(d[k], yaw)
			var to := KeyDirs.screen_angle(d[(k + 1) % 4], yaw)
			check(is_equal_approx(fposmod(to - from, 360.0), 90.0), "yaw %.0f: %d -> %d sigue las agujas del reloj" % [yaw, k, (k + 1) % 4])
		yaw += 7.0
	# el caso del tutorial: un eje apunta casi derecho hacia arriba (un poco a la izquierda) y el otro hacia la derecha: W tiene que ser el de arriba
	var yaw_case := 100.0
	var dc := KeyDirs.assign(yaw_case)
	check(absf(KeyDirs.screen_angle(dc[0], yaw_case)) < 20.0, "con un eje casi vertical, W es el vertical y no el que va a la derecha (%.0f°)" % KeyDirs.screen_angle(dc[0], yaw_case))
	print("tests de las direcciones de las teclas terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
