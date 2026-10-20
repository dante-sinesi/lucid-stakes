extends SceneTree
## Farolín (el peaje de la puerta de salida): su cara y su modelo 3D, lo que ofrece en cada caso, el cuadro de diálogo con decisiones (flechas y Enter/Espacio),
## y que en los 4 casinos tenga su celda libre de muebles junto a la puerta.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_farolin.gd

const Farolin := preload("res://scripts/farolin.gd")
const DialogueBox := preload("res://scripts/dialogue_box.gd")
const CasinoScene := preload("res://scripts/casino_scene.gd")
const Room := preload("res://scripts/casino_room.gd")
const RunState := preload("res://scripts/run_state.gd")

var fails := 0
var chosen_log: Array = []


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


## Farolín tiene su frase para cada decisión (que el español sea neutro lo comprueba tests/test_neutro.gd en todo el juego).
func test_reactions() -> void:
	for id in [Farolin.PAY, Farolin.REDO, Farolin.GIVE_UP]:
		check(Farolin.reaction(id) != "", "Farolín contesta cuando eliges %s" % id)


## Los diseños de Farolín (el de siempre y tres sin sonrisa): cada cara tiene 13 filas de 12 con colores válidos y cada modelo 3D se arma y cambia de ánimo.
func test_variants() -> void:
	check(Farolin.FACE_VARIANTS.size() == 4, "hay cuatro diseños de Farolín")
	for v in Farolin.FACE_VARIANTS.size():
		var rows: Array = Farolin.face_rows(v)
		var ok: bool = rows.size() == 13
		for row in rows:
			ok = ok and str(row).length() == 12
			for ch in str(row):
				ok = ok and (ch == "." or Farolin.FACE_PAL.has(ch))
		check(ok, "la cara del diseño %d es válida" % v)
		var f: Node3D = Farolin.build(v)
		check(f != null and f.smile != null and f.frown != null and f.flame != null, "el modelo 3D del diseño %d se arma" % v)
		f.set_mood("triste")
		check(f.frown.visible and not f.smile.visible, "el diseño %d cambia a la cara triste" % v)
		f.free()


