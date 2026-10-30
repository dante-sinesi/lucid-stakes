extends Control
## El aviso del peaje: un triángulo amarillo de cubitos con una exclamación, sin texto. Es casi equilátero (21 x 19 cubitos) y tiene las tres puntas redondeadas. Aparece junto a la claridad o al precio
## cuando lo que vas a gastar (una apuesta, una fianza, una compra, un cambio) puede dejarte por debajo de lo que cobra Farolín en la puerta. Qué significa se explica en la ayuda de cada juego
## ("el símbolo {peaje} indica que...").
## Sólo se muestra si hoy llegas al peaje y ese gasto te dejaría por debajo (si ya estás por debajo, gastar no cambia la advertencia). Uso: `actualizar(claridad, costo, peaje)`.

const D := preload("res://scripts/ui/voxel_draw.gd")

const ANCHO := 21   # columnas de cubitos
const ALTO := 19    # filas de cubitos
const RADIO := 2.5  # cuánto se redondean las puntas
const BORDE := 1.4  # el borde naranja: lo que mide hacia adentro

## El triángulo equilátero de adentro (el de afuera es éste engordado en RADIO: así las tres puntas salen redondeadas): vértices en coordenadas de cubitos.
const A := Vector2(10.5, 2.5)
const B := Vector2(3.0, 15.49)
const C := Vector2(18.0, 15.49)

static var _celdas: Array = []   # [{x, y, borde}] de cada cubito del triángulo (se calcula una vez)

var lado := 2.2     # lado de un cubito
var _t := 0.0


## ¿Este gasto te deja por debajo del peaje? Sólo avisa si ahora llegas al peaje (`claridad >= peaje`), cuesta algo y después de pagarlo no llegas.
static func alerta(claridad: int, costo: int, peaje: int) -> bool:
	return peaje > 0 and costo > 0 and claridad >= peaje and claridad - costo < peaje


func _init(cubito := 2.2) -> void:
	lado = cubito
	name = "aviso_peaje"
	visible = false
	custom_minimum_size = Vector2(ANCHO, ALTO) * lado
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Muestra u oculta el aviso.
func actualizar(claridad: int, costo: int, peaje: int) -> void:
	visible = alerta(claridad, costo, peaje)


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


func _draw() -> void:
	dibujar(self, Vector2(ANCHO, ALTO) * lado * 0.5, lado, 0.9 + 0.1 * sin(_t * 5.0))


## La distancia con signo de un punto a un triángulo (negativa adentro).
static func _distancia(p: Vector2) -> float:
	var e0 := B - A
	var e1 := C - B
	var e2 := A - C
	var v0 := p - A
	var v1 := p - B
	var v2 := p - C
	var pq0 := v0 - e0 * clampf(v0.dot(e0) / e0.dot(e0), 0.0, 1.0)
	var pq1 := v1 - e1 * clampf(v1.dot(e1) / e1.dot(e1), 0.0, 1.0)
	var pq2 := v2 - e2 * clampf(v2.dot(e2) / e2.dot(e2), 0.0, 1.0)
	var s := signf(e0.x * e2.y - e0.y * e2.x)
	var d0 := Vector2(pq0.dot(pq0), s * (v0.x * e0.y - v0.y * e0.x))
	var d1 := Vector2(pq1.dot(pq1), s * (v1.x * e1.y - v1.y * e1.x))
	var d2 := Vector2(pq2.dot(pq2), s * (v2.x * e2.y - v2.y * e2.x))
	var dx := minf(minf(d0.x, d1.x), d2.x)
	var dy := minf(minf(d0.y, d1.y), d2.y)
	return -sqrt(dx) * signf(dy)


static func _preparar() -> void:
	if not _celdas.is_empty():
		return
	for y in ALTO:
		for x in ANCHO:
			var d := _distancia(Vector2(x + 0.5, y + 0.5)) - RADIO
			if d <= 0.0:
				_celdas.append({"x": x, "y": y, "borde": d > -BORDE})


## Dibuja el triángulo de advertencia centrado en `centro`, con cubitos de lado `lado` (`brillo`: 1 = normal). También lo usa la ayuda para mostrar el símbolo dentro de un texto.
static func dibujar(ci: CanvasItem, centro: Vector2, lado: float, brillo := 1.0) -> void:
	_preparar()
	var origen := centro - Vector2(ANCHO, ALTO) * lado * 0.5
	for c in _celdas:
		var col := Color(1.0, 0.58, 0.08) if c.borde else Color(1.0, 0.86, 0.22)
		D.cube(ci, origen + Vector2(c.x, c.y) * lado, lado, Color(col.r * brillo, col.g * brillo, col.b * brillo), true)
	var oscuro := Color(0.16, 0.07, 0.02)
	for y in range(6, 11):   # el palito de la exclamación (tres cubitos de ancho)
		for x in range(9, 12):
			D.cube(ci, origen + Vector2(x, y) * lado, lado, oscuro, true)
	for y in range(12, 14):   # y el punto
		for x in range(9, 12):
			D.cube(ci, origen + Vector2(x, y) * lado, lado, oscuro, true)
