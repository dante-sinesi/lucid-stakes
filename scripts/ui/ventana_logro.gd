extends Control
## Una ventana de logro (fondo oscuro transparente, un título grande y, debajo, una línea por cada cosa lograda), como la del resumen de claridad. Se usa cuando se desbloquea un personaje
## nuevo. Uso: `mostrar(titulo, lineas)`; emite `cerrado` con Espacio, Enter o un clic.

const UI := preload("res://scripts/ui/menu_ui.gd")
const PadHints := preload("res://scripts/ui/pad_hints.gd")
const PadGlyph := preload("res://scripts/ui/pad_glyph.gd")
const MenuAnim := preload("res://scripts/ui/menu_anim.gd")
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const Loc := preload("res://scripts/idioma/loc.gd")

signal cerrado

var titulo_label: Control
var lista: VBoxContainer
var donde_label: Control   # dónde se elige lo que se desbloqueó (una sola línea, no cambia nada de la partida)


func _init() -> void:
	name = "ventana_logro"
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
	col.add_theme_constant_override("separation", 30)
	centro.add_child(col)
	titulo_label = UI.label(col, "", 6, UI.GOLD)
	titulo_label.dance = true
	lista = VBoxContainer.new()
	lista.add_theme_constant_override("separation", 14)
	col.add_child(lista)
	donde_label = UI.label(col, "Lo eliges en el menú principal, en «Personaje».", 3, Color(0.8, 0.76, 0.92), false)
	donde_label.align = UI.VoxelLabel.Align.CENTER
	PadHints.attach(self, [{"slot": PadGlyph.Slot.SOUTH, "key": "Espacio", "text": Loc.t("Continuar"), "keycode": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER], "call": cerrar}])


func mostrar(titulo: String, lineas: Array) -> void:
	titulo_label.text = titulo
	for ch in lista.get_children():
		lista.remove_child(ch)
		ch.queue_free()
	for l in lineas:
		var t := UI.label(lista, str(l), 4, Draw.MARBLE, false)
		t.align = UI.VoxelLabel.Align.CENTER
	visible = true
	MenuAnim.pop_in(titulo_label, 1.4, 0.4)
	MenuAnim.stagger(lista.get_children(), 0.12, 0.3, 0.3)


func cerrar() -> void:
	if visible:
		visible = false
		cerrado.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cerrar()
		accept_event()
