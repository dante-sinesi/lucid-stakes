extends RefCounted
## Poses del personaje: el cuerpo se mueve según lo que hace (empujar, tirar, trepar, colgarse...). Cada pose es una lista de cuadros clave sobre las partes que ya giran
## ("pata_i/d" y "brazo_i/d", ver Characters) y sobre el cuerpo entero (inclinación y salto). Todas las poses terminan en reposo, salvo las de colgarse, que quedan
## en "colgado" (los dos brazos agarrando el borde y las piernas meciéndose) hasta la próxima acción.
## Un brazo o pata cuelga hacia abajo: rotation.x = -PI/2 lo estira hacia adelante (+Z) y -PI hacia arriba; rotation.z abre hacia los costados.

const HANG_POSES := ["colgarse", "avanzar_colgado"]
const NAMES := ["paso", "empujar", "tirar", "trepar", "saltar", "caer", "resbalar", "colgarse", "colgado", "avanzar_colgado", "subir_del_borde", "soltarse", "victoria", "reposo"]

const ARM_UP := -2.9      # brazos casi estirados hacia arriba (colgado)

## Cuadros clave: [fin (0 a 1 de la duración), {parte: valor}]. Partes: ai, ad (brazos), li, ld (piernas) como Vector2(giro x, giro z); reach (cuánto se estiran los brazos: 1 = lo normal); lean (inclina el cuerpo hacia adelante o atrás); dip (sube o baja el cuerpo).
static func frames(pose: String) -> Array:
	match pose:
		"empujar":   # los dos brazos al frente, el cuerpo inclinado y las piernas abiertas
			return [[0.25, {"reach": 1.3, "ai": Vector2(-1.5, 0.08), "ad": Vector2(-1.5, -0.08), "li": Vector2(0.4, 0), "ld": Vector2(-0.5, 0), "lean": 0.3}],
					[0.7, {"reach": 1.3, "ai": Vector2(-1.55, 0.08), "ad": Vector2(-1.55, -0.08), "li": Vector2(0.45, 0), "ld": Vector2(-0.55, 0), "lean": 0.4}],
					[1.0, {}]]
		"tirar":   # agarra con los brazos al frente y se echa hacia atrás con las piernas firmes
			return [[0.25, {"reach": 1.3, "ai": Vector2(-1.4, 0.08), "ad": Vector2(-1.4, -0.08), "li": Vector2(-0.35, 0), "ld": Vector2(0.45, 0), "lean": 0.12}],
					[0.7, {"reach": 1.3, "ai": Vector2(-0.5, 0.05), "ad": Vector2(-0.5, -0.05), "li": Vector2(-0.4, 0), "ld": Vector2(0.5, 0), "lean": -0.32}],
					[1.0, {}]]
		"trepar":   # sube un escalón: levanta una pierna, estira los brazos y se impulsa
			return [[0.3, {"reach": 1.4, "ai": Vector2(-2.3, 0), "ad": Vector2(-2.3, 0), "li": Vector2(-1.25, 0), "ld": Vector2(0.2, 0), "lean": 0.18}],
					[0.65, {"reach": 1.4, "ai": Vector2(-0.8, 0), "ad": Vector2(-0.8, 0), "li": Vector2(-0.4, 0), "ld": Vector2(-0.2, 0), "lean": 0.05, "dip": 0.04}],
					[1.0, {}]]
		"saltar":   # la catapulta: brazos arriba y piernas recogidas
			return [[0.3, {"reach": 1.25, "ai": Vector2(-2.9, -0.4), "ad": Vector2(-2.9, 0.4), "li": Vector2(-0.8, 0), "ld": Vector2(-0.8, 0), "lean": 0.1}],
					[0.8, {"reach": 1.25, "ai": Vector2(-2.9, -0.5), "ad": Vector2(-2.9, 0.5), "li": Vector2(-0.8, 0), "ld": Vector2(-0.8, 0), "lean": 0.1}],
					[1.0, {}]]
		"caer":   # cayendo: brazos y piernas abiertos
			return [[0.25, {"reach": 1.15, "ai": Vector2(-2.6, -0.8), "ad": Vector2(-2.6, 0.8), "li": Vector2(0, -0.4), "ld": Vector2(0, 0.4)}],
					[0.6, {"reach": 1.15, "ai": Vector2(-2.4, -1.0), "ad": Vector2(-2.4, 1.0), "li": Vector2(0, -0.5), "ld": Vector2(0, 0.5)}],
					[1.0, {}]]
		"resbalar":   # sobre el hielo: piernas al frente, brazos abiertos para no perder el equilibrio
			return [[0.2, {"ai": Vector2(0, -1.1), "ad": Vector2(0, 1.1), "li": Vector2(-0.55, 0), "ld": Vector2(-0.25, 0), "lean": -0.2}],
					[0.85, {"ai": Vector2(0.1, -1.2), "ad": Vector2(0.1, 1.2), "li": Vector2(-0.55, 0), "ld": Vector2(-0.25, 0), "lean": -0.2}],
					[1.0, {}]]
		"colgarse":   # se agarra del borde: los dos brazos arriba y el cuerpo cuelga
			return [[1.0, {"reach": 1.8, "ai": Vector2(ARM_UP, -0.3), "ad": Vector2(ARM_UP, 0.3), "li": Vector2(0.3, 0), "ld": Vector2(-0.2, 0)}]]
		"colgado":   # (quieto) los brazos agarrados al borde
			return [[1.0, {"reach": 1.8, "ai": Vector2(ARM_UP, -0.3), "ad": Vector2(ARM_UP, 0.3), "li": Vector2(0.1, 0), "ld": Vector2(-0.1, 0)}]]
		"avanzar_colgado":   # va de costado por el borde: una mano después de la otra
			return [[0.5, {"reach": 1.8, "ai": Vector2(-3.1, -0.45), "ad": Vector2(-2.7, 0.25), "li": Vector2(0.35, 0), "ld": Vector2(-0.2, 0)}],
					[1.0, {"reach": 1.8, "ai": Vector2(-2.7, -0.25), "ad": Vector2(-3.1, 0.45), "li": Vector2(-0.2, 0), "ld": Vector2(0.35, 0)}]]
		"subir_del_borde":   # se impulsa con los brazos y sube una pierna para pasar al borde
			return [[0.3, {"reach": 1.5, "ai": Vector2(-2.3, -0.1), "ad": Vector2(-2.3, 0.1), "li": Vector2(-1.2, 0), "ld": Vector2(0.3, 0), "lean": 0.25}],
					[0.65, {"reach": 1.5, "ai": Vector2(-1.1, 0), "ad": Vector2(-1.1, 0), "li": Vector2(-0.5, 0), "ld": Vector2(0.1, 0), "lean": 0.35}],
					[1.0, {}]]
		"soltarse":   # suelta el borde y cae: brazos todavía arriba, piernas abiertas
			return [[0.3, {"reach": 1.3, "ai": Vector2(-2.6, -0.6), "ad": Vector2(-2.6, 0.6), "li": Vector2(0, -0.3), "ld": Vector2(0, 0.3)}],
					[1.0, {}]]
		"victoria":   # llegó al portal: salta con los brazos en alto
			return [[0.25, {"reach": 1.25, "ai": Vector2(-3.0, -0.35), "ad": Vector2(-3.0, 0.35), "li": Vector2(-0.3, 0), "ld": Vector2(-0.3, 0), "dip": 0.0}],
					[0.5, {"reach": 1.25, "ai": Vector2(-3.0, -0.4), "ad": Vector2(-3.0, 0.4), "li": Vector2(-0.5, 0), "ld": Vector2(-0.5, 0), "dip": 0.14}],
					[0.75, {"reach": 1.25, "ai": Vector2(-3.0, -0.35), "ad": Vector2(-3.0, 0.35), "li": Vector2(-0.3, 0), "ld": Vector2(-0.3, 0), "dip": 0.0}],
					[1.0, {"reach": 1.25, "ai": Vector2(-3.0, -0.35), "ad": Vector2(-3.0, 0.35)}]]
	return []


