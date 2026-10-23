extends HBoxContainer
## Contador de Luz: el sol girando y el número al lado ("[sol] 25"). Sin la palabra "Luz": el ícono lo dice todo.
## `prefix` se antepone al número (por ejemplo "+" para lo que ganaste).

const LuzIcon := preload("res://scripts/ui/luz_icon.gd")
const VoxelLabel := preload("res://scripts/ui/voxel_label.gd")

var icon
var label
var prefix := "":
	set(v):
		prefix = v
		_refresh()
var value := 0:
	set(v):
		value = v
		_refresh()
var plate_alpha := 0.0:   # placa oscura translúcida detrás (para leerlo sobre cualquier fondo)
	set(v):
		plate_alpha = v
		queue_redraw()


## `cube`: lado de los cubitos del número; el sol es del mismo tamaño.
func _init(cube := 3.0, color := Color(1.0, 0.95, 0.7)) -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon = LuzIcon.new()
	icon.cube = cube * 0.8
	add_child(icon)
	label = VoxelLabel.new()
	label.cube = cube
	label.color = color
	label.text = "0"
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(label)


func _draw() -> void:
	if plate_alpha > 0.0:
		draw_rect(Rect2(Vector2(-8, -4), size + Vector2(16, 8)), Color(0.03, 0.02, 0.06, plate_alpha))


func _refresh() -> void:
	if label != null:
		label.text = prefix + str(value)
