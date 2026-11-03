extends SceneTree
## Compara cómo se ve el texto chico hoy y con la propuesta (negrita en los textos chicos y teclas con la fuente de cubitos): una hoja con las dos versiones, para decidir antes de tocar el juego.
## Uso: GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/capturas/shot_letra_comparacion.gd -- SALIDA.png
const UI := preload("res://scripts/ui/menu_ui.gd")
const VFont := preload("res://scripts/ui/voxel_font.gd")
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const PadHints := preload("res://scripts/ui/pad_hints.gd")

const FONDO := Color(0.07, 0.04, 0.13)
const TEXTO := Color(0.8, 0.76, 0.92)


## Texto de cubitos de la propuesta: igual que el de ahora pero "en negrita" (cada cubito se junta con el de al lado) y sin ruido.
class Negrita extends Control:
	const VFont := preload("res://scripts/ui/voxel_font.gd")
	var texto := ""
	var cubo := 2.5
	var color := Color(0.8, 0.76, 0.92)
	var grosor := 1.5   # cuánto se ensancha cada cubito (1.0 = como hoy)

	func _draw() -> void:
		var l: Dictionary = VFont.layout([texto])
		var cells: Array = l.cells
		var c2 := color.lerp(Color.WHITE, 0.35)
		var o := maxf(1.0, cubo * 0.4)
		var w := cubo * grosor
		for c in cells:
			draw_rect(Rect2(Vector2(c.x, c.y) * cubo - Vector2(o, o), Vector2(w + o * 2.0, cubo + o * 2.0)), Color(0.0, 0.0, 0.02, 0.92))
		for c in cells:
			draw_rect(Rect2(Vector2(c.x, c.y) * cubo, Vector2(w, cubo)), c2)
			draw_rect(Rect2(Vector2(c.x, c.y) * cubo, Vector2(w, maxf(1.0, cubo * 0.22))), c2.lightened(0.3))

	func _get_minimum_size() -> Vector2:
		var l: Dictionary = VFont.layout([texto])
		return Vector2(l.size) * cubo + Vector2(cubo * 2.0, 0)


## Una tecla dibujada con la fuente de cubitos (la propuesta): placa clara y letras de cubitos oscuros.
class Tecla extends Control:
	const VFont := preload("res://scripts/ui/voxel_font.gd")
	var texto := ""
	var cubo := 2.5

	func _get_minimum_size() -> Vector2:
		var l: Dictionary = VFont.layout([texto])
		return Vector2(l.size) * cubo + Vector2(16, 12)

	func _draw() -> void:
		var s := get_minimum_size()
		draw_rect(Rect2(Vector2(2, 3), s), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.86, 0.82, 0.74))
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.55, 0.5, 0.42), false, 2.0)
		var l: Dictionary = VFont.layout([texto])
		for c in l.cells:
			draw_rect(Rect2(Vector2(8, 6) + Vector2(c.x, c.y) * cubo, Vector2(cubo * 1.5, cubo)), Color(0.12, 0.08, 0.16))


func _columna(titulo: String, nueva: bool, cubo_n := 2.8, grosor_n := 1.5) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	var t := UI.label(col, titulo, 3.0, Color(1.0, 0.85, 0.4), false)
	t.dance = false
	for linea in ["Rosa de los vientos", "Alto contraste", "Cámara del casino", "Ayuda de profundidad"]:
		if nueva:
			var n := Negrita.new()
			n.texto = linea
			n.cubo = cubo_n
			n.grosor = grosor_n
			n.color = TEXTO
			col.add_child(n)
		else:
			UI.label(col, linea, 2.5, TEXTO, false)
	# la tira de teclas de abajo
	var tira := HBoxContainer.new()
	tira.add_theme_constant_override("separation", 10)
	col.add_child(tira)
	for par in [["Espacio", "Elegir"], ["Q E", "Pestaña"], ["Esc", "Volver"]]:
		if nueva:
			var k := Tecla.new()
			k.texto = par[0]
			k.cubo = cubo_n
			tira.add_child(k)
			var n2 := Negrita.new()
			n2.texto = par[1]
			n2.cubo = cubo_n
			n2.grosor = grosor_n
			n2.color = Color(0.95, 0.93, 0.88)
			tira.add_child(n2)
		else:
			var cap := Label.new()
			cap.text = par[0]
			cap.add_theme_font_size_override("font_size", 16)
			cap.add_theme_color_override("font_color", Color(0.12, 0.08, 0.16))
			var caja := PanelContainer.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.86, 0.82, 0.74)
			sb.set_content_margin_all(5)
			caja.add_theme_stylebox_override("panel", sb)
			caja.add_child(cap)
			tira.add_child(caja)
			UI.label(tira, par[1], 2.5, Color(0.95, 0.93, 0.88), false)
	# un párrafo largo, como el de una descripción
	var parrafo := "Cartas oscuras de borde claro, sin ruido, y la escena con más contraste y color. Si te pasas tú, pierdes aunque él también se pase."
	if nueva:
		var lineas := VFont.wrap(parrafo, 100)
		for ln in lineas:
			var n3 := Negrita.new()
			n3.texto = ln
			n3.cubo = cubo_n
			n3.grosor = grosor_n
			n3.color = TEXTO
			col.add_child(n3)
	else:
		UI.label(col, parrafo, 2.5, TEXTO, false, 360)
	return col


func _init() -> void:
	var salida: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "capturas/letra_comparacion.png"
	var fondo := ColorRect.new()
	fondo.color = FONDO
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(fondo)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 24)
	fila.position = Vector2(40, 30)
	root.add_child(fila)
	fila.add_child(_columna("AHORA", false))
	fila.add_child(_columna("SUAVE", true, 2.8, 1.0))
	fila.add_child(_columna("MEDIA", true, 2.7, 1.25))
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png(salida)
	quit()
