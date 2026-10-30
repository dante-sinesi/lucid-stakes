extends HBoxContainer
## El aviso "Cuidado" del casino: un triángulo amarillo de cubitos con una exclamación y, al lado, lo que pasa: lo que vas a gastar (una apuesta, una fianza, una compra) puede dejarte por debajo del
## peaje de Farolín. Se muestra sólo si hoy llegas al peaje y ese gasto te dejaría por debajo (si ya estás por debajo, gastar no cambia esa advertencia).
## Uso: `AvisoPeaje.new()` y `actualizar(claridad, costo, peaje, texto)`. Con `compacto` (para donde falta alto) todo va en una sola línea.

const UI := preload("res://scripts/ui/menu_ui.gd")
const Loc := preload("res://scripts/idioma/loc.gd")

const AMARILLO := Color(1.0, 0.86, 0.22)

var compacto := false
var _titulo: Control
var _detalle: Control
var _triangulo: Control


## ¿Este gasto te deja por debajo del peaje? Sólo avisa si ahora llegas al peaje (`claridad >= peaje`), cuesta algo y después de pagarlo no llegas.
static func alerta(claridad: int, costo: int, peaje: int) -> bool:
	return peaje > 0 and costo > 0 and claridad >= peaje and claridad - costo < peaje


func _init(en_una_linea := false) -> void:
	compacto = en_una_linea
	name = "aviso_peaje"
	visible = false
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_triangulo = _Triangulo.new(3.8 if compacto else 4.6)
	add_child(_triangulo)
	if compacto:
		_titulo = UI.label(self, "", 2.6, AMARILLO, false)
		_titulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_detalle = _titulo
		_detalle.name = "detalle"
		return
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 2)
	columna.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(columna)
	_titulo = UI.label(columna, Loc.t("Cuidado"), 3.6, AMARILLO, false)
	_detalle = UI.label(columna, "", 2, Color(1.0, 0.95, 0.75), false, 300)
	_detalle.name = "detalle"


## Muestra u oculta el aviso. `texto`: lo que se dice (por omisión, "Esta apuesta puede dejarte por debajo del peaje (N).").
func actualizar(claridad: int, costo: int, peaje: int, texto := "") -> void:
	var on := alerta(claridad, costo, peaje)
	visible = on
	if not on:
		return
	var detalle := texto if texto != "" else Loc.f("Esta apuesta puede dejarte por debajo del peaje (%d).", [peaje])
	_detalle.text = (Loc.t("Cuidado") + ": " + detalle) if compacto else detalle


## El triángulo de advertencia: amarillo con el borde naranja y una exclamación oscura, de cubitos; late despacio.
class _Triangulo extends Control:
	const D := preload("res://scripts/ui/voxel_draw.gd")
	const ALTO := 11
	const ANCHO := 15
	var s := 4.6   # lado de un cubito
	var _t := 0.0

	func _init(lado := 4.6) -> void:
		s = lado
		name = "triangulo"
		custom_minimum_size = Vector2(ANCHO, ALTO + 1) * s
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var brillo := 0.9 + 0.1 * sin(_t * 5.0)
		var centro := ANCHO / 2
		for y in ALTO:
			var medio := int(round(0.7 * float(y)))
			for x in range(centro - medio, centro + medio + 1):
				var borde := x == centro - medio or x == centro + medio or y == ALTO - 1
				var col := Color(1.0, 0.58, 0.08) if borde else Color(1.0, 0.86, 0.22)
				D.cube(self, Vector2(x, y) * s, s, Color(col.r * brillo, col.g * brillo, col.b * brillo), true)
		var oscuro := Color(0.16, 0.07, 0.02)
		for y in range(3, 7):   # el palito de la exclamación
			D.cube(self, Vector2(centro, y) * s, s, oscuro, true)
		D.cube(self, Vector2(centro, 8) * s, s, oscuro, true)   # y el punto
