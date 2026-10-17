extends VBoxContainer
## La ventana de la partida, arriba a la izquierda: los corazones (chicos), la etapa y, al final, la claridad (la racha sólo aparece en el cartel de ganancia, no acá).
## Es la única información fija que se ve jugando; lo demás (la próxima prueba, la regla de la casa) lo cuenta el tabernero.

const LivesHud := preload("res://scripts/lives_hud.gd")
const VoxelLabel := preload("res://scripts/voxel_label.gd")
const Loc := preload("res://scripts/loc.gd")
const ClarityCounter := preload("res://scripts/clarity_counter.gd")

var lives
var stage_label: Control
var clarity
var toll_label: Control      # lo que cobra Farolín del portal de salida


## `with_stage`: false en la taberna y el casino (sólo vida y claridad).
func _init(with_stage := true) -> void:
	name = "ventana_partida"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 7)
	position = Vector2(22, 18)
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
	resized.connect(queue_redraw)
	minimum_size_changed.connect(queue_redraw)


## El peaje de Farolín (0 lo oculta); `short`: te falta claridad para pagarlo.
func set_toll(amount: int, short := false) -> void:
	toll_label.visible = amount > 0
	toll_label.text = Loc.f("Peaje %d", [amount])
	toll_label.color = Color(1.0, 0.55, 0.45) if short else Color(0.55, 0.9, 0.4)


func _draw() -> void:
	var r := Rect2(Vector2(-12, -10), size + Vector2(24, 20))
	draw_rect(r, Color(0.03, 0.02, 0.06, 0.66))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(0.85, 0.7, 0.3, 0.55))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)), Color(0.85, 0.7, 0.3, 0.35))
