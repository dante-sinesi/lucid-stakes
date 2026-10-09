extends Node3D
## Vista isométrica + entrada. Las reglas viven en tower_logic.gd.

const TowerLogic := preload("res://scripts/tower_logic.gd")
const Gen := preload("res://scripts/tower_gen.gd")
const STEP_TIME := 0.14
const FALL_TIME := 0.08
const PATH_STEP_TIME := 0.07  # segundos por celda cuando el recorrido tiene varias (salto, hielo, caída)
const PATH_MAX_TIME := 1.3
const SILHOUETTE_SHADER := preload("res://shaders/silhouette.gdshader")
const RunState := preload("res://scripts/run_state.gd")
const Controls := preload("res://scripts/controls.gd")
const Graphics := preload("res://scripts/graphics.gd")
const KeyDirs := preload("res://scripts/key_dirs.gd")
const CasinoRules := preload("res://scripts/casino_rules.gd")
const BalanceScreen := preload("res://scripts/casino_balance_screen.gd")
const PadBridge := preload("res://scripts/pad_bridge.gd")
const CasinoScene := preload("res://scripts/casino_scene.gd")
const MainMenu := preload("res://scripts/main_menu.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")
const Settings := preload("res://scripts/settings.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Music := preload("res://scripts/music.gd")
const AudioHub := preload("res://scripts/audio_hub.gd")
const LostScreen := preload("res://scripts/lost_screen.gd")
const Lab := preload("res://scripts/lab.gd")
const Loc := preload("res://scripts/loc.gd")
const Hint := preload("res://scripts/hint.gd")
const Items := preload("res://scripts/items.gd")
const VoxelLabel := preload("res://scripts/voxel_label.gd")
const ItemBar := preload("res://scripts/item_bar.gd")
const ClarityCounter := preload("res://scripts/clarity_counter.gd")
const Compass := preload("res://scripts/compass.gd")
const Juice := preload("res://scripts/juice.gd")
const Tutorial := preload("res://scripts/tutorial.gd")
const Trials := preload("res://scripts/trials.gd")
const Profile := preload("res://scripts/profile.gd")
const Scenarios := preload("res://scripts/scenarios.gd")
const Abilities := preload("res://scripts/abilities.gd")
const DialogueBox := preload("res://scripts/dialogue_box.gd")
const Story := preload("res://scripts/story.gd")
const DiceGame := preload("res://scripts/dice_game.gd")
const Cosmetics := preload("res://scripts/cosmetics.gd")
const Characters := preload("res://scripts/characters.gd")
const RunEndScreen := preload("res://scripts/run_end_screen.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const DevCommands := preload("res://scripts/dev_commands.gd")
const DevConsole := preload("res://scripts/dev_console.gd")
const BlockModels := preload("res://scripts/block_models.gd")
const BLOCK_SHADER := preload("res://shaders/voxel_block.gdshader")
const SILHOUETTE_ALPHA := 0.55  # opacidad de la silueta del personaje cuando algo lo tapa
const PURIFY_TIME := 0.35    # segundos que dura el rebote de un bloque al purificarse
## Cámara:
## La cámara se mueve con el mouse (arrastrar: girar y inclinar; rueda: zoom). Q y E vuelven al ángulo isométrico (girando 90 grados).
const PITCH_NORMAL := -35.264   # ángulo isométrico
const SIZE_NORMAL := 17.0
const SIZE_MIN := 6.0
const SIZE_MAX := 36.0
const PITCH_MIN := -86.0
const PITCH_MAX := -10.0
const TOP_VIEW_PITCH := -52.0    # desde este ángulo (mirando desde arriba) se ocultan las capas que tapan al personaje
const MOUSE_SENS := 0.28         # grados por píxel
const ZOOM_FACTOR := 1.1
const ARROW_SPEED := 110.0       # grados por segundo al girar la cámara con las flechas
## Ayudas de profundidad (tecla V): 0 ninguna, 1 atenuación, 2 atenuación + transparencia cercana.
const DEPTH_STRENGTH := 0.11
const XRAY_RADIUS := 1.3
const TOWER_ROWS := 25         # filas (pisos) de cada etapa
const MAX_GEN_THREADS := 4     # semillas que se generan a la vez como máximo
const FINAL_STAGE := 27        # etapas del juego: al pasar la última se termina
## Fondo y bloques se aclaran de una etapa a la siguiente (no dentro de una misma etapa).
const BG_DARK := Color(0.05, 0.04, 0.09)
const BG_LIGHT := Color(0.80, 0.84, 0.95)
const AMBIENT_TOWER := 0.7        # luz ambiente de las torres (el aclarado por etapa va en el tinte de los bloques)
const AMBIENT_CASINO_EARLY := 1.0  # luz ambiente del casino en la primera etapa (una taberna en penumbra, pero que se lee)
const AMBIENT_CASINO_LATE := 1.5   # luz ambiente del casino en la última etapa
const TALL_TOWER := 16         # desde esta altura la cámara sigue al personaje en vez de mirar el centro de la torre
const PACE_NAMES := {"fast": "rápido", "normal": "normal", "slow": "lento"}
## Generación al jugar: búsqueda más liviana que la completa (tarda menos; las etapas difíciles se generan fuera de línea).
const GEN_OPTS := {"tries": 6, "climb": 0.5, "budget_states": 25000, "max_states": 2000}

var logic
var stage_start            # copia de la torre generada, para reintentar sin regenerar
var solution: Array = []   # camino óptimo de la torre generada
var generating := false
var max_height := 0        # altura máxima alcanzada en este intento (no baja si el jugador baja)
var block_nodes := {}
var player_node: Node3D
var goal_nodes: Array[Node3D] = []
var pivot: Node3D
var cam: Camera3D
var yaw_target := 45.0
var busy := false
var seed_value := 1
var stage_number := 1      # etapa (1..27) que se genera: define dificultad, ritmo de caída y mecánicas
var profile := {}
var hud: Control              # texto de depuración (semilla, contadores...): sólo se ve con F2 en las compilaciones de desarrollo
var debug_hud := false
var stage_label: Control     # "Etapa 5/27" y el piso en que estás
var collapse_label: Control  # "Caída en N": cuántos movimientos faltan para que caiga la fila de abajo
var streak_label: Control    # multiplicador de la racha (sólo con racha)
var banner: Control
var toast: Control
var gain_label: Control
var _mesh_corrupt: SphereMesh
var _goal_mesh: BoxMesh
var _goal_mat: StandardMaterial3D
var _mesh_light: SphereMesh
var anim_tween: Tween
var cam_tween: Tween
var cam_pitch := PITCH_NORMAL
var cam_zoom := SIZE_NORMAL
var _last_top_view := false
var pitch_node: Node3D
var depth_mode := 1
var run := RunState.new()   # estado del run: claridad, boosts, consumibles
var casino                  # escena del casino mientras se está en él
var hud_layer: CanvasLayer
var quick_portal := false   # pruebas: pasar al casino sin esperar
var banked := false         # la claridad de esta torre ya se sumó al run
var quit_game_override := false  # pruebas: quit_game no cierra el proceso
var test_mode_jobs := false  # pruebas: generar igual la etapa siguiente de antemano
var test_mode := false      # pruebas: sin menú, torres chicas y sin generar la etapa siguiente de antemano
var tower_rows := TOWER_ROWS
var in_menu := false
var main_menu
var pause_menu
var menu_layer: CanvasLayer
var env: Environment
var training := false       # tutorial: lecciones sueltas, sin casino ni claridad en juego, reintento gratis y pista (tecla P)
var trial := {}              # prueba (etapa especial) de la torre actual: {} si es una etapa común (ver trials.gd)
var run_new_abilities: Array[String] = []   # habilidades persistentes ganadas en este run (se muestran al terminar)
var trial_label: Control    # "* Prueba: Niebla" arriba al centro
var _trial_msg := ""         # resultado de la prueba superada (se muestra al llegar al portal)
var _gen_failures := 0
var lost_screen              # pantalla de derrota: Reintentar o Salir al menú
var dice_always := true      # los dados del tabernero se ven en toda pantalla de carga, aunque la torre ya esté lista (las pruebas lo apagan)
var casino_balance := true   # al salir del casino se ve el balance (las pruebas lo apagan: salir pasa directo a la torre)
var balance_layer: CanvasLayer   # donde vive el balance mientras se ve
var _tick_t := 0.0           # tic-tac de las bombas a la vista
var _tick_tock := false
var _trial_banner := ""      # texto del anuncio de la prueba (para borrarlo solo si sigue siendo ese)
var tutorial_index := -1    # lección del tutorial en curso (-1 = no se está en el tutorial)
var lab_active := false     # modo dev: el laboratorio de estaciones (lab.gd)
var lab_station := 0
var lab_perks: Array[String] = []   # boosts que se activaron con `perk` (valen en el laboratorio hasta salir)
var lab_abilities: Array[String] = []   # habilidades persistentes que se activaron con `ability` (en el laboratorio no valen las del perfil real)
var lab_collapse := false           # la caída de la fila de abajo (comando `collapse`)
var lab_signs: Array[Node3D] = []
var dice                      # los dados del tabernero: el minijuego de la pantalla de carga
var _model: Node3D          # el animalito (y su copia de silueta): se vuelve a armar cuando cambia el personaje o la ropa
var _ghost: Node3D
var _sun: DirectionalLight3D
var dialogue                 # cuadro de diálogo del tabernero (historia y consejos del tutorial)
var story_kind := ""         # "intro" o "outro" mientras se está en una sala de historia del tutorial
var tutorial_label: Control # cartel con la lección
var hint_on := false
var hint_label: Control
var perk_label: Control
var _moved_blocks: Array[Node3D] = []   # bloques que se movieron en la jugada actual (para el rebote al llegar)
var _fell := 0              # celdas que bajó el personaje en la jugada actual
var juice                # animaciones de sensación de juego (estirar, polvo, temblor, destellos)
var compass              # rosa de los vientos (qué eje mueve cada tecla)
var clarity_counter       # [ícono] claridad (la del run más la juntada en esta torre)
var dev_console           # consola del modo dev (sólo en compilaciones de desarrollo; null en las release)
var console_open := false
var run_end             # pantalla de fin de run
var run_over := false
var action_log: Array[String] = []   # acciones del intento actual ("dx,dz,modo"): se imprime al perder, para poder reproducir un caso
var attempt_dirty := false  # el intento actual de la torre ya empezó (hubo un movimiento o se usó un consumible)
var left_bar              # barra de consumibles (izquierda)
var right_bar             # barra de boosts (derecha)
var item_tip: Control     # descripción del ítem bajo el mouse
var _hint_thread: Thread
var _hint_seq := 0          # sube con cada cambio de estado: una pista calculada para un estado viejo se descarta
var _hint_res := {}         # última pista calculada (para volver a escribirla si cambia la cámara)
var epoch := 0              # sube al volver al menú: las generaciones en curso se descartan
var _jobs: Array = []       # hilos de generación: la torre de la etapa actual y la de la siguiente (se genera mientras se juega)


func _ready() -> void:
	if test_mode:
		casino_balance = false
		dice_always = false
	Settings.apply()   # idioma, ventana, resolución y volumen del jugador
	AudioHub.instance()   # el audio (efectos y música) se prepara desde el arranque
	_register_globals()
	var pad_bridge := PadBridge.new()   # el mando se traduce a las teclas de cada acción
	pad_bridge.nav_mode = func() -> bool:
		return in_menu or get_tree().paused or (casino != null and casino.screen != null) or (lost_screen != null and lost_screen.visible)
	add_child(pad_bridge)
	add_to_group("graphics")
	_set_depth_mode(depth_mode)
	_build_environment()
	_build_hud()
	_build_fx_assets()
	_build_menus()
	Graphics.apply_global()   # sombras, escala de render, antialiasing y tope de cuadros del jugador
	_build_dev_console()
	if test_mode:
		SaveGame.path = "user://test_save.json"   # las pruebas no tocan la partida real
		Profile.path = "user://test_profile.json"   # ni el perfil
		tower_rows = 8
		stage_number = 6
		new_tower(randi() % 100000)
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


## Pone en marcha los gráficos del jugador en lo que es de esta escena (grupo "graphics"; ver graphics.gd).
func apply_graphics() -> void:
	if _sun != null:
		Graphics.apply_to_sun(_sun)
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.visible = bool(Graphics.value("silhouette"))
	if logic != null:
		_refresh()   # las partículas de los bloques cambian con el ajuste


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	hud_layer = layer
	add_child(layer)
	var story_layer := CanvasLayer.new()   # el cuadro de diálogo va por encima de todo (incluso del casino y los menús)
	story_layer.layer = 30
	add_child(story_layer)
	dialogue = DialogueBox.new()
	dialogue.finished.connect(_on_dialogue_finished)
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
	# HUD del jugador (arriba a la izquierda): etapa y piso, claridad, cuenta para que caiga la fila de abajo y racha.
	stage_label = _label(layer, 3, Color(0.97, 0.95, 0.9))
	stage_label.position = Vector2(16, 12)
	stage_label.plate_alpha = 0.55
	clarity_counter = ClarityCounter.new(4.0)   # la claridad no es texto: es el ícono girando y el número
	clarity_counter.name = "claridad"
	clarity_counter.position = Vector2(22, 104)
	clarity_counter.plate_alpha = 0.55
	layer.add_child(clarity_counter)
	collapse_label = _label(layer, 3, Color(1.0, 0.9, 0.7))
	collapse_label.position = Vector2(16, 168)
	collapse_label.plate_alpha = 0.55
	trial_label = _label(layer, 3, Color(1.0, 0.85, 0.35))
	trial_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trial_label.align = VoxelLabel.Align.CENTER
	trial_label.y_offset = 12.0
	trial_label.plate_alpha = 0.6
	trial_label.visible = false
	streak_label = _label(layer, 3, Color(1.0, 0.93, 0.5))
	streak_label.position = Vector2(16, 208)
	streak_label.plate_alpha = 0.55
	streak_label.visible = false
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
	compass.view_source = func(): return Vector2(pivot.rotation_degrees.y, pitch_node.rotation_degrees.x) if pivot != null else Vector2(45, PITCH_NORMAL)
	compass.dir_source = _dir_for_screen
	layer.add_child(compass)
	tutorial_label = _label(layer, 2.5, Color(1.0, 0.97, 0.85))
	tutorial_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_label.align = VoxelLabel.Align.CENTER
	tutorial_label.wrap_px = 900
	tutorial_label.y_offset = 14.0
	tutorial_label.plate_alpha = 0.7
	tutorial_label.visible = false
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
	left_bar.min_y = 262.0   # debajo de la etapa, la claridad, la cuenta de la fila de abajo y la racha
	left_bar.tip = item_tip
	left_bar.slot_pressed.connect(use_consumable_slot)
	right_bar = ItemBar.new()
	right_bar.name = "barra_boosts"
	layer.add_child(right_bar)
	right_bar.edge = 1
	right_bar.tip = item_tip
	_bind_bars()
	perk_label = _label(layer, 2, Color(0.8, 0.95, 0.85))
	perk_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	perk_label.align = VoxelLabel.Align.RIGHT
	perk_label.y_offset = 104.0
	perk_label.margin = 120.0 + Compass.SPAN
	perk_label.plate_alpha = 0.55
	hint_label = _label(layer, 4, Color(0.55, 1.0, 0.65))
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint_label.align = VoxelLabel.Align.CENTER
	hint_label.y_offset = 150.0
	hint_label.plate_alpha = 0.6
	hint_label.visible = false
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


func new_tower(s: int) -> void:
	if generating:
		return
	generating = true
	seed_value = s
	trial = run.trial_at(stage_number) if not training else {}
	profile = Gen.profile_for_stage(stage_number, trial, run.scenario())
	var my_epoch := epoch
	var job := _find_job(stage_number)  # ¿ya se generó (o se está generando) la de esta etapa mientras se jugaba la anterior?
	if job.is_empty():
		job = _start_job(stage_number, s)
	var res: Dictionary = await _await_job(job)
	if my_epoch != epoch:  # se volvió al menú mientras se generaba
		generating = false
		return
	if not res.ok:   # (muy raro) se prueba solo con otra semilla; si falla varias veces, se avisa
		generating = false
		_gen_failures += 1
		if _gen_failures > 5:
			banner.text = "No se pudo generar la torre.\nVolvé al menú (Esc) y probá de nuevo."
			return
		banner.text = "Generando otra torre..."
		await get_tree().create_timer(0.3).timeout
		if my_epoch == epoch:
			new_tower(randi() % 100000)
		return
	_gen_failures = 0
	seed_value = res.seed_used
	stage_start = res.logic
	solution = res.path
	print("torre %d (etapa %d): filas %s, N=%d, %d ms" % [seed_value, stage_number, res.rows, res.collapse_every, res.ms])
	run.stage = stage_number
	run.max_stage = maxi(run.max_stage, stage_number)
	if not training:
		var unlocked: Array = Profile.on_stage_reached(stage_number)   # la etapa 10 desbloquea al conejito
		if not unlocked.is_empty():
			_flash(_character_msg(unlocked))
			Sfx.play("item")
	run.tower_retries = 0
	restart()
	generating = false
	save_game()
	_prefetch_next_stage()
	_announce_trial()


## Un hilo del trabajo: genera la torre con SU semilla (`s + k * 7919`). El primero que la saca la deja en la caja y frena a los demás.
func _generate_worker(k: int, s: int, prof: Dictionary, rows: int, token: Array, box: Dictionary, mutex: Mutex) -> void:
	var opts := GEN_OPTS.duplicate()
	opts["pace"] = prof.pace
	opts["combo"] = prof.combo
	opts["bias"] = prof.bias   # sesgo de los tipos de bloque (escenario y prueba)
	opts["cancel_token"] = token
	var seed_k := s + k * 7919
	var res := Gen.generate_stage(seed_k, rows, prof.difficulty, opts)
	if res.ok:
		mutex.lock()
		if box.res == null:
			res["seed_used"] = seed_k
			box.res = res
			token[0] = true   # ya hay torre: las otras semillas paran
		mutex.unlock()


## Cuántas semillas se generan a la vez (la mitad de los procesadores, de 1 a 4): como el tiempo de una torre varía mucho de una semilla
## a otra, esperar a la primera que sale es bastante más rápido que probar de a una.
func _gen_thread_count() -> int:
	return clampi(OS.get_processor_count() / 2, 1, MAX_GEN_THREADS)


func _start_job(stage: int, s: int) -> Dictionary:
	var tr: Dictionary = run.trial_at(stage) if not training else {}
	var prof := Gen.profile_for_stage(stage, tr, run.scenario())
	var token := [false]
	var box := {"res": null}
	var mutex := Mutex.new()
	var threads: Array[Thread] = []
	for k in _gen_thread_count():
		var th := Thread.new()
		th.start(_generate_worker.bind(k, s, prof, tower_rows, token, box, mutex))
		threads.append(th)
	var job := {"stage": stage, "thread": threads[0], "threads": threads, "token": token, "box": box, "t0": Time.get_ticks_msec(), "done": false}
	_jobs.append(job)
	return job


## ¿Algún hilo del trabajo sigue generando? (Los trabajos de prueba traen un solo hilo en `thread`.)
func _job_alive(job: Dictionary) -> bool:
	if job.has("threads"):
		for th in job.threads:
			if th.is_alive():
				return true
		return false
	return job.thread.is_alive()


## Espera a que terminen todos los hilos y devuelve la torre (o {"ok": false} si ninguna semilla salió).
func _job_join(job: Dictionary) -> Dictionary:
	if job.has("threads"):
		for th in job.threads:
			if th.is_started():
				th.wait_to_finish()
		var res = job.box.res
		return res if res != null else {"ok": false}
	return job.thread.wait_to_finish()


func _find_job(stage: int) -> Dictionary:
	for job in _jobs:
		if job.stage == stage:
			return job
	return {}


func _await_job(job: Dictionary) -> Dictionary:
	while _job_alive(job):  # el juego sigue respondiendo mientras se genera
		if not dice.visible and not job.done:   # pantalla de carga: se abre directo con los dados del tabernero (sin ningún cartel antes)
			dice.open()
		banner.text = ""
		await get_tree().process_frame
	if dice_always and not dice.visible and not job.done:   # los dados van siempre (son parte del juego): si la torre ya estaba lista, se abren igual con Empezar habilitado
		dice.open()
	if dice.visible:   # la torre está lista: el minijuego no te saca, se habilita "Empezar" (el tiro en curso termina antes de cerrar)
		dice.set_ready(true)
		while dice.visible:
			await get_tree().process_frame
	if job.done:  # cancelado mientras esperábamos
		return {"ok": false}
	job.done = true
	var res: Dictionary = _job_join(job)
	_jobs.erase(job)
	return res


## Premio de un tiro de los dados de la pantalla de carga: claridad (con tope por partida), Luz y, con los 5 aciertos, un cosmético.
## Completa `info` con lo que de verdad se dio (`granted`, `cosmetic_name`) para que el minijuego lo muestre.
func _on_dice_prize(info: Dictionary) -> void:
	var granted := 0
	var want := int(info.get("claridad", 0))
	if want > 0 and run != null:
		granted = mini(want, maxi(RunState.DICE_CAP - run.dice_claridad, 0))
		run.dice_claridad += granted
		run.gain(granted)
	info["granted"] = granted
	if int(info.get("luz", 0)) > 0:
		Profile.add_luz(int(info.luz))
	var weights: Dictionary = info.get("cosmetic", {})
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if not weights.is_empty() and rng.randf() < float(info.get("cosmetic_chance", 1.0)):   # el cosmético sale con la rareza que toca (y que todavía no tengas)
		var c := Cosmetics.roll(weights, Profile.owned_cosmetics(), rng)
		if c.is_empty():   # ya los tiene todos: claridad grande en su lugar
			if run != null:
				run.gain(100)
			info["granted"] = int(info.get("granted", 0)) + 100
		else:
			Profile.grant_cosmetic(c.id)
			info["cosmetic_name"] = c.name
			info["cosmetic_rarity"] = c.rarity


## Mientras se juega la etapa actual se genera la siguiente en otro hilo (cada torre es nueva: nada pregenerado).
func _prefetch_next_stage() -> void:
	if training or (test_mode and not test_mode_jobs) or stage_number >= FINAL_STAGE or not _find_job(stage_number + 1).is_empty():
		return
	_start_job(stage_number + 1, randi() % 100000)


func _cancel_jobs() -> void:
	Gen.cancel = true
	for job in _jobs:
		if not job.done:
			job.done = true
			_job_join(job)
	_jobs.clear()
	Gen.cancel = false


## Vuelve a la torre generada tal como empezó.
func restart() -> void:
	if lost_screen != null:
		lost_screen.hide_screen()
	Music.play("torre")
	if anim_tween:
		anim_tween.kill()
	busy = false
	for n in block_nodes.values():
		n.queue_free()
	for n in goal_nodes:
		n.queue_free()
	block_nodes.clear()
	goal_nodes.clear()
	logic = stage_start.clone()
	var perks: Array = run.boosts.duplicate()   # los boosts del run valen en cada etapa, y también las habilidades persistentes y la prueba
	if not lab_active:
		perks.append_array(Abilities.perks_for(Profile.owned_abilities()))
	if lab_active:   # en el laboratorio sólo valen las habilidades y perks que se prendieron a mano (las del perfil real no)
		perks.append_array(lab_perks)
		perks.append_array(Abilities.perks_for(lab_abilities))
		logic.player = Lab.station_start(lab_station)
		logic.last_safe = logic.player
		if lab_collapse:
			logic.collapse_every = 6
			logic.moves_to_collapse = 6
	if trial.get("no_streak", false):
		perks.append("sin_racha")
	logic.apply_perks(perks)
	if run.collapse_bonus > 0:   # mejora permanente "Aire de más"
		logic.collapse_every += run.collapse_bonus
		logic.moves_to_collapse += run.collapse_bonus
	_apply_stage_look()
	max_height = logic.player.y
	banked = false
	attempt_dirty = false
	action_log.clear()
	_ensure_rig()
	_apply_skin()
	_apply_camera(0.0)
	for id in logic.positions:
		block_nodes[id] = _make_block(logic.positions[id])
	player_node.position = _player_pos()
	player_node.rotation.y = 0.0
	juice.reset_body()
	_build_goal()
	_build_lab_signs()
	banner.text = ""
	_refresh()
	_update_hint()


func _w(c: Vector3i) -> Vector3:
	return Vector3(c.x + 0.5, c.y + 0.5, c.z + 0.5)


## Colgado: el cuerpo se arrima al bloque del que se agarra.
func _player_pos() -> Vector3:
	return _w(logic.player) + Vector3(logic.hang_dir) * 0.22


func _ensure_rig() -> void:
	if pivot:
		return
	pivot = Node3D.new()
	pivot.position = _rig_center()
	pivot.rotation_degrees.y = yaw_target
	add_child(pivot)
	pitch_node = Node3D.new()
	pitch_node.rotation_degrees.x = cam_pitch
	pivot.add_child(pitch_node)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = cam_zoom
	cam.far = 200.0
	cam.position = Vector3(0, 0, 40)
	pitch_node.add_child(cam)
	cam.make_current()

	player_node = Node3D.new()
	juice.body = Node3D.new()   # el cuerpo cuelga de los pies: así estirar y aplastar no lo separa del piso
	juice.body.position = Vector3(0, -0.5, 0)
	player_node.add_child(juice.body)
	add_child(player_node)
	_apply_skin()


## Arma el personaje elegido con su gorro y su prenda. Lleva una copia (la silueta, ver shaders/silhouette.gdshader) que sólo se dibuja
## donde algo lo tapa: así se ve a través del core y las plataformas.
func _apply_skin() -> void:
	if juice == null or juice.body == null:
		return
	for n in [_model, _ghost]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_model = Characters.build(Profile.character(), Profile.equipped_hat(), Profile.equipped_outfit())
	_ghost = Characters.build(Profile.character(), Profile.equipped_hat(), Profile.equipped_outfit(), true)
	juice.body.add_child(_model)
	juice.body.add_child(_ghost)
	_ghost.visible = bool(Graphics.value("silhouette"))


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m


## 0 en la primera etapa y 1 en la última: cuánto se aclararon el fondo y los bloques.
func stage_tone() -> float:
	return clampf(float(stage_number - 1) / float(FINAL_STAGE - 1), 0.0, 1.0)


## Los bloques corruptos y los especiales traen colores oscuros en el modelo: se los aclara con la etapa.
func _stage_tint() -> Color:
	var k := lerpf(1.0, 1.9, stage_tone())
	return Color(k, k, k)


func _apply_stage_look() -> void:
	env.background_color = BG_DARK.lerp(BG_LIGHT, stage_tone())
	env.ambient_light_energy = AMBIENT_TOWER


## El casino se ilumina más a medida que avanza el run (sucio y en penumbra al principio, de mármol luminoso al final).
func _apply_casino_light() -> void:
	env.background_color = BG_DARK.lerp(BG_LIGHT, stage_tone())
	env.ambient_light_energy = lerpf(AMBIENT_CASINO_EARLY, AMBIENT_CASINO_LATE, stage_tone())


func _make_block(c: Vector3i) -> MeshInstance3D:
	var id: int = logic.blocks[c]
	var m := MeshInstance3D.new()
	var kind: int = logic.kind_at(c)
	var model_kind: int = BlockModels.CORE if logic.fixed.has(c) else kind  # el core tiene su propio modelo
	var t := stage_tone()
	var base := Color.from_hsv(lerpf(0.62, 0.08, t), lerpf(0.65, 0.18, t), lerpf(0.85, 1.0, t))  # color de la etapa (sólo bloques normales)
	var mat := ShaderMaterial.new()
	mat.shader = BLOCK_SHADER
	mat.set_shader_parameter("roughness_value", 0.15 if kind == TowerLogic.Kind.ICE else 0.8)
	m.material_override = mat
	m.position = _w(c)
	m.set_meta("kind", kind)
	m.set_meta("model_kind", model_kind)
	m.set_meta("base", base)
	m.set_meta("purity", 1.0 if logic.purified.has(id) else 0.0)  # 0 = corrupto, 1 = purificado
	m.set_meta("warn", false)
	var tag := _tag_for(kind)
	if tag != "":
		var lab := Label3D.new()
		lab.name = "tag"
		lab.text = tag
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.no_depth_test = true  # se lee aunque algo lo tape
		lab.font_size = 56
		lab.pixel_size = 0.012
		lab.outline_size = 14
		lab.position = Vector3(0, 0.78, 0)
		m.add_child(lab)
	var fx := _make_fx()
	fx.name = "fx"
	m.add_child(fx)
	add_child(m)
	_style_block(m, id)
	return m


## Modelo (minibloques) de un bloque según su tipo y estado.
func _model_for(node: MeshInstance3D, id: int) -> ArrayMesh:
	var kind: int = node.get_meta("kind")
	var model_kind: int = node.get_meta("model_kind")
	var state := BlockModels.State.PURE if float(node.get_meta("purity")) >= 0.5 else BlockModels.State.CORRUPT
	if kind == TowerLogic.Kind.BOMB:  # una bomba purificada es una bomba desactivada
		state = BlockModels.State.CORRUPT if logic.bomb_timer.has(id) else BlockModels.State.DEFUSED
	return BlockModels.mesh_for(model_kind, state)


## Aspecto de un bloque: su modelo (corrupto o purificado), el tinte, y el brillo (aviso de caída, bomba, purificado).
func _style_block(node: MeshInstance3D, id: int) -> void:
	var mat := node.material_override as ShaderMaterial
	var kind: int = node.get_meta("kind")
	var pure: bool = float(node.get_meta("purity")) >= 0.5
	var model := _model_for(node, id)
	if node.mesh != model:
		node.mesh = model
	# Los bloques normales purificados toman el color de su altura; el resto ya trae sus colores en el modelo.
	var normal_pure: bool = pure and kind == TowerLogic.Kind.NORMAL and not logic.fixed.has(logic.positions[id])
	mat.set_shader_parameter("tint", node.get_meta("base") if normal_pure else _stage_tint())
	var glow := Color.BLACK
	var energy := 0.0
	if node.get_meta("warn"):  # la fila base está por caer
		glow = Color(1.0, 0.1, 0.1)
		energy = 1.0
	elif kind == TowerLogic.Kind.BOMB and logic.bomb_timer.has(id):
		glow = Color(0.9, 0.1, 0.05)
		energy = 0.35
	elif pure:  # purificado: emana luz
		glow = (node.get_meta("base") as Color).lightened(0.3) if normal_pure else Color(1.0, 0.95, 0.7)
		energy = 0.22 if normal_pure else 0.12
	mat.set_shader_parameter("glow_color", glow)
	mat.set_shader_parameter("glow_energy", energy)


## Partículas que salen de la cara de arriba de cada bloque: oscuras si está corrupto, de luz si está purificado.
func _make_fx() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 3
	p.lifetime = 1.6
	p.local_coords = false
	p.fixed_fps = 20
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.42, 0.02, 0.42)
	p.direction = Vector3.UP
	p.spread = 30.0
	p.gravity = Vector3(0, 0.25, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.2
	p.mesh = _mesh_corrupt
	p.position = Vector3(0, 0.5, 0)
	p.emitting = false
	return p


func _build_fx_assets() -> void:
	_goal_mesh = BoxMesh.new()
	_goal_mesh.size = Vector3(0.9, 0.05, 0.9)
	_goal_mat = _mat(Color(1.0, 0.85, 0.2))
	_goal_mat.emission_enabled = true
	_goal_mat.emission = Color(1.0, 0.8, 0.1)
	_mesh_corrupt = _fx_mesh(Color(0.5, 0.15, 0.7, 0.75))
	_mesh_light = _fx_mesh(Color(1.0, 0.95, 0.55, 0.9))


func _fx_mesh(color: Color) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 0.045
	m.height = 0.09
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	return m


## Al purificarse un bloque: cambia al modelo completo y de color con un rebote, y suelta un destello de luz.
func _play_purify(node: MeshInstance3D, id: int) -> void:
	node.set_meta("purity", 1.0)
	_style_block(node, id)
	node.scale = Vector3.ONE * 1.2
	node.create_tween().tween_property(node, "scale", Vector3.ONE, PURIFY_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var b := CPUParticles3D.new()
	b.one_shot = true
	b.amount = maxi(int(14 * Graphics.particle_factor()), 1)
	b.lifetime = 0.8
	b.explosiveness = 1.0
	b.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	b.emission_sphere_radius = 0.25
	b.direction = Vector3.UP
	b.spread = 80.0
	b.initial_velocity_min = 0.8
	b.initial_velocity_max = 1.8
	b.gravity = Vector3(0, -1.2, 0)
	b.mesh = _mesh_light
	add_child(b)
	b.position = node.position + Vector3(0, 0.5, 0)
	b.emitting = Graphics.particle_factor() > 0.0
	get_tree().create_timer(1.2).timeout.connect(b.queue_free)


func _flash_gain(text: String) -> void:
	gain_label.text = text
	gain_label.modulate.a = 1.0
	juice.pop(gain_label)
	create_tween().tween_property(gain_label, "modulate:a", 0.0, 1.8)


## Texto que se muestra sobre un tipo de bloque: sólo la bomba lleva su cuenta (se actualiza en _refresh).
func _tag_for(kind: int) -> String:
	return "?" if kind == TowerLogic.Kind.BOMB else ""


func _build_goal() -> void:
	if lab_active:
		return   # el laboratorio no tiene meta
	# La baldosa-portal va sobre el bloque meta (ver _refresh) y lo sigue si se lo mueve.
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.15, 4.0, 0.15)
	beam.mesh = bm
	var bmat := _mat(Color(1.0, 0.85, 0.2, 0.45))
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = bmat
	beam.position = _w(logic.goal_cell) + Vector3(0, 2.0, 0)
	add_child(beam)
	goal_nodes.append(beam)


func _unhandled_input(event: InputEvent) -> void:
	if dev_console != null and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		dev_console.toggle()   # F1: consola del modo dev
		return
	if dev_console != null and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		debug_hud = not debug_hud   # F2: textos de depuración (semilla, contadores); sólo en compilaciones de desarrollo
		hud.visible = debug_hud
		return
	if console_open:
		return
	if in_menu:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or Controls.hit(event, "pausa")):
		pause_game()
		return
	if casino != null:  # en el casino manda su propia escena
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		_camera_mouse(event)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var mode: int = TowerLogic.Mode.MOVE
	if Controls.modifier_held(event, "empujar"):
		mode = TowerLogic.Mode.GRAB
	elif Controls.held("colgarse"):
		mode = TowerLogic.Mode.HANG
	match Controls.action_of(event):
		"vista_izquierda": _reset_view(1)
		"vista_derecha": _reset_view(-1)
		"reintentar": request_restart()
		"profundidad": _set_depth_mode((depth_mode + 1) % 3)
		"pista": toggle_hint()
		"consumible_1": use_consumable_slot(0)
		"consumible_2": use_consumable_slot(1)
		"consumible_3": use_consumable_slot(2)
		"consumible_4": use_consumable_slot(3)
		"zoom_mas": zoom_view(1.0 / ZOOM_FACTOR)
		"zoom_menos": zoom_view(ZOOM_FACTOR)
		"mover_adelante": _act(1, 1, mode)
		"mover_derecha": _act(1, -1, mode)
		"mover_atras": _act(-1, -1, mode)
		"mover_izquierda": _act(-1, 1, mode)
		_:
			match event.keycode:
				KEY_N:
					if tutorial_index >= 0:
						_tutorial_next()
					elif dev_console != null:   # (sólo en compilaciones de desarrollo)
						new_tower(randi() % 100000)
				KEY_ENTER, KEY_KP_ENTER:
					if tutorial_index >= 0 and logic != null and logic.won:
						_tutorial_next()
				KEY_BRACKETRIGHT:
					if dev_console != null:
						_change_stage(1)
				KEY_BRACKETLEFT:
					if dev_console != null:
						_change_stage(-1)


## Cambia de etapa (1..27) y genera una torre nueva con su dificultad, ritmo de caída y mecánicas.
func _change_stage(step: int) -> void:
	if generating:
		return
	stage_number = clampi(stage_number + step, 1, FINAL_STAGE)
	new_tower(randi() % 100000)


func _rig_center() -> Vector3:
	if lab_active:   # el laboratorio es larguísimo: la cámara siempre sigue al personaje
		return _w(logic.player) + Vector3(0, 0.5, 0)
	var center: Vector3
	if logic.goal_y > TALL_TOWER:  # torre alta: la cámara sube con el personaje
		center = Vector3(logic.size.x * 0.5, clampf(float(logic.player.y) + 1.5, 6.0, float(logic.goal_y) - 2.0), logic.size.y * 0.5)
	else:
		center = Vector3(logic.size.x * 0.5, logic.goal_y * 0.5, logic.size.y * 0.5)
	# Con el zoom cerca, la cámara (y el giro) se centra en el personaje; con el zoom normal o lejos, en la torre.
	var t := clampf((SIZE_NORMAL - cam_zoom) / (SIZE_NORMAL - SIZE_MIN), 0.0, 1.0)
	var focus := center.lerp(_w(logic.player), t)
	if tutorial_index >= 0:   # en el tutorial el cuadro del tabernero tapa abajo: la torre se sube un poco en la pantalla
		focus.y -= 1.4
	return focus


## Aplica la cámara: sigue al personaje en vertical (torres altas) y usa el ángulo y el zoom actuales (con animación si duration > 0).
func _apply_camera(duration: float) -> void:
	if cam_tween:
		cam_tween.kill()
	if duration <= 0.0:
		pivot.rotation_degrees.y = yaw_target
		pitch_node.rotation_degrees.x = cam_pitch
		cam.size = cam_zoom
		pivot.position = _rig_center()
		_update_top_view()
		return
	cam_tween = create_tween().set_parallel(true)
	cam_tween.tween_property(pivot, "rotation_degrees:y", yaw_target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam_tween.tween_property(pitch_node, "rotation_degrees:x", cam_pitch, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam_tween.tween_property(cam, "size", cam_zoom, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam_tween.tween_property(pivot, "position", _rig_center(), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam_tween.chain().tween_callback(_update_top_view)


## Q / E: vuelve al ángulo isométrico (también la inclinación y el zoom) y gira 90 grados desde la diagonal más cercana.
func _reset_view(step: int) -> void:
	var base := roundf((yaw_target - 45.0) / 90.0) * 90.0 + 45.0
	yaw_target = base + 90.0 * step
	cam_pitch = PITCH_NORMAL
	cam_zoom = SIZE_NORMAL
	_show_hint(_hint_res)
	_apply_camera(0.35)


## Mouse: arrastrar gira y inclina la cámara; la rueda acerca y aleja.
func _camera_mouse(event: InputEvent) -> void:
	if pivot == null:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_view(1.0 / ZOOM_FACTOR)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_view(ZOOM_FACTOR)
	elif event is InputEventMouseMotion and (event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)) != 0:
		orbit_view(event.relative)


## Las flechas giran (izquierda y derecha) e inclinan (arriba y abajo) la cámara, igual que arrastrar con el mouse.
func _arrow_camera(delta: float) -> void:
	if in_menu or casino != null or console_open or pivot == null or logic == null or get_tree().paused:
		return
	var ax := int(Controls.held("camara_derecha")) - int(Controls.held("camara_izquierda"))
	var ay := int(Controls.held("camara_abajo")) - int(Controls.held("camara_arriba"))
	if ax != 0 or ay != 0:
		orbit_view(Vector2(ax, ay) * ARROW_SPEED * delta / MOUSE_SENS)


## Gira (x) e inclina (y) la cámara según un desplazamiento del mouse en píxeles.
func orbit_view(rel: Vector2) -> void:
	yaw_target -= rel.x * MOUSE_SENS
	cam_pitch = clampf(cam_pitch - rel.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)
	if cam_tween:
		cam_tween.kill()
	pivot.rotation_degrees.y = yaw_target
	pitch_node.rotation_degrees.x = cam_pitch
	_update_top_view()
	_show_hint(_hint_res)


## Acerca (factor < 1) o aleja (factor > 1) la cámara.
func zoom_view(factor: float) -> void:
	cam_zoom = clampf(cam_zoom * factor, SIZE_MIN, SIZE_MAX)
	cam.size = cam_zoom
	if logic != null:
		pivot.position = _rig_center()


## ¿Se está mirando desde arriba? Entonces las capas que están sobre el personaje lo taparían y se ocultan.
func is_top_view() -> bool:
	return cam_pitch <= TOP_VIEW_PITCH


## ¿Se dibuja el bloque de esa celda? Depende del límite de capas (vista desde arriba) y de las reglas de la prueba (niebla, oscuridad).
func _node_visible(pos: Vector3i) -> bool:
	return pos.y <= _visible_limit() and Trials.visible_from(trial, pos, logic.player)


func _visible_limit() -> int:
	return logic.player.y + 1 if is_top_view() else 1 << 20   # la torre se ve entera (sólo desde arriba se ocultan las capas que tapan)


func _update_top_view() -> void:
	var tv := is_top_view()
	if tv == _last_top_view:
		return
	_last_top_view = tv
	if logic != null:
		for id in block_nodes:
			block_nodes[id].visible = _node_visible(logic.positions[id])


## Distancia a la cámara (en la dirección en que mira) de un punto del mundo: más chica = más cerca.
func view_depth(world_pos: Vector3) -> float:
	return -(cam.global_transform.affine_inverse() * world_pos).z


static var _globals_registered := false  # los parámetros globales se registran una sola vez por proceso


func _register_globals() -> void:
	if _globals_registered:
		return
	_globals_registered = true
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
	_poll_hint()
	juice.process(delta)
	_bomb_ticking(delta)
	_arrow_camera(delta)
	if cam == null or player_node == null:
		return
	var v: Vector3 = cam.global_transform.affine_inverse() * player_node.global_position
	RenderingServer.global_shader_parameter_set("depth_focus", -v.z)
	RenderingServer.global_shader_parameter_set("focus_view", v)


## Tic-tac de las bombas: mientras haya una con cuenta a la vista suena cada vez más rápido a medida que se le acaba el tiempo.
func _bomb_ticking(delta: float) -> void:
	if logic == null or in_menu or casino != null or logic.won or logic.lost or cam == null or get_tree().paused or generating:
		return
	if logic.bomb_timer.is_empty():
		return
	_tick_t += delta
	var soonest := 99
	for id in logic.bomb_timer:
		var n: Node3D = block_nodes.get(id)
		if n != null and n.visible and cam.is_position_in_frustum(n.global_position):
			soonest = mini(soonest, int(logic.bomb_timer[id]))
	if soonest == 99:
		return
	var interval := clampf(0.22 + 0.11 * float(soonest), 0.3, 1.0)
	if _tick_t >= interval:
		_tick_t = 0.0
		_tick_tock = not _tick_tock
		Sfx.play("tic" if _tick_tock else "tac", 1.0, -9.0 + clampf(float(8 - soonest), 0.0, 6.0))


## Traduce una diagonal de pantalla (sx derecha, sy arriba) a la dirección de grilla más cercana.
func _dir_for_screen(sx: float, sy: float) -> Vector3i:
	var d := KeyDirs.dir_for(yaw_target, sx, sy)   # ver key_dirs.gd: W es la dirección que más sube en la pantalla
	return Vector3i(d.x, 0, d.y)


func _act(sx: float, sy: float, mode: int) -> void:
	_apply(_dir_for_screen(sx, sy), mode)


func _apply(dir: Vector3i, mode: int) -> void:
	if generating or busy or logic.won or logic.lost:
		return
	var was_y: int = logic.player.y
	var bombs_before: Array = logic.bomb_timer.keys()
	var res: Dictionary = logic.try_action(dir, mode)
	if res.ok:
		action_log.append("%d,%d,%d" % [dir.x, dir.z, mode])
		run.moves += 1
		if not attempt_dirty:
			attempt_dirty = true
			save_game()
	if not res.ok:
		player_node.rotation.y = atan2(dir.x, dir.z)
		_flash(res.msg)
		return
	var face: Vector3i = logic.hang_dir if logic.hang_dir != Vector3i.ZERO else dir
	player_node.rotation.y = atan2(face.x, face.z)
	_action_sound(mode, was_y)
	_check_defused(bombs_before)
	_animate()


## El sonido de la acción que se acaba de hacer: pisada, empujar, tirar, trepar, colgarse, resbalar... o lo que pasó (caída, pinchos, bomba).
func _action_sound(mode: int, was_y: int) -> void:
	if logic.lost:
		var why: String = logic.lost_reason
		Sfx.play("boom" if why.begins_with("Explotó") else ("spikes" if why.contains("pinchos") else "fall"))
		return
	if logic.won:
		Sfx.play("portal")
		return
	if logic.trap_broke:
		Sfx.play("crumble")
	elif logic.moves_to_collapse == logic.collapse_every and logic.moves_made > 0 and logic.floor_y > 0:
		Sfx.play("rumble")   # la fila de abajo acaba de caer
	elif mode == TowerLogic.Mode.GRAB:
		Sfx.play("pull" if logic.trail.size() > 1 else "push")
	elif mode == TowerLogic.Mode.HANG or logic.hang_dir != Vector3i.ZERO:
		Sfx.play("hang")
	elif logic.trail.size() > 3 and logic.player.y > was_y + 1:
		Sfx.play("boing")
	elif logic.trail.size() > 2 and logic.kind_at(logic.player + Vector3i(0, -1, 0)) != TowerLogic.Kind.NORMAL and logic.player.y == was_y:
		Sfx.play("slide")
	elif logic.player.y > was_y:
		Sfx.play("climb")
	else:
		Sfx.play("step")
	if not logic.last_purified.is_empty():
		Sfx.play("purify", minf(0.9 + 0.06 * logic.streak, 1.8))


## La explosión de una bomba: destello naranja que crece, chispas y trocitos que salen disparados, y sacudón de pantalla.
func _play_explosion(cell: Vector3i) -> void:
	var pos := _w(cell)
	var flash := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	flash.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color = Color(1.0, 0.7, 0.2, 0.9)
	fm.no_depth_test = true
	flash.material_override = fm
	flash.position = pos
	flash.scale = Vector3.ONE * 0.3
	add_child(flash)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(flash, "scale", Vector3.ONE * 3.2, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(fm, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(flash.queue_free)
	for spec in [[70, Color(1.0, 0.75, 0.2), 0.14, 6.0], [40, Color(0.25, 0.1, 0.1), 0.2, 4.0]]:   # llamas y escombros oscuros
		var p := CPUParticles3D.new()
		p.amount = maxi(int(float(spec[0]) * Graphics.particle_factor()), 1)
		p.one_shot = true
		p.explosiveness = 1.0
		p.lifetime = 0.9
		p.local_coords = false
		p.direction = Vector3.UP
		p.spread = 180.0
		p.initial_velocity_min = float(spec[3]) * 0.4
		p.initial_velocity_max = float(spec[3])
		p.gravity = Vector3(0, -9.0, 0)
		var box := BoxMesh.new()
		box.size = Vector3.ONE * float(spec[2])
		var bmat := StandardMaterial3D.new()
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bmat.albedo_color = spec[1]
		box.material = bmat
		p.mesh = box
		p.position = pos
		add_child(p)
		p.emitting = Graphics.particle_factor() > 0.0
		get_tree().create_timer(1.5).timeout.connect(p.queue_free)
	juice.flash(Color(1.0, 0.6, 0.2), 0.5, 0.5)
	juice.add_shake(1.2)


## Si alguna bomba que tenía cuenta dejó de tenerla sin caerse (la pisaste o la desarmaste), suena la mecha que se apaga.
func _check_defused(before: Array) -> void:
	if logic == null or logic.lost:
		return
	for id in before:
		if not logic.bomb_timer.has(id) and logic.positions.has(id):
			Sfx.play("defuse")
			return


func _animate() -> void:
	busy = true
	if logic.exploded:
		_play_explosion(logic.explosion_cell)
	for id in logic.removed_ids:
		_drop_into_void(id)
	if logic.perk_msg != "":
		_flash(logic.perk_msg)
	for id in logic.last_purified:
		var pn = block_nodes.get(id)
		if pn != null:
			_play_purify(pn, id)
	if logic.last_gain > 0:
		var mult: float = logic.streak_mult(logic.streak)
		_flash_gain(Loc.f("+%d claridad", [logic.last_gain]) + (Loc.f("   racha ×%.1f", [mult]) if logic.streak >= 2 else ""))
	_refresh()
	anim_tween = create_tween().set_parallel(true)
	_moved_blocks.clear()
	for id in logic.positions:
		var bn: Node3D = block_nodes[id]
		if bn.position.distance_to(_w(logic.positions[id])) > 0.01:
			_moved_blocks.append(bn)
		_tween_to(bn, _w(logic.positions[id]))
	_fell = maxi(0, int(round(player_node.position.y - _player_pos().y)))
	juice.step(_fell)
	Characters.step_anim(_model, STEP_TIME)
	_tween_player()
	if logic.goal_y > TALL_TOWER or cam_zoom < SIZE_NORMAL:
		anim_tween.tween_property(pivot, "position", _rig_center(), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	anim_tween.chain().tween_callback(_on_anim_done)


## El jugador va del punto de partida al final. Si el recorrido tiene varias celdas (salto de catapulta,
## deslizamiento por hielo, caída) se anima celda por celda, para que se vea cómo sube, avanza y cae.
func _tween_player() -> void:
	var trail: Array[Vector3i] = logic.trail
	if trail.size() <= 2:
		_tween_to(player_node, _player_pos())
		return
	var pts: Array[Vector3] = [player_node.position]
	for i in range(1, trail.size()):
		pts.append(_w(trail[i]))
	pts[pts.size() - 1] = _player_pos()  # al final, colgado o parado
	var seg := minf(PATH_STEP_TIME, PATH_MAX_TIME / (pts.size() - 1))
	anim_tween.tween_method(func(t: float) -> void: player_node.position = _path_at(pts, t), 0.0, 1.0, seg * (pts.size() - 1))


## Punto de la poligonal a lo largo de t (0 = primer punto, 1 = último).
func _path_at(pts: Array[Vector3], t: float) -> Vector3:
	var u := clampf(t, 0.0, 1.0) * (pts.size() - 1)
	var i := mini(int(u), pts.size() - 2)
	return pts[i].lerp(pts[i + 1], u - i)


## Los bloques que caen al vacío se hunden en la oscuridad y desaparecen.
func _drop_into_void(id: int) -> void:
	var n: Node3D = block_nodes.get(id)
	if n == null:
		return
	block_nodes.erase(id)
	var tw := n.create_tween()
	tw.tween_property(n, "position:y", n.position.y - 14.0, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)
	juice.spin_fall(n)


func _tween_to(node: Node3D, target: Vector3) -> void:
	var dist := node.position.distance_to(target)
	if dist < 0.01:
		return
	var t := STEP_TIME + FALL_TIME * maxf(0.0, dist - 1.0)
	anim_tween.tween_property(node, "position", target, t) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Al empezar una prueba se anuncia su regla unos segundos.
func _announce_trial() -> void:
	if trial.is_empty() or training or logic == null:
		return
	_trial_banner = Loc.f("PRUEBA: %s\n%s", [Loc.t(trial.name), Loc.t(trial.desc)])
	banner.text = _trial_banner
	if quick_portal or test_mode:
		return
	var idx := epoch
	await get_tree().create_timer(3.0).timeout
	if idx == epoch and logic != null and not logic.won and not logic.lost and banner.text == _trial_banner:
		banner.text = ""


func _on_anim_done() -> void:
	busy = false
	_check_tutorial_marker()
	juice.land(_fell)
	for bn in _moved_blocks:
		juice.settle(bn)
	_moved_blocks.clear()
	if logic.lost:
		juice.add_shake(0.5)
		juice.flash(Color(0.8, 0.1, 0.15), 0.4, 0.6)
		juice.tumble()
	elif logic.won:
		juice.gold_burst(player_node.position)
		juice.flash(Color(1.0, 0.9, 0.5), 0.35, 0.7)
		juice.zoom_punch(0.05)
	_update_hint()
	if logic.won:
		if training:
			if tutorial_index >= 0:   # lección completada: un instante de festejo y pasa sola a la siguiente
				var idx := tutorial_index
				banner.text = "¡Terminaste el tutorial!" if idx + 1 >= Tutorial.count() else "¡Bien!"
				if not quick_portal:
					await get_tree().create_timer(1.3).timeout
				if tutorial_index == idx and logic != null and logic.won:
					await _tutorial_next()
				return
			banner.text = "¡Completaste la torre!"
			_update_hint()
			return
		_bank_claridad()
		if stage_number >= FINAL_STAGE:
			_finish_game()
			return
		banner.text = "¡Portal alcanzado!" + ("\n" + _trial_msg if _trial_msg != "" else "")
		if not quick_portal:
			await get_tree().create_timer(1.0).timeout
		if logic != null and logic.won and casino == null:
			enter_casino()
	elif logic.lost and trial.get("no_retry", false) and not training:
		end_run(false, Loc.f("Fallaste la prueba «%s»: %s.", [Loc.t(trial.name), Loc.t(logic.lost_reason).to_lower()]))
	elif logic.lost:
		var cost := run.restart_cost()
		lost_screen.show_loss(Loc.t(logic.lost_reason), cost, run.can_afford(cost), training)
		# Registro para reproducir el caso (queda en el archivo de log de Godot): semilla, etapa y todas las acciones.
		print("PERDIDA (%s): semilla=%d etapa=%d acciones=%s" % [logic.lost_reason, seed_value, stage_number, ";".join(action_log)])


func _flash(msg: String) -> void:
	toast.text = msg
	toast.modulate.a = 1.0
	juice.pop(toast, 1.2)
	create_tween().tween_property(toast, "modulate:a", 0.0, 1.4)


func _refresh() -> void:
	var state := "colgado" if logic.hang_dir != Vector3i.ZERO else "de pie"
	var prof_text := ("ENTRENAMIENTO   " if training else "") + "Etapa %d/%d (ritmo %s)" % [stage_number, FINAL_STAGE, PACE_NAMES.get(profile.get("pace", "normal"), "normal")]
	if lab_active:
		trial_label.visible = false
		stage_label.text = "LABORATORIO\n%d. %s" % [lab_station + 1, Lab.STATIONS[lab_station].name]
		var falls: bool = logic.collapse_every < 1000
		collapse_label.visible = falls
		if falls:
			collapse_label.text = Loc.f("Cae en %d", [logic.moves_to_collapse])
		streak_label.visible = false
		hud.text = "LABORATORIO   estación %d/%d: %s" % [lab_station + 1, Lab.count(), Lab.STATIONS[lab_station].id]
	elif tutorial_index >= 0:
		trial_label.visible = false
		stage_label.text = Loc.f("Tutorial\nLección %d/%d", [tutorial_index + 1, Tutorial.count()])
		collapse_label.visible = false
		streak_label.visible = false
		hud.text = "TUTORIAL   Lección %d/%d: %s" % [tutorial_index + 1, Tutorial.count(), Tutorial.lessons()[tutorial_index].title]
	else:
		stage_label.text = Loc.f("Etapa %d/%d%s\nPiso %d/%d", [stage_number, FINAL_STAGE, " *" if not trial.is_empty() else "", maxi(logic.player.y - 1, 0), logic.goal_y - 1])
		var next_text := run.next_trial_text(stage_number)
		trial_label.visible = not trial.is_empty() or next_text != ""
		if not trial.is_empty():
			trial_label.text = Loc.f("* Prueba: %s\n%s", [Loc.t(trial.name), Loc.t(trial.desc)])
			trial_label.color = Color(1.0, 0.85, 0.35)
		elif next_text != "":
			trial_label.text = next_text
			trial_label.color = Color(0.85, 0.82, 0.95)
		var has_fall: bool = logic.collapse_every < 1000
		collapse_label.visible = has_fall
		if has_fall:
			var n: int = logic.moves_to_collapse
			collapse_label.text = Loc.f("Cae en %d", [n])
			collapse_label.color = Color(1.0, 0.35, 0.3) if n <= 2 else Color(1.0, 0.9, 0.7)
		streak_label.visible = logic.streak >= 2
		if streak_label.visible:
			streak_label.text = Loc.f("Racha ×%.1f", [logic.streak_mult(logic.streak)])
		hud.text = prof_text + "\nCaída de la fila base en %d (cada %d)    Altura %d/%d    Movimientos %d    %s\nRacha %d (×%.1f)    Mejor racha %d    Purificados %d    Semilla %d" % [
		logic.moves_to_collapse, logic.collapse_every, logic.player.y, logic.goal_y, logic.moves_made, state,
		logic.streak, logic.streak_mult(logic.streak), logic.best_streak, logic.purified_count, seed_value]
	var total: int = run.claridad + logic.claridad
	if total > clarity_counter.value:
		juice.pop(clarity_counter, 1.25)
	clarity_counter.value = total
	_update_perk_label()
	# Aviso: la fila base brilla en rojo cuando el próximo movimiento la hace caer.
	var warn: bool = logic.moves_to_collapse <= 1
	max_height = maxi(max_height, logic.player.y)
	for id in block_nodes:
		var node: MeshInstance3D = block_nodes[id]
		var pos: Vector3i = logic.positions[id]
		var cur_kind: int = logic.kind_at(pos)
		if node.get_meta("kind") != cur_kind:  # un consumible cambió el tipo (hielo a roca, catapulta de bolsillo)
			node.set_meta("kind", cur_kind)
			node.set_meta("model_kind", BlockModels.CORE if logic.fixed.has(pos) else cur_kind)
		# Mirando desde arriba se ocultan las capas que están por encima del nivel del personaje (son las que tapan).
		node.visible = _node_visible(pos)
		node.set_meta("warn", warn and pos.y == logic.floor_y)
		_style_block(node, id)
		if node.get_meta("kind") == TowerLogic.Kind.BOMB:
			var lab: Label3D = node.get_node("tag")
			if logic.bomb_timer.has(id):
				lab.text = str(logic.bomb_timer[id])
				# Cuenta activa (roja) cuando el jugador está en su fila; congelada (gris) si no.
				lab.modulate = Color(1.0, 0.25, 0.2) if pos.y == logic.player.y else Color(0.75, 0.75, 0.75)
			else:
				lab.text = "✓"  # desactivada por purificación
				lab.modulate = Color(0.5, 1.0, 0.55)
		# Meta: el bloque-portal (goal_block) lleva la baldosa dorada y el haz de luz, que lo siguen si se lo mueve.
		# Sin bloque-portal (torres de prueba) cualquier bloque de la capa superior vale y lleva baldosa.
		var is_top: bool = (id == logic.goal_block) if logic.goal_block >= 0 else (pos.y == logic.goal_y - 1 and not logic.fixed.has(pos))
		var tile: Node = node.get_node_or_null("goal")
		if is_top and tile == null:
			var gt := MeshInstance3D.new()
			gt.name = "goal"
			gt.mesh = _goal_mesh
			gt.material_override = _goal_mat
			gt.position = Vector3(0, 0.49, 0)
			node.add_child(gt)
			tile = gt
		if is_top and logic.goal_block >= 0 and not goal_nodes.is_empty():
			goal_nodes[0].position = _w(pos) + Vector3(0, 2.5, 0)
			goal_nodes[0].visible = node.visible  # el rayo se ve sólo cuando se ve el portal
		if tile != null:
			tile.visible = is_top
		# Partículas: sólo en los bloques con la cara de arriba libre y cerca del jugador.
		var fx: CPUParticles3D = node.get_node("fx")
		var fx_radius := Graphics.block_particles_radius()
		fx.emitting = fx_radius >= 0 and node.visible and absi(pos.y - logic.player.y) <= fx_radius and not logic.blocks.has(pos + Vector3i(0, 1, 0))
		var want_mesh: SphereMesh = _mesh_light if logic.purified.has(id) else _mesh_corrupt
		if fx.mesh != want_mesh:
			fx.mesh = want_mesh


## La claridad que se juntó en la torre pasa al run (una sola vez por torre).
func _bank_claridad() -> void:
	if banked:
		return
	banked = true
	run.stage = stage_number
	run.towers_cleared += 1
	var gained := int(round(logic.claridad * float(trial.get("mult", 1.0))))
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
		_trial_msg = Loc.f("¡Prueba superada!   +%d de claridad extra\n%s", [gained - logic.claridad, rw.text])
		var new_chars: Array = Profile.on_trial_cleared()   # superar una prueba puede desbloquear personajes
		if not new_chars.is_empty():
			_trial_msg = Loc.join([_trial_msg, _character_msg(new_chars)])
			Sfx.play("item")


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
	Music.play("casino")
	if not restoring:
		_bank_claridad()
	casino = CasinoScene.new()
	casino.position = Vector3(500, 0, 0)  # lejos de la torre: la cámara ortogonal del casino no ve nada de ella
	add_child(casino)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	casino.setup(run, rng)
	_apply_casino_light()
	casino.left.connect(leave_casino)
	casino.changed.connect(save_game)
	hud_layer.visible = false
	banner.text = ""
	_prefetch_next_stage()   # la torre siguiente se genera mientras se está en el casino (no-op si ya venía generándose)
	save_game()


## El portal del casino lleva a la torre de la etapa siguiente. Antes se ve el balance del casino (mientras la torre se genera).
func leave_casino() -> void:
	if casino == null or balance_layer != null:
		return
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
	Music.play("torre")
	casino.queue_free()
	casino = null
	if cam != null:
		cam.make_current()
	hud_layer.visible = true
	stage_number = mini(stage_number + 1, FINAL_STAGE)
	run.stage = stage_number
	new_tower(randi() % 100000)


# --- menús ------------------------------------------------------------------------------------------------------

func _build_menus() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 100
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu_layer)
	main_menu = MainMenu.new()
	main_menu.new_game.connect(start_game)
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
	pause_menu.abandon_run.connect(func():
		resume_game()
		end_run(false, "Abandonaste el run."))
	pause_menu.to_main_menu.connect(open_main_menu)
	pause_menu.quit_game.connect(quit_game)
	pause_menu.language_changed.connect(_on_language_changed)
	menu_layer.add_child(pause_menu)
	run_end = RunEndScreen.new()
	run_end.new_game.connect(func():   # "Nueva partida" del fin de run: se elige el escenario otra vez
		open_main_menu()
		main_menu.show_panel("escenarios"))
	run_end.to_menu.connect(open_main_menu)
	menu_layer.add_child(run_end)
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
		pause_menu.set_restart_cost(run.restart_cost(), training)
		pause_menu.open()
		pause_menu.show_options(true)
		if trial.get("no_retry", false):
			pause_menu.buttons["reiniciar"].disabled = true
			pause_menu.buttons["reiniciar"].set_label(Loc.t("Reintentar (no en esta prueba)"))


func open_main_menu() -> void:
	_close_balance()
	lab_active = false
	_clear_lab_signs()
	if lost_screen != null:
		lost_screen.hide_screen()
	Music.play("menu")
	save_game()   # (no hace nada si no hay un run en juego)
	epoch += 1
	_cancel_jobs()
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
	in_menu = true
	hud_layer.visible = false
	main_menu.set_continue(SaveGame.peek_stage())
	main_menu.open()
	# Con el menú abierto el procesador está libre: si lo más probable es una partida nueva (no hay nada que continuar),
	# se va generando la torre de la etapa 1 para que "Nueva partida" arranque casi sin espera.
	if not test_mode and SaveGame.peek_stage() <= 0 and _find_job(1).is_empty():
		_start_job(1, randi() % 100000)


## "Nueva partida": run nuevo desde la etapa 1 en el escenario elegido (se paga su entrada con Luz; si no alcanza, se juega La Pesadilla).
func start_game(scenario_id := Scenarios.FREE) -> void:
	if not Profile.pay_entry(scenario_id):
		scenario_id = Scenarios.FREE
	main_menu.visible = false
	in_menu = false
	run = RunState.new()
	run.scenario_id = scenario_id
	var draw_rng := RandomNumberGenerator.new()
	draw_rng.randomize()
	run.trial_schedule = Trials.draw_schedule(run.scenario().pool, draw_rng)   # qué prueba toca en cada etapa 3, 6, 9...
	run_new_abilities.clear()
	Profile.apply_to_run(run)   # habilidades persistentes y reglas del escenario
	_bind_bars()
	_set_training(false)
	run_over = false
	run_end.visible = false
	stage_number = 1
	run.stage = 1
	hud_layer.visible = true
	new_tower(randi() % 100000)


func pause_game() -> void:
	if in_menu or pause_menu.visible:
		return
	get_tree().paused = true
	pause_menu.set_restart_cost(run.restart_cost(), training)
	pause_menu.open()
	if trial.get("no_retry", false):
		pause_menu.buttons["reiniciar"].disabled = true   # (la prueba "Todo o nada" no tiene reintentos)
		pause_menu.buttons["reiniciar"].set_label(Loc.t("Reintentar (no en esta prueba)"))


func resume_game() -> void:
	pause_menu.close()
	get_tree().paused = false


func quit_game() -> void:
	save_game()
	epoch += 1
	_cancel_jobs()
	if not quit_game_override:
		get_tree().quit()


## Se pasó la última etapa.
func _finish_game() -> void:
	banner.text = "¡Escapaste de la pesadilla!"
	if not quick_portal:
		await get_tree().create_timer(2.5).timeout
	if not in_menu and logic != null and logic.won:
		end_run(true)


## Reintentar la torre cuesta claridad (gratis en el entrenamiento). Si no te alcanza, el run termina.
func request_restart() -> void:
	if in_menu or logic == null or generating or casino != null:
		return
	if training:
		restart()
		return
	if trial.get("no_retry", false):
		_flash(Loc.f("Prueba «%s»: no hay reintentos", [Loc.t(trial.name)]))
		return
	var cost := run.restart_cost()
	if not run.can_afford(cost):
		end_run(false, Loc.f("No te alcanza la claridad para reintentar la torre (cuesta %d).", [cost]))
		return
	run.spend(cost)
	run.note_retry()
	restart()
	_flash(Loc.f("Reintento: −%d de claridad", [cost]) if cost > 0 else Loc.t("Reintento gratis: el seguro lo cubre"))


## Termina el run y muestra el resumen.
func end_run(victory: bool, reason := "") -> void:
	if run_over:
		return
	if lost_screen != null:
		lost_screen.hide_screen()
	Music.play("menu")
	Sfx.play("win" if victory else "lose")
	run_over = true
	epoch += 1
	_close_balance()
	_cancel_jobs()
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
	var luz := Profile.record_run(run, victory)   # la Luz y las estadísticas pasan al perfil
	if victory and not training:   # escapar da una habilidad persistente del escenario (o Luz si ya las tenés todas)
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
	run_end.show_summary(run, victory, reason, luz, Profile.luz(), run_new_abilities.duplicate())


# --- modo entrenamiento -----------------------------------------------------------------------------------------

func _set_training(on: bool) -> void:
	training = on
	if not on:
		lab_active = false
		if dialogue != null:
			dialogue.hide_box()
		story_kind = ""
		if tutorial_index >= 0:
			cam_zoom = SIZE_NORMAL   # las lecciones usan su propio zoom
		tutorial_index = -1
		if tutorial_label != null:
			tutorial_label.visible = false
	if clarity_counter != null:
		clarity_counter.visible = not on
	hint_on = false
	_hint_seq += 1
	_hint_res = {}
	if hint_label != null:
		hint_label.visible = false


## Tutorial: lecciones armadas a mano (tutorial.gd), sin casino ni claridad en juego; con P se ve la mejor jugada.
## `skip_intro`: salta la escena de la taberna (las pruebas, o quien quiera empezar directo en una lección).
func start_tutorial(index := 0, skip_intro := false) -> void:
	lab_active = false
	_cancel_jobs()   # (la torre de la etapa 1 que se venía generando en el menú no sirve acá)
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
	add_child(casino)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	casino.setup(run, rng)
	casino.input_locked = true   # no se camina mientras habla
	casino.story_message.connect(func(t): dialogue.show_lines([t], Story.SPEAKER, false))
	casino.left.connect(_on_story_left)
	_apply_casino_light()
	dialogue.show_lines(lines, Story.SPEAKER, true)


func _on_dialogue_finished() -> void:
	if story_kind == "intro" and casino != null:   # terminó de contar la historia: ahora hay que ir a la puerta de atrás
		casino.input_locked = false
		casino.show_exit_arrow(true)
	elif story_kind == "outro":   # terminó el cierre: el tutorial se acabó
		open_main_menu()


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


func _load_lesson() -> void:
	var lesson: Dictionary = Tutorial.lessons()[tutorial_index]
	var my_epoch := epoch
	logic = null
	banner.text = ""
	tutorial_label.text = "%s\n%s" % [lesson.title, lesson.text]
	tutorial_label.visible = false   # (las lecciones las dice el tabernero en el cuadro de diálogo)
	dialogue.hide_box()
	if lesson.has("generated"):   # la última lección es una torre generada de verdad, chica
		tower_rows = lesson.generated
		cam_zoom = lesson.zoom
		await new_tower(randi() % 100000)   # (mientras se genera está la pantalla de los dados: el tabernero habla recién después, así no la tapa)
		tower_rows = TOWER_ROWS
		if my_epoch == epoch and tutorial_index >= 0:
			dialogue.show_lines([Story.lesson_say(str(lesson.id), str(lesson.text))], Story.SPEAKER, false)
		return
	dialogue.show_lines([Story.lesson_say(str(lesson.id), str(lesson.text))], Story.SPEAKER, false)
	profile = {}
	seed_value = 0
	solution = []
	stage_start = Tutorial.build(tutorial_index)
	cam_zoom = lesson.zoom
	run.stage = 1
	restart()
	generating = false
	if my_epoch != epoch:
		return


func _tutorial_next() -> void:
	if tutorial_index < 0 or generating:
		return
	if tutorial_index + 1 >= Tutorial.count():
		_open_story_room(Story.OUTRO_STAGE, Story.outro(), "outro")   # el tabernero te recibe en el salón de piedra
		return
	tutorial_index += 1
	await _load_lesson()


## En las lecciones con casilla marcada, se completan al dejar un bloque encima.
func _check_tutorial_marker() -> void:
	if tutorial_index < 0 or logic == null or logic.won or logic.lost:
		return
	var lesson: Dictionary = Tutorial.lessons()[tutorial_index]
	if lesson.has("marker") and logic.blocks.has(lesson.marker):
		logic.won = true


func toggle_hint() -> void:
	if not training:
		return
	hint_on = not hint_on
	_hint_seq += 1
	if hint_on:
		_update_hint()
	else:
		hint_label.visible = false
		_hint_res = {}


## Pide la pista del estado actual (en un hilo: resolver tarda un par de segundos).
func _update_hint() -> void:
	if not training or not hint_on:
		return
	_hint_seq += 1
	_hint_res = {}
	if logic == null or logic.won or logic.lost or generating:
		hint_label.visible = false
		return
	hint_label.text = "Pista: calculando..."
	hint_label.visible = true
	_start_hint_thread()


func _start_hint_thread() -> void:
	if _hint_thread != null:
		return  # hay un cálculo en curso: al terminar _poll_hint ve que quedó viejo y lanza otro
	var snap = logic.clone()
	var seq := _hint_seq
	_hint_thread = Thread.new()
	_hint_thread.start(func() -> Dictionary:
		var r: Dictionary = Hint.best_move(snap)
		r["seq"] = seq
		return r)


func _poll_hint() -> void:
	if _hint_thread == null or _hint_thread.is_alive():
		return
	var res: Dictionary = _hint_thread.wait_to_finish()
	_hint_thread = null
	if not hint_on or logic == null:
		return
	if res.get("seq", -1) != _hint_seq:  # el estado cambió mientras se calculaba
		if not logic.won and not logic.lost and not generating:
			_start_hint_thread()
		return
	_hint_res = res
	_show_hint(res)


func _show_hint(res: Dictionary) -> void:
	if hint_label == null or not hint_on or res.is_empty():
		return
	hint_label.visible = true
	if not res.get("ok", false):
		hint_label.text = "Sin pista: la torre quedó en un estado sin salida (R: reintentar)"
		return
	hint_label.text = Loc.join([Loc.t("Pista: "), Hint.describe(res.mode, res.dir, _key_for_dir)], "")


## Letra (W, A, S o D) que mueve hacia `dir` con la cámara actual.
func _key_for_dir(dir: Vector3i) -> String:
	for k in [["W", 1.0, 1.0], ["D", 1.0, -1.0], ["S", -1.0, -1.0], ["A", -1.0, 1.0]]:
		if _dir_for_screen(k[1], k[2]) == dir:
			return k[0]
	return "?"


func _exit_tree() -> void:
	if _hint_thread != null:
		_hint_thread.wait_to_finish()
		_hint_thread = null


# --- boosts y consumibles en la torre -------------------------------------------------------------------------------

func _item_name(id: String) -> String:
	return Items.get_item(id).get("name", id)


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
	perk_label.text = (Loc.f("Freno: %d movimientos", [logic.collapse_pause])) if logic != null and logic.collapse_pause > 0 else ""


## Usa el consumible del casillero `slot` (teclas 1, 2 y 3).
func use_consumable_slot(slot: int) -> void:
	if in_menu or generating or busy or logic == null or logic.won or logic.lost or casino != null:
		return
	if slot >= run.consumables.size():
		return
	if trial.get("no_items", false):
		_flash(Loc.f("Prueba «%s»: no se pueden usar consumibles", [Loc.t(trial.name)]))
		return
	var id: String = run.consumables[slot]
	var bombs_before: Array = logic.bomb_timer.keys()
	var res: Dictionary = logic.use_item(id)
	_check_defused(bombs_before)
	if res.get("msg", "") != "":
		_flash(res.msg)
	if res.get("ok", false):
		run.use_consumable(id)
		attempt_dirty = true
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


## Comando goto_end: el jugador aparece sobre el bloque-portal de la torre actual y se gana (lo que lleva al casino).
func dev_goto_end() -> String:
	if in_menu or logic == null:
		return "No hay una torre en juego"
	if casino != null:
		return "Ya estás en el casino"
	if generating:
		return "Esperá: se está generando la torre"
	if logic.won or logic.lost:
		return "La torre ya terminó (R para reintentarla)"
	var cell: Vector3i = logic.goal_cell
	if logic.goal_block >= 0 and logic.positions.has(logic.goal_block):
		cell = logic.positions[logic.goal_block] + Vector3i.UP
	logic.hang_dir = Vector3i.ZERO
	logic.player = cell
	logic.trail.clear()
	logic.trail.append(cell)
	logic.won = true
	player_node.position = _player_pos()
	max_height = maxi(max_height, cell.y)
	_refresh()
	_on_anim_done()   # banca la claridad y pasa al casino (o avisa que se completó, en entrenamiento)
	return "Teletransportado al portal"


## Carteles 3D del laboratorio (uno por estación).
func _clear_lab_signs() -> void:
	for n in lab_signs:
		if is_instance_valid(n):
			n.queue_free()
	lab_signs.clear()


func _build_lab_signs() -> void:
	_clear_lab_signs()
	if not lab_active:
		return
	for s in [Lab.sign_for(lab_station)]:
		var lab := Label3D.new()
		lab.text = s.text
		lab.position = s.pos
		lab.font_size = 26
		lab.pixel_size = 0.0105
		lab.outline_size = 12
		lab.modulate = Color(1.0, 0.95, 0.75)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.no_depth_test = true
		add_child(lab)
		lab_signs.append(lab)


## Comando lab: entra al laboratorio (o salta a otra estación si ya se está). `arg`: número o id de la estación ("" = la primera / la actual).
func dev_lab(arg: String) -> String:
	var index := lab_station if (lab_active and arg == "") else 0
	if arg != "":
		index = Lab.index_of(arg)
		if index < 0:
			return "No hay una estación %s (mirá la lista con: labs)" % arg
	if not lab_active:
		_cancel_jobs()
		if casino != null:
			casino.queue_free()
			casino = null
			if cam != null:
				cam.make_current()
		main_menu.visible = false
		pause_menu.close()
		get_tree().paused = false
		in_menu = false
		run = RunState.new()
		_bind_bars()
		_set_training(true)
		tutorial_index = -1
		lab_active = true
		lab_perks.clear()
		lab_abilities.clear()
		lab_collapse = false
		run.meta_consumable_slots = 6   # lugar de sobra para probar todos los consumibles (give <id>)
		stage_number = 1
		run.stage = 1
		profile = {}
		seed_value = 0
		solution = []
		cam_zoom = SIZE_NORMAL * 0.6
		generating = false
		hud_layer.visible = true
	lab_station = index
	stage_start = Lab.build(index)   # se carga una sola estación (las bombas cuentan en todo el mundo)
	restart()
	return "Laboratorio: estación %d, %s (R reinicia la estación; Esc > menú para salir)" % [index + 1, Lab.STATIONS[index].name]


func dev_labs() -> String:
	var out: Array[String] = []
	for i in Lab.count():
		out.append("%d %s" % [i + 1, Lab.STATIONS[i].id])
	return "Estaciones: " + ", ".join(out) + "   (lab <n|id>)"


const SPAWN_KINDS := {"normal": 0, "hielo": 1, "bomba": 2, "catapulta": 3, "agrietado": 4, "pesado": 5, "trampa": 6, "pinchos": 7, "fijo": -1}


## Comando spawn: pone un bloque del tipo dado en la celda de enfrente del personaje (a su altura). Sólo en el laboratorio.
func dev_spawn(kind_name: String, arg := "") -> String:
	if not lab_active or logic == null:
		return "spawn sólo funciona en el laboratorio (lab)"
	if not SPAWN_KINDS.has(kind_name):
		return "Tipos: " + ", ".join(SPAWN_KINDS.keys())
	var facing: Vector3i = logic.facing
	if facing == Vector3i.ZERO or facing.y != 0:
		facing = Vector3i(0, 0, -1)
	var cell: Vector3i = logic.player + facing
	if logic.blocks.has(cell) or not logic.in_bounds(cell):
		return "Esa celda está ocupada o fuera de la huella"
	var kind: int = SPAWN_KINDS[kind_name]
	var timer := int(arg) if arg.is_valid_int() else 5
	logic.add_block(cell, kind < 0, maxi(kind, 0), timer)
	logic._settle()
	_dev_rebuild_blocks()
	return "Bloque %s puesto en %s" % [kind_name, str(cell)]


## Vuelve a armar los bloques que se ven (después de agregar uno por comando).
func _dev_rebuild_blocks() -> void:
	for n in block_nodes.values():
		n.queue_free()
	block_nodes.clear()
	for id in logic.positions:
		block_nodes[id] = _make_block(logic.positions[id])
	player_node.position = _player_pos()
	_refresh()


## Comando perk: activa (o saca) un boost o habilidad en el laboratorio, por ejemplo `perk fuerza_bruta`.
func dev_perk(id: String) -> String:
	if not lab_active or logic == null:
		return "perk sólo funciona en el laboratorio (lab)"
	var known: Array[String] = []
	for it in Items.ALL:
		if it.type == Items.Type.BOOST:
			known.append(it.id)
	for a in Abilities.ALL:
		if a.has("perk") and not known.has(str(a.perk)):
			known.append(str(a.perk))
	if not known.has(id):
		return "Perks: " + ", ".join(known)
	if lab_perks.has(id):
		lab_perks.erase(id)
	else:
		lab_perks.append(id)
	restart()   # los boosts se aplican al armar la torre (Aire extra, Madrugada, Reflejos... cambian números): se reinicia la estación
	return "%s: %s (activos: %s). Se reinició la estación." % [id, "activado" if lab_perks.has(id) else "desactivado", ", ".join(lab_perks) if not lab_perks.is_empty() else "ninguno"]


## Comando ability: prende o apaga una habilidad persistente en el laboratorio (sin id: las lista, con una marca las que están prendidas).
func dev_ability(id: String) -> String:
	if not lab_active or logic == null:
		return "ability sólo funciona en el laboratorio (lab)"
	if Abilities.get_ability(id).is_empty():
		var names: Array[String] = []
		for a in Abilities.ALL:
			names.append(("[x] " if lab_abilities.has(a.id) else "") + str(a.id))
		return "Habilidades: " + ", ".join(names)
	if lab_abilities.has(id):
		lab_abilities.erase(id)
		Abilities.remove_from_run(run, id)
	else:
		lab_abilities.append(id)
		Abilities.apply_to_run(run, [id])
	_bind_bars()
	restart()
	return "%s: %s. Se reinició la estación." % [id, "activada" if lab_abilities.has(id) else "desactivada"]


## Comando collapse: enciende o apaga la caída de la fila de abajo en el laboratorio.
func dev_collapse(on: bool) -> String:
	if not lab_active or logic == null:
		return "collapse sólo funciona en el laboratorio (lab)"
	lab_collapse = on
	logic.collapse_every = 6 if on else 100000
	logic.moves_to_collapse = logic.collapse_every
	_refresh()
	return "Caída de la fila de abajo: %s" % ("encendida (cada 6 movimientos)" if on else "apagada")


## Comando goto_casino: abre directamente el casino de la etapa `stage` (como si acabaras de pasar esa torre).
func dev_goto_casino(stage: int) -> String:
	if in_menu or logic == null:
		return "Empezá una partida primero (Nueva partida)"
	if training:
		return "En el tutorial no hay casino"
	if generating:
		return "Esperá: se está generando la torre"
	_cancel_jobs()
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
	if casino == null and logic != null and not banked:
		var earned: int = logic.claridad
		if n >= earned:
			run.claridad = n - earned
		else:
			run.claridad = 0
			logic.claridad = n
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
		return "Ítem desconocido: %s (mirá los ids con: items)" % id
	if not run.take(item):
		return "No hay lugar para %s" % item.name
	if lab_active and item.type == Items.Type.BOOST:
		restart()   # en el laboratorio el boost se aplica enseguida (se reinicia la estación)
		return "Recibiste %s. Se reinició la estación para aplicarlo." % item.name
	if logic != null:
		_update_perk_label()
	if casino != null:
		casino._refresh_hud()
	return "Recibiste %s%s" % [item.name, " (se aplica al reintentar la torre: R)" if item.type == Items.Type.BOOST and casino == null else ""]


# --- guardar y continuar -------------------------------------------------------------------------------------------

## ¿Hay un run en juego que valga la pena guardar? (no en el entrenamiento, ni terminado, ni en el menú)
func _run_active() -> bool:
	return not training and not run_over and not in_menu and (casino != null or (logic != null and stage_start != null))


## Autoguardado: el run y, si se está en una torre, el estado inicial de esa torre (para volver a empezarla igual).
func save_game() -> void:
	if not _run_active():
		return
	var data := {"run": run.to_dict(), "stage": stage_number, "seed": seed_value}
	if casino != null:
		data["phase"] = "casino"
	else:
		data["phase"] = "tower"
		data["tower"] = stage_start.to_dict()
		data["dirty"] = attempt_dirty
	SaveGame.write(data)


## Botón Continuar: vuelve al casino donde se quedó, o al comienzo de la misma torre. Si el intento de la torre ya había empezado,
## continuar cuenta como un reintento (cuesta claridad): así salir y volver no sirve para reiniciar gratis.
func continue_game() -> void:
	var data := SaveGame.read()
	if data.is_empty():
		return
	_cancel_jobs()
	main_menu.visible = false
	in_menu = false
	run = RunState.from_dict(data.run)
	_bind_bars()
	_set_training(false)
	run_over = false
	run_end.visible = false
	stage_number = int(data.stage)
	seed_value = int(data.get("seed", 1))
	hud_layer.visible = true
	if data.phase == "casino":
		run.stage = stage_number
		enter_casino(true)
		return
	stage_start = TowerLogic.from_dict(data.tower)
	trial = run.trial_at(stage_number)
	profile = Gen.profile_for_stage(stage_number, trial, run.scenario())
	if data.get("dirty", false) and trial.get("no_retry", false):
		end_run(false, Loc.f("Abandonaste la prueba «%s» (no hay reintentos).", [Loc.t(trial.name)]))
		return
	if data.get("dirty", false):
		var cost := run.restart_cost()
		if not run.can_afford(cost):
			end_run(false, Loc.f("No te alcanza la claridad para reintentar la torre (cuesta %d).", [cost]))
			return
		run.spend(cost)
		run.note_retry()
	restart()
	_prefetch_next_stage()
	save_game()
