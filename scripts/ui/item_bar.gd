extends VBoxContainer
## Barra vertical de ítems (como la de Minecraft pero de costado): casilleros de consumibles (izquierda) o de boosts (derecha).
## La cantidad de casilleros NO es fija: sale de RunState (consumable_capacity / boost_capacity), así que hay boosts que
## agrandan las barras (acumulables). Pasar el mouse por un casillero muestra el nombre y la descripción del ítem.

const ItemSlot := preload("res://scripts/ui/item_slot.gd")
const Items := preload("res://scripts/datos/items.gd")
const VoxelLabel := preload("res://scripts/ui/voxel_label.gd")
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const Loc := preload("res://scripts/idioma/loc.gd")

signal slot_pressed(index: int)
signal discarded(kind: int, id: String)   ## se tiró un ítem (el que recibe esto actualiza el HUD y guarda)

enum Kind { CONSUMABLE, BOOST }

var kind: int = Kind.CONSUMABLE
var run
var slots: Array = []
var interactive := false
var min_y := 4.0              # no sube más arriba de acá (para dejar lugar a otros textos del HUD)
var edge := 0                # 0 = pegada a la izquierda de la pantalla, 1 = a la derecha
var bottom := false          # pegada al borde de abajo (si no, centrada en vertical)
var tip: Control            # descripción del ítem bajo el mouse (la agrega quien crea la barra, a la capa de la interfaz)
var _tip_index := -1
var _prompt: Control


## Se queda centrada en vertical y pegada a su borde aunque cambie la cantidad de casilleros.
func _process(_delta: float) -> void:
	var vs := get_viewport_rect().size
	var sz := get_combined_minimum_size()
	var y := clampf(maxf((vs.y - sz.y) * 0.5, min_y), 4.0, maxf(vs.y - sz.y - 4.0, 4.0))
	if bottom:
		y = maxf(vs.y - sz.y - 14.0, 4.0)
	position = Vector2(14.0 if edge == 0 else vs.x - sz.x - 14.0, y)


func _init() -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(run_state, bar_kind: int, can_use := false) -> void:
	run = run_state
	kind = bar_kind
	interactive = can_use
	refresh()


func capacity() -> int:
	return run.consumable_capacity() if kind == Kind.CONSUMABLE else run.boost_capacity()


func items() -> Array:
	return run.consumables if kind == Kind.CONSUMABLE else run.boosts


## Ajusta la cantidad de casilleros a la capacidad actual y pone cada ítem en el suyo.
func refresh() -> void:
	if run == null:
		return
	var cap := capacity()
	while slots.size() < cap:
		var slot := ItemSlot.new()
		slot.interactive = interactive and kind == Kind.CONSUMABLE
		var idx := slots.size()
		slot.pressed.connect(func(): slot_pressed.emit(idx))
		slot.hovered.connect(func(on: bool): _on_hover(idx, on))
		slot.discard.connect(func(): ask_discard(idx))
		add_child(slot)
		slots.append(slot)
	while slots.size() > cap:
		var last = slots.pop_back()
		last.queue_free()
	var n := slots.size()
	var vh := get_viewport_rect().size.y if is_inside_tree() else 720.0
	var ss := clampf((vh - 40.0 - (n - 1) * 8.0) / maxf(n, 1.0), 44.0, ItemSlot.SLOT)
	for slot in slots:
		slot.custom_minimum_size = Vector2(ss, ss)
	var list := items()
	for i in slots.size():
		slots[i].item_id = list[i] if i < list.size() else ""
		slots[i].key_label = str(i + 1) if kind == Kind.CONSUMABLE else ""
	modulate.a = 1.0 if not list.is_empty() else 0.0   # (sin nada que mostrar, las casillas vacías no se dibujan: aparecen con el primer ítem)
	reset_size()


