extends SceneTree
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_logic.gd

const TowerLogic := preload("res://scripts/tower_logic.gd")
const E := Vector3i(1, 0, 0)
const W := Vector3i(-1, 0, 0)
const S := Vector3i(0, 0, 1)
const N := Vector3i(0, 0, -1)
const MOVE := TowerLogic.Mode.MOVE
const GRAB := TowerLogic.Mode.GRAB
const HANG := TowerLogic.Mode.HANG
const ICE := TowerLogic.Kind.ICE
const BOMB := TowerLogic.Kind.BOMB
const CAT := TowerLogic.Kind.CATAPULT
const CRACKED := TowerLogic.Kind.CRACKED
const HEAVY := TowerLogic.Kind.HEAVY
const TRAP := TowerLogic.Kind.TRAP
const SPIKES := TowerLogic.Kind.SPIKES

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


## Capa base completa de 5x5 en y = 0, jugador en (2,1,2), sin caída automática.
func fresh() -> RefCounted:
	var t := TowerLogic.new()
	t.size = Vector2i(5, 5)
	t.goal_y = 99
	t.collapse_every = 1000
	t.moves_to_collapse = 1000
	for x in 5:
		for z in 5:
			t.add_block(Vector3i(x, 0, z))
	t.player = Vector3i(2, 1, 2)
	return t


## Una fila de bloques en y = 0 (x = 0..2, z = 1..2), jugador sobre (2,0,2).
func ledge() -> RefCounted:
	var t := fresh()
	t.blocks.clear()
	t.positions.clear()
	for x in 3:
		t.add_block(Vector3i(x, 0, 2))
		t.add_block(Vector3i(x, 0, 1))
	t.player = Vector3i(2, 1, 2)
	return t


