extends Control
## El "clin" de la claridad: cuando se gana, junto al personaje salta el ícono de la claridad (girando como una moneda) con "+N" de cubitos, rebota, brilla con destellos como un premio de
## tragamonedas y sube desvaneciéndose. Cuanta más racha, más grande y con más destellos. Una pérdida (cantidad negativa) sale en rojo, sin destellos, y cae. Uso: `ClinClaridad.lanzar(capa, punto_en_pantalla, cantidad, racha)`.

const ClarityIcon := preload("res://scripts/ui/clarity_icon.gd")
const VoxelLabel := preload("res://scripts/ui/voxel_label.gd")
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const NumberFormat := preload("res://scripts/datos/number_format.gd")

const DURACION := 1.5      # segundos que dura todo
const SUBE := 90.0         # píxeles que sube

var _cantidad := 0
var _racha := 1.0
var _fila: HBoxContainer
var _t := 0.0
var _origen := Vector2.ZERO


## Lanza un "clin" en `punto` (coordenadas de pantalla de `capa`). `racha`: el multiplicador de racha (1,0 = sin racha).
static func lanzar(capa: Node, punto: Vector2, cantidad: int, racha := 1.0) -> void:
	var c = load("res://scripts/ui/clin_claridad.gd").new()
	c._cantidad = cantidad
	c._racha = maxf(racha, 1.0)
	c._origen = punto + Vector2(randf_range(-18.0, 18.0), 0.0)
	capa.add_child(c)


## Qué tan grande sale: de 1 (sin racha) a 2,4 (racha altísima), con un poco más si la ganancia es grande.
static func tamano(racha: float, cantidad: int) -> float:
	cantidad = absi(cantidad)
	var por_racha := clampf(1.0 + 0.32 * (racha - 1.0), 1.0, 2.2)
	var por_cantidad := 1.0 + 0.2 * clampf((log(maxf(float(cantidad), 1.0)) / log(10.0) - 1.0) / 6.0, 0.0, 1.0)
	return por_racha * por_cantidad


func _init() -> void:
	name = "clin_claridad"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var k := tamano(_racha, _cantidad)
	var cubo := 3.5
	_fila = HBoxContainer.new()
	_fila.add_theme_constant_override("separation", 8)
	_fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icono := ClarityIcon.new()
	icono.cube = cubo
	_fila.add_child(icono)
	var numero := VoxelLabel.new()
	numero.cube = cubo * 1.3
	numero.localize = false
	numero.text = ("+" if _cantidad >= 0 else "−") + NumberFormat.fmt(absi(_cantidad))
	numero.color = Color(1.0, 0.95, 0.65).lerp(Color(1.0, 0.7, 0.25), clampf((_racha - 1.0) / 4.0, 0.0, 1.0)) if _cantidad >= 0 else Color(1.0, 0.45, 0.4)
	numero.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fila.add_child(numero)
	add_child(_fila)
	var tam := _fila.get_combined_minimum_size()
	_fila.size = tam
	_fila.pivot_offset = tam * 0.5
	_fila.scale = Vector2.ONE * k
	_fila.position = _origen - tam * 0.5
	var pop := create_tween()   # rebota al aparecer: chico, se pasa de grande y se asienta
	_fila.scale = Vector2.ONE * k * 0.3
	pop.tween_property(_fila, "scale", Vector2.ONE * k * 1.3, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_fila, "scale", Vector2.ONE * k, 0.12)
	var vuelo := create_tween().set_parallel(true)
	vuelo.tween_property(_fila, "position:y", _origen.y - tam.y * 0.5 - (SUBE * minf(k, 1.6) if _cantidad >= 0 else -SUBE * 0.5), DURACION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	vuelo.tween_property(_fila, "modulate:a", 0.0, 0.4).set_delay(DURACION - 0.4)
	vuelo.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Los destellos (cruces de cubitos blancos y dorados) que centellean en las esquinas: uno solo sin racha, hasta cinco con mucha.
func _draw() -> void:
	if _fila == null or _t > DURACION:
		return
	var tam := _fila.size * _fila.scale
	var centro := _fila.position + _fila.size * 0.5
	var cuantos := clampi(1 + int(_racha - 1.0), 1, 5) if _cantidad >= 0 else 0
	var alfa := clampf(1.0 - maxf(_t - (DURACION - 0.4), 0.0) / 0.4, 0.0, 1.0)
	for i in cuantos:
		var fase := _t * 7.0 + float(i) * 1.7
		var brillo := clampf(sin(fase) * 0.5 + 0.6, 0.0, 1.0)
		if brillo < 0.15:
			continue
		var ang := float(i) * 2.4 + 0.6
		var p := centro + Vector2(cos(ang) * (tam.x * 0.5 + 6.0), sin(ang) * (tam.y * 0.5 + 4.0))
		var s := (2.0 + 1.3 * brillo) * minf(tamano(_racha, _cantidad), 1.8)
		var col := Color(1.0, 1.0, 0.92, alfa * brillo)
		for d in [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
			draw_rect(Rect2(p + d * s - Vector2(s, s) * 0.5, Vector2(s, s)), col if d.length() <= 1.0 else Color(1.0, 0.85, 0.4, alfa * brillo * 0.8))
