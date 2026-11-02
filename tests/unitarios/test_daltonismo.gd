extends SceneTree
## La opción de daltonismo: el ajuste, los colores azul y naranja, los símbolos del peaje y de los movimientos, y la marca sobre cada bloque especial.
## Uso: GAME_SANDBOX=1 godot --headless --path . -s tests/unitarios/test_daltonismo.gd
const Settings := preload("res://scripts/datos/settings.gd")
const Seguro := preload("res://scripts/datos/archivo_seguro.gd")
const VDraw := preload("res://scripts/ui/voxel_draw.gd")
const HudPanel := preload("res://scripts/ui/hud_panel.gd")
const MarcaEspecial := preload("res://torre/marca_especial.gd")
const Vista := preload("res://torre/vista.gd")
const Motor := preload("res://torre/motor.gd")
const VFont := preload("res://scripts/ui/voxel_font.gd")

var fallos := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		fallos += 1
		print("FALLA ", msg)


func _init() -> void:
	await process_frame   # (el bucle principal todavía no existe en `_init`)
	Settings.headless_io = true   # (para que los ajustes se apliquen aun sin pantalla)
	Settings.path = "user://test_settings_dalto.json"
	Seguro.borrar("user://test_settings_dalto.json")
	Settings._loaded = false
	Settings.load_settings()
	check(not bool(Settings.get_value("daltonismo")) and not VDraw.daltonismo, "por omisión el daltonismo está apagado")
	check(VDraw.color_bien().g > VDraw.color_bien().b and VDraw.color_mal().r > 0.9, "apagado: verde y rojo coral de siempre")
	Settings.set_value("daltonismo", true)
	check(VDraw.daltonismo, "al prenderlo, el dibujo lo sabe")
	check(VDraw.color_bien().b > VDraw.color_bien().g and VDraw.color_bien().b > VDraw.color_bien().r, "prendido: el 'bien' es azul")
	check(VDraw.color_mal().r > 0.9 and VDraw.color_mal().b < 0.2 and VDraw.color_mal().g > 0.5, "prendido: el 'mal' es naranja")
	# el HUD: el peaje lleva una tilde o una equis, los movimientos que quedan pocos un signo de exclamación
	var hud = HudPanel.new()
	root.add_child(hud)
	await process_frame
	hud.set_toll(245, false)
	check(hud.toll_label.text.begins_with("✓") and hud.toll_label.color == VDraw.color_bien(), "el peaje que alcanza: tilde y azul")
	hud.set_toll(245, true)
	check(hud.toll_label.text.begins_with("×") and hud.toll_label.color == VDraw.color_mal(), "el peaje que no alcanza: equis y naranja")
	hud.set_moves("Movimientos 12/15", true)
	check(hud.moves_label.text.ends_with("!"), "pocos movimientos: signo de exclamación")
	check(VFont.G.has("✓"), "la fuente tiene la tilde")
	# las marcas de los bloques especiales
	for letra in ["i", "h", "c", "t", "s", "k"]:
		var img := MarcaEspecial.dibujo(letra)
		var blancos := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).r > 0.9:
					blancos += 1
		check(blancos >= 15, "la marca '%s' se dibuja (%d pixeles blancos)" % [letra, blancos])
	check(not MarcaEspecial.tiene("n") and not MarcaEspecial.tiene("b3") and MarcaEspecial.tiene("i"), "los bloques comunes y las bombas no llevan marca")
	var m = Motor.crear(5, Vector3i(0, 2, 0))
	m.poner(Vector3i(0, 1, 0), "p")
	m.poner(Vector3i(1, 1, 0), "i")
	m.poner(Vector3i(2, 1, 0), "n")
	m.poner(Vector3i(0, 1, 1), "s")
	var nodo := Node3D.new()
	root.add_child(nodo)
	Vista.poblar(nodo, m, {}, false, false, false, true)
	var marcas := 0
	for c in nodo.get_children():
		if str(c.name).begins_with("marca_"):
			marcas += 1
	check(marcas == 2, "con daltonismo hay una marca por cada especial (hielo y pinchos): %d" % marcas)
	Settings.set_value("daltonismo", false)
	var nodo2 := Node3D.new()
	root.add_child(nodo2)
	Vista.poblar(nodo2, m, {}, false, false, false, true)
	var sin := 0
	for c in nodo2.get_children():
		if str(c.name).begins_with("marca_"):
			sin += 1
	check(sin == 0, "apagado no hay marcas")
	Settings.headless_io = false
	Seguro.borrar("user://test_settings_dalto.json")
	print("tests del daltonismo terminados, fallos: ", fallos)
	quit(1 if fallos > 0 else 0)
