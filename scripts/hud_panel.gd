extends VBoxContainer
## La ventana de la partida, arriba a la izquierda (marco de cubitos como el del cuadro de diálogo): los corazones (chicos), la etapa y, al final, la claridad (la racha sólo aparece en el cartel de ganancia, no acá).
## Es la única información fija que se ve jugando; lo demás (la próxima prueba, la regla de la casa) lo cuenta el tabernero.

const LivesHud := preload("res://scripts/lives_hud.gd")
const VoxelLabel := preload("res://scripts/voxel_label.gd")
const Loc := preload("res://scripts/loc.gd")
const ClarityCounter := preload("res://scripts/clarity_counter.gd")
const Draw := preload("res://scripts/voxel_draw.gd")

var lives
var stage_label: Control
var clarity
var toll_label: Control      # lo que cobra Farolín del portal de salida
var mistakes: Control        # los movimientos en falso que quedan en la sala (Sin piedad): cubitos rojos


## `with_stage`: false en la taberna y el casino (sólo vida y claridad).
func _init(with_stage := true) -> void:
	name = "ventana_partida"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 7)
	position = Vector2(30, 26)
	lives = LivesHud.new()
	lives.compact = true
	add_child(lives)
	if with_stage:
		stage_label = VoxelLabel.new()
		stage_label.cube = 3.0
		stage_label.color = Color(0.97, 0.95, 0.9)
		add_child(stage_label)
	clarity = ClarityCounter.new(3.5)   # la claridad no es texto: es el ícono girando y el número
	clarity.name = "claridad"
	add_child(clarity)
	toll_label = VoxelLabel.new()
	toll_label.cube = 3.0
	toll_label.color = Color(0.55, 0.9, 0.4)
	toll_label.visible = false
	add_child(toll_label)
	mistakes = _Pips.new()
	mistakes.visible = false
	add_child(mistakes)
	resized.connect(queue_redraw)
	minimum_size_changed.connect(queue_redraw)


## Los movimientos en falso que quedan en la sala (`total` 0 lo oculta): un cubito rojo por cada uno, apagado el que ya se gastó.
func set_mistakes(left: int, total: int) -> void:
	mistakes.visible = total > 0
	mistakes.set_state(left, total)


## El peaje de Farolín (0 lo oculta); `short`: te falta claridad para pagarlo.
func set_toll(amount: int, short := false) -> void:
	toll_label.visible = amount > 0
	toll_label.text = Loc.f("Peaje %d", [amount])
	toll_label.color = Color(1.0, 0.55, 0.45) if short else Color(0.55, 0.9, 0.4)


func _draw() -> void:
	# El marco es de cubitos, igual que el cuadro de diálogo y las pantallas (placa oscura con borde de piedra).
	var r := Rect2(Vector2(-16, -14), size + Vector2(32, 28))
	Draw.card(self, r, 5.0, 0, 0.06, 77, false, -1.0)


## Fila de cubitos: los movimientos en falso que quedan (rojos) y los gastados (apagados).
class _Pips extends Control:
	const D := preload("res://scripts/voxel_draw.gd")
	var left := 0
	var total := 0

	func _init() -> void:
		name = "falsos"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 22)

	func set_state(l: int, t: int) -> void:
		left = l
		total = t
		custom_minimum_size = Vector2(maxf(float(t) * 26.0, 26.0), 22)
		queue_redraw()

	func _draw() -> void:
		for i in total:
			D.cube(self, Vector2(float(i) * 26.0, 0.0), 20.0, Color(1.0, 0.28, 0.25) if i < left else Color(0.22, 0.12, 0.16), true)
