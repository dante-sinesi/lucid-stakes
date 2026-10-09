extends RefCounted
## Animaciones de "sensación de juego" (sin sonido): estirar y aplastar al personaje, polvo al aterrizar, temblor de cámara,
## destellos de pantalla al ganar o perder, rebote de los bloques empujados y pulsos de la interfaz.
## Todo es cosmético: nada de esto toca la lógica de la torre.

var main: Node
var shake := 0.0            # intensidad actual del temblor (se apaga sola)
var body: Node3D            # cuerpo del personaje, con el pivote en los pies (para estirar y aplastar)
var flash_rect: ColorRect   # destello de pantalla completa
var _dust_mesh: BoxMesh
var _dust_mat: StandardMaterial3D
var _gold_mat: StandardMaterial3D
var _body_tween: Tween
var _flash_tween: Tween


func _init(owner_node: Node) -> void:
	main = owner_node
	_dust_mesh = BoxMesh.new()
	_dust_mesh.size = Vector3.ONE * 0.09
	_dust_mat = StandardMaterial3D.new()
	_dust_mat.albedo_color = Color(0.85, 0.82, 0.92, 0.85)
	_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dust_mesh.material = _dust_mat
	_gold_mat = StandardMaterial3D.new()
	_gold_mat.albedo_color = Color(1.0, 0.88, 0.35)
	_gold_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


## Se llama una vez creado el HUD: el destello de pantalla va sobre la torre pero debajo del texto.
func attach_flash(layer: CanvasLayer) -> void:
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	layer.add_child(flash_rect)
	layer.move_child(flash_rect, 0)


## Cada cuadro: aplica el temblor a la cámara (se desplaza la imagen, no el rig, para no pelear con el seguimiento).
func process(delta: float) -> void:
	if main.cam == null:
		return
	if shake > 0.001:
		main.cam.h_offset = randf_range(-1.0, 1.0) * shake
		main.cam.v_offset = randf_range(-1.0, 1.0) * shake
		shake = maxf(0.0, shake - delta * 2.2) * 0.9
	elif main.cam.h_offset != 0.0 or main.cam.v_offset != 0.0:
		main.cam.h_offset = 0.0
		main.cam.v_offset = 0.0


func add_shake(amount: float) -> void:
	shake = minf(maxf(shake, amount), 0.9)


# ---- personaje ----------------------------------------------------------------------------------------------------

## Un paso: se estira en la dirección del salto y al llegar se aplasta y vuelve a su forma con un resorte.
## `height`: cuántas celdas bajó (caídas largas aplastan más y levantan polvo y temblor).
func step(height := 0) -> void:
	if body == null:
		return
	if _body_tween:
		_body_tween.kill()
	_body_tween = body.create_tween()
	body.scale = Vector3(0.9, 1.18, 0.9)
	_body_tween.tween_property(body, "scale", Vector3.ONE, main.STEP_TIME * 0.8).set_trans(Tween.TRANS_SINE)


func land(fell: int) -> void:
	if body == null:
		return
	if _body_tween:
		_body_tween.kill()
	var k := clampf(0.14 + 0.05 * fell, 0.14, 0.4)
	body.scale = Vector3(1.0 + k, 1.0 - k * 1.3, 1.0 + k)
	_body_tween = body.create_tween()
	_body_tween.tween_property(body, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	dust(main.player_node.position + Vector3(0, -0.45, 0), 6 + mini(fell * 3, 12), 0.9 + 0.3 * fell)
	if fell >= 2:
		add_shake(clampf(0.05 * fell, 0.05, 0.3))


func tumble() -> void:
	if body == null:
		return
	if _body_tween:
		_body_tween.kill()
	_body_tween = body.create_tween().set_parallel(true)
	_body_tween.tween_property(body, "rotation:z", 1.6, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_body_tween.tween_property(body, "scale", Vector3(1.2, 0.5, 1.2), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func reset_body() -> void:
	if body == null:
		return
	if _body_tween:
		_body_tween.kill()
	body.scale = Vector3.ONE
	body.rotation = Vector3.ZERO


# ---- partículas ---------------------------------------------------------------------------------------------------

## Una nubecita de cubitos que sale hacia los costados desde `pos`.
func dust(pos: Vector3, amount := 8, speed := 1.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2
	p.direction = Vector3.UP
	p.spread = 85.0
	p.initial_velocity_min = 0.4 * speed
	p.initial_velocity_max = 1.1 * speed
	p.gravity = Vector3(0, -2.5, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.4
	p.mesh = _dust_mesh
	main.add_child(p)
	p.position = pos
	p.emitting = true
	main.get_tree().create_timer(0.9).timeout.connect(p.queue_free)


## Lluvia dorada de cubitos (al llegar al portal).
func gold_burst(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 40
	p.lifetime = 1.1
	p.explosiveness = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -4.0, 0)
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.12
	m.material = _gold_mat
	p.mesh = m
	main.add_child(p)
	p.position = pos
	p.emitting = true
	main.get_tree().create_timer(1.6).timeout.connect(p.queue_free)


# ---- bloques ------------------------------------------------------------------------------------------------------

## Un bloque empujado o jalado llega a su lugar con un leve aplastón.
func settle(node: Node3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.scale = Vector3(1.07, 0.93, 1.07)
	node.create_tween().tween_property(node, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	dust(node.position + Vector3(0, -0.45, 0), 4, 0.6)


## Un bloque que cae al vacío da vueltas mientras se hunde.
func spin_fall(node: Node3D) -> void:
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "rotation:x", randf_range(-1.5, 1.5), 0.8)
	tw.tween_property(node, "rotation:z", randf_range(-1.5, 1.5), 0.8)


# ---- pantalla e interfaz --------------------------------------------------------------------------------------------

func flash(color: Color, peak := 0.35, time := 0.45) -> void:
	if flash_rect == null:
		return
	if _flash_tween:
		_flash_tween.kill()
	flash_rect.color = Color(color, peak)
	_flash_tween = flash_rect.create_tween()
	_flash_tween.tween_property(flash_rect, "color:a", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Un pulso de la cámara (un poco más cerca y de vuelta).
func zoom_punch(amount := 0.04) -> void:
	if main.cam == null:
		return
	var target: float = main.cam_zoom
	main.cam.size = target * (1.0 - amount)
	main.cam.create_tween().tween_property(main.cam, "size", target, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Un control (texto o contador) aparece "de golpe": más grande y se asienta en su tamaño.
static func pop(ctrl: Control, from := 1.35) -> void:
	if ctrl == null:
		return
	ctrl.pivot_offset = ctrl.size * 0.5
	ctrl.scale = Vector2.ONE * from
	ctrl.create_tween().tween_property(ctrl, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
