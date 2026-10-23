extends Node3D
## La escena principal: el menú, el run (etapas, torre, casino, peaje), los menús de pausa y de fin, el tutorial y el guardado. La torre se juega en torre/torre_juego.gd.

const TorreJuego := preload("res://torre/torre_juego.gd")   # la torre (salas apiladas, sin núcleo): ver docs/reglas_torre.md
const RunState := preload("res://scripts/datos/run_state.gd")
const Controls := preload("res://scripts/entrada/controls.gd")
const Graphics := preload("res://scripts/ui/graphics.gd")
const LivesHud := preload("res://scripts/ui/lives_hud.gd")
const HudPanel := preload("res://scripts/ui/hud_panel.gd")
const Stages := preload("res://scripts/datos/stages.gd")
const BlockGuide := preload("res://scripts/datos/block_guide.gd")
const Farolin := preload("res://scripts/personajes/farolin.gd")
const TrialBanner := preload("res://scripts/ui/trial_banner.gd")
const Telemetry := preload("res://scripts/datos/telemetry.gd")
const Demo := preload("res://scripts/datos/demo.gd")
const DemoEndScreen := preload("res://scripts/ui/demo_end_screen.gd")
const KeyHint := preload("res://scripts/ui/key_hint.gd")
const KeyDirs := preload("res://scripts/entrada/key_dirs.gd")
const CasinoRules := preload("res://scripts/casino/casino_rules.gd")
const BalanceScreen := preload("res://scripts/casino/casino_balance_screen.gd")
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
## Ayudas de profundidad (tecla V): 0 ninguna, 1 atenuación, 2 atenuación + transparencia cercana.
const DEPTH_STRENGTH := 0.11
const XRAY_RADIUS := 1.3
const FINAL_STAGE := Stages.FINAL   # etapas del juego: al pasar la última se termina
## Fondo y bloques se aclaran de una etapa a la siguiente (no dentro de una misma etapa).
const BG_DARK := Color(0.05, 0.04, 0.09)
const BG_LIGHT := Color(0.80, 0.84, 0.95)
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
const PORTAL_SHADER := preload("res://shaders/portal.gdshader")
var cam: Camera3D
var _goal_mat: StandardMaterial3D
const GOAL_TOP_LIFT := 0.52   # a qué altura (desde el centro del cubo de salida) va la losa de ondas de su cara de arriba
var seed_value := 1
var stage_number := 1      # etapa (1..15) que se genera: define la dificultad, el largo de la torre y las mecánicas
var hud: Control              # texto de depuración (semilla, contadores...): sólo se ve con F2 en las compilaciones de desarrollo
var debug_hud := false
var stage_label: Control     # "Etapa 5/27" y el piso en que estás
var hud_panel               # la ventana de la partida: corazones, etapa, claridad y racha
var banner: Control
var toast: Control
var _gain_tween: Tween     # el desvanecer del cartel de ganancia (uno solo a la vez)
var _toast_tween: Tween    # y el del aviso
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
var dice_always := true      # los dados del tabernero se ven en toda pantalla de carga, aunque la torre ya esté lista (las pruebas lo apagan)
var lives_hud                # las tres vidas (corazones 3D que giran, abajo a la derecha)
var casino_balance := true   # al salir del casino se ve el balance (las pruebas lo apagan: salir pasa directo a la torre)
var balance_layer: CanvasLayer   # donde vive el balance mientras se ve
var farolin_reacts := true   # Farolín dice una frase después de cada decisión del peaje (las pruebas la apagan)
var tutorial_forced := false   # primera vez: el tutorial no se puede dejar (la pausa no vuelve al menú principal)
var tutorial_index := -1    # lección del tutorial en curso (-1 = no se está en el tutorial)
var dice                      # los dados del tabernero: el minijuego de la pantalla de carga
var _sun: DirectionalLight3D
var dialogue                 # cuadro de diálogo del tabernero (historia y consejos del tutorial)
const TUTORIAL_TOLL := 25   # lo que cuesta el peaje de práctica del final del tutorial
var _outro_phase := 0       # el cierre del tutorial: 0 el tabernero habla, 1 se camina hasta Farolín, 2 Farolín contesta y se termina
var story_kind := ""         # "intro" o "outro" mientras se está en una sala de historia del tutorial
var tutorial_label: Control # cartel con la lección
var block_discovery := true   # al llegar a la fila de un bloque nuevo, el tabernero lo explica (las pruebas lo apagan)
var _dice_intro_pending := false   # tutorial: al abrirse los dados, el tabernero explica el juego
var _dice_talk := false
var _leaving_casino := false   # se le pagó a Farolín y se está yendo del casino: si se cierra el juego ahora, se continúa en la pantalla de carga (no hay que volver a pagar)
var _loading_dice_done := false   # ya se jugaron los dados de esta pantalla de carga (no se vuelven a ofrecer al continuar)
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
		return in_menu or get_tree().paused or (dice != null and dice.visible) or (casino != null and casino.screen != null) or (lost_screen != null and lost_screen.visible) or (dialogue != null and dialogue.is_active()) or (confirm_box != null and confirm_box.is_open()) or (difficulty_screen != null and difficulty_screen.is_open())
	pad_bridge.process_mode = Node.PROCESS_MODE_ALWAYS   # (el mando tiene que seguir andando con el juego en pausa: si no, el menú de pausa no responde)
	add_child(pad_bridge)
	add_to_group("graphics")
	_set_depth_mode(depth_mode)
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
	_goal_mat = StandardMaterial3D.new()   # el dorado de los bordes del cubo-portal
	_goal_mat.albedo_color = Color(1.0, 0.85, 0.2)
	_goal_mat.emission_enabled = true
	_goal_mat.emission = Color(1.0, 0.8, 0.1)


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
	juice = Juice.new(self)
	juice.attach_flash(layer)
	# La ventana de la partida (arriba a la izquierda): corazones, etapa y claridad (y la racha cuando hay). Lo demás lo cuenta el tabernero.
	hud_panel = HudPanel.new(true)
	layer.add_child(hud_panel)
	lives_hud = hud_panel.lives
	stage_label = hud_panel.stage_label
	clarity_counter = hud_panel.clarity
	var banner_layer := CanvasLayer.new()   # el cartel de la prueba va por encima de los menús: al pausar se ve entero
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
	toast = _label(layer, 3, Color(0.95, 0.93, 0.88))
	toast.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast.align = VoxelLabel.Align.CENTER
	toast.y_offset = 215.0
	toast.plate_alpha = 0.6
	toast.modulate.a = 0.0
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
	# Los dados del tabernero de la pantalla de carga (son parte del juego): la torre se arma al instante, pero al empezar cada torre se ofrecen igual, con "Empezar" ya habilitado.
	if con_dados and dice_always and not _loading_dice_done and not in_menu:
		var mi_epoca := epoch
		generating = true   # (así un guardado en este momento es el de "cargando la torre": no se repiten el casino ni los dados)
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
			_flash(_character_msg(unlocked))
			Sfx.play("item")
	if con_dados:   # (una torre nueva: los reintentos de la anterior no cuentan; al rehacer la misma torre sí)
		run.tower_retries = 0
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
	torre.dificultad = run.dificultad
	torre.pista_permitida = run.dificultad == "facil" and tutorial_index < 0 and not training
	torre.pista_activa = _pista_on and torre.pista_permitida
	torre.pista_cambiada.connect(_torre_pista)
	torre.mov_run = run.movs_extra   # (Pies ligeros y la mejora Aire de más: movimientos de más en cada sala)
	var permitidos := 0   # Sin piedad: movimientos en falso por sala
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
	torre.puede_jugar = func(): return not in_menu and not generating and casino == null and not console_open and not get_tree().paused and (dialogue == null or not dialogue.is_active()) and (lost_screen == null or not lost_screen.visible)
	torre.position = Vector3(-1000, 0, 0)   # lejos de todo lo demás (el casino y el menú no ven la torre)
	torre.checkpoint_alcanzado.connect(_torre_checkpoint)
	torre.torre_completa.connect(_torre_ganada)
	torre.murio.connect(_torre_murio)
	torre.accion_hecha.connect(_torre_accion)
	torre.falsos_cambiaron.connect(_torre_falsos)
	torre.aviso.connect(func(texto: String): _flash(Loc.t(texto)))
	torre.ganancia.connect(_flash_gain)
	torre.profundidad_pedida.connect(func(): _set_depth_mode((depth_mode + 1) % 3))
	torre.portal = _cubo_portal()
	torre.deshacer_pedido.connect(undo_move)
	torre.movimiento_hecho.connect(_tutorial_movimiento)
	torre.camara_usada.connect(_tutorial_camara)
	torre.reintentar_pedido.connect(request_restart)
	add_child(torre)
	hud_layer.visible = true
	banner.text = ""
	if permitidos == 0:
		hud_panel.set_mistakes(0, 0)
	_refresh()
	_loading_dice_done = false
	save_game()
	_announce_trial()
	_descubrir_bloques()


