extends RefCounted
## Textos y piezas comunes de los menús, todo hecho de cubitos (menú principal: main_menu.gd; pausa: pause_menu.gd).

const VoxelLabel := preload("res://scripts/voxel_label.gd")
const VoxelButton := preload("res://scripts/voxel_button.gd")
const Draw := preload("res://scripts/voxel_draw.gd")
const SwirlBG := preload("res://scripts/swirl_bg.gd")
const Loc := preload("res://scripts/loc.gd")

const TITLE := "Balatro × Catherine"
const SUBTITLE := "Escapá de la pesadilla, una torre a la vez"

## Créditos del juego: completar con los nombres reales antes de publicar.
const CREDITS_GAME := """Diseño y desarrollo: (agregar nombre)
Arte, música y sonido: (agregar)

Gracias por jugar."""

const BG := Color(0.05, 0.03, 0.09)
const GOLD := Draw.GOLD


## Texto de cubitos. `cube`: lado de un cubito en píxeles; `wrap_px` > 0 parte el texto en líneas de ese ancho.
static func label(parent: Node, text: String, cube: float, color: Color, centered := true, wrap_px := 0) -> Control:
	var l := VoxelLabel.new()
	l.cube = cube
	l.color = color
	l.wrap_px = wrap_px
	l.align = VoxelLabel.Align.CENTER if centered else VoxelLabel.Align.LEFT
	l.text = text
	if parent != null:
		parent.add_child(l)
	return l


## Botón de cubitos centrado en su columna.
static func button(text: String, primary := false, cube := 3.0, min_cells_w := 0, animated := true) -> Button:
	var b := VoxelButton.new()
	b.cube = cube
	b.primary = primary
	b.min_cells_w = min_cells_w
	b.animated = animated
	b.set_label(text)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b


## Texto de los créditos: breve (los del juego y el motor). Las licencias van aparte, en la pantalla de Licencias.
static func credits_text() -> String:
	return Loc.t(CREDITS_GAME) + "\n\n" + Loc.t("Hecho con Godot Engine - https://godotengine.org\n")


## Texto de las licencias: el aviso de Godot y su licencia MIT y la lista de componentes de terceros que trae el motor.
## Todo sale de lo que el propio motor informa (Engine.get_license_text / get_copyright_info), así queda al día con la versión usada.
static func licenses_text() -> String:
	var t := Loc.t("Godot Engine se distribuye bajo la licencia MIT.\n\n")
	t += Engine.get_license_text().strip_edges() + "\n\n"
	t += Loc.t("Componentes de terceros incluidos en el motor (nombre: licencias):\n")
	for comp in Engine.get_copyright_info():
		var licenses := {}
		for part in comp.parts:
			licenses[part.license] = true
		t += "- %s: %s\n" % [comp.name, ", ".join(licenses.keys())]
	t += Loc.t("\nLos textos completos de esas licencias están en https://godotengine.org/license y en el código fuente de Godot (COPYRIGHT.txt y LICENSE.txt).")
	return t.replace("©", "(c)").replace("\r", "")


## Panel de créditos (corto) con un botón a las licencias y otro para volver (oculto al crearlo).
static func make_credits_panel(on_back: Callable, on_licenses: Callable) -> Control:
	var panel := _text_panel("creditos", "Créditos", credits_text(), "texto_creditos", 300)
	var col: VBoxContainer = panel.find_child("columna", true, false)
	var lic := button("Licencias", false, 2.2, 0, false)
	lic.name = "licencias"
	lic.pressed.connect(on_licenses)
	col.add_child(lic)
	var back := button("Volver", true)
	back.name = "volver_creditos"
	back.pressed.connect(on_back)
	col.add_child(back)
	return panel


## Panel con las licencias de terceros, con desplazamiento (rueda del mouse).
static func make_licenses_panel(on_back: Callable) -> Control:
	var panel := _text_panel("licencias", "Licencias", licenses_text(), "texto_licencias", 560)
	var back := button("Volver", true)
	back.name = "volver_licencias"
	back.pressed.connect(on_back)
	panel.find_child("columna", true, false).add_child(back)
	return panel


static func _text_panel(panel_name: String, title_text: String, body: String, body_name: String, height: int) -> Control:
	var panel := Control.new()
	panel.name = panel_name
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.09, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var col := VBoxContainer.new()
	col.name = "columna"
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)
	var title := label(col, title_text, 5, GOLD)
	title.dance = true
	var scroll := ScrollContainer.new()
	scroll.name = "desplazamiento"
	scroll.custom_minimum_size = Vector2(1180, height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var txt := label(null, "", 2, Draw.MARBLE, false, 1140)
	txt.name = body_name
	txt.localize = false   # el texto ya viene traducido (y las licencias son larguísimas)
	txt.text = body
	scroll.add_child(txt)
	return panel
