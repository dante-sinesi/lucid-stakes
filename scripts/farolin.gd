extends RefCounted
## Farolín: el farol con piernas y brazos que cobra el peaje en la puerta de salida de cada casino y enciende el portal de la torre que sigue.
## `build()` arma su modelo 3D (cubos, con la llama que titila y una luz cálida), `FACE` es su cara para el cuadro de diálogo (12 x 13 cubitos,
## como la del tabernero) y `toll_dialog()` arma lo que dice y las salidas que ofrece cuando se llega a la puerta (pagar, rehacer la torre o abandonar).

const Loc := preload("res://scripts/loc.gd")

const SPEAKER := "Farolín"

const FACE := ["....kkkk....", "...k....k...", "..kkkkkkkk..", ".kkkkkkkkkk.", ".kOYYYYYYOk.", ".kYEEYYEEYk.", ".kYEEYYEEYk.",
		"aakYYYYYYkaa", ".kYEYYYYEYk.", ".kOYEEEEYOk.", ".kkkkkkkkkk.", "..kkkkkkkk..", "..bb....bb.."]
const FACE_PAL := {"k": Color(0.16, 0.14, 0.18), "Y": Color(1.0, 0.86, 0.35), "E": Color(0.18, 0.1, 0.05), "O": Color(1.0, 0.55, 0.15),
		"a": Color(0.3, 0.27, 0.32), "b": Color(0.3, 0.27, 0.32)}

## Lo que sale de las decisiones de la puerta.
const PAY := "pagar"
const REDO := "rehacer"
const GIVE_UP := "abandonar"


## Dibuja la cara de Farolín en un control: `origin` es la esquina de arriba a la izquierda y `s` el lado de un cubito.
static func draw_face(ci: CanvasItem, origin: Vector2, s: float) -> void:
	for y in FACE.size():
		var row: String = FACE[y]
		for x in row.length():
			if row[x] == ".":
				continue
			var col: Color = FACE_PAL.get(row[x], Color.MAGENTA)
			var p := origin + Vector2(x, y) * s
			ci.draw_rect(Rect2(p, Vector2(s, s)), col)
			ci.draw_rect(Rect2(p, Vector2(s, maxf(s * 0.18, 1.0))), col.lightened(0.3))
			ci.draw_rect(Rect2(p + Vector2(0, s * 0.82), Vector2(s, maxf(s * 0.18, 1.0))), col.darkened(0.35))


## Lo que dice Farolín en la puerta y las dos salidas que ofrece: {text, options: [{id, text, enabled}]}.
##  - con vidas (o Tótem): "Pagar N" o "Rehacer la torre (−1 vida)"; si no alcanza la claridad, Pagar va apagado;
##  - sin vidas: "Pagar N" o "Abandonar" (se pierde el run).
static func toll_dialog(price: int, have: int, can_redo: bool, redo_costs_life := true) -> Dictionary:
	var can_pay := have >= price
	var short := price - have
	var text := ""
	if can_redo:
		if can_pay:
			text = Loc.f("Son %d de claridad para seguir. ¿Pagás, o volvés a subir esta torre?", [price])
		else:
			text = Loc.f("Son %d de claridad y te faltan %d. Sin luz no hay camino: ¿volvés a subir la torre?", [price, short])
	else:
		if can_pay:
			text = Loc.f("Son %d de claridad, y ya no te queda ninguna vida. ¿Pagás, o dejás que todo se apague?", [price])
		else:
			text = Loc.f("Son %d de claridad, te faltan %d y ya no te queda ninguna vida. ¿Dejás que todo se apague?", [price, short])
	var second := {"id": REDO, "text": Loc.t("Rehacer la torre (−1 vida)") if redo_costs_life else Loc.t("Rehacer la torre"), "enabled": true} if can_redo \
			else {"id": GIVE_UP, "text": Loc.t("Abandonar"), "enabled": true}
	return {"text": text, "options": [{"id": PAY, "text": Loc.f("Pagar %d", [price]), "enabled": can_pay}, second]}


