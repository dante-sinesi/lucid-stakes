extends SceneTree
## Cobertura de las traducciones (headless): (1) toda frase que el código pide con Loc.t / Loc.f está en la tabla inglesa y los textos
## fijos del catálogo también; (2) se recorren las pantallas en inglés y no queda ninguna frase sin traducir.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_loc.gd
## (Con LOC_PRINT=1 imprime las frases que faltan para completar la tabla.)

const Loc := preload("res://scripts/loc.gd")
const Settings := preload("res://scripts/settings.gd")
const RunState := preload("res://scripts/run_state.gd")
const Items := preload("res://scripts/items.gd")
const Abilities := preload("res://scripts/abilities.gd")
const Trials := preload("res://scripts/trials.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
const Cosmetics := preload("res://scripts/cosmetics.gd")
const Characters := preload("res://scripts/characters.gd")
const Roulette := preload("res://scripts/roulette.gd")
const Story := preload("res://scripts/story.gd")
const BlockGuide := preload("res://scripts/block_guide.gd")
const Tutorial := preload("res://scripts/tutorial.gd")
const RouletteScreen := preload("res://scripts/roulette_screen.gd")
const SlotsScreen := preload("res://scripts/slots_screen.gd")
const Controls := preload("res://scripts/controls.gd")
const CasinoRules := preload("res://scripts/casino_rules.gd")
const CasinoServices := preload("res://scripts/casino_services.gd")
const BlackjackScreen := preload("res://scripts/blackjack_screen.gd")

var fails := 0
var table: Dictionary


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	Settings.headless_io = false
	Loc.set_lang("en")
	table = Loc.table_for("en")
	test_catalog()
	test_source_calls()
	await test_screens()
	await test_in_game()
	Loc.set_lang("es")
	print("tests de las traducciones terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func need(text: String, what: String) -> void:
	check(table.has(text), "falta la traducción (%s): %s" % [what, text.replace("\n", "\\n")])


func test_catalog() -> void:
	for it in Items.ALL:
		need(it.name, "boost/consumible")
		need(it.desc, "descripción de " + it.name)
	for a in Abilities.ALL:
		need(a.name, "habilidad")
		need(a.desc, "descripción de " + a.name)
	for id in Trials.CATALOG:
		need(Trials.CATALOG[id].name, "prueba")
		need(Trials.CATALOG[id].desc, "descripción de " + id)
	for s in [Scenarios.TUTORIAL] + Scenarios.ALL:
		need(s.name, "escenario")
		need(s.desc, "descripción de " + s.name)
	for c in Cosmetics.ALL:
		need(c.name, "cosmético")
	for ch in Characters.ALL:
		need(ch.name, "personaje")
		need(ch.how, "cómo se desbloquea " + ch.id)
	for r in Cosmetics.RARITIES:
		need(Cosmetics.RARITIES[r].name, "rareza")
	for b in Roulette.BETS:
		need(Roulette.BETS[b].name, "apuesta")
	for l in Story.intro() + Story.outro():
		need(l if typeof(l) == TYPE_STRING else l.text, "historia")
	for id in Story.LESSONS:
		need(Story.LESSONS[id], "lección del tabernero")
	need(Story.BLOCKED_TABLE, "mesa bloqueada")
	for b in BlockGuide.ALL:
		need(b.name, "bloque de la guía")
		need(b.desc, "descripción del bloque " + b.id)
		need(b.say, "lo que dice el tabernero del bloque " + b.id)
	for l in Story.dice_intro():
		need(l if typeof(l) == TYPE_STRING else l.text, "dados del tabernero")
	for l in Tutorial.lessons():
		need(l.title, "título de lección")
		if l.help != "":
			need(l.help, "ayuda de lección " + l.id)
	need(Story.SPEAKER, "nombre del tabernero")
	for k in CasinoServices.INFO:
		need(CasinoServices.INFO[k].name, "servicio del casino")
		need(CasinoServices.INFO[k].desc, "descripción del servicio " + k)
	for g in CasinoRules.GAME_NAMES.values() + CasinoRules.ROOM_NAMES:
		need(g, "balance del casino")
	for r in CasinoRules.RULES:
		if str(r.id) == "":   # (la taberna no tiene regla)
			continue
		need(r.name, "regla de la casa")
		need(r.desc, "descripción de la regla " + r.id)
	for a in Controls.ACTIONS:
		need(a.name, "acción de controles")
		need(a.group, "grupo de controles")
	for b in Controls.BUTTON_NAMES.values() + Controls.AXIS_NAMES.values():
		if b.begins_with("Cruceta") or b.begins_with("Stick"):
			need(b, "botón del mando")


## Cada Loc.t("...") y Loc.f("...", ...) del código tiene su traducción.
func test_source_calls() -> void:
	var rx := RegEx.new()
	rx.compile("Loc\\.[tf]\\(\"((?:[^\"\\\\]|\\\\.)*)\"")
	var dir := DirAccess.open("res://scripts")
	var count := 0
	for f in dir.get_files():
		if not f.ends_with(".gd") or f.begins_with("loc"):
			continue
		var src := FileAccess.get_file_as_string("res://scripts/" + f)
		for m in rx.search_all(src):
			var key := m.get_string(1).replace("\\n", "\n").replace("\\\"", "\"").replace("\\\\", "\\")
			count += 1
			if Loc.has_words(key):
				need(key, "llamada en " + f)
	check(count > 40, "se encontraron las llamadas a Loc en el código (%d)" % count)


## Se abren las pantallas en inglés: ninguna etiqueta o botón puede quedar sin traducir.
func test_screens() -> void:
	Loc.missing.clear()
	var main = load("res://scenes/main.tscn").instantiate()
	main.quit_game_override = true
	root.add_child(main)
	await process_frame
	Loc.set_lang("en")
	main._rebuild_menus()
	await process_frame
	main.open_main_menu()
	main.main_menu.set_continue(5)
	for p in ["escenarios", "despertar", "cosmeticos", "opciones", "creditos", "licencias", "principal"]:
		main.main_menu.show_panel(p)
		await process_frame
	for id in [Scenarios.TUTORIAL.id] + Scenarios.ALL.map(func(s): return s.id):
		main.main_menu.scenarios.show_info(id)
	for a in Abilities.ALL:
		main.main_menu.meta.show_info(a.id)
	for r in [true, false]:
		var run := RunState.new()
		main.run_end.show_summary(run, r, "", 12, 30, ["Garras de hielo"])
	main.pause_menu.set_restart(2, false, false)
	main.pause_menu.open()
	main.pause_menu.show_options(true)
	main.dialogue.show_lines(Story.intro(), Story.SPEAKER, true)
	await process_frame
	# la ruleta y sus premios
	var run2 := RunState.new()
	run2.claridad = 500
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var rs := RouletteScreen.new()
	root.add_child(rs)
	rs.setup(run2, rng, true)
	await process_frame
	rs.open_prizes()
	rs.toggle_pocket(5)
	rs.spin()
	for i in 200:
		await process_frame
	# la tragamonedas y el blackjack
	var sl := SlotsScreen.new()
	root.add_child(sl)
	sl.setup(run2, rng, true)
	sl.spin()
	sl.toggle_hold(0)
	sl.respin()
	sl.spin()
	sl.collect()
	sl.game.reels.assign([4, 4, 4])
	sl._show_result(sl.game.collect() if sl.game.phase == 1 else {"kind": "triple", "symbol": 4, "claridad": 10, "item": {"name": "Madrugada"}, "converted": false, "spent": 50})
	sl._show_result({"kind": "none", "symbol": -1, "claridad": 0, "item": {}, "converted": false, "spent": 50})
	sl._show_result({"kind": "pair", "symbol": 1, "claridad": 20, "item": {}, "converted": false, "spent": 50})
	sl._show_result({"kind": "triple", "symbol": 1, "claridad": 20, "item": {}, "converted": false, "spent": 50})
	await process_frame
	var bj := BlackjackScreen.new()
	root.add_child(bj)
	bj.setup(run2, rng, true)
	for k in 6:
		await bj.deal()
		if bj.game.phase == 1:
			await bj.hit()
		if bj.game.phase == 1:
			await bj.stand()
	sl.queue_free()
	bj.queue_free()
	# el aviso de la torre
	main.dice.open(rng)
	await process_frame
	var missing: Array = Loc.missing.keys()
	if OS.get_environment("LOC_PRINT") != "":
		for m in missing:
			print("FALTA: ", str(m).replace("\n", "\\n"))
	check(missing.is_empty(), "las pantallas en inglés no dejan frases sin traducir (%d faltan)" % missing.size())
	main.queue_free()
	rs.queue_free()


## En juego (torre, prueba, casino, tutorial): los textos del HUD también salen traducidos.
func test_in_game() -> void:
	Loc.missing.clear()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	await process_frame
	Loc.set_lang("en")
	while main.generating or main.logic == null:
		await process_frame
	var tr: Dictionary = Trials.for_stage({6: "niebla"}, 6)
	main.trial = tr
	main._announce_trial()
	main._refresh()
	for id in Trials.CATALOG:
		main.trial = Trials.for_stage({6: id}, 6)
		main._announce_trial()
		main._refresh()
	main.trial = {}
	main._refresh()
	main.request_restart()
	await process_frame
	main.logic.try_action(Vector3i(1, 0, 0))
	main.logic.try_action(Vector3i(0, 0, 1), 1)
	main._flash(main.logic.perk_msg)
	main.pause_game()
	main.resume_game()
	main.enter_casino()
	await process_frame
	for i in 5:
		await process_frame
	main.leave_casino()
	await process_frame
	main.end_run(false, Loc.t("Abandonaste la partida."))
	await process_frame
	main.open_main_menu()
	main.start_tutorial()
	for i in 30:
		await process_frame
	main._cancel_jobs()
	var missing: Array = Loc.missing.keys()
	if OS.get_environment("LOC_PRINT") != "":
		for m in missing:
			print("FALTA (juego): ", str(m).replace("
", "\n"))
	check(missing.is_empty(), "el juego en inglés no deja frases sin traducir (%d faltan)" % missing.size())
	main.queue_free()
