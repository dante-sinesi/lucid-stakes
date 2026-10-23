extends Control
## Un casillero de la barra de ítems: una carta de cubitos con el ícono del ítem (o vacía). Se inclina hacia el mouse y flota
## un poco, como los botones. Los de consumibles muestran su tecla (1..4) y se pueden usar con un clic.

const Draw := preload("res://scripts/ui/voxel_draw.gd")
const VFont := preload("res://scripts/ui/voxel_font.gd")
const Icons := preload("res://scripts/ui/item_icons.gd")

const SLOT := 78.0      # lado del casillero en píxeles
const ICON_CUBE := 6.0

signal pressed
signal hovered(on: bool)
signal discard   ## clic derecho: se quiere tirar el ítem

var item_id := "":
	set(v):
		item_id = v
		queue_redraw()
var key_label := "":
	set(v):
		key_label = v
		queue_redraw()
var selected := false:   # el casillero elegido (con teclado, mando o mouse): un marco que titila
	set(v):
		selected = v
		queue_redraw()
var interactive := false     # los de consumibles se usan con un clic
var _t := 0.0
var _hover := false


func _init() -> void:
	custom_minimum_size = Vector2(SLOT, SLOT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_t = randf() * 20.0
	mouse_entered.connect(func():
		_hover = true
		hovered.emit(true)
		queue_redraw())
	mouse_exited.connect(func():
		_hover = false
		hovered.emit(false)
		queue_redraw())


func is_empty() -> bool:
	return item_id == ""


func _gui_input(event: InputEvent) -> void:
	if not is_empty() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		discard.emit()
		accept_event()
		return
	if interactive and not is_empty() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var k := size.x / SLOT
	var s := maxf(6.0 * k, 3.0)
	var center := size * 0.5
	var filled := not is_empty()
	var bob := sin(_t * 1.6) * 1.5 if filled else 0.0
	var rel := Vector2.ZERO
	if _hover:
		rel = ((get_local_mouse_position() - center) / center).clampf(-1.0, 1.0)
	var scl := 1.08 if _hover and filled else 1.0
	var xf := Transform2D(sin(_t * 1.2) * 0.02 * (1.0 if filled else 0.0) + rel.x * 0.06, Vector2(scl * (1.0 - absf(rel.y) * 0.04), scl * (1.0 - absf(rel.x) * 0.03)), rel.y * 0.07, center + Vector2(0, bob))
	draw_set_transform_matrix(xf)
	var body := Rect2(-center + Vector2(0, 0), size - Vector2(0, 0))
	Draw.card(self, body, s, 1 if (_hover and filled) else (0 if filled else 3), 0.25 if filled else 0.5, hash(item_id) & 0xFFFF, false, -1.0)
	if filled:
		Icons.draw(self, item_id, -Vector2(Icons.SIZE, Icons.SIZE) * ICON_CUBE * k * 0.5, ICON_CUBE * k)
	if key_label != "":
		var l: Dictionary = VFont.layout([key_label])
		Draw.text_cells(self, -center + Vector2(s * 1.6, s * 1.4), l.cells, l.size.y, 2.0, Color(1, 0.92, 0.6) if filled else Color(0.6, 0.55, 0.7), 0.0, 1, true)
	if selected and filled:
		draw_rect(body.grow(5.0), Color(1.0, 1.0, 0.9, 0.55 + 0.45 * sin(_t * 8.0)), false, 4.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)
