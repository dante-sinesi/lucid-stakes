extends SceneTree
## Maquetas del HUD, del diálogo del duende y del cartel de la prueba (tres propuestas: A, B y C) sobre el juego real.
## GAME_SANDBOX=1 godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/mock_propuestas.gd -- casino|torre PREFIJO
## Genera PREFIJO_A_<modo>.png, PREFIJO_B_<modo>.png y PREFIJO_C_<modo>.png. Es sólo para decidir el diseño (docs/plan_demo.md, punto 10).

const Draw := preload("res://scripts/voxel_draw.gd")
const VFont := preload("res://scripts/voxel_font.gd")
const VoxelLabel := preload("res://scripts/voxel_label.gd")
const LivesHud := preload("res://scripts/lives_hud.gd")
const ClarityCounter := preload("res://scripts/clarity_counter.gd")

## Cara provisoria del duende (12 x 13 cubitos, como la del tabernero).
const GOB := ["....rrrr....", "...rrrrrr...", "..rrrrrrrr..", "gg.rrrrrr.gg", "gggggggggggg", ".ggyKggyKgg.", "..gggnngggg.",
		"..gggnngggg.", "..gdmmmmdgg.", "...gggggg...", "..bbbbbbbb..", ".bbbbyybbbb.", ".bbbbbbbbbb."]
const GOB_PAL := {"r": Color(0.78, 0.12, 0.14), "g": Color(0.42, 0.68, 0.28), "y": Color(1.0, 0.85, 0.2), "K": Color(0.05, 0.05, 0.05),
		"n": Color(0.30, 0.52, 0.20), "d": Color(0.12, 0.08, 0.08), "m": Color(0.95, 0.95, 0.9), "b": Color(0.42, 0.26, 0.14)}

const BOX_W := 1040.0
const BOX_H := 210.0
const TEXT := "Son 260 de claridad para pasar a la torre que sigue. ¿Pagás, o vuelves a subir la que acabás de dejar?"
const GOLD := Color(1.0, 0.85, 0.40)
const WHITE := Color(0.97, 0.95, 0.9)


class Canvas extends Control:
	var painter: Callable

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


func _label(parent: Node, text: String, cube: float, color: Color, pos: Vector2, plate := 0.0) -> Control:
	var l := VoxelLabel.new()
	l.localize = false
	l.cube = cube
	l.color = color
	l.plate_alpha = plate
	l.text = text
	l.position = pos
	parent.add_child(l)
	return l


func _centered(parent: Node, text: String, cube: float, color: Color, y: float, dance := false) -> Control:
	var l := VoxelLabel.new()
	l.localize = false
	l.cube = cube
	l.color = color
	l.text = text
	l.align = VoxelLabel.Align.CENTER
	l.dance = dance
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.y_offset = y
	parent.add_child(l)
	return l


func _hearts(parent: Node, pos: Vector2) -> void:
	var h := LivesHud.new()
	h.compact = true
	h.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	h.position = pos
	h.size = h.custom_minimum_size
	parent.add_child(h)


func _clarity(parent: Node, pos: Vector2, cube := 3.5) -> void:
	var c := ClarityCounter.new(cube)
	c.value = 300
	c.position = pos
	parent.add_child(c)


## ---- HUD: tres propuestas ----

