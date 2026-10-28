extends RefCounted
## Pantallas de las estaciones de servicio del casino (las reglas están en casino_services.gd): el Taller, la Tienda y el Tablón de contratos (scripts/datos/contratos.gd).
## Todas se abren como los juegos (casino_scene._open_screen): `setup(run, rng, quick)`, señal `closed` al salir y `resolved` cuando algo cambió
## en el run (hay que guardar).

const NumberFormat := preload("res://scripts/datos/number_format.gd")
const Services := preload("res://scripts/casino/casino_services.gd")
const Showcase := preload("res://scripts/casino/showcase.gd")
const Items := preload("res://scripts/datos/items.gd")
const ItemSlot := preload("res://scripts/ui/item_slot.gd")
const UI := preload("res://scripts/ui/menu_ui.gd")
const PadHints := preload("res://scripts/ui/pad_hints.gd")
const PadGlyph := preload("res://scripts/ui/pad_glyph.gd")
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const ClarityCounter := preload("res://scripts/ui/clarity_counter.gd")
const Loc := preload("res://scripts/idioma/loc.gd")
const Sfx := preload("res://scripts/sonido/sfx.gd")
const Contratos := preload("res://scripts/datos/contratos.gd")
const Arte := preload("res://scripts/ui/contract_art.gd")

const GOOD := Color(0.8, 1.0, 0.7)
const BAD := Color(1.0, 0.65, 0.55)


## La pantalla de una estación según su id ("taller", "tienda" o "tablon").
static func make(id: String) -> Control:
	match id:
		"taller": return TallerScreen.new()
		"tienda": return TiendaScreen.new()
		"tablon": return TablonScreen.new()
	return TiendaScreen.new()


## Lo común: fondo, contador de claridad, Salir, título y una columna central.
class Base extends Control:
	var hints
	signal resolved
	signal closed
	signal open_shop   ## se pidió ir a la tienda (las estaciones tienen un botón; la tienda no)
	signal open_tablon   ## se pidió volver al tablón (solo cuando la tienda se abrió desde el tablón: son dos pestañas de lo mismo)

	var pestanas := false   ## el tablón y la tienda se ven como dos pestañas ("Contratos" y "Tienda") en vez de un botón suelto

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
		if pestanas:
			var tabs := HBoxContainer.new()
			tabs.add_theme_constant_override("separation", 6)
			var en_tablon := service_id == "tablon"
			var t_contratos := UI.button("Contratos", en_tablon, 3.0, 12, false)
			t_contratos.name = "pestana_contratos"
			t_contratos.pressed.connect(func():
				if not en_tablon:
					open_tablon.emit())
			tabs.add_child(t_contratos)
			var t_tienda := UI.button("Tienda", not en_tablon, 3.0, 12, false)
			t_tienda.name = "tienda"
			t_tienda.pressed.connect(func():
				if en_tablon:
					open_shop.emit())
			tabs.add_child(t_tienda)
			top.add_child(tabs)
			var gap2 := Control.new()
			gap2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top.add_child(gap2)
		elif service_id != "tienda":
			var shop_button := UI.button("Tienda", false, 3.0, 20, false)
			shop_button.name = "tienda"
			shop_button.pressed.connect(func(): open_shop.emit())
			top.add_child(shop_button)
		exit_button = UI.button("Salir", false, 3.0, 16, false)
		exit_button.name = "salir"
		exit_button.pressed.connect(func(): request_close())
		top.add_child(exit_button)
		var replaced: Array = [exit_button]
		var shop_node := top.find_child("tienda", true, false)
		if shop_node != null:
			replaced.append(shop_node)
		if pestanas:
			replaced.append(top.find_child("pestana_contratos", true, false))
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
		if pestanas:   # (Q cambia de pestaña)
			if service_id == "tablon":
				items.append({"name": "LB", "key": "Q", "text": Loc.t("Tienda"), "keycode": KEY_Q, "call": func(): open_shop.emit()})
			else:
				items.append({"name": "LB", "key": "Q", "text": Loc.t("Contratos"), "keycode": KEY_Q, "call": func(): open_tablon.emit()})
		elif service_id != "tienda":
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
			KEY_LEFT, KEY_UP, KEY_A, KEY_W:
				step_selection(-1)
				get_viewport().set_input_as_handled()
			KEY_RIGHT, KEY_DOWN, KEY_D, KEY_S:
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
		_set_hints([{"slot": PadGlyph.Slot.SOUTH, "key": "Espacio", "text": sell_button.text, "dim": sell_button.disabled, "keycode": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER], "call": func(): if not sell_button.disabled: sell()},
				{"slot": PadGlyph.Slot.WEST, "key": "Shift", "text": swap_button.text, "dim": swap_button.disabled, "keycode": KEY_SHIFT, "call": func(): if not swap_button.disabled: swap()}])


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
		_set_hints([{"slot": PadGlyph.Slot.SOUTH, "key": "Espacio", "text": buy_button.text, "dim": buy_button.disabled, "keycode": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER], "call": func(): if not buy_button.disabled: buy()}])