func _init() -> void:
	test_variants()
	test_reactions()
	test_face()
	test_model()
	test_toll_dialog()
	await test_dialogue_choice()
	await test_casinos()
	print("tests de Farolín terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_face() -> void:
	check(Farolin.FACE.size() == 13, "la cara tiene 13 filas")
	var ok := true
	for row in Farolin.FACE:
		ok = ok and str(row).length() == 12
		for ch in str(row):
			if ch != "." and not Farolin.FACE_PAL.has(ch):
				ok = false
	check(ok, "todas las filas miden 12 y usan colores de la paleta")


func test_model() -> void:
	var f: Node3D = Farolin.build()
	check(f.get_child_count() > 15 and f.flame != null and f.light != null, "el modelo trae su llama, su luz y las partes del farol")
	f.set_mood("triste")
	check(f.frown.visible and not f.smile.visible, "triste: la boca va para abajo")
	f.set_mood("contento")
	check(f.smile.visible and not f.frown.visible, "contento: sonríe")
	f.free()


func test_toll_dialog() -> void:
	var d := Farolin.toll_dialog(100, 150, true)
	check(d.options.size() == 2 and d.options[0].id == "pagar" and d.options[0].enabled and d.options[1].id == "rehacer", "con vidas y claridad: Pagar y Rehacer la torre")
	check(str(d.options[1].text).contains("vida"), "Rehacer la torre dice que cuesta una vida")
	d = Farolin.toll_dialog(100, 40, true)
	check(not d.options[0].enabled and d.options[1].enabled and str(d.text).contains("60"), "sin claridad: Pagar apagado y dice cuánto falta")
	d = Farolin.toll_dialog(100, 150, false)
	check(d.options[0].enabled and d.options[1].id == "abandonar", "sin vidas: Pagar o Abandonar")
	d = Farolin.toll_dialog(100, 40, false)
	check(not d.options[0].enabled and d.options[1].id == "abandonar" and d.options[1].enabled, "sin vidas y sin claridad: sólo Abandonar")
	d = Farolin.toll_dialog(100, 40, true, false)
	check(not str(d.options[1].text).contains("vida"), "con el Tótem rehacer no cuesta vida")


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func test_dialogue_choice() -> void:
	var box: Control = DialogueBox.new()
	root.add_child(box)
	await process_frame
	box.chosen.connect(func(i): chosen_log.append(i))
	var opts := [{"id": "a", "text": "Pagar 50", "enabled": true}, {"id": "b", "text": "Rehacer la torre (−1 vida)", "enabled": true}]
	box.show_choice("Son 50 de claridad.", opts, Farolin.SPEAKER)
	check(box.is_choosing() and not box.options_visible(), "al empezar escribe el texto y todavía no se ven las opciones")
	box.advance()   # (completa el texto)
	check(box.options_visible() and box.selected == 0, "al terminar el texto aparecen las opciones, con la primera elegida")
	box._unhandled_input(_key(KEY_RIGHT))
	check(box.selected == 1, "flecha derecha elige la segunda")
	box._unhandled_input(_key(KEY_RIGHT))
	check(box.selected == 0, "y vuelve a la primera (da la vuelta)")
	box._unhandled_input(_key(KEY_LEFT))
	check(box.selected == 1, "flecha izquierda elige la anterior")
	box._unhandled_input(_key(KEY_ENTER))
	check(chosen_log == [1] and not box.is_active(), "Enter confirma la elegida y cierra el cuadro")
	# con la primera apagada la elección arranca y se queda en la segunda
	var opts2 := [{"id": "a", "text": "Pagar 50", "enabled": false}, {"id": "b", "text": "Abandonar", "enabled": true}]
	box.show_choice("No alcanza.", opts2, Farolin.SPEAKER)
	box.advance()
	check(box.selected == 1, "la opción apagada no se elige: arranca en la habilitada")
	box._unhandled_input(_key(KEY_LEFT))
	check(box.selected == 1, "con la flecha no se pasa a la apagada")
	box._unhandled_input(_key(KEY_SPACE))
	check(chosen_log == [1, 1], "Espacio también confirma")
	# Esc cancela
	box.show_choice("¿Seguro?", opts, Farolin.SPEAKER)
	box.advance()
	box.cancel_choice()
	check(chosen_log == [1, 1, -1] and not box.is_active(), "Esc cierra la decisión sin elegir (-1)")
	# antes de que termine de escribirse, Enter sólo completa el texto
	box.show_choice("Un texto un poco más largo para que tarde en escribirse del todo.", opts, Farolin.SPEAKER)
	box._unhandled_input(_key(KEY_ENTER))
	check(box.is_active() and box.options_visible() and chosen_log.size() == 3, "Enter mientras escribe sólo muestra el texto entero")
	box.hide_box()
	check(not box.is_choosing(), "hide_box limpia la decisión")
	box.queue_free()
	await process_frame


## En los 4 casinos Farolín tiene su celda junto a la puerta de salida, libre de muebles, y se llega a la puerta; el personaje aparece saliendo del portal.
func test_casinos() -> void:
	var stages := {}
	for s in range(1, 16):
		var t := Room.tier_of(s)
		if not stages.has(t):
			stages[t] = s
	check(stages.size() == 4, "hay 4 niveles de casino (taberna, salón, casino y gran casino)")
	for tier in stages:
		var run := RunState.new()
		run.stage = int(stages[tier])
		var c = CasinoScene.new()
		c.quick = true
		c.toll_base = 100
		root.add_child(c)
		c.setup(run, RandomNumberGenerator.new())
		var f: Vector2i = c.lay.farolin
		var e: Vector2i = c.lay.exit
		check(c.farolin_cell_free(), "nivel %d: la celda de Farolín está libre" % tier)
		check(f == e + Vector2i(-1, 0), "nivel %d: Farolín está pegado a la puerta de salida, contra su borde izquierdo" % tier)
		check(not Room.walkable(f, c.lay), "nivel %d: Farolín ocupa su celda (no se camina por ahí)" % tier)
		check(Room.reachable(c.lay.entry, c.lay).has(e), "nivel %d: se llega a la puerta de salida" % tier)
		check(c._farolin != null and absf(c._farolin.position.x - Room.world_of_cell(f, c.lay).x) < 0.001, "nivel %d: Farolín está en su celda" % tier)
		check(c.facing == Vector2i(1, 0) and absf(c.player_node.rotation.y - PI * 0.5) < 0.001 and c.cell.x == 0, "nivel %d: el personaje aparece saliendo del portal, mirando hacia adentro de la sala" % tier)
		var talk := [0]
		c.toll_talk.connect(func(): talk[0] += 1)
		c.cell = f + Vector2i(0, 1) if Room.walkable(f + Vector2i(0, 1), c.lay) else f + Vector2i(-1, 0)
		var dir: Vector2i = f - c.cell
		check(c.step(dir) == "farolin" and talk[0] == 1, "nivel %d: caminar hacia Farolín abre su diálogo" % tier)
		c.queue_free()
		await process_frame
	# sin peaje no hay Farolín ni celda ocupada
	var run2 := RunState.new()
	var c2 = CasinoScene.new()
	c2.quick = true
	root.add_child(c2)
	c2.setup(run2, RandomNumberGenerator.new())
	check(c2._farolin == null and Room.walkable(c2.lay.farolin, c2.lay), "sin peaje no hay Farolín y su celda queda libre")
	c2.queue_free()
	await process_frame