func _hud(kind: String, root: Control) -> void:
	match kind:
		"A":   # un solo marco de cubitos con borde dorado (el mismo lenguaje del cuadro de diálogo y de las pantallas)
			var bg := Canvas.new()
			bg.painter = func(ci): Draw.card(ci, Rect2(Vector2(14, 12), Vector2(250, 204)), 5.0, 0, 0.06, 77, false, -1.0)
			root.add_child(bg)
			_hearts(root, Vector2(40, 30))
			_label(root, "Etapa 2", 3.0, WHITE, Vector2(40, 74))
			_clarity(root, Vector2(40, 108))
			_label(root, "Peaje 260", 3.0, Color(0.55, 0.9, 0.4), Vector2(40, 164))
		"B":   # placas sueltas, sin marco general: cada dato en su propia placita de piedra
			var bg := Canvas.new()
			bg.painter = func(ci):
				Draw.card(ci, Rect2(Vector2(14, 12), Vector2(176, 52)), 4.0, 0, 0.05, 11, false, -1.0)
				Draw.card(ci, Rect2(Vector2(14, 78), Vector2(176, 46)), 4.0, 0, 0.05, 12, false, -1.0)
				Draw.card(ci, Rect2(Vector2(14, 138), Vector2(176, 52)), 4.0, 0, 0.05, 13, false, -1.0)
				Draw.card(ci, Rect2(Vector2(14, 204), Vector2(210, 46)), 4.0, 1, 0.05, 14, true, -1.0)
			root.add_child(bg)
			_hearts(root, Vector2(30, 22))
			_label(root, "Etapa 2", 3.0, WHITE, Vector2(30, 90))
			_clarity(root, Vector2(30, 148), 3.2)
			_label(root, "Peaje 260", 2.8, GOLD, Vector2(30, 216))
		"C":   # barra fina arriba de todo el ancho: vidas a la izquierda, etapa al centro, claridad y peaje a la derecha
			var bg := Canvas.new()
			bg.painter = func(ci):
				var w: float = ci.size.x
				ci.draw_rect(Rect2(0, 0, w, 66), Color(0.03, 0.02, 0.06, 0.78))
				ci.draw_rect(Rect2(0, 66, w, 3), Color(0.85, 0.7, 0.3, 0.9))
				for i in int(w / 12.0):
					Draw.cube(ci, Vector2(i * 12.0, 69), 6.0, Color(0.55, 0.38, 0.12), true)
			root.add_child(bg)
			_hearts(root, Vector2(24, 16))
			_centered(root, "Etapa 2", 4.0, WHITE, 18.0)
			_clarity(root, Vector2(780, 14), 3.2)
			_label(root, "Peaje 260", 3.0, Color(0.55, 0.9, 0.4), Vector2(950, 24))


## ---- Diálogo del duende con las dos salidas: pagar o rehacer la torre ----

func _dialogue(kind: String, root: Control) -> void:
	var ox := 120.0
	var oy := 720.0 - BOX_H - 14.0
	var box := Canvas.new()
	box.painter = func(ci):
		Draw.card(ci, Rect2(Vector2(ox, oy), Vector2(BOX_W, BOX_H - 10.0)), 6.0, 0, 0.1, 4242, false, -1.0)
		var s := 7.0
		var origin := Vector2(ox + 48, oy + 24)
		ci.draw_rect(Rect2(origin - Vector2(8, 8), Vector2(12 * s + 16, 13 * s + 16)), Color(0.05, 0.03, 0.09))
		for y in GOB.size():
			var row: String = GOB[y]
			for x in row.length():
				if row[x] == ".":
					continue
				var col: Color = GOB_PAL.get(row[x], Color.MAGENTA)
				var p := origin + Vector2(x, y) * s
				ci.draw_rect(Rect2(p, Vector2(s, s)), col)
				ci.draw_rect(Rect2(p, Vector2(s, maxf(s * 0.18, 1.0))), col.lightened(0.3))
				ci.draw_rect(Rect2(p + Vector2(0, s * 0.82), Vector2(s, maxf(s * 0.18, 1.0))), col.darkened(0.35))
		match kind:
			"A":   # dos botones de cubitos dentro del cuadro, abajo a la derecha (el elegido, dorado)
				Draw.card(ci, Rect2(Vector2(ox + 440, oy + 138), Vector2(200, 52)), 4.0, 1, 0.0, 5, true, -1.0)
				Draw.card(ci, Rect2(Vector2(ox + 660, oy + 138), Vector2(350, 52)), 4.0, 0, 0.0, 6, false, -1.0)
			"B":   # menú vertical flotando sobre el cuadro, a la derecha, con un cursor de cubito
				Draw.card(ci, Rect2(Vector2(ox + 590, oy - 118), Vector2(440, 48)), 4.0, 1, 0.0, 7, true, -1.0)
				Draw.card(ci, Rect2(Vector2(ox + 590, oy - 62), Vector2(440, 48)), 4.0, 0, 0.0, 8, false, -1.0)
				Draw.cube(ci, Vector2(ox + 562, oy - 104), 14.0, GOLD, true)
			"C":   # una fila dentro del cuadro con el botón del mando (A / B) delante de cada salida
				ci.draw_circle(Vector2(ox + 220, oy + 158), 17.0, Color(0.25, 0.7, 0.35))
				ci.draw_circle(Vector2(ox + 540, oy + 158), 17.0, Color(0.85, 0.3, 0.25))
	root.add_child(box)
	_label(root, "Duende", 3.0, GOLD, Vector2(ox + 176, oy + 22))
	_label(root, "\n".join(VFont.wrap(TEXT, 330)), 2.5, WHITE, Vector2(ox + 176, oy + 62))
	match kind:
		"A":
			_label(root, "Pagar 260", 2.5, Color(1, 0.95, 0.7), Vector2(ox + 486, oy + 154))
			_label(root, "Rehacer la torre  -1 vida", 2.2, WHITE, Vector2(ox + 684, oy + 154))
		"B":
			_label(root, "Pagar 260", 3.0, Color(1, 0.95, 0.7), Vector2(ox + 640, oy - 106))
			_label(root, "Rehacer la torre  -1 vida", 2.5, WHITE, Vector2(ox + 614, oy - 48))
		"C":
			_label(root, "A", 2.5, Color(0.02, 0.1, 0.03), Vector2(ox + 213, oy + 148))
			_label(root, "Pagar 260", 2.5, Color(1, 0.95, 0.7), Vector2(ox + 250, oy + 148))
			_label(root, "B", 2.5, Color(0.1, 0.02, 0.02), Vector2(ox + 533, oy + 148))
			_label(root, "Rehacer la torre  -1 vida", 2.5, WHITE, Vector2(ox + 570, oy + 148))


