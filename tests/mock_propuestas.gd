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
const TEXT := "Son 260 de claridad para pasar a la torre que sigue. ¿Pagás, o volvés a subir la que acabás de dejar?"
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
			_centered(root, "Sólo ves unos pocos pisos por encima de vos.", 2.5, WHITE, 632.0)
		"B":   # una franja a todo el ancho, como un subtítulo de película
			var bg := Canvas.new()
			bg.painter = func(ci):
				var w: float = ci.size.x
				ci.draw_rect(Rect2(0, 584, w, 100), Color(0.03, 0.02, 0.06, 0.75))
				ci.draw_rect(Rect2(0, 584, w, 3), Color(0.85, 0.7, 0.3, 0.9))
			root.add_child(bg)
			_label(root, "PRUEBA", 2.5, Color(0.85, 0.7, 0.3), Vector2(70, 598))
			_label(root, "Niebla", 6.0, GOLD, Vector2(70, 626))
			_label(root, "Sólo ves unos pocos pisos por encima de vos.", 3.0, WHITE, Vector2(360, 640))
		"C":   # sin placa: letras grandes que bailan, con sombra, en el tercio de abajo
			_centered(root, "Prueba", 3.0, Color(0.85, 0.7, 0.3), 540.0)
			_centered(root, "Niebla", 8.0, GOLD, 572.0, true)
			_centered(root, "Sólo ves unos pocos pisos por encima de vos.", 3.0, WHITE, 640.0)


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
	if mode == "casino":
		main.enter_casino(true)
	for i in 40:
		await process_frame
	_hide_real_hud(main)
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
