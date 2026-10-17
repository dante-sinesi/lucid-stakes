extends HBoxContainer
## La botonera de una pantalla de juego: "[A] Girar   [X] Poner ficha   [B] Salir". Con mando muestra sus botones (Xbox, PlayStation...) y con teclado las teclas ("Enter", "Espacio"...).
## Es lo único que hay para jugar: no hay botones duplicados en la pantalla. Cada ítem también se puede tocar con el mouse.
## `set_items([{slot: PadGlyph.Slot | name: "LB|RB", key: "Enter", text, call: Callable, dim: bool}])`:
##   slot / name: el botón del mando (de cara, o con nombre: LB, RB, LT, DPAD; varios con "|") · key: la tecla del teclado (varias con "|") · text: lo que hace ·
##   call: lo que pasa al tocarlo con el mouse · dim: la acción no se puede hacer ahora.

const PadGlyph := preload("res://scripts/pad_glyph.gd")
const Controls := preload("res://scripts/controls.gd")
const VoxelLabel := preload("res://scripts/voxel_label.gd")

var items: Array = []
var _icons: Array = []
var _labels: Array = []
var _was_pad := false


## Saca el foco de todos los botones de una pantalla: se juega apretando botones y no moviéndose por la interfaz (el mouse sigue andando).
static func focus_none(node: Node) -> void:
	if node is Control:
		(node as Control).focus_mode = Control.FOCUS_NONE
	for c in node.get_children():
		focus_none(c)


## Saca del árbol (sin borrarlos) los botones que la botonera reemplaza: así ningún `_refresh` de la pantalla los vuelve a mostrar. Las pruebas siguen pudiendo apretarlos.
static func retire(buttons: Array) -> Array:
	for b in buttons:
		if b != null and b.get_parent() != null:
			b.get_parent().remove_child(b)
	return buttons


static func free_retired(buttons: Array) -> void:
	for b in buttons:
		if is_instance_valid(b) and b.get_parent() == null:
			b.free()


class _Icon extends Control:
	var slot := -1
	var named := ""
	var key := ""
	var dim := false

	func _init() -> void:
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(new_slot: int, new_named: String, new_key: String, new_dim: bool) -> void:
		slot = new_slot
		named = new_named
		key = new_key
		dim = new_dim
		refresh_size()

	func _parts() -> PackedStringArray:
		if Controls.using_pad:
			return named.split("|") if named != "" else PackedStringArray([""])
		return key.split("|") if key != "" else PackedStringArray([""])

	func _cap_width(text: String) -> float:
		return maxf(26.0, ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 14.0)

	func refresh_size() -> void:
		var w := 0.0
		if Controls.using_pad:
			w = 46.0 + 52.0 * maxi(named.count("|"), 0) if named != "" else 46.0
		else:
			for part in _parts():
				w += _cap_width(part) + 4.0
		custom_minimum_size = Vector2(w, 40)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		if Controls.using_pad:
			if named != "":
				var parts := named.split("|")
				var x := c.x - (parts.size() - 1) * 26.0
				for part in parts:
					PadGlyph.draw_named(self, Vector2(x, c.y), 12.0, part, dim)
					x += 52.0
			elif slot >= 0:
				PadGlyph.draw(self, c, 13.0, slot, dim)
			return
		var parts := _parts()
		var total := 0.0
		for part in parts:
			total += _cap_width(part) + 4.0
		var x := c.x - total * 0.5
		for part in parts:
			var w := _cap_width(part)
			PadGlyph.draw_cap(self, Vector2(x + w * 0.5, c.y), w, 15.0, part, dim)
			x += w + 4.0


class _Item extends HBoxContainer:
	var action: Callable = Callable()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and action.is_valid():
			action.call()
			accept_event()


func _init() -> void:
	add_theme_constant_override("separation", 10)
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_dt: float) -> void:
	if Controls.using_pad != _was_pad:   # cambió el dispositivo: se redibuja con los botones o con las teclas
		_was_pad = Controls.using_pad
		for icon in _icons:
			icon.refresh_size()


func set_items(new_items: Array) -> void:
	items = new_items
	_was_pad = Controls.using_pad
	for c in get_children():
		c.queue_free()
	_icons.clear()
	_labels.clear()
	for it in items:
		var box := _Item.new()
		box.add_theme_constant_override("separation", 5)
		box.action = it.get("call", Callable())
		box.mouse_filter = Control.MOUSE_FILTER_STOP if box.action.is_valid() else Control.MOUSE_FILTER_IGNORE
		if box.action.is_valid():
			box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_child(box)
		var icon := _Icon.new()
		icon.setup(int(it.get("slot", -1)), str(it.get("name", "")), str(it.get("key", "")), bool(it.get("dim", false)))
		box.add_child(icon)
		var l := VoxelLabel.new()
		l.cube = 1.8
		l.color = Color(0.9, 0.86, 1.0) if not icon.dim else Color(0.5, 0.46, 0.55)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.text = str(it.text)
		box.add_child(l)
		_icons.append(icon)
		_labels.append(l)


## Apaga o enciende un ítem (por posición) sin rearmar la barra.
func set_dim(i: int, dim: bool) -> void:
	if i < 0 or i >= _icons.size() or _icons[i].dim == dim:
		return
	_icons[i].dim = dim
	_icons[i].queue_redraw()
	_labels[i].color = Color(0.5, 0.46, 0.55) if dim else Color(0.9, 0.86, 1.0)
