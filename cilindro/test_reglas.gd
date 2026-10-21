extends SceneTree
## Pruebas de las reglas del cilindro. GAME_SANDBOX=1 godot --headless --path . -s cilindro/test_reglas.gd
const R := preload("res://cilindro/reglas.gd")
var fallos := 0


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		fallos += 1
	print(("ok  " if cond else "FALLA ") + msg)


func _init() -> void:
	var alto := 8
	var b := {}
	for c in R.cima(alto):
		b[c] = true
	# diagonal que baja desde la cima por la cara z=1: (1..7 niveles) un bloque por nivel, sin extras
	for i in 6:
		b[Vector3i(1 + i, alto - 1 - i, 1)] = true
	var base := b.size()
	_ok(R.sostenidos(b, alto).size() == base, "diagonal de bajada colgando de la cima: se sostiene")
	var r := R.asentar(b, alto)
	_ok(r.perdidos == 0 and r.caidos == 0, "asentar no mueve nada si todo se sostiene")
	# sacar el bloque de arriba de la diagonal: lo de abajo queda sin ancla, cae y se pierde (el pozo/exterior no tiene piso)
	var b2 := b.duplicate()
	b2.erase(Vector3i(1, alto - 1, 1))
	var r2 := R.asentar(b2, alto)
	_ok(r2.bloques.size() < b2.size() or r2.caidos > 0, "sin el primer eslabón, la cola de la diagonal cae")
	# un bloque apoyado en el anillo se sostiene aunque no esté anclado
	var b3 := {Vector3i(0, 1, 3): true}
	for c in R.cima(alto):
		b3[c] = true
	_ok(R.sostenidos(b3, alto).has(Vector3i(0, 1, 3)), "bloque sobre el anillo: se sostiene")
	# un bloque suelto en el aire, sobre una celda de masa (sin piso) se pierde
	var b4 := {Vector3i(2, 3, 2): true}
	for c in R.cima(alto):
		b4[c] = true
	var r4 := R.asentar(b4, alto)
	_ok(not r4.bloques.has(Vector3i(2, 3, 2)) and r4.perdidos == 1, "bloque suelto sobre la masa (sin piso): se pierde")
	# una columna sobre el anillo, apoyada, y sobre ella otro: ambos se sostienen
	var b5 := {Vector3i(0, 1, 3): true, Vector3i(0, 2, 3): true}
	for c in R.cima(alto):
		b5[c] = true
	_ok(R.sostenidos(b5, alto).size() == b5.size(), "columna sobre el anillo: se sostiene")
	print("fallos: ", fallos)
	quit(0)