## El ítem del casillero `idx` no se puede usar ahora: tiembla y muestra el símbolo de cancelado.
func rechazar(idx: int) -> void:
	if idx >= 0 and idx < slots.size():
		slots[idx].rechazar()


## El rectángulo en pantalla del casillero `idx` (para animar un ítem que sale de la barra). Vacío si no existe.
func rect_de(idx: int) -> Rect2:
	if idx >= 0 and idx < slots.size():
		return (slots[idx] as Control).get_global_rect()
	return Rect2()


## Marca un casillero como el elegido para usar (-1: ninguno).
func set_pick(idx: int) -> void:
	for i in slots.size():
		slots[i].selected = i == idx and idx >= 0


## Clic derecho en un casillero: pregunta si se tira (no se recupera claridad) y, si se confirma, lo saca.
func ask_discard(idx: int) -> void:
	if run == null or _prompt != null or idx >= items().size():
		return
	var k := "boost" if kind == Kind.BOOST else "consumable"
	var err: String = run.discard_error(k, idx)
	var it := Items.get_item(str(items()[idx]))
	if tip != null:
		tip.visible = false
	_prompt = _DiscardPrompt.new()
	_prompt.setup(Loc.f("¿Tirar %s? No recuperas nada.", [Loc.t(str(it.get("name", "")))]) if err == "" else Loc.t(err), err == "")
	_prompt.answered.connect(func(yes: bool):
		_prompt.queue_free()
		_prompt = null
		if yes:
			do_discard(idx))
	var host: Node = get_parent()
	host.add_child(_prompt)


## Tira el ítem del casillero `idx` ya mismo (sin preguntar). Devuelve true si se pudo.
func do_discard(idx: int) -> bool:
	var k := "boost" if kind == Kind.BOOST else "consumable"
	var id: String = run.discard(k, idx)
	if id == "":
		return false
	refresh()
	discarded.emit(kind, id)
	return true


func _on_hover(idx: int, on: bool) -> void:
	if tip == null:
		return
	if not on:
		if _tip_index == idx:
			tip.visible = false
			_tip_index = -1
		return
	var id: String = slots[idx].item_id
	if id == "":
		return
	var it := Items.get_item(id)
	_tip_index = idx
	tip.text = Loc.join([Loc.t(str(it.get("name", id))), Loc.t(str(it.get("desc", "")))])
	tip.visible = true
	var slot: Control = slots[idx]
	var r := slot.get_global_rect()
	var tsize := tip.get_combined_minimum_size()
	if kind == Kind.CONSUMABLE:
		tip.global_position = Vector2(r.end.x + 14, r.position.y)
	else:
		tip.global_position = Vector2(r.position.x - 14 - tsize.x, r.position.y)


## Cartelito de confirmación al tirar un ítem: "Tirar" / "Cancelar" (Esc o clic derecho también cancelan).
class _DiscardPrompt extends Control:
	const UI := preload("res://scripts/ui/menu_ui.gd")
	signal answered(yes: bool)
	var yes_button: Button
	var no_button: Button

	func setup(text: String, can_do: bool) -> void:
		name = "tirar_item"
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		z_index = 50
		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.01, 0.05, 0.7)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(center)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 16)
		center.add_child(col)
		var label := UI.label(col, text, 3, Color(1, 0.95, 0.85), true, 760)
		label.plate_alpha = 0.9
		label.localize = false   # (ya viene traducido)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 20)
		col.add_child(row)
		yes_button = UI.button("Tirar", can_do, 3.0, 24, false)
		yes_button.name = "tirar"
		yes_button.disabled = not can_do
		yes_button.pressed.connect(func(): answered.emit(true))
		row.add_child(yes_button)
		no_button = UI.button("Cancelar", not can_do, 3.0, 28, false)
		no_button.name = "cancelar"
		no_button.pressed.connect(func(): answered.emit(false))
		row.add_child(no_button)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			answered.emit(false)
			accept_event()

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			answered.emit(false)
			get_viewport().set_input_as_handled()
