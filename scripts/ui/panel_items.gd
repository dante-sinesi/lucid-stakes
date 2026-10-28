extends "res://scripts/ui/panel_info.gd"
## El panel de boosts y consumibles (docs/panel_informacion.md): la ventana de la derecha, con lo que se tiene y lo que hace cada cosa, con su descripción completa. Se abre como el panel de
## información (mantener o alternar) y comparte su forma. `datos` lo arma main.gd (`_panel_items_datos`): {boosts: [{id, nombre, desc}], max_boosts, consumibles: [...], max_consumibles}.

const Iconos := preload("res://scripts/ui/item_icons.gd")


## Un ítem: su ícono de cubitos y, al lado, el nombre y la descripción.
class Fila extends HBoxContainer:
	const I := preload("res://scripts/ui/item_icons.gd")
	var id := ""

	func _init(item_id: String) -> void:
		id = item_id
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_constant_override("separation", 14)
		var icono := Control.new()
		icono.custom_minimum_size = Vector2(I.SIZE * 4.0 + 4.0, I.SIZE * 4.0 + 4.0)
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icono.draw.connect(func(): I.draw(icono, id, Vector2(2, 2), 4.0))
		add_child(icono)


func _derecha() -> bool:
	return true


func _init() -> void:
	super()
	name = "panel_items"


func _armar() -> void:
	var scroll_anterior := _scroll.scroll_vertical
	_filas.clear()
	for c in _caja.get_children():
		_caja.remove_child(c)
		c.queue_free()
	var d := _datos
	_linea(Loc.t("Boosts y consumibles"), 2.8, UI.GOLD, "titulo")
	_seccion(Loc.f("Boosts %d/%d", [d.get("boosts", []).size(), int(d.get("max_boosts", 0))]), d.get("boosts", []), "boost", Loc.t("Ninguno todavía"))
	_seccion(Loc.f("Consumibles %d/%d", [d.get("consumibles", []).size(), int(d.get("max_consumibles", 0))]), d.get("consumibles", []), "consumible", Loc.t("Ninguno todavía"))
	_despues_de_armar(scroll_anterior)


func _seccion(titulo: String, items: Array, prefijo: String, vacio: String) -> void:
	_separador()
	_linea(titulo, 2.4, Color(0.85, 0.7, 0.3), prefijo + "s_titulo")
	if items.is_empty():
		_linea(vacio, 2.2, COLOR_SUAVE, prefijo + "s_vacio")
		return
	for i in items.size():
		var it: Dictionary = items[i]
		var fila := Fila.new(str(it.get("id", "")))
		fila.name = "%s_%d" % [prefijo, i]
		_caja.add_child(fila)
		_registrar_fila(fila)
		var texto := VBoxContainer.new()
		texto.add_theme_constant_override("separation", 4)
		fila.add_child(texto)
		UI.label(texto, str(it.get("nombre", "")), 2.6, UI.GOLD, false, ANCHO_TEXTO - 40)
		UI.label(texto, str(it.get("desc", "")), 2.2, COLOR_TEXTO, false, ANCHO_TEXTO - 40)