## El cubo-portal del final de la torre (el mismo del juego de siempre: luminoso, con bordes dorados y las ondas arriba), siempre encendido (Farolín cobra en el casino).
func _cubo_portal() -> Node3D:
	goal_mat = ShaderMaterial.new()
	goal_mat.shader = PORTAL_SHADER
	goal_mat.set_shader_parameter("col_a", Color(0.95, 0.78, 0.3))
	goal_mat.set_shader_parameter("col_b", Color(1.0, 0.93, 0.6))
	goal_mat.set_shader_parameter("col_c", Color(1.0, 1.0, 0.92))
	goal_mat.set_shader_parameter("cells", Vector2(5.0, 5.0))
	goal_mat.set_shader_parameter("lit", 1.0)
	return _make_goal_cube()


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


## Sin piedad: lo que quedan de movimientos en falso en la sala (y el aviso si acaba de pasar uno).
func _torre_falsos(quedan: int, permitidos: int, sin_salida: bool, hubo_falso: bool) -> void:
	if torre == null:
		return
	hud_panel.set_mistakes(quedan, permitidos)
	if hubo_falso and quedan >= 0 and permitidos - quedan <= permitidos:
		var cuenta: int = permitidos - quedan
		if cuenta <= permitidos and cuenta > 0:
			Sfx.play("miss")
			juice.flash(Color(0.8, 0.1, 0.15), 0.18, 0.4)
			_flash(Loc.f("¡Sin salida! Movimiento en falso %d de %d", [cuenta, permitidos]) if sin_salida else Loc.f("¡Movimiento en falso! %d de %d", [cuenta, permitidos]))


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