## Las partes del modelo por su nombre corto.
static func _part(model: Node3D, key: String) -> Node3D:
	var n := {"reach": 1.25, "ai": "brazo_i", "ad": "brazo_d", "li": "pata_i", "ld": "pata_d"}
	return model.get_node_or_null(str(n[key])) as Node3D


static func _kill(model: Node3D) -> void:
	var old = model.get_meta("pose_tween") if model.has_meta("pose_tween") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	model.set_meta("pose_tween", null)


## Todo en reposo (sin animar): brazos y piernas colgando, cuerpo derecho.
static func rest(model: Node3D) -> void:
	if model == null or not is_instance_valid(model):
		return
	if not model.has_meta("base_y"):
		model.set_meta("base_y", model.position.y)
	_kill(model)
	for k in ["ai", "ad", "li", "ld"]:
		var p := _part(model, k)
		if p != null:
			p.rotation.x = 0.0
			p.rotation.z = 0.0
			p.scale.y = 1.0
	model.rotation.x = 0.0
	model.position.y = float(model.get_meta("base_y", 0.0))


## Hace la pose durante `duration` segundos. Las poses de colgarse terminan en "colgado" (se queda así); las demás vuelven al reposo.
static func play(model: Node3D, pose: String, duration: float) -> void:
	if model == null or not is_instance_valid(model):
		return
	if not model.has_meta("base_y"):
		model.set_meta("base_y", model.position.y)
	var fr := frames(pose)
	_kill(model)
	if fr.is_empty():
		rest(model)
		return
	var tw := model.create_tween().set_parallel(true)
	model.set_meta("pose_tween", tw)
	var base_y := float(model.get_meta("base_y", 0.0))
	var prev_t := 0.0
	var last := {"reach": 1.25, "ai": Vector2.ZERO, "ad": Vector2.ZERO, "li": Vector2.ZERO, "ld": Vector2.ZERO, "lean": 0.0, "dip": 0.0}
	for k in ["ai", "ad", "li", "ld"]:   # (parte de donde está ahora: un movimiento seguido no salta al reposo)
		var p := _part(model, k)
		if p != null:
			last[k] = Vector2(p.rotation.x, p.rotation.z)
	var arm_i := _part(model, "ai")
	last["reach"] = arm_i.scale.y if arm_i != null else 1.0
	last["lean"] = model.rotation.x
	last["dip"] = model.position.y - base_y
	for f in fr:
		var t: float = float(f[0])
		var keys: Dictionary = f[1]
		var seg := maxf(t - prev_t, 0.001) * duration
		var delay := prev_t * duration
		for k in ["ai", "ad", "li", "ld"]:
			var target: Vector2 = keys.get(k, Vector2.ZERO)
			var part := _part(model, k)
			if part != null:
				tw.tween_property(part, "rotation:x", target.x, seg).set_delay(delay).set_trans(Tween.TRANS_SINE)
				tw.tween_property(part, "rotation:z", target.y, seg).set_delay(delay).set_trans(Tween.TRANS_SINE)
			last[k] = target
		for k in ["ai", "ad"]:
			var arm := _part(model, k)
			if arm != null:
				tw.tween_property(arm, "scale:y", float(keys.get("reach", 1.0)), seg).set_delay(delay).set_trans(Tween.TRANS_SINE)
		var lean_to := float(keys.get("lean", 0.0))
		tw.tween_property(model, "rotation:x", lean_to, seg).set_delay(delay).set_trans(Tween.TRANS_SINE)
		tw.tween_property(model, "position:y", base_y + float(keys.get("dip", 0.0)), seg).set_delay(delay).set_trans(Tween.TRANS_SINE)
		prev_t = t
	if pose in HANG_POSES:
		tw.chain().tween_callback(func(): hold(model))


