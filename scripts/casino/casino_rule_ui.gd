extends RefCounted
## Piezas de interfaz de las reglas de la casa (casino_rules.gd) que comparten las tres mesas: el renglón que dice qué regla rige y cómo viene,
## los avisos que se suman al resultado y los botones para elegir cuántas fichas apostar (sólo con "Apuesta libre").

const Rules := preload("res://scripts/casino/casino_rules.gd")
const UI := preload("res://scripts/ui/menu_ui.gd")
const Loc := preload("res://scripts/idioma/loc.gd")

const COLOR := Color(1.0, 0.86, 0.5)


## (Ya no se muestra el estado de la regla: lo cuenta el tabernero cuando le hablás.) Devuelve siempre "".
static func status(_run) -> String:
	return ""


## Los avisos de una apuesta ya resuelta (devolución, racha, jackpot), listos para sumar a un texto. "" si no hubo.
static func notes(res: Dictionary) -> String:
	var rules: Dictionary = res.get("rules", {})
	var list: Array = rules.get("notes", [])
	return "" if list.is_empty() else "  " + "  ".join(list)


## Renglón con el estado de la regla (VoxelLabel) para poner en una pantalla de juego.
static func make_status(parent: Node, wrap_px := 0) -> Control:
	var l := UI.label(parent, "", 2, COLOR, true, wrap_px)
	l.name = "regla"
	return l


## Fila "Apuesta: ×1 ×2 ×3 ×5" (sólo se ve con la regla "Apuesta libre"). Devuelve {row, buttons}; `on_change` se llama al elegir una.
static func make_stake_row(parent: Node, run, on_change: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	row.name = "fichas"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	UI.label(row, "Fichas", 2.5, Color(0.85, 0.8, 1.0), false)
	var buttons := {}
	for n in Rules.STAKES:
		var b := UI.button("×%d" % n, false, 2.5, 8, false)
		b.name = "fichas_%d" % n
		b.pressed.connect(func():
			if Rules.set_stake(run, n):
				on_change.call())
		row.add_child(b)
		buttons[n] = b
	return {"row": row, "buttons": buttons}


## Pone la fila como está el estado: visible sólo con la regla, la elegida marcada y bloqueada mientras hay una tirada en curso.
static func refresh_stake(ui: Dictionary, run, enabled: bool) -> void:
	ui.row.visible = Rules.rule_id(run) == "libre"
	for n in ui.buttons:
		ui.buttons[n].selected = n == Rules.stake(run)
		ui.buttons[n].disabled = not enabled
