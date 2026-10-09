extends Control
## Dibujo de la rueda de la ruleta hecha de cubitos: 13 casillas (la 0 es la Pesadilla), las casillas cubiertas con ficha y la
## bola fija arriba. La rueda gira (rotation_angle) y la casilla que queda bajo la bola es la que cae.
## La mugre (cubitos corrompidos y huecos) queda fija en pantalla mientras la rueda gira.

const Roulette := preload("res://scripts/roulette.gd")
const VFont := preload("res://scripts/voxel_font.gd")
const Draw := preload("res://scripts/voxel_draw.gd")

const CUBE := 10.0   # lado de un cubito de la rueda, en píxeles

## Se emite al tocar una casilla (la 0, de la casa, no se puede cubrir). Usa la rotación ACTUAL de la rueda: lo que ves es lo que tocás.
signal pocket_clicked(pocket: int)

var rotation_angle := 0.0:
	set(v):
		rotation_angle = v
		queue_redraw()
var covered: Array = []:
	set(v):
		for p in v:
			if not covered.has(p):
				chip_age[p] = 0.0   # ficha nueva: salta y cae sobre la casilla
		covered = v
		queue_redraw()
var result := -1:
	set(v):
		result = v
		queue_redraw()
var hover_pocket := -1:
	set(v):
		if v != hover_pocket:
			hover_pocket = v
			queue_redraw()


## Animaciones: el marcador da un golpecito cada vez que pasa una casilla, la bola salta al caer, las fichas nuevas rebotan,
## la casilla ganadora parpadea y la rueda tiembla cuando gana la casa.
var spinning := false
var kick := 0.0                 # golpe del marcador (1 = recién pasó una casilla)
var ball_off := 0.0             # desplazamiento vertical de la bola, en cubitos (negativo = arriba)
var shake_px := 0.0
var chip_age := {}              # casilla -> segundos desde que se puso la ficha
var win_t := -1.0               # segundos desde que se marcó la ganadora (-1 = no hay)
var _last_under := -1
const CHIP_TIME := 0.35
const WIN_BLINK := 1.6


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	var dirty := false
	if spinning:
		var u := pocket_under_ball()
		if u != _last_under:
			_last_under = u
			kick = 1.0
	if kick > 0.0:
		kick = maxf(0.0, kick - delta * 7.0)
		dirty = true
	if shake_px > 0.05:
		shake_px *= pow(0.02, delta)
		dirty = true
	elif shake_px != 0.0:
		shake_px = 0.0
		dirty = true
	for p in chip_age.keys():
		chip_age[p] += delta
		if chip_age[p] >= CHIP_TIME:
			chip_age.erase(p)
		dirty = true
	if win_t >= 0.0:
		win_t += delta
		dirty = true
		if win_t > WIN_BLINK:
			win_t = -1.0
	if dirty:
		queue_redraw()


## La bola rebota unas veces cada vez más bajo al caer en su casilla.
func ball_hop() -> void:
	var tw := create_tween()
	var h := 3.2
	for i in 4:
		tw.tween_property(self, "ball_off", -h, 0.11 + 0.01 * i).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "ball_off", 0.0, 0.11 + 0.01 * i).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		h *= 0.45


## Radio de la rueda en píxeles (la parte donde se eligen casillas: ni el aro ni el centro).
func wheel_radius() -> float:
	return (int(minf(size.x, size.y) / 2.0 / CUBE) - 2) * CUBE


## Casilla bajo un punto local del control, o -1 si cae en el aro, en el centro o afuera.
func pocket_at_point(p: Vector2) -> int:
	var d := p - size / 2.0
	var r := wheel_radius()
	if d.length() > r - CUBE * 1.6 or d.length() < CUBE * 2.2:
		return -1
	return pocket_at(d.x, d.y)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var p := pocket_at_point(event.position)
		hover_pocket = p if p > 0 else -1
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := pocket_at_point(event.position)
		if p > 0:
			pocket_clicked.emit(p)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover_pocket = -1


func sector() -> float:
	return TAU / Roulette.POCKETS


## Ángulo de la rueda que deja la casilla `pocket` bajo la bola (arriba).
func angle_for(pocket: int) -> float:
	return -pocket * sector()


## Casilla que está bajo la bola con la rotación actual.
func pocket_under_ball() -> int:
	var a := fposmod(-rotation_angle, TAU)
	return int(round(a / sector())) % Roulette.POCKETS


## Casilla de la rueda en el punto (dx, dy) respecto del centro, con la rotación actual (ángulo de pantalla: 0 = derecha).
func pocket_at(dx: float, dy: float) -> int:
	var rel := fposmod(atan2(dy, dx) - (rotation_angle - PI / 2.0) + sector() / 2.0, TAU)
	return int(rel / sector()) % Roulette.POCKETS


func pocket_color(i: int) -> Color:
	if i == 0:
		return Color(0.28, 0.08, 0.40)   # la Pesadilla
	return Color(1.0, 0.86, 0.5) if i % 2 == 1 else Color(0.95, 0.60, 0.34)


