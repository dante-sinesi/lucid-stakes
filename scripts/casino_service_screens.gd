extends RefCounted
## Pantallas de las estaciones de servicio del casino (las reglas están en casino_services.gd): Taller y Caja fuerte (y la Tienda).
## Todas se abren como los juegos (casino_scene._open_screen): `setup(run, rng, quick)`, señal `closed` al salir y `resolved` cuando algo cambió
## en el run (hay que guardar).

const NumberFormat := preload("res://scripts/number_format.gd")
const Services := preload("res://scripts/casino_services.gd")
const Showcase := preload("res://scripts/showcase.gd")
const Items := preload("res://scripts/items.gd")
const ItemSlot := preload("res://scripts/item_slot.gd")
const UI := preload("res://scripts/menu_ui.gd")
const PadHints := preload("res://scripts/pad_hints.gd")
const PadGlyph := preload("res://scripts/pad_glyph.gd")
const Draw := preload("res://scripts/voxel_draw.gd")
const ClarityCounter := preload("res://scripts/clarity_counter.gd")
const Loc := preload("res://scripts/loc.gd")
const Sfx := preload("res://scripts/sfx.gd")

const GOOD := Color(0.8, 1.0, 0.7)
const BAD := Color(1.0, 0.65, 0.55)


## La pantalla de una estación según su id ("taller", "caja" o "tienda").
static func make(id: String) -> Control:
	match id:
		"taller": return TallerScreen.new()
		"caja": return CajaScreen.new()
		"tienda": return TiendaScreen.new()
	return TiendaScreen.new()


## Lo común: fondo, contador de claridad, Salir, título y una columna central.
class Base extends Control:
	var hints
	signal resolved
	signal closed
	signal open_shop   ## se pidió ir a la tienda (las estaciones tienen un botón; la tienda no)

	var run
	var rng: RandomNumberGenerator
	var fast := false
	var service_id := ""
	var claridad_counter
	var col: VBoxContainer
	var message: Control
	var exit_button: Button

	func setup(run_state, random: RandomNumberGenerator, quick := false) -> void:
		run = run_state
		rng = random
		fast = quick
		_build_frame()
		_build_body()
		_refresh()

	func _build_frame() -> void:
		name = service_id
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var bg := ColorRect.new()
		bg.color = Color(0.015, 0.008, 0.035, 0.93)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		var top := HBoxContainer.new()
		top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		top.offset_left = 24
		top.offset_right = -24
		top.offset_top = 14
		top.add_theme_constant_override("separation", 12)
		add_child(top)
		claridad_counter = ClarityCounter.new(4.0)
		claridad_counter.name = "claridad"
		top.add_child(claridad_counter)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(gap)
		if service_id != "tienda":
			var shop_button := UI.button("Tienda", false, 3.0, 20, false)
			shop_button.name = "tienda"
			shop_button.pressed.connect(func(): open_shop.emit())
			top.add_child(shop_button)
		exit_button = UI.button("Salir", false, 3.0, 16, false)
		exit_button.name = "salir"
		exit_button.pressed.connect(func(): request_close())
		top.add_child(exit_button)
		var replaced: Array = [exit_button]
		var shop_node := top.get_node_or_null("tienda")
		if shop_node != null:
			replaced.append(shop_node)
		hints = PadHints.attach(self, [], replaced)
		_set_hints([])
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(center)
		col = VBoxContainer.new()
		col.add_theme_constant_override("separation", 14)
		center.add_child(col)
		var title := UI.label(col, str(Services.INFO[service_id].name), 5, UI.GOLD)
		title.dance = true
		UI.label(col, str(Services.INFO[service_id].desc), 2.5, Color(0.8, 0.76, 0.92), true, 900)

	func _build_body() -> void:
		pass

	## La botonera: lo propio de cada servicio, la tienda (LB o Q, salvo en la tienda misma) y salir.
	func _set_hints(extra: Array) -> void:
		var items: Array = extra.duplicate()
		if service_id != "tienda":
			items.append({"name": "LB", "key": "Q", "text": Loc.t("Tienda"), "keycode": KEY_Q, "call": func(): open_shop.emit()})
		items.append({"slot": PadGlyph.Slot.EAST, "key": "Esc", "text": Loc.t("Salir"), "call": func(): request_close()})
		if hints != null:
			hints.set_items(items)

	## Mover la selección de los casilleros con las flechas (cada servicio con casilleros lo implementa).
	func step_selection(_dir: int) -> void:
		pass

	func _refresh() -> void:
		claridad_counter.value = run.claridad

	func button(parent: Node, text: String, node_name: String, action: Callable, primary := false, cells := 0) -> Button:
		var b := UI.button(text, primary, 3.0, cells, false)
		b.name = node_name
		b.pressed.connect(action)
		parent.add_child(b)
		return b

	func say(text: String, color := Color(0.9, 0.86, 1.0)) -> void:
		message.text = text
		message.color = color

	func request_close() -> void:
		closed.emit()

	func _unhandled_input(event: InputEvent) -> void:
		if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
			return
		match event.keycode:
			KEY_ESCAPE:
				request_close()
				get_viewport().set_input_as_handled()
			KEY_LEFT, KEY_UP:
				step_selection(-1)
				get_viewport().set_input_as_handled()
			KEY_RIGHT, KEY_DOWN:
				step_selection(1)
				get_viewport().set_input_as_handled()