## Llegó al portal de la torre: la claridad pasa al run y sigue el casino (o el final).
func _torre_ganada() -> void:
	_log_sala()
	_log_torre("ganada", "")
	if training:   # (el tutorial: se festeja y pasa solo a la siguiente lección)
		if tutorial_index >= 0:
			if tutorial_locked():   # llegaste, pero te faltan las teclas de la lección: no se pasa
				_flash(Loc.t("Todavía te faltan teclas: prueba todas las de arriba."))
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
	_cosmetico_de_la_torre()
	banner.text = "¡Portal alcanzado!" + ("\n" + _trial_msg if _trial_msg != "" else "")
	if not quick_portal:
		await get_tree().create_timer(1.0).timeout
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


## Al superar las torres de las etapas 5, 10 y 15 en Medio, Difícil o Pesadilla se gana un cosmético (Fácil no da; qué rarezas, según la dificultad).
func _cosmetico_de_la_torre() -> void:
	if run == null or training or tutorial_index >= 0 or stage_number % 5 != 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var c := Cosmetics.roll_por_dificultad(run.dificultad, Profile.owned_cosmetics(), rng)
	if c.is_empty():
		return
	Profile.grant_cosmetic(str(c.id))
	_trial_msg = (_trial_msg + "
" if _trial_msg != "" else "") + Loc.f("¡Cosmético nuevo: %s!", [Loc.t(str(c.name))])


## Se perdió una vida en la torre (la sala ya volvió a empezar): se descuenta la del run, o se termina si no quedaba ninguna.
func _torre_murio(motivo: String) -> void:
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
		_flash(Loc.t(motivo))
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
	lost_screen.show_loss(Loc.t(motivo), run.restart_cost(true), run.can_afford(run.restart_cost(true)), libre, true)
	save_game()


## Premio de un tiro de los dados de la pantalla de carga: claridad (con tope por partida) y Luz.
## Completa `info` con lo que de verdad se dio (`granted`) para que el minijuego lo muestre.
func _on_dice_prize(info: Dictionary) -> void:
	_loading_dice_done = true   # el premio ya está dado (la Luz queda pendiente en el run hasta superar una torre): si se cierra el juego ahora, al continuar no se vuelven a ofrecer los dados
	var granted := 0
	var want := int(info.get("claridad", 0))
	if want > 0 and run != null:
		granted = mini(want, maxi(RunState.DICE_CAP - run.dice_claridad, 0))
		run.dice_claridad += granted
		run.gain(granted)
	info["granted"] = granted
	if int(info.get("luz", 0)) > 0 and run != null:
		run.dice_pending.luz = int(run.dice_pending.luz) + int(info.luz)
	save_game()


## Lo que dieron los dados (la Luz) pasa al perfil: se llama al superar una torre (entrar al casino), al terminar el tutorial y al terminar un run en el que se superó alguna.
func _claim_dice_rewards() -> void:
	if run == null or training:
		return
	var luz := int(run.dice_pending.luz)
	if luz > 0:
		Profile.add_luz(luz)
	run.dice_pending = {"luz": 0}


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


func _apply_stage_look() -> void:
	env.background_color = BG_DARK.lerp(BG_LIGHT, stage_tone())
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
	env.background_color = BG_DARK.lerp(BG_LIGHT, stage_tone())
	env.ambient_light_energy = lerpf(AMBIENT_CASINO_EARLY, AMBIENT_CASINO_LATE, stage_tone())
	env.ambient_light_color = AMBIENT_COLOR_TOWER
	if _sun != null:
		_sun.light_energy = 1.0


## El cubo de salida: un cubo claro y luminoso con bordes dorados y, en la cara de arriba, las ondas del portal (como las puertas del casino).
func _make_goal_cube() -> Node3D:
	var g := Node3D.new()
	g.name = "goal"
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 1.015
	body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.97, 0.86)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.93, 0.7)
	mat.emission_energy_multiplier = 0.9
	mat.roughness = 0.4
	body.material_override = mat
	g.add_child(body)
	for axis in 3:   # los 12 bordes dorados
		for a in [-0.5, 0.5]:
			for b in [-0.5, 0.5]:
				var bar := MeshInstance3D.new()
				var m := BoxMesh.new()
				var size := Vector3.ONE * 0.075
				size[axis] = 1.07
				m.size = size
				bar.mesh = m
				bar.material_override = _goal_mat
				var p := Vector3.ZERO
				p[(axis + 1) % 3] = a
				p[(axis + 2) % 3] = b
				bar.position = p
				g.add_child(bar)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.86, 0.86)
	var top := MeshInstance3D.new()
	top.mesh = quad
	top.material_override = goal_mat
	top.rotation_degrees.x = -90.0
	top.position = Vector3(0, GOAL_TOP_LIFT, 0)
	g.add_child(top)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.6)
	light.omni_range = 3.2
	light.light_energy = 0.6
	light.position = Vector3(0, 0.9, 0)
	g.add_child(light)
	return g


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
	if is_inside_tree() and toast:
		_flash(["Ayuda de profundidad: ninguna", "Ayuda de profundidad: más claro lo cercano", "Ayuda de profundidad: más claro lo cercano + transparencia cercana"][mode])


