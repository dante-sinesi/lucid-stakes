extends Node3D
## La escena principal: el menú, el run (etapas, torre, casino, peaje), los menús de pausa y de fin, el tutorial y el guardado. La torre se juega en torre/torre_juego.gd.

const TorreJuego := preload("res://torre/torre_juego.gd")   # la torre (salas apiladas, sin núcleo): ver docs/reglas_torre.md
const Escena := preload("res://torre/escena.gd")
const BlockArt := preload("res://scripts/personajes/block_art.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Controls := preload("res://scripts/entrada/controls.gd")
const Graphics := preload("res://scripts/ui/graphics.gd")
const LivesHud := preload("res://scripts/ui/lives_hud.gd")
const HudPanel := preload("res://scripts/ui/hud_panel.gd")
const Stages := preload("res://scripts/datos/stages.gd")
const BlockGuide := preload("res://scripts/datos/block_guide.gd")
const Farolin := preload("res://scripts/personajes/farolin.gd")
const TrialBanner := preload("res://scripts/ui/trial_banner.gd")
const PanelInfo := preload("res://scripts/ui/panel_info.gd")
const PanelItems := preload("res://scripts/ui/panel_items.gd")
const Telemetry := preload("res://scripts/datos/telemetry.gd")
const Demo := preload("res://scripts/datos/demo.gd")
const DemoEndScreen := preload("res://scripts/ui/demo_end_screen.gd")
const KeyHint := preload("res://scripts/ui/key_hint.gd")
const FondoAnimado := preload("res://scripts/ui/fondo_animado.gd")
const KeyDirs := preload("res://scripts/entrada/key_dirs.gd")
const CasinoRules := preload("res://scripts/casino/casino_visit.gd")
const BalanceScreen := preload("res://scripts/casino/casino_balance_screen.gd")
const SenalPantalla := preload("res://scripts/ui/senal_pantalla.gd")
const ItemVuela := preload("res://scripts/ui/item_vuela.gd")
const ResumenClaridad := preload("res://scripts/ui/resumen_claridad.gd")
const VentanaLogro := preload("res://scripts/ui/ventana_logro.gd")
const Contratos := preload("res://scripts/datos/contratos.gd")
const ContratoResuelto := preload("res://scripts/ui/contrato_resuelto.gd")
const PadBridge := preload("res://scripts/entrada/pad_bridge.gd")
const CasinoScene := preload("res://scripts/casino/casino_scene.gd")
const MainMenu := preload("res://scripts/ui/main_menu.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const ConfirmBox := preload("res://scripts/ui/confirm_box.gd")
const DifficultyScreen := preload("res://scripts/ui/difficulty_screen.gd")
const Settings := preload("res://scripts/datos/settings.gd")
const Sfx := preload("res://scripts/sonido/sfx.gd")
const Music := preload("res://scripts/sonido/music.gd")
const AudioHub := preload("res://scripts/sonido/audio_hub.gd")
const LostScreen := preload("res://scripts/ui/lost_screen.gd")
const Loc := preload("res://scripts/idioma/loc.gd")
const Items := preload("res://scripts/datos/items.gd")
const VoxelLabel := preload("res://scripts/ui/voxel_label.gd")
const ItemBar := preload("res://scripts/ui/item_bar.gd")
const ConsumablePick := preload("res://scripts/entrada/consumable_pick.gd")
const ClarityCounter := preload("res://scripts/ui/clarity_counter.gd")
const Compass := preload("res://scripts/ui/compass.gd")
const Juice := preload("res://scripts/ui/juice.gd")
const Tutorial := preload("res://scripts/datos/tutorial.gd")
const Trials := preload("res://scripts/datos/trials.gd")
const CasinoEventos := preload("res://scripts/casino/casino_eventos.gd")
const Profile := preload("res://scripts/datos/profile.gd")
const Scenarios := preload("res://scripts/datos/scenarios.gd")
const Abilities := preload("res://scripts/datos/abilities.gd")
const DialogueBox := preload("res://scripts/ui/dialogue_box.gd")
const Story := preload("res://scripts/datos/story.gd")
const DiceGame := preload("res://scripts/casino/dice_game.gd")
const Cosmetics := preload("res://scripts/personajes/cosmetics.gd")
const Characters := preload("res://scripts/personajes/characters.gd")
const RunEndScreen := preload("res://scripts/ui/run_end_screen.gd")
const SaveGame := preload("res://scripts/datos/save_game.gd")
const DevCommands := preload("res://scripts/herramientas/dev_commands.gd")
const DevConsole := preload("res://scripts/herramientas/dev_console.gd")
const BlockModels := preload("res://scripts/personajes/block_models.gd")
## Cámara:
## La cámara se mueve con el mouse (arrastrar: girar y inclinar; rueda: zoom). Q y E vuelven al ángulo isométrico (girando 90 grados).
const PITCH_NORMAL := -35.264   # ángulo isométrico
## Ayudas de profundidad (Opciones): 0 ninguna, 1 atenuación, 2 atenuación + transparencia cercana.
const DEPTH_STRENGTH := 0.11
const XRAY_RADIUS := 1.3
const FINAL_STAGE := Stages.FINAL   # etapas del juego: al pasar la última se termina
## Fondo y bloques se aclaran de una etapa a la siguiente (no dentro de una misma etapa).
const BG_DARK := Color(0.25, 0.22, 0.40)   # (la etapa 1: un violeta medio, para que la obsidiana oscura de los bloques corruptos se recorte contra el fondo)
const BG_LIGHT := Color(0.09, 0.07, 0.17)   # (de la etapa 4 en adelante: oscuro, porque los bloques se van aclarando (la piedra pasa a lavanda) y tienen que seguir recortándose; el nombre es histórico)
const AMBIENT_TOWER := 0.7        # luz ambiente de las torres
const AMBIENT_CASINO_EARLY := 1.0  # luz ambiente del casino en la primera etapa (una taberna en penumbra, pero que se lee)
const AMBIENT_CASINO_LATE := 1.5   # luz ambiente del casino en la última etapa (el salón; el casino y el gran casino usan la luz cálida de abajo)
const AMBIENT_COLOR_TOWER := Color(0.55, 0.55, 0.7)
const CASINO_BG_WARM := Color(0.055, 0.048, 0.045)
const CASINO_AMBIENT_WARM := 1.0
const CASINO_SUN_WARM := 0.6
## Generación al jugar: búsqueda más liviana que la completa (tarda menos; las etapas difíciles se generan fuera de línea).

var generating := false
var toll_in_tests := false   # las pruebas no cobran el peaje de Farolín salvo que se pida
var goal_mat: ShaderMaterial   # el material del portal de salida (apagado hasta que alcance para el peaje)
var cam: Camera3D
var seed_value := 1
var stage_number := 1      # etapa (1..15) que se genera: define la dificultad, el largo de la torre y las mecánicas
var hud: Control              # texto de depuración (semilla, contadores...): sólo se ve con F2 en las compilaciones de desarrollo
var debug_hud := false
var stage_label: Control     # "Etapa 5/27" y el piso en que estás
var hud_panel               # la ventana de la partida: corazones, etapa, claridad y racha
var banner: Control
var senal: Control          # las señales sin texto (rebobinar, cancelado, candado)
var resumen_claridad: Control   # la ventana del resumen de claridad (al entrar al casino y antes de la torre)
var ventana_logro: Control      # la ventana de un logro (personaje nuevo)
var ultimo_ingreso_torre := 0   # lo que dio la última torre superada (para el resumen de claridad)
var ingreso_dados := 0          # la claridad que dieron los dados de esa visita
var _gain_tween: Tween     # el desvanecer del cartel de ganancia (uno solo a la vez)
var gain_label: Control
var depth_mode := 1
var run := RunState.new()   # estado del run: claridad, boosts, consumibles
var casino                  # escena del casino mientras se está en él
var torre = null            # la escena de la torre mientras se juega una
var _movs_vistos := 0       # movimientos de la sala que ya se sumaron al run
var hud_layer: CanvasLayer
var quick_portal := false   # pruebas: pasar al casino sin esperar
var banked := false         # la claridad de esta torre ya se sumó al run
var quit_game_override := false  # pruebas: quit_game no cierra el proceso
var test_mode := false      # pruebas: sin menú, torres chicas y sin generar la etapa siguiente de antemano
var in_menu := false
var main_menu
var pause_menu
var difficulty_screen   # selector de dificultad de La Pesadilla
var confirm_box   # cuadro de confirmación (abandonar la partida, empezar otra sobre una sin terminar)
var menu_layer: CanvasLayer
var env: Environment
var training := false       # tutorial: lecciones sueltas, sin casino ni claridad en juego, y reintento gratis
var trial := {}              # prueba (etapa especial) de la torre actual: {} si es una etapa común (ver trials.gd)
var run_new_abilities: Array[String] = []   # habilidades persistentes ganadas en este run (se muestran al terminar)
var trial_banner: Control   # el cartel de la prueba (abajo, letras grandes sin fondo): ver trial_banner.gd
var _trial_msg := ""         # resultado de la prueba superada (se muestra al llegar al portal)
var lost_screen              # pantalla de derrota: Reintentar o Salir al menú
var contrato_pantalla         # la pantalla de un contrato resuelto (contrato_resuelto.gd)
var _contratos_cola: Array = []   # contratos resueltos que esperan su pantalla
var dice_always := true      # los dados del tabernero se ven en toda pantalla de carga, aunque la torre ya esté lista (las pruebas lo apagan)
var lives_hud                # las tres vidas (corazones 3D que giran, abajo a la derecha)
var casino_balance := true   # al salir del casino se ve el balance (las pruebas lo apagan: salir pasa directo a la torre)
var balance_layer: CanvasLayer   # donde vive el balance mientras se ve
var farolin_reacts := true   # Farolín dice una frase después de cada decisión del peaje (las pruebas la apagan)
var tutorial_forced := false   # primera vez: el tutorial no se puede dejar (la pausa no vuelve al menú principal)
var tutorial_index := -1    # lección del tutorial en curso (-1 = no se está en el tutorial)
var dice                      # los dados del tabernero: el minijuego de la pantalla de carga
var _sun: DirectionalLight3D
var fondo                   # el fondo con movimiento suave (fondo_animado.gd)
var dialogue                 # cuadro de diálogo del tabernero (historia y consejos del tutorial)
const TUTORIAL_TOLL := 25   # lo que cuesta el peaje de práctica del final del tutorial
var _outro_phase := 0       # el cierre del tutorial: 0 el tabernero habla, 1 se camina hasta Farolín, 2 Farolín contesta y se termina
var story_kind := ""         # "intro" o "outro" mientras se está en una sala de historia del tutorial
var tutorial_label: Control # cartel con la lección
var block_discovery := true   # al llegar a la fila de un bloque nuevo, el tabernero lo explica (las pruebas lo apagan)
var _dice_intro_pending := false   # tutorial: al abrirse los dados, el tabernero explica el juego
var _dice_talk := false
var _leaving_casino := false   # se le pagó a Farolín y se está yendo del casino: si se cierra el juego ahora, se continúa en la pantalla de carga (no hay que volver a pagar)
var _dados_en_casino := false     # los dados del tabernero están en pantalla al entrar al casino (no se guarda ni se vuelve a entrar mientras tanto)
var _toll_options: Array = []   # las salidas que ofrece Farolín en la puerta (ver Farolin.toll_dialog)
var _keeper_talk := false   # el tabernero del casino está hablando (cuadro de diálogo)
var key_hint                # las teclas de la lección arriba al centro: grises hasta que se aprietan (ver key_hint.gd)
var pista_hint              # el modo pista de Fácil: el próximo movimiento arriba al centro, con sus teclas (el mismo dibujo que key_hint)
var _pista_on := false      # el modo pista sigue encendido de una torre a la siguiente
var perk_label: Control
var juice                # animaciones de sensación de juego (estirar, polvo, temblor, destellos)
var compass              # rosa de los vientos (qué eje mueve cada tecla)
var clarity_counter       # [ícono] claridad (la del run más la juntada en esta torre)
var dev_console           # consola del modo dev (sólo en compilaciones de desarrollo; null en las release)
var console_open := false
var panel_items: Control     # el panel de boosts y consumibles (B), por la derecha
var panel_info: Control      # el panel de información (Tab): la partida contada por la izquierda
var run_end             # pantalla de fin de run
var demo_end            # pantalla de fin de la demo (demo_end_screen.gd)
var run_over := false
var attempt_dirty := false  # el intento actual de la torre ya empezó (hubo un movimiento o se usó un consumible)
var left_bar              # barra de consumibles (izquierda)
var consumable_pick := ConsumablePick.new()   # elegir y usar consumibles con el mando (mantener RT y arriba o abajo)
var right_bar             # barra de boosts (derecha)
var item_tip: Control     # descripción del ítem bajo el mouse
var epoch := 0              # sube al volver al menú: las generaciones en curso se descartan
var _attempt_t0 := 0   # cuándo empezó el intento actual de la torre (para la telemetría)


func _ready() -> void:
	if Demo.on():   # la demo tiene su propia carpeta de guardado (no pisa la del juego completo) y su título
		DirAccess.make_dir_recursive_absolute(Demo.save_dir())
		SaveGame.path = Demo.save_dir() + "/save.json"
		Profile.path = Demo.save_dir() + "/profile.json"
		Profile._loaded_from = ""
		if DisplayServer.get_name() != "headless":
			DisplayServer.window_set_title(Demo.TITLE)
	# Las pruebas (y las capturas hechas con GAME_SANDBOX=1) no tocan la partida, el perfil ni los ajustes reales del jugador.
	if test_mode or DisplayServer.get_name() == "headless" or OS.get_environment("GAME_SANDBOX") == "1":
		SaveGame.path = "user://test_save.json"
		Profile.path = "user://test_profile.json"
		Settings.path = "user://test_settings.json"
		Telemetry.path = "user://test_telemetria.jsonl"
		Profile._loaded_from = ""
		Settings._loaded = false
	if test_mode:
		casino_balance = false
		dice_always = false
		block_discovery = false
	Settings.apply()   # idioma, ventana, resolución y volumen del jugador
	for par in [["ui_up", KEY_W], ["ui_down", KEY_S], ["ui_left", KEY_A], ["ui_right", KEY_D]]:   # (en los menús también se navega con WASD)
		var ev := InputEventKey.new()
		ev.keycode = par[1] as Key
		if not InputMap.action_has_event(par[0], ev):
			InputMap.action_add_event(par[0], ev)
	AudioHub.instance()   # el audio (efectos y música) se prepara desde el arranque
	_register_globals()
	var pad_bridge := PadBridge.new()   # el mando se traduce a las teclas de cada acción
	pad_bridge.nav_mode = func() -> bool:
		return in_menu or get_tree().paused or (resumen_claridad != null and resumen_claridad.visible) or (ventana_logro != null and ventana_logro.visible) or (dice != null and dice.visible) or (casino != null and casino.screen != null) or (lost_screen != null and lost_screen.visible) or (dialogue != null and dialogue.is_active()) or (confirm_box != null and confirm_box.is_open()) or (difficulty_screen != null and difficulty_screen.is_open())
	pad_bridge.process_mode = Node.PROCESS_MODE_ALWAYS   # (el mando tiene que seguir andando con el juego en pausa: si no, el menú de pausa no responde)
	add_child(pad_bridge)
	add_to_group("graphics")
	_set_depth_mode(int(Settings.get_value("ayuda_profundidad")))
	_build_environment()
	_build_hud()
	_build_menus()
	Graphics.apply_global()   # sombras, escala de render, antialiasing y tope de cuadros del jugador
	_build_dev_console()
	if test_mode:
		SaveGame.path = "user://test_save.json"   # las pruebas no tocan la partida real
		Profile.path = "user://test_profile.json"   # ni el perfil
		stage_number = 6
		new_tower(randi() % 100000)
	elif not Profile.tutorial_done():   # la primera vez que se abre el juego: el tutorial empieza solo, en la taberna, y no se puede saltear
		tutorial_forced = true
		start_tutorial()
	else:
		open_main_menu()


## Dónde está la cámara de la torre, según su derecha y su arriba (el fondo mueve sus capas con paralaje); cero si no hay torre.
func _camara_para_fondo() -> Vector2:
	if torre == null or torre.pivot == null or torre.cam == null:
		return Vector2.ZERO
	var b: Basis = torre.cam.global_transform.basis
	return Vector2(torre.pivot.position.dot(b.x), torre.pivot.position.dot(b.y))


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.04, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.7)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	fondo = FondoAnimado.new(env)
	fondo.camara_fn = _camara_para_fondo
	add_child(fondo)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	add_child(sun)
	_sun = sun
	cam = Camera3D.new()   # la cámara de fondo: queda activa en el menú y cuando se vuelve del casino; la torre y el casino traen la suya
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 17.0
	cam.far = 200.0
	cam.position = Vector3(0, 0, 40)
	add_child(cam)
	cam.make_current()


## Pone en marcha los gráficos del jugador en lo que es de esta escena (grupo "graphics"; ver graphics.gd).
func apply_graphics() -> void:
	if env != null:   # modo de lectura: la escena con más contraste y color
		var contrast: bool = Settings.high_contrast()
		env.adjustment_enabled = contrast
		env.adjustment_contrast = 1.22
		env.adjustment_saturation = 1.12
		env.adjustment_brightness = 1.05
	if _sun != null:
		Graphics.apply_to_sun(_sun)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	hud_layer = layer
	add_child(layer)
	var story_layer := CanvasLayer.new()   # el cuadro de diálogo va por encima de todo (incluso del casino y los menús)
	story_layer.layer = 30
	add_child(story_layer)
	dialogue = DialogueBox.new()
	dialogue.finished.connect(_on_dialogue_finished)
	dialogue.chosen.connect(_on_dialogue_chosen)
	story_layer.add_child(dialogue)
	var dice_layer := CanvasLayer.new()   # la pantalla de carga con los dados va por encima del juego
	dice_layer.layer = 25
	add_child(dice_layer)
	dice = DiceGame.new()
	dice.fast = test_mode   # (en las pruebas el tiro se resuelve al instante y no se espera el botón Empezar)
	dice.auto_start = test_mode
	dice.prize.connect(_on_dice_prize)
	dice_layer.add_child(dice)
	var lost_layer := CanvasLayer.new()   # la pantalla de derrota va sobre el juego y debajo de los menús
	lost_layer.layer = 35
	add_child(lost_layer)
	lost_screen = LostScreen.new()
	lost_screen.fast = test_mode
	lost_screen.retry.connect(request_restart)
	lost_screen.menu.connect(open_main_menu)
	lost_layer.add_child(lost_screen)
	contrato_pantalla = ContratoResuelto.new()
	contrato_pantalla.terminado.connect(_contrato_siguiente)
	contrato_pantalla.terminado.connect(func(): if casino != null: casino.input_locked = false)
	lost_layer.add_child(contrato_pantalla)
	juice = Juice.new(self)
	juice.attach_flash(layer)
	# La ventana de la partida (arriba a la izquierda): corazones, etapa y claridad (y la racha cuando hay). Lo demás lo cuenta el tabernero.
	hud_panel = HudPanel.new(true)
	layer.add_child(hud_panel)
	lives_hud = hud_panel.lives
	stage_label = hud_panel.stage_label
	clarity_counter = hud_panel.clarity
	var panel_layer := CanvasLayer.new()   # el panel de información (Tab) va sobre el HUD y debajo de los menús
	panel_layer.layer = 20
	add_child(panel_layer)
	panel_info = PanelInfo.new()
	panel_layer.add_child(panel_info)
	panel_items = PanelItems.new()
	panel_layer.add_child(panel_items)
	var banner_layer := CanvasLayer.new()   # el cartel de la prueba va por encima de los menús (y se va al pausar)
	banner_layer.layer = 105
	add_child(banner_layer)
	trial_banner = TrialBanner.new()
	banner_layer.add_child(trial_banner)
	# Texto de depuración: oculto salvo que se prenda con F2 (sólo existe en compilaciones de desarrollo).
	hud = _label(layer, 2, Color(0.95, 0.93, 0.88))
	hud.localize = false   # (texto de depuración: siempre en español)
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud.position += Vector2(16, -110)
	hud.plate_alpha = 0.55
	hud.visible = false
	compass = Compass.new()
	compass.name = "rosa_vientos"
	compass.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	compass.position = Vector2(-Compass.SPAN - 16, 10)
	compass.size = Vector2(Compass.SPAN, Compass.SPAN)
	compass.view_source = func(): return Vector2(torre.pivot.rotation_degrees.y, torre.pitch_node.rotation_degrees.x) if torre != null and torre.pivot != null else Vector2(45, PITCH_NORMAL)
	compass.dir_source = _dir_for_screen
	layer.add_child(compass)
	tutorial_label = _label(layer, 2.5, Color(1.0, 0.97, 0.85))
	tutorial_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_label.align = VoxelLabel.Align.CENTER
	tutorial_label.wrap_px = 900
	tutorial_label.y_offset = 14.0
	tutorial_label.plate_alpha = 0.7
	tutorial_label.visible = false
	key_hint = KeyHint.new()
	layer.add_child(key_hint)
	pista_hint = KeyHint.new()
	pista_hint.name = "pista"
	pista_hint.offset_top = 6.0   # (más arriba que la ayuda del tutorial: el cartel de claridad sale justo debajo)
	pista_hint.offset_bottom = 6.0 + KeyHint.KEY_H + 36.0
	layer.add_child(pista_hint)
	banner = _label(layer, 5, Color(1.0, 0.95, 0.8))
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.align = VoxelLabel.Align.CENTER
	banner.vcenter = true
	banner.plate_alpha = 0.6
	item_tip = _label(layer, 2, Color(0.95, 0.93, 0.88))
	item_tip.wrap_px = 460
	item_tip.plate_alpha = 0.85
	item_tip.visible = false
	left_bar = ItemBar.new()
	left_bar.name = "barra_consumibles"
	layer.add_child(left_bar)
	left_bar.edge = 0
	left_bar.bottom = true   # los consumibles van abajo a la izquierda
	left_bar.tip = item_tip
	left_bar.slot_pressed.connect(use_consumable_slot)
	left_bar.discarded.connect(_on_item_discarded)
	right_bar = ItemBar.new()
	right_bar.name = "barra_boosts"
	layer.add_child(right_bar)
	right_bar.edge = 1
	right_bar.discarded.connect(_on_item_discarded)
	right_bar.tip = item_tip
	_bind_bars()
	perk_label = _label(layer, 2, Color(0.8, 0.95, 0.85))
	perk_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	perk_label.align = VoxelLabel.Align.RIGHT
	perk_label.y_offset = 104.0
	perk_label.margin = 120.0 + Compass.SPAN
	perk_label.plate_alpha = 0.55
	senal = SenalPantalla.new()
	layer.add_child(senal)
	var capa_ventanas := CanvasLayer.new()
	capa_ventanas.layer = 55
	add_child(capa_ventanas)
	resumen_claridad = ResumenClaridad.new()
	capa_ventanas.add_child(resumen_claridad)
	ventana_logro = VentanaLogro.new()
	capa_ventanas.add_child(ventana_logro)
	gain_label = _label(layer, 3, Color(1.0, 0.93, 0.5))
	gain_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gain_label.align = VoxelLabel.Align.CENTER
	gain_label.y_offset = 100.0
	gain_label.modulate.a = 0.0


## Texto de cubitos para la interfaz de juego: `cube` es el lado de un cubito en píxeles.
func _label(parent: Node, cube: float, color: Color) -> Control:
	var l := VoxelLabel.new()
	l.cube = cube
	l.color = color
	parent.add_child(l)
	return l


## La música de la torre de una etapa: el Invierno de Vivaldi en las pruebas y el Verano en las torres comunes.
func _tower_music(stage: int) -> String:
	return "pruebas" if not training and run != null and not run.trial_at(stage).is_empty() else "torre"


## Arma y empieza la torre de la etapa (o la vuelve a empezar con la misma semilla).
func _torre_arrancar(s: int, con_dados := false) -> void:
	if lost_screen != null:
		lost_screen.hide_screen()
	_torre_cerrar(false)
	seed_value = s
	# Los dados del tabernero solo se juegan aquí en el tutorial (donde el tabernero los explica); en una partida salen al entrar al casino (`_dados_del_tabernero`).
	if con_dados and dice_always and tutorial_index >= 0 and not in_menu:
		var mi_epoca := epoch
		generating = true
		dice.claridad_actual = run.claridad if run != null else 0
		dice.open()
		_maybe_dice_intro()
		dice.set_ready(true)
		while dice.visible:
			await get_tree().process_frame
		generating = false
		if mi_epoca != epoch or in_menu or run_over:
			return
	trial = run.trial_at(stage_number) if not training else {}
	run.stage = stage_number
	run.max_stage = maxi(run.max_stage, stage_number)
	if not training:
		var unlocked: Array = Profile.on_stage_reached(stage_number)   # la etapa 10 desbloquea al conejito
		if not unlocked.is_empty():
			_mostrar_logro(unlocked)
			Sfx.play("item")
	if con_dados:   # (una torre nueva: los reintentos de la anterior no cuentan; al rehacer la misma torre sí)
		run.tower_retries = 0
		run.claridad_inicio_torre = run.claridad   # (con esto cobran la Caja fuerte y la Alcancía al entrar al casino)
	Music.play(_tower_music(stage_number))
	_apply_stage_look()   # (el fondo y la luz se aclaran con la etapa)
	generating = false
	banked = false
	attempt_dirty = false
	_movs_vistos = 0
	_attempt_t0 = Time.get_ticks_msec()
	var perks: Array = run.boosts.duplicate()   # los boosts del run y las habilidades persistentes valen en cada torre
	perks.append_array(Abilities.perks_for(Profile.owned_abilities()))
	if trial.get("no_streak", false):
		perks.append("sin_racha")
	torre = TorreJuego.new()
	torre.en_juego = true
	torre.semilla = s
	torre.etapa = stage_number
	torre.boosts = perks
	torre.dificultad = run.dificultad_torre()   # (Gran Casino: un escalón más difícil)
	var reglas: Dictionary = run.scenario().duplicate()   # (las del escenario y, en la prueba Travesuras, la de Ama)
	if trial.get("travesuras", false):
		reglas["travesuras"] = true
	reglas.merge(trial.get("reglas", {}), true)   # (las reglas de la prueba: Mareo, Terremoto, Presupuesto compartido... ver trials.gd)
	torre.reglas = reglas
	torre.pista_permitida = run.dificultad == "facil" and tutorial_index < 0 and not training
	torre.pista_activa = _pista_on and torre.pista_permitida
	torre.pista_cambiada.connect(_torre_pista)
	torre.mov_run = run.movs_extra   # (Pies ligeros y la mejora Aire de más: movimientos de más en cada sala)
	var permitidos := 0   # El camino corto: movimientos en falso por sala
	if not training:
		permitidos = int(run.scenario().get("mistakes", 0))
		if permitidos > 0 and Profile.has_ability("margen_de_error"):
			permitidos += 1
	torre.falsos_permitidos = permitidos
	torre.sala_inicial = _continuar_sala
	torre.banco_inicial = _continuar_banco
	_continuar_sala = 0
	_continuar_banco = 0
	if tutorial_index >= 0:
		var leccion: Dictionary = Tutorial.lessons()[tutorial_index]
		if leccion.has("generated"):
			torre.n_salas_fijo = int(leccion.generated)   # (la última lección es una torre chica de verdad)
		else:
			torre.salas_fijas = [Tutorial.sala(tutorial_index)]   # (las demás son una sala armada a mano)
		torre.zoom = float(leccion.zoom)
	torre.vidas_fn = func(): return run.lives
	torre.puede_jugar = func(): return not in_menu and not generating and casino == null and not console_open and not get_tree().paused and (dialogue == null or not dialogue.is_active()) and (lost_screen == null or not lost_screen.visible) and (contrato_pantalla == null or not contrato_pantalla.visible)
	torre.position = Vector3(-1000, 0, 0)   # lejos de todo lo demás (el casino y el menú no ven la torre)
	torre.contrato_evento.connect(func(evento: String, datos: Dictionary): _contratos_registrar(evento, datos))
	torre.checkpoint_alcanzado.connect(_torre_checkpoint)
	torre.torre_completa.connect(_torre_ganada)
	torre.murio.connect(_torre_murio)
	torre.accion_hecha.connect(_torre_accion)
	torre.falsos_cambiaron.connect(_torre_falsos)
	torre.rechazo.connect(_on_rechazo_torre)
	torre.aliento.connect(_on_aliento_torre)
	torre.ganancia.connect(_flash_gain)
	torre.portal = _cubo_portal()
	torre.deshacer_pedido.connect(undo_move)
	torre.movimiento_hecho.connect(_tutorial_movimiento)
	torre.camara_usada.connect(_tutorial_camara)
	torre.reintentar_pedido.connect(request_restart)
	add_child(torre)
	if not training and tutorial_index < 0:   # los contratos activos empiezan su seguimiento en esta torre (los que no se pueden cumplir en ella se anulan)
		for p in Contratos.empezar_torre(run, Contratos.capacidad_de(torre.t)):   # (el papel se anula con su sello, como cuando se cancela: la fianza vuelve)
			_contratos_cola.append({"papel": p, "cumplido": false, "monto": int(p.get("fianza", 0)), "cancelado": true})
		_contratos_mostrar()
	hud_layer.visible = true
	banner.text = ""
	if permitidos == 0:
		hud_panel.set_mistakes(0, 0)
	_refresh()
	save_game()
	_announce_trial()
	_descubrir_bloques()


## El cubo-portal del final de la torre (de minibloques, con las ondas animadas en los costados; sus colores combinan con la etapa), siempre encendido (Farolín cobra en el casino).
func _cubo_portal() -> Node3D:
	var g := Escena.cubo_portal(BlockArt.nivel_de_etapa(maxi(stage_number, 1)))
	goal_mat = g.get_node("ondas").material_override
	return g


## Saca la escena de la torre (y, si se pide, devuelve la cámara del juego).
func _torre_cerrar(devolver_camara: bool) -> void:
	if pista_hint != null:
		pista_hint.clear()
	if torre != null:
		if torre.pista_permitida:
			_pista_on = torre.pista_activa
		torre.queue_free()
		torre = null
	if devolver_camara and cam != null:
		cam.make_current()


## La pista del modo Fácil: la frase con las teclas arriba ("" la saca).
func _torre_pista(texto: String) -> void:
	if texto == "":
		pista_hint.clear()
	else:
		pista_hint.show_help(texto, "")


func _torre_accion() -> void:
	_contratos_mostrar()   # (los contratos que se cumplieron con esta acción)
	if torre == null:   # (la última acción ganó la torre y la escena ya se sacó)
		return
	if not attempt_dirty:   # el primer movimiento del intento: el guardado ya lo marca como empezado
		attempt_dirty = true
		save_game()
	if torre.t != null:   # (el "Movimientos" del resumen del run: sólo suman los movimientos nuevos, no lo que vuelve al deshacer o al empezar otra sala)
		if torre.t.movs > _movs_vistos:
			run.moves += torre.t.movs - _movs_vistos
		_movs_vistos = torre.t.movs
	_refresh()


## El camino corto: lo que quedan de movimientos en falso en la sala (y el aviso si acaba de pasar uno).
func _torre_falsos(quedan: int, permitidos: int, sin_salida: bool, hubo_falso: bool) -> void:
	if torre == null:
		return
	hud_panel.set_mistakes(quedan, permitidos)
	if hubo_falso and quedan >= 0 and permitidos - quedan <= permitidos:
		var cuenta: int = permitidos - quedan
		if cuenta <= permitidos and cuenta > 0:
			Sfx.play("miss")
			juice.flash(Color(0.8, 0.1, 0.15), 0.18, 0.4)


## La telemetría de la torre (local, nada se envía): un evento "sala" por cada sala que termina (superada o perdida) y uno "torre" por intento.
func _log_sala() -> void:
	if training or tutorial_index >= 0 or torre == null or torre.t == null or torre.t.ultima_sala.is_empty():
		return
	var d: Dictionary = torre.t.ultima_sala.duplicate()
	d["stage"] = stage_number
	d["lives"] = run.lives
	d["dificultad"] = run.dificultad
	Telemetry.log_event("sala", d)


func _log_torre(resultado: String, causa: String) -> void:
	if training or tutorial_index >= 0 or torre == null or torre.t == null:
		return
	Telemetry.log_event("torre", {"stage": stage_number, "outcome": resultado, "seconds": int((Time.get_ticks_msec() - _attempt_t0) / 1000), "moves": torre.t.movs_total,
			"claridad": torre.t.cosecha.claridad(), "retries": run.tower_retries, "lives": run.lives, "cause": causa, "dificultad": run.dificultad, "sala": torre.t.indice + 1, "salas": torre.t.salas.size()})


func _torre_checkpoint(faltan: int, total: int) -> void:
	Sfx.play("item")
	if torre == null:
		return
	_log_sala()
	_refresh()
	_descubrir_bloques()


## Descubrimiento de bloques: al entrar a una sala con un tipo de bloque que todavía no conoces, el juego frena y el tabernero lo explica (queda anotado en el perfil).
func _descubrir_bloques() -> void:
	if not block_discovery or training or tutorial_index >= 0 or casino != null or in_menu or torre == null or torre.t == null or generating or dialogue.is_active():
		return
	var letras: Array = []
	for c in torre.t.motor.bloques:
		letras.append(torre.t.motor.bloques[c])
	var found := BlockGuide.newly_in_room(letras)
	if found.is_empty():
		return
	var lines: Array = []
	for b in found:
		Profile.discover_block(str(b.id))
		lines.append(b.say)
	dialogue.show_lines(lines, Story.SPEAKER, true, true)   # (el cuadro es bloqueante: el jugador no se mueve hasta que termina)


## Un contrato resuelto (cumplido o fallido): se cobra en el acto y se pone en la cola de pantallas, que aparecen cuando termina la acción en curso.
func _contratos_registrar(evento: String, datos: Dictionary) -> void:
	if run == null or training or tutorial_index >= 0:
		return
	for res in Contratos.registrar(run, evento, datos):
		_contratos_cola.append(res)


## Muestra la pantalla de los contratos que esperan (de a uno). En las pruebas no se muestra nada.
func _contratos_mostrar() -> void:
	if _contratos_cola.is_empty() or contrato_pantalla == null or contrato_pantalla.visible:
		return
	if test_mode:
		_contratos_cola.clear()
		return
	var res: Dictionary = _contratos_cola.pop_front()
	var p: Dictionary = res.papel
	if casino != null:
		casino.input_locked = true   # (en el casino no se camina ni se interactúa mientras se ve el sello)
	var condiciones: Array = [Contratos.condicion(p)]
	if int(p.fianza) > 0:
		condiciones.append(Loc.f("Con fianza de %d", [int(p.fianza)]))
	contrato_pantalla.mostrar({"objetivo": str(Contratos.OBJETIVOS[p.obj].icono), "rareza": int(p.r), "titulo": Contratos.titulo(p), "condiciones": condiciones}, bool(res.cumplido), int(res.monto), bool(res.get("cancelado", false)))
	_refresh()
	save_game()


func _contrato_siguiente() -> void:
	_contratos_mostrar()


## Espera a que se vean todos los contratos resueltos (antes de seguir con lo que sigue en la torre).
func _contratos_esperar() -> void:
	_contratos_mostrar()
	while not test_mode and contrato_pantalla != null and (contrato_pantalla.visible or not _contratos_cola.is_empty()):
		await get_tree().process_frame
		_contratos_mostrar()


## Llegó al portal de la torre: la claridad pasa al run y sigue el casino (o el final).
func _torre_ganada() -> void:
	_log_sala()
	_log_torre("ganada", "")
	if not training and tutorial_index < 0:   # los contratos de "al terminar la torre" se resuelven ahora
		_contratos_registrar("torre", {})
		await _contratos_esperar()
		if torre == null or in_menu:
			return
	if training:   # (el tutorial: se festeja y pasa solo a la siguiente lección)
		if tutorial_index >= 0:
			if tutorial_locked():   # llegaste, pero te faltan las teclas de la lección: no se pasa
				_senal_rechazo()   # (las teclas que faltan siguen grises arriba)
				await get_tree().create_timer(1.2).timeout
				if tutorial_index >= 0 and torre != null:
					restart()   # (las teclas ya doradas se quedan así)
				return
			var idx := tutorial_index
			banner.text = "¡Terminaste el tutorial!" if idx + 1 >= Tutorial.count() else "¡Bien!"
			if not quick_portal:
				await get_tree().create_timer(1.3).timeout
			if tutorial_index == idx and torre != null:
				_torre_cerrar(true)
				await _tutorial_next()
			return
		return
	_bank_claridad()
	banner.text = "¡Portal alcanzado!" + ("\n" + _trial_msg if _trial_msg != "" else "")
	if not quick_portal:
		await get_tree().create_timer(1.5).timeout   # (el personaje se mete en el portal)
	if torre == null or in_menu:
		return
	_torre_cerrar(true)
	if stage_number >= FINAL_STAGE:
		banner.text = "¡Escapaste de la pesadilla!"
		if not quick_portal:
			await get_tree().create_timer(2.5).timeout
		if not in_menu:
			end_run(true)
		return
	enter_casino()


## Se perdió una vida en la torre (la sala ya volvió a empezar): se descuenta la del run, o se termina si no quedaba ninguna.
func _torre_murio(motivo: String) -> void:
	_contratos_registrar("vida", {})
	_log_sala()
	_log_torre("muerta", motivo)
	if training:   # (tutorial: no hay vidas; la sala vuelve a empezar sola después de la caída)
		var previo_t: float = torre.animar_derrota(motivo)
		Sfx.play("lose")
		await get_tree().create_timer(previo_t + 2.4).timeout
		if torre != null:
			torre.reiniciar_sala()
		return
	if trial.get("no_retry", false) or not run.can_revive():   # (el run termina: antes se ve caer al personaje y se dice por qué murió)
		var razon: String = Loc.f("Fallaste la prueba «%s»: %s.", [Loc.t(trial.name), Loc.t(motivo).to_lower()]) if trial.get("no_retry", false) else (Loc.t("Moriste: en este escenario no hay segundas oportunidades.") if run.permadeath() else Loc.t("Te quedaste sin vidas."))
		var previo: float = torre.animar_derrota(motivo)
		juice.flash(Color(0.8, 0.1, 0.15), 0.4, 0.6)
		Sfx.play("lose")
		var mi_epoca := epoch
		await get_tree().create_timer(previo + 3.2 if not test_mode else 0.1).timeout
		if mi_epoca == epoch and not in_menu and not run_over:
			end_run(false, razon)
		return
	# se cae, y aparece la pantalla de derrota (Reintentar -1 vida o salir al menú)
	var previo: float = torre.animar_derrota(motivo)
	var mi_epoca := epoch
	if previo > 0.0 and not test_mode:   # primero se ve el movimiento que hizo perder; recién después sigue la caída y la pantalla de derrota
		await get_tree().create_timer(previo).timeout
		if mi_epoca != epoch or torre == null or torre.t == null or not torre.t.muerta:
			return
	juice.flash(Color(0.8, 0.1, 0.15), 0.4, 0.6)
	Sfx.play("lose")
	var libre: bool = run.consumables.has("totem") and not run.item_blocked("totem")   # (con un Tótem el reintento no cuesta la vida)
	lost_screen.show_loss(Loc.t(motivo), run.restart_cost(true), run.can_afford(run.restart_cost(true)), libre, true, maxi(run.lives - 1, 0))
	save_game()


## Premio de un tiro de los dados de la pantalla de carga: claridad (un porcentaje de la que tienes, con un mínimo), Luz y, a veces, un cosmético (con la rareza que permite la dificultad).
## Completa `info` con lo que de verdad se dio (`granted`, `cosmetic_name`) para que el minijuego lo muestre.
func _on_dice_prize(info: Dictionary) -> void:
	var granted := 0
	var want := DiceGame.claridad_para(int(info.get("hits", 0)), run.claridad if run != null else 0)
	if want > 0 and run != null:
		granted = want
		run.gain(granted)
	info["granted"] = granted
	if int(info.get("luz", 0)) > 0 and run != null:
		run.dice_pending.luz = int(run.dice_pending.luz) + int(info.luz)
	var weights: Dictionary = info.get("cosmetic", {})
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if not weights.is_empty() and rng.randf() < float(info.get("cosmetic_chance", 1.0)):   # el cosmético sale con la rareza que toca (y que todavía no tengas)
		var have: Array[String] = Profile.owned_cosmetics()
		if run != null:
			for pid in run.dice_pending.cosmetics:
				have.append(str(pid))
		var c := Cosmetics.roll_por_dificultad(run.dificultad if run != null else "media", have, rng)   # (la dificultad decide qué rarezas pueden salir; Fácil no da ninguna)
		if c.is_empty():   # ya los tiene todos: claridad grande en su lugar
			if run != null:
				run.gain(100)
			info["granted"] = int(info.get("granted", 0)) + 100
		else:
			if run != null:
				run.dice_pending.cosmetics.append(str(c.id))
			info["cosmetic_name"] = c.name
			info["cosmetic_rarity"] = c.rarity
			info["cosmetic_id"] = c.id
			info["cosmetic_slot"] = c.slot
	save_game()


## Lo que dieron los dados (Luz y cosméticos) pasa al perfil: se llama al superar una torre (entrar al casino), al terminar el tutorial y al terminar un run en el que se superó alguna.
func _claim_dice_rewards() -> void:
	if run == null or training:
		return
	var luz := int(run.dice_pending.luz)
	if luz > 0:
		Profile.add_luz(luz)
	for id in run.dice_pending.cosmetics:
		Profile.grant_cosmetic(str(id))
	run.dice_pending = {"luz": 0, "cosmetics": []}


## Empieza la torre de la etapa (con los dados del tabernero mientras se arma). Las torres se arman al momento con el paquete de salas: no hay nada que generar de antemano.
func new_tower(s: int) -> void:
	if generating:
		return
	await _torre_arrancar(s, true)


## Vuelve a empezar la torre desde la primera sala, con la misma semilla.
func restart() -> void:
	_torre_arrancar(seed_value)


var _continuar_sala := 0    # (al continuar una partida guardada en la torre: el checkpoint donde se quedó)
var _continuar_banco := 0


## 0 en la primera etapa y 1 en la última: cuánto se aclararon el fondo y los bloques.
func stage_tone() -> float:
	return clampf(float(stage_number - 1) / float(FINAL_STAGE - 1), 0.0, 1.0)


## El color del fondo de la etapa: de un violeta medio (etapa 1) a uno oscuro (a partir de la 7), en sentido contrario a los bloques, que se aclaran.
func _fondo_de_etapa() -> Color:
	return BG_DARK.lerp(BG_LIGHT, smoothstep(0.0, 0.43, stage_tone()))


func _apply_stage_look() -> void:
	env.background_color = _fondo_de_etapa()
	env.ambient_light_energy = AMBIENT_TOWER
	env.ambient_light_color = AMBIENT_COLOR_TOWER   # (el casino de nivel alto usa una luz más cálida: se restablece al volver a la torre)
	if _sun != null:
		_sun.light_energy = 1.0


## El casino se ilumina más a medida que avanza el run (sucio y en penumbra al principio, de mármol luminoso al final).
func _apply_casino_light() -> void:
	var tier: int = int(casino.lay.tier) if casino != null and not casino.lay.is_empty() else 0
	if tier >= 2:   # casino y gran casino: mármol cálido con luz contenida (si no, los claros se queman y se pierden los detalles)
		env.background_color = CASINO_BG_WARM if tier == 2 else CASINO_BG_WARM.darkened(0.1)
		env.ambient_light_energy = CASINO_AMBIENT_WARM
		env.ambient_light_color = Color(0.95, 0.9, 0.85)
		if _sun != null:
			_sun.light_energy = CASINO_SUN_WARM
		return
	env.background_color = _fondo_de_etapa()
	env.ambient_light_energy = lerpf(AMBIENT_CASINO_EARLY, AMBIENT_CASINO_LATE, stage_tone())
	env.ambient_light_color = AMBIENT_COLOR_TOWER
	if _sun != null:
		_sun.light_energy = 1.0


## El cubo de salida: un cubo claro y luminoso con bordes dorados y, en los cuatro costados, las ondas del portal (como las puertas del casino).
func _flash_gain(text: String, gain := 0) -> void:
	var w := gain_weight(gain)
	gain_label.cube = 3.0 + 3.0 * w   # (una ganancia grande se ve más grande, dura más y suena más fuerte)
	gain_label.color = Color(1.0, 0.93, 0.5).lerp(Color(1.0, 0.62, 0.2), w)
	gain_label.text = text
	gain_label.modulate.a = 1.0
	juice.pop(gain_label, 1.35 + 0.6 * w)
	if w > 0.4:
		juice.add_shake(0.1 + 0.35 * w)
	if gain >= 1000:
		Sfx.play("item", 0.9 + 0.5 * w, -4.0)
	if _gain_tween != null:   # (un solo desvanecer a la vez: si quedaban los de las ganancias anteriores pisaban la transparencia y el cartel no volvía a verse)
		_gain_tween.kill()
	_gain_tween = create_tween()
	_gain_tween.tween_interval(0.3 + 1.2 * w)
	_gain_tween.tween_property(gain_label, "modulate:a", 0.0, 1.8 + 1.0 * w)


## Qué tan "pesada" es una ganancia de claridad, de 0 (10 o menos) a 1 (10 millones o más), en escala logarítmica.
static func gain_weight(gain: int) -> float:
	if gain <= 10:
		return 0.0
	return clampf((log(float(gain)) / log(10.0) - 1.0) / 6.0, 0.0, 1.0)


static var _globals_registered := false  # los parámetros globales se registran una sola vez por proceso


func _register_globals() -> void:
	if _globals_registered:
		return
	_globals_registered = true
	Engine.set_meta("globales_de_bloques", true)   # (room_view.gd, que usa la torre, no los registra otra vez)
	for spec in [["depth_focus", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
			["depth_strength", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, DEPTH_STRENGTH],
			["xray_radius", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
			["focus_view", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO]]:
		RenderingServer.global_shader_parameter_add(spec[0], spec[1], spec[2])


func _set_depth_mode(mode: int) -> void:
	depth_mode = mode
	RenderingServer.global_shader_parameter_set("depth_strength", 0.0 if mode == 0 else DEPTH_STRENGTH)
	RenderingServer.global_shader_parameter_set("xray_radius", XRAY_RADIUS if mode == 2 else 0.0)


## Cada cuadro: dónde está el personaje respecto de la cámara (referencia de las ayudas de profundidad).
func _process(delta: float) -> void:
	juice.process(delta)
	_panel_vigilar()
	if torre == null or torre.cam == null or torre.gato_nodo == null:
		return
	var v: Vector3 = torre.cam.global_transform.affine_inverse() * torre.gato_nodo.global_position
	RenderingServer.global_shader_parameter_set("depth_focus", -v.z)
	RenderingServer.global_shader_parameter_set("focus_view", v)


## Traduce una diagonal de pantalla (sx derecha, sy arriba) a la dirección de grilla más cercana.
func _dir_for_screen(sx: float, sy: float) -> Vector3i:
	var d := KeyDirs.dir_for(torre.yaw_target if torre != null else 45.0, sx, sy)   # ver key_dirs.gd: W es la dirección que más sube en la pantalla
	return Vector3i(d.x, 0, d.y)


## Al empezar una prueba se anuncia su regla unos segundos.
func _announce_trial() -> void:
	_play_trial_banner()


## El cartel de la prueba al empezar (o rehacer) la torre: grande abajo, se queda unos segundos y se desvanece lento. Sin prueba, no hay cartel.
func _play_trial_banner() -> void:
	if trial_banner == null:
		return
	if trial.is_empty() or training or tutorial_index >= 0 or torre == null or in_menu or casino != null:
		trial_banner.clear()
		return
	trial_banner.play(Loc.t(trial.name), Loc.t(trial.desc))


## Un consumible no se puede usar ahora: su casillero tiembla con el símbolo de cancelado en rojo (sin texto).
func _rechazar_item(slot: int) -> void:
	if left_bar != null:
		left_bar.rechazar(slot)
	Sfx.play("miss", 0.8, -4.0)


## Un ítem que se usó: su ícono sale de su casillero de la barra (`barra`: la de consumibles o la de boosts), vuela al medio y se deshace en luz (sin texto).
func _item_vuela(id: String, barra, idx: int) -> void:
	if barra != null and idx >= 0:
		ItemVuela.volar(hud_layer, id, barra.rect_de(idx))


## Algo que no se puede hacer ahora y no tiene un casillero donde mostrarlo: el símbolo de cancelado en el medio (sin texto).
func _senal_rechazo() -> void:
	senal.mostrar(SenalPantalla.Tipo.RECHAZO)
	Sfx.play("miss", 0.8, -4.0)


## La torre rechazó un movimiento: siempre un sonido bajito; y si es por una regla que no se ve (Solo tres bloques, una fila de más de tres), el símbolo de cancelado sobre el personaje.
func _on_rechazo_torre(msg: String) -> void:
	Sfx.play("miss", 0.7, -8.0)
	if (msg == "Ya moviste todos los bloques que se pueden mover" or msg == "Demasiados bloques") and torre != null and torre.cam != null and torre.gato_nodo != null:
		senal.mostrar(SenalPantalla.Tipo.RECHAZO, torre.cam.unproject_position(torre.gato_nodo.global_position + Vector3(0, 1.3, 0)))


## El Segundo aliento salvó la sala: su ícono sale de la barra de boosts y se deshace en luz.
func _on_aliento_torre() -> void:
	if run != null:
		_item_vuela("segundo_aliento", right_bar, run.boosts.find("segundo_aliento"))


## El HUD con la torre: la etapa, la claridad del run más la de la torre, lo que cobrará Farolín, las vidas y las barras de boosts y consumibles.
func _refresh_torre() -> void:
	stage_label.text = Loc.f("Etapa %d/%d%s", [stage_number, Demo.shown_final(FINAL_STAGE), " *" if not trial.is_empty() else ""])
	stage_label.visible = false   # (la etapa y el peaje se ven en el menú de pausa; el HUD muestra los movimientos de la sala)
	hud.text = "Semilla %d   Sala %d/%d   Movimientos %d/%d   Dificultad %s" % [seed_value, torre.t.indice + 1, torre.t.salas.size(), torre.t.movs, torre.t.max_mov(), run.dificultad] if torre.t != null else ""
	var total: int = run.claridad + (torre.t.cosecha.claridad() if torre.t != null and not banked else 0)   # (ya sumada al run al llegar al portal: no se cuenta dos veces)
	var show_toll: bool = not training and tutorial_index < 0 and not (test_mode and not toll_in_tests)
	var next_toll: int = run.toll_after_discounts(RunState.toll_for(stage_number)) if show_toll else 0
	hud_panel.set_toll(0)
	if total > clarity_counter.value:
		juice.pop(clarity_counter, 1.25)
	clarity_counter.value = total
	_update_perk_label()
	if panel_info != null and panel_info.abierto:
		panel_info.actualizar(_panel_datos())
	if panel_items != null and panel_items.abierto:
		panel_items.actualizar(_panel_items_datos())
	clarity_counter.visible = false   # (el total de claridad se lee en el panel de información; el HUD de la torre sólo lleva las vidas, los consumibles y los boosts)


func _refresh() -> void:
	if lives_hud != null and run != null:
		lives_hud.max_lives = run.max_lives()
		lives_hud.lives = run.lives
		lives_hud.visible = not training
	if torre != null:
		_refresh_torre()


## La claridad que se juntó en la torre pasa al run (una sola vez por torre).
func _bank_claridad() -> void:
	if banked:
		return
	banked = true
	run.stage = stage_number
	run.towers_cleared += 1
	var cl: int = torre.t.cosecha.claridad() if torre != null and torre.t != null else 0
	var gained := int(round(cl * float(trial.get("mult", 1.0))))
	run.claridad_earned += gained
	ultimo_ingreso_torre = gained
	run.gain(gained)
	_trial_msg = ""
	if not trial.is_empty() and not training:
		run.trials_cleared += 1
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var rw := Trials.reward(trial, stage_number, run, rng)
		if not rw.item.is_empty():
			run.take(rw.item)
		else:
			run.gain(int(rw.claridad))
		_trial_msg = Loc.f("¡Prueba superada!   +%d de claridad extra\n%s", [gained - cl, rw.text])
		var new_chars: Array = Profile.on_trial_cleared()   # superar una prueba puede desbloquear personajes
		if not new_chars.is_empty():
			_trial_msg = Loc.join([_trial_msg, _character_msg(new_chars)])
			Sfx.play("item")


## El panel de información (docs/panel_informacion.md): se abre al apretar su tecla (Tab; Select en el mando) y, según Opciones, se ve mientras se mantiene apretada o hasta un nuevo toque.
func _input(event: InputEvent) -> void:
	if panel_info == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if _panel_abierto() and _panel_tecla(event):
		get_viewport().set_input_as_handled()
		return
	if Controls.action_of(event) != "panel_info":
		return
	if not _panel_permitido():
		return
	get_viewport().set_input_as_handled()   # (Tab no mueve el foco de nadie)
	if panel_info.abierto and str(Settings.get_value("panel_modo")) == "alternar":
		_menu = []
		panel_info.cerrar()
		panel_items.cerrar()
	else:
		panel_info.abrir(_panel_datos())   # (Tab abre los dos: el de la partida por la izquierda y el de boosts y consumibles por la derecha)
		panel_items.abrir(_panel_items_datos())
		_foco_iniciar()


## ¿Se puede ver el panel ahora? En la torre y en el sala del casino, sin menús, pausa, diálogos ni pantallas de juego encima.
func _panel_permitido() -> bool:
	if run == null or in_menu or console_open or generating or get_tree().paused:
		return false
	if dialogue != null and dialogue.visible:
		return false
	if casino != null:
		return casino.screen == null
	return torre != null and not run_over


## Lo que cuenta el panel de información ahora (ver `PanelInfo`).
func _panel_datos() -> Dictionary:
	var d := {}
	if run == null:
		return d
	d["titulo"] = Loc.t("Tutorial") if tutorial_index >= 0 else _titulo_pausa()
	d["etapa"] = Loc.f("Etapa %d/%d", [stage_number, Demo.shown_final(FINAL_STAGE)])
	var en_torre: bool = torre != null and casino == null and torre.t != null
	var de_la_torre := 0
	if en_torre:
		d["sala"] = Loc.f("Sala %d/%d", [torre.t.indice + 1, torre.t.salas.size()])
		de_la_torre = torre.t.cosecha.claridad() if not banked else 0   # (ya sumada al run al llegar al portal: no se cuenta dos veces)
		d["movs"] = torre.t.movs
		d["max_movs"] = torre.t.max_mov()
		if torre.t.presupuesto_total > 0:   # (Presupuesto compartido: un solo fondo para toda la torre)
			d["fondo"] = true
			d["movs"] = torre.t.gastado_antes + torre.t.movs
			d["max_movs"] = torre.t.presupuesto_total + torre.t.mov_extra + torre.t.mov_run
		if torre.t.motor.limite_movibles >= 0:   # (Solo tres bloques)
			d["movibles"] = {"usados": torre.t.motor.movidos.size(), "limite": torre.t.motor.limite_movibles}
		d["sin_limite"] = torre.t.max_mov() >= 99999
		if torre.falsos != null and torre.falsos_permitidos > 0:
			d["falsos"] = {"quedan": torre.falsos.quedan(), "permitidos": torre.falsos_permitidos}
	d["claridad"] = run.claridad + de_la_torre
	d["claridad_torre"] = de_la_torre
	var cobra: bool = not training and tutorial_index < 0 and not (test_mode and not toll_in_tests)
	var precio := 0
	if casino != null:
		precio = casino.toll_now() if cobra and casino.toll_base > 0 else 0
	elif cobra:
		precio = run.toll_after_discounts(RunState.toll_for(stage_number))
	if precio > 0:
		d["peaje"] = {"precio": precio, "alcanza": int(d.claridad) >= precio}
	if en_torre and not trial.is_empty() and not training:
		d["prueba"] = {"nombre": Loc.t(trial.name), "desc": Loc.t(trial.desc)}
	elif not training and tutorial_index < 0:
		d["proxima_prueba"] = run.next_trial_text(stage_number + 1)
	if not training and tutorial_index < 0:
		d["contratos"] = Contratos.para_pausa(run)
	return d


## El cursor de los paneles: `_foco` es el panel (0 contratos, a la izquierda; 1 boosts y consumibles, a la derecha) y `_foco_i` la fila. Con Espacio se abre el menú de la fila (`_menu`: lo que se puede
## hacer con ella, con "Volver" marcado de entrada y lo que gasta o quita al final) como botones junto al panel; se elige con W y S, se confirma con Espacio y se vuelve con "Volver", Esc o Shift.
var _foco := 1
var _foco_i := 0
var _menu: Array = []     # ids de las opciones del menú abierto: "usar", "tirar", "abandonar", "volver"
var _menu_i := 0


func _foco_panel(z: int) -> Control:
	return panel_info if z == 0 else panel_items


func _foco_iniciar() -> void:
	_menu = []
	_foco = 1 if panel_items.filas() > 0 else 0
	_foco_i = 0
	_foco_pintar()


## Pone el marco en la fila elegida (y el menú, si está abierto); el otro panel queda sin cursor.
func _foco_pintar() -> void:
	var n: int = _foco_panel(_foco).filas()
	_foco_i = clampi(_foco_i, 0, maxi(n - 1, 0))
	_foco_panel(1 - _foco).poner_opciones([])
	_foco_panel(1 - _foco).poner_seleccion(-1)
	_foco_panel(_foco).poner_seleccion(_foco_i if n > 0 else -1)
	_foco_panel(_foco).poner_opciones(_menu_textos() if not _menu.is_empty() else [], _menu_i)


func _menu_textos() -> Array:
	var out: Array = []
	for id in _menu:
		match id:
			"usar": out.append(Loc.t("Usar"))
			"tirar": out.append(Loc.t("Tirar"))
			"volver": out.append(Loc.t("Volver"))
			"abandonar":
				var p: Dictionary = Contratos.activos(run)[_foco_i]
				if casino != null:
					out.append(Loc.t("Cancelar (se devuelve la fianza)") if int(p.fianza) > 0 else Loc.t("Cancelar"))
				else:
					out.append(Loc.t("Abandonar (pierdes la fianza)") if int(p.fianza) > 0 else Loc.t("Abandonar"))
	return out


## Una tecla con un panel abierto: navegar (W y S suben y bajan, A y D pasan de un panel al otro), Espacio abre el menú o elige, Shift lo cierra. Devuelve true si la atendió.
func _panel_tecla(event: InputEvent) -> bool:
	var accion: String = Controls.action_of(event)
	var k: int = (event as InputEventKey).keycode
	var enter: bool = k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER
	if not _menu.is_empty():
		if accion == "mover_adelante":
			_menu_i = maxi(_menu_i - 1, 0)
		elif accion == "mover_atras":
			_menu_i = mini(_menu_i + 1, _menu.size() - 1)
		elif enter:
			_menu_elegir(str(_menu[_menu_i]))
			return true
		elif k == KEY_SHIFT or k == KEY_ESCAPE:
			_menu = []
		else:
			return k != KEY_TAB
		_foco_pintar()
		return true
	if accion == "mover_adelante" or accion == "mover_atras":
		_foco_i += -1 if accion == "mover_adelante" else 1
		_foco_pintar()
		return true
	if accion == "mover_izquierda" or accion == "mover_derecha":
		var z := 1 if accion == "mover_derecha" else 0
		if z != _foco and _foco_panel(z).filas() > 0:
			_foco = z
			_foco_i = 0
			_foco_pintar()
		return true
	if enter:
		_menu_abrir()
		return true
	return false


## Abre el menú de la fila elegida: un consumible se usa o se tira; un boost se tira; un contrato se abandona.
func _menu_abrir() -> void:
	if _foco_panel(_foco).filas() == 0:
		return
	if _foco == 0:
		_menu = ["volver", "abandonar"]
	elif _foco_i < run.boosts.size():
		_menu = ["volver", "tirar"]
	else:
		_menu = ["volver", "usar", "tirar"]
	_menu_i = 0
	_foco_pintar()


func _menu_elegir(id: String) -> void:
	_menu = []
	var en_items := _foco == 1
	var es_boost: bool = en_items and _foco_i < run.boosts.size()
	var idx: int = _foco_i if _foco == 0 or es_boost else _foco_i - run.boosts.size()
	match id:
		"tirar":
			var tipo := "boost" if es_boost else "consumable"
			var err: String = run.discard_error(tipo, idx)
			if err != "":
				Sfx.play("miss", 0.8, -4.0)
			else:
				var tirado: String = run.discard(tipo, idx)
				if casino != null:
					casino._on_item_discarded(ItemBar.Kind.BOOST if es_boost else ItemBar.Kind.CONSUMABLE, tirado)
					save_game()
				else:
					_on_item_discarded(ItemBar.Kind.BOOST if es_boost else ItemBar.Kind.CONSUMABLE, tirado)
		"usar":
			_panel_cerrar_todo()
			if casino != null:
				casino.use_consumable_slot(idx)
			else:
				use_consumable_slot(idx)
			return
		"abandonar":
			_panel_cerrar_todo()
			if casino != null:
				var papel: Dictionary = Contratos.activos(run)[idx]
				var r: Dictionary = Contratos.cancelar(run, idx)
				if bool(r.ok):
					_contratos_cola.append({"papel": papel, "cumplido": false, "monto": int(r.devuelto), "cancelado": true})   # (el sello de CANCELADO, como el de los contratos resueltos)
					_contratos_mostrar()
				else:
					Sfx.play("miss", 0.8, -4.0)
				save_game()
			else:
				var res: Dictionary = Contratos.abandonar(run, idx)
				if not res.is_empty():
					_contratos_cola.append(res)
					_contratos_mostrar()
			return
	panel_info.actualizar(_panel_datos())
	panel_items.actualizar(_panel_items_datos())
	_foco_pintar()


func _panel_cerrar_todo() -> void:
	_menu = []
	panel_info.cerrar()
	panel_items.cerrar()


## Lo que cuenta el panel de boosts y consumibles ahora (ver `PanelItems`).
func _panel_items_datos() -> Dictionary:
	var d := {"boosts": [], "consumibles": [], "max_boosts": 0, "max_consumibles": 0}
	if run == null:
		return d
	for par in [["boosts", run.boosts], ["consumibles", run.consumables]]:
		for id in par[1]:
			var it: Dictionary = Items.get_item(str(id))
			d[par[0]].append({"id": str(id), "nombre": Loc.t(str(it.get("name", id))), "desc": Loc.t(str(it.get("desc", "")))})
	d["max_boosts"] = run.boost_capacity()
	d["max_consumibles"] = run.consumable_capacity()
	return d


## ¿Hay un panel de información abierto? Entonces la torre no se juega (sólo se mueve la cámara).
func _panel_abierto() -> bool:
	return (panel_info != null and panel_info.abierto) or (panel_items != null and panel_items.abierto)


## Si un panel está abierto: se cierra cuando ya no se puede ver o, en modo "mantener", cuando se suelta su tecla; y se refresca lo que cuenta.
func _panel_vigilar() -> void:
	if panel_info == null:
		return
	if torre != null:
		torre.solo_camara = _panel_abierto()
	if not _panel_abierto():
		return
	if not _panel_permitido():
		panel_info.cerrar(true)
		panel_items.cerrar(true)
	elif str(Settings.get_value("panel_modo")) == "mantener" and not Controls.held("panel_info") and _menu.is_empty():
		panel_info.cerrar()
		panel_items.cerrar()


## Teclas del juego fuera de la torre (la torre maneja sus movimientos y su cámara): la pausa, la consola de desarrollo y los consumibles con el mando.
func _unhandled_input(event: InputEvent) -> void:
	if dev_console != null and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		dev_console.toggle()   # F1: consola del modo dev
		return
	if dev_console != null and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		debug_hud = not debug_hud   # F2: textos de depuración (semilla, contadores); sólo en compilaciones de desarrollo
		hud.visible = debug_hud
		return
	if console_open or in_menu:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or Controls.hit(event, "pausa")):
		if dialogue != null and dialogue.is_choosing():
			dialogue.cancel_choice()   # Esc cierra la decisión de Farolín sin elegir (se sigue en el casino)
			return
		pause_game()
		return
	if casino != null:  # en el casino manda su propia escena
		return
	if run != null and left_bar != null:
		if _panel_abierto():
			return   # (con un panel abierto no se usan consumibles)
		var pick: Dictionary = consumable_pick.process(event, run.consumables.size())
		if pick.taken:
			left_bar.set_pick(consumable_pick.marked())
			if pick.use >= 0:
				use_consumable_slot(int(pick.use))
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N and tutorial_index >= 0:
		_tutorial_next()   # N salta la lección (la de ahora no se completa)


## Usa el consumible del casillero `slot` (teclas 1 a 4): los que tienen sentido en la torre (cosecha, racha, luz, movimientos, bombas) funcionan; el resto avisa y no se gasta.
func use_consumable_slot(slot: int) -> void:
	if _panel_abierto() or torre == null or in_menu or generating or casino != null or torre.t == null or torre.t.terminada:
		return
	if slot >= run.consumables.size():
		return
	if trial.get("no_items", false):
		_rechazar_item(slot)
		return
	var id: String = run.consumables[slot]
	if run.item_blocked(id):
		_rechazar_item(slot)
		return
	if id == "vida_extra":
		if run.add_life():
			_item_vuela(id, left_bar, slot)
			run.use_consumable(id)
			Sfx.play("item")
			_refresh()
			save_game()
		else:
			_rechazar_item(slot)
		return
	if id == "totem" or id == "soborno":   # (se usan solos cuando hace falta: el Tótem al morir, el Soborno frente a Farolín)
		_rechazar_item(slot)
		return
	var r: Dictionary = torre.t.usar_item(id)
	if bool(r.ok):
		_item_vuela(id, left_bar, slot)
		run.use_consumable(id)
		var ganado := int(r.get("claridad", 0))
		if ganado > 0:
			_flash_gain(Loc.f("+%d claridad", [ganado]), ganado)
		Sfx.play("item")
		torre.actualizar()
		_refresh()
		save_game()
	else:
		_rechazar_item(slot)


## Empieza la lección actual del tutorial (una sala armada a mano o, la última, una torre de verdad chica).
func _load_lesson() -> void:
	var lesson: Dictionary = Tutorial.lessons()[tutorial_index]
	var mi_epoca := epoch
	banner.text = ""
	tutorial_label.visible = false
	key_hint.clear()   # (la ayuda aparece cuando el tabernero termina de hablar)
	dialogue.hide_box()
	stage_number = 1
	run.stage = 1
	if lesson.has("generated"):
		_dice_intro_pending = bool(lesson.get("dice", false))
		await new_tower(randi() % 100000)   # (mientras se arma está la pantalla de los dados: el tabernero explica el juego encima)
		_dice_intro_pending = false
	else:
		await _torre_arrancar(randi() % 100000)
	if mi_epoca == epoch and tutorial_index >= 0:
		_say_lesson(lesson)


## El jugador movió con una tecla de movimiento: en el tutorial se doran las teclas de la ayuda que se usaron bien.
func _tutorial_movimiento(accion: String, modo: int, agarre: String) -> void:
	if tutorial_index < 0 or key_hint == null or not key_hint.visible:
		return
	key_hint.note(accion, modo, agarre)
	_check_keys_complete()


## Se movió la cámara con una de las teclas de cámara (tutorial).
func _tutorial_camara(accion: String) -> void:
	if tutorial_index < 0 or key_hint == null or not key_hint.visible:
		return
	key_hint.note_camera(accion)
	_check_keys_complete()


## Lecciones sin meta (la cámara): se completan al usar todas las teclas de la ayuda.
func _check_keys_complete() -> void:
	if tutorial_index < 0 or torre == null or not key_hint.visible:
		return
	if Tutorial.lessons()[tutorial_index].get("complete", "") == "keys" and key_hint.all_done():
		_torre_ganada()


## Aviso de los personajes que se acaban de desbloquear.

## Aviso de los personajes que se acaban de desbloquear.
## Se desbloqueó uno o más personajes: una ventana de logro con su nombre (no un cartel).
func _mostrar_logro(ids: Array) -> void:
	if test_mode or ventana_logro == null:
		return
	var nombres: Array = []
	for id in ids:
		nombres.append(Loc.t(str(Characters.get_character(str(id)).name)))
	ventana_logro.mostrar(Loc.t("¡Personaje nuevo!"), nombres)


func _character_msg(ids: Array) -> String:
	var parts: Array[String] = []
	for id in ids:
		parts.append(Loc.f("¡Personaje nuevo: %s!", [Loc.t(str(Characters.get_character(str(id)).name))]))
	return Loc.join(parts)


## ¿Se juegan los dados del tabernero al entrar al casino? (no en el entrenamiento ni en el tutorial, donde se juegan al empezar la torre)
func _hay_dados() -> bool:
	return dice_always and not training and tutorial_index < 0 and run != null


## Se superó la torre y todavía no se jugaron los dados: se anota en la partida (con la semilla de los dados) y se guarda ya, así salir con los dados abiertos y volver los retoma
## en vez de volver a la torre que ya se había superado.
func _preparar_dados() -> void:
	if not _hay_dados():
		return
	run.dados_por_jugar = true
	run.dados_semilla = randi()
	SaveGame.write({"run": run.to_dict(), "stage": stage_number, "seed": seed_value, "phase": "casino"})


## Los dados del tabernero: al entrar al casino, antes de verlo. Se juegan sobre la claridad que ya tienes (la de la torre cobrada); en el tutorial se juegan al empezar la torre.
func _dados_del_tabernero() -> void:
	if not _hay_dados():
		return
	_dados_en_casino = true   # (mientras tanto no se guarda: si se cierra el juego ahora, se vuelve a la torre y los dados no se cobraron)
	dice.claridad_actual = run.claridad
	var rng_dados := RandomNumberGenerator.new()
	rng_dados.seed = run.dados_semilla
	dice.open(rng_dados)
	dice.set_ready(true)
	while dice.visible:
		await get_tree().process_frame
	_dados_en_casino = false


## El portal de la torre lleva al casino: se cambia de cámara y se esconde el HUD de la torre.
func enter_casino(restoring := false) -> void:
	if casino != null or _dados_en_casino:
		return
	var mi_epoca := epoch
	if trial_banner != null:
		trial_banner.clear()
	Music.play("casino")
	if not restoring:
		_bank_claridad()
		_preparar_dados()
	ingreso_dados = 0
	if run.dados_por_jugar:
		var antes_de_dados := run.claridad
		await _dados_del_tabernero()   # (superaste la torre: antes del casino, el tabernero tira los dados sobre la claridad que acabas de cobrar)
		if mi_epoca != epoch or in_menu or run_over or casino != null:
			return
		ingreso_dados = maxi(run.claridad - antes_de_dados, 0)
		run.dados_por_jugar = false
		_claim_dice_rewards()   # (superaste la torre: lo que dieron los dados es tuyo)
	if not training and tutorial_index < 0:
		Telemetry.log_event("casino", {"stage": stage_number, "claridad_in": run.claridad, "lives": run.lives, "boosts": run.boosts.size()})
	casino = CasinoScene.new()
	casino.position = Vector3(500, 0, 0)  # lejos de la torre: la cámara ortogonal del casino no ve nada de ella
	add_child(casino)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	casino.toll_base = 0 if training or tutorial_index >= 0 or (test_mode and not toll_in_tests) else RunState.toll_for(run.stage)   # Farolín de la puerta de salida cobra la torre que se acaba de superar
	casino.setup(run, rng)
	_apply_casino_light()
	casino.left.connect(leave_casino)
	casino.toll_talk.connect(_on_toll_talk)
	casino.changed.connect(save_game)
	casino.keeper_talk.connect(_on_keeper_talk)
	hud_layer.visible = false
	banner.text = ""
	if not restoring:
		await _resumen_de_entrada()   # (la cuenta de lo que sumaron la torre, los dados y los ahorros, antes de empezar a jugar)
		if casino == null or in_menu or run_over or mi_epoca != epoch:
			return
	_evento_del_casino()
	save_game()


## Los eventos aleatorios del casino (casino_eventos.gd): se sortea (o se recuerda) el de esta etapa; si es nuevo, lo cuenta el personaje en un diálogo y, con el peaje por adelantado, Farolín cobra en el acto.
func _evento_del_casino() -> void:
	if casino == null or training or tutorial_index >= 0 or story_kind != "":
		return
	var rng_ev := RandomNumberGenerator.new()
	rng_ev.randomize()
	var precio: int = casino.toll_base if casino.toll_base <= 0 else run.toll_after_discounts(casino.toll_base)
	var ev: Dictionary = CasinoEventos.al_entrar(run, rng_ev, int(casino.lay.tier), precio)
	if ev.is_empty():
		return
	casino.poner_evento(ev)
	if not bool(ev.get("nuevo", false)):
		return
	var cobrado := CasinoEventos.aplicar_entrada(run, ev, precio)
	casino._refresh_hud()
	var a := CasinoEventos.anuncio(ev, cobrado, Story.SPEAKER, Farolin.SPEAKER)
	if test_mode:
		return   # (en las pruebas no se muestra el diálogo)
	_keeper_talk = true
	casino.input_locked = true
	dialogue.show_lines(a.lines, str(a.speaker), true)


## El tabernero del casino habla (regla de la casa y próxima prueba): el cuadro de diálogo, y mientras tanto no se camina.
func _on_keeper_talk(lines: Array) -> void:
	if casino == null:
		return
	_keeper_talk = true
	casino.input_locked = true
	dialogue.show_lines(lines, Story.SPEAKER, true)


## Farolín en la puerta de salida: el cuadro de diálogo con sus salidas (pagar, rehacer la torre o, sin vidas, abandonar). Mientras tanto no se camina.
## Termina el tutorial (después del peaje de práctica): se marca como hecho y se vuelve al menú.
func _finish_tutorial() -> void:
	_claim_dice_rewards()
	tutorial_forced = false
	Profile.mark_tutorial_done()
	open_main_menu()


func _on_toll_talk() -> void:
	if casino == null or dialogue.is_active():
		return
	var d: Dictionary = Farolin.practice_dialog(casino.toll_now()) if story_kind == "outro" else casino.toll_dialog()
	_toll_options = d.options
	casino.input_locked = true
	dialogue.show_choice(d.text, d.options, Farolin.SPEAKER)


## Se eligió una salida del diálogo (-1: se cerró con Esc y se sigue en el casino).
func _on_dialogue_chosen(index: int) -> void:
	if casino == null:
		return
	casino.input_locked = false
	if index < 0 or index >= _toll_options.size():
		if index < 0 and not _toll_options.is_empty():
			Telemetry.log_event("peaje", {"stage": stage_number, "price": casino.toll_now(), "claridad": run.claridad, "choice": "cancelar"})
		return
	var id := str(_toll_options[index].id)
	_toll_options = []
	if story_kind == "outro":   # el peaje de práctica: Farolín contesta y se termina el tutorial (no se cobra nada de verdad)
		_outro_phase = 2
		casino.input_locked = true
		dialogue.show_lines([Farolin.reaction(Farolin.PAY)], Farolin.SPEAKER, true, true)
		return
	Telemetry.log_event("peaje", {"stage": stage_number, "price": casino.toll_now(), "claridad": run.claridad, "choice": id})
	if farolin_reacts and not test_mode:   # Farolín contesta antes de que pase lo que se eligió
		casino.input_locked = true
		dialogue.show_lines([Farolin.reaction(id)], Farolin.SPEAKER, true, true)
		await dialogue.finished
		if casino == null:
			return
		casino.input_locked = false
	match id:
		Farolin.PAY:
			casino.pay_toll()
		Farolin.REDO:
			_on_pay_failed()
		Farolin.GIVE_UP:
			end_run(false, Loc.t("Dejaste que la luz se apagara."))


## Se eligió rehacer la torre: se pierde una vida y se vuelve a subir la misma (la claridad juntada se conserva).
func _on_pay_failed() -> void:
	if casino == null:
		return
	if not run.can_revive():
		end_run(false, Loc.t("Moriste: en este escenario no hay segundas oportunidades.") if run.permadeath() else Loc.t("Te quedaste sin vidas."))
		return
	run.note_retry(true)
	Music.play(_tower_music(stage_number))
	casino.queue_free()
	casino = null
	if cam != null:
		cam.make_current()
	hud_layer.visible = true
	restart()
	save_game()


## El portal del casino lleva a la torre de la etapa siguiente. Antes se ve el balance del casino (mientras la torre se genera).
func leave_casino() -> void:
	if casino == null or balance_layer != null:
		return
	_leaving_casino = true   # (desde acá el guardado es el de la pantalla de carga de la torre que sigue)
	save_game()
	if casino_balance and CasinoRules.active(run):
		balance_layer = CanvasLayer.new()
		balance_layer.layer = 50
		add_child(balance_layer)
		var screen := BalanceScreen.new()
		balance_layer.add_child(screen)
		screen.setup(run)
		screen.done.connect(func():
			_close_balance()
			_salir_con_resumen())
		return
	_salir_con_resumen()


## Después del balance del casino y antes de la torre: la ventana de claridad con lo que sumó el peaje y los boosts con los que se empieza.
func _salir_con_resumen() -> void:
	await _resumen_de_salida()
	if casino == null or in_menu or run_over:
		return
	_leave_casino_now()


## ¿Se muestran las ventanas del resumen de claridad? (no en las pruebas, el entrenamiento ni el tutorial)
func _resumenes_activos() -> bool:
	return not test_mode and not training and tutorial_index < 0 and resumen_claridad != null and run != null


## Al entrar al casino: la claridad con la que empezó la torre, lo que se añadió (la torre, los dados, la Caja fuerte, la Alcancía, los contratos) y el total.
func _resumen_de_entrada() -> void:
	if not _resumenes_activos() or casino == null:
		return
	var total: int = run.claridad
	var ahorro: int = int(casino._ahorro_cobrado)
	var caja := 0
	if run.boosts.has("caja_fuerte"):
		caja = mini(int(round(float(run.claridad_inicio_torre) * 0.15)), ahorro)
	var filas := [
		{"id": "", "nombre": Loc.t("Torre"), "valor": ultimo_ingreso_torre},
		{"id": "", "nombre": Loc.t("Dados"), "valor": ingreso_dados},
		{"id": "caja_fuerte", "nombre": Loc.t("Caja fuerte"), "valor": caja},
		{"id": "alcancia", "nombre": Loc.t("Alcancía"), "valor": ahorro - caja},
	]
	var entrada: int = run.claridad_inicio_torre
	var suma := 0
	for f in filas:
		suma += int(f.valor)
	if total - entrada - suma != 0:   # (lo que no es de ninguno de los de arriba, por ejemplo los contratos que se cobraron al terminar la torre)
		filas.append({"id": "", "nombre": Loc.t("Contratos"), "valor": total - entrada - suma})
	casino.input_locked = true
	resumen_claridad.mostrar(Loc.t("Entras al casino"), entrada, filas)
	await resumen_claridad.cerrado
	if casino != null:
		casino.input_locked = false


## Después del balance del casino: la claridad con la que sales del peaje, lo que sumó el Interés y lo que devolvió Farolín, y lo con lo que empieza la torre (Ahorro, Bolsillo de luz).
func _resumen_de_salida() -> void:
	if not _resumenes_activos() or casino == null or Demo.is_last_casino(stage_number):
		return
	var interes := int(casino.resumen_salida.get("interes", 0))
	var devuelto := int(casino.resumen_salida.get("devuelto", 0))
	var filas := [
		{"id": "interes", "nombre": Loc.t("Interés"), "valor": interes},
		{"id": "", "nombre": Loc.t("Farolín te devuelve"), "valor": devuelto},
		{"id": "ahorro", "nombre": Loc.t("Ahorro"), "valor": 20 if run.boosts.has("ahorro") else 0},
		{"id": "bolsillo_de_luz", "nombre": Loc.t("Bolsillo de luz"), "valor": 60 if run.boosts.has("bolsillo_de_luz") else 0},
	]
	casino.input_locked = true
	resumen_claridad.mostrar(Loc.f("Empiezas la torre %d", [mini(stage_number + 1, FINAL_STAGE)]), run.claridad - interes - devuelto, filas)
	await resumen_claridad.cerrado


func _close_balance() -> void:
	if balance_layer != null:
		balance_layer.queue_free()
		balance_layer = null


func _leave_casino_now() -> void:
	if casino == null:
		return
	if Demo.is_last_casino(stage_number) and not training:   # el casino que cierra la demo: se le pagó a Farolín, se terminó
		_leaving_casino = false
		end_run(true, "")
		return
	Music.play(_tower_music(mini(stage_number + 1, FINAL_STAGE)))
	casino.queue_free()
	casino = null
	if cam != null:
		cam.make_current()
	hud_layer.visible = true
	stage_number = mini(stage_number + 1, FINAL_STAGE)
	run.stage = stage_number
	_leaving_casino = false
	new_tower(randi() % 100000)


# --- menús ------------------------------------------------------------------------------------------------------

func _build_menus() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 100
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu_layer)
	main_menu = MainMenu.new()
	main_menu.new_game.connect(_on_new_game)
	main_menu.continue_game.connect(continue_game)
	main_menu.start_tutorial.connect(start_tutorial)
	main_menu.quit_game.connect(quit_game)
	main_menu.language_changed.connect(_on_language_changed)
	menu_layer.add_child(main_menu)
	pause_menu = PauseMenu.new()
	pause_menu.resume.connect(resume_game)
	pause_menu.restart_tower.connect(func():
		resume_game()
		request_restart())
	pause_menu.abandon_run.connect(_ask_abandon)
	pause_menu.to_main_menu.connect(open_main_menu)
	pause_menu.quit_game.connect(quit_game)
	pause_menu.language_changed.connect(_on_language_changed)
	menu_layer.add_child(pause_menu)
	confirm_box = ConfirmBox.new()
	menu_layer.add_child(confirm_box)
	difficulty_screen = DifficultyScreen.new()
	menu_layer.add_child(difficulty_screen)
	run_end = RunEndScreen.new()
	run_end.new_game.connect(func():   # "Nueva partida" del fin de run: se elige el escenario otra vez
		open_main_menu()
		main_menu.show_panel("escenarios"))
	run_end.to_menu.connect(open_main_menu)
	menu_layer.add_child(run_end)
	demo_end = DemoEndScreen.new()
	demo_end.new_game.connect(func():
		open_main_menu()
		main_menu.show_panel("escenarios"))
	demo_end.to_menu.connect(open_main_menu)
	menu_layer.add_child(demo_end)
	main_menu.visible = false


## Cambió el idioma: los menús se arman de nuevo con los textos nuevos y se vuelve a la pantalla de Opciones donde se estaba.
func _on_language_changed() -> void:
	_rebuild_menus.call_deferred()


func _rebuild_menus() -> void:
	var was_paused: bool = pause_menu != null and pause_menu.visible
	var old := menu_layer
	old.get_parent().remove_child(old)
	old.queue_free()
	_build_menus()
	if in_menu:
		main_menu.set_continue(SaveGame.peek_stage())
		main_menu.visible = true
		main_menu.show_panel("opciones")
	elif was_paused:
		pause_menu.set_restart(run.lives, training, casino != null)
		pause_menu.open()
		pause_menu.show_options(true)
		if trial.get("no_retry", false):
			pause_menu.buttons["reiniciar"].disabled = true
			pause_menu.buttons["reiniciar"].set_label(Loc.t("Reintentar (no en esta prueba)"))


func open_main_menu() -> void:
	_torre_cerrar(true)
	_close_balance()
	if trial_banner != null:
		trial_banner.clear()
	if lost_screen != null:
		lost_screen.hide_screen()
	Music.play("menu")
	save_game()   # (no hace nada si no hay un run en juego)
	epoch += 1
	get_tree().paused = false
	pause_menu.close()
	if casino != null:
		casino.queue_free()
		casino = null
		if cam != null:
			cam.make_current()
	generating = false
	banner.text = ""
	dice.visible = false
	dice.phase = DiceGame.Phase.IDLE
	_set_training(false)
	run_over = false
	run_end.visible = false
	demo_end.visible = false
	in_menu = true
	hud_layer.visible = false
	main_menu.set_continue(SaveGame.peek_stage())
	main_menu.open()


## "Nueva partida": run nuevo desde la etapa 1 en el escenario elegido (se paga su entrada con Luz; si no alcanza, se juega La Pesadilla).
## El resumen de una partida (de la guardada o de la que está en marcha) para los cuadros de confirmación.
func _progress_text(r: Dictionary, stage: int) -> String:
	var scn := Scenarios.get_scenario(str(r.get("scenario_id", Scenarios.FREE)))
	return Loc.f("%s: etapa %d de %d, %d torres superadas, %d de claridad y %d vidas.", [Loc.t(str(scn.get("name", ""))), stage, Demo.shown_final(FINAL_STAGE), int(r.get("towers_cleared", 0)), int(r.get("claridad", 0)), int(r.get("lives", 0))])


## "Abandonar partida" de la pausa: primero se pregunta; si se confirma, termina la partida (con el resumen).
func _ask_abandon() -> void:
	confirm_box.ask(Loc.t("¿Abandonar la partida?"), Loc.f("Vas a terminar la partida en curso y se perderá este progreso. %s", [_progress_text(run.to_dict(), stage_number)]),
			Loc.t("Sí, abandonar"), Loc.t("Seguir jugando"))
	var yes: bool = await confirm_box.chosen
	if not yes or run_over:
		return
	resume_game()
	end_run(false, Loc.t("Abandonaste la partida."))


## Elegir un escenario nuevo: si hay una partida sin terminar, antes hay que confirmar que se pierde.
func _on_new_game(scenario_id: String) -> void:
	var dificultad := "media"
	var elegibles := Scenarios.difficulties(scenario_id)
	if not elegibles.is_empty():   # primero se elige la dificultad (gradúa las salas de las 15 etapas); La Pesadilla tiene las cuatro y los demás escenarios, sin Fácil
		difficulty_screen.ask(elegibles)
		dificultad = await difficulty_screen.chosen
		if dificultad == "":
			return
	var saved := SaveGame.read()
	if saved.is_empty():
		start_game(scenario_id, dificultad)
		return
	confirm_box.ask(Loc.t("¿Empezar una partida nueva?"), Loc.f("Tienes una partida sin terminar. %s Si empiezas otra, esa partida se perderá.", [_progress_text(saved.run, int(saved.stage))]),
			Loc.t("Sí, empezar de nuevo"), Loc.t("Volver"))
	var yes: bool = await confirm_box.chosen
	if yes:
		SaveGame.delete()
		start_game(scenario_id, dificultad)


func start_game(scenario_id := Scenarios.FREE, dificultad := "media") -> void:
	_torre_cerrar(true)
	if not Profile.pay_entry(scenario_id):
		scenario_id = Scenarios.FREE
	main_menu.visible = false
	in_menu = false
	run = RunState.new()
	_pista_on = false
	run.scenario_id = scenario_id
	run.dificultad = dificultad if ["facil", "media", "dificil", "pesadilla"].has(dificultad) else "media"
	var draw_rng := RandomNumberGenerator.new()
	draw_rng.randomize()
	run.trial_schedule = Trials.draw_schedule(run.scenario().pool, draw_rng, run.dificultad == "facil")   # qué prueba toca en cada etapa 3, 6, 9... (en Fácil no salen las que tratan de los movimientos)
	run_new_abilities.clear()
	Profile.apply_to_run(run)   # habilidades persistentes y reglas del escenario
	_bind_bars()
	_set_training(false)
	run_over = false
	run_end.visible = false
	demo_end.visible = false
	stage_number = 1
	run.stage = 1
	hud_layer.visible = true
	new_tower(randi() % 100000)


## El título del menú de pausa: el escenario en el que se está (La Pesadilla lleva además su dificultad); en el tutorial, "Pausa".
func _titulo_pausa() -> String:
	if run == null or training:
		return ""
	var nombre := str(run.scenario().get("name", ""))
	for o in DifficultyScreen.OPTIONS:
		if o.id == run.dificultad:
			return Loc.f("%s - %s", [Loc.t(nombre), Loc.t(o.name)])   # ("La Pesadilla - Fácil", "Compromiso - Difícil"...)
	return Loc.t(nombre)


func pause_game() -> void:
	if in_menu or pause_menu.visible:
		return
	get_tree().paused = true
	pause_menu.set_tutorial_lock(tutorial_forced)
	if panel_info != null:
		panel_info.cerrar(true)
		panel_items.cerrar(true)
	if trial_banner != null:
		trial_banner.hide_for_pause()   # (el cartel grande no se ve en la pausa: la prueba, los contratos y el resto se leen en el panel de información)
	pause_menu.set_restart(run.lives, training, casino != null)
	pause_menu.set_title(_titulo_pausa())
	pause_menu.open()
	if trial.get("no_retry", false):
		pause_menu.buttons["reiniciar"].disabled = true   # (la prueba "Todo o nada" no tiene reintentos)
		pause_menu.buttons["reiniciar"].set_label(Loc.t("Reintentar (no en esta prueba)"))


func resume_game() -> void:
	pause_menu.close()
	_set_depth_mode(int(Settings.get_value("ayuda_profundidad")))   # (por si se cambió en Opciones)
	get_tree().paused = false


func quit_game() -> void:
	save_game()
	epoch += 1
	if not quit_game_override:
		get_tree().quit()


## Deshace el último movimiento de la sala (con lo que se había juntado y la cuenta de movimientos).
func undo_move() -> void:
	if torre == null:
		return
	if run != null and bool(run.scenario().get("no_undo", false)) and not training:
		senal.mostrar(SenalPantalla.Tipo.NO_REBOBINAR)   # (el escenario no deja deshacer)
		Sfx.play("miss", 0.8, -4.0)
		return
	if in_menu or generating or casino != null or dialogue.is_active():
		return
	if torre.deshacer():
		senal.mostrar(SenalPantalla.Tipo.REBOBINAR)
		_contratos_registrar("deshacer", {})
		_contratos_mostrar()


## Reintentar: tras perder una sala se reintenta ESA sala (cuesta una vida, o el Tótem); por voluntad (desde la pausa o con R) se vuelve a empezar la torre y cuesta una vida.
func request_restart() -> void:
	if torre == null or in_menu or generating or casino != null:
		return
	if torre.t != null and torre.t.muerta:
		var costo := run.restart_cost(true)
		if not run.can_afford(costo):
			end_run(false, Loc.f("No te alcanza la claridad para reintentar la torre (cuesta %d).", [costo]))
			return
		var con_totem: bool = run.consumables.has("totem") and not run.item_blocked("totem")
		var casillero_totem: int = run.consumables.find("totem") if con_totem else -1
		if con_totem:
			_item_vuela("totem", left_bar, casillero_totem)   # (el Tótem sale de su casillero y se deshace en luz: te salvó la vida)
		run.spend(costo)
		run.note_retry(true)
		lost_screen.hide_screen()
		torre.reiniciar_sala()
		_refresh()
		save_game()
		return
	if training:
		restart()
		return
	if trial.get("no_retry", false) or not run.pay_voluntary_retry():
		_senal_rechazo()   # (Todo o nada, o sin vidas)
		return
	restart()


## Termina el run y muestra el resumen.
func end_run(victory: bool, reason := "") -> void:
	if run_over:
		return
	_torre_cerrar(true)
	if not training:
		Telemetry.log_event("run_fin", {"victory": victory, "stage": run.max_stage, "towers": run.towers_cleared, "trials": run.trials_cleared, "earned": run.claridad_earned, "lives": run.lives})
	if lost_screen != null:
		lost_screen.hide_screen()
	Music.play("menu")
	Sfx.play("win" if victory else "lose")
	run_over = true
	if trial_banner != null:
		trial_banner.clear()
	epoch += 1
	_close_balance()
	get_tree().paused = false
	pause_menu.close()
	if casino != null:
		casino.queue_free()
		casino = null
		if cam != null:
			cam.make_current()
	generating = false
	banner.text = ""
	hud_layer.visible = false
	in_menu = true
	SaveGame.delete()   # el run terminó: no hay nada que continuar
	if run.towers_cleared > 0:
		_claim_dice_rewards()   # (si se abandona antes de superar una torre, lo de los dados se pierde)
	var luz := Profile.record_run(run, victory)   # la Luz y las estadísticas pasan al perfil
	if victory and not training and not Demo.on():   # escapar da una habilidad persistente del escenario (o Luz si ya las tenés todas; en la demo no hay habilidades)
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var award := Profile.award_scenario_ability(run.scenario_id, rng)
		if award.ability != "":
			var ab := Abilities.get_ability(str(award.ability))
			run_new_abilities.append(ab.name)
			var chars: Array = Profile.on_ability(ab.id)
			if not chars.is_empty():
				reason = Loc.join([reason, _character_msg(chars)]) if reason != "" else _character_msg(chars)
		luz += int(award.luz)
	if Demo.on() and not training:
		demo_end.show_summary(run, victory)
		return
	run_end.show_summary(run, victory, reason, luz, Profile.luz(), run_new_abilities.duplicate())


# --- modo entrenamiento -----------------------------------------------------------------------------------------

func _set_training(on: bool) -> void:
	training = on
	if not on:
		if dialogue != null:
			dialogue.hide_box()
		story_kind = ""
		tutorial_index = -1
		if tutorial_label != null:
			tutorial_label.visible = false
		if key_hint != null:
			key_hint.clear()
	if clarity_counter != null:
		clarity_counter.visible = not on


## Tutorial: lecciones armadas a mano (tutorial.gd), sin casino ni claridad en juego.
## `skip_intro`: salta la escena de la taberna (las pruebas, o quien quiera empezar directo en una lección).
func start_tutorial(index := 0, skip_intro := false) -> void:
	main_menu.visible = false
	in_menu = false
	run = RunState.new()
	_bind_bars()
	_set_training(true)
	tutorial_index = clampi(index, 0, Tutorial.count() - 1)
	stage_number = 1
	run.stage = 1
	if index == 0 and not skip_intro:
		_open_story_room(Story.INTRO_STAGE, Story.intro(), "intro")
		return
	hud_layer.visible = true
	await _load_lesson()


## Una sala de historia del tutorial: el tabernero habla (cuadro de diálogo) en la taberna (al empezar) o en el salón de piedra (al terminar).
func _open_story_room(stage: int, lines: Array, kind: String) -> void:
	Music.play("menu")
	story_kind = kind
	hud_layer.visible = false
	banner.text = ""
	stage_number = stage   # (la luz y la sala del casino dependen de la etapa)
	run.stage = stage
	casino = CasinoScene.new()
	casino.position = Vector3(500, 0, 0)   # lejos de la torre, como el casino normal
	casino.story = true
	if kind == "outro":   # en el salón de piedra Farolín espera junto a la puerta: se le paga un peaje de práctica
		casino.toll_base = TUTORIAL_TOLL
		_outro_phase = 0
		casino.toll_talk.connect(_on_toll_talk)
	add_child(casino)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	casino.setup(run, rng)
	casino.input_locked = true   # no se camina mientras habla
	casino.story_message.connect(_on_story_message)
	casino.left.connect(_on_story_left)
	_apply_casino_light()
	dialogue.show_lines(lines, Story.SPEAKER, true)


var _story_msg_id := 0


## Un aviso del tabernero en la historia (por ejemplo, que todavía no se apuesta): se escribe solo y se va a los pocos segundos (si no, quedaba el cuadro tapando la pantalla y no se podía seguir).
func _on_story_message(t: String) -> void:
	dialogue.show_lines([t], Story.SPEAKER, false)
	_story_msg_id += 1
	var id := _story_msg_id
	await get_tree().create_timer(3.0).timeout
	if id == _story_msg_id and dialogue != null and dialogue.is_active() and not dialogue.blocking:
		dialogue.hide_box()


func _on_dialogue_finished() -> void:
	if _keeper_talk:   # terminó de hablar con el tabernero del casino: se vuelve a caminar
		_keeper_talk = false
		if casino != null:
			casino.input_locked = false
		return
	if story_kind == "intro" and casino != null:   # terminó de contar la historia: ahora hay que ir a la puerta de atrás
		casino.input_locked = false
		casino.show_exit_arrow(true)
	elif story_kind == "outro":
		match _outro_phase:
			0:   # terminó de hablar el tabernero: ahora a pagarle a Farolín (el tabernero presta la claridad)
				_outro_phase = 1
				run.claridad = maxi(run.claridad, casino.toll_now())
				casino.input_locked = false
				casino.show_exit_arrow(true)
				casino._refresh_hud()
			2:   # Farolín contestó: el tutorial se acabó
				_finish_tutorial()
	elif _dice_talk:   # terminó de explicar los dados: se puede jugar
		_dice_talk = false
		dice.paused = false
	elif tutorial_index >= 0 and story_kind == "":
		_show_lesson_help()


## Se empujó la puerta de atrás de la taberna: empiezan las lecciones.
func _on_story_left() -> void:
	if story_kind != "intro":
		return
	story_kind = ""
	dialogue.hide_box()
	if casino != null:
		casino.queue_free()
		casino = null
	if cam != null:
		cam.make_current()
	stage_number = 1
	run.stage = 1
	hud_layer.visible = true
	await _load_lesson()


## ¿Faltan teclas de la lección por usar? Entonces no se puede pasar a la siguiente (en las pruebas automáticas no rige).
func tutorial_locked() -> bool:
	return not test_mode and tutorial_locked_for_test()


## (Para las pruebas: lo mismo que tutorial_locked pero sin la excepción del modo de pruebas.)
func tutorial_locked_for_test() -> bool:
	return key_hint != null and key_hint.visible and key_hint.has_keys() and not key_hint.all_done()


## El tabernero cuenta el lore de la lección (con cualquier tecla se va) y entonces aparece la ayuda con las teclas.
func _say_lesson(lesson: Dictionary) -> void:
	var lore := Story.lesson_say(str(lesson.id), "")
	if lore == "":
		_show_lesson_help()
		return
	dialogue.show_lines([lore], Story.SPEAKER, true, true)


func _show_lesson_help() -> void:
	if tutorial_index < 0:
		return
	var l: Dictionary = Tutorial.lessons()[tutorial_index]
	key_hint.show_help(str(l.get("help", "")), str(l.get("mode", "")))


## Tutorial: cuando se abren los dados, el tabernero explica cómo se juega (y los dados esperan a que termine).
func _maybe_dice_intro() -> void:
	if not _dice_intro_pending or tutorial_index < 0:
		return
	_dice_intro_pending = false
	_dice_talk = true
	dice.paused = true
	dialogue.show_lines(Story.dice_intro(), Story.SPEAKER, true, true)


func _tutorial_next() -> void:
	if tutorial_index < 0 or generating or tutorial_locked():
		return
	if tutorial_index + 1 >= Tutorial.count():
		_open_story_room(Story.OUTRO_STAGE, Story.outro(), "outro")   # el tabernero te recibe en el salón de piedra
		return
	tutorial_index += 1
	await _load_lesson()


# --- boosts y consumibles en la torre -------------------------------------------------------------------------------


## Las barras de ítems se atan al run (cada partida nueva trae un RunState nuevo).
func _bind_bars() -> void:
	if left_bar == null:
		return
	left_bar.setup(run, ItemBar.Kind.CONSUMABLE, true)
	right_bar.setup(run, ItemBar.Kind.BOOST)


## Barras de consumibles y boosts (con sus casilleros según la capacidad actual) y el aviso del Freno.
func _update_perk_label() -> void:
	if perk_label == null:
		return
	if left_bar != null:
		left_bar.refresh()
		right_bar.refresh()
	perk_label.text = ""


## Se tiró un ítem con clic derecho en la barra: se actualiza el HUD y se guarda. (Un boost tirado deja de valer desde el próximo intento.)
func _on_item_discarded(_item_kind: int, _id: String) -> void:
	Sfx.play("miss")
	if torre != null:
		_refresh()
	save_game()


# --- modo dev ---------------------------------------------------------------------------------------------------

## La consola sólo se crea en compilaciones de desarrollo (nunca en la exportación release que va a Steam).
func _build_dev_console() -> void:
	if not DevCommands.available():
		return
	dev_console = DevConsole.new()
	add_child(dev_console)
	dev_console.command_entered.connect(_on_dev_command)
	dev_console.toggled.connect(func(open: bool): console_open = open)


func _on_dev_command(line: String) -> void:
	var out := DevCommands.execute(line, self)
	if out != "" and dev_console != null:
		dev_console.print_line(out)


## Comando tower: una partida nueva en la etapa y el escenario que se pida (sin pagar la entrada), con la semilla opcional. Funciona desde el menú principal y desde el juego.
func dev_tower(stage: int, scenario_id := "", seed := -1, prueba := "") -> String:
	if generating:
		return "Espera: se está armando la torre"
	var sc := scenario_id.to_lower() if scenario_id != "" else Scenarios.FREE
	var ids: Array[String] = []
	var known := false
	for s in Scenarios.ALL:
		ids.append(str(s.id))
		known = known or s.id == sc
	if not known:
		return "Escenario desconocido: %s   (escenarios: %s)" % [scenario_id, ", ".join(ids)]
	stage = clampi(stage, 1, FINAL_STAGE)
	if casino != null:
		casino.queue_free()
		casino = null
		if cam != null:
			cam.make_current()
	if lost_screen != null:
		lost_screen.hide_screen()
	pause_menu.close()
	get_tree().paused = false
	main_menu.visible = false
	in_menu = false
	run = RunState.new()
	run.scenario_id = sc
	var draw_rng := RandomNumberGenerator.new()
	draw_rng.randomize()
	run.trial_schedule = Trials.draw_schedule(run.scenario().pool, draw_rng, run.dificultad == "facil")
	if prueba != "":   # (el comando prueba: esa prueba en esa etapa)
		run.trial_schedule[stage] = prueba
	run_new_abilities.clear()
	Profile.apply_to_run(run)
	_bind_bars()
	_set_training(false)
	run_over = false
	run_end.visible = false
	demo_end.visible = false
	stage_number = stage
	run.stage = stage
	run.max_stage = stage
	hud_layer.visible = true
	var used := seed if seed >= 0 else randi() % 100000
	new_tower(used)
	return "Torre de la etapa %d, escenario %s, semilla %d" % [stage, sc, used]


## Comando goto_end: se da por ganada la torre actual (lo que lleva al casino).
func dev_goto_end() -> String:
	if casino != null:
		return "Ya estás en el casino"
	if in_menu or torre == null:
		return "No hay una torre en juego"
	if generating:
		return "Espera: se está generando la torre"
	_torre_ganada()
	return "Llegaste al portal: torre completada"


## Comando goto_casino: abre directamente el casino de la etapa `stage` (como si acabaras de pasar esa torre).
func dev_goto_casino(stage: int) -> String:
	if in_menu or (torre == null and casino == null):
		return "Empieza una partida primero (Nueva partida)"
	if training:
		return "En el tutorial no hay casino"
	if generating:
		return "Espera: se está generando la torre"
	if casino != null:
		casino.queue_free()
		casino = null
		if cam != null:
			cam.make_current()
	stage = clampi(stage, 1, FINAL_STAGE)
	stage_number = stage
	run.stage = stage
	run.max_stage = maxi(run.max_stage, stage)
	banner.text = ""
	_torre_cerrar(true)
	enter_casino(true)   # (true: no se suma de nuevo la claridad de la torre)
	return "Casino de la etapa %d" % stage


## Comando set_luz: deja la Luz del perfil en `n` (no baja de 0) y actualiza las pantallas que la muestran.
func dev_set_luz(n: int) -> String:
	n = maxi(n, 0)
	Profile.load_profile()
	Profile.data.luz = n
	Profile.save()
	if main_menu != null:
		if main_menu.scenarios.visible:
			main_menu.scenarios.refresh()
		if main_menu.meta.visible:
			main_menu.meta.refresh()
	return "Luz: %d" % n


## Comando set_claridad: deja la claridad total en `n` (la del run más la juntada en la torre actual).
func dev_set_claridad(n: int) -> String:
	n = maxi(n, 0)
	if casino == null and torre != null and torre.t != null and not banked:
		var earned: int = torre.t.cosecha.claridad()
		if n >= earned:
			run.claridad = n - earned
		else:
			run.claridad = 0
			torre.t.cosecha.sala = 0
			torre.t.cosecha.banco = n
		_refresh()
	else:
		run.claridad = n
		if casino != null:
			casino._refresh_hud()
			if casino.screen != null:
				casino.screen._refresh()
	return "Claridad = %d" % n


## Comando give: da un boost o consumible (los boosts se aplican al empezar o reintentar la torre: R).
func dev_give(id: String) -> String:
	var item := Items.get_item(id)
	if item.is_empty() or item.type == Items.Type.CLARITY:
		return "Ítem desconocido: %s (mira los ids con: items)" % id
	if not run.take(item):
		return "No hay lugar para %s" % item.name
	if torre != null:
		_update_perk_label()
	if casino != null:
		casino._refresh_hud()
	return "Recibiste %s%s" % [item.name, " (se aplica al reintentar la torre: R)" if item.type == Items.Type.BOOST and casino == null else ""]


# --- guardar y continuar -------------------------------------------------------------------------------------------

## ¿Hay un run en juego que valga la pena guardar? (no en el entrenamiento, ni terminado, ni en el menú)
func _run_active() -> bool:
	return not training and not run_over and not in_menu and (casino != null or torre != null)


## Autoguardado: el run y, si se está en una torre, el estado inicial de esa torre (para volver a empezarla igual).
## Alt + F4 (o cerrar la ventana): guardado rápido antes de salir.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


## ¿Se está entre el casino y la torre que sigue (peaje pagado, torre generándose o dados en pantalla)?
func _loading_state() -> bool:
	if training or tutorial_index >= 0 or run == null or run_over or in_menu:
		return false
	return _leaving_casino or (generating and casino == null)


func save_game() -> void:
	if _dados_en_casino:
		return
	if _loading_state():   # pagado el peaje (o generando la torre): se guarda "cargando la torre" para no repetir el casino ni los dados
		var next_stage := mini(stage_number + 1, FINAL_STAGE) if casino != null else stage_number
		SaveGame.write({"run": run.to_dict(), "stage": next_stage, "seed": seed_value, "phase": "loading"})
		return
	if not _run_active():
		return
	var data := {"run": run.to_dict(), "stage": stage_number, "seed": seed_value}
	if casino != null:
		data["phase"] = "casino"
	elif torre != null:   # (la torre se retoma en el último checkpoint con la misma semilla)
		data["phase"] = "tower"
		if torre.t != null:
			data["sala"] = torre.t.indice
			data["banco"] = torre.t.cosecha.banco
		data["dirty"] = attempt_dirty
		data["dead"] = torre.t != null and torre.t.muerta   # (murió y todavía no reintentó: al continuar cuenta como reintento después de morir)
	SaveGame.write(data)


## Botón Continuar: vuelve al casino donde se quedó, o al comienzo de la misma torre. Si el intento de la torre ya había empezado,
## continuar cuenta como un reintento (cuesta claridad): así salir y volver no sirve para reiniciar gratis.
func continue_game() -> void:
	var data := SaveGame.read()
	if data.is_empty():
		return
	main_menu.visible = false
	in_menu = false
	run = RunState.from_dict(data.run)
	_bind_bars()
	_set_training(false)
	run_over = false
	run_end.visible = false
	demo_end.visible = false
	stage_number = int(data.stage)
	seed_value = int(data.get("seed", 1))
	hud_layer.visible = true
	if data.phase == "casino":
		run.stage = stage_number
		enter_casino(true)
		return
	if data.phase == "loading":   # había pagado el peaje: sigue la carga de la torre (y los dados sólo si no los había jugado)
		run.stage = stage_number
		Music.play(_tower_music(stage_number))
		new_tower(seed_value)
		return
	trial = run.trial_at(stage_number)
	if data.get("dirty", false) and trial.get("no_retry", false):
		end_run(false, Loc.f("Abandonaste la prueba «%s» (no hay reintentos).", [Loc.t(trial.name)]))
		return
	_continuar_sala = int(data.get("sala", 0))
	_continuar_banco = int(data.get("banco", 0))
	var was_dead: bool = data.get("dead", false)
	if was_dead and not run.can_revive():
		end_run(false, Loc.t("Moriste: en este escenario no hay segundas oportunidades.") if run.permadeath() else Loc.t("Te quedaste sin vidas."))
		return
	if data.get("dirty", false) or was_dead:
		var cost := run.restart_cost(was_dead)
		if not run.can_afford(cost):
			end_run(false, Loc.f("No te alcanza la claridad para reintentar la torre (cuesta %d).", [cost]))
			return
		run.spend(cost)
		run.note_retry(was_dead)
	restart()
	save_game()
