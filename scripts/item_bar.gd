extends VBoxContainer
## Barra vertical de ítems (como la de Minecraft pero de costado): casilleros de consumibles (izquierda) o de boosts (derecha).
## La cantidad de casilleros NO es fija: sale de RunState (consumable_capacity / boost_capacity), así que hay boosts que
## agrandan las barras (acumulables). Pasar el mouse por un casillero muestra el nombre y la descripción del ítem.

const ItemSlot := preload("res://scripts/item_slot.gd")
const Items := preload("res://scripts/items.gd")
const VoxelLabel := preload("res://scripts/voxel_label.gd")
const Draw := preload("res://scripts/voxel_draw.gd")
const Loc := preload("res://scripts/loc.gd")

signal slot_pressed(index: int)

enum Kind { CONSUMABLE, BOOST }

var kind: int = Kind.CONSUMABLE
var run
var slots: Array = []
var interactive := false
var min_y := 4.0              # no sube más arriba de acá (para dejar lugar a otros textos del HUD)
var edge := 0                # 0 = pegada a la izquierda de la pantalla, 1 = a la derecha
var tip: Control            # descripción del ítem bajo el mouse (la agrega quien crea la barra, a la capa de la interfaz)
var _tip_index := -1


## Se queda centrada en vertical y pegada a su borde aunque cambie la cantidad de casilleros.
func _process(_delta: float) -> void:
	var vs := get_viewport_rect().size
	var sz := get_combined_minimum_size()
	var y := clampf(maxf((vs.y - sz.y) * 0.5, min_y), 4.0, maxf(vs.y - sz.y - 4.0, 4.0))
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
	reset_size()


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