## ---- Cartel de la prueba, abajo en la pantalla ----

func _trial(kind: String, root: Control) -> void:
	match kind:
		"A":   # un cartel de cubitos dorado, centrado abajo
			var bg := Canvas.new()
			bg.painter = func(ci): Draw.card(ci, Rect2(Vector2(300, 560), Vector2(680, 120)), 5.0, 0, 0.06, 31, true, -1.0)
			root.add_child(bg)
			_centered(root, "Prueba: Niebla", 5.0, GOLD, 578.0)
			_centered(root, "Sólo ves unos pocos pisos por encima de ti.", 2.5, WHITE, 632.0)
		"B":   # una franja a todo el ancho, como un subtítulo de película
			var bg := Canvas.new()
			bg.painter = func(ci):
				var w: float = ci.size.x
				ci.draw_rect(Rect2(0, 584, w, 100), Color(0.03, 0.02, 0.06, 0.75))
				ci.draw_rect(Rect2(0, 584, w, 3), Color(0.85, 0.7, 0.3, 0.9))
			root.add_child(bg)
			_label(root, "PRUEBA", 2.5, Color(0.85, 0.7, 0.3), Vector2(70, 598))
			_label(root, "Niebla", 6.0, GOLD, Vector2(70, 626))
			_label(root, "Sólo ves unos pocos pisos por encima de ti.", 3.0, WHITE, Vector2(360, 640))
		"C":   # sin placa: letras grandes que bailan, con sombra, en el tercio de abajo
			_centered(root, "Prueba", 3.0, Color(0.85, 0.7, 0.3), 540.0)
			_centered(root, "Niebla", 8.0, GOLD, 572.0, true)
			_centered(root, "Sólo ves unos pocos pisos por encima de ti.", 3.0, WHITE, 640.0)

## ---- Versión final elegida por Dante: el Farolero, HUD tipo cuadro de texto, cartel de la prueba sin fondo ----

## Cara del Farolero (12 x 13 cubitos): un farol de hierro con asa, llama con ojos y boca, y los bracitos a los costados.
const FAROL := ["....kkkk....", "...k....k...", "..kkkkkkkk..", ".kkkkkkkkkk.", ".kOYYYYYYOk.", ".kYEEYYEEYk.", ".kYEEYYEEYk.",
		"aakYYYYYYkaa", ".kYEYYYYEYk.", ".kOYEEEEYOk.", ".kkkkkkkkkk.", "..kkkkkkkk..", "..bb....bb.."]
