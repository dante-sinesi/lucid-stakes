extends RefCounted
## Estética de las mesas por nivel de casino: los juegos se "purifican" a medida que mejoran las salas.
## Taberna (0): lo gastado y corrupto de siempre · Salón (1): limpiado, madera barnizada y latón · Casino (2): madera pulida, filetes dorados, gemas ·
## Gran casino (3): marfil y oro brillante, filigrana y destellos. Todo con cubitos; `shine` (0 a 3) es cuánta animación extra hay (luces que corren,
## destellos, chispas al ganar) y `ornament` (0 a 3) cuánta decoración fija.
## `for_tier(t)` devuelve el estilo; `for_run(run)` el del casino donde se está jugando. `apply_ui` y `reset_ui` ajustan la corrupción de los botones y
## textos de la interfaz mientras se está en el casino.

const Draw := preload("res://scripts/voxel_draw.gd")
const Room := preload("res://scripts/casino_room.gd")

const UI_DEFAULT := 0.45   # la corrupción de la interfaz fuera del casino (la de VoxelDraw)

const TIERS: Array[Dictionary] = [
	{"name": "taberna", "corruption": 0.45, "ornament": 0, "shine": 0,
		"wood": Color(0.34, 0.20, 0.09), "gold": Color(0.66, 0.50, 0.20), "pocket_a": Color(1.0, 0.86, 0.5), "pocket_b": Color(0.95, 0.60, 0.34),
		"zero": Color(0.28, 0.08, 0.40), "divider": Color(0.30, 0.18, 0.08), "marker": Color(1.0, 0.82, 0.2), "chip": Color(1.0, 0.86, 0.25),
		"ball": Color(1, 1, 1), "window": Color(0.04, 0.02, 0.09), "strip": Color(0.13, 0.07, 0.22), "bg": Color(0.015, 0.008, 0.035),
		"felt": Color(0.07, 0.15, 0.12), "felt_edge": Color(0.04, 0.09, 0.07), "card": Color(0.93, 0.90, 0.82), "card_in": Color(0.96, 0.94, 0.88),
		"card_edge": Color(0.10, 0.05, 0.16), "back": Color(0.36, 0.14, 0.56), "back_dot": Color(0.62, 0.30, 0.85), "trim": Color(0.66, 0.50, 0.20)},
	{"name": "salon", "corruption": 0.28, "ornament": 1, "shine": 0,
		"wood": Color(0.46, 0.27, 0.12), "gold": Color(0.80, 0.62, 0.25), "pocket_a": Color(1.0, 0.89, 0.58), "pocket_b": Color(0.93, 0.50, 0.28),
		"zero": Color(0.32, 0.10, 0.48), "divider": Color(0.52, 0.36, 0.15), "marker": Color(1.0, 0.84, 0.25), "chip": Color(1.0, 0.88, 0.32),
		"ball": Color(1, 1, 1), "window": Color(0.04, 0.03, 0.12), "strip": Color(0.14, 0.09, 0.26), "bg": Color(0.015, 0.012, 0.04),
		"felt": Color(0.08, 0.25, 0.17), "felt_edge": Color(0.05, 0.15, 0.10), "card": Color(0.96, 0.94, 0.88), "card_in": Color(0.99, 0.98, 0.95),
		"card_edge": Color(0.45, 0.32, 0.13), "back": Color(0.28, 0.12, 0.50), "back_dot": Color(0.55, 0.30, 0.85), "trim": Color(0.80, 0.62, 0.25)},
	{"name": "casino", "corruption": 0.10, "ornament": 2, "shine": 2,
		"wood": Color(0.22, 0.12, 0.07), "gold": Color(0.92, 0.74, 0.28), "pocket_a": Color(1.0, 0.92, 0.66), "pocket_b": Color(0.78, 0.22, 0.20),
		"zero": Color(0.36, 0.12, 0.55), "divider": Color(0.88, 0.70, 0.26), "marker": Color(1.0, 0.86, 0.30), "chip": Color(1.0, 0.9, 0.38),
		"ball": Color(0.96, 0.94, 1.0), "window": Color(0.03, 0.04, 0.14), "strip": Color(0.11, 0.10, 0.28), "bg": Color(0.01, 0.015, 0.05),
		"felt": Color(0.05, 0.30, 0.20), "felt_edge": Color(0.03, 0.18, 0.12), "card": Color(0.98, 0.97, 0.93), "card_in": Color(1.0, 0.99, 0.97),
		"card_edge": Color(0.92, 0.74, 0.28), "back": Color(0.20, 0.10, 0.42), "back_dot": Color(0.92, 0.74, 0.28), "trim": Color(0.92, 0.74, 0.28)},
	{"name": "gran_casino", "corruption": 0.0, "ornament": 3, "shine": 3,
		"wood": Color(0.93, 0.90, 0.82), "gold": Color(1.0, 0.85, 0.35), "pocket_a": Color(0.98, 0.95, 0.88), "pocket_b": Color(0.74, 0.14, 0.20),
		"zero": Color(0.40, 0.14, 0.62), "divider": Color(1.0, 0.85, 0.35), "marker": Color(1.0, 0.88, 0.35), "chip": Color(1.0, 0.92, 0.45),
		"ball": Color(0.97, 0.95, 1.0), "window": Color(0.04, 0.05, 0.16), "strip": Color(0.10, 0.10, 0.30), "bg": Color(0.012, 0.02, 0.06),
		"felt": Color(0.04, 0.38, 0.26), "felt_edge": Color(0.02, 0.22, 0.15), "card": Color(1.0, 0.99, 0.96), "card_in": Color(1.0, 1.0, 0.99),
		"card_edge": Color(1.0, 0.85, 0.35), "back": Color(0.15, 0.08, 0.35), "back_dot": Color(1.0, 0.85, 0.35), "trim": Color(1.0, 0.85, 0.35)},
]


