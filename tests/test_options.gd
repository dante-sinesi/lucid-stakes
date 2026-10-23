extends SceneTree
## Pruebas de los idiomas, los ajustes y la pantalla de Opciones (headless).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_options.gd

const Loc := preload("res://scripts/loc.gd")
const Settings := preload("res://scripts/settings.gd")
const Graphics := preload("res://scripts/graphics.gd")
const Controls := preload("res://scripts/controls.gd")
const PadBridge := preload("res://scripts/pad_bridge.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func test_reading_mode() -> void:
	var VDraw = load("res://scripts/voxel_draw.gd")
	var OptionsScreen = load("res://scripts/options_screen.gd")
	var o: Control = OptionsScreen.new()
	root.add_child(o)
	o.visible = true
	await process_frame
	check(not Settings.reading_mode() and not VDraw.reading, "el modo de lectura viene apagado")
	o.reading_buttons.on.pressed.emit()
	check(Settings.reading_mode() and VDraw.reading and not VDraw.high_contrast and is_equal_approx(root.content_scale_factor, 1.0), "modo de lectura: letras claras, sin tocar el contraste ni el tamaño de la interfaz")
	o.contrast_buttons.on.pressed.emit()
	check(Settings.high_contrast() and VDraw.high_contrast and o.contrast_buttons.on.selected, "alto contraste se prende por separado")
	o.reading_buttons.off.pressed.emit()
	check(not VDraw.reading and VDraw.high_contrast and is_equal_approx(root.content_scale_factor, 1.0), "y cada uno se apaga sin el otro")
	o.reading_buttons.on.pressed.emit()
	check(o.reading_buttons.on.selected and not o.reading_buttons.off.selected, "el botón lo refleja")
	Settings.data.reading_mode = "x"
	Settings._sanitize()
	check(Settings.get_value("reading_mode") == false, "lo que no es un booleano se descarta")
	o.reset_button.pressed.emit()
	check(not Settings.reading_mode() and not VDraw.reading and not Settings.high_contrast() and not VDraw.high_contrast and is_equal_approx(root.content_scale_factor, 1.0), "Restablecer en General apaga los dos")
	o.queue_free()


func _init() -> void:
	test_loc()
	test_settings()
	test_graphics()
	test_controls()
	test_music_default()
	await test_tabs()
	await test_ui_scale()
	await test_reading_mode()
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
	check(Settings.get_value("fullscreen") and not o.res_next.disabled, "pantalla completa se guarda y deja elegir la resolución (la del render)")
	o.mode_buttons.window.pressed.emit()
	check(not Settings.get_value("fullscreen") and not o.res_next.disabled, "ventana también permite elegir resolución")
	o.res_next.pressed.emit()
	check(Settings.resolution() == Vector2i(1366, 768) and o.res_label.text == "1366 x 768", "la flecha cambia la resolución")
	o.res_prev.pressed.emit()
	check(Settings.resolution() == Vector2i(1280, 720), "y la otra la devuelve")
	for i in 6:
		o.res_prev.pressed.emit()
	check(Settings.resolution() == Vector2i(854, 480), "no pasa del primero (hay resoluciones menores a 1280 para equipos flojos)")
	o.res_next.pressed.emit()
	o.res_next.pressed.emit()
	o.res_next.pressed.emit()
	check(Settings.resolution() == Vector2i(1280, 720), "y se vuelve a subir de a una")
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
	var P := preload("res://scripts/profile.gd")
	P.path = "user://test_profile.json"   # (el perfil de prueba: con el tutorial ya hecho, si no el juego arranca en el tutorial)
	P._loaded_from = ""
	P.mark_tutorial_done()
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


func test_graphics() -> void:
	Graphics.reset()
	check(Graphics.preset() == "alta" and Graphics.value("shadows") == "soft", "por defecto la calidad es Alta")
	Graphics.set_preset("baja")
	check(Graphics.value("shadows") == "off" and Graphics.value("particles") == "none" and Graphics.value("scale") == 70 and Graphics.value("aa") == 0, "Baja: sin sombras, sin partículas, escala 70 % y sin suavizado")
	check(Graphics.block_particles_radius() < 0 and Graphics.particle_factor() == 0.0, "Baja apaga las partículas")
	Graphics.set_value("shadows", "hard")
	check(Graphics.preset() == "custom", "tocar un ajuste suelto pasa a Personalizada")
	Graphics.set_value("shadows", "off")
	check(Graphics.preset() == "baja", "si los valores vuelven a coincidir con un preajuste, se lo nombra")
	Graphics.cycle("scale", 1)
	check(Graphics.value("scale") == 80 and Graphics.preset() == "custom", "cycle avanza una opción")
	Graphics.set_value("scale", 12345)
	check(Graphics.value("scale") == 100, "un valor inválido vuelve al de fábrica")
	Graphics.reset()
	check(Graphics.preset() == "alta", "reset vuelve a lo de fábrica")


func test_controls() -> void:
	Controls.reset_all()
	check(Controls.key_of("mover_adelante") == KEY_W and Controls.key_of("empujar") == KEY_SHIFT, "las teclas de fábrica")
	var e := InputEventKey.new()
	e.keycode = KEY_W
	e.pressed = true
	check(Controls.action_of(e) == "mover_adelante", "una tecla se reconoce como su acción")
	var swapped := Controls.rebind_key("mover_adelante", KEY_UP)
	check(swapped == "camara_arriba" and Controls.key_of("camara_arriba") == KEY_W and Controls.key_of("mover_adelante") == KEY_UP, "reasignar a una tecla en uso intercambia las dos")
	check(Controls.rebind_key("reintentar", KEY_H) == "" and Controls.key_of("reintentar") == KEY_H, "reasignar a una tecla libre")
	var saved: Dictionary = Settings.get_value("bindings")
	check(saved.has("reintentar") and int(saved.reintentar.key) == KEY_H, "el cambio se guarda en los ajustes")
	Controls._loaded = false
	check(Controls.key_of("reintentar") == KEY_H, "y se vuelve a leer de los ajustes")
	check(Controls.pad_of("mover_adelante") == {"axis": Controls.AXIS_LY, "sign": -1} and Controls.pads_of("mover_adelante").size() == 2, "el mando de fábrica: stick y cruceta")
	var keys := Controls.keys_for_pad({"button": JOY_BUTTON_DPAD_UP})
	check(keys == [KEY_UP], "la cruceta arriba manda la tecla de Mover adelante (reasignada)")
	check(Controls.keys_for_pad({"button": JOY_BUTTON_A}) == [KEY_SPACE], "A confirma (Espacio)")
	check(Controls.rebind_pad("reintentar", {"button": JOY_BUTTON_A}) == "" and Controls.keys_for_pad({"button": JOY_BUTTON_A}) == [KEY_H], "reasignar un botón cambia la tecla que produce")
	Controls.reset_action("reintentar")
	check(Controls.key_of("reintentar") == KEY_R, "reset_action vuelve una sola acción a lo de fábrica")
	Controls.reset_all()
	check(Controls.key_of("mover_adelante") == KEY_W and (Settings.get_value("bindings") as Dictionary).is_empty(), "reset_all vuelve todo a lo de fábrica")


func test_music_default() -> void:
	check(int(Settings.defaults().music) == 8 and int(Settings.defaults().volume) == Settings.VOLUME_STEPS and int(Settings.defaults().sfx) == Settings.VOLUME_STEPS, "la música arranca al 80 % y el resto al 100 %")


func test_tabs() -> void:
	var OptionsScreen = load("res://scripts/options_screen.gd")
	var o: Control = OptionsScreen.new()
	root.add_child(o)
	o.visible = true
	await process_frame
	check(o.tab == "general" and o.pages.general.visible and not o.pages.graficos.visible and o.reset_button != null, "arranca en General")
	o.tab_buttons.graficos.pressed.emit()
	check(o.tab == "graficos" and o.pages.graficos.visible and not o.pages.general.visible, "las pestañas se alternan")
	check(o.pages.graficos is ScrollContainer, "Gráficos se puede desplazar")
	o.preset_buttons.baja.pressed.emit()
	check(Graphics.preset() == "baja" and o.preset_buttons.baja.selected and o.gfx_buttons.shadows["off"].selected, "elegir Baja la marca y mueve los ajustes sueltos")
	o.gfx_buttons.shadows["soft"].pressed.emit()
	check(o.preset_buttons.custom.selected and not o.preset_buttons.baja.selected, "tocar uno suelto marca Personalizada")
	o.reset_button.pressed.emit()
	check(Graphics.preset() == "alta" and o.preset_buttons.alta.selected, "Restablecer en Gráficos vuelve a Alta")
	o.tab_buttons.controles.pressed.emit()
	o.bind_buttons.reintentar.key.pressed.emit()
	check(o.capturing == "reintentar" and Controls.capturing, "apretar una tecla de la lista espera la nueva")
	var e := InputEventKey.new()
	e.keycode = KEY_J
	e.pressed = true
	o._input(e)
	check(o.capturing == "" and not Controls.capturing and Controls.key_of("reintentar") == KEY_J, "la tecla apretada se asigna")
	o.bind_buttons.reintentar.key.pressed.emit()
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	o._input(esc)
	check(o.capturing == "" and Controls.key_of("reintentar") == KEY_J, "Esc cancela sin cambiar nada")
	o.bind_buttons.mover_derecha.key.pressed.emit()
	var e2 := InputEventKey.new()
	e2.keycode = KEY_J
	e2.pressed = true
	o._input(e2)
	check(Controls.key_of("reintentar") == KEY_D and o.bind_message.text != "", "una tecla en uso se intercambia y se avisa")
	o.bind_buttons.empujar.pad.pressed.emit()
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	jb.pressed = true
	o._input(jb)
	check(Controls.pad_of("empujar") == {"button": JOY_BUTTON_RIGHT_SHOULDER}, "un botón del mando se asigna")
	o.reset_button.pressed.emit()
	check(Controls.key_of("reintentar") == KEY_R, "Restablecer en Controles vuelve a lo de fábrica")
	o.queue_free()


func test_ui_scale() -> void:
	var OptionsScreen = load("res://scripts/options_screen.gd")
	var o: Control = OptionsScreen.new()
	root.add_child(o)
	o.visible = true
	await process_frame
	check(Settings.get_value("ui_scale") == 100 and o.ui_label.text == "100%", "el tamaño de la interfaz es 100 % por defecto")
	o.ui_next.pressed.emit()
	check(Settings.get_value("ui_scale") == 110 and o.ui_label.text == "110%" and is_equal_approx(root.content_scale_factor, 1.1), "subir un paso: 110 % y se aplica a toda la interfaz")
	o.ui_next.pressed.emit()
	o.ui_next.pressed.emit()
	check(Settings.get_value("ui_scale") == 125 and o.ui_next.disabled, "tiene tope")
	for i in 6:
		o.ui_prev.pressed.emit()
	check(Settings.get_value("ui_scale") == 80 and o.ui_prev.disabled and is_equal_approx(root.content_scale_factor, 0.8), "y piso")
	o.reset_button.pressed.emit()
	check(Settings.get_value("ui_scale") == 100 and is_equal_approx(root.content_scale_factor, 1.0), "Restablecer en General vuelve a 100 %")
	var applies_before := Settings.window_applies
	o.ui_next.pressed.emit()
	check(Settings.window_applies == applies_before, "cambiar el tamaño de la interfaz no toca la ventana")
	Settings.data.ui_scale = 777
	Settings._sanitize()
	check(Settings.get_value("ui_scale") == 100, "un valor que no es una opción vuelve a 100 %")
	Settings.set_value("ui_scale", 100)
	o.queue_free()
