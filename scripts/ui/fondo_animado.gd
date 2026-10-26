extends CanvasLayer
## El fondo del juego: el color liso de la etapa (que main.gd pone en `Environment.background_color`) con estrellitas que titilan y bajan muy despacio (shaders/fondo.gdshader).
## Se dibuja detrás de todo como fondo del entorno (`BG_CANVAS`), así que el 3D, la interfaz y los menús quedan encima.

const SHADER := preload("res://shaders/fondo.gdshader")

var rect: ColorRect
var mat: ShaderMaterial
var env: Environment


func _init(entorno: Environment) -> void:
	name = "fondo"
	layer = -10
	env = entorno
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	rect = ColorRect.new()
	rect.material = mat
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = -1   # (se ven las capas de fondo; el resto va por encima del 3D)


func _process(_delta: float) -> void:
	mat.set_shader_parameter("base", env.background_color)   # (el color de la etapa; cambia cuando main.gd aplica el aspecto de la etapa)
