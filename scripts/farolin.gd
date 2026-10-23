extends RefCounted
## Farolín: el farol con piernas y brazos que cobra el peaje en la puerta de salida de cada casino y enciende el portal de la torre que sigue.
## `build()` arma su modelo 3D (cubos, con la llama que titila y una luz cálida), `FACE` es su cara para el cuadro de diálogo (12 x 13 cubitos,
## como la del tabernero) y `toll_dialog()` arma lo que dice y las salidas que ofrece cuando se llega a la puerta (pagar, rehacer la torre o abandonar).

const Loc := preload("res://scripts/loc.gd")

const SPEAKER := "Farolín"

const FACE := ["....kkkk....", "...k....k...", "..kkkkkkkk..", ".kkkkkkkkkk.", ".kOYYYYYYOk.", ".kYEEYYEEYk.", ".kYEEYYEEYk.",
		"aakYYYYYYkaa", ".kYEYYYYEYk.", ".kOYEEEEYOk.", ".kkkkkkkkkk.", "..kkkkkkkk..", "..bb....bb.."]
## Tres diseños nuevos de la cara (sin la sonrisa) para elegir: 1 "Sereno" (ojos altos, sin boca), 2 "Boquita" (ojos redondos y una boca chica en o), 3 "Cíclope" (un solo ojo grande).
## El 0 es el de siempre. `Farolin.variant` es el que se usa en el juego.
const FACE_VARIANTS := [
	["....kkkk....", "...k....k...", "..kkkkkkkk..", ".kkkkkkkkkk.", ".kOYYYYYYOk.", ".kYEEYYEEYk.", ".kYEEYYEEYk.",
			"aakYYYYYYkaa", ".kYEYYYYEYk.", ".kOYEEEEYOk.", ".kkkkkkkkkk.", "..kkkkkkkk..", "..bb....bb.."],
	["....kkkk....", "...k....k...", "..kkkkkkkk..", ".kkkkkkkkkk.", ".kOYYYYYYOk.", ".kYEwYYEwYk.", ".kYEEYYEEYk.",
			"aakEEYYEEkaa", ".kYYYYYYYYk.", ".kOYYYYYYOk.", ".kkkkkkkkkk.", "..kkkkkkkk..", "..bb....bb.."],
	["....kkkk....", "...k....k...", "..kkkkkkkk..", ".kkkkkkkkkk.", ".kOYYYYYYOk.", ".kYEEYYEEYk.", ".kYEEYYEEYk.",
			"aakYYYYYYkaa", ".kYYYEEYYYk.", ".kOYYEEYYOk.", ".kkkkkkkkkk.", "..kkkkkkkk..", "..bb....bb.."],
	["....kkkk....", "...k....k...", "..kkkkkkkk..", ".kkkkkkkkkk.", ".kOYYYYYYOk.", ".kYYYEEYYYk.", ".kYYEEEEYYk.",
			"aakYEEEEYkaa", ".kYYYEEYYYk.", ".kOYYYYYYOk.", ".kkkkkkkkkk.", "..kkkkkkkk..", "..bb....bb.."],
]
static var variant := 1   # el diseño de Farolín que se usa (0 = el de siempre con sonrisa; 1 = "Sereno", el elegido)


static func face_rows(v := -1) -> Array:
	return FACE_VARIANTS[clampi(variant if v < 0 else v, 0, FACE_VARIANTS.size() - 1)]


const FACE_PAL := {"k": Color(0.16, 0.14, 0.18), "Y": Color(1.0, 0.86, 0.35), "E": Color(0.18, 0.1, 0.05), "O": Color(1.0, 0.55, 0.15),
		"a": Color(0.3, 0.27, 0.32), "b": Color(0.3, 0.27, 0.32), "w": Color(1.0, 0.98, 0.85)}

## Lo que sale de las decisiones de la puerta.
const PAY := "pagar"
const REDO := "rehacer"
const GIVE_UP := "abandonar"

## El peaje de práctica del final del tutorial: una sola salida (pagar), con la claridad que presta el tabernero.
static func practice_dialog(price: int) -> Dictionary:
	return {"text": Loc.f("Son %d de claridad para seguir. Como es tu primera vez, hoy te la presta el tabernero.", [price]), "options": [{"id": PAY, "text": Loc.f("Pagar %d", [price]), "enabled": true}]}


## Lo que dice Farolín después de cada decisión (antes de que pase lo que se eligió).
const REACTIONS := {
	PAY: "Gracias, soñador. Te prendo el camino.",
	REDO: "Otra vez a subir. La luz no se va a ningún lado.",
	GIVE_UP: "Entonces se apaga todo... Nos vemos en el próximo sueño.",
}


## Lo que dice Farolín cuando llegás a un checkpoint de la torre: cuántos faltan (contando el portal) según cuánto se subió. `indice`: el número de checkpoint, para variar la frase.
static func checkpoint_line(faltan: int, total: int, indice: int) -> String:
	if faltan <= 1:
		var ultimas := ["Ya casi: la siguiente es la última.", "Último tramo, soñador. La siguiente es la última."]
		return Loc.t(ultimas[indice % ultimas.size()])
	var avance := float(total - faltan) / float(maxi(total, 1))
	var frases: Array
	if indice <= 1:
		frases = ["Buen comienzo, soñador. Faltan %d.", "¡Así se empieza! Faltan %d."]
	elif avance < 0.66:
		frases = ["Vas bien. Faltan %d.", "Sigue subiendo, soñador. Faltan %d.", "La luz te sigue. Faltan %d."]
	else:
		frases = ["Ya queda poco. Faltan %d.", "Se ve el final... Faltan %d."]
	return Loc.f(str(frases[indice % frases.size()]), [faltan])