## El tablón de contratos: los papeles colgados (3 a 6, según el casino), con lo que pide cada uno. Se aceptan gratis (o con fianza, en el casino y el gran casino), se descuelgan o se rotan
## por un precio que sube con cada rotación de la visita. Los contratos activos (hasta el límite) se ven en el menú de pausa.
class TablonScreen extends Base:
	var tier := 0              # el nivel del casino (lo pone quien la abre): decide si se acepta con fianza
	var grid: Control
	var info: Control
	var activos_label: Control
	var accept_button: Button
	var fianza_button: Button
	var reject_button: Button
	var rotate_button: Button
	var sel := 0
	var con_fianza := false

	func _init() -> void:
		service_id = "tablon"

	func _build_body() -> void:
		activos_label = UI.label(col, "", 2.5, Color(0.8, 0.76, 0.92), true, 900)
		activos_label.name = "activos"
		grid = Cartelera.new()
		grid.name = "cartelera"
		grid.pressed.connect(select)
		col.add_child(grid)
		info = UI.label(col, "", 2.5, Draw.MARBLE, true, 900)
		info.custom_minimum_size = Vector2(900, 90)
		info.vcenter = true
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		col.add_child(row)
		accept_button = button(row, Loc.t("Aceptar"), "aceptar", func(): accept(), true, 22)
		if Contratos.permite_fianza(tier):
			fianza_button = button(row, Loc.t("Con fianza: no"), "fianza", func(): toggle_fianza(), false, 26)
		reject_button = button(row, Loc.t("Descolgar"), "descolgar", func(): reject(), false, 22)
		rotate_button = button(row, Loc.t("Rotar"), "rotar", func(): rotate_papers(), false, 26)
		var ocultos: Array = [accept_button, reject_button, rotate_button]
		if fianza_button != null:
			ocultos.append(fianza_button)
		hints.replaced.append_array(PadHints.hide_buttons(ocultos))   # (la botonera de abajo los reemplaza)
		message = UI.label(col, "", 2.5, Color(0.9, 0.86, 1.0), true, 900)
		message.custom_minimum_size = Vector2(900, 40)
		message.vcenter = true

	func select(i: int) -> void:
		sel = i
		_refresh()

	func step_selection(dir: int) -> void:
		var n := Contratos.cartelera(run).size()
		if n > 0:
			select(posmod(sel + dir, n))

	func toggle_fianza() -> void:
		con_fianza = not con_fianza
		_refresh()

	func _papel():
		var cart := Contratos.cartelera(run)
		return cart[sel] if sel >= 0 and sel < cart.size() else null

	func accept() -> void:
		var res: Dictionary = Contratos.aceptar(run, sel, con_fianza, tier)
		if res.ok:
			Sfx.play("item")
			say(Loc.t("Aceptaste el contrato: se cobra en cuanto lo cumplas, en la torre que viene."), GOOD)
			resolved.emit()
		else:
			say(str(res.error), BAD)
		_refresh()

	func reject() -> void:
		var res: Dictionary = Contratos.rechazar(run, sel)
		if res.ok:
			Sfx.play("chip")
			say(Loc.t("Descolgaste el papel: en la próxima torre puede aparecer otro."), Color(0.9, 0.86, 1.0))
			resolved.emit()
		else:
			say(str(res.error), BAD)
		_refresh()

	func rotate_papers() -> void:
		var res: Dictionary = Contratos.rotar(run, rng, tier)
		if res.ok:
			Sfx.play("dice")
			say(Loc.t("Los papeles son otros."), GOOD)
			resolved.emit()
		else:
			say(str(res.error), BAD)
		_refresh()

	func _refresh() -> void:
		super._refresh()
		var cart := Contratos.cartelera(run)
		sel = clampi(sel, 0, maxi(cart.size() - 1, 0))
		grid.set_data(cart, sel, run.stage)
		activos_label.text = Loc.f("Contratos activos: %d de %d", [Contratos.activos(run).size(), Contratos.limite(run)])
		var papel = _papel()
		var cost := Contratos.costo_rotar(run)
		rotate_button.set_label(Loc.t("Rotar (gratis)") if cost == 0 else Loc.f("Rotar (−%d)", [cost]))
		rotate_button.disabled = not run.can_afford(cost)
		if fianza_button != null:
			fianza_button.set_label(Loc.t("Con fianza: sí") if con_fianza else Loc.t("Con fianza: no"))
		if papel == null:
			info.text = Loc.t("Aquí no hay ningún papel. En la próxima torre pueden aparecer nuevos.") if cart.is_empty() or cart.count(null) == cart.size() else Loc.t("Este lugar está vacío.")
			accept_button.disabled = true
			reject_button.disabled = true
		else:
			var reward := Contratos.recompensa(papel, run.stage)
			var texto := "%s\n%s\n%s" % [Contratos.titulo(papel), Contratos.condicion(papel), Loc.f("Recompensa: %d de claridad", [reward])]
			if con_fianza and Contratos.permite_fianza(tier):
				texto += "\n" + Loc.f("Con fianza de %d: paga más (×1,5) y la recuperas si lo cumples; si no, la pierdes.", [Contratos.fianza(papel, run.stage)])
			info.text = texto
			accept_button.disabled = false
			reject_button.disabled = false
		_update_tablon_hints()

	func _update_tablon_hints() -> void:
		var items: Array = [{"slot": PadGlyph.Slot.SOUTH, "key": "Espacio", "text": accept_button.text, "dim": accept_button.disabled, "keycode": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER], "call": func(): if not accept_button.disabled: accept()},
				{"slot": PadGlyph.Slot.WEST, "key": "Shift", "text": reject_button.text, "dim": reject_button.disabled, "keycode": KEY_SHIFT, "call": func(): if not reject_button.disabled: reject()},
				{"slot": PadGlyph.Slot.NORTH, "key": "C", "text": rotate_button.text, "dim": rotate_button.disabled, "keycode": KEY_C, "call": func(): if not rotate_button.disabled: rotate_papers()}]
		if fianza_button != null:
			items.append({"name": "RB", "key": "F", "text": fianza_button.text, "keycode": KEY_F, "call": func(): toggle_fianza()})
		_set_hints(items)