## Cada cuadro: dónde está el personaje respecto de la cámara (referencia de las ayudas de profundidad).
func _process(delta: float) -> void:
	juice.process(delta)
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


func _flash(msg: String) -> void:
	toast.text = msg
	toast.modulate.a = 1.0
	juice.pop(toast, 1.2)
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 1.4)


## El HUD con la torre: la etapa, la claridad del run más la de la torre, lo que cobrará Farolín, las vidas y las barras de boosts y consumibles.
func _refresh_torre() -> void:
	stage_label.text = Loc.f("Etapa %d/%d%s", [stage_number, Demo.shown_final(FINAL_STAGE), " *" if not trial.is_empty() else ""])
	stage_label.visible = false   # (la etapa y el peaje se ven en el menú de pausa; el HUD muestra los movimientos de la sala)
	hud.text = "Semilla %d   Sala %d/%d   Movimientos %d/%d   Dificultad %s" % [seed_value, torre.t.indice + 1, torre.t.salas.size(), torre.t.movs, torre.t.max_mov(), run.dificultad] if torre.t != null else ""
	var total: int = run.claridad + (torre.t.cosecha.claridad() if torre.t != null else 0)
	var show_toll: bool = not training and tutorial_index < 0 and not (test_mode and not toll_in_tests)
	var next_toll: int = run.toll_after_discounts(RunState.toll_for(stage_number)) if show_toll else 0
	hud_panel.set_toll(0)
	hud_panel.set_moves(torre.t.movs if torre.t != null else 0)
	_info_pausa = [stage_label.text] + ([Loc.f("Peaje %d", [next_toll])] if next_toll > 0 else [])
	_info_pausa_rojo = 1 if next_toll > 0 and total < next_toll else -1
	if total > clarity_counter.value:
		juice.pop(clarity_counter, 1.25)
	clarity_counter.value = total
	_update_perk_label()