const FAROL_PAL := {"k": Color(0.16, 0.14, 0.18), "Y": Color(1.0, 0.86, 0.35), "E": Color(0.18, 0.1, 0.05), "O": Color(1.0, 0.55, 0.15),
		"a": Color(0.3, 0.27, 0.32), "b": Color(0.3, 0.27, 0.32)}


func _dialogue_final(device: String, has_lives: bool, root: Control) -> void:
	var ox := 120.0
	var oy := 720.0 - BOX_H - 14.0
	var box := Canvas.new()
	box.painter = func(ci):
		Draw.card(ci, Rect2(Vector2(ox, oy), Vector2(BOX_W, BOX_H - 10.0)), 6.0, 0, 0.1, 4242, false, -1.0)
		var s := 7.0
		var origin := Vector2(ox + 48, oy + 24)
		ci.draw_rect(Rect2(origin - Vector2(8, 8), Vector2(12 * s + 16, 13 * s + 16)), Color(0.05, 0.03, 0.09))
		for y in FAROL.size():
			var row: String = FAROL[y]
			for x in row.length():
				if row[x] == ".":
					continue
				var col: Color = FAROL_PAL.get(row[x], Color.MAGENTA)
				var p := origin + Vector2(x, y) * s
				ci.draw_rect(Rect2(p, Vector2(s, s)), col)
				ci.draw_rect(Rect2(p, Vector2(s, maxf(s * 0.18, 1.0))), col.lightened(0.3))
				ci.draw_rect(Rect2(p + Vector2(0, s * 0.82), Vector2(s, maxf(s * 0.18, 1.0))), col.darkened(0.35))
		# la luz de la llama sobre el cuadro
		ci.draw_circle(origin + Vector2(6, 6) * s, 62.0, Color(1.0, 0.8, 0.3, 0.07))
		if device == "mando":
			ci.draw_circle(Vector2(ox + 220, oy + 158), 17.0, Color(0.25, 0.7, 0.35))
			ci.draw_circle(Vector2(ox + 540, oy + 158), 17.0, Color(0.85, 0.3, 0.25))
		else:   # teclas: 1 y 2
			Draw.card(ci, Rect2(Vector2(ox + 196, oy + 136), Vector2(48, 44)), 4.0, 1, 0.0, 21, true, -1.0)
			Draw.card(ci, Rect2(Vector2(ox + 516, oy + 136), Vector2(48, 44)), 4.0, 0, 0.0, 22, false, -1.0)
	root.add_child(box)
	var txt := "Son 260 de claridad para seguir. ¿Pagás, o vuelves a subir esta torre?"
	if not has_lives:
		txt = "Son 260 de claridad, y ya no te queda ninguna vida. ¿Pagás, o dejás que todo se apague?"
	_label(root, "Farolero", 3.0, GOLD, Vector2(ox + 176, oy + 22))
	_label(root, "
".join(VFont.wrap(txt, 330)), 2.5, WHITE, Vector2(ox + 176, oy + 62))
	var k1 := "A" if device == "mando" else "1"
	var k2 := "B" if device == "mando" else "2"
	var off := 0.0 if device == "mando" else 0.0
	var c1 := Color(0.02, 0.1, 0.03) if device == "mando" else Color(1, 0.95, 0.7)
	var c2 := Color(0.1, 0.02, 0.02) if device == "mando" else WHITE
	_label(root, k1, 2.5, c1, Vector2(ox + (213 if device == "mando" else 213), oy + 148))
	_label(root, "Pagar 260", 2.5, Color(1, 0.95, 0.7), Vector2(ox + (250 if device == "mando" else 262), oy + 148))
	_label(root, k2, 2.5, c2, Vector2(ox + (533 if device == "mando" else 533), oy + 148))
	_label(root, "Rehacer la torre  -1 vida" if has_lives else "Abandonar", 2.5, WHITE, Vector2(ox + (570 if device == "mando" else 582), oy + 148))


func _trial_final(root: Control) -> void:
	_centered(root, "Prueba", 3.0, Color(0.85, 0.7, 0.3), 516.0)
	_centered(root, "Niebla", 8.0, GOLD, 548.0, true)
	_centered(root, "Sólo ves unos pocos pisos por encima de ti.", 3.0, WHITE, 650.0)


## ---- Tercera corrida: Farolín en 3D, opciones lado a lado con flechas (teclado) o stick (mando), prueba al pausar ----

static func _fbox(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glow := 0.0) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	m.material_override = mat
	m.position = pos
	parent.add_child(m)


## Farolín en 3D (unos 0,55 de alto, los pies en y = 0, mirando hacia +z): farol de hierro con asa, llama con ojos y sonrisa, brazos y patitas.
static func _farolin3d() -> Node3D:
	var r := Node3D.new()
	r.name = "farolin"
	var iron := Color(0.16, 0.14, 0.18)
	var iron2 := Color(0.3, 0.27, 0.32)
	var glow := Color(1.0, 0.8, 0.3)
	var dark := Color(0.25, 0.1, 0.02)
	_fbox(r, Vector3(-0.06, 0.06, 0), Vector3(0.06, 0.12, 0.07), iron2)
	_fbox(r, Vector3(0.06, 0.06, 0), Vector3(0.06, 0.12, 0.07), iron2)
	_fbox(r, Vector3(0, 0.145, 0), Vector3(0.22, 0.05, 0.22), iron)
	_fbox(r, Vector3(0, 0.27, 0), Vector3(0.17, 0.2, 0.17), glow, 1.6)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_fbox(r, Vector3(0.09 * sx, 0.27, 0.09 * sz), Vector3(0.025, 0.21, 0.025), iron)
	_fbox(r, Vector3(0, 0.385, 0), Vector3(0.24, 0.04, 0.24), iron)
	_fbox(r, Vector3(0, 0.425, 0), Vector3(0.13, 0.04, 0.13), iron)
	_fbox(r, Vector3(0, 0.505, 0), Vector3(0.11, 0.02, 0.02), iron)
	_fbox(r, Vector3(-0.055, 0.465, 0), Vector3(0.02, 0.08, 0.02), iron)
	_fbox(r, Vector3(0.055, 0.465, 0), Vector3(0.02, 0.08, 0.02), iron)
	_fbox(r, Vector3(-0.04, 0.31, 0.092), Vector3(0.035, 0.055, 0.012), dark)
	_fbox(r, Vector3(0.04, 0.31, 0.092), Vector3(0.035, 0.055, 0.012), dark)
	_fbox(r, Vector3(0, 0.235, 0.092), Vector3(0.09, 0.02, 0.012), dark)
	_fbox(r, Vector3(-0.045, 0.25, 0.092), Vector3(0.02, 0.02, 0.012), dark)
	_fbox(r, Vector3(0.045, 0.25, 0.092), Vector3(0.02, 0.02, 0.012), dark)
	_fbox(r, Vector3(-0.145, 0.24, 0), Vector3(0.05, 0.13, 0.05), iron2)
	_fbox(r, Vector3(0.145, 0.24, 0), Vector3(0.05, 0.13, 0.05), iron2)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.28, 0.15)
	light.light_color = Color(1.0, 0.75, 0.35)
	light.light_energy = 1.3
	light.omni_range = 2.0
	r.add_child(light)
	return r


