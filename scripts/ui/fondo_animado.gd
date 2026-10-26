extends CanvasLayer
## El fondo del juego: un remolino psicodélico de cuadraditos en varias capas (shaders/fondo.gdshader) alrededor del color de la etapa (que main.gd pone en
## `Environment.background_color`). Las capas se mueven con paralaje cuando la cámara de la torre se desplaza, para dar profundidad.
## Se dibuja detrás de todo como fondo del entorno (`BG_CANVAS`), así que el 3D, la interfaz y los menús quedan encima.

const SHADER := preload("res://shaders/fondo.gdshader")

var rect: ColorRect
var mat: ShaderMaterial
var env: Environment
var camara_fn := Callable()   # devuelve dónde está la cámara de la torre en pantalla (Vector2, en unidades del mundo); vacío fuera de la torre
var _camara := Vector2.ZERO


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


func _process(delta: float) -> void:
	var destino := Vector2.ZERO
	if camara_fn.is_valid():
		destino = camara_fn.call()
	_camara = _camara.lerp(destino, 1.0 - exp(-4.0 * delta))   # (suave: la cámara de la torre salta de sala en sala)
	mat.set_shader_parameter("camara", _camara)
	mat.set_shader_parameter("base", env.background_color)   # (el color de la etapa; cambia cuando main.gd aplica el aspecto de la etapa)
