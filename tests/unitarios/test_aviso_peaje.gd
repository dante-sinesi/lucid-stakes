extends SceneTree
## El aviso del peaje de las mesas del casino: aparece (triángulo amarillo con exclamación, sin texto) cuando la apuesta que vas a hacer te dejaría por debajo del peaje de Farolín, y no cuando no.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_aviso_peaje.gd

const AvisoPeaje := preload("res://scripts/ui/aviso_peaje.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Roulette := preload("res://scripts/casino/roulette.gd")
const RouletteScreen := preload("res://scripts/casino/roulette_screen.gd")
const SlotsScreen := preload("res://scripts/casino/slots_screen.gd")
const BlackjackScreen := preload("res://scripts/casino/blackjack_screen.gd")
const Profile := preload("res://scripts/datos/profile.gd")

var fallos := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fallos += 1
		print("FAIL: ", label)


func _init() -> void:
	Profile.path = "user://test_profile.json"
	Profile.reset()
	# la regla
	check(AvisoPeaje.alerta(150, 60, 100), "con 150, apostando 60 con peaje de 100: te deja en 90, por debajo: avisa")
	check(not AvisoPeaje.alerta(300, 60, 100), "con 300 sigues por encima: no avisa")
	check(not AvisoPeaje.alerta(160, 60, 100), "con 160 quedas justo en 100: no avisa (el peaje se puede pagar)")
	check(AvisoPeaje.alerta(159, 60, 100), "con 159 quedas en 99: avisa")
	check(not AvisoPeaje.alerta(90, 60, 100), "si ya estás por debajo del peaje, no avisa")
	check(not AvisoPeaje.alerta(500, 60, 0), "sin peaje (tutorial, entrenamiento) nunca avisa")
	check(not AvisoPeaje.alerta(150, 0, 100), "una apuesta gratis no avisa")
	# el widget
	var a := AvisoPeaje.new()
	root.add_child(a)
	check(not a.visible, "empieza oculto")
	a.actualizar(150, 60, 100)
	check(a.visible, "se ve (es solo el triángulo: sin texto)")
	a.actualizar(500, 60, 100)
	check(not a.visible, "se oculta cuando ya no corresponde")
	check(a.get_child_count() == 0 and a.custom_minimum_size.x > 20.0, "es solo el triángulo de advertencia, sin textos")
	a.queue_free()
	# las tres mesas
	var run := RunState.new()
	run.stage = 1
	var ficha := Roulette.run_price(run)
	var giro := Roulette.spin_price(run)
	var peaje := 200
	run.claridad = peaje + giro - 1   # (el giro de la ruleta te deja a 1 del peaje)
	var rule := RouletteScreen.new()
	rule.peaje_fn = func(): return peaje
	root.add_child(rule)
	rule.setup(run, RandomNumberGenerator.new(), true)
	check(rule.aviso_peaje.visible, "ruleta: el giro te deja por debajo del peaje: avisa")
	run.claridad = peaje + giro + 1
	rule._refresh()
	check(not rule.aviso_peaje.visible, "ruleta: con un poco más de claridad ya no avisa")
	run.free_chip = true
	run.claridad = peaje + 1
	rule._refresh()
	check(not rule.aviso_peaje.visible, "ruleta: con Ficha gratis el giro no cuesta y no avisa")
	rule.queue_free()
	run.free_chip = false
	run.claridad = peaje + ficha - 1
	var slots := SlotsScreen.new()
	slots.peaje_fn = func(): return peaje
	root.add_child(slots)
	slots.setup(run, RandomNumberGenerator.new(), true)
	check(slots.aviso_peaje.visible, "tragamonedas: la tirada te deja por debajo del peaje: avisa")
	slots.queue_free()
	var bj := BlackjackScreen.new()
	bj.peaje_fn = func(): return peaje
	root.add_child(bj)
	bj.setup(run, RandomNumberGenerator.new(), true)
	check(bj.aviso_peaje.visible, "blackjack: la apuesta te deja por debajo del peaje: avisa")
	run.claridad = peaje + 1000
	bj._refresh()
	check(not bj.aviso_peaje.visible, "blackjack: con claridad de sobra no avisa")
	bj.queue_free()
	# la fianza de un contrato, la compra de la tienda y el cambio del Taller
	var ServiceScreens := load("res://scripts/casino/casino_service_screens.gd")
	var Contratos := load("res://scripts/datos/contratos.gd")
	var run2 := RunState.new()
	run2.stage = 6
	Contratos.entrar(run2, RandomNumberGenerator.new(), 2)
	var tab = ServiceScreens.make("tablon")
	tab.tier = 2
	tab.peaje_fn = func(): return peaje
	root.add_child(tab)
	var papel: Dictionary = Contratos.cartelera(run2)[0]
	var fianza: int = Contratos.fianza(papel, run2.stage)
	run2.claridad = peaje + fianza - 1
	tab.setup(run2, RandomNumberGenerator.new(), true)
	check(not tab.aviso_peaje.visible, "tablón: sin fianza no hay nada que gastar al aceptar: no avisa")
	tab.toggle_fianza()
	check(tab.aviso_peaje.visible, "tablón: aceptar con fianza te deja por debajo del peaje: avisa")
	run2.claridad = peaje + fianza + 50
	tab._refresh()
	check(not tab.aviso_peaje.visible, "tablón: con claridad de sobra la fianza no avisa")
	tab.queue_free()
	var shop = ServiceScreens.make("tienda")
	shop.peaje_fn = func(): return peaje
	root.add_child(shop)
	var run3 := RunState.new()
	run3.stage = 5
	run3.showcase = {"shop": ["aire_extra"], "sold": []}
	var Showcase := load("res://scripts/casino/showcase.gd")
	var precio: int = Showcase.shop_price(run3, load("res://scripts/datos/items.gd").get_item("aire_extra"))
	run3.claridad = peaje + precio - 1
	shop.setup(run3, RandomNumberGenerator.new(), true)
	shop.select("aire_extra")
	check(shop.aviso_peaje.visible, "tienda: la compra elegida te deja por debajo del peaje: avisa")
	shop.queue_free()
	# la ayuda explica el símbolo en cada juego donde se gasta claridad
	var Ayuda := load("res://scripts/ui/game_help.gd")
	for juego in ["ruleta", "tragamonedas", "blackjack", "taller", "tablon", "tienda"]:
		var con_simbolo := false
		for pagina in Ayuda.PAGES[juego]:
			if str(pagina.text).contains("{peaje}"):
				con_simbolo = true
		check(con_simbolo, "la ayuda de %s explica el símbolo del peaje" % juego)
	check(Ayuda.glyph_parts("peaje", false)[0].has("simbolo") and Ayuda.glyph_parts("peaje", true)[0].has("simbolo"), "{peaje} se dibuja como el triángulo, con teclado y con mando")
	# sin peaje (la mesa suelta, sin escena del casino) nada avisa
	run.claridad = 50
	var suelta := RouletteScreen.new()
	root.add_child(suelta)
	suelta.setup(run, RandomNumberGenerator.new(), true)
	check(not suelta.aviso_peaje.visible, "una mesa sin peaje no avisa")
	suelta.queue_free()
	await process_frame
	Profile.reset()
	print("tests del aviso del peaje terminados, fallos: ", fallos)
	quit(1 if fallos > 0 else 0)