## Salón: vender o cambiar un boost o consumible.
class TallerScreen extends Base:
	var boost_row: HBoxContainer
	var consumable_row: HBoxContainer
	var info: Control
	var sell_button: Button
	var swap_button: Button
	var sel_kind := ""
	var sel_index := -1
	var slots := {}   # "boost:0" -> casillero

	func _init() -> void:
		service_id = "taller"

	func _build_body() -> void:
		UI.label(col, "Boosts", 2.5, Color(0.8, 0.76, 0.92))
		boost_row = HBoxContainer.new()
		boost_row.add_theme_constant_override("separation", 8)
		boost_row.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(boost_row)
		UI.label(col, "Consumibles", 2.5, Color(0.8, 0.76, 0.92))
		consumable_row = HBoxContainer.new()
		consumable_row.add_theme_constant_override("separation", 8)
		consumable_row.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(consumable_row)
		info = UI.label(col, "", 2.5, Draw.MARBLE, true, 900)
		info.custom_minimum_size = Vector2(900, 60)
		info.vcenter = true
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		col.add_child(row)
		sell_button = button(row, Loc.t("Vender"), "vender", func(): sell(), true, 40)
		swap_button = button(row, Loc.t("Cambiar"), "cambiar", func(): swap(), false, 40)
		hints.replaced.append_array(PadHints.hide_buttons([sell_button, swap_button]))   # (la botonera de abajo los reemplaza)
		message = UI.label(col, "", 2.5, Color(0.9, 0.86, 1.0), true, 900)
		message.custom_minimum_size = Vector2(900, 40)
		message.vcenter = true

	func _fill(row: HBoxContainer, kind: String, list: Array) -> void:
		for ch in row.get_children():
			ch.queue_free()
		for i in list.size():
			var slot := ItemSlot.new()
			slot.item_id = str(list[i])
			slot.interactive = true
			slot.pressed.connect(select.bind(kind, i))
			slot.selected = (kind == sel_kind and i == sel_index)
			row.add_child(slot)
			slots["%s:%d" % [kind, i]] = slot
		if list.is_empty():
			UI.label(row, "(vacío)", 2.5, Color(0.6, 0.55, 0.7))

	func select(kind: String, index: int) -> void:
		sel_kind = kind
		sel_index = index
		_refresh()

	func step_selection(dir: int) -> void:
		var keys: Array = slots.keys()
		if keys.is_empty():
			return
		var i := keys.find("%s:%d" % [sel_kind, sel_index])
		var nk: String = str(keys[0] if i < 0 else keys[posmod(i + dir, keys.size())])
		var parts := nk.split(":")
		select(parts[0], int(parts[1]))

	func _selected_id() -> String:
		var list: Array = run.boosts if sel_kind == "boost" else run.consumables
		return str(list[sel_index]) if sel_index >= 0 and sel_index < list.size() else ""

	func sell() -> void:
		var res: Dictionary = Services.sell(run, sel_kind, sel_index)
		if res.ok:
			Sfx.play("coin")
			say(Loc.f("Vendiste %s: +%d de claridad.", [Loc.t(str(Items.get_item(res.id).name)), int(res.claridad)]), GOOD)
			sel_index = -1
			resolved.emit()
		else:
			say(str(res.error), BAD)
		_refresh()

	func swap() -> void:
		var res: Dictionary = Services.swap(run, sel_kind, sel_index, rng)
		if res.ok:
			Sfx.play("chip")
			say(Loc.f("Cambiaste %s por %s (−%d).", [Loc.t(str(Items.get_item(res.old).name)), Loc.t(str(Items.get_item(res.new).name)), int(res.price)]), GOOD)
			resolved.emit()
		else:
			say(str(res.error), BAD)
		_refresh()

	func _refresh() -> void:
		super._refresh()
		slots.clear()
		_fill(boost_row, "boost", run.boosts)
		_fill(consumable_row, "consumable", run.consumables)
		var id := _selected_id()
		if id == "":
			sel_index = -1
			info.text = Loc.t("Toca un ítem para venderlo o cambiarlo.")
			sell_button.disabled = true
			swap_button.disabled = true
			sell_button.set_label(Loc.t("Vender"))
			swap_button.set_label(Loc.t("Cambiar"))
			_update_taller_hints()
			return
		var it := Items.get_item(id)
		info.text = "%s: %s" % [Loc.t(str(it.name)), Loc.t(str(it.desc))]
		sell_button.set_label(Loc.f("Vender (+%d)", [Services.sell_price(run, id)]))
		swap_button.set_label(Loc.f("Cambiar (−%d)", [Services.swap_price(run)]))
		sell_button.disabled = false
		swap_button.disabled = Services.swap_options(run, sel_kind, sel_index).is_empty() or not run.can_afford(Services.swap_price(run))
		_update_taller_hints()

	func _update_taller_hints() -> void:
		_set_hints([{"name": "DPAD_LR", "key": "← | →", "text": Loc.t("Elegir")},
				{"slot": PadGlyph.Slot.SOUTH, "key": "Enter", "text": sell_button.text, "dim": sell_button.disabled, "keycode": [KEY_ENTER, KEY_KP_ENTER], "call": func(): if not sell_button.disabled: sell()},
				{"slot": PadGlyph.Slot.WEST, "key": "Espacio", "text": swap_button.text, "dim": swap_button.disabled, "keycode": KEY_SPACE, "call": func(): if not swap_button.disabled: swap()}])


