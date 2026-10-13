extends Control
## Fondo en remolino hecho de cubitos grandes (estilo Balatro): una espiral que gira y respira, en violetas oscuros con
## manchas de corrupción más claras. `dim` oscurece el fondo (0 = tal cual, 1 = negro) para que el texto se lea.

const Draw := preload("res://scripts/voxel_draw.gd")

var cube := 20.0
var dim := 0.0
var speed := 1.0
var _t := 0.0
var _frame := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta * speed
	_frame += 1
	if _frame % 2 == 0:   # a 30 cuadros por segundo alcanza y cuesta la mitad
		queue_redraw()


## Color del cubito en (i, j) de la grilla, con el remolino en el tiempo `t`.
func color_at(i: int, j: int, cols: int, rows: int, t: float) -> Color:
	var dx := (i - cols * 0.5) * cube
	var dy := (j - rows * 0.5) * cube
	var r := sqrt(dx * dx + dy * dy)
	var a := atan2(dy, dx)
	var v := sin(a * 3.0 + r * 0.035 - t * 1.4) + sin(r * 0.05 + t * 0.9)
	var c := Color(0.07, 0.03, 0.13)
	if v > 0.8:
		c = Color(0.30, 0.12, 0.43)
	elif v > 0.0:
		c = Color(0.17, 0.07, 0.29)
	elif v > -0.8:
		c = Color(0.10, 0.04, 0.19)
	return c.darkened(dim)


func _draw() -> void:
	var cols := int(size.x / cube) + 1
	var rows := int(size.y / cube) + 1
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.04))   # las juntas entre cubitos siempre negras (no se asoma la escena de atrás, que puede ser clara)
	for j in rows:
		for i in cols:
			var col := color_at(i, j, cols, rows, _t)
			var pos := Vector2(i, j) * cube
			draw_rect(Rect2(pos, Vector2(cube - 1, cube - 1)), col)
			draw_rect(Rect2(pos, Vector2(cube - 1, 3)), Color(1, 1, 1, 0.04 * (1.0 - dim)))