func _init() -> void:
	test_walk_climb_push_pull()
	test_shift_walks()
	test_support()
	test_edge_support()
	test_standing()
	test_fixed()
	test_ice()
	test_bomb()
	test_catapult()
	test_cracked()
	test_heavy()
	test_rows()
	test_trap()
	test_spikes()
	test_purify()
	test_win_anywhere_on_top()
	test_goal_block()
	test_hang()
	test_pull_hang()
	test_push_out()
	test_collapse()
	test_generated_towers()
	print("tests terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_walk_climb_push_pull() -> void:
	var t := fresh()
	check(t.try_action(E).ok and t.player == Vector3i(3, 1, 2), "caminar")

	t = fresh()
	t.player = Vector3i(4, 1, 2)
	check(not t.try_action(E).ok, "no salir de la grilla")

	t = fresh()
	t.add_block(Vector3i(3, 1, 2))
	check(t.try_action(E).ok and t.player == Vector3i(3, 2, 2), "trepar 1 bloque")

	t = fresh()
	t.add_block(Vector3i(3, 1, 2))
	t.add_block(Vector3i(3, 2, 2))
	check(not t.try_action(E).ok, "no trepar con bloque encima del destino")

	t = fresh()
	t.add_block(Vector3i(3, 1, 2))
	check(t.try_action(E, GRAB).ok and t.blocks.has(Vector3i(4, 1, 2)), "empujar bloque")

	t = fresh()
	t.add_block(Vector3i(3, 1, 2))
	t.add_block(Vector3i(4, 1, 2))
	check(t.try_action(E, GRAB).ok and t.blocks.has(Vector3i(4, 1, 2)) and t.blocks.has(Vector3i(5, 1, 2)), "contra otro bloque se empuja la fila entera (ver test_rows)")

	t = fresh()
	t.add_block(Vector3i(1, 1, 2))
	check(t.try_action(E, GRAB).ok and t.player == Vector3i(3, 1, 2) and t.blocks.has(Vector3i(2, 1, 2)), "tirar bloque")

	t = fresh()
	t.add_block(Vector3i(2, 1, 2))
	t.player = Vector3i(2, 2, 2)  # sobre (2,1,2); hacia z=3 la superficie está un escalón más abajo
	check(t.try_action(S).ok and t.player == Vector3i(2, 1, 3), "bajar un escalon")


## Shift + dirección sin nada que empujar ni tirar es un paso común (mecánica de todo el juego); con un bloque trabado no camina.
func test_shift_walks() -> void:
	var t := fresh()
	check(t.try_action(E, GRAB).ok and t.player == Vector3i(3, 1, 2), "Shift + dirección sin bloques camina")
	t = fresh()
	var c := fresh()
	c.try_action(E)
	t.try_action(E, GRAB)
	check(t.player == c.player and t.blocks.size() == c.blocks.size() and t.claridad == c.claridad, "el paso con Shift es igual al paso común")
	t = fresh()
	t.add_block(Vector3i(3, 1, 2), true)   # un bloque fijo adelante: está trabado, no se camina ni se trepa
	check(not t.try_action(E, GRAB).ok and t.player == Vector3i(2, 1, 2), "con un bloque fijo adelante no camina")
	t = fresh()
	t.add_block(Vector3i(3, 1, 2), false, HEAVY)
	check(not t.try_action(E, GRAB).ok and t.player == Vector3i(2, 1, 2), "con un bloque pesado adelante no camina")
	t = fresh()
	t.add_block(Vector3i(1, 1, 2), true)   # un bloque fijo atrás: no se puede tirar de él, y tampoco se camina
	check(not t.try_action(E, GRAB).ok and t.player == Vector3i(2, 1, 2), "con un bloque fijo atrás no camina")
	t = fresh()
	t.player = Vector3i(4, 1, 2)
	check(not t.try_action(E, GRAB).ok, "Shift hacia el borde no sale de la grilla")
	t = fresh()
	t.add_block(Vector3i(3, 1, 2))
	check(t.try_action(E, GRAB).ok and t.player == Vector3i(2, 1, 2) and t.blocks.has(Vector3i(4, 1, 2)), "con un bloque adelante sigue empujando")


func test_support() -> void:
	var t := fresh()
	t.add_block(Vector3i(3, 5, 3))
	t._settle()
	check(t.blocks.has(Vector3i(3, 1, 3)), "bloque aislado cae hasta tocar otro")

	t = fresh()
	t.add_block(Vector3i(2, 5, 2))  # justo sobre el jugador: queda apoyado en él
	t._settle()
	check(t.blocks.has(Vector3i(2, 2, 2)) and not t.lost, "bloque que cae sobre el jugador se apoya en el")

	t = fresh()
	t.add_block(Vector3i(1, 5, 1))
	t.add_block(Vector3i(2, 5, 1))
	t._settle()
	check(not t.blocks.has(Vector3i(1, 5, 1)) and t.blocks.has(Vector3i(1, 1, 1)) and t.blocks.has(Vector3i(2, 1, 1)), "dos bloques que sólo se tocan entre sí (sin nada que los sostenga) caen juntos")
	t = fresh()
	t.add_block(Vector3i(1, 1, 1))   # un bloque en el piso: sostenido
	t.add_block(Vector3i(0, 2, 1))   # y otro pegado de costado en lo alto (colgante): se sostiene de él
	t._settle()
	check(t.blocks.has(Vector3i(0, 2, 1)), "un bloque colgante pegado a uno sostenido se sostiene")

	t = fresh()
	t.add_block(Vector3i(3, 1, 2))
	t.try_action(E, GRAB)  # (3,1,2) -> (4,1,2); sigue apoyado en la base
	check(t.blocks.has(Vector3i(4, 1, 2)), "bloque empujado sobre la base se mantiene")

	# Tirar de un bloque sin piso atrás deja colgado del borde (ver test_pull_hang).
	t = ledge()
	t.add_block(Vector3i(1, 1, 2))
	check(t.try_action(E, GRAB).ok and t.hang_dir == W, "tirar de un bloque sin piso atras deja colgado del bloque donde estabas")


## Un bloque que estaba apoyado sobre otro cae si le sacan el apoyo aunque tenga vecinos al costado; los que cuelgan desde el principio (plataformas) siguen sosteniéndose.
func test_standing() -> void:
	var t := TowerLogic.new()
	t.size = Vector2i(6, 6)
	t.collapse_every = 100000
	t.moves_to_collapse = 100000
	t.add_block(Vector3i(0, 0, 0))   # donde está parado el jugador
	t.add_block(Vector3i(1, 0, 0))
	t.add_block(Vector3i(1, 0, 4))   # un solo bloque de piso
	for y in [1, 2, 3]:   # una columna apoyada en él
		t.add_block(Vector3i(1, y, 4))
	for y in [2, 3]:   # y una vecina pegada que cuelga de la primera (no tiene nada debajo)
		t.add_block(Vector3i(2, y, 4))
	t.player = Vector3i(0, 1, 0)
	t.mark_standing()
	check(not t.standing.has(t.blocks[Vector3i(2, 2, 4)]) and t.standing.has(t.blocks[Vector3i(1, 2, 4)]), "los bloques con algo debajo cuentan como apoyados; los que cuelgan, no")
	check(t.try_action(E).ok and t.blocks.has(Vector3i(1, 3, 4)) and t.blocks.has(Vector3i(2, 3, 4)), "mientras nadie toca el apoyo, todo sigue en su lugar")
	# se saca el bloque de abajo de la columna: cae entera (y arrastra a la vecina que colgaba de ella), aunque se tocaran
	t._remove_block(Vector3i(1, 0, 4))
	t._settle()
	check(not t.blocks.has(Vector3i(1, 3, 4)) and not t.blocks.has(Vector3i(2, 3, 4)), "la columna a la que le sacan el bloque de abajo cae, aunque tenga una vecina al costado")
	# una plataforma pegada al núcleo cuelga sin nada debajo; un grupo sin núcleo ni piso no se sostiene
	var h := TowerLogic.new()
	h.size = Vector2i(6, 6)
	h.collapse_every = 100000
	h.moves_to_collapse = 100000
	for y in [0, 1, 2, 3]:
		h.add_block(Vector3i(3, y, 1), true)   # núcleo
	h.add_block(Vector3i(4, 3, 1))   # plataforma colgante pegada al núcleo
	h.add_block(Vector3i(5, 3, 1))
	h.add_block(Vector3i(0, 4, 4))   # grupo suelto (sólo se tocan entre ellos)
	h.add_block(Vector3i(1, 4, 4))
	h.player = Vector3i(2, 1, 1)
	h.mark_standing()
	h._settle()
	check(h.blocks.has(Vector3i(4, 3, 1)) and h.blocks.has(Vector3i(5, 3, 1)), "la plataforma colgante pegada al núcleo se sostiene")
	check(not h.blocks.has(Vector3i(0, 4, 4)) and not h.blocks.has(Vector3i(1, 4, 4)), "un grupo de bloques que sólo se sostienen entre sí cae")
	# lo que se empujó de costado cuelga de sus vecinos (como las plataformas)
	check(h.standing.is_empty() or not h.standing.has(h.blocks.get(Vector3i(4, 3, 1), -5)), "(las plataformas no cuentan como apoyadas)")
	# pegado al núcleo, un bloque apoyado se sigue sosteniendo aunque le saquen el piso
	var f := TowerLogic.new()
	f.size = Vector2i(4, 4)
	f.collapse_every = 100000
	f.moves_to_collapse = 100000
	for x in 3:
		f.add_block(Vector3i(x, 0, 0))
	for y in [0, 1, 2, 3]:
		f.add_block(Vector3i(3, y, 0), true)   # núcleo
	f.add_block(Vector3i(2, 1, 0))
	f.add_block(Vector3i(2, 2, 0))
	f.player = Vector3i(0, 1, 1)
	f.mark_standing()
	f._remove_block(Vector3i(2, 0, 0))
	f._settle()
	check(f.blocks.has(Vector3i(2, 1, 0)) and f.blocks.has(Vector3i(2, 2, 0)), "pegado al núcleo se sigue sosteniendo")


func test_edge_support() -> void:
	# Dos bloques apilados: si se empuja el de abajo de costado, el de arriba queda apoyado en su arista y no cae.
	var t := fresh()
	t.add_block(Vector3i(3, 1, 2))
	t.add_block(Vector3i(3, 2, 2))
	t.player = Vector3i(1, 1, 2)
	t.add_block(Vector3i(2, 1, 2))   # un bloque para empujar el de abajo desde el oeste... (ver abajo)
	t.blocks.erase(Vector3i(2, 1, 2))
	t.positions.erase(t.blocks.get(Vector3i(2, 1, 2), -1))
	var low: int = t.blocks[Vector3i(3, 1, 2)]
	var up: int = t.blocks[Vector3i(3, 2, 2)]
	t.player = Vector3i(2, 1, 2)
	var res: Dictionary = t.try_action(E, TowerLogic.Mode.GRAB)
	check(res.ok, "se empuja el bloque de abajo hacia el este")
	check(t.positions[low] == Vector3i(4, 1, 2), "el de abajo queda un lugar al costado")
	check(t.positions.has(up) and t.positions[up] == Vector3i(3, 2, 2), "el de arriba no cae: lo sostiene la arista del de abajo")
	# Sin arista (el de abajo se va dos lugares) el de arriba sí cae.
	var t2 := fresh()
	t2.add_block(Vector3i(3, 1, 2))
	t2.add_block(Vector3i(3, 2, 2))
	t2.add_block(Vector3i(0, 1, 0))
	var u2: int = t2.blocks[Vector3i(3, 2, 2)]
	t2._move_block(Vector3i(3, 1, 2), Vector3i(5, 1, 2))
	t2._settle()
	check(t2.positions[u2].y == 1, "sin apoyo (ni cara ni arista) el bloque cae")


func test_fixed() -> void:
	var t := fresh()
	t.add_block(Vector3i(3, 1, 2), true)
	check(not t.try_action(E, GRAB).ok and t.blocks.has(Vector3i(3, 1, 2)), "no se empuja un bloque fijo")

	t = fresh()
	t.add_block(Vector3i(1, 1, 2), true)
	check(not t.try_action(E, GRAB).ok and t.blocks.has(Vector3i(1, 1, 2)) and t.player == Vector3i(2, 1, 2), "no se tira de un bloque fijo")

	t = fresh()
	t.add_block(Vector3i(3, 1, 2), true)
	check(t.try_action(E).ok and t.player == Vector3i(3, 2, 2), "un bloque fijo se puede trepar")

	t = fresh()
	t.add_block(Vector3i(3, 6, 3), true)  # aislado y en el aire: un fijo no cae
	t._settle()
	check(t.blocks.has(Vector3i(3, 6, 3)), "un bloque fijo no cae aunque no toque nada")

	t = fresh()
	t.add_block(Vector3i(3, 1, 2), true)
	t.add_block(Vector3i(4, 1, 2))  # sostenido por el fijo
	t.blocks.erase(Vector3i(4, 0, 2))
	t._settle()
	check(t.blocks.has(Vector3i(4, 1, 2)), "el fijo sostiene a sus vecinos")

	t = fresh()
	t.add_block(Vector3i(3, 0, 2), true)
	t._collapse_bottom()
	check(not t.blocks.has(Vector3i(3, 0, 2)) and not t.fixed.has(Vector3i(3, 0, 2)), "la caida de la fila base se lleva tambien a los fijos")


## Cambia el tipo del bloque de la capa base en (x, 0, z).
func set_base_kind(t, x: int, z: int, kind: int) -> void:
	t.kind_of[t.blocks[Vector3i(x, 0, z)]] = kind


func test_ice() -> void:
	# Empujar un bloque de hielo: se desliza hasta chocar con el borde.
	var t := fresh()
	t.player = Vector3i(0, 1, 2)
	t.add_block(Vector3i(1, 1, 2), false, ICE)
	check(t.try_action(E, GRAB).ok and t.blocks.has(Vector3i(5, 1, 2)), "el hielo empujado se desliza hasta salir de la huella y queda apoyado en la arista de la base")

	# ... o hasta chocar con otro bloque, conservando su tipo.
	t = fresh()
	t.player = Vector3i(0, 1, 2)
	t.add_block(Vector3i(1, 1, 2), false, ICE)
	t.add_block(Vector3i(3, 1, 2))
	check(t.try_action(E, GRAB).ok and t.kind_at(Vector3i(2, 1, 2)) == ICE, "el hielo se frena contra un bloque y conserva su tipo")

	# Un bloque normal se mueve una sola celda.
	t = fresh()
	t.player = Vector3i(0, 1, 2)
	t.add_block(Vector3i(1, 1, 2))
	t.try_action(E, GRAB)
	check(t.blocks.has(Vector3i(2, 1, 2)) and not t.blocks.has(Vector3i(3, 1, 2)), "un bloque normal avanza una celda")

	# Hielo pegado a otro bloque: se empuja la fila, sin resbalar.
	t = fresh()
	t.player = Vector3i(0, 1, 2)
	t.add_block(Vector3i(1, 1, 2), false, ICE)
	t.add_block(Vector3i(2, 1, 2))
	check(t.try_action(E, GRAB).ok and t.blocks.has(Vector3i(2, 1, 2)) and t.blocks.has(Vector3i(3, 1, 2)) and not t.blocks.has(Vector3i(1, 1, 2)), "un hielo pegado a otro bloque se empuja en fila, sin resbalar")

	# El jugador resbala por el hielo hasta salir de el.
	t = fresh()
	t.player = Vector3i(0, 1, 2)
	for x in range(1, 4):
		set_base_kind(t, x, 2, ICE)
	check(t.try_action(E).ok and t.player == Vector3i(4, 1, 2), "el jugador resbala hasta salir del hielo")

	# ... o hasta chocar con un bloque.
	t = fresh()
	t.player = Vector3i(0, 1, 2)
	for x in range(1, 4):
		set_base_kind(t, x, 2, ICE)
	t.add_block(Vector3i(3, 1, 2))
	check(t.try_action(E).ok and t.player == Vector3i(2, 1, 2), "resbalar se frena contra un bloque")

	# Al resbalar fuera del borde se cae: no hay forma de agarrarse.
	t = fresh()
	t.player = Vector3i(0, 1, 2)
	for x in range(1, 5):
		set_base_kind(t, x, 2, ICE)
	t.blocks.erase(Vector3i(4, 0, 2))
	check(t.try_action(E).ok and t.lost, "resbalar fuera del borde es caer al vacio")

	# No se puede colgar del borde de un bloque de hielo.
	t = ledge()
	set_base_kind(t, 2, 2, ICE)
	check(not t.try_action(E, HANG).ok and t.hang_dir == Vector3i.ZERO, "no se cuelga de un borde de hielo")

	# Colgado, tampoco se avanza hacia un agarre de hielo.
	t = ledge()
	t.try_action(E, HANG)
	set_base_kind(t, 2, 1, ICE)
	check(not t.try_action(N).ok and t.player == Vector3i(3, 0, 2), "no se avanza por un borde de hielo")

	# Trepar a un hielo suelto: queda apoyado en hielo, resbala hacia adelante y, sin nada que lo frene, se cae del bloque.
	t = fresh()
	t.player = Vector3i(0, 1, 2)
	t.add_block(Vector3i(1, 1, 2), false, ICE)
	check(t.try_action(E).ok and t.player == Vector3i(2, 1, 2), "trepar a un hielo suelto: resbala fuera del bloque y baja")

	# ... pero si hay un bloque adelante, se frena arriba del hielo.
	t = fresh()
	t.player = Vector3i(0, 1, 2)
	t.add_block(Vector3i(1, 1, 2), false, ICE)
	t.add_block(Vector3i(2, 1, 2))
	t.add_block(Vector3i(2, 2, 2))
	check(t.try_action(E).ok and t.player == Vector3i(1, 2, 2), "resbalar arriba del hielo se frena contra un bloque")


func test_bomb() -> void:
	# La cuenta avanza cuando el jugador esta dentro de la zona de la bomba (esfera de distancia^2 <= 5) y explota al llegar a 0.
	var t := fresh()
	t.add_block(Vector3i(3, 1, 3), false, BOMB, 3)
	t.try_action(E)
	check(t.bomb_timer.values() == [2] and not t.lost, "primer movimiento: 3 -> 2")
	t.try_action(W)
	t.try_action(E)
	check(t.lost and t.lost_reason.contains("bomba"), "al llegar a 0 la bomba explota")
	check(t.blocks.is_empty(), "la explosion tira toda la torre")

	# Una bomba lejos (fuera de la zona) no cuenta.
	t = fresh()
	t.add_block(Vector3i(4, 1, 4))
	t.add_block(Vector3i(4, 2, 4), false, BOMB, 2)
	for i in 4:
		t.try_action(E if i % 2 == 0 else W)
	check(not t.lost and t.bomb_timer.values() == [2], "una bomba fuera de la zona no avanza")

	# Una bomba en otra capa pero cerca (dentro de la esfera) sí cuenta.
	t = fresh()
	t.add_block(Vector3i(3, 1, 3))
	t.add_block(Vector3i(3, 2, 3), false, BOMB, 4)
	t.try_action(E)
	check(t.bomb_timer.values() == [3], "una bomba de otra capa pero dentro de la zona cuenta")

	# Una bomba que cae al vacio queda desactivada.
	t = ledge()
	t.add_block(Vector3i(4, 0, 4), false, BOMB, 3)  # aislada en la fila mas baja: cae al vacio
	t._settle()
	check(t.bomb_timer.is_empty() and t.removed_ids.size() == 1, "una bomba caida al vacio se desactiva")

	# Empujar la bomba conserva su tipo y su cuenta.
	t = fresh()
	t.player = Vector3i(0, 1, 2)
	t.add_block(Vector3i(1, 1, 2), false, BOMB, 5)
	t.try_action(E, GRAB)
	check(t.kind_at(Vector3i(2, 1, 2)) == BOMB and t.bomb_timer.values() == [4], "la bomba empujada conserva tipo y cuenta")

	# Clonar copia las cuentas de forma independiente.
	var c = t.clone()
	c.try_action(E)
	check(t.bomb_timer.values() == [4] and c.bomb_timer.values() == [3], "el clon tiene su propia cuenta")


## Una catapulta junto a una pared: la pared llega hasta la capa `top` (su borde de arriba queda libre).
func wall_world(top: int = 6) -> RefCounted:
	var t := fresh()
	t.player = Vector3i(0, 1, 2)
	t.add_block(Vector3i(1, 1, 2), false, CAT)
	for y in range(1, top + 1):
		t.add_block(Vector3i(2, y, 2))
	return t


func test_catapult() -> void:
	# Sube 4 en vertical y se agarra del lateral de la pared (que tiene el borde libre a esa altura).
	var t := wall_world(6)
	check(t.try_action(E).ok and t.player == Vector3i(1, 6, 2) and t.hang_dir == E, "catapulta: sube 4 y queda colgado del lateral de la pared")
	var vertical := true
	for i in range(1, t.trail.size()):
		vertical = vertical and (t.trail[i].x == 1 and t.trail[i].z == 2 or i == 1)
	check(vertical and t.trail.size() >= 6, "catapulta: nunca se mueve hacia los costados, solo sube (%d celdas en el rastro)" % t.trail.size())
	check(t.purified.has(t.blocks[Vector3i(2, 6, 2)]), "el bloque del que queda colgado queda purificado")
	# Desde ahi se trepa a la cima de la pared: llego a una altura que sin la catapulta no se alcanza.
	check(t.try_action(E).ok and t.player == Vector3i(2, 7, 2) and t.hang_dir == Vector3i.ZERO, "catapulta: desde el lateral se trepa a la cima de la pared")

	# Si la pared sigue un poco por encima, la catapulta busca el borde hasta 2 celdas mas arriba del punto mas alto y se agarra de ese.
	t = wall_world(7)
	t.try_action(E)
	check(t.player == Vector3i(1, 7, 2) and t.hang_dir == E, "catapulta: la pared llega una celda mas arriba: se agarra del borde mas alto que alcanza")
	t = wall_world(8)
	t.try_action(E)
	check(t.player == Vector3i(1, 8, 2) and t.hang_dir == E, "catapulta: y hasta dos celdas mas arriba")
	# Si la pared sigue por encima de eso (no hay borde libre al alcance) no hay de donde agarrarse: vuelve a caer sobre la catapulta.
	t = wall_world(10)
	t.try_action(E)
	check(t.player == Vector3i(1, 2, 2) and t.hang_dir == Vector3i.ZERO, "catapulta: sin borde libre al alcance vuelve a caer sobre ella")
	var went_up := false
	for c in t.trail:
		went_up = went_up or c.y == 6
	check(went_up, "catapulta: aunque no se agarre, el rastro muestra que subio 4")

	# Un bloque de hielo no sirve para agarrarse.
	t = wall_world(6)
	t.kind_of[t.blocks[Vector3i(2, 6, 2)]] = ICE
	t.try_action(E)
	check(t.hang_dir == Vector3i.ZERO and t.player == Vector3i(1, 2, 2), "catapulta: no se agarra de un bloque de hielo")

	# Si no hay nada hacia donde miraba, se agarra de un costado.
	t = fresh()
	t.player = Vector3i(0, 1, 2)
	t.add_block(Vector3i(1, 1, 2), false, CAT)
	for y in range(1, 7):
		t.add_block(Vector3i(1, y, 3))  # pared al costado (+z) de la catapulta
	t.try_action(E)
	check(t.player == Vector3i(1, 6, 2) and t.hang_dir == S, "catapulta: sin nada de frente, se agarra del costado")

	# Tambien dispara hacia arriba cuando se la pisa en otra direccion.
	t = fresh()
	t.player = Vector3i(2, 1, 0)
	t.add_block(Vector3i(2, 1, 1), false, CAT)
	for y in range(1, 7):
		t.add_block(Vector3i(2, y, 2))
	t.try_action(S)
	check(t.player == Vector3i(2, 6, 1) and t.hang_dir == S, "catapulta: pisada hacia +z tambien sube y se agarra de frente")

	# Un techo justo encima impide el despegue.
	t = wall_world(6)
	t.add_block(Vector3i(1, 3, 2), true)
	t.try_action(E)
	check(t.player == Vector3i(1, 2, 2) and t.hang_dir == Vector3i.ZERO and t.trail.size() == 2, "catapulta: con un techo pegado no despega")

	# Un techo mas arriba corta el ascenso: sube hasta donde puede y se agarra si hay borde a esa altura.
	t = fresh()
	t.player = Vector3i(0, 1, 2)
	t.add_block(Vector3i(1, 1, 2), false, CAT)
	for y in range(1, 4):
		t.add_block(Vector3i(2, y, 2))  # pared de 3: borde libre a la altura 3
	t.add_block(Vector3i(1, 4, 2), true)  # techo: solo puede subir hasta la altura 3
	t.try_action(E)
	check(t.player == Vector3i(1, 3, 2) and t.hang_dir == E, "catapulta: un techo corta el ascenso y se agarra de lo que alcanza")

	# Sin la catapulta la pared no se puede trepar: es un bloque comun.
	t = wall_world(6)
	t.kind_of.erase(t.blocks[Vector3i(1, 1, 2)])
	t.try_action(E)
	check(t.player == Vector3i(1, 2, 2) and t.hang_dir == Vector3i.ZERO, "un bloque comun no impulsa")

	# El rastro se limpia en cada accion y registra partida y llegada.
	t = fresh()
	t.try_action(E)
	check(t.trail.size() == 2 and t.trail[0] == Vector3i(2, 1, 2) and t.trail[1] == Vector3i(3, 1, 2), "el rastro registra la celda de partida y la de llegada")
	t.try_action(E)
	check(t.trail.size() == 2 and t.trail[0] == Vector3i(3, 1, 2), "el rastro de la accion anterior se descarta")

	# Una catapulta es un bloque normal para empujar y conserva su tipo (el truco: acercarla a una pared alta).
	t = fresh()
	t.player = Vector3i(0, 1, 2)
	t.add_block(Vector3i(1, 1, 2), false, CAT)
	t.try_action(E, GRAB)
	check(t.kind_at(Vector3i(2, 1, 2)) == CAT, "una catapulta empujada conserva su tipo")


func test_cracked() -> void:
	# Un bloque agrietado se aguanta mientras estás encima y se rompe cuando te bajás.
	var t := fresh()
	t.add_block(Vector3i(3, 1, 2), false, CRACKED)
	check(t.try_action(E).ok and t.player == Vector3i(3, 2, 2), "se puede trepar a un agrietado")
	check(t.blocks.has(Vector3i(3, 1, 2)), "mientras estás encima, no se rompe")
	t.try_action(GRAB, GRAB) if false else null
	check(t.try_action(E).ok and t.player == Vector3i(4, 1, 2), "bajas de un salto al piso de al lado")
	check(not t.blocks.has(Vector3i(3, 1, 2)) and t.removed_ids.size() == 1, "al bajarte, el agrietado se rompe y cae")
	# empujar sin moverte no lo rompe
	t = fresh()
	t.add_block(Vector3i(2, 1, 3), false, CRACKED)
	t.player = Vector3i(2, 2, 3)
	t.add_block(Vector3i(3, 2, 3))
	check(t.try_action(E, GRAB).ok and t.blocks.has(Vector3i(2, 1, 3)) and t.player == Vector3i(2, 2, 3), "empujar un bloque sin moverte no rompe el agrietado de abajo")
	# el agrietado se puede empujar como un bloque normal
	t = fresh()
	t.add_block(Vector3i(3, 1, 2), false, CRACKED)
	check(t.try_action(E, GRAB).ok and t.blocks.has(Vector3i(4, 1, 2)) and t.kind_at(Vector3i(4, 1, 2)) == CRACKED, "un agrietado se empuja y sigue siendo agrietado")
	# lo que estaba apoyado sólo en él cae
	t = fresh()
	t.blocks.clear(); t.positions.clear()
	t.add_block(Vector3i(2, 0, 2))
	t.add_block(Vector3i(3, 0, 2), false, CRACKED)
	t.add_block(Vector3i(3, 1, 3))   # sólo lo sostiene (por arista) el agrietado
	t.player = Vector3i(3, 1, 2)
	t.floor_y = -5
	t.try_action(W)
	check(not t.blocks.has(Vector3i(3, 0, 2)) and not t.blocks.has(Vector3i(3, 1, 3)), "el agrietado de abajo se rompe cuando te vas y lo que sostenía cae")
	var cl = t.clone()
	check(cl.zob == t.zob, "la huella del estado queda consistente al romperse")
	var t2 = TowerLogic.from_dict(JSON.parse_string(JSON.stringify(t.to_dict())))
	check(t2.kind_of == t.kind_of, "los tipos nuevos se guardan y se cargan")


func test_heavy() -> void:
	var t := fresh()
	t.add_block(Vector3i(3, 1, 2), false, HEAVY)
	var r: Dictionary = t.try_action(E, GRAB)
	check(not r.ok and r.msg.contains("pesado"), "un bloque pesado no se empuja")
	check(t.try_action(E).ok and t.player == Vector3i(3, 2, 2), "pero se puede trepar")
	t = fresh()
	t.add_block(Vector3i(1, 1, 2), false, HEAVY)
	r = t.try_action(W, GRAB)
	check(not r.ok, "un pesado detrás tampoco se tira (hay que mirar hacia afuera)")
	t = fresh()
	t.add_block(Vector3i(1, 1, 2), false, HEAVY)
	r = t.try_action(E, GRAB)
	check(not r.ok and r.msg.contains("pesado"), "tirar de un pesado tampoco funciona")


## Empujar una fila: se mueve toda la fila (hasta 3) si la celda de más allá está libre.
func test_rows() -> void:
	var t := fresh()
	t.add_block(Vector3i(3, 1, 2))
	t.add_block(Vector3i(4, 1, 2))
	var r: Dictionary = t.try_action(E, GRAB)
	check(r.ok and t.blocks.has(Vector3i(4, 1, 2)) and t.blocks.has(Vector3i(5, 1, 2)) and not t.blocks.has(Vector3i(3, 1, 2)), "empujar con otro pegado detras mueve la fila de dos")
	check(t.player == Vector3i(2, 1, 2), "el jugador no se mueve al empujar")
	# tres bloques entran; cuatro no
	t = fresh()
	for x in [3, 4, 5]:
		t.add_block(Vector3i(x, 1, 2))
	check(t.try_action(E, GRAB).ok and t.blocks.has(Vector3i(6, 1, 2)), "una fila de tres se empuja")
	t = fresh()
	for x in [3, 4, 5, 6]:
		t.add_block(Vector3i(x, 1, 2))
	check(not t.try_action(E, GRAB).ok and t.blocks.has(Vector3i(3, 1, 2)), "una fila de cuatro es demasiado: no se mueve nada")
	# un fijo o uno pesado en la fila la frena
	t = fresh()
	t.add_block(Vector3i(3, 1, 2))
	t.add_block(Vector3i(4, 1, 2), false, HEAVY)
	check(not t.try_action(E, GRAB).ok and t.blocks.has(Vector3i(3, 1, 2)), "un bloque pesado en la fila impide empujarla")
	t = fresh()
	t.add_block(Vector3i(3, 1, 2))
	t.add_block(Vector3i(4, 1, 2), true)
	check(not t.try_action(E, GRAB).ok, "un bloque fijo en la fila impide empujarla")
	# el hielo no resbala dentro de una fila, pero sí solo
	t = fresh()
	t.add_block(Vector3i(3, 1, 2), false, ICE)
	t.add_block(Vector3i(4, 1, 2))
	t.try_action(E, GRAB)
	check(t.blocks.has(Vector3i(4, 1, 2)) and t.blocks.has(Vector3i(5, 1, 2)), "el hielo dentro de una fila se mueve una sola celda")
	# lo que queda sin apoyo cae: la fila empujada sobre el vacío
	t = fresh()
	t.blocks.clear()
	t.positions.clear()
	for x in 3:
		t.add_block(Vector3i(x, 0, 2))
	t.add_block(Vector3i(1, 1, 2))
	t.add_block(Vector3i(2, 1, 2))
	t.player = Vector3i(0, 1, 2)
	t.try_action(E, GRAB)
	check(t.blocks.has(Vector3i(2, 1, 2)) and t.blocks.has(Vector3i(3, 1, 2)), "la fila empujada hacia afuera del piso queda sostenida por su vecino")


## Trampa: al quedar parado sobre ella se desarma y se cae con ella.
func test_trap() -> void:
	var t := fresh()
	t.add_block(Vector3i(3, 1, 2), false, TRAP)
	t.try_action(E)   # trepar a la trampa
	check(not t.blocks.has(Vector3i(3, 1, 2)) and t.player == Vector3i(3, 1, 2) and not t.lost, "sobre un piso: la trampa se desarma y se aterriza en la capa de abajo")
	check(t.removed_ids.size() == 1, "la vista se entera de que el bloque cayo")
	# sobre el vacio: se pierde
	t = TowerLogic.new()
	t.size = Vector2i(5, 5)
	t.goal_y = 99
	t.collapse_every = 1000
	t.moves_to_collapse = 1000
	for x in 2:
		t.add_block(Vector3i(x, 0, 2))
	t.add_block(Vector3i(2, 0, 2), false, TRAP)
	t.player = Vector3i(1, 1, 2)
	t.try_action(E)
	check(t.lost and t.lost_reason == "Caíste al vacío", "una trampa sobre el vacio: pisarla cae al vacio")
	# empujar o tirar de una trampa no la activa
	t = fresh()
	t.add_block(Vector3i(3, 1, 2), false, TRAP)
	check(t.try_action(E, GRAB).ok and t.blocks.has(Vector3i(4, 1, 2)) and t.kind_at(Vector3i(4, 1, 2)) == TRAP, "empujar una trampa la mueve entera")
	# colgarse de una trampa no la activa
	t = ledge()
	t.blocks.clear()
	t.positions.clear()
	t.add_block(Vector3i(2, 0, 2), false, TRAP)
	t.add_block(Vector3i(1, 0, 2))
	t.add_block(Vector3i(3, 0, 2))
	t.player = Vector3i(2, 1, 2)
	t.try_action(N, HANG)
	check(t.hang_dir != Vector3i.ZERO and t.blocks.has(Vector3i(2, 0, 2)), "colgarse del borde de una trampa no la desarma")


## Pinchos: quedar parado sobre ellos pierde; se pueden empujar como un bloque común.
func test_spikes() -> void:
	var t := fresh()
	t.add_block(Vector3i(3, 1, 2), false, SPIKES)
	t.try_action(E)   # trepar sobre los pinchos
	check(t.lost and t.lost_reason == "Caíste sobre los pinchos", "trepar a unos pinchos pierde")
	t = fresh()
	t.add_block(Vector3i(3, 1, 2), false, SPIKES)
	check(t.try_action(E, GRAB).ok and t.blocks.has(Vector3i(4, 1, 2)) and not t.lost, "los pinchos se pueden empujar")
	# caminar hasta unos pinchos al nivel del piso (bajando un escalon) tambien pierde
	t = TowerLogic.new()
	t.size = Vector2i(5, 5)
	t.goal_y = 99
	t.collapse_every = 1000
	t.moves_to_collapse = 1000
	for x in 3:
		t.add_block(Vector3i(x, 1, 2))
	t.add_block(Vector3i(3, 0, 2), false, SPIKES)
	t.add_block(Vector3i(2, 0, 2))
	t.player = Vector3i(2, 2, 2)
	t.try_action(E)
	check(t.lost and t.lost_reason == "Caíste sobre los pinchos", "bajar un escalon sobre unos pinchos pierde")
	# la trampa que deja caer sobre pinchos
	t = TowerLogic.new()
	t.size = Vector2i(5, 5)
	t.goal_y = 99
	t.collapse_every = 1000
	t.moves_to_collapse = 1000
	t.add_block(Vector3i(1, 0, 2))
	t.add_block(Vector3i(2, 0, 2), false, SPIKES)
	t.add_block(Vector3i(2, 1, 2), false, TRAP)
	t.add_block(Vector3i(1, 1, 2))
	t.player = Vector3i(1, 2, 2)
	t.try_action(E)
	check(t.lost and t.lost_reason == "Caíste sobre los pinchos", "una trampa que deja caer sobre pinchos pierde")


func test_purify() -> void:
	# Pasar por encima purifica: se purifican la celda de partida y la de llegada.
	var t := fresh()
	t.try_action(E)  # (2,1,2) -> (3,1,2): pisa (2,0,2) y (3,0,2)
	check(t.purified_count == 2 and t.claridad == 2 and t.streak == 1 and t.last_gain == 2, "primera accion: 2 bloques normales = 2 de claridad")

	# La racha sube el multiplicador mientras cada accion purifique algo nuevo.
	t.try_action(E)  # (3,1,2) -> (4,1,2): solo (4,0,2) es nuevo
	check(t.streak == 2 and t.last_gain == 2 and t.claridad == 4, "racha 2: 1 bloque nuevo x1,5 (redondeado) = 2")
	check(is_equal_approx(TowerLogic.streak_multiplier(1), 1.0) and is_equal_approx(TowerLogic.streak_multiplier(3), 2.0), "multiplicador: x1 con racha 1, x2 con racha 3")
	check(is_equal_approx(TowerLogic.streak_multiplier(50), 4.0), "el multiplicador tiene tope x4")

	# Volver por lo ya purificado corta la racha.
	t.try_action(W)
	check(t.streak == 0 and t.last_gain == 0 and t.claridad == 4 and t.best_streak == 2, "pisar solo lo ya purificado corta la racha (y se recuerda la mejor)")

	# El hielo vale mas y se purifican todos los bloques por los que se resbala.
	t = fresh()
	t.player = Vector3i(0, 1, 2)
	for x in range(1, 4):
		set_base_kind(t, x, 2, ICE)
	t.try_action(E)  # resbala 0 -> 4: pisa 5 bloques (normal, 3 de hielo, normal)
	check(t.purified_count == 5 and t.claridad == 1 + 2 + 2 + 2 + 1, "resbalar por hielo purifica todo el tramo: 1+2+2+2+1 = 8")

	# Cada tipo da lo suyo.
	t = fresh()
	t.player = Vector3i(0, 1, 2)
	t.add_block(Vector3i(1, 1, 2), false, CAT)
	t.try_action(E)  # trepa al catapulta (pisa el catapulta) y sale lanzado
	check(t.purified.has(t.blocks[Vector3i(1, 1, 2)]), "pisar un catapulta lo purifica antes de salir lanzado")
	check(t.clarity_at(Vector3i(1, 1, 2)) == 3 and t.clarity_at(Vector3i(2, 0, 2)) == 1, "catapulta = 3, bloque normal = 1")
	t = fresh()
	t.add_block(Vector3i(3, 1, 2), false, BOMB, 5)
	check(t.clarity_at(Vector3i(3, 1, 2)) == 5, "bomba = 5")
	t.add_block(Vector3i(0, 5, 0), true)
	check(t.clarity_at(Vector3i(0, 5, 0)) == 1, "bloque fijo (core) = 1")

	# Purificar una bomba la desactiva: queda en su sitio, pero ya no cuenta ni explota.
	t = fresh()
	t.add_block(Vector3i(3, 1, 2), false, BOMB, 2)
	t.add_block(Vector3i(0, 1, 0))
	t.try_action(E)  # trepa sobre la bomba: la purifica
	check(t.bomb_timer.is_empty() and t.kind_at(Vector3i(3, 1, 2)) == BOMB and t.claridad >= 5, "pararse sobre una bomba la desactiva y da 5")
	for i in 6:
		t.try_action(W if i % 2 == 0 else E)
	check(not t.lost, "una bomba purificada no explota aunque pasen movimientos")

	# La bomba que no se purifica sigue contando.
	t = fresh()
	t.add_block(Vector3i(4, 1, 4), false, BOMB, 3)
	t.try_action(E)
	check(t.bomb_timer.values() == [2], "una bomba sin purificar sigue contando")

	# La purificacion acompana al bloque: empujarlo no lo vuelve a corromper.
	t = fresh()
	t.player = Vector3i(0, 1, 2)
	t.add_block(Vector3i(1, 1, 2))
	var id: int = t.blocks[Vector3i(1, 1, 2)]
	t.purified[id] = true
	check(t.try_action(E, GRAB).ok and t.positions[id] == Vector3i(2, 1, 2) and t.purified.has(id), "el bloque empujado sigue purificado")

	# Un bloque que cae al vacio se olvida.
	t = ledge()
	t.add_block(Vector3i(4, 0, 4))  # aislado en la fila mas baja: cae al vacio
	var gone: int = t.blocks[Vector3i(4, 0, 4)]
	t.purified[gone] = true
	t._settle()
	check(t.removed_ids.has(gone) and not t.purified.has(gone), "un bloque caido al vacio deja de figurar como purificado")

	# Colgarse purifica el bloque del que se cuelga.
	t = ledge()
	t.try_action(E, HANG)
	check(t.purified.has(t.blocks[Vector3i(2, 0, 2)]), "colgado, el bloque del que se agarra queda purificado")

	# El clon lleva su propia cuenta.
	t = fresh()
	var c = t.clone()
	c.try_action(E)
	check(t.claridad == 0 and c.claridad == 2 and t.purified.is_empty(), "el clon tiene su propia claridad y purificados")

	# El solucionador no cuenta claridad (no cambia el juego) pero si desactiva bombas.
	t = fresh()
	t.track_purify = false
	t.add_block(Vector3i(3, 1, 2), false, BOMB, 2)
	t.try_action(E)
	check(t.claridad == 0 and t.purified.is_empty() and t.bomb_timer.is_empty(), "sin seguimiento: no hay claridad pero la bomba se desactiva igual")

	# Perder o fallar una accion no cambia claridad ni racha.
	t = fresh()
	t.try_action(E)
	var gain_before: int = t.claridad
	var streak_before: int = t.streak
	t.player = Vector3i(4, 1, 2)
	t.try_action(E)  # borde: accion fallida
	check(t.claridad == gain_before and t.streak == streak_before, "una accion fallida no toca claridad ni racha")


func test_win_anywhere_on_top() -> void:
	# La meta es llegar al nivel de arriba: vale cualquier bloque de la capa superior, no solo el de goal_cell.
	var t := fresh()
	t.goal_y = 3
	t.goal_cell = Vector3i(0, 3, 0)  # lejos
	t.add_block(Vector3i(3, 1, 2))
	t.add_block(Vector3i(4, 1, 2))
	t.add_block(Vector3i(4, 2, 2))
	check(t.try_action(E).ok and t.player == Vector3i(3, 2, 2) and not t.won, "preparacion: sobre el primer escalon todavia no se gana")
	check(t.try_action(E).ok and t.player == Vector3i(4, 3, 2) and t.won, "pararse en cualquier bloque de la capa superior gana, aunque no sea goal_cell")


func test_goal_block() -> void:
	# Con bloque-portal, llegar a la altura de la meta sobre otro bloque NO gana: hay que pisar el portal.
	var t := fresh()
	t.goal_y = 3
	t.add_block(Vector3i(3, 1, 2))
	t.add_block(Vector3i(4, 1, 2))
	t.add_block(Vector3i(4, 2, 2))
	t.add_block(Vector3i(3, 2, 2))
	t.add_block(Vector3i(2, 1, 3))
	t.add_block(Vector3i(2, 2, 3))
	t.add_block(Vector3i(2, 1, 2))
	t.add_block(Vector3i(2, 2, 2))
	t.goal_block = t.blocks[Vector3i(2, 2, 3)]
	t.player = Vector3i(3, 3, 2)
	t.try_action(Vector3i(1, 0, 0))
	check(t.player == Vector3i(4, 3, 2) and not t.won, "a la altura de la meta pero sobre otro bloque: no gana")
	t.player = Vector3i(2, 3, 2)
	t.try_action(Vector3i(0, 0, 1))
	check(t.player == Vector3i(2, 3, 3) and t.won, "parado sobre el bloque-portal: gana")


func test_hang() -> void:
	var t := ledge()
	check(not t.try_action(E, MOVE).ok, "borde con caida: no se camina al vacio")
	check(t.try_action(E, HANG).ok and t.player == Vector3i(3, 0, 2) and t.hang_dir == W, "colgarse del borde")
	check(t.try_action(N).ok and t.player == Vector3i(3, 0, 1), "desplazarse por el borde")
	check(t.try_action(W).ok and t.player == Vector3i(2, 1, 1) and t.hang_dir == Vector3i.ZERO, "trepar desde colgado")

	t = ledge()
	t.try_action(E, HANG)
	t.try_action(E)  # soltarse: no hay nada abajo
	check(t.lost, "soltarse sin nada abajo es caer al vacio")

	# Esquina hacia afuera: el borde del bloque termina, se lo rodea y queda agarrado de su otro lado.
	t = ledge()
	t.try_action(E, HANG)  # colgado en (3,0,2) del bloque (2,0,2)
	check(t.try_action(S).ok and t.player == Vector3i(2, 0, 3) and t.hang_dir == N, "doblar una esquina hacia afuera: queda agarrado de la otra cara del mismo bloque")
	check(t.try_action(W).ok and t.player == Vector3i(1, 0, 3), "...y se puede seguir por esa cara")
	check(t.try_action(N).ok and t.player == Vector3i(1, 1, 2) and t.hang_dir == Vector3i.ZERO, "...y trepar desde ahi")

	# Se puede volver por la misma esquina.
	t = ledge()
	t.try_action(E, HANG)
	t.try_action(S)
	check(t.try_action(E).ok and t.player == Vector3i(3, 0, 2) and t.hang_dir == W, "ida y vuelta por la esquina hacia afuera: vuelve exactamente al punto de partida")

	# Esquina hacia adentro: la pared gira hacia el jugador, y se agarra de ella sin moverse.
	t = fresh()
	t.blocks.clear()
	t.positions.clear()
	for x in range(0, 3):
		t.add_block(Vector3i(x, 0, 2))
	t.add_block(Vector3i(2, 0, 3))  # la pared gira: bloque al costado del jugador colgado
	t.player = Vector3i(1, 1, 2)
	t.try_action(S, HANG)  # colgado en (1,0,3) del bloque (1,0,2)
	check(t.hang_dir == N and t.player == Vector3i(1, 0, 3), "preparacion: colgado de la cara +z de la pared")
	check(t.try_action(E).ok and t.player == Vector3i(1, 0, 3) and t.hang_dir == E, "doblar una esquina hacia adentro: se agarra de la pared que gira sin moverse")
	check(t.try_action(E, MOVE).ok and t.player == Vector3i(2, 1, 3), "...y desde ahi se trepa a ese bloque")

	# La esquina hacia adentro no se dobla si no hay borde libre arriba, o si es de hielo.
	var wall = t.clone()
	t = fresh()
	t.blocks.clear()
	t.positions.clear()
	for x in range(0, 3):
		t.add_block(Vector3i(x, 0, 2))
	t.add_block(Vector3i(2, 0, 3))
	t.add_block(Vector3i(2, 1, 3))  # bloque arriba: no hay borde
	t.player = Vector3i(1, 1, 2)
	t.try_action(S, HANG)
	check(not t.try_action(E).ok and t.hang_dir == N, "esquina hacia adentro con un bloque encima: no hay borde, no se dobla")
	t = fresh()
	t.blocks.clear()
	t.positions.clear()
	for x in range(0, 3):
		t.add_block(Vector3i(x, 0, 2))
	t.add_block(Vector3i(2, 0, 3), false, ICE)
	t.player = Vector3i(1, 1, 2)
	t.try_action(S, HANG)
	check(not t.try_action(E).ok and t.hang_dir == N, "esquina hacia adentro de hielo: no hay de donde agarrarse")

	# La esquina hacia afuera necesita el borde libre del bloque del que se cuelga.
	t = ledge()
	t.try_action(E, HANG)
	t.add_block(Vector3i(2, 1, 2))  # ahora el bloque (2,0,2) tiene otro encima
	check(not t.try_action(S).ok and t.player == Vector3i(3, 0, 2), "esquina hacia afuera con un bloque encima del agarre: no se dobla")

	# No se dobla hacia fuera de la huella.
	t = fresh()
	t.blocks.clear()
	t.positions.clear()
	for z in 5:
		t.add_block(Vector3i(4, 0, z))
	t.player = Vector3i(4, 1, 4)
	t.try_action(S, HANG)  # (4,1,5) esta una celda fuera: el borde de la torre tambien sirve para colgarse
	check(t.hang_dir == Vector3i(0, 0, -1) and t.player == Vector3i(4, 0, 5), "se puede colgar de un bloque del borde de la huella")



func test_push_out() -> void:
	# Un bloque empujado puede salir de la huella (el limite de 3 alrededor del core es solo de generacion).
	var t := fresh()
	t.player = Vector3i(3, 1, 2)
	t.add_block(Vector3i(4, 1, 2))
	var id: int = t.blocks[Vector3i(4, 1, 2)]
	check(t.try_action(E, GRAB).ok, "se puede empujar un bloque hacia fuera de la huella")
	check(t.player == Vector3i(3, 1, 2), "el jugador no se mueve al empujar")
	check(t.positions[id] == Vector3i(5, 1, 2) and not t.in_footprint(t.positions[id]), "el bloque sale de la huella y queda sostenido por la arista de la base")

	# Hacia el otro lado (coordenadas negativas).
	t = fresh()
	t.player = Vector3i(1, 1, 2)
	t.add_block(Vector3i(0, 1, 2))
	id = t.blocks[Vector3i(0, 1, 2)]
	check(t.try_action(W, GRAB).ok and t.positions[id] == Vector3i(-1, 1, 2) and t.player == Vector3i(1, 1, 2), "tambien se puede sacar por el lado de las coordenadas negativas")

	# Si afuera hay una fila demasiado larga, no hay lugar.
	t = fresh()
	t.player = Vector3i(3, 1, 2)
	for x in [4, 5, 6, 7]:
		t.add_block(Vector3i(x, 1, 2))  # sostenidos por el vecino
	check(not t.try_action(E, GRAB).ok, "no se empuja una fila demasiado larga que sale de la huella")

	# Sin nada que lo sostenga, el bloque que sale cae al vacio (queda sin vecinos a la altura de la fila mas baja).
	t = fresh()
	t.blocks.clear()
	t.positions.clear()
	t.floor_y = 1
	for x in range(0, 5):
		t.add_block(Vector3i(x, 1, 2))  # fila mas baja que queda
	t.add_block(Vector3i(4, 2, 2))
	t.player = Vector3i(3, 2, 2)
	id = t.blocks[Vector3i(4, 2, 2)]
	t.try_action(E, GRAB)  # sale a (5,2,2) y la arista de la fila (4,1,2) lo sostiene: queda ahi
	check(t.positions.get(id, Vector3i.ZERO) == Vector3i(5, 2, 2), "un bloque que sale y toca el costado de la estructura queda pegado")
	# Una vez afuera y sin vecinos a esa altura, cae al vacio si la fila de abajo se va.
	t._collapse_bottom()
	t._settle()
	check(not t.positions.has(id) and t.removed_ids.has(id), "si la fila a la que estaba pegado cae, el bloque cae al vacio con ella")

	# El hielo empujado hacia afuera se detiene en la primera celda fuera de la huella (no vuela lejos).
	t = fresh()
	t.player = Vector3i(0, 1, 2)
	t.add_block(Vector3i(1, 1, 2), false, ICE)
	var ice_id: int = t.blocks[Vector3i(1, 1, 2)]
	t.try_action(E, GRAB)
	check(t.positions[ice_id].x == 5, "el hielo sale de la huella y se detiene en la primera celda de afuera (x = %d)" % t.positions[ice_id].x)


func test_pull_hang() -> void:
	# Tirar sin piso atrás (como en Catherine): el bloque tirado viene a donde estabas y quedás colgado del bloque en el que estabas parado, sin poder trepar de vuelta
	# (el bloque tirado quedó encima del borde); hay que moverse de costado.
	var t := ledge()
	t.add_block(Vector3i(1, 1, 2))
	check(t.try_action(E, GRAB).ok, "tirar sin piso atras se puede")
	check(t.blocks.has(Vector3i(2, 1, 2)) and not t.blocks.has(Vector3i(1, 1, 2)), "el bloque tirado viene a donde estabas")
	check(t.player == Vector3i(3, 0, 2) and t.hang_dir == W, "y quedas colgado del bloque en el que estabas parado, un piso más abajo")
	check(not t.try_action(W).ok and t.player == Vector3i(3, 0, 2), "no se puede trepar de vuelta: el bloque tirado quedó encima")
	t = fresh()
	t.player = Vector3i(4, 1, 2)
	t.add_block(Vector3i(3, 1, 2))
	check(t.try_action(E, GRAB).ok and t.player == Vector3i(5, 0, 2) and t.hang_dir == W, "tirar hacia fuera de la huella también deja colgado (el mundo sigue más allá de la huella)")
	t = fresh()   # un bloque de hielo no sirve de agarre
	t.player = Vector3i(4, 1, 2)
	t.add_block(Vector3i(3, 1, 2))
	set_base_kind(t, 4, 2, ICE)
	check(not t.try_action(E, GRAB).ok and t.hang_dir == Vector3i.ZERO, "sobre hielo no hay de dónde agarrarse al tirar")

	# Un bloque fijo no se puede tirar, haya piso o no.
	t = ledge()
	t.add_block(Vector3i(1, 1, 2), true)
	check(not t.try_action(E, GRAB).ok and t.player == Vector3i(2, 1, 2), "un bloque fijo no se tira")

	# Atrás hay un escalón más bajo: se baja en vez de colgarse.
	t = fresh()
	t.blocks.clear()
	t.positions.clear()
	for x in range(0, 3):
		for y in range(0, 2):
			t.add_block(Vector3i(x, y, 2))  # plataforma alta (superficie en nivel 2)
	t.add_block(Vector3i(3, 0, 2))             # plataforma baja (superficie en nivel 1)
	t.add_block(Vector3i(1, 2, 2))             # el bloque que se va a tirar
	t.player = Vector3i(2, 2, 2)
	var id: int = t.blocks[Vector3i(1, 2, 2)]
	check(t.try_action(E, GRAB).ok and t.player == Vector3i(3, 1, 2) and t.hang_dir == Vector3i.ZERO, "tirando hacia un escalon mas bajo se baja y queda parado")
	check(t.blocks.get(Vector3i(2, 2, 2), -1) == id, "...y el bloque viene a donde estabas")

	# Con piso atrás, tirar sigue siendo el movimiento de siempre (no cuelga).
	t = fresh()
	t.add_block(Vector3i(1, 1, 2))
	check(t.try_action(E, GRAB).ok and t.player == Vector3i(3, 1, 2) and t.hang_dir == Vector3i.ZERO and t.blocks.has(Vector3i(2, 1, 2)), "con piso atras tirar es el movimiento normal")


func test_collapse() -> void:
	var t := fresh()
	t.collapse_every = 2
	t.moves_to_collapse = 2
	t.try_action(E)
	check(t.floor_y == 0 and not t.lost, "antes de N movimientos no cae nada")
	t.try_action(W)
	check(t.floor_y == 1 and t.lost, "cae la fila de abajo: pierde quien estaba sobre ella")

	t = fresh()
	t.add_block(Vector3i(3, 1, 2))
	t.add_block(Vector3i(3, 2, 2))
	t.player = Vector3i(3, 3, 2)
	t._collapse_bottom()
	t._settle()
	check(not t.lost and t.floor_y == 1, "la columna alta sobrevive a la caida")
	check(t.blocks.size() == 2 and t.removed_ids.size() == 25, "se cayeron solo los 25 bloques de la fila base")

	t = ledge()
	t.try_action(E, HANG)
	t._collapse_bottom()
	t._settle()
	check(t.lost, "colgado de la fila que cae: pierde")


func test_generated_towers() -> void:
	var route: Array[Vector3i] = [N, N, E, E, E, E, E, E, S]
	for s in 50:
		var t := TowerLogic.new()
		t.generate(s)
		for d in route:
			t.try_action(d)
		check(t.won and t.moves_made == 9, "torre con semilla %d: la ruta minima gana" % s)