static func for_tier(tier: int) -> Dictionary:
	return TIERS[clampi(tier, 0, TIERS.size() - 1)]


## El nivel de sala donde se juega: el de la visita en curso, o (sin visita: pruebas) el de la etapa o el del escenario.
static func tier_for(run) -> int:
	var v = run.get("casino_visit") if run != null else null
	if v is Dictionary and not (v as Dictionary).is_empty():
		return int(v.tier)
	if run == null:
		return 0
	return Room.tier_of(int(run.stage)) if int(run.scenario().get("casino_tier", -1)) < 0 else int(run.scenario().casino_tier)


static func for_run(run) -> Dictionary:
	return for_tier(tier_for(run))


## Mientras se está en el casino, los botones y textos de la interfaz se limpian según el nivel de la sala.
static func apply_ui(tier: int) -> void:
	Draw.default_corruption = float(for_tier(tier).corruption)


static func reset_ui() -> void:
	Draw.default_corruption = UI_DEFAULT


## Destello que corre: 0 a 1 según el tiempo, con una pausa entre pasadas (para barridos de brillo).
static func sweep(t: float, period := 2.4) -> float:
	var u := fposmod(t, period) / period
	return u * 1.6 - 0.3   # pasa de -0.3 a 1.3: una parte del recorrido queda fuera de la pieza (pausa)


## Ornamento de marco para una pieza dibujada con Draw.card (misma geometría de cubitos): recolorea el borde con el material del nivel, agrega
## tachuelas, esquinas con gemas y, con shine, luces que corren y titilan. `active`: luces más vivas (por ejemplo mientras gira un rodillo).
static func frame(ci: CanvasItem, rect: Rect2, s: float, th: Dictionary, t: float, active := false) -> void:
	var orn: int = th.ornament
	if orn == 0:
		return
	var cols := maxi(int(rect.size.x / s), 3)
	var rows := maxi(int(rect.size.y / s), 3)
	var origin := rect.position + Vector2((rect.size.x - cols * s) * 0.5, 0)
	var trim: Color = th.trim
	var ring: Array[Vector2i] = []
	for x in cols:
		ring.append(Vector2i(x, 0))
	for y in range(1, rows):
		ring.append(Vector2i(cols - 1, y))
	for x in range(cols - 2, -1, -1):
		ring.append(Vector2i(x, rows - 1))
	for y in range(rows - 2, 0, -1):
		ring.append(Vector2i(0, y))
	for i in ring.size():
		var c: Vector2i = ring[i]
		var pos := origin + Vector2(c) * s
		var col := trim
		if orn == 1:
			if i % 4 != 0:
				continue   # sólo tachuelas sueltas de latón
			col = trim.darkened(0.1)
		elif orn == 2:
			col = trim.darkened(0.12 * float(i % 2))
		else:
			col = trim.lightened(0.10 * float(i % 3 == 0))
		Draw.cube(ci, pos, s, col, true)
	if orn >= 2:   # gemas en las esquinas
		var gem := Color(0.9, 0.25, 0.3) if orn == 2 else Color(0.35, 0.8, 1.0)
		for c in [Vector2i(0, 0), Vector2i(cols - 1, 0), Vector2i(0, rows - 1), Vector2i(cols - 1, rows - 1)]:
			var tw := 0.75 + 0.25 * sin(t * 3.0 + float(c.x + c.y))
			Draw.cube(ci, origin + Vector2(c) * s, s, gem.lightened(0.25 * tw), true)
	if int(th.shine) >= 2 and ring.size() > 0:   # luces que recorren el marco
		var n := ring.size()
		var head := int(t * (24.0 if active else 9.0)) % n
		for k in 5:
			var c2: Vector2i = ring[(head - k + n) % n]
			var a := 1.0 - float(k) * 0.2
			Draw.cube(ci, origin + Vector2(c2) * s, s, Color(1.0, 0.97, 0.75).lerp(trim, 1.0 - a), true)


## Chispas doradas: un estallido que sube y se apaga (para ganar en los niveles altos).
class Sparkles extends Control:
	var _p: Array[Dictionary] = []   # {pos, vel, life, max, size, color}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		set_process(false)

	func burst(center: Vector2, count: int, colors: Array, spread := 260.0) -> void:
		for i in count:
			var ang := randf() * TAU
			var sp := randf_range(0.25, 1.0) * spread
			_p.append({"pos": center, "vel": Vector2.from_angle(ang) * sp + Vector2(0, -60), "life": 0.0, "max": randf_range(0.6, 1.2),
					"size": float(2 + randi() % 3) * 2.0, "color": colors[randi() % colors.size()]})
		set_process(true)

	func _process(delta: float) -> void:
		for q in _p:
			q.life += delta
			q.pos += q.vel * delta
			q.vel = q.vel * pow(0.2, delta) + Vector2(0, 220) * delta
		_p = _p.filter(func(q): return q.life < q.max)
		if _p.is_empty():
			set_process(false)
		queue_redraw()

	func _draw() -> void:
		for q in _p:
			var a: float = 1.0 - float(q.life) / float(q.max)
			var c: Color = q.color
			draw_rect(Rect2(q.pos - Vector2.ONE * q.size * 0.5, Vector2.ONE * q.size), Color(c, a))
