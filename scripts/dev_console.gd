extends CanvasLayer
## Consola del modo dev: un panel arriba con el historial y una línea para escribir. Se abre y se cierra con F1 (Esc también la cierra).
## No hace nada por sí sola: avisa con `command_entered(texto)` y quien la creó (main.gd) ejecuta el comando con DevCommands.

signal command_entered(line: String)
signal toggled(open: bool)

const MAX_HISTORY := 8

var panel: Control
var output: RichTextLabel
var input: LineEdit
var history: Array[String] = []   # comandos escritos antes (flechas arriba y abajo)
var _hist_pos := -1


func _init() -> void:
	layer = 200
	name = "consola_dev"
	panel = ColorRect.new()
	(panel as ColorRect).color = Color(0.03, 0.02, 0.06, 0.92)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 230
	panel.visible = false
	add_child(panel)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 10
	col.offset_right = -10
	col.offset_top = 8
	col.offset_bottom = -8
	panel.add_child(col)
	output = RichTextLabel.new()
	output.bbcode_enabled = false
	output.scroll_following = true
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.add_theme_font_size_override("normal_font_size", 16)
	col.add_child(output)
	input = LineEdit.new()
	input.placeholder_text = "Modo dev: escribí un comando (help para ver la lista)"
	input.add_theme_font_size_override("font_size", 18)
	input.text_submitted.connect(_on_submit)
	input.gui_input.connect(_on_input_key)
	col.add_child(input)
	print_line("Consola dev. " + "help: lista de comandos")


func is_open() -> bool:
	return panel.visible


func toggle() -> void:
	set_open(not panel.visible)


func set_open(open: bool) -> void:
	panel.visible = open
	if open:
		input.grab_focus()
	else:
		input.release_focus()
		input.clear()
	toggled.emit(open)


func print_line(text: String) -> void:
	output.append_text(text + "\n")


func _on_submit(line: String) -> void:
	input.clear()
	_hist_pos = -1
	if line.strip_edges() == "":
		return
	history.append(line)
	if history.size() > 50:
		history.pop_front()
	print_line("> " + line)
	command_entered.emit(line)


func _on_input_key(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	match event.keycode:
		KEY_ESCAPE, KEY_F1:
			set_open(false)
			get_viewport().set_input_as_handled()
		KEY_UP:
			if not history.is_empty():
				_hist_pos = history.size() - 1 if _hist_pos < 0 else maxi(_hist_pos - 1, 0)
				input.text = history[_hist_pos]
				input.caret_column = input.text.length()
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			if _hist_pos >= 0:
				_hist_pos += 1
				input.text = history[_hist_pos] if _hist_pos < history.size() else ""
				if _hist_pos >= history.size():
					_hist_pos = -1
				input.caret_column = input.text.length()
			get_viewport().set_input_as_handled()
