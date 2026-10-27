extends Control
## Ayuda de un juego del casino (ruleta, tragamonedas, blackjack, dados del tabernero y las tres estaciones de servicio): un panel de varias páginas,
## cada una con un título, un dibujito de cubitos y unas líneas que explican las reglas. Se abre sola la primera vez que se entra a cada juego y se
## vuelve a abrir con H (teclado) o Select (mando); siempre está en la botonera de abajo como "Ayuda". Qué ayudas ya se vieron: `Profile.help_seen`.
## Uso: `GameHelp.attach(pantalla, "ruleta")` después de armar la pantalla (le agrega el ítem "Ayuda" a su botonera y se encarga de las teclas).

const Draw := preload("res://scripts/ui/voxel_draw.gd")
const VFont := preload("res://scripts/ui/voxel_font.gd")
const UI := preload("res://scripts/ui/menu_ui.gd")
const Icons := preload("res://scripts/casino/casino_icons.gd")
const PadHints := preload("res://scripts/ui/pad_hints.gd")
const PadGlyph := preload("res://scripts/ui/pad_glyph.gd")
const Controls := preload("res://scripts/entrada/controls.gd")
const Profile := preload("res://scripts/datos/profile.gd")
const Loc := preload("res://scripts/idioma/loc.gd")
const Arte := preload("res://scripts/ui/contract_art.gd")
const Dice3D := preload("res://scripts/casino/dice_3d.gd")
const Slots := preload("res://scripts/casino/slots.gd")
const MenuAnim := preload("res://scripts/ui/menu_anim.gd")

signal closed

