extends Control
## El cartel de la prueba: letras grandes de cubitos abajo en la pantalla, sin fondo ("Prueba" chico, el nombre grande y bailando, la descripción abajo).
## Aparece al empezar la torre, se queda unos segundos y se desvanece lento. Al pausar se va (`hide_for_pause`): la prueba se lee en el panel de información.

const VoxelLabel := preload("res://scripts/ui/voxel_label.gd")
const Loc := preload("res://scripts/idioma/loc.gd")

const HOLD := 4.0   # segundos que se queda entero
const FADE := 3.0   # y lo que tarda en desvanecerse
const MARGEN_ABAJO := 74.0   # lo que queda libre abajo (la guía de controles)

var band: ColorRect   # la banda oscura detrás: el cartel se lee sobre cualquier bloque
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
	band = ColorRect.new()
	band.color = Color(0.02, 0.01, 0.05, 0.82)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
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


## Las tres líneas se apilan desde abajo según lo que miden (la descripción puede tener una línea o varias) y dejan libre el borde de abajo, donde va la guía de controles.
func _layout() -> void:
	var abajo := size.y - MARGEN_ABAJO
	var alto_desc: float = float(desc_label.layout().size.y + 2) * float(desc_label.cube)
	desc_label.y_offset = abajo - alto_desc
	var alto_nombre: float = float(name_label.layout().size.y + 2) * float(name_label.cube)
	name_label.y_offset = desc_label.y_offset - alto_nombre + 14.0
	title_label.y_offset = name_label.y_offset - 32.0
	var arriba: float = title_label.y_offset + 4.0
	band.position = Vector2(0, arriba)
	band.size = Vector2(size.x, maxf(abajo - arriba + 14.0, 0.0))


## Empieza la torre con una prueba: aparece, se queda y se desvanece lento.
func play(trial_name: String, trial_desc: String) -> void:
	title_label.text = Loc.t("Prueba")
	name_label.text = trial_name
	desc_label.text = trial_desc
	_layout()
	active = true
	_fade(HOLD, FADE)


## Se pausa: el cartel se va (la prueba se ve en el panel de información, que no tapa ni choca con nada).
func hide_for_pause() -> void:
	_kill()
	visible = false
	modulate.a = 0.0


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
