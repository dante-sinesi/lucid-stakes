extends Control
## El cartel de la prueba: letras grandes de cubitos abajo en la pantalla, sin fondo ("Prueba" chico, el nombre grande y bailando, la descripción abajo).
## Aparece al empezar la torre, se queda unos segundos y se desvanece lento. Al pausar se muestra otra vez completo (`pin`), igual que al principio, y al volver
## al juego se desvanece de nuevo (`release`).

const VoxelLabel := preload("res://scripts/voxel_label.gd")
const Loc := preload("res://scripts/loc.gd")

const HOLD := 4.0   # segundos que se queda entero
const FADE := 3.0   # y lo que tarda en desvanecerse
const RELEASE_HOLD := 1.2
const RELEASE_FADE := 2.0

var title_label: Control
var name_label: Control
var desc_label: Control
var active := false   # hay una prueba en esta torre (el cartel puede mostrarse)
var _tween: Tween


func _init() -> void:
	name = "cartel_prueba"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS   # (sigue andando con el juego en pausa)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	title_label = _make(3.0, Color(0.85, 0.7, 0.3))
	name_label = _make(8.0, Color(1.0, 0.85, 0.4))
	name_label.dance = true
	desc_label = _make(3.0, Color(0.97, 0.95, 0.9))
	desc_label.wrap_px = 1000
	resized.connect(_layout)
	_layout()


func _make(cube: float, color: Color) -> Control:
	var l := VoxelLabel.new()
	l.cube = cube
	l.color = color
	l.align = VoxelLabel.Align.CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(l)
	return l


func _layout() -> void:
	title_label.y_offset = size.y - 204.0
	name_label.y_offset = size.y - 172.0
	desc_label.y_offset = size.y - 70.0


## ¿Se ve ahora? (visible y no del todo desvanecido)
func is_shown() -> bool:
	return visible and modulate.a > 0.01


## Empieza la torre con una prueba: aparece, se queda y se desvanece lento.
func play(trial_name: String, trial_desc: String) -> void:
	title_label.text = Loc.t("Prueba")
	name_label.text = trial_name
	desc_label.text = trial_desc
	active = true
	_fade(HOLD, FADE)


## Se pausa: se muestra completo y se queda mientras dure la pausa.
func pin() -> void:
	if not active:
		return
	_kill()
	visible = true
	modulate.a = 1.0


## Se vuelve al juego: se queda un momento y se desvanece de nuevo.
func release() -> void:
	if active and visible:
		_fade(RELEASE_HOLD, RELEASE_FADE)


## Sin prueba (otra torre, el menú, el casino): se saca de golpe.
func clear() -> void:
	active = false
	_kill()
	visible = false
	modulate.a = 0.0


func _fade(hold: float, fade: float) -> void:
	_kill()
	visible = true
	modulate.a = 1.0
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_interval(hold)
	_tween.tween_property(self, "modulate:a", 0.0, fade)
	_tween.tween_callback(func(): visible = false)


func _kill() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
