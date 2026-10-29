extends Control
## Dibujo de la rueda de la ruleta hecha de cubitos: 13 casillas, cada una con el ícono de su rareza (épica, rara, común o bolsa de claridad) y la
## bola fija arriba. La rueda gira (rotation_angle) y la casilla que queda bajo la bola es la que cae.
## La mugre (cubitos corrompidos y huecos) queda fija en pantalla mientras la rueda gira.

const Roulette := preload("res://scripts/casino/roulette.gd")
const Items := preload("res://scripts/datos/items.gd")
const Draw := preload("res://scripts/ui/voxel_draw.gd")
const CasinoTheme := preload("res://scripts/casino/casino_theme.gd")

const CUBE := 10.0   # lado de un cubito de la rueda, en píxeles

var rotation_angle := 0.0:
	set(v):
		rotation_angle = v
		queue_redraw()
var tiers: Array[int] = Roulette.WHEEL.duplicate()   # la rareza de cada casilla (con Casilla de regalo, una de las comunes es épica)
var result := -1:
	set(v):
		result = v
		queue_redraw()


## Animaciones: el marcador da un golpecito cada vez que pasa una casilla, la bola salta al caer y la casilla ganadora parpadea.
var th := CasinoTheme.for_tier(0)     # estética según el nivel del casino (casino_theme.gd): la rueda se purifica con las salas
var _anim := 0.0
var _anim_frame := -1
var spinning := false
var kick := 0.0                 # golpe del marcador (1 = recién pasó una casilla)
var ball_off := 0.0             # desplazamiento vertical de la bola, en cubitos (negativo = arriba)
var win_t := -1.0               # segundos desde que se marcó la ganadora (-1 = no hay)
var _last_under := -1
const WIN_BLINK := 1.6


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	var dirty := false
	if int(th.shine) > 0:   # destellos: se redibuja unas 8 veces por segundo
		_anim += delta
		var fr := int(_anim * 8.0)
		if fr != _anim_frame:
			_anim_frame = fr
			dirty = true
	if spinning:
		var u := pocket_under_ball()
		if u != _last_under:
			_last_under = u
			kick = 1.0
	if kick > 0.0:
		kick = maxf(0.0, kick - delta * 7.0)
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
	return th.pocket_a if i % 2 == 1 else th.pocket_b


## Íconos de cubitos de cada rareza (7 x 7): a = color, b = brillo.
const ICON_ROWS := {
	Items.Tier.EPICO: ["...a...", "..aaa..", ".aabaa.", "aabbbaa", ".aabaa.", "..aaa..", "...a..."],
	Items.Tier.RARO: ["...a...", "..aba..", ".aabaa.", "aaaaaaa", ".aabaa.", "..aba..", "...a..."],
	Items.Tier.COMUN: [".aaaaa.", "aaaaaaa", "aabbbaa", "aabaaaa", "aabbaaa", "aaaaaaa", ".aaaaa."],
	Items.Tier.CONSUMIBLE: ["..aaa..", "...b...", "..aaa..", ".aaaaa.", "aaabaaa", "aaaaaaa", ".aaaaa."],
}
const ICON_COLORS := {
	Items.Tier.EPICO: [Color(0.78, 0.38, 1.0), Color(1.0, 0.9, 0.4)],
	Items.Tier.RARO: [Color(0.35, 0.65, 1.0), Color(0.85, 0.95, 1.0)],
	Items.Tier.COMUN: [Color(0.72, 0.72, 0.78), Color(0.95, 0.95, 1.0)],
	Items.Tier.CONSUMIBLE: [Color(0.98, 0.82, 0.30), Color(0.55, 0.32, 0.10)],
}


## Dibuja el ícono de una rareza centrado en `center`, con una sombra dura y cubitos de `cell` píxeles.
func _icon(tier: int, center: Vector2, cell: float) -> void:
	var rows: Array = ICON_ROWS[tier]
	var cols: Array = ICON_COLORS[tier]
	var origin := center - Vector2(7, 7) * cell * 0.5
	for y in 7:
		for x in 7:
			var ch: String = rows[y][x]
			if ch == ".":
				continue
			draw_rect(Rect2(origin + Vector2(x, y) * cell + Vector2(2, 3), Vector2(cell, cell)), Color(0, 0, 0, 0.45))
	for y in 7:
		for x in 7:
			var ch: String = rows[y][x]
			if ch == ".":
				continue
			Draw.cube(self, origin + Vector2(x, y) * cell, cell, cols[0] if ch == "a" else cols[1], true)


