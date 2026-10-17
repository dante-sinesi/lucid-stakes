extends HBoxContainer
## La barra de ayuda de los botones del mando de una pantalla de juego: "[A] Girar   [X] Rotar vitrina   [B] Salir". Sólo se ve cuando se juega con el mando (Controls.using_pad).
## `set_items([{slot: PadGlyph.Slot, text}, {name: "LB", text}, ...])`: cada ítem lleva un botón de cara (slot) o uno con nombre (hombros, cruceta) y lo que hace.
## `Item.dim`: apagado (la acción no se puede hacer ahora).

const PadGlyph := preload("res://scripts/pad_glyph.gd")
const Controls := preload("res://scripts/controls.gd")
const VoxelLabel := preload("res://scripts/voxel_label.gd")

## Saca el foco de todos los botones de una pantalla: con el mando se juega apretando botones y no moviéndose por la interfaz (el mouse sigue andando).
static func focus_none(node: Node) -> void:
	if node is Control:
		(node as Control).focus_mode = Control.FOCUS_NONE
	for c in node.get_children():
		focus_none(c)


var items: Array = []
var _icons: Array = []
var _labels: Array = []


class _Icon extends Control:
	var slot := -1
	var named := ""
	var dim := false

	func _init() -> void:
		custom_minimum_size = Vector2(46, 40)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## `named` puede juntar varios botones con "|" (por ejemplo "LB|RB").
	func setup(new_slot: int, new_named: String, new_dim: bool) -> void:
		slot = new_slot
		named = new_named
		dim = new_dim
		custom_minimum_size = Vector2(46 + 52 * maxi(named.count("|"), 0), 40)

	func _draw() -> void:
		var c := size * 0.5
		if named != "":
			var parts := named.split("|")
			var x := c.x - (parts.size() - 1) * 26.0
			for part in parts:
				PadGlyph.draw_named(self, Vector2(x, c.y), 12.0, part, dim)
				x += 52.0
		elif slot >= 0:
			PadGlyph.draw(self, c, 13.0, slot, dim)


func _init() -> void:
	add_theme_constant_override("separation", 10)
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(_dt: float) -> void:
	var want: bool = Controls.using_pad and not items.is_empty()
	if visible != want:
		visible = want


func set_items(new_items: Array) -> void:
	items = new_items
	for c in get_children():
		c.queue_free()
	_icons.clear()
	_labels.clear()
	for it in items:
		var icon := _Icon.new()
		icon.setup(int(it.get("slot", -1)), str(it.get("name", "")), bool(it.get("dim", false)))
		add_child(icon)
		var l := VoxelLabel.new()
		l.cube = 2.0
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.color = Color(0.9, 0.86, 1.0) if not icon.dim else Color(0.5, 0.46, 0.55)
		l.text = str(it.text)
		add_child(l)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(14, 1)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(gap)
		_icons.append(icon)
		_labels.append(l)


## Apaga o enciende un ítem (por posición) sin rearmar la barra.
func set_dim(i: int, dim: bool) -> void:
	if i < 0 or i >= _icons.size() or _icons[i].dim == dim:
		return
	_icons[i].dim = dim
	_icons[i].queue_redraw()
	_labels[i].color = Color(0.5, 0.46, 0.55) if dim else Color(0.9, 0.86, 1.0)
