extends SceneTree
## Pruebas de los idiomas, los ajustes y la pantalla de Opciones (headless).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_options.gd

const Loc := preload("res://scripts/loc.gd")
const Settings := preload("res://scripts/settings.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	test_loc()
	test_settings()
	await test_screen()
	await test_menus_follow_language()
	Loc.set_lang("es")
	print("tests de opciones terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_loc() -> void:
	Loc.set_lang("es")
	check(Loc.t("Nueva partida") == "Nueva partida", "en español la frase queda igual")
	Loc.set_lang("en")
	check(Loc.t("Nueva partida") == "New game", "en inglés se traduce")
	check(Loc.t("Continuar (etapa %d)") % 3 == "Continue (stage 3)", "los patrones con números se traducen")
	Loc.missing.clear()
	check(Loc.t("frase que no existe") == "frase que no existe" and Loc.missing.has("frase que no existe"), "sin traducción se muestra en español y se anota")
	Loc.set_lang("xx")
	check(Loc.lang == "es", "un idioma desconocido vuelve al español")
	# Toda clave de la tabla inglesa conserva los marcadores % de su frase
	for k in Loc.table_for("en"):
		check(k.count("%d") == str(Loc.table_for("en")[k]).count("%d") and k.count("%s") == str(Loc.table_for("en")[k]).count("%s"), "la traducción conserva los marcadores de: " + k)


func test_settings() -> void:
	Settings.headless_io = true
	Settings.path = "user://test_settings.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Settings.load_settings()
	check(Settings.lang() == "es" and not Settings.get_value("fullscreen") and Settings.resolution() == Vector2i(1280, 720) and Settings.volume_linear() == 1.0, "valores por defecto")
	Settings.set_value("lang", "en")
	Settings.set_value("fullscreen", true)
	Settings.set_value("resolution", [1600, 900])
	Settings.set_value("volume", 4)
	Settings.set_value("vsync", false)
	check(Loc.lang == "en", "apply() pone el idioma")
	Settings.load_settings()
	check(Settings.lang() == "en" and Settings.get_value("fullscreen") and Settings.resolution() == Vector2i(1600, 900) and Settings.get_value("volume") == 4 and not Settings.get_value("vsync"), "los ajustes se guardan y se leen")
	Settings.set_value("volume", 99)
	check(Settings.get_value("volume") == Settings.VOLUME_STEPS, "el volumen se limita")
	Settings.set_value("resolution", [10, 10])
	check(Settings.resolution() == Vector2i(1280, 720), "una resolución absurda vuelve a la de siempre")
	check(Settings.available_resolutions().has(Vector2i(1920, 1080)), "se ofrecen resoluciones")
	# Cambiar el volumen, el idioma o la sincronia vertical no toca la ventana (si estaba maximizada, tiene que seguir asi)
	var before := Settings.window_applies
	Settings.set_value("volume", 3)
	Settings.set_value("music", 4)
	Settings.set_value("sfx", 5)
	Settings.set_value("vsync", true)
	Settings.set_value("lang", "en")
	check(Settings.window_applies == before, "el volumen, el idioma y la sincronia vertical no vuelven a poner la ventana en su tamaño")
	Settings.set_value("fullscreen", true)
	Settings.set_value("resolution", [1600, 900])
	check(Settings.window_applies == before + 2, "pantalla completa y resolucion si la tocan")
	Settings.set_value("lang", "es")
	Settings.set_value("fullscreen", false)
	Settings.set_value("resolution", [1280, 720])
	Settings.set_value("volume", Settings.VOLUME_STEPS)
	Settings.set_value("vsync", true)


func test_screen() -> void:
	var OptionsScreen = load("res://scripts/options_screen.gd")
	var o: Control = OptionsScreen.new()
	root.add_child(o)
	o.visible = true
	await process_frame
	var langs := [0]
	o.language_changed.connect(func(): langs[0] += 1)
	check(o.lang_buttons.es.selected and not o.lang_buttons.en.selected, "el idioma actual está marcado")
	o.lang_buttons.en.pressed.emit()
	check(Settings.lang() == "en" and langs[0] == 1, "elegir inglés lo guarda y avisa")
	o.lang_buttons.es.pressed.emit()
	check(Settings.lang() == "es" and langs[0] == 2, "y se puede volver al español")
	o.mode_buttons.fullscreen.pressed.emit()
	check(Settings.get_value("fullscreen") and o.res_prev.disabled and o.res_next.disabled, "pantalla completa se guarda y apaga la resolución")
	o.mode_buttons.window.pressed.emit()
	check(not Settings.get_value("fullscreen") and not o.res_next.disabled, "ventana vuelve a permitir elegir resolución")
	o.res_next.pressed.emit()
	check(Settings.resolution() == Vector2i(1366, 768) and o.res_label.text == "1366 x 768", "la flecha cambia la resolución")
	o.res_prev.pressed.emit()
	check(Settings.resolution() == Vector2i(1280, 720), "y la otra la devuelve")
	o.res_prev.pressed.emit()
	check(Settings.resolution() == Vector2i(1280, 720), "no pasa del primero")
	o.vol_minus.pressed.emit()
	o.vol_minus.pressed.emit()
	check(Settings.get_value("volume") == Settings.VOLUME_STEPS - 2 and o.vol_label.text == "80%", "el volumen baja de a un paso")
	o.vol_plus.pressed.emit()
	o.vol_plus.pressed.emit()
	o.vol_plus.pressed.emit()
	check(Settings.get_value("volume") == Settings.VOLUME_STEPS and o.vol_plus.disabled, "el volumen tiene tope")
	o.vsync_buttons.off.pressed.emit()
	check(not Settings.get_value("vsync"), "se apaga la sincronía vertical")
	o.vsync_buttons.on.pressed.emit()
	o.queue_free()


func test_menus_follow_language() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.quit_game_override = true
	root.add_child(main)
	await process_frame
	check(main.main_menu.buttons.has("opciones"), "el menú principal tiene Opciones")
	main.main_menu.buttons["opciones"].pressed.emit()
	check(main.main_menu.options.visible and not main.main_menu.main_center.visible, "Opciones abre la pantalla y esconde el menú")
	main.main_menu.options.lang_buttons.en.pressed.emit()
	await process_frame
	await process_frame
	check(Loc.lang == "en" and main.main_menu.options.visible, "al cambiar de idioma se vuelve a las opciones")
	check(main.main_menu.buttons["nueva"].text == "New game", "el menú reconstruido está en inglés")
	main.main_menu.options.back.emit()
	check(main.main_menu.main_center.visible and main.main_menu.buttons["salir"].text == "Quit", "Volver muestra el menú en inglés")
	main.main_menu.buttons["opciones"].pressed.emit()
	main.main_menu.options.lang_buttons.es.pressed.emit()
	await process_frame
	await process_frame
	check(main.main_menu.buttons["nueva"].text == "Nueva partida", "y de vuelta en español")
	main.queue_free()
