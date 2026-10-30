extends Control
## La ventana del resumen de claridad (fondo oscuro transparente): arriba la cuenta "claridad con la que entraste + lo que se añade = claridad total" y, debajo, una fila por cada
## cosa que sumó (la torre, los dados, un boost, un consumible...) con cuánto aportó. Se usa al entrar al casino y, después del balance del casino, antes de empezar la torre.
## Uso: `mostrar(titulo, entrada, filas)`; `filas` = [{id: ícono del ítem o "" (la claridad), nombre, valor}]. Emite `cerrado` con Espacio, Enter o un clic.

const UI := preload("res://scripts/ui/menu_ui.gd")
const ClarityCounter := preload("res://scripts/ui/clarity_counter.gd")
const ClarityIcon := preload("res://scripts/ui/clarity_icon.gd")
const Icons := preload("res://scripts/ui/item_icons.gd")
const PadHints := preload("res://scripts/ui/pad_hints.gd")
const PadGlyph := preload("res://scripts/ui/pad_glyph.gd")
const MenuAnim := preload("res://scripts/ui/menu_anim.gd")
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const Loc := preload("res://scripts/idioma/loc.gd")

signal cerrado

var titulo_label: Control
var entrada_counter
var suma_counter
var total_counter
var lista: VBoxContainer
var filas_mostradas: Array = []   # las filas que se ven (para las pruebas)


func _init() -> void:
	name = "resumen_claridad"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.add_child(col)
	titulo_label = UI.label(col, "", 5, UI.GOLD)
	var cuenta := HBoxContainer.new()
	cuenta.alignment = BoxContainer.ALIGNMENT_CENTER
	cuenta.add_theme_constant_override("separation", 22)
	col.add_child(cuenta)
	entrada_counter = _contador(cuenta)
	_signo(cuenta, "+")
	suma_counter = _contador(cuenta)
	_signo(cuenta, "=")
	total_counter = _contador(cuenta)
	lista = VBoxContainer.new()
	lista.add_theme_constant_override("separation", 10)
	lista.custom_minimum_size = Vector2(760, 0)
	col.add_child(lista)
	PadHints.attach(self, [{"slot": PadGlyph.Slot.SOUTH, "key": "Espacio", "text": Loc.t("Continuar"), "keycode": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER], "call": cerrar}])


func _contador(padre: Control):
	var c := ClarityCounter.new(5.0)
	padre.add_child(c)
	return c


func _signo(padre: Control, txt: String) -> void:
	var l := UI.label(padre, txt, 5, Color(0.85, 0.8, 1.0), false)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Abre la ventana. Sólo se muestran las filas con algo que sumar.
func mostrar(titulo: String, entrada: int, filas: Array) -> void:
	titulo_label.text = titulo
	for ch in lista.get_children():
		lista.remove_child(ch)
		ch.queue_free()
	filas_mostradas = []
	var suma := 0
	for f in filas:
		if int(f.valor) == 0:
			continue
		filas_mostradas.append(f)
		suma += int(f.valor)
		lista.add_child(_fila(f))
	entrada_counter.value = entrada
	suma_counter.value = suma
	total_counter.value = entrada + suma
	visible = true
	MenuAnim.stagger(lista.get_children(), 0.08, 0.25, 0.25)


func cerrar() -> void:
	if visible:
		visible = false
		cerrado.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cerrar()
		accept_event()


func _fila(f: Dictionary) -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 16)
	fila.custom_minimum_size = Vector2(0, 52)
	fila.add_child(_Icono.new(str(f.get("id", ""))))
	var nombre := UI.label(null, str(f.nombre), 3, Draw.MARBLE, false)
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nombre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(nombre)
	var valor := UI.label(null, "%s%d" % ["+" if int(f.valor) > 0 else "", int(f.valor)], 3, UI.GOLD, false)
	valor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(valor)
	return fila


## El ícono de la fila: el del ítem, o el rayo de la claridad si lo que suma no es un ítem (la torre, los dados).
class _Icono extends Control:
	const I := preload("res://scripts/ui/item_icons.gd")
	const CI := preload("res://scripts/ui/clarity_icon.gd")
	var id := ""

	func _init(item_id: String) -> void:
		id = item_id
		custom_minimum_size = Vector2(52, 52)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if id != "" and I.has_icon(id):
			I.draw(self, id, size * 0.5 - Vector2(I.SIZE, I.SIZE) * 4.0 * 0.5, 4.0)
		else:
			CI.draw_bolt(self, size * 0.5, 4.0, 0.6)