## Triángulo que apunta a la izquierda (dir = -1) o a la derecha (dir = 1), de alto 2r, con la punta en `c`.
func _tri(ci: CanvasItem, c: Vector2, dir: int, r: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(dir * r, 0), c + Vector2(-dir * r * 0.6, -r), c + Vector2(-dir * r * 0.6, r)]), col)


func _dialogue_v3(device: String, has_lives: bool, sel: int, can_pay: bool, root: Control) -> void:
	var ox := 120.0
	var oy := 720.0 - BOX_H - 14.0
	var box := Canvas.new()
	box.painter = func(ci):
		Draw.card(ci, Rect2(Vector2(ox, oy), Vector2(BOX_W, BOX_H - 10.0)), 6.0, 0, 0.1, 4242, false, -1.0)
		var s := 7.0
		var origin := Vector2(ox + 48, oy + 24)
		ci.draw_rect(Rect2(origin - Vector2(8, 8), Vector2(12 * s + 16, 13 * s + 16)), Color(0.05, 0.03, 0.09))
		for y in FAROL.size():
			var row: String = FAROL[y]
			for x in row.length():
				if row[x] == ".":
					continue
				var col: Color = FAROL_PAL.get(row[x], Color.MAGENTA)
				var p := origin + Vector2(x, y) * s
				ci.draw_rect(Rect2(p, Vector2(s, s)), col)
				ci.draw_rect(Rect2(p, Vector2(s, maxf(s * 0.18, 1.0))), col.lightened(0.3))
				ci.draw_rect(Rect2(p + Vector2(0, s * 0.82), Vector2(s, maxf(s * 0.18, 1.0))), col.darkened(0.35))
		var st1 := 3 if not can_pay else (1 if sel == 0 else 0)
		Draw.card(ci, Rect2(Vector2(ox + 240, oy + 138), Vector2(230, 52)), 4.0, st1, 0.0, 5, sel == 0 and can_pay, -1.0)
		Draw.card(ci, Rect2(Vector2(ox + 484, oy + 138), Vector2(400, 52)), 4.0, 1 if sel == 1 else 0, 0.0, 6, sel == 1, -1.0)
		var keycol := Color(0.9, 0.88, 0.8)
		if device == "mando":
			ci.draw_circle(Vector2(ox + 204, oy + 164), 22.0, Color(0.2, 0.2, 0.26))
			ci.draw_arc(Vector2(ox + 204, oy + 164), 22.0, 0.0, TAU, 24, keycol, 2.0)
			_tri(ci, Vector2(ox + 191, oy + 164), -1, 7.0, keycol)
			_tri(ci, Vector2(ox + 217, oy + 164), 1, 7.0, keycol)
			ci.draw_circle(Vector2(ox + 960, oy + 164), 20.0, Color(0.25, 0.7, 0.35))
		else:
			Draw.card(ci, Rect2(Vector2(ox + 176, oy + 140), Vector2(48, 48)), 4.0, 0, 0.0, 31, false, -1.0)
			Draw.card(ci, Rect2(Vector2(ox + 896, oy + 140), Vector2(48, 48)), 4.0, 0, 0.0, 32, false, -1.0)
			Draw.card(ci, Rect2(Vector2(ox + 954, oy + 140), Vector2(76, 48)), 4.0, 0, 0.0, 33, false, -1.0)
			_tri(ci, Vector2(ox + 191, oy + 164), -1, 9.0, keycol)
			_tri(ci, Vector2(ox + 929, oy + 164), 1, 9.0, keycol)
	root.add_child(box)
	var txt := "Son 260 de claridad para seguir. ¿Pagás, o vuelves a subir esta torre?"
	if not has_lives:
		txt = "Son 260 de claridad, y ya no te queda ninguna vida. ¿Pagás, o dejás que todo se apague?"
	if not can_pay:
		txt = "Son 260 de claridad y te faltan 40. Sin luz no hay camino: ¿vuelves a subir la torre?"
	_label(root, "Farolín", 3.0, GOLD, Vector2(ox + 176, oy + 22))
	_label(root, "\n".join(VFont.wrap(txt, 330)), 2.5, WHITE, Vector2(ox + 176, oy + 62))
	_label(root, "Pagar 260", 2.5, Color(0.5, 0.45, 0.45) if not can_pay else Color(1, 0.95, 0.7), Vector2(ox + 280, oy + 154))
	_label(root, "Rehacer la torre  -1 vida" if has_lives else "Abandonar", 2.5, WHITE, Vector2(ox + 510, oy + 154))
	if device == "mando":
		_label(root, "A", 2.5, Color(0.02, 0.1, 0.03), Vector2(ox + 953, oy + 154))
	else:
		_label(root, "Enter", 1.8, WHITE, Vector2(ox + 966, oy + 158))