## La tienda: tres premios de la visita (uno épico, uno raro y uno común), a la venta a precio fijo. Caro pero seguro.
class TiendaScreen extends Base:
	var offers_row: HBoxContainer
	var info: Control
	var buy_button: Button
	var sel := ""   # id de la oferta elegida
	var slots := {}

	func _init() -> void:
		service_id = "tienda"

	func _build_body() -> void:
		offers_row = HBoxContainer.new()
		offers_row.add_theme_constant_override("separation", 26)
		offers_row.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(offers_row)
		info = UI.label(col, "", 2.5, Draw.MARBLE, true, 900)
		info.custom_minimum_size = Vector2(900, 70)
		info.vcenter = true
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(row)
		buy_button = button(row, Loc.t("Comprar"), "comprar", func(): buy(), true, 44)
		hints.replaced.append_array(PadHints.hide_buttons([buy_button]))
		message = UI.label(col, "", 2.5, Color(0.9, 0.86, 1.0), true, 900)
		message.custom_minimum_size = Vector2(900, 40)
		message.vcenter = true

	func select(id: String) -> void:
		sel = id
		_refresh()

	func step_selection(dir: int) -> void:
		var ids: Array = slots.keys()
		if ids.is_empty():
			return
		var i := ids.find(sel)
		select(str(ids[0] if i < 0 else ids[posmod(i + dir, ids.size())]))

	func buy() -> void:
		var res: Dictionary = Showcase.buy(run, sel)
		if res.ok:
			Sfx.play("coin")
			say(Loc.f("Compraste %s (−%d de claridad).", [Loc.t(str(Items.get_item(sel).name)), int(res.price)]), GOOD)
			sel = ""
			resolved.emit()
		else:
			say(Loc.t(str(res.error)), BAD)
		_refresh()

	func _refresh() -> void:
		super._refresh()
		slots.clear()
		for ch in offers_row.get_children():
			ch.queue_free()
			offers_row.remove_child(ch)
		var offers := Showcase.shop_offers(run)
		for it in offers:
			var box := VBoxContainer.new()
			box.add_theme_constant_override("separation", 6)
			var slot := ItemSlot.new()
			slot.item_id = str(it.id)
			slot.interactive = true
			slot.pressed.connect(select.bind(str(it.id)))
			slot.selected = (str(it.id) == sel)
			slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			box.add_child(slot)
			slots[str(it.id)] = slot
			var price := UI.label(box, NumberFormat.fmt(Showcase.shop_price(run, it)), 3, UI.GOLD if run.can_afford(Showcase.shop_price(run, it)) else BAD, false)
			price.name = "precio_" + str(it.id)
			offers_row.add_child(box)
		if offers.is_empty():
			UI.label(offers_row, Loc.t("Ya no queda nada en la vitrina de la tienda."), 2.5, Color(0.6, 0.55, 0.7))
		if sel == "" or Items.get_item(sel).is_empty() or not Showcase.shop_offers(run).any(func(o): return o.id == sel):
			sel = ""
			info.text = Loc.t("Toca un premio para ver qué hace.")
			buy_button.disabled = true
			buy_button.set_label(Loc.t("Comprar"))
			_update_tienda_hints()
			return
		var item := Items.get_item(sel)
		var p := Showcase.shop_price(run, item)
		info.text = "%s: %s" % [Loc.t(str(item.name)), Loc.t(str(item.desc))]
		buy_button.set_label(Loc.f("Comprar (−%d)", [p]))
		buy_button.disabled = not run.can_afford(p)
		_update_tienda_hints()

	func _update_tienda_hints() -> void:
		_set_hints([{"name": "DPAD_LR", "key": "← | →", "text": Loc.t("Elegir")},
				{"slot": PadGlyph.Slot.SOUTH, "key": "Enter", "text": buy_button.text, "dim": buy_button.disabled, "keycode": [KEY_ENTER, KEY_KP_ENTER], "call": func(): if not buy_button.disabled: buy()}])