## Las páginas de cada juego: {title, art (nombre del dibujito), text}. En los textos, {enter}, {space}, {c}, {esc}, {qe}, {shift}, {lr}, {ud}, {arrows}, {hold} y {help} se
## dibujan como la tecla (con teclado) o el botón (con mando) que corresponde, con el mismo diseño de las botoneras.
const PAGES := {
	"ruleta": [
		{"title": "La ruleta", "art": "ruleta_rueda", "text": "Hay 13 casillas: la 0 es de la casa y la 1 a la 12 son tuyas. Con {arrows} mueves la marca y con {space} eliges las casillas que cubres (el tipo de apuesta fija cuántas). Gira con {enter}."},
		{"title": "Tipos de apuesta", "art": "ruleta_apuestas", "text": "Pleno cubre 1 casilla y da premios épicos. Terna cubre 3 (raros), Mitad cubre 6 (comunes) y Rango cubre 9 (consumibles). Cuantas menos casillas cubres, mejor es el premio. Cambias de tipo con {qe}."},
		{"title": "Si pierdes", "art": "ruleta_perder", "text": "Si la bola cae en una casilla que no cubriste, o en el 0, pierdes la ficha. La ficha cuesta lo mismo en los cuatro tipos y sube con cada etapa. Con {c} ves qué premios puede dar cada tipo."},
		{"title": "La vitrina", "art": "ruleta_vitrina", "text": "Los premios de cada visita salen de una vitrina. Si no te gustan, puedes rotarla con {shift} pagando una ficha, y cada rotación cuesta una más. Los premios nuevos aparecen en la ventana de premios."},
	],
	"tragamonedas": [
		{"title": "Los rodillos", "art": "slots_rodillos", "text": "Pagas una ficha y giran tres rodillos con cinco símbolos: cubo, hielo, bomba, sol y corona. Los comunes salen más seguido y la corona es la más rara. Gira con {enter}."},
		{"title": "Qué paga", "art": "slots_pagos", "text": "Dos símbolos iguales pagan un poco; tres iguales pagan bastante más. Tres coronas son el premio gordo y además te dan un boost épico. Los pagos son claridad, en múltiplos de la ficha."},
		{"title": "Retener", "art": "slots_retener", "text": "Cuando los rodillos frenan puedes retener los que te gustan (con {hold}) y volver a girar los demás por media ficha. Se puede una sola vez por jugada: lo mejor es retener las parejas."},
		{"title": "Cobrar", "art": "slots_cobrar", "text": "En cualquier momento puedes cobrar lo que tengas con {space}, sin volver a girar. Elegir bien qué retener es lo que hace que la máquina rinda: sin pensarlo, cada ficha devuelve algo menos de lo que cuesta."},
	],
	"blackjack": [
		{"title": "Llegar a 21", "art": "bj_objetivo", "text": "Acércate a 21 sin pasarte. Las figuras valen 10, el As vale 1 u 11 y los palos son los símbolos del juego. Empiezas apostando una ficha con {enter}."},
		{"title": "Tu turno", "art": "bj_acciones", "text": "Pedir ({enter}) te da otra carta. Plantarte ({space}) te deja como estás. Doblar ({c}), solo con tus dos primeras cartas, apuesta otra ficha, te da una única carta y te planta."},
		{"title": "El crupier", "art": "bj_crupier", "text": "Una de sus cartas está tapada. Pide hasta tener 17 y se planta con cualquier 17. Si tú te pasas de 21 pierdes en el acto, aunque el crupier también se pase."},
		{"title": "Pagos", "art": "bj_pagos", "text": "Ganar paga 1 a 1. Un blackjack (21 con las dos primeras cartas) paga 3 a 2. Si empatas, te devuelven la apuesta."},
	],
	"dados": [
		{"title": "Los dados del tabernero", "art": "dados_elegir", "text": "Mientras se genera la torre puedes jugar. Elige con {lr} qué cara crees que saldrá en cada uno de los 5 dados (con {ud} cambias el número) y tira con {enter}."},
		{"title": "Tres tiradas", "art": "dados_tiradas", "text": "Tienes 3 tiradas para cumplir tu predicción. Los dados que aciertan quedan retenidos, en verde y con candado, y solo se vuelven a tirar los que fallaron."},
		{"title": "Premios", "art": "dados_premios", "text": "Con 2 aciertos ganas 8 de claridad, con 3 ganas 25, con 4 ganas 80 y con 5 ganas 150. Con 4 o 5 aciertos también puede salir un cosmético. Los premios son tuyos cuando superes la torre."},
	],
	"taller": [
		{"title": "El taller", "art": "taller_yunque", "text": "Aquí vendes un boost o un consumible por el 40 % de su valor. También puedes cambiarlo por otro del mismo nivel pagando el 30 % de la ficha. Sirve para liberar lugar en tus barras."},
	],
	"tablon": [
		{"title": "El tablón de contratos", "art": "tablon_papeles", "text": "Cada papel pide algo para la próxima torre: llegar a una racha, no deshacer, purificar especiales... Acéptalo gratis y se cobra en cuanto lo cumples."},
		{"title": "Los sellos", "art": "tablon_papeles", "text": "El sello dice qué tan difícil es: gris, azul, violeta, y negro el casi imposible. Los papeles que no aceptes siguen colgados en el próximo casino."},
		{"title": "Aceptar, descolgar y rotar", "art": "tablon_acciones", "text": "Puedes tener pocos contratos activos a la vez. Descolgar un papel libera su lugar y cancelar uno aceptado te devuelve la fianza. Rotar cambia todos y cada vez cuesta más."},
		{"title": "Fianza y tienda", "art": "tablon_acciones", "text": "En el casino y el gran casino puedes aceptar con fianza: pagas ahora y, si cumples, cobras más y la recuperas. La pestaña de arriba te lleva a la tienda."},
	],
	"tienda": [
		{"title": "La tienda", "art": "tienda_vitrina", "text": "Tres premios de esta visita (uno épico, uno raro y uno común) a precio fijo. Es caro, pero seguro: no hay que tirar la ruleta. Los premios cambian en cada visita."},
	],
}

## Si se abre sola la primera vez (las pruebas sin pantalla lo apagan: se piden a mano con `open()`).
static var auto_open := DisplayServer.get_name() != "headless"

var id := ""
var page := 0
var host: Control
var _pages: Array = []
var _card: Control
var _title: Control
var _art: Control
var _body: Control
var _count: Control
var _hints: Control
var _want_auto := false


## Le pone la ayuda `help_id` a una pantalla: agrega "Ayuda" a su botonera y se abre sola si es la primera vez.
static func attach(screen: Control, help_id: String) -> Control:
	if not PAGES.has(help_id):
		return null
	var h = load("res://scripts/ui/game_help.gd").new()
	h.id = help_id
	h.host = screen
	screen.add_child(h)
	var bar = screen.get("pad_hints")
	if bar == null:
		bar = screen.get("hints")
	if bar != null and bar.has_method("add_extra"):
		bar.add_extra({"name": "BACK", "key": "H", "text": Loc.t("Ayuda"), "call": h.open})
	h._want_auto = auto_open and not Profile.help_seen(help_id)
	return h


## El id de ayuda de una pantalla del casino (por su script o por su `service_id`).
static func id_for(screen: Control) -> String:
	var sid = screen.get("service_id")
	if sid != null and PAGES.has(str(sid)):
		return str(sid)
	var path: String = str(screen.get_script().resource_path) if screen.get_script() != null else ""
	if path.ends_with("roulette_screen.gd"):
		return "ruleta"
	if path.ends_with("slots_screen.gd"):
		return "tragamonedas"
	if path.ends_with("blackjack_screen.gd"):
		return "blackjack"
	return ""


