extends HBoxContainer
## Contador de claridad: el ícono girando y el número al lado ("[ícono] 250"), todo de cubitos.

const ClarityIcon := preload("res://scripts/ui/clarity_icon.gd")
const VoxelLabel := preload("res://scripts/ui/voxel_label.gd")
const NumberFormat := preload("res://scripts/datos/number_format.gd")

var icon
var label
var plate_alpha := 0.0:   # placa oscura translúcida detrás (para leerlo sobre la escena, sobre todo en las etapas claras)
	set(v):
		plate_alpha = v
		queue_redraw()
var value := 0:
	set(v):
		value = v
		if label != null:
			label.text = NumberFormat.fmt(v)


func _draw() -> void:
	if plate_alpha > 0.0:
		draw_rect(Rect2(Vector2(-8, -4), size + Vector2(16, 8)), Color(0.03, 0.02, 0.06, plate_alpha))


## `cube`: lado de los cubitos del número; el ícono es un poco más chico.
func _init(cube := 4.0, color := Color(1.0, 0.97, 0.80)) -> void:
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon = ClarityIcon.new()
	icon.cube = cube * 1.0
	add_child(icon)
	label = VoxelLabel.new()
	label.cube = cube
	label.color = color
	label.text = "0"
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(label)
