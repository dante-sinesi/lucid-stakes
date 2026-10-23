extends SceneTree
## Números grandes legibles (NumberFormat) y que los contadores de claridad no rompan el diseño con 10^9 o más.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_numeros.gd

const NumberFormat := preload("res://scripts/datos/number_format.gd")
const Loc := preload("res://scripts/idioma/loc.gd")
const ClarityCounter := preload("res://scripts/ui/clarity_counter.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	Loc.set_lang("es")
	check(NumberFormat.fmt(0) == "0" and NumberFormat.fmt(999) == "999" and NumberFormat.fmt(9999) == "9999", "hasta 9999 se escribe entero")
	check(NumberFormat.fmt(10000) == "10 mil" and NumberFormat.fmt(12345) == "12,3 mil" and NumberFormat.fmt(123456) == "123 mil", "miles: 10 mil, 12,3 mil, 123 mil")
	check(NumberFormat.fmt(1000000) == "1 M" and NumberFormat.fmt(1234567) == "1,23 M" and NumberFormat.fmt(98765432) == "98,8 M", "millones")
	check(NumberFormat.fmt(4500000000) == "4,5 B" and NumberFormat.fmt(2000000000000) == "2 T", "miles de millones (B) y billones (T)")
	check(NumberFormat.fmt(-12345) == "-12,3 mil", "negativos")
	check(NumberFormat.fmt(1e15) == "1 P", "mil billones")
	Loc.set_lang("en")
	check(NumberFormat.fmt(12345) == "12.3k" and NumberFormat.fmt(1234567) == "1.23M" and NumberFormat.fmt(4500000000) == "4.5B", "en inglés: 12.3k, 1.23M, 4.5B")
	Loc.set_lang("es")
	# Loc.f abrevia sólo los %d de 10 mil o más (el resto queda igual)
	check(Loc.f("Peaje %d", [260]) == "Peaje 260" and Loc.f("Peaje %d", [1234567]) == "Peaje 1,23 M", "Loc.f abrevia el peaje grande y deja el chico")
	check(Loc.f("%d de %d (%d %%)", [12345, 99, 50]) == "12,3 mil de 99 (50 %)", "sólo se abrevia el valor grande y el %% sigue andando")
	Loc.set_lang("en")
	check(Loc.f("Peaje %d", [1234567]) == "Peaje 1.23M" or Loc.f("Peaje %d", [1234567]).ends_with("1.23M"), "en inglés también")
	Loc.set_lang("es")
	var main_script: GDScript = load("res://scripts/main.gd")
	check(main_script.gain_weight(5) == 0.0 and main_script.gain_weight(100) > 0.1 and main_script.gain_weight(100) < main_script.gain_weight(100000) and main_script.gain_weight(100000000) == 1.0, "el peso de la ganancia sube con el tamaño (0 a 1)")
	# el contador no se rompe con números enormes
	var c := ClarityCounter.new(3.5)
	root.add_child(c)
	await process_frame
	c.value = 1234567890
	await process_frame
	check(c.label.text == "1,23 B" and c.get_combined_minimum_size().x < 260.0, "el contador de claridad muestra 1,23 B y no se ensancha (%s)" % str(c.get_combined_minimum_size()))
	c.value = 7
	check(c.label.text == "7", "los chicos siguen igual")
	c.queue_free()
	print("tests de números grandes terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
