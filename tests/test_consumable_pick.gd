extends SceneTree
## Elegir consumibles con el mando: mantener "usar el consumible elegido" (RT) y arriba o abajo cambia el casillero; al soltar se usa; tocarlo sin mover usa el último elegido.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_consumable_pick.gd

const ConsumablePick := preload("res://scripts/consumable_pick.gd")
const Controls := preload("res://scripts/controls.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _key(id: String, pressed: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = Controls.key_of(id) as Key
	e.physical_keycode = e.keycode
	e.pressed = pressed
	return e


func _init() -> void:
	check(Controls.key_of("consumible_usar") == KEY_G, "el teclado usa la G por defecto")
	var rt := false
	for p in Controls.pads_of("consumible_usar"):
		if p.has("axis") and int(p.axis) == Controls.AXIS_RT:
			rt = true
	check(rt, "en el mando es RT")
	var pad_1: Array = Controls.pads_of("consumible_1")
	check(pad_1.is_empty(), "RT ya no usa directo el casillero 1")
	var p := ConsumablePick.new()
	# tocar sin mover: usa el casillero elegido (el primero)
	check(p.process(_key("consumible_usar", true), 3).taken and int(p.process(_key("consumible_usar", false), 3).use) == 0, "tocar usa el casillero 1")
	# sin consumibles no usa nada
	p.process(_key("consumible_usar", true), 0)
	check(int(p.process(_key("consumible_usar", false), 0).use) == -1, "sin consumibles no se usa nada")
	# mantener y bajar: cambia el elegido y al soltar usa ése
	p.process(_key("consumible_usar", true), 3)
	Input.parse_input_event(_key("consumible_usar", true))
	Input.flush_buffered_events()
	var r: Dictionary = p.process(_key("mover_atras", true), 3)
	check(r.taken and p.sel == 1 and p.marked() == 1, "mantener y abajo elige el siguiente")
	p.process(_key("mover_atras", true), 3)
	p.process(_key("mover_atras", true), 3)
	check(p.sel == 0, "da la vuelta al llegar al final")
	p.process(_key("mover_adelante", true), 3)
	check(p.sel == 2, "arriba elige el anterior")
	Input.parse_input_event(_key("consumible_usar", false))
	Input.flush_buffered_events()
	check(int(p.process(_key("consumible_usar", false), 3).use) == -1, "si se movió la elección, soltar no usa nada")
	check(p.marked() == -1, "al soltar se apaga el marco")
	# sin mantener, las flechas no las toma
	check(not p.process(_key("mover_atras", true), 3).taken, "sin mantener, el movimiento sigue normal")
	print("tests de elegir consumibles terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