## Las piezas que se dibujan para un token ({enter}, {space}...): cada una {cap: texto de tecla} / {slot: botón de cara} / {named: botón con nombre}.
static func glyph_parts(token: String, pad := Controls.using_pad) -> Array:
	if pad:
		match token:
			"enter": return [{"slot": PadGlyph.Slot.SOUTH}]
			"space": return [{"slot": PadGlyph.Slot.WEST}]
			"c": return [{"slot": PadGlyph.Slot.NORTH}]
			"esc": return [{"slot": PadGlyph.Slot.EAST}]
			"qe": return [{"named": "LB"}, {"named": "RB"}]
			"shift": return [{"named": "LT"}]
			"lr": return [{"named": "DPAD_LR"}]
			"ud", "arrows", "hold": return [{"named": "DPAD"}]
			"help": return [{"named": "BACK"}]
	else:
		match token:
			"enter": return [{"cap": "Enter"}]
			"space": return [{"cap": "Espacio"}]
			"c": return [{"cap": "C"}]
			"esc": return [{"cap": "Esc"}]
			"qe": return [{"cap": "Q"}, {"cap": "E"}]
			"shift": return [{"cap": "Shift"}]
			"lr": return [{"cap": "←"}, {"cap": "→"}]
			"ud": return [{"cap": "↑"}, {"cap": "↓"}]
			"arrows": return [{"cap": "←"}, {"cap": "↑"}, {"cap": "↓"}, {"cap": "→"}]
			"hold": return [{"cap": "1"}, {"cap": "2"}, {"cap": "3"}]
			"help": return [{"cap": "H"}]
	return [{"cap": token}]


func _init() -> void:
	name = "ayuda"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card = _Card.new()
	_card.custom_minimum_size = Vector2(980, 600)
	center.add_child(_card)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	_card.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	_title = UI.label(col, "", 4, UI.GOLD)
	_art = _Art.new()
	_art.custom_minimum_size = Vector2(0, 220)
	_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_art)
	_body = _Rich.new()
	_body.custom_minimum_size = Vector2(880, 150)
	_body.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_body)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	_count = UI.label(col, "", 2, Color(0.8, 0.76, 0.92))
	_hints = PadHints.attach_in(col, [])


func _ready() -> void:
	_pages = PAGES.get(id, [])
	if host != null and not host.visibility_changed.is_connected(_on_host_visibility):
		host.visibility_changed.connect(_on_host_visibility)


func _on_host_visibility() -> void:
	if host != null and host.is_visible_in_tree() and not Profile.help_seen(id) and auto_open:
		_want_auto = true


func _process(_dt: float) -> void:
	# la primera vez se abre sola, apenas la pantalla se ve (y no tiene a un personaje hablando encima)
	if _want_auto and not visible and host != null and host.is_visible_in_tree() and not _host_paused():
		_want_auto = false
		open()


## ¿La pantalla está en pausa (un personaje habla encima)?
func _host_paused() -> bool:
	var v = host.get("paused") if host != null else null
	return v is bool and v


func is_open() -> bool:
	return visible


## Abre la ayuda desde la primera página.
func open() -> void:
	if _pages.is_empty():
		return
	page = 0
	visible = true
	_want_auto = false
	Profile.mark_help_seen(id)
	_show_page()
	MenuAnim.pop_in(_card, 0.94, 0.22)


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func next_page() -> void:
	if page >= _pages.size() - 1:
		close()
	else:
		page += 1
		_show_page()


func prev_page() -> void:
	if page > 0:
		page -= 1
		_show_page()


func _show_page() -> void:
	var p: Dictionary = _pages[page]
	_title.text = Loc.t(str(p.title))
	_body.set_markup(Loc.t(str(p.text)))
	_art.kind = str(p.art)
	_art.queue_redraw()
	_count.text = "%d / %d" % [page + 1, _pages.size()]
	var last := page >= _pages.size() - 1
	var items := []
	items.append({"slot": PadGlyph.Slot.SOUTH, "key": "Espacio", "text": Loc.t("Entendido") if last else Loc.t("Siguiente"), "call": next_page})
	items.append({"slot": PadGlyph.Slot.EAST, "key": "Esc", "text": Loc.t("Cerrar"), "call": close})
	_hints.set_items(items)