var _info_pausa: Array = []   # lo que muestra el menú de pausa a la izquierda: etapa y peaje
var _info_pausa_rojo := -1


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
	if torre == null or in_menu or generating or casino != null or torre.t == null or torre.t.terminada:
		return
	if slot >= run.consumables.size():
		return
	if trial.get("no_items", false):
		_flash(Loc.f("Prueba «%s»: no se pueden usar consumibles", [Loc.t(trial.name)]))
		return
	var id: String = run.consumables[slot]
	if run.item_blocked(id):
		_flash(Loc.t("No funciona en este escenario"))
		return
	if id == "vida_extra":
		if run.add_life():
			run.use_consumable(id)
			_flash(Loc.t("¡Una vida más!"))
			Sfx.play("item")
			_refresh()
			save_game()
		else:
			_flash(Loc.f("Ya tienes las %d vidas", [run.max_lives()]))
		return
	if id == "totem" or id == "soborno":
		_flash(Loc.t("Se usa solo cuando hace falta") if id != "soborno" else Loc.t("Se usa en el casino, frente a Farolín"))
		return
	var r: Dictionary = torre.t.usar_item(id)
	if bool(r.ok):
		run.use_consumable(id)
		_flash(Loc.t(str(r.msg)))
		Sfx.play("item")
		torre.actualizar()
		_refresh()
		save_game()
	else:
		_flash(Loc.t(str(r.msg)))


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
func _character_msg(ids: Array) -> String:
	var parts: Array[String] = []
	for id in ids:
		parts.append(Loc.f("¡Personaje nuevo: %s!", [Loc.t(str(Characters.get_character(str(id)).name))]))
	return Loc.join(parts)


## El portal de la torre lleva al casino: se cambia de cámara y se esconde el HUD de la torre.
func enter_casino(restoring := false) -> void:
	if casino != null:
		return
	if not restoring:
		_claim_dice_rewards()   # (superaste la torre: lo que dieron los dados es tuyo)
	if trial_banner != null:
		trial_banner.clear()
	Music.play("casino")
	if not restoring:
		_bank_claridad()
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
	save_game()


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
	_flash(Loc.t("Perdiste una vida: vuelves a subir la torre"))
	save_game()