## Casino: guardar claridad con interés para el casino siguiente.
class CajaScreen extends Base:
	var vault_label: Control
	var deposit_buttons := {}
	var withdraw_button: Button

	func _init() -> void:
		service_id = "caja"

	func _build_body() -> void:
		vault_label = UI.label(col, "", 3, Draw.MARBLE, true, 900)
		vault_label.custom_minimum_size = Vector2(900, 70)
		vault_label.vcenter = true
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		col.add_child(row)
		deposit_buttons["cuarto"] = button(row, Loc.t("Guardar 1/4"), "guardar_cuarto", func(): deposit(int(run.claridad / 4)), false, 34)
		deposit_buttons["mitad"] = button(row, Loc.t("Guardar 1/2"), "guardar_mitad", func(): deposit(int(run.claridad / 2)), false, 34)
		deposit_buttons["todo"] = button(row, Loc.t("Guardar todo"), "guardar_todo", func(): deposit(run.claridad), false, 40)
		withdraw_button = button(col, Loc.t("Retirar (sin interés)"), "retirar", func(): withdraw(), false, 60)
		withdraw_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hints.replaced.append_array(PadHints.hide_buttons([deposit_buttons.cuarto, deposit_buttons.mitad, deposit_buttons.todo, withdraw_button]))
		message = UI.label(col, "", 2.5, Color(0.9, 0.86, 1.0), true, 900)
		message.custom_minimum_size = Vector2(900, 40)
		message.vcenter = true

	func deposit(amount: int) -> void:
		var res: Dictionary = Services.deposit(run, amount)
		if res.ok:
			Sfx.play("coin")
			say(Loc.f("Guardaste %d de claridad.", [amount]), GOOD)
			resolved.emit()
		else:
			say(str(res.error), BAD)
		_refresh()

	func withdraw() -> void:
		var n: int = Services.withdraw(run)
		if n > 0:
			Sfx.play("coin")
			say(Loc.f("Retiraste %d de claridad.", [n]), GOOD)
			resolved.emit()
		_refresh()

	func _refresh() -> void:
		super._refresh()
		if run.vault > 0:
			vault_label.text = Loc.f("Guardado: %d. En el próximo casino cobras %d (+%d %%).", [run.vault, Services.vault_payout(run), int(round(Services.VAULT_INTEREST * 100.0))])
		else:
			vault_label.text = Loc.f("No hay nada guardado. Cada casino que pasa rinde un %d %% de interés.", [int(round(Services.VAULT_INTEREST * 100.0))])
		deposit_buttons.cuarto.disabled = run.claridad < 4
		deposit_buttons.mitad.disabled = run.claridad < 2
		deposit_buttons.todo.disabled = run.claridad < 1
		withdraw_button.disabled = run.vault <= 0
		_set_hints([{"slot": PadGlyph.Slot.SOUTH, "key": "Enter", "text": deposit_buttons.cuarto.text, "dim": deposit_buttons.cuarto.disabled, "keycode": [KEY_ENTER, KEY_KP_ENTER], "call": func(): deposit(int(run.claridad / 4))},
				{"slot": PadGlyph.Slot.WEST, "key": "Espacio", "text": deposit_buttons.mitad.text, "dim": deposit_buttons.mitad.disabled, "keycode": KEY_SPACE, "call": func(): deposit(int(run.claridad / 2))},
				{"slot": PadGlyph.Slot.NORTH, "key": "C", "text": deposit_buttons.todo.text, "dim": deposit_buttons.todo.disabled, "keycode": KEY_C, "call": func(): deposit(run.claridad)},
				{"name": "RB", "key": "E", "text": withdraw_button.text, "dim": withdraw_button.disabled, "keycode": KEY_E, "call": func(): withdraw()}])