func _run_v3(main, mode: String, prefix: String) -> void:
	var variants: Array = []
	if mode == "casino3":
		variants = [["tec_pagar", "teclado", true, 0, true], ["tec_rehacer", "teclado", true, 1, true], ["pad_sinvidas", "mando", false, 0, true],
				["pad_abandonar", "mando", false, 1, true], ["tec_noalcanza", "teclado", true, 1, false]]
		var c = main.casino
		if c._goblin != null:
			c._goblin.visible = false
			var f := _farolin3d()
			f.scale = Vector3.ONE * 3.3
			f.position = c._goblin.position + Vector3(-0.9, 0.0, -0.1)
			f.rotation_degrees.y = 45.0
			c.add_child(f)
		c.player_node.rotation.y = deg_to_rad(45.0)   # (aparece de frente a la cámara)
	else:
		variants = [["vis"], ["pausa"]]
	for v in variants:
		var layer := CanvasLayer.new()
		layer.layer = 99
		root.add_child(layer)
		var top := Control.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.add_child(top)
		_hud("A", top)
		if mode == "casino3":
			_dialogue_v3(v[1], v[2], v[3], v[4], top)
		else:
			if v[0] == "pausa":
				main.pause_game()
			_trial_final(top)
		for i in 14:
			await process_frame
		root.get_texture().get_image().save_png("%s_v3_%s.png" % [prefix, v[0]])
		layer.queue_free()
		await process_frame
	print("tercera corrida lista: ", mode)
	quit(0)