## Colgado: los dos brazos agarrando el borde y las piernas meciéndose despacio hasta la próxima acción.
static func hold(model: Node3D) -> void:
	if model == null or not is_instance_valid(model):
		return
	_kill(model)
	var f: Dictionary = frames("colgado")[0][1]
	var tw := model.create_tween().set_loops()
	model.set_meta("pose_tween", tw)
	for k in ["ai", "ad"]:
		var p := _part(model, k)
		if p != null:
			p.rotation.x = f[k].x
			p.rotation.z = f[k].y
			p.scale.y = float(f.get("reach", 1.0))
	var li := _part(model, "li")
	var ld := _part(model, "ld")
	if li != null and ld != null:
		var sway := 0.22
		tw.set_parallel(true)
		tw.tween_property(li, "rotation:x", sway, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(ld, "rotation:x", -sway, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.chain().tween_property(li, "rotation:x", -sway, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(ld, "rotation:x", sway, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## La pose en el cuadro `idx` de un golpe (sin animar): para mirarla en capturas.
static func apply_now(model: Node3D, pose: String, idx: int) -> void:
	rest(model)
	var fr := frames(pose)
	if fr.is_empty():
		return
	var keys: Dictionary = fr[clampi(idx, 0, fr.size() - 1)][1]
	for k in ["ai", "ad", "li", "ld"]:
		var p := _part(model, k)
		if p != null:
			var v: Vector2 = keys.get(k, Vector2.ZERO)
			p.rotation.x = v.x
			p.rotation.z = v.y
			if k == "ai" or k == "ad":
				p.scale.y = float(keys.get("reach", 1.0))
	model.rotation.x = float(keys.get("lean", 0.0))
	model.position.y += float(keys.get("dip", 0.0))