func _draw() -> void:
	var g := CUBE
	var c := size / 2.0
	var radius := int(minf(size.x, size.y) / 2.0 / g) - 2     # radio de la rueda en cubitos
	var k: float = th.corruption
	var orn: int = th.ornament
	var shine: int = th.shine
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
				var wood: Color = (th.wood as Color).lightened(0.12 * float((i + j) & 1))
				if orn >= 1 and (i * 3 + j * 5) % 4 == 0:   # tachuelas de metal en el aro (y gemas en los niveles altos)
					wood = th.gold
					if orn >= 2 and (i + j) % 8 == 0:
						wood = Color(0.9, 0.2, 0.28) if orn == 2 else Color(0.35, 0.8, 1.0)
				Draw.cube(self, pos, g, wood if n > k * 0.30 else Draw.corrupt_color(n), true)
				continue
			if d > radius - 1.6:  # aro dorado
				var ring: Color = th.gold
				if shine >= 2:   # algunos cubitos del aro brillan y se apagan
					var tw := Draw.noise(i + 40, j + 40, int(_anim * 3.0) + 7)
					if tw > 0.93:
						ring = ring.lightened(0.55)
				Draw.cube(self, pos, g, ring if n > k * 0.25 else Draw.corrupt_color(n), true)
				continue
			if d < 2.2:  # el centro
				Draw.cube(self, pos, g, th.gold, true)
				continue
			var p := pocket_at(float(i), float(j))
			var col := pocket_color(p).darkened(0.25)   # (un poco más oscura: los íconos resaltan)
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
			Draw.cube(self, origin + cell * g, g, th.divider, true)
			if p == result or p == (result + 1) % Roulette.POCKETS:
				var lit := Color.WHITE
				if win_t >= 0.0 and int(win_t * 8.0) % 2 == 1:
					lit = Color(1.0, 0.8, 0.2)   # parpadea unos instantes
				Draw.cube(self, origin + cell * g, g, lit, true)
	# el ícono de la rareza de cada casilla, siempre derecho
	for p in Roulette.POCKETS:
		var mid := rotation_angle + p * sector() - PI / 2.0
		_icon(tiers[p], c + Vector2.from_angle(mid) * float(radius) * g * 0.68, 6.0)
	# marcador (flecha de cubitos) y bola, fijos arriba
	var top := c + Vector2(0, -(radius + 1) * g - kick * g * 0.9)
	for step in 3:
		for w in (3 - step):
			Draw.cube(self, top + Vector2((w - (2 - step) * 0.5 - 0.5) * g, -(3 - step) * g), g, th.marker, true)
	if orn >= 2:   # gema en la punta del marcador
		Draw.cube(self, top + Vector2(-g * 0.5, -3.0 * g), g, Color(0.9, 0.2, 0.28) if orn == 2 else Color(0.35, 0.8, 1.0), true)
	var ball_pos := c + Vector2(-g * 0.5, (-(radius - 2.5) + ball_off) * g)
	Draw.cube(self, ball_pos, g, th.ball, true)
	if shine >= 2:   # reflejo de la bola
		draw_rect(Rect2(ball_pos + Vector2(g * 0.2, g * 0.2), Vector2(g * 0.25, g * 0.25)), Color(1, 1, 1))
	# adorno del centro: una gema en el casino y una corona de cubitos en el gran casino
	if orn >= 2:
		var cc := c - Vector2(g * 0.5, g * 0.5)
		if orn == 2:
			Draw.cube(self, cc, g, Color(0.9, 0.2, 0.28).lightened(0.2 * sin(_anim * 3.0)), true)
		else:
			for x in range(-2, 3):
				Draw.cube(self, cc + Vector2(x, 0.6) * g, g, th.marker, true)
			for x in [-2, 0, 2]:
				Draw.cube(self, cc + Vector2(x, -0.5) * g, g, th.marker.lightened(0.15), true)
			Draw.cube(self, cc + Vector2(0, 0.6) * g, g, Color(0.35, 0.8, 1.0).lightened(0.25 * sin(_anim * 4.0)), true)
