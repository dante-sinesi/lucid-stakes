extends Node3D
## Casino jugable: la sala de casino_room.gd con el personaje caminando de celda en celda.
##  - Se llega frente a la puerta de llegada (pared oeste), que es sólo estética. Se vuelve a la torre empujando la puerta
##    de salida (pared norte, frente a EXIT).
##  - Chocar contra la mesa de la ruleta abre la pantalla de apuesta (roulette_screen.gd). Espacio / Enter hace lo
##    mismo parado al lado de la mesa, mirándola. Tragamonedas y mesa de cartas: próximamente.
##  - Q / E giran la cámara; las paredes que quedan entre la cámara y la sala se ocultan.
## Uso: crear, add_child, setup(run, rng). Emite `left` al irse por el portal.

const Controls := preload("res://scripts/entrada/controls.gd")
const Room := preload("res://scripts/casino/casino_room.gd")
const VoxelMesh := preload("res://scripts/ui/voxel_mesh.gd")
const RouletteScreen := preload("res://scripts/casino/roulette_screen.gd")
const SlotsScreen := preload("res://scripts/casino/slots_screen.gd")
const BlackjackScreen := preload("res://scripts/casino/blackjack_screen.gd")
const Sfx := preload("res://scripts/sonido/sfx.gd")
const Characters := preload("res://scripts/personajes/characters.gd")
const Compass := preload("res://scripts/ui/compass.gd")
const Roulette := preload("res://scripts/casino/roulette.gd")
const VoxelLabel := preload("res://scripts/ui/voxel_label.gd")
const ItemBar := preload("res://scripts/ui/item_bar.gd")
const ConsumablePick := preload("res://scripts/entrada/consumable_pick.gd")
const ClarityCounter := preload("res://scripts/ui/clarity_counter.gd")
const Rules := preload("res://scripts/casino/casino_rules.gd")
const KeyDirs := preload("res://scripts/entrada/key_dirs.gd")
const CasinoTheme := preload("res://scripts/casino/casino_theme.gd")
const LivesHud := preload("res://scripts/ui/lives_hud.gd")
const Loc := preload("res://scripts/idioma/loc.gd")
const RuleUI := preload("res://scripts/casino/casino_rule_ui.gd")
const Services := preload("res://scripts/casino/casino_services.gd")
const HudPanel := preload("res://scripts/ui/hud_panel.gd")
const Story := preload("res://scripts/datos/story.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const GameHelp := preload("res://scripts/ui/game_help.gd")
const PORTAL_SHADER := preload("res://shaders/portal.gdshader")
const ServiceScreens := preload("res://scripts/casino/casino_service_screens.gd")

signal left
signal roulette_opened
signal changed   ## el run cambió (se jugó una tirada): hay que guardar
signal story_message(text: String)   ## en el modo historia (tutorial): algo que el tabernero tiene para decir
signal toll_talk   ## se llegó a la puerta de salida (o se habló con Farolín): el juego muestra su diálogo con las salidas (toll_dialog)
signal keeper_talk(lines: Array)   ## se habló con el tabernero: lo que dice (el juego lo muestra en el cuadro de diálogo)

const STEP_TIME := 0.14
const FAROLIN_SCALE := 2.6   # (Farolín mide 0,55: así queda un poco más alto que el personaje)
const PITCH := -35.264
const PITCH_MIN := -86.0
const PITCH_MAX := 80.0   # (positivo = mirando desde abajo del horizonte, como en el editor)
const MOUSE_SENS := 0.28       # grados por píxel (igual que en la torre)
const ARROW_SPEED := 110.0     # grados por segundo al girar con las flechas
const ZOOM_FACTOR := 1.1
const PLAYER_SCALE := 1.5  # el personaje se agranda un poco: la sala está hecha de minibloques y el crupier es alto

var run
var rng: RandomNumberGenerator
var lay := {}                 # distribución de la sala de esta etapa (casino_room.gd: layout)
var cell := Vector2i.ZERO
var facing := Vector2i(0, -1)
var yaw_target := 45.0
var cam_pitch := PITCH
var pitch_node: Node3D
var model: Node3D             # el animalito
var compass                    # rosa de los vientos
var busy := false             # caminando o con una pantalla abierta
var leaving := false
var player_node: Node3D
var pivot: Node3D
var cam: Camera3D
var walls := {}               # "west"/"north" -> [sólido, luces]
var hud: Control
var hud_panel                  # la ventana de la partida: corazones y claridad
var toast: Control
var hud_layer: CanvasLayer
var left_bar
var consumable_pick := ConsumablePick.new()   # elegir y usar consumibles con el mando (mantener RT y arriba o abajo)
var right_bar
var clarity_counter
var lives_hud
var item_tip: Control
var overlay: CanvasLayer
var screen
var _toast_tween: Tween
var _walk_tween: Tween
var _cam_tween: Tween
var story := false            # modo historia (tutorial): la ruleta no se abre y no se ve la interfaz de juego
var input_locked := false     # mientras habla el tabernero no se camina
var portals: Array[MeshInstance3D] = []   # los portales de las paredes
const Farolin := preload("res://scripts/personajes/farolin.gd")
const Demo := preload("res://scripts/datos/demo.gd")
const Items := preload("res://scripts/datos/items.gd")
const Showcase := preload("res://scripts/casino/showcase.gd")
var toll_base := 0            # el precio de Farolín en la puerta de salida (0: no cobra; tutorial, entrenamiento y pruebas); lo que se paga sale de acá con los descuentos (toll_now)
var _farolin: Node3D
var _arrow: Node3D            # flecha que marca la puerta de salida
var _t := 0.0
var quick := false            # pruebas: sin animaciones
var _vault_paid := 0          # lo que cobró la caja fuerte al entrar (lo comenta el tabernero)
var _greeting := -1           # qué saludo toca ahora (el tabernero va variando)


func setup(run_state, random: RandomNumberGenerator) -> void:
	run = run_state
	rng = random
	lay = Room.layout(run.stage, int(run.scenario().get("casino_tier", -1)))
	lay["farolin_on"] = toll_base > 0   # (Farolín ocupa su celda sólo si el casino cobra)
	cell = lay.entry
	if not story:
		CasinoTheme.apply_ui(int(lay.tier))   # los botones y textos se limpian según el nivel de la sala (se restablece al salir)
	var vault_paid := 0
	if not story:
		vault_paid = Services.enter(run)   # se paga la caja fuerte del casino anterior
		Rules.enter(run, int(lay.tier))   # la regla de la casa de esta sala (casino_rules.gd)
		Showcase.enter(run, rng)   # la vitrina de premios de esta visita (showcase.gd)
	_build_room()
	_build_portals()
	_build_player()
	_build_camera()
	_build_hud()
	if story:
		hud_layer.visible = false
	facing = Vector2i(1, 0)   # (al llegar mira hacia adentro de la sala, como si saliera del portal de la pared oeste)
	_place_player()
	_vault_paid = vault_paid
	if vault_paid > 0:
		_flash(Loc.f("Caja fuerte: cobras %d de claridad (con interés).", [vault_paid]))
	_refresh_hud()


# --- construcción --------------------------------------------------------------------------------------------

func _exit_tree() -> void:
	CasinoTheme.reset_ui()


func _solid_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	return m


func _glow_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _mesh_node(vox: Dictionary, material: Material, size := Room.VOXEL_FINO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = VoxelMesh.build(vox, size)
	mi.material_override = material
	add_child(mi)
	return mi


func _build_room() -> void:
	var data := Room.build_detalle(run.stage, int(run.scenario().get("casino_tier", -1)))
	var base_solid: Dictionary = data.solid.duplicate()
	var base_glow: Dictionary = data.glow.duplicate()
	for side in ["west", "north"]:
		for p in data[side].solid:
			base_solid.erase(p)
		for p in data[side].glow:
			base_glow.erase(p)
	_mesh_node(base_solid, _solid_material())
	_mesh_node(base_glow, _glow_material())
	if not data.fino.is_empty():   # (los papeles del tablón: minibloques de un tercio de tamaño)
		_mesh_node(data.fino, _solid_material(), Room.VOXEL_FINO / 3.0)
	for side in ["west", "north"]:
		walls[side] = [_mesh_node(data[side].solid, _solid_material()), _mesh_node(data[side].glow, _glow_material())]


## Los portales de las paredes (el de llegada, sólo estético, y el de salida): ondas que se mueven, como los de Minecraft. Se ocultan con su pared.
func _build_portals() -> void:
	var span := float(Room.CELL_VOX) * Room.VOXEL
	for side in ["north", "west"]:
		var is_exit: bool = side == "north"
		var col := Room.portal_color(run.stage, is_exit)
		var mat := ShaderMaterial.new()
		mat.shader = PORTAL_SHADER
		mat.set_shader_parameter("col_a", col.darkened(0.25))
		mat.set_shader_parameter("col_b", col)
		mat.set_shader_parameter("col_c", col.lightened(0.45))
		var quad := QuadMesh.new()
		quad.size = Vector2(span, 10.0 * Room.VOXEL)
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mat
		add_child(mi)
		if is_exit:   # pared norte: el vano corre por x, a la altura de las puertas (2 minibloques arriba del piso), en el medio del grosor de la pared
			mi.position = Vector3((lay.exit.x * Room.CELL_VOX + Room.CELL_VOX * 0.5) * Room.VOXEL, 7.0 * Room.VOXEL, 1.0 * Room.VOXEL)
		else:   # pared oeste: el vano corre por z
			mi.position = Vector3(1.0 * Room.VOXEL, 7.0 * Room.VOXEL, (lay.entry.y * Room.CELL_VOX + Room.CELL_VOX * 0.5) * Room.VOXEL)
			mi.rotation_degrees.y = 90.0
		walls[side].append(mi)
		portals.append(mi)
	_build_farolin()
	_update_toll_ui()


## Farolín, junto a la puerta de salida (en su celda, libre de muebles y mirando a la cámara): cobra el precio de la torre que sigue. El portal queda apagado hasta que se le paga.
func toll_now() -> int:
	return run.toll_after_discounts(toll_base)


func _build_farolin() -> void:
	if toll_base <= 0:
		return
	_farolin = Farolin.build()
	_farolin.scale = Vector3.ONE * FAROLIN_SCALE
	_farolin.position = Room.world_of_cell(lay.farolin, lay) + Vector3(-0.08, 0.0, 0.28)   # (un poco hacia adentro de la sala: pegado a la pared no entra el farol)
	_farolin.rotation_degrees.y = yaw_target
	add_child(_farolin)


## Lo que dice Farolín al llegar a la puerta y las salidas que ofrece (ver Farolin.toll_dialog).
func toll_dialog() -> Dictionary:
	return Farolin.toll_dialog(toll_now(), run.claridad, run.can_revive(), run.lives > 0)


## ¿La celda de Farolín está dentro de la sala, libre de muebles y máquinas, y se llega a la puerta de salida caminando?
func farolin_cell_free() -> bool:
	if not lay.has("farolin") or not Room.in_room(lay.farolin, lay):
		return false
	var f: Vector2i = lay.farolin
	if f == lay.exit or f == lay.entry or f == lay.dealer or lay.table.has_point(f) or lay.machines.has(f) or lay.obstacles.has(f) or (lay.has("station") and f == lay.station.cell):
		return false
	for ct in lay.card_tables:
		if ct.has_point(f):
			return false
	var reach := Room.reachable(lay.entry, lay)
	return reach.has(lay.exit)


## Se llegó a la puerta (o se habló con Farolín): el juego abre el diálogo.
func ask_toll() -> void:
	toll_talk.emit()


## Se eligió pagar: se cobra, vale una sola vez el soborno, se suma el interés y se pasa a la torre que sigue. false si no alcanza.
func pay_toll() -> bool:
	var price := toll_now()
	if run.claridad < price:
		return false
	if price > 0:
		run.spend(price)
		run.toll_bribe = false   # (el soborno vale para una sola vez)
		var interest: int = run.apply_interest()
		if interest > 0:
			_flash(Loc.f("Interés: +%d de claridad", [interest]))
		_refresh_hud()
	leaving = true
	_update_toll_ui()
	left.emit()
	return true


## El portal de salida se prende sólo al pagarle a Farolín; el precio se ve arriba a la izquierda (en rojo si falta).
func _update_toll_ui() -> void:
	var price := toll_now()
	if hud_panel != null:
		hud_panel.set_toll(price, run.claridad < price)
	if not portals.is_empty():
		var mat := portals[0].material_override as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("lit", 1.0 if (toll_base <= 0 or leaving) else 0.0)   # el portal se prende al pagarle a Farolín, no antes
	if _farolin != null:
		_farolin.set_mood("contento" if run.claridad >= price else "triste")


func _build_player() -> void:
	player_node = Node3D.new()
	player_node.scale = Vector3.ONE * PLAYER_SCALE
	var profile := preload("res://scripts/datos/profile.gd")
	model = Characters.build(profile.character(), profile.equipped_hat(), profile.equipped_outfit())   # el animalito elegido, con su ropa
	model.position = Vector3(0, -0.35, 0)   # (el origen del modelo está en los pies; el del personaje, en el centro del cuerpo)
	player_node.add_child(model)
	add_child(player_node)


func _room_center() -> Vector3:
	return Vector3(lay.cells.x * 0.5, 1.0, lay.cells.y * 0.5) * (Room.CELL_VOX * Room.VOXEL)


func _build_camera() -> void:
	pivot = Node3D.new()
	add_child(pivot)
	pivot.position = _room_center()
	pivot.rotation_degrees.y = yaw_target
	var pitch := Node3D.new()
	pitch.rotation_degrees.x = PITCH
	pitch_node = pitch
	pivot.add_child(pitch)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = lay.cam_size
	cam.far = 200.0
	cam.position = Vector3(0, 0, 40)
	pitch.add_child(cam)
	cam.make_current()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	hud_layer = layer
	add_child(layer)
	hud = _label(layer, 3, Color(1.0, 0.92, 0.7))   # (el título "Casino" ya no se muestra)
	hud.visible = false
	# La rosa de los vientos (como en la torre): qué eje mueve cada tecla según como esté girada la cámara.
	compass = Compass.new()
	compass.name = "rosa_vientos"
	compass.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	compass.position = Vector2(-Compass.SPAN - 16, 10)
	compass.size = Vector2(Compass.SPAN, Compass.SPAN)
	compass.view_source = func(): return Vector2(pivot.rotation_degrees.y, pitch_node.rotation_degrees.x) if pivot != null and pitch_node != null else Vector2(45, PITCH)
	compass.dir_source = func(sx, sy): return Vector3i(_dir_for_screen(sx, sy).x, 0, _dir_for_screen(sx, sy).y)
	layer.add_child(compass)
	hud_panel = HudPanel.new(false)   # la vida y la claridad (lo demás, la regla de la casa y la próxima prueba, lo cuenta el tabernero)
	layer.add_child(hud_panel)
	lives_hud = hud_panel.lives
	clarity_counter = hud_panel.clarity
	_update_toll_ui()   # lo que cobra Farolín de la puerta de salida
	item_tip = _label(layer, 2, Color(0.95, 0.93, 0.88))
	item_tip.wrap_px = 460
	item_tip.plate_alpha = 0.85
	item_tip.visible = false
	left_bar = ItemBar.new()
	layer.add_child(left_bar)
	left_bar.edge = 0
	left_bar.bottom = true   # los consumibles van abajo a la izquierda
	left_bar.tip = item_tip
	left_bar.setup(run, ItemBar.Kind.CONSUMABLE, false)
	left_bar.discarded.connect(_on_item_discarded)
	left_bar.slot_pressed.connect(use_consumable_slot)
	right_bar = ItemBar.new()
	layer.add_child(right_bar)
	right_bar.edge = 1
	right_bar.discarded.connect(_on_item_discarded)
	right_bar.tip = item_tip
	right_bar.setup(run, ItemBar.Kind.BOOST, false)
	toast = _label(layer, 2, Color(1.0, 0.95, 0.85))
	toast.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast.align = VoxelLabel.Align.CENTER
	toast.y_offset = 104.0
	toast.plate_alpha = 0.6
	toast.modulate.a = 0.0


func _label(parent: Node, cube: float, color: Color) -> Control:
	var l := VoxelLabel.new()
	l.cube = cube
	l.color = color
	parent.add_child(l)
	return l


# --- estado y movimiento -------------------------------------------------------------------------------------

func cell_position(c: Vector2i) -> Vector3:
	return Room.world_of_cell(c, lay) + Vector3(0, 0.35 * PLAYER_SCALE, 0)


func _place_player() -> void:
	player_node.position = cell_position(cell)
	player_node.rotation.y = atan2(facing.x, facing.y)


## Usa un consumible dentro del casino: sólo los que sirven acá (Vida extra y Soborno; los demás son de la torre).
func use_consumable_slot(slot: int) -> void:
	if busy or leaving or input_locked or screen != null or story or slot >= run.consumables.size():
		return
	var id: String = run.consumables[slot]
	if not Items.CASINO_USABLE.has(id):
		_flash(Loc.t("Ese consumible sólo se usa en la torre"))
		return
	if run.item_blocked(id):
		_flash(Loc.t("No funciona en este escenario"))
		return
	if id == "vida_extra":
		if not run.add_life():
			_flash(Loc.f("Ya tienes las %d vidas", [run.max_lives()]))
			return
		run.use_consumable(id)
		_flash(Loc.t("¡Una vida más!"))
	elif id == "ficha_gratis":
		if run.free_chip:
			_flash(Loc.t("Ya tienes una ficha gratis lista"))
			return
		run.free_chip = true
		run.use_consumable(id)
		_flash(Loc.t("Tu próxima apuesta no cuesta la ficha"))
	elif id == "rayos_x":
		if run.xray:
			_flash(Loc.t("Ya tienes los rayos X listos"))
			return
		run.xray = true
		run.use_consumable(id)
		_flash(Loc.t("En tu próxima mano de blackjack ves la carta tapada"))
	elif id == "doble_o_nada":
		var visit = run.casino_visit
		if not (visit is Dictionary) or visit.is_empty() or bool(visit.get("double", false)):
			_flash(Loc.t("No se puede usar ahora"))
			return
		run.casino_visit["double"] = true
		run.use_consumable(id)
		_flash(Loc.t("Lo que ganes en esta visita vale el doble"))
	elif id == "soborno":
		if toll_base <= 0 or run.toll_bribe:
			_flash(Loc.t("Farolín no cobra, o ya lo sobornaste"))
			return
		run.toll_bribe = true
		run.use_consumable(id)
		_flash(Loc.f("Farolín te cobra un 30 %% menos: %d", [toll_now()]))
	Sfx.play("item")
	_refresh_hud()
	changed.emit()


## Se tiró un ítem con clic derecho en una barra: se actualiza el HUD y se avisa para guardar.
func _on_item_discarded(_kind: int, id: String) -> void:
	_flash(Loc.f("Tiraste %s.", [Loc.t(str(preload("res://scripts/datos/items.gd").get_item(id).get("name", id)))]))
	_refresh_hud()
	changed.emit()


func _refresh_hud() -> void:
	if lives_hud != null:
		lives_hud.max_lives = run.max_lives()
		lives_hud.lives = run.lives
	if left_bar != null:
		left_bar.refresh()
		right_bar.refresh()
	hud.text = "Casino"
	clarity_counter.value = run.claridad
	_update_toll_ui()


func _flash(msg: String) -> void:
	toast.text = msg
	toast.modulate.a = 1.0
	if _toast_tween != null:   # (un solo desvanecer a la vez: si no, los viejos pisan la transparencia del aviso nuevo)
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 3.0).set_delay(1.5)


## Intenta dar un paso hacia `dir` (en celdas). Devuelve qué pasó: "moved", "blocked", "roulette", "soon" o "exit".
func step(dir: Vector2i) -> String:
	if busy or leaving or input_locked:
		return "blocked"
	facing = dir
	player_node.rotation.y = atan2(dir.x, dir.y)
	var n := cell + dir
	if not Room.in_room(n, lay):
		if cell == lay.exit and dir == Vector2i(0, -1):  # la puerta de salida: Farolín cobra (si no cobra, se pasa directo)
			if toll_now() > 0:
				ask_toll()
				return "blocked"
			leaving = true
			_update_toll_ui()
			left.emit()
			return "exit"
		return "blocked"
	if not Room.walkable(n, lay):
		return _bump(n)
	cell = n
	busy = true
	Sfx.play("step", 1.3, -8.0)
	Characters.step_anim(model, STEP_TIME)
	var target := cell_position(cell)
	if quick:
		player_node.position = target
		_on_arrived()
	else:
		if _walk_tween:
			_walk_tween.kill()
		# Un saltito por casilla: sube y baja mientras avanza, se estira en el aire y se aplasta al pisar.
		var start := player_node.position
		var base := Vector3.ONE * PLAYER_SCALE
		_walk_tween = create_tween()
		_walk_tween.tween_method(func(t: float) -> void:
				var e := 1.0 - (1.0 - t) * (1.0 - t)
				player_node.position = start.lerp(target, e) + Vector3(0, sin(t * PI) * 0.18, 0)
				var stretch := sin(t * PI) * 0.12
				player_node.scale = base * Vector3(1.0 - stretch * 0.5, 1.0 + stretch, 1.0 - stretch * 0.5), 0.0, 1.0, STEP_TIME)
		_walk_tween.tween_callback(_on_arrived)   # se puede seguir caminando mientras termina el aplastón
		_walk_tween.tween_property(player_node, "scale", base * Vector3(1.12, 0.88, 1.12), 0.04)
		_walk_tween.tween_property(player_node, "scale", base, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return "moved"


func _on_arrived() -> void:
	busy = false


## Chocar contra lo que no se camina: la mesa de la ruleta se abre; el resto avisa.
func _bump(n: Vector2i) -> String:
	if toll_base > 0 and lay.get("farolin_on", false) and n == lay.farolin:   # Farolín: se habla con él (el peaje)
		ask_toll()
		return "farolin"
	if n == lay.dealer:   # el tabernero: se habla con él (en el tutorial todavía no hay nada de qué hablar)
		if story:
			story_message.emit(Story.BLOCKED_TABLE)
			return "blocked"
		talk_to_keeper()
		return "keeper"
	if lay.table.has_point(n):
		if story:   # en el tutorial no se apuesta todavía
			story_message.emit(preload("res://scripts/datos/story.gd").BLOCKED_TABLE)
			return "blocked"
		open_roulette()
		return "roulette"
	if lay.machines.has(n):
		if story:
			story_message.emit(preload("res://scripts/datos/story.gd").BLOCKED_TABLE)
			return "blocked"
		open_slots()
		return "slots"
	if lay.has("station") and n == lay.station.cell:
		if story:
			story_message.emit(preload("res://scripts/datos/story.gd").BLOCKED_TABLE)
			return "blocked"
		open_service()
		return "service"
	for ct in lay.card_tables:
		if ct.has_point(n):
			if story:
				story_message.emit(preload("res://scripts/datos/story.gd").BLOCKED_TABLE)
				return "blocked"
			open_blackjack()
			return "blackjack"
	return "blocked"


## Espacio / Enter: jugar a la ruleta si se está al lado de la mesa y mirándola.
func interact() -> String:
	if busy or leaving or input_locked:
		return "blocked"
	var n := cell + facing
	if lay.table.has_point(n) or n == lay.dealer or lay.machines.has(n) or (lay.has("station") and n == lay.station.cell) or (toll_base > 0 and n == lay.farolin):
		return _bump(n)
	for ct in lay.card_tables:
		if ct.has_point(n):
			return _bump(n)
	return "blocked"


## Habla con el tabernero (el de detrás de la mesa): saluda, cuenta la regla de la casa de esta sala (que desde ahora rige en toda la visita) y la próxima prueba.
## Emite `keeper_talk` con lo que dice (el juego lo muestra en el cuadro de diálogo) y lo devuelve.
func talk_to_keeper() -> Array:
	if _greeting < 0:
		_greeting = rng.randi() % Story.GREETINGS.size()
	else:
		_greeting = (_greeting + 1) % Story.GREETINGS.size()
	var rule := Rules.rule_of(int(lay.tier))
	var lines := Story.keeper(rule, Rules.accepted(run), run.next_trial_info(run.stage + 1), _greeting, _vault_paid)
	Rules.accept(run)
	keeper_talk.emit(lines)
	return lines


func open_roulette() -> void:
	_open_screen(RouletteScreen.new())
	roulette_opened.emit()


func open_slots() -> void:
	if Demo.on():   # la demo: las tragamonedas son del juego completo
		_flash(Demo.casino_text())
		return
	_open_screen(SlotsScreen.new())


## Abre la estación de servicio de la sala (Taller o Caja fuerte).
func open_service() -> void:
	_open_screen(ServiceScreens.make(str(lay.station.id)))


func open_blackjack() -> void:
	if Demo.on():   # la demo: el blackjack es del juego completo
		_flash(Demo.casino_text())
		return
	_open_screen(BlackjackScreen.new())


## Abre una pantalla de juego (ruleta, tragamonedas o blackjack) a pantalla completa sobre el casino.
func _open_screen(new_screen: Control) -> void:
	if screen != null:
		new_screen.free()
		return
	busy = true
	overlay = CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)
	screen = new_screen
	overlay.add_child(screen)
	screen.setup(run, rng, quick)
	GameHelp.attach(screen, GameHelp.id_for(screen))   # la ayuda del juego: se abre sola la primera vez y con H o Select
	screen.closed.connect(close_roulette)
	screen.resolved.connect(func(): changed.emit())
	if screen.has_signal("open_shop"):   # las estaciones de servicio tienen un botón para pasar a la tienda
		screen.open_shop.connect(func():
			close_roulette()
			_open_screen(ServiceScreens.make("tienda")))
	hud_layer.visible = false   # el juego ocupa toda la pantalla: la interfaz del casino no se ve detras


func close_roulette() -> void:
	if screen == null:
		return
	overlay.queue_free()
	overlay = null
	screen = null
	busy = false
	hud_layer.visible = true
	_refresh_hud()


# --- cámara --------------------------------------------------------------------------------------------------

func _dir_for_screen(sx: float, sy: float) -> Vector2i:
	return KeyDirs.dir_for(yaw_target, sx, sy)   # ver key_dirs.gd: W es la dirección que más sube en la pantalla


## Gira (x) e inclina (y) la cámara según un desplazamiento del mouse en píxeles (igual que en la torre).
func orbit_view(rel: Vector2) -> void:
	yaw_target -= rel.x * MOUSE_SENS
	cam_pitch = clampf(cam_pitch - rel.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)
	if _cam_tween:
		_cam_tween.kill()
	pivot.rotation_degrees.y = yaw_target
	pitch_node.rotation_degrees.x = cam_pitch


## Acerca (factor < 1) o aleja (factor > 1) la cámara.
func zoom_view(factor: float) -> void:
	cam.size = clampf(cam.size * factor, float(lay.cam_size) * 0.4, float(lay.cam_size) * 1.8)


func rotate_camera(stp: int) -> void:
	yaw_target = roundf((yaw_target - 45.0) / 90.0) * 90.0 + 45.0 + 90.0 * stp   # vuelve a la diagonal más cercana y gira desde ahí
	cam_pitch = PITCH
	if _cam_tween:
		_cam_tween.kill()
	if quick:
		pivot.rotation_degrees.y = yaw_target
		pitch_node.rotation_degrees.x = cam_pitch
		return
	_cam_tween = create_tween().set_parallel(true)
	_cam_tween.tween_property(pivot, "rotation_degrees:y", yaw_target, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(pitch_node, "rotation_degrees:x", cam_pitch, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Qué paredes quedan entre la cámara y la sala (la cámara está del lado de sin(yaw), cos(yaw) respecto del centro).
func hidden_walls(yaw_deg: float) -> Array[String]:
	var yaw := deg_to_rad(yaw_deg)
	var out: Array[String] = []
	if sin(yaw) < -0.1:
		out.append("west")
	if cos(yaw) < -0.1:
		out.append("north")
	return out


## Marca la puerta de salida con una flecha dorada que sube y baja (la ve quien tiene que ir hasta ahí: el tutorial).
func show_exit_arrow(on: bool) -> void:
	if _arrow != null:
		_arrow.queue_free()
		_arrow = null
	if not on:
		return
	_arrow = Node3D.new()
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.3
	cm.height = 0.55
	cm.radial_segments = 4
	cone.mesh = cm
	cone.rotation_degrees.x = 180.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.25)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone.material_override = mat
	_arrow.add_child(cone)
	add_child(_arrow)
	_arrow.position = Room.world_of_cell(lay.exit, lay) + Vector3(0, 3.7, 0.1)


func _process(delta: float) -> void:
	_t += delta
	if screen == null and pivot != null and not input_locked:   # (mientras hay una decisión o habla alguien las flechas eligen, no giran la cámara) las flechas giran (izquierda y derecha) e inclinan (arriba y abajo) la cámara, como en la torre
		var ax := int(Controls.held("camara_derecha")) - int(Controls.held("camara_izquierda"))
		var ay := int(Controls.held("camara_abajo")) - int(Controls.held("camara_arriba"))
		if ax != 0 or ay != 0:
			orbit_view(Vector2(ax, ay) * ARROW_SPEED * delta / MOUSE_SENS)
	if _arrow != null:
		_arrow.position.y = Room.world_of_cell(lay.exit, lay).y + 3.7 + sin(_t * 4.0) * 0.18
		_arrow.rotation.y += delta * 2.0
	if pivot == null:
		return
	var hide := hidden_walls(pivot.rotation_degrees.y)
	for side in walls:
		for mi in walls[side]:
			mi.visible = not hide.has(side)


func _unhandled_input(event: InputEvent) -> void:
	if screen == null and pivot != null:   # mouse: arrastrar gira e inclina, la rueda acerca y aleja
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_view(1.0 / ZOOM_FACTOR)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_view(ZOOM_FACTOR)
		elif event is InputEventMouseMotion and (event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)) != 0:
			orbit_view(event.relative)
	if not input_locked and screen == null and run != null and left_bar != null:
		var pick: Dictionary = consumable_pick.process(event, run.consumables.size())
		if pick.taken:
			left_bar.set_pick(consumable_pick.marked())
			if pick.use >= 0:
				use_consumable_slot(int(pick.use))
			return
	if input_locked or not (event is InputEventKey) or not event.pressed or event.echo or screen != null:
		return
	match Controls.action_of(event):
		"vista_izquierda": rotate_camera(1)
		"vista_derecha": rotate_camera(-1)
		"zoom_mas": zoom_view(1.0 / ZOOM_FACTOR)
		"zoom_menos": zoom_view(ZOOM_FACTOR)
		"mover_adelante": step(_dir_for_screen(1, 1))
		"mover_derecha": step(_dir_for_screen(1, -1))
		"mover_atras": step(_dir_for_screen(-1, -1))
		"mover_izquierda": step(_dir_for_screen(-1, 1))
		"consumible_1": use_consumable_slot(0)
		"consumible_2": use_consumable_slot(1)
		"consumible_3": use_consumable_slot(2)
		"consumible_4": use_consumable_slot(3)
		_:
			if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
				interact()
