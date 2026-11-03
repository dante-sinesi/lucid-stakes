extends Control
## Texto hecho de cubitos (reemplaza a Label). Se mide y se corta en líneas en celdas de la fuente; `cube` es el lado de un
## cubito en píxeles. `wrap_px` > 0 corta el texto para que entre en ese ancho.

const VFont := preload("res://scripts/ui/voxel_font.gd")
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const Loc := preload("res://scripts/idioma/loc.gd")

enum Align { LEFT, CENTER, RIGHT }

var text := "":
	set(v):
		if localize:
			v = Loc.auto(v)
		if v == text:
			return
		text = v
		_dirty()
## El tamaño del cubito. El texto chico (menos de 3) se dibuja un 12 % más grande que lo pedido: así no se ve fino (ver `Draw.CUBO_CHICO_MULT`).
var cube := 3.0:
	set(v):
		cube = v * Draw.CUBO_CHICO_MULT if v < 3.0 else v
		_dirty()
var color := Color(0.95, 0.93, 0.88):
	set(v):
		color = v
		queue_redraw()
var corruption := -1.0:   # -1 = la de la interfaz (VoxelDraw.default_corruption)
	set(v):
		corruption = v
		queue_redraw()
var align: int = Align.LEFT:
	set(v):
		align = v
		_dirty()
var wrap_px := 0:
	set(v):
		wrap_px = v
		_dirty()
var shadow := true
var localize := true        # el texto se traduce al idioma elegido (Loc.auto); el cuadro de diálogo lo apaga porque escribe letra por letra
var y_offset := 0.0:        # corrimiento vertical del texto dentro del control
	set(v):
		y_offset = v
		queue_redraw()
var margin := 0.0            # margen derecho cuando el texto va alineado a la derecha
var vcenter := false        # centrar el texto en vertical
var plate_alpha := 0.0:     # placa oscura translúcida detrás del texto (para leerlo sobre la escena 3D)
	set(v):
		plate_alpha = v
		queue_redraw()

var dance := false:         # cada letra se balancea y salta (títulos)
	set(v):
		dance = v
		set_process(v)
		queue_redraw()

var _layout := {}
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _dirty() -> void:
	_layout = {}
	update_minimum_size()
	queue_redraw()


func lines() -> Array:
	if wrap_px > 0:
		return VFont.wrap(text, int(wrap_px / cube))
	return text.replace("\r", "").split("\n")


func layout() -> Dictionary:
	if _layout.is_empty():
		_layout = VFont.layout(lines(), align)
	return _layout


func _get_minimum_size() -> Vector2:
	var sz: Vector2i = layout().size
	return Vector2(sz.x, sz.y + 2) * cube   # 2 celdas más abajo para las chorreras


func _draw() -> void:
	var l := layout()
	var seed_value := text.hash() & 0xFFFF
	var k := Draw.default_corruption if corruption < 0.0 else corruption
	var origin := Vector2(0, y_offset)
	if align == Align.CENTER:
		origin.x = (size.x - l.size.x * cube) * 0.5
	elif align == Align.RIGHT:
		origin.x = size.x - l.size.x * cube - margin
	if vcenter:
		origin.y = (size.y - l.size.y * cube) * 0.5
	if plate_alpha > 0.0 and not text.is_empty():
		var pad := cube * 3.0
		draw_rect(Rect2(origin - Vector2(pad, pad), Vector2(l.size) * cube + Vector2(pad, pad) * 2.0), Color(0.03, 0.01, 0.06, plate_alpha))
	if dance:
		_draw_dance(l, origin, k, seed_value)
		return
	Draw.text_cells(self, origin, l.cells, l.size.y, cube, color, k, seed_value, shadow)


## Cada letra se dibuja por separado, girando y saltando un poco alrededor de su centro.
func _draw_dance(l: Dictionary, origin: Vector2, k: float, seed_value: int) -> void:
	var ls := lines()
	for li in ls.size():
		var line: String = ls[li]
		var off := 0
		if align == Align.CENTER:
			off = (l.size.x - VFont.line_width(line)) / 2
		elif align == Align.RIGHT:
			off = l.size.x - VFont.line_width(line)
		for ci in line.length():
			var cells := VFont.glyph_cells(line[ci])
			if cells.is_empty():
				continue
			var gc := origin + Vector2(off + ci * VFont.ADVANCE + VFont.W * 0.5, li * VFont.LINE_H + VFont.H * 0.5) * cube
			var rot := sin(_t * 2.4 + ci * 0.5) * 0.09
			var hop := sin(_t * 2.2 + ci * 0.55) * cube * 0.8
			draw_set_transform(gc + Vector2(0, hop), rot, Vector2.ONE)
			Draw.text_cells(self, -Vector2(VFont.W * 0.5, VFont.H * 0.5) * cube, cells, VFont.H, cube, color, k, seed_value + ci, shadow)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