func _draw() -> void:
	if shake_px > 0.05:
		draw_set_transform(Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_px)
	var g := CUBE
	var c := size / 2.0
	var radius := int(minf(size.x, size.y) / 2.0 / g) - 2     # radio de la rueda en cubitos
	var k := Draw.default_corruption
	var origin := c - Vector2(0.5, 0.5) * g
	draw_circle(c + Vector2(g * 0.8, g * 1.2), (radius + 1) * g, Color(0, 0, 0, 0.5))   # sombra dura de la rueda
	for j in range(-radius - 1, radius + 2):
		for i in range(-radius - 1, radius + 2):
			var d := sqrt(float(i * i + j * j))
			if d > radius + 1.0:
				continue
			var pos := origin + Vector2(i, j) * g
			var n := Draw.noise(i + 64, j + 64, 11)
			if d > radius - 0.5:  # aro exterior de madera
				if n < k * 0.10:
					continue
				var wood := Color(0.34, 0.2, 0.09).lightened(0.12 * float((i + j) & 1))
				Draw.cube(self, pos, g, wood if n > k * 0.30 else Draw.corrupt_color(n), true)
				continue
			if d > radius - 1.6:  # aro dorado
				Draw.cube(self, pos, g, Color(0.88, 0.68, 0.26) if n > k * 0.25 else Draw.corrupt_color(n), true)
				continue
			if d < 2.2:  # el centro
				Draw.cube(self, pos, g, Color(0.88, 0.68, 0.26), true)
				continue
			var p := pocket_at(float(i), float(j))
			var col := pocket_color(p)
			if covered.has(p):   # las casillas elegidas se oscurecen: así las fichas doradas resaltan
				col = col.darkened(0.55)
			elif p == hover_pocket:
				col = col.lightened(0.15)
			if n < k * 0.12 * (0.4 + d / radius):  # mugre que va creciendo hacia afuera
				col = Draw.corrupt_color(n)
			Draw.cube(self, pos, g, col, true)
	# separaciones entre casillas y marca de la ganadora
	for p in Roulette.POCKETS:
		var mid := rotation_angle + p * sector() - PI / 2.0
		var a0 := mid - sector() / 2.0
		var steps := radius - 4
		for s in range(3, steps + 2):
			var pt := c + Vector2.from_angle(a0) * (s * g)
			var cell := Vector2(roundf((pt.x - c.x) / g), roundf((pt.y - c.y) / g))
			Draw.cube(self, origin + cell * g, g, Color(0.30, 0.18, 0.08), true)
			if p == result or p == (result + 1) % Roulette.POCKETS:
				var lit := Color.WHITE
				if win_t >= 0.0 and int(win_t * 8.0) % 2 == 1:
					lit = Color(1.0, 0.8, 0.2)   # parpadea unos instantes
				Draw.cube(self, origin + cell * g, g, lit, true)
	# números de cada casilla, siempre derechos (cubitos de 2 píxeles)
	for p in Roulette.POCKETS:
		var mid := rotation_angle + p * sector() - PI / 2.0
		var lp := c + Vector2.from_angle(mid) * float(radius) * g * 0.74
		var txt := str(p)
		var l := VFont.layout([txt])
		var tsize := Vector2(l.size) * 3.0
		var col := Color(0.85, 0.65, 1.0) if p == 0 else (Color(1.0, 0.95, 0.8) if covered.has(p) else Color(0.22, 0.10, 0.04))
		Draw.text_cells(self, lp - tsize / 2.0, l.cells, l.size.y, 3.0, col, 0.0, p, true)
		if covered.has(p):  # ficha: una pila de cubitos dorados y brillantes sobre la casilla oscurecida
			var cp := c + Vector2.from_angle(mid) * float(radius) * g * 0.52
			var cs := g * 2.0
			var lift := 0.0
			if chip_age.has(p):   # la ficha salta y cae
				lift = sin(chip_age[p] / CHIP_TIME * PI) * cs * 1.6
			for h in 3:
				var base := cp - Vector2(cs * 0.5, cs * 0.5 + h * cs * 0.55 + lift)
				draw_rect(Rect2(base + Vector2(2, 3), Vector2(cs, cs)), Color(0, 0, 0, 0.55))
				Draw.cube(self, base, cs, Color(1.0, 0.86, 0.25).lightened(0.12 * h), true)
			draw_rect(Rect2(cp - Vector2(cs * 0.5, cs * 0.5 + 2 * cs * 0.55), Vector2(cs, 2)), Color(1, 1, 0.85))
	# marcador (flecha de cubitos) y bola, fijos arriba
	var top := c + Vector2(0, -(radius + 1) * g - kick * g * 0.9)
	for step in 3:
		for w in (3 - step):
			Draw.cube(self, top + Vector2((w - (2 - step) * 0.5 - 0.5) * g, -(3 - step) * g), g, Color(1.0, 0.82, 0.2), true)
	Draw.cube(self, c + Vector2(-g * 0.5, (-(radius - 2.5) + ball_off) * g), g, Color.WHITE, true)