## Los papeles colgados, dibujados con el arte de los contratos (contract_art.gd); un clic elige uno.
class Cartelera extends Control:
	signal pressed(index: int)
	const CUBO := 5.0
	const SEPARACION := 24.0
	var papeles: Array = []
	var sel := 0
	var stage := 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func set_data(lista: Array, elegido: int, etapa: int) -> void:
		papeles = lista
		sel = elegido
		stage = etapa
		custom_minimum_size = Vector2(900.0, Arte.PAPEL_ROWS * CUBO + 24.0)
		queue_redraw()

	## Dónde empieza el primer papel: la fila de papeles queda centrada.
	func _x0() -> float:
		var total := papeles.size() * Arte.PAPEL_COLS * CUBO + maxf(papeles.size() - 1.0, 0.0) * SEPARACION
		return maxf((size.x - total) * 0.5, 12.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var paso := Arte.PAPEL_COLS * CUBO + SEPARACION
			var i := int((event.position.x - _x0() + SEPARACION * 0.5) / paso)
			if i >= 0 and i < papeles.size():
				pressed.emit(i)

	func _draw() -> void:
		var ancho := Arte.PAPEL_COLS * CUBO
		var alto := Arte.PAPEL_ROWS * CUBO
		for i in papeles.size():
			var pos := Vector2(_x0() + i * (ancho + SEPARACION), 12.0)
			var p = papeles[i]
			if i == sel:
				draw_rect(Rect2(pos - Vector2(8, 8), Vector2(ancho + 16, alto + 16)), Color(1.0, 0.85, 0.40, 0.35))
				draw_rect(Rect2(pos - Vector2(8, 8), Vector2(ancho + 16, alto + 16)), Color(1.0, 0.85, 0.40), false, 3.0)
			if p == null:
				draw_rect(Rect2(pos, Vector2(ancho, alto)), Color(0.45, 0.32, 0.20, 0.55))
				draw_rect(Rect2(pos, Vector2(ancho, alto)), Color(0.30, 0.20, 0.12), false, 2.0)
				continue
			Arte.dibujar_papel(self, pos, CUBO, int(p.r), str(Contratos.OBJETIVOS[p.obj].icono), int(p.id), true)