func _hide_real_hud(n: Node) -> void:
	if n.name == "ventana_partida" and n is CanvasItem:
		n.visible = false
	for c in n.get_children():
		_hide_real_hud(c)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "casino"
	var prefix := args[1] if args.size() > 1 else "capturas/propuestas/mock"
	var main = load("res://scenes/main.tscn").instantiate()
	main.quit_game_override = true
	main.test_mode = true
	main.toll_in_tests = true
	main.quick_portal = true
	root.add_child(main)
	await process_frame
	while main.generating or main.logic == null:
		await process_frame
	main.in_menu = false
	paused = false
	main.main_menu.visible = false
	main._cancel_jobs()
	main.generating = false
	main.stage_number = 2
	main.run.stage = 2
	main.run.claridad = 300
	if mode.begins_with("casino"):
		main.enter_casino(true)
	for i in 40:
		await process_frame
	_hide_real_hud(main)
	if mode.ends_with("3"):
		await _run_v3(main, mode, prefix)
		return
	if mode.ends_with("2"):
		var variants: Array = [["teclado", true], ["mando", true], ["teclado", false], ["mando", false]] if mode == "casino2" else [["vis", 1.0], ["des", 0.35]]
		for v in variants:
			var layer2 := CanvasLayer.new()
			layer2.layer = 50
			root.add_child(layer2)
			var top2 := Control.new()
			top2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			top2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			layer2.add_child(top2)
			_hud("A", top2)
			var tag := ""
			if mode == "casino2":
				_dialogue_final(v[0], v[1], top2)
				tag = "%s_%s" % [v[0], "vidas" if v[1] else "sinvidas"]
			else:
				var tr := Control.new()
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				tr.modulate.a = v[1]
				top2.add_child(tr)
				_trial_final(tr)
				tag = v[0]
			for i in 12:
				await process_frame
			root.get_texture().get_image().save_png("%s_final_%s.png" % [prefix, tag])
			layer2.queue_free()
			await process_frame
		print("maquetas finales listas: ", mode)
		quit(0)
		return
	for kind in ["A", "B", "C"]:
		var layer := CanvasLayer.new()
		layer.layer = 50
		root.add_child(layer)
		var top := Control.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.add_child(top)
		_hud(kind, top)
		if mode == "casino":
			_dialogue(kind, top)
		else:
			_trial(kind, top)
		for i in 12:
			await process_frame
		root.get_texture().get_image().save_png("%s_%s_%s.png" % [prefix, kind, mode])
		layer.queue_free()
		await process_frame
	print("maquetas listas: ", mode)
	quit(0)
