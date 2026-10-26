extends CanvasLayer
## El fondo del juego: un color liso (el de la etapa, que main.gd pone en `Environment.background_color`) con un movimiento muy suave encima (shaders/fondo.gdshader).
## Se dibuja detrás de todo como fondo del entorno (`BG_CANVAS`), así que el 3D, la interfaz y los menús quedan encima.
## Modos: 0 liso · 1 polvo de luz · 2 bruma · 3 aurora · 4 estrellas · 5 cubos a la deriva.

const SHADER := preload("res://shaders/fondo.gdshader")
const NOMBRES := ["Liso", "Polvo de luz", "Bruma", "Aurora", "Estrellas", "Cubos a la deriva"]

var rect: ColorRect
var mat: ShaderMaterial
var env: Environment


func _init(entorno: Environment, modo := 0) -> void:
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
	set_modo(modo)
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = -1   # (se ven las capas de fondo; el resto va por encima del 3D)


func set_modo(m: int) -> void:
	mat.set_shader_parameter("modo", clampi(m, 0, NOMBRES.size() - 1))


func modo() -> int:
	return int(mat.get_shader_parameter("modo"))


func _process(_delta: float) -> void:
	mat.set_shader_parameter("base", env.background_color)   # (el color de la etapa; cambia cuando main.gd aplica el aspecto de la etapa)
