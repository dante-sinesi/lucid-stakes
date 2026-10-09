extends Control
## Las vidas: tres corazones de cubitos en 3D que giran, abajo a la derecha. Los que se perdieron quedan grises y quietos. Se ven siempre (torre y casino).
## Un corazón que se acaba de perder (o de ganar) da un saltito. `lives` y `max_lives` se actualizan desde el juego.

const AbilityArt := preload("res://scripts/ability_art.gd")

const SPACING := 76.0
const HEART := 6.2    # lado de un cubito del corazón, en píxeles

var max_lives := 3
var lives := 3:
	set(v):
		if v != lives:
			_pop = 1.0
		lives = v
		queue_redraw()
var _t := 0.0
var _pop := 0.0


func _init() -> void:
	name = "vidas"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SPACING * 3.0, 86)
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -SPACING * 3.0 - 16.0
	offset_top = -96.0
	offset_right = -16.0
	offset_bottom = -8.0


func _process(delta: float) -> void:
	_t += delta
	_pop = maxf(_pop - delta * 3.0, 0.0)
	queue_redraw()


func _draw() -> void:
	for i in max_lives:
		var owned := i < lives
		var c := Vector2(SPACING * (i + 0.5), size.y * 0.5 + 6.0)
		var s := HEART * (1.0 + (0.25 * sin(_pop * PI) if i == lives - 1 or i == lives else 0.0))
		AbilityArt.draw(self, "corazon", c, s, owned, _t + float(i) * 0.6)
