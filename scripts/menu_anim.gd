extends RefCounted
## Animaciones de entrada de los menús y ventanas: aparecer con un rebote, escalonar los botones y contar números hacia arriba.
## En las pruebas (sin pantalla) no se anima nada, así los textos y el estado quedan al instante.


static var force := false   # pruebas de las animaciones mismas


static func enabled() -> bool:
	return force or DisplayServer.get_name() != "headless"


static func _center(n: Control) -> void:
	n.pivot_offset = n.size.max(n.get_combined_minimum_size()) * 0.5


## Un control aparece de golpe: más grande y transparente, y se asienta en su tamaño.
static func pop_in(n: Control, from := 0.9, dur := 0.26) -> void:
	if n == null or not enabled():
		return
	_center(n)
	n.modulate.a = 0.0
	n.scale = Vector2.ONE * from
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "modulate:a", 1.0, dur * 0.7)
	tw.tween_property(n, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Varios controles aparecen uno tras otro (cada uno con su rebote).
static func stagger(nodes: Array, step := 0.05, dur := 0.26, first_delay := 0.0) -> void:
	if not enabled():
		return
	var i := 0
	for n in nodes:
		if n == null or not n.visible:
			continue
		_center(n)
		n.modulate.a = 0.0
		n.scale = Vector2.ONE * 0.8
		var d := first_delay + step * i
		var tw: Tween = n.create_tween().set_parallel(true)
		tw.tween_property(n, "modulate:a", 1.0, dur * 0.7).set_delay(d)
		tw.tween_property(n, "scale", Vector2.ONE, dur).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1


## Botones (visibles) dentro de un árbol de controles, en orden.
static func buttons_in(root: Node) -> Array:
	var out: Array = []
	if root is Button and root.visible:
		out.append(root)
	for ch in root.get_children():
		out.append_array(buttons_in(ch))
	return out


## Un contador (VoxelLabel o ClarityCounter) cuenta de 0 al valor final.
static func count_up(target: Control, to: int, dur := 0.8, delay := 0.0) -> void:
	if not enabled() or to <= 0:
		return
	_set_num(target, 0)
	var tw := target.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(func(v: float) -> void:
			if is_instance_valid(target):
				_set_num(target, int(round(v))), 0.0, float(to), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func _set_num(target: Control, n: int) -> void:
	if target.get("label") != null:   # ClarityCounter
		target.set("value", n)
	else:
		target.set("text", str(n))
