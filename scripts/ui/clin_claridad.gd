extends Control
## El "clin" de la claridad: el ícono de la claridad (girando como una moneda) con "+N" de cubitos, fijo en un punto de la pantalla (debajo del marco de la partida, lejos del personaje). Las ganancias que
## llegan seguidas se suman en un solo clin (no aparece uno por paso): rebota cada vez que suma, brilla con destellos como un premio de tragamonedas y se desvanece solo un momento después de la última.
## Cuanta más racha, más grande y con más destellos. Una pérdida (cantidad negativa) sale aparte, en rojo, sin destellos.
## Uso: `ClinClaridad.lanzar(capa, punto_en_pantalla, cantidad, racha)` devuelve el clin; para sumar a uno que sigue vivo, `clin.acumular(cantidad, racha)`.

const ClarityIcon := preload("res://scripts/ui/clarity_icon.gd")
const VoxelLabel := preload("res://scripts/ui/voxel_label.gd")
const NumberFormat := preload("res://scripts/datos/number_format.gd")

const PERMANENCIA := 0.9   # segundos que se queda desde la última ganancia
const DESVANECER := 0.35

var _cantidad := 0
var _racha := 1.0
var _fila: HBoxContainer
var _numero: Control
var _t := 0.0
var _vida := PERMANENCIA
var _origen := Vector2.ZERO
var _pop: Tween


## Lanza un clin con su borde izquierdo (y su centro en vertical) en `punto` (coordenadas de pantalla de `capa`). `racha`: el multiplicador de racha (1,0 = sin racha).
static func lanzar(capa: Node, punto: Vector2, cantidad: int, racha := 1.0):
	var c = load("res://scripts/ui/clin_claridad.gd").new()
	c._cantidad = cantidad
	c._racha = maxf(racha, 1.0)
	c._origen = punto
	capa.add_child(c)
	return c


## Qué tan grande sale: de 1 (sin racha) a 1,7 (racha altísima), con un poco más si la ganancia es grande. (Más chico que al principio: es un indicador, no un cartel.)
static func tamano(racha: float, cantidad: int) -> float:
	cantidad = absi(cantidad)
	var por_racha := clampf(1.0 + 0.2 * (racha - 1.0), 1.0, 1.7)
	var por_cantidad := 1.0 + 0.15 * clampf((log(maxf(float(cantidad), 1.0)) / log(10.0) - 1.0) / 6.0, 0.0, 1.0)
	return por_racha * por_cantidad


func _init() -> void:
	name = "clin_claridad"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var cubo := 3.0
	_fila = HBoxContainer.new()
	_fila.add_theme_constant_override("separation", 8)
	_fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icono := ClarityIcon.new()
	icono.cube = cubo
	_fila.add_child(icono)
	_numero = VoxelLabel.new()
	_numero.cube = cubo * 1.3
	_numero.localize = false
	_numero.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fila.add_child(_numero)
	add_child(_fila)
	_actualizar()
	_rebotar()


## Suma otra ganancia al clin que sigue en pantalla.
func acumular(cantidad: int, racha: float) -> void:
	_cantidad += cantidad
	_racha = maxf(_racha, maxf(racha, 1.0))
	_vida = PERMANENCIA
	_fila.modulate.a = 1.0
	_actualizar()
	_rebotar()


## ¿Sigue vivo (todavía no se está yendo) y es una ganancia?
func vivo() -> bool:
	return not is_queued_for_deletion() and _vida > 0.0 and _cantidad >= 0


func _actualizar() -> void:
	_numero.text = ("+" if _cantidad >= 0 else "−") + NumberFormat.fmt(absi(_cantidad))
	_numero.color = Color(1.0, 0.95, 0.65).lerp(Color(1.0, 0.7, 0.25), clampf((_racha - 1.0) / 4.0, 0.0, 1.0)) if _cantidad >= 0 else Color(1.0, 0.45, 0.4)
	var tam := _fila.get_combined_minimum_size()
	_fila.size = tam
	_fila.pivot_offset = Vector2(0.0, tam.y * 0.5)   # (crece hacia la derecha: el borde izquierdo no se corre aunque el número tenga más cifras)
	_fila.position = _origen - Vector2(0.0, tam.y * 0.5)


## Rebota: se pasa de grande un instante y se asienta.
func _rebotar() -> void:
	var k := tamano(_racha, _cantidad)
	if _pop != null:
		_pop.kill()
	_fila.scale = Vector2.ONE * k * 0.6
	_pop = create_tween()
	_pop.tween_property(_fila, "scale", Vector2.ONE * k * 1.25, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop.tween_property(_fila, "scale", Vector2.ONE * k, 0.1)


func _process(delta: float) -> void:
	_t += delta
	_vida -= delta
	if _vida <= 0.0:
		_fila.modulate.a = clampf(1.0 + _vida / DESVANECER, 0.0, 1.0)
		if _vida < -DESVANECER:
			queue_free()
			return
	queue_redraw()


## Los destellos (cruces de cubitos blancos y dorados) que centellean alrededor: uno solo sin racha, hasta cinco con mucha.
func _draw() -> void:
	if _fila == null or _cantidad < 0:
		return
	var tam := _fila.size * _fila.scale
	var centro := _fila.position + Vector2(tam.x * 0.5, _fila.size.y * 0.5)
	var cuantos := clampi(1 + int(_racha - 1.0), 1, 5)
	var alfa := _fila.modulate.a
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
