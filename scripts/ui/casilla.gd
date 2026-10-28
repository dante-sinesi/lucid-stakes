extends "res://scripts/ui/voxel_button.gd"
## Casilla de verificación hecha de cubitos, con el estilo de los botones del juego: una carta cuadrada que, tildada, se vuelve dorada y lleva una tilde de cubitos. Es un Button de verdad
## (foco, teclado, mando, mouse): al apretarla emite `pressed` y quien la usa decide el valor nuevo y la vuelve a marcar con `checked`.

const TILDE := [Vector2i(0, 3), Vector2i(1, 4), Vector2i(2, 5), Vector2i(3, 4), Vector2i(4, 3), Vector2i(5, 2), Vector2i(6, 1), Vector2i(7, 0)]

var checked := false:
	set(v):
		checked = v
		selected = v   # (la carta dorada es la de una opción elegida)
		queue_redraw()


func _init() -> void:
	super()
	animated = false
	cube = 2.2


## Una carta cuadrada, sin texto.
func card_size() -> Vector2:
	var fc := frame_cube()
	return Vector2(fc * 9.0, fc * 9.0)


func _draw() -> void:
	super()
	if not checked:
		return
	var fc := frame_cube()
	var body := Vector2(size.x, size.y - fc * 2.0)
	var u := floorf(body.x / 11.0)
	var origen := body * 0.5 - Vector2(8.0, 6.0) * u * 0.5
	for c in TILDE:
		Draw.cube(self, origen + Vector2(c.x, c.y) * u, u, Color(1.0, 0.98, 0.9), true)
