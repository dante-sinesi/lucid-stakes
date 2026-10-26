extends Control
## Balance del casino: se ve al salir de la sala, antes de la torre siguiente (y mientras ésta se genera). Muestra cuántas partidas se jugaron en
## cada mesa, cuántas se ganaron o perdieron, lo gastado, lo ganado y el neto, más datos sueltos de la visita (mejor jugada, la regla de la casa,
## lo que hay en la caja fuerte). Los datos salen de `CasinoRules.balance(run)`.
## Uso: crear, add_child, setup(run); emite `done` al apretar Continuar.

const Rules := preload("res://scripts/casino/casino_visit.gd")
const UI := preload("res://scripts/ui/menu_ui.gd")
const PadHints := preload("res://scripts/ui/pad_hints.gd")
const PadGlyph := preload("res://scripts/ui/pad_glyph.gd")
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const Services := preload("res://scripts/casino/casino_services.gd")
const Loc := preload("res://scripts/idioma/loc.gd")

signal done

const GOOD := Color(0.65, 0.95, 0.75)
const BAD := Color(1.0, 0.65, 0.55)
const COL_W := [210, 120, 120, 120, 120, 120, 120]

var run
var data := {}
var lines: Array[String] = []      # los renglones de abajo de la tabla (para las pruebas)
var continue_button: Button
var table: GridContainer
var _closed := false


func setup(run_state) -> void:
	run = run_state
	data = Rules.balance(run)
	_build()


func _build() -> void:
	name = "balance"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.008, 0.035, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)
	var title := UI.label(col, "Balance del casino", 5, UI.GOLD)
	title.dance = true
	if str(data.room) != "":
		UI.label(col, Loc.f("%s, etapa %d", [Loc.t(str(data.room)), run.stage]), 2.5, Color(0.8, 0.76, 0.92))
	table = GridContainer.new()
	table.name = "tabla"
	table.columns = COL_W.size()
	table.add_theme_constant_override("h_separation", 10)
	table.add_theme_constant_override("v_separation", 8)
	col.add_child(table)
	for i in 7:
		_cell(UI.GOLD, i, [Loc.t("Juego"), Loc.t("Partidas"), Loc.t("Ganadas"), Loc.t("Perdidas"), Loc.t("Gastado"), Loc.t("Ganado"), Loc.t("Neto")][i])
	for r in data.rows:
		_row(Loc.t(str(r.name)), r)
	_row(Loc.t("Total"), data.total, true)
	for t in _summary_lines():
		lines.append(t)
		UI.label(col, t, 2.5, Draw.MARBLE, true, 1000)
	continue_button = UI.button("Continuar", true, 3.5, 40)
	continue_button.name = "continuar"
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.pressed.connect(finish)
	col.add_child(continue_button)
	PadHints.attach(self, [{"slot": PadGlyph.Slot.SOUTH, "key": "Espacio", "text": Loc.t("Continuar"), "call": finish}], [continue_button])


func _cell(color: Color, i: int, text: String) -> Control:
	var l := UI.label(table, text, 2.2, color, i == 0 and false)
	l.custom_minimum_size = Vector2(COL_W[i], 0)
	l.align = UI.VoxelLabel.Align.LEFT if i == 0 else UI.VoxelLabel.Align.CENTER
	return l


func _row(name_text: String, r: Dictionary, bold := false) -> void:
	var dim := int(r.plays) == 0
	var base := UI.GOLD if bold else (Color(0.6, 0.56, 0.7) if dim else Draw.MARBLE)
	var vals := [name_text, str(r.plays), str(r.wins), str(r.losses), str(r.spent), str(r.won), _signed(int(r.net))]
	for i in vals.size():
		var color := base
		if i == 6 and not dim:
			color = GOOD if int(r.net) > 0 else (BAD if int(r.net) < 0 else base)
		_cell(color, i, vals[i])


static func _signed(n: int) -> String:
	return "+%d" % n if n > 0 else str(n)


## Los renglones de abajo de la tabla: entrada y salida, mejor jugada, racha y pozo.
func _summary_lines() -> Array[String]:
	var out: Array[String] = []
	if int(data.total.plays) == 0:
		out.append(Loc.t("No jugaste a nada en este casino."))
	else:
		out.append(Loc.f("Entraste con %d de claridad y sales con %d (%s).", [data.claridad_in, data.claridad_out, _signed(int(data.claridad_out) - int(data.claridad_in))]))
		if int(data.best) > 0:
			out.append(Loc.f("Mejor jugada: +%d en %s.", [data.best, Loc.t(str(Rules.GAME_NAMES.get(data.best_game, "")))]))
		else:
			out.append(Loc.t("Ninguna apuesta te dejó ganancia esta vez."))
	if bool(data.racha) and int(data.max_streak) >= 2:
		out.append(Loc.f("Tu mejor racha fue de %d victorias seguidas.", [data.max_streak]))
	if bool(data.pozo) and int(data.pool) > 0:
		out.append(Loc.f("El pozo del jackpot quedó con %d de claridad sin cobrar.", [data.pool]))
	return out


func finish() -> void:
	if _closed:
		return
	_closed = true
	done.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
		if event.keycode != KEY_ESCAPE:   # (Esc lo usa el menú de pausa)
			finish()
			get_viewport().set_input_as_handled()