## El portal del casino lleva a la torre de la etapa siguiente. Antes se ve el balance del casino (mientras la torre se genera).
func leave_casino() -> void:
	if casino == null or balance_layer != null:
		return
	_leaving_casino = true   # (desde acá el guardado es el de la pantalla de carga de la torre que sigue)
	_loading_dice_done = false
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
			_leave_casino_now())
		return
	_leave_casino_now()


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
	if scenario_id == Scenarios.FREE:   # La Pesadilla: primero se elige la dificultad (gradúa las salas de las 15 etapas)
		difficulty_screen.ask()
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
	run.trial_schedule = Trials.draw_schedule(run.scenario().pool, draw_rng)   # qué prueba toca en cada etapa 3, 6, 9...
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
	if run.scenario_id == Scenarios.FREE:
		for o in DifficultyScreen.OPTIONS:
			if o.id == run.dificultad:
				return Loc.t("%s - %s" % [nombre, o.name])   # (la frase entera está en la tabla: "La Pesadilla - Fácil"...)
	return Loc.t(nombre)


func pause_game() -> void:
	if in_menu or pause_menu.visible:
		return
	get_tree().paused = true
	pause_menu.set_tutorial_lock(tutorial_forced)
	pause_menu.make_room_for_banner(trial_banner != null and trial_banner.active)   # (al pausar el cartel de la prueba se ve entero: el menú sube para no taparlo)
	if trial_banner != null:
		trial_banner.pin()
	pause_menu.set_restart(run.lives, training, casino != null)
	pause_menu.set_title(_titulo_pausa())
	pause_menu.set_info(_info_pausa if torre != null and casino == null else [], _info_pausa_rojo)
	pause_menu.open()
	if trial.get("no_retry", false):
		pause_menu.buttons["reiniciar"].disabled = true   # (la prueba "Todo o nada" no tiene reintentos)
		pause_menu.buttons["reiniciar"].set_label(Loc.t("Reintentar (no en esta prueba)"))


func resume_game() -> void:
	pause_menu.close()
	pause_menu.make_room_for_banner(false)
	if trial_banner != null:
		trial_banner.release()
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
		_flash(Loc.t("En este escenario no se puede deshacer"))
		return
	if in_menu or generating or casino != null or dialogue.is_active():
		return
	if torre.deshacer():
		_flash(Loc.t("Movimiento deshecho"))


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
		run.spend(costo)
		run.note_retry(true)
		lost_screen.hide_screen()
		torre.reiniciar_sala()
		_flash(Loc.t("Reintento gratis: el Tótem te dio otra vida") if con_totem else Loc.t("Reintento: perdiste una vida"))
		_refresh()
		save_game()
		return
	if training:
		restart()
		return
	if trial.get("no_retry", false):
		_flash(Loc.f("Prueba «%s»: no hay reintentos", [Loc.t(trial.name)]))
		return
	if not run.pay_voluntary_retry():
		_flash(Loc.t("No te quedan vidas para reintentar la torre"))
		return
	restart()
	_flash(Loc.t("Reintento: −1 vida"))


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
func _on_item_discarded(item_kind: int, id: String) -> void:
	_flash(Loc.f("Tiraste %s.", [Loc.t(str(Items.get_item(id).get("name", id)))]) + ("" if item_kind == ItemBar.Kind.CONSUMABLE else Loc.t(" Deja de valer desde el próximo intento.")))
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
func dev_tower(stage: int, scenario_id := "", seed := -1) -> String:
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
	run.trial_schedule = Trials.draw_schedule(run.scenario().pool, draw_rng)
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
	if _loading_state():   # pagado el peaje (o generando la torre): se guarda "cargando la torre" para no repetir el casino ni los dados
		var next_stage := mini(stage_number + 1, FINAL_STAGE) if casino != null else stage_number
		SaveGame.write({"run": run.to_dict(), "stage": next_stage, "seed": seed_value, "phase": "loading", "dice_done": _loading_dice_done})
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
		_loading_dice_done = bool(data.get("dice_done", false))
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
