extends SceneTree
## Pruebas del motor del cilindro. GAME_SANDBOX=1 godot --headless --path . -s cilindro/test_motor.gd
const Motor := preload("res://cilindro/motor.gd")
var fallos := 0


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		fallos += 1
	print(("ok  " if cond else "FALLA ") + msg)


func _escalera() -> Object:
	# cima en y=4; la escalera baja en diagonal por la fila z=0 (encima del anillo de piso): (2,3,0), (3,2,0), (4,1,0); el último apoya en el piso
	var t = Motor.nueva(4, Vector3i(5, 1, 0))
	t.poner(Vector3i(2, 3, 0))
	t.poner(Vector3i(3, 2, 0))
	t.poner(Vector3i(4, 1, 0))
	return t


func _init() -> void:
	var t = _escalera()
	_ok(t.bloques.size() == 32 + 3, "la escalera de 3 bloques se sostiene entera (sin bloques extra)")
	var W := Vector3i(-1, 0, 0)
	t.actuar(W)
	t.actuar(W)
	t.actuar(W)
	_ok(t.jugador == Vector3i(2, 4, 0), "sube la escalera diagonal")
	t.actuar(Vector3i(0, 0, 1))
	_ok(t.ganado, "pasa a la cima: gana en 4 acciones")

	# empujar un bloque de la escalera: el de arriba se corre y sigue tocando la cima
	var u = _escalera()
	u.actuar(W)
	u.actuar(W)
	var antes: int = u.bloques.size()
	var r2: Dictionary = u.actuar(W, Motor.Modo.AGARRAR)
	_ok(r2.ok and u.bloques.has(Vector3i(1, 3, 0)) and u.bloques.size() == antes, "se empuja un bloque de la escalera y sigue sostenido (toca la cima)")

	# un bloque suelto sin conexión cae y, sin piso (pozo), se pierde
	var v = Motor.nueva(4, Vector3i(4, 1, 0))
	v.poner(Vector3i(4, 1, 1))
	v.poner(Vector3i(5, 1, 1))   # tocan el piso por la cara de abajo? (4,1,1) es masa: sin piso -> sólo se tocan entre sí
	v._asentar()
	_ok(not v.bloques.has(Vector3i(4, 1, 1)) and not v.bloques.has(Vector3i(5, 1, 1)), "un par de bloques sin conexión con la cima y sin piso se pierden")

	# colgarse: parado en la escalera, pasar al lado de afuera (z=-1) y trepar de vuelta
	var w = _escalera()
	w.actuar(W)
	w.actuar(W)
	var r3: Dictionary = w.actuar(Vector3i(0, 0, -1), Motor.Modo.COLGAR)
	_ok(r3.ok and w.colgado == Vector3i(0, 0, 1), "colgarse de un borde")
	w.actuar(Vector3i(0, 0, 1))
	_ok(w.colgado == Vector3i.ZERO and not w.perdido, "trepar el bloque desde el cuelgue")
	print("fallos: ", fallos)
	quit(0)
