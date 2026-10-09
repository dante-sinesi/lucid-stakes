extends RefCounted
## Piezas de interfaz de las reglas de la casa (casino_rules.gd) que comparten las tres mesas: el renglón que dice qué regla rige y cómo viene,
## los avisos que se suman al resultado y los botones para elegir cuántas fichas apostar (sólo con "Apuesta libre").

const Rules := preload("res://scripts/casino_rules.gd")
const UI := preload("res://scripts/menu_ui.gd")
const Loc := preload("res://scripts/loc.gd")

const COLOR := Color(1.0, 0.86, 0.5)


## El renglón de estado de la regla de la sala ("" si no hay visita: tutorial, entrenamiento).
static func status(run) -> String:
	var id := Rules.rule_id(run)
	var v: Dictionary = run.casino_visit
	match id:
		"fiado":
			return Loc.t("Fiado: ya lo usaste en esta visita.") if v.fiado_used else Loc.t("Fiado: tu primera pérdida de la visita devuelve la mitad.")
		"racha":
			var pct := int(round(Rules.streak_bonus(int(v.streak)) * 100.0))
			return Loc.f("Racha de %d: +%d %% al próximo pago.", [v.streak, pct]) if int(v.streak) >= 2 else Loc.t("Racha: ganá seguido para sumar +10 % cada vez.")
		"libre":
			return Loc.f("Apuesta libre: ×%d fichas.", [Rules.stake(run)]) if Rules.stake(run) > 1 else Loc.t("Apuesta libre: podés apostar varias fichas juntas.")
		"jackpot":
			return Loc.f("Pozo del jackpot: %d de claridad.", [Rules.pool(run)])
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