static func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, glow := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


## Farolín en 3D (unos 0,55 de alto, los pies en y = 0), mirando hacia +z: un farol de hierro con asa, la llama con ojos y sonrisa dentro del vidrio,
## bracitos y patitas. La llama titila (ver farolin_node.gd) y alumbra la sala con una luz cálida.
static func build() -> Node3D:
	var r: Node3D = preload("res://scripts/farolin_node.gd").new()
	r.name = "farolin"
	var iron := Color(0.16, 0.14, 0.18)
	var iron2 := Color(0.3, 0.27, 0.32)
	var glow := Color(1.0, 0.8, 0.3)
	var dark := Color(0.25, 0.1, 0.02)
	_box(r, Vector3(-0.06, 0.06, 0), Vector3(0.06, 0.12, 0.07), iron2)   # patitas
	_box(r, Vector3(0.06, 0.06, 0), Vector3(0.06, 0.12, 0.07), iron2)
	_box(r, Vector3(0, 0.145, 0), Vector3(0.22, 0.05, 0.22), iron)       # base del farol
	r.flame = _box(r, Vector3(0, 0.27, 0), Vector3(0.17, 0.2, 0.17), glow, 1.6)   # el vidrio con la llama
	for sx in [-1, 1]:   # marco: cuatro parantes
		for sz in [-1, 1]:
			_box(r, Vector3(0.09 * sx, 0.27, 0.09 * sz), Vector3(0.025, 0.21, 0.025), iron)
	_box(r, Vector3(0, 0.385, 0), Vector3(0.24, 0.04, 0.24), iron)       # tapa
	_box(r, Vector3(0, 0.425, 0), Vector3(0.13, 0.04, 0.13), iron)
	_box(r, Vector3(0, 0.505, 0), Vector3(0.11, 0.02, 0.02), iron)       # asa
	_box(r, Vector3(-0.055, 0.465, 0), Vector3(0.02, 0.08, 0.02), iron)
	_box(r, Vector3(0.055, 0.465, 0), Vector3(0.02, 0.08, 0.02), iron)
	_box(r, Vector3(-0.04, 0.31, 0.092), Vector3(0.035, 0.055, 0.012), dark)   # ojos
	_box(r, Vector3(0.04, 0.31, 0.092), Vector3(0.035, 0.055, 0.012), dark)
	r.smile = Node3D.new()   # sonrisa
	r.add_child(r.smile)
	_box(r.smile, Vector3(0, 0.235, 0.092), Vector3(0.09, 0.02, 0.012), dark)
	_box(r.smile, Vector3(-0.045, 0.25, 0.092), Vector3(0.02, 0.02, 0.012), dark)
	_box(r.smile, Vector3(0.045, 0.25, 0.092), Vector3(0.02, 0.02, 0.012), dark)
	r.frown = Node3D.new()   # (carita triste: las puntas de la boca para abajo)
	r.frown.visible = false
	r.add_child(r.frown)
	_box(r.frown, Vector3(0, 0.25, 0.092), Vector3(0.09, 0.02, 0.012), dark)
	_box(r.frown, Vector3(-0.045, 0.235, 0.092), Vector3(0.02, 0.02, 0.012), dark)
	_box(r.frown, Vector3(0.045, 0.235, 0.092), Vector3(0.02, 0.02, 0.012), dark)
	_box(r, Vector3(-0.145, 0.24, 0), Vector3(0.05, 0.13, 0.05), iron2)  # bracitos
	_box(r, Vector3(0.145, 0.24, 0), Vector3(0.05, 0.13, 0.05), iron2)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.28, 0.15)
	light.light_color = Color(1.0, 0.75, 0.35)
	light.light_energy = 1.3
	light.omni_range = 2.0
	r.light = light
	r.add_child(light)
	return r
