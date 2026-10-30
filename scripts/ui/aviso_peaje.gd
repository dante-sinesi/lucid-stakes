extends Control
## El aviso del peaje: un triángulo amarillo de cubitos con una exclamación, sin texto. Aparece junto a la claridad o al precio cuando lo que vas a gastar (una apuesta, una fianza, una compra, un cambio)
## puede dejarte por debajo de lo que cobra Farolín en la puerta. Qué significa se explica en la ayuda de cada juego ("el símbolo {peaje} indica que...").
## Sólo se muestra si hoy llegas al peaje y ese gasto te dejaría por debajo (si ya estás por debajo, gastar no cambia la advertencia). Uso: `actualizar(claridad, costo, peaje)`.

const D := preload("res://scripts/ui/voxel_draw.gd")

const ALTO := 11    # filas de cubitos
const ANCHO := 15   # columnas de cubitos

var lado := 4.6     # lado de un cubito
var _t := 0.0


## ¿Este gasto te deja por debajo del peaje? Sólo avisa si ahora llegas al peaje (`claridad >= peaje`), cuesta algo y después de pagarlo no llegas.
static func alerta(claridad: int, costo: int, peaje: int) -> bool:
	return peaje > 0 and costo > 0 and claridad >= peaje and claridad - costo < peaje


func _init(cubito := 4.6) -> void:
	lado = cubito
	name = "aviso_peaje"
	visible = false
	custom_minimum_size = Vector2(ANCHO, ALTO + 1) * lado
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


## Dibuja el triángulo de advertencia centrado en `centro`, con cubitos de lado `lado` (`brillo`: 1 = normal). También lo usa la ayuda para mostrar el símbolo dentro de un texto.
static func dibujar(ci: CanvasItem, centro: Vector2, lado: float, brillo := 1.0) -> void:
	var origen := centro - Vector2(ANCHO, ALTO) * lado * 0.5
	var medio := ANCHO / 2
	for y in ALTO:
		var ancho_fila := int(round(0.7 * float(y)))
		for x in range(medio - ancho_fila, medio + ancho_fila + 1):
			var borde := x == medio - ancho_fila or x == medio + ancho_fila or y == ALTO - 1
			var col := Color(1.0, 0.58, 0.08) if borde else Color(1.0, 0.86, 0.22)
			D.cube(ci, origen + Vector2(x, y) * lado, lado, Color(col.r * brillo, col.g * brillo, col.b * brillo), true)
	var oscuro := Color(0.16, 0.07, 0.02)
	for y in range(3, 7):   # el palito de la exclamación
		D.cube(ci, origen + Vector2(medio, y) * lado, lado, oscuro, true)
	D.cube(ci, origen + Vector2(medio, 8) * lado, lado, oscuro, true)   # y el punto