static func reaction(id: String) -> String:
	return Loc.t(str(REACTIONS.get(id, "")))


## Dibuja la cara de Farolín en un control: `origin` es la esquina de arriba a la izquierda y `s` el lado de un cubito.
static func draw_face(ci: CanvasItem, origin: Vector2, s: float, v := -1, bob := Vector2.ZERO) -> void:
	var rows: Array = face_rows(v)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch: String = row[x]
			if ch == ".":
				continue
			var col: Color = FACE_PAL.get(ch, Color.MAGENTA)
			var p := origin + Vector2(x, y) * s + bob
			if ch == "Y" or ch == "O" or ch == "E" or ch == "w":   # el vidrio con la llama: liso (sin biseles) y más claro hacia el centro
				if ch == "Y":
					col = col.lerp(Color(1.0, 0.97, 0.72), (1.0 - absf(float(x) - 5.5) / 5.5) * 0.4)
				ci.draw_rect(Rect2(p, Vector2(s + 0.6, s + 0.6)), col)
			else:   # el hierro, en cubitos
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
			text = Loc.f("Son %d de claridad para seguir. ¿Pagas, o vuelves a subir esta torre?", [price])
		else:
			text = Loc.f("Son %d de claridad y te faltan %d. Sin luz no hay camino: ¿vuelves a subir la torre?", [price, short])
	else:
		if can_pay:
			text = Loc.f("Son %d de claridad, y ya no te queda ninguna vida. ¿Pagas, o dejas que todo se apague?", [price])
		else:
			text = Loc.f("Son %d de claridad, te faltan %d y ya no te queda ninguna vida. ¿Dejas que todo se apague?", [price, short])
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
static func build(v := -1, seated := false) -> Node3D:
	var kind := variant if v < 0 else v
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
	r.smile = Node3D.new()   # la cara "contenta" (la de siempre lleva sonrisa; los diseños nuevos no)
	r.add_child(r.smile)
	r.frown = Node3D.new()   # la cara "triste"
	r.frown.visible = false
	r.add_child(r.frown)
	match kind:
		1:   # Sereno: ojos altos, sin boca; triste = cejitas caídas
			_box(r, Vector3(-0.045, 0.285, 0.092), Vector3(0.03, 0.085, 0.012), dark)
			_box(r, Vector3(0.045, 0.285, 0.092), Vector3(0.03, 0.085, 0.012), dark)
			_box(r.smile, Vector3(0, 0.34, 0.092), Vector3(0.001, 0.001, 0.001), dark)
			_box(r.frown, Vector3(-0.05, 0.345, 0.092), Vector3(0.045, 0.012, 0.012), dark)
			_box(r.frown, Vector3(0.05, 0.345, 0.092), Vector3(0.045, 0.012, 0.012), dark)
		2:   # Boquita: ojos redondos y una o chica; triste = la o más abajo y más chica
			_box(r, Vector3(-0.04, 0.31, 0.092), Vector3(0.035, 0.045, 0.012), dark)
			_box(r, Vector3(0.04, 0.31, 0.092), Vector3(0.035, 0.045, 0.012), dark)
			_box(r.smile, Vector3(0, 0.24, 0.092), Vector3(0.04, 0.04, 0.012), dark)
			_box(r.smile, Vector3(0, 0.24, 0.0935), Vector3(0.018, 0.018, 0.012), glow)
			_box(r.frown, Vector3(0, 0.225, 0.092), Vector3(0.03, 0.025, 0.012), dark)
		3:   # Cíclope: un solo ojo grande con un brillo; triste = el párpado a medio cerrar
			_box(r, Vector3(0, 0.285, 0.092), Vector3(0.095, 0.075, 0.012), dark)
			_box(r, Vector3(0.015, 0.295, 0.0935), Vector3(0.025, 0.025, 0.012), glow)
			_box(r.smile, Vector3(0, 0.34, 0.092), Vector3(0.001, 0.001, 0.001), dark)
			_box(r.frown, Vector3(0, 0.315, 0.0945), Vector3(0.1, 0.03, 0.012), glow)
		_:   # el de siempre: ojos y sonrisa
			_box(r, Vector3(-0.04, 0.31, 0.092), Vector3(0.035, 0.055, 0.012), dark)
			_box(r, Vector3(0.04, 0.31, 0.092), Vector3(0.035, 0.055, 0.012), dark)
			_box(r.smile, Vector3(0, 0.235, 0.092), Vector3(0.09, 0.02, 0.012), dark)
			_box(r.smile, Vector3(-0.045, 0.25, 0.092), Vector3(0.02, 0.02, 0.012), dark)
			_box(r.smile, Vector3(0.045, 0.25, 0.092), Vector3(0.02, 0.02, 0.012), dark)
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
	if seated:
		_sentar(r)
	return r


## Farolín sentado: el cuerpo baja y las patitas quedan estiradas hacia adelante (lo usa la torre: espera sentado en el próximo checkpoint).
static func _sentar(r: Node3D) -> void:
	var iron2 := Color(0.3, 0.27, 0.32)
	for c in r.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).position.y < 0.1:
			c.queue_free()   # (las patitas de pie)
		elif c is Node3D:
			c.position.y -= 0.09   # (el farol, la cara y la luz)
	_box(r, Vector3(-0.06, 0.03, 0.12), Vector3(0.06, 0.06, 0.2), iron2)
	_box(r, Vector3(0.06, 0.03, 0.12), Vector3(0.06, 0.06, 0.2), iron2)