## Mientras la ayuda está abierta se queda con todas las teclas (el juego de atrás no se entera); cerrada, H la abre.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if visible:
		match event.keycode:
			KEY_RIGHT, KEY_D, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				next_page()
			KEY_LEFT, KEY_A:
				prev_page()
			KEY_ESCAPE, KEY_H:
				close()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_H and host != null and host.is_visible_in_tree() and not _host_paused():
		open()
		get_viewport().set_input_as_handled()


## Fondo de la ayuda: una carta grande de cubitos.
class _Card extends Control:
	const D := preload("res://scripts/ui/voxel_draw.gd")

	func _draw() -> void:
		D.card(self, Rect2(Vector2.ZERO, size), 6.0, 0, 0.1, 4242, false, -1.0)


## Texto con fichas de teclas o botones en línea ({enter}, {space}...): se parte en palabras, se acomoda en renglones centrados y las fichas se dibujan con el diseño de las botoneras
## (teclas con teclado, botones del mando con mando; se redibuja solo si cambia el dispositivo).
class _Rich extends Control:
	const D := preload("res://scripts/ui/voxel_draw.gd")
	const VF := preload("res://scripts/ui/voxel_font.gd")
	const PG := preload("res://scripts/ui/pad_glyph.gd")
	const Ctl := preload("res://scripts/entrada/controls.gd")

	const CS := 2.5          # lado de un cubito de las letras
	const LINE_H := 40.0
	const GAP := 4.0         # separación entre las piezas de una ficha

	var markup := ""
	var _ops: Array = []
	var _was_pad := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(_relayout)

	func set_markup(text: String) -> void:
		markup = text
		_relayout()

	func _process(_dt: float) -> void:
		if Ctl.using_pad != _was_pad:
			_relayout()

	static func _part_width(part: Dictionary) -> float:
		if part.has("cap"):
			return maxf(26.0, ThemeDB.fallback_font.get_string_size(str(part.cap), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 14.0)
		if part.has("slot"):
			return 30.0
		return {"LB": 32.0, "RB": 32.0, "LT": 32.0, "RT": 32.0, "BACK": 40.0, "START": 40.0}.get(str(part.named), 30.0)

	func _relayout() -> void:
		_was_pad = Ctl.using_pad
		_ops.clear()
		var width := minf(size.x if size.x > 0.0 else 880.0, 900.0)
		var re := RegEx.new()
		re.compile("\\{[a-z0-9]+\\}|[^\\s{]+")
		var toks: Array = []
		for m in re.search_all(markup):
			var t: String = m.get_string()
			var before := m.get_start() > 0 and markup[m.get_start() - 1] in [" ", "\n"]
			var tok := {"space": before, "gap": 0.0}
			if t.begins_with("{"):
				var parts: Array = load("res://scripts/ui/game_help.gd").glyph_parts(t.substr(1, t.length() - 2), Ctl.using_pad)
				var w := GAP * (parts.size() - 1)
				for part in parts:
					w += _part_width(part)
				tok["parts"] = parts
				tok["w"] = w
			else:
				var l: Dictionary = VF.layout([t])
				tok["word"] = t
				tok["cells"] = l.cells
				tok["rows"] = int(l.size.y)
				tok["w"] = float(l.size.x) * CS
			toks.append(tok)
		var lines: Array = []
		var line: Array = []
		var cur := 0.0
		for tok in toks:
			var gap := CS * 4.0 if (not line.is_empty() and tok.space) else 0.0
			if not line.is_empty() and cur + gap + tok.w > width:
				lines.append({"items": line, "w": cur})
				line = []
				cur = 0.0
				gap = 0.0
			tok["gap"] = gap
			line.append(tok)
			cur += gap + tok.w
		if not line.is_empty():
			lines.append({"items": line, "w": cur})
		var y := 0.0
		for L in lines:
			var x: float = (size.x - float(L.w)) * 0.5 if size.x > 0.0 else (width - float(L.w)) * 0.5
			for tok in L.items:
				x += float(tok.gap)
				tok["x"] = x
				tok["y"] = y
				x += float(tok.w)
				_ops.append(tok)
			y += LINE_H
		queue_redraw()

	func _draw() -> void:
		for tok in _ops:
			var cy: float = float(tok.y) + LINE_H * 0.5
			if tok.has("word"):
				var h := float(tok.rows) * CS
				D.text_cells(self, Vector2(tok.x, cy - h * 0.5), tok.cells, int(tok.rows), CS, Color(0.84, 0.82, 0.9), 0.0, str(tok.word).hash() & 0xFFFF, true)
				continue
			var x: float = tok.x
			for part in tok.parts:
				var w := _part_width(part)
				var c := Vector2(x + w * 0.5, cy)
				if part.has("cap"):
					PG.draw_cap(self, c, w, 13.0, str(part.cap))
				elif part.has("slot"):
					PG.draw(self, c, 13.0, int(part.slot))
				else:
					PG.draw_named(self, c, 12.0, str(part.named))
				x += w + GAP


## El dibujito de cada página, hecho con cubitos.
class _Art extends Control:
	const D := preload("res://scripts/ui/voxel_draw.gd")
	const VF := preload("res://scripts/ui/voxel_font.gd")
	const Ic := preload("res://scripts/casino/casino_icons.gd")
	const D3 := preload("res://scripts/casino/dice_3d.gd")
	const SL := preload("res://scripts/casino/slots.gd")

	const LILAC := Color(0.62, 0.40, 0.95)
	const GOLDC := Color(1.0, 0.85, 0.30)
	const REDC := Color(1.0, 0.30, 0.20)
	const GREENC := Color(0.55, 1.0, 0.65)
	const EPIC := Color(0.78, 0.42, 1.0)
	const RARE := Color(0.42, 0.68, 1.0)
	const COMMON := Color(0.78, 0.78, 0.84)
	const CONSUM := Color(0.5, 0.9, 0.5)
	const DARK := Color(0.10, 0.06, 0.16)

	var kind := ""
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_t += delta
			queue_redraw()

	# --- piezas ---

	func _cube(center: Vector2, s: float, col: Color) -> void:
		D.cube(self, center - Vector2(s, s) * 0.5, s, col, false)

	func _txt(text: String, center: Vector2, cs: float, col: Color) -> void:
		var l: Dictionary = VF.layout([text])
		var sz := Vector2(l.size) * cs
		D.text_cells(self, center - sz * 0.5, l.cells, l.size.y, cs, col, 0.0, text.hash() & 0xFFFF, true)

	func _icon(id: String, center: Vector2, s: float) -> void:
		Ic.draw(self, id, center, s)

	func _arrow(a: Vector2, b: Vector2, col: Color, w := 6.0) -> void:
		draw_line(a, b, col, w)
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([b + dir * 4.0, b - dir * 16.0 + side * 12.0, b - dir * 16.0 - side * 12.0]), col)

	func _lock(center: Vector2, s: float, col: Color) -> void:
		for x in 4:
			for y in 3:
				_cube(center + Vector2((x - 1.5) * s, (y - 0.5) * s), s, col)
		for p in [Vector2(0, -2), Vector2(1, -2), Vector2(2, -2), Vector2(3, -1), Vector2(0, -1)]:
			_cube(center + Vector2((p.x - 1.5) * s, (p.y - 0.5) * s - 0.0), s, col.lightened(0.15))
		_cube(center + Vector2(0, 0.5 * s), s * 0.7, DARK)

	func _pips(origin: Vector2, side: float, value: int, col: Color) -> void:
		for pip in D3.PIPS[clampi(value, 1, 6)]:
			var pc: Vector2 = origin + Vector2(float(pip[0]), float(pip[1])) * side
			draw_rect(Rect2(pc - Vector2(side, side) * 0.09, Vector2(side, side) * 0.18), col)

	func _die(center: Vector2, s: float, value: int, tint: Color) -> void:
		var top_left := center - Vector2(s, s) * 0.5
		D.cube(self, top_left, s, tint, false)
		_pips(top_left, s, value, DARK)

	func _card_at(center: Vector2, label: String, suit: String, hidden := false) -> void:
		var r := Rect2(center - Vector2(36, 50), Vector2(72, 100))
		draw_rect(r.grow(3.0), DARK)
		if hidden:
			draw_rect(r, Color(0.36, 0.20, 0.60))
			for i in 5:
				draw_line(r.position + Vector2(0, i * 22.0), r.position + Vector2(72, i * 22.0 - 40.0), Color(0.62, 0.40, 0.95), 4.0)
			return
		draw_rect(r, Color(0.96, 0.94, 0.88))
		_txt(label, r.position + Vector2(20, 22), 3.0, DARK)
		_icon(suit, r.position + Vector2(36, 66), 44.0)

	func _chip(center: Vector2, col := GOLDC) -> void:
		_cube(center, 26.0, col)
		_cube(center + Vector2(0, -8), 26.0, col.lightened(0.1))

	func _reel(center: Vector2, symbol: String, locked := false) -> void:
		var r := Rect2(center - Vector2(44, 62), Vector2(88, 124))
		draw_rect(r.grow(4.0), Color(0.05, 0.03, 0.09))
		draw_rect(r, Color(0.16, 0.10, 0.26))
		if symbol != "":
			_icon(symbol, center, 62.0)
		if locked:
			draw_rect(r, Color(GREENC, 0.16))
			draw_rect(r, GREENC, false, 3.0)
			_lock(center + Vector2(0, -78), 9.0, GREENC)

	func _draw() -> void:
		var c := size * 0.5
		var bob := sin(_t * 3.0) * 4.0
		match kind:
			"ruleta_rueda":
				var radius := 84.0
				for i in 13:
					var a := float(i) / 13.0 * TAU - PI * 0.5
					var col := REDC if i == 0 else (LILAC if i % 2 == 0 else GOLDC)
					_cube(c + Vector2(cos(a), sin(a)) * radius, 28.0, col)
				_txt("0", c + Vector2(0, -radius - 30.0), 3.0, REDC)
				var ba := float(7) / 13.0 * TAU - PI * 0.5 + _t * 0.8
				_cube(c + Vector2(cos(ba), sin(ba)) * (radius - 30.0), 14.0, Color.WHITE)
				_txt("1-12", c, 3.0, GOLDC)
			"ruleta_apuestas":
				var cols := [EPIC, RARE, COMMON, CONSUM]
				var counts := [1, 3, 6, 9]
				var names := ["EPICO", "RARO", "COMUN", "CONSUMIBLE"]
				for row in 4:
					var y := 30.0 + row * 50.0
					_txt(str(counts[row]), Vector2(c.x - 250.0, y), 4.0, GOLDC)
					for k in 12:
						var lit: bool = k < int(counts[row])
						_cube(Vector2(c.x - 200.0 + k * 28.0, y), 22.0, cols[row] if lit else Color(0.2, 0.17, 0.27))
					_txt(str(names[row]), Vector2(c.x + 210.0, y), 2.0, cols[row])
			"ruleta_perder":
				for i in 3:
					_chip(Vector2(c.x - 200.0, c.y + 30.0 - i * 18.0))
				_arrow(Vector2(c.x - 140.0, c.y), Vector2(c.x - 40.0, c.y), Color(0.7, 0.65, 0.85))
				_cube(Vector2(c.x + 50.0, c.y), 64.0, REDC)
				_txt("0", Vector2(c.x + 50.0, c.y), 5.0, Color.WHITE)
				_cube(Vector2(c.x + 50.0, c.y - 50.0 - bob), 18.0, Color.WHITE)
				for i in 3:
					draw_rect(Rect2(Vector2(c.x + 160.0 + i * 36.0, c.y - 10.0 + i * 8.0), Vector2(26, 26)), Color(GOLDC, 0.55 - i * 0.16))
			"ruleta_vitrina":
				var cols2 := [EPIC, RARE, COMMON]
				for i in 3:
					var cx := c.x + (i - 1) * 150.0
					var r := Rect2(Vector2(cx - 54.0, 14.0), Vector2(108, 130))
					draw_rect(r.grow(4.0), DARK)
					draw_rect(r, Color(0.16, 0.10, 0.26))
					draw_rect(r, GOLDC, false, 2.0)
					_cube(Vector2(cx, 70.0 + bob), 46.0, cols2[i])
				_arrow(Vector2(c.x - 70.0, 176.0), Vector2(c.x + 70.0, 176.0), Color(0.7, 0.65, 0.85), 5.0)
				_arrow(Vector2(c.x + 70.0, 196.0), Vector2(c.x - 70.0, 196.0), Color(0.7, 0.65, 0.85), 5.0)
				_chip(Vector2(c.x + 110.0, 186.0))
			"slots_rodillos":
				var names2 := ["cubo", "hielo", "bomba", "sol", "corona"]
				for i in 5:
					_icon(names2[i], Vector2(c.x - 160.0 + i * 80.0, 26.0), 36.0)
				_reel(Vector2(c.x - 100.0, 140.0), "cubo")
				_reel(Vector2(c.x, 140.0), "hielo")
				_reel(Vector2(c.x + 100.0, 140.0), "bomba")
			"slots_pagos":
				_icon("cubo", Vector2(c.x - 150.0, 44.0), 46.0)
				_icon("cubo", Vector2(c.x - 100.0, 44.0), 46.0)
				_icon("hielo", Vector2(c.x - 50.0, 44.0), 46.0)
				_txt("x%s" % str(SL.PAIR[0]), Vector2(c.x + 80.0, 44.0), 4.0, COMMON)
				for i in 3:
					_icon("cubo", Vector2(c.x - 150.0 + i * 50.0, 110.0), 46.0)
				_txt("x%d" % int(SL.TRIPLE[0]), Vector2(c.x + 80.0, 110.0), 4.0, GOLDC)
				for i in 3:
					_icon("corona", Vector2(c.x - 150.0 + i * 50.0, 176.0 + bob * 0.5), 46.0)
				_txt("x%d" % int(SL.TRIPLE[4]), Vector2(c.x + 80.0, 176.0), 4.0, GOLDC)
				_cube(Vector2(c.x + 170.0, 176.0), 26.0, EPIC)
			"slots_retener":
				_reel(Vector2(c.x - 110.0, 130.0), "cubo", true)
				_reel(Vector2(c.x, 130.0), "cubo", true)
				var spin := ["hielo", "bomba", "sol", "corona", "cubo"]
				_reel(Vector2(c.x + 110.0, 130.0), spin[int(_t * 8.0) % 5])
				for i in 3:
					_txt(str(i + 1), Vector2(c.x - 110.0 + i * 110.0, 206.0), 3.0, GOLDC)
				_arrow(Vector2(c.x + 190.0, 130.0), Vector2(c.x + 150.0, 130.0), GOLDC, 4.0)
			"slots_cobrar":
				for i in 3:
					for k in 3 - i:
						_cube(Vector2(c.x - 200.0 + i * 15.0 + k * 30.0, c.y + 40.0 - i * 28.0), 28.0, GOLDC)
				_arrow(Vector2(c.x - 100.0, c.y), Vector2(c.x + 20.0, c.y), Color(0.7, 0.65, 0.85))
				for i in 5:
					for k in 5 - i:
						_cube(Vector2(c.x + 70.0 + i * 15.0 + k * 30.0, c.y + 50.0 - i * 28.0 + bob * 0.3), 28.0, GOLDC)
			"bj_objetivo":
				_card_at(Vector2(c.x - 170.0, c.y), "K", "sol")
				_card_at(Vector2(c.x - 80.0, c.y), "A", "bomba")
				_txt("=", Vector2(c.x + 10.0, c.y), 6.0, Draw.MARBLE)
				_txt("21", Vector2(c.x + 110.0, c.y), 10.0, GOLDC)
			"bj_acciones":
				var labels := ["PEDIR", "PLANTARSE", "DOBLAR"]
				for i in 3:
					var cx := c.x + (i - 1) * 190.0
					var r := Rect2(Vector2(cx - 80.0, 14.0), Vector2(160, 150))
					draw_rect(r.grow(3.0), DARK)
					draw_rect(r, Color(0.16, 0.10, 0.26))
					_txt(str(labels[i]), Vector2(cx, 184.0), 3.0, GOLDC)
					match i:
						0:
							draw_rect(Rect2(Vector2(cx - 30.0, 36.0), Vector2(46, 66)), Color(0.96, 0.94, 0.88))
							_txt("?", Vector2(cx - 7.0, 69.0), 5.0, DARK)
							_txt("+", Vector2(cx + 40.0, 100.0), 5.0, GREENC)
						1:
							_cube(Vector2(cx, 88.0), 64.0, REDC)
							draw_rect(Rect2(Vector2(cx - 22.0, 82.0), Vector2(44, 12)), Color.WHITE)
						2:
							_chip(Vector2(cx - 22.0, 94.0))
							_chip(Vector2(cx + 22.0, 94.0))
							_txt("x2", Vector2(cx, 54.0), 4.0, GOLDC)
			"bj_crupier":
				_card_at(Vector2(c.x - 130.0, c.y), "10", "cubo")
				_card_at(Vector2(c.x - 40.0, c.y), "", "", true)
				_arrow(Vector2(c.x + 30.0, c.y), Vector2(c.x + 100.0, c.y), Color(0.7, 0.65, 0.85))
				_txt("17", Vector2(c.x + 190.0, c.y), 9.0, GOLDC)
			"bj_pagos":
				for i in 3:
					var cx := c.x + (i - 1) * 190.0
					match i:
						0:
							_chip(Vector2(cx - 30.0, c.y + 10.0))
							_chip(Vector2(cx + 30.0, c.y + 10.0))
							_txt("1:1", Vector2(cx, c.y - 50.0), 6.0, GOLDC)
						1:
							for k in 3:
								_chip(Vector2(cx - 40.0 + k * 40.0, c.y + 10.0))
							_txt("3:2", Vector2(cx, c.y - 50.0), 6.0, GOLDC)
						2:
							_chip(Vector2(cx, c.y + 10.0))
							_txt("=", Vector2(cx, c.y - 50.0), 6.0, Draw.MARBLE)
			"dados_elegir":
				for i in 5:
					var cx := c.x + (i - 2) * 100.0
					_die(Vector2(cx, c.y), 64.0, [3, 5, 2, 6, 1][i], Color(0.95, 0.93, 0.88))
					var sel := i == 2
					var ac := GOLDC if sel else Color(0.6, 0.55, 0.72)
					draw_colored_polygon(PackedVector2Array([Vector2(cx - 14, c.y - 46), Vector2(cx + 14, c.y - 46), Vector2(cx, c.y - 62)]), ac)
					draw_colored_polygon(PackedVector2Array([Vector2(cx - 14, c.y + 46), Vector2(cx + 14, c.y + 46), Vector2(cx, c.y + 62)]), ac)
			"dados_tiradas":
				for i in 5:
					var cx := c.x + (i - 2) * 100.0
					var hit := i != 1 and i != 3
					_die(Vector2(cx, c.y + 10.0), 64.0, [4, 2, 5, 6, 3][i], Color(0.62, 1.0, 0.7) if hit else Color(1.0, 0.62, 0.62))
					if hit:
						_lock(Vector2(cx, c.y - 52.0), 7.0, GREENC)
				for i in 3:
					_cube(Vector2(c.x + 200.0 + i * 30.0, 22.0), 22.0, GOLDC if i < 2 else Color(0.25, 0.22, 0.3))
			"dados_premios":
				var hits := [2, 3, 4, 5]
				var vals := [8, 25, 80, 150]
				for i in 4:
					var y := 30.0 + i * 52.0
					_txt(str(hits[i]), Vector2(c.x - 170.0, y), 4.0, Draw.MARBLE)
					for k in int(hits[i]):
						_cube(Vector2(c.x - 130.0 + k * 24.0, y), 18.0, GREENC)
					_arrow(Vector2(c.x + 10.0, y), Vector2(c.x + 60.0, y), Color(0.7, 0.65, 0.85), 4.0)
					_txt(str(vals[i]), Vector2(c.x + 130.0, y), 4.0, GOLDC)
					if i >= 2:
						_icon("corona", Vector2(c.x + 220.0, y), 34.0)
			"taller_yunque":
				draw_rect(Rect2(c + Vector2(-120, 10), Vector2(120, 22)), Color(0.3, 0.3, 0.36))
				draw_rect(Rect2(c + Vector2(-100, -10), Vector2(80, 20)), Color(0.4, 0.4, 0.46))
				draw_rect(Rect2(c + Vector2(-80, 32), Vector2(40, 36)), Color(0.26, 0.26, 0.32))
				_cube(c + Vector2(-60, -34 - bob), 34.0, EPIC)
				_arrow(c + Vector2(30, -16), c + Vector2(130, -16), Color(0.7, 0.65, 0.85), 5.0)
				_arrow(c + Vector2(130, 24), c + Vector2(30, 24), Color(0.7, 0.65, 0.85), 5.0)
				_chip(c + Vector2(190, -16))
				_cube(c + Vector2(190, 36), 34.0, RARE)
			"tablon_papeles":
				for i in 3:
					Arte.dibujar_papel(self, c + Vector2(-230.0 + i * 160.0, -110.0), 4.0, i, ["racha", "especiales", "claridad"][i], i * 7 + 3, true)
			"tablon_acciones":
				Arte.dibujar_papel(self, c + Vector2(-210.0, -110.0), 4.0, 1, "movimientos", 5, true)
				_arrow(c + Vector2(-110.0, 0.0), c + Vector2(-10.0, 0.0), Color(0.7, 0.65, 0.85), 5.0)
				Arte.dibujar_papel(self, c + Vector2(0.0, -110.0), 4.0, 2, "bomba", 9, false)
				_chip(c + Vector2(130.0, -20.0))
				_chip(c + Vector2(160.0, 10.0))
			"tienda_vitrina":
				var cols3 := [EPIC, RARE, COMMON]
				var prices := ["300", "180", "90"]
				for i in 3:
					var cx := c.x + (i - 1) * 170.0
					draw_rect(Rect2(Vector2(cx - 50.0, 130.0), Vector2(100, 36)), Color(0.30, 0.20, 0.12))
					_cube(Vector2(cx, 86.0 + bob), 52.0, cols3[i])
					_txt(str(prices[i]), Vector2(cx, 190.0), 3.0, GOLDC)
