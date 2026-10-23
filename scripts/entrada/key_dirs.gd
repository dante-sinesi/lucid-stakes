extends RefCounted
## Qué dirección de la grilla mueve cada tecla (W, D, S, A) según el giro de la cámara.
## Las cuatro teclas siguen el orden de las agujas del reloj en pantalla (W, D, S, A), y W es siempre la dirección que "más sube" en la pantalla:
## con la cámara en la diagonal isométrica por defecto W va arriba a la derecha, y a medida que se gira cambia de eje sólo cuando otro eje
## pasa a quedar más arriba. Así W nunca queda hacia un costado de la pantalla y A hacia arriba (lo que se sentía al revés).

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
## W es la dirección cuyo ángulo en pantalla (desde "arriba", hacia la derecha) cae en (-37, 53]: la isométrica por defecto (45°) queda adentro.
const W_FROM := -37.0
const W_TO := 53.0


## Ángulo en pantalla (grados, 0 = arriba, hacia la derecha) de una dirección de la grilla con la cámara girada `yaw_deg`.
static func screen_angle(d: Vector2i, yaw_deg: float) -> float:
	var yaw := deg_to_rad(yaw_deg)
	var right := Vector2(cos(yaw), -sin(yaw))
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var v := Vector2(d)
	return rad_to_deg(atan2(v.dot(right), v.dot(fwd)))


## Las direcciones de [W, D, S, A] con la cámara girada `yaw_deg`.
static func assign(yaw_deg: float) -> Array[Vector2i]:
	var w := DIRS[0]
	for d in DIRS:
		var a := fposmod(screen_angle(d, yaw_deg) - W_FROM, 360.0)   # grados desde W_FROM: W es la que cae en (0, 90]
		if a > 0.0 and a <= W_TO - W_FROM:
			w = d
	# Hacia la derecha en pantalla (sentido de las agujas): la siguiente dirección es la que queda 90° después de W.
	var order := DIRS.duplicate()
	order.sort_custom(func(p, q): return screen_angle(p, yaw_deg) < screen_angle(q, yaw_deg))
	var iw := order.find(w)
	var out: Array[Vector2i] = []
	for k in 4:
		out.append(order[(iw + k) % 4])
	return out


## La dirección de una tecla: (sx, sy) = (1, 1) W · (1, -1) D · (-1, -1) S · (-1, 1) A.
static func dir_for(yaw_deg: float, sx: float, sy: float) -> Vector2i:
	var idx := 0
	if sx > 0 and sy < 0:
		idx = 1
	elif sx < 0 and sy < 0:
		idx = 2
	elif sx < 0 and sy > 0:
		idx = 3
	return assign(yaw_deg)[idx]
