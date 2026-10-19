extends SceneTree
## Pruebas de los boosts y consumibles del run (efectos en las reglas de la torre).
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/test_perks.gd

const TowerLogic := preload("res://scripts/tower_logic.gd")
const Items := preload("res://scripts/items.gd")
const E := Vector3i(1, 0, 0)
const W := Vector3i(-1, 0, 0)
const S := Vector3i(0, 0, 1)
const N := Vector3i(0, 0, -1)
const GRAB := TowerLogic.Mode.GRAB
const ICE := TowerLogic.Kind.ICE
const BOMB := TowerLogic.Kind.BOMB

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func fresh(every := 1000) -> RefCounted:
	var t := TowerLogic.new()
	t.size = Vector2i(5, 5)
	t.goal_y = 99
	t.collapse_every = every
	t.moves_to_collapse = every * 2
	for x in 5:
		for z in 5:
			t.add_block(Vector3i(x, 0, z))
	t.player = Vector3i(2, 1, 2)
	return t


func _init() -> void:
	test_catalogue()
	test_streak()
	test_collapse_boosts()
	test_purify_boosts()
	test_other_boosts()
	test_second_wind()
	test_consumables()
	print("tests de boosts y consumibles terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


## Todo premio del catálogo (menos las bolsas de claridad) tiene su efecto conectado.
func test_catalogue() -> void:
	var boosts := ["segundo_aliento", "madrugada", "luz_propia", "mano_de_oro", "pies_de_luz", "paso_firme", "reflejos", "racha_larga", "aire_extra", "ojo_de_hielo", "ahorro", "bolsillo_hondo", "mente_abierta",
			"cosecha_doble", "racha_imparable", "midas", "cosecha", "pies_de_oro", "buen_ojo", "escalador", "empuje_rentable", "interes", "descuento_duende", "bolsillo_de_luz", "mano_23", "mesa_caliente", "blackjack_de_oro", "ficha_barata", "casilla_de_regalo", "red_de_seguridad", "giro_de_cortesia", "llave_de_la_vitrina"]   # (los de ganancia y los del casino se prueban en test_boosts_ganancia.gd y test_casino_items.gd)
	var consumables := ["freno", "desarmar", "ancla_chica", "conv_roca", "conv_hielo", "conv_agrietado", "conv_trampa", "conv_pinchos", "conv_pesado", "conv_bomba", "conv_catapulta", "escudo", "doble_salto", "totem", "teletransporte", "vida_extra", "lluvia_de_luz", "soborno", "pocion_de_cosecha", "iman_de_luz", "baraja_de_racha", "reloj_de_arena", "doble_o_nada", "ficha_gratis", "rayos_x"]
	var ok := true
	for it in Items.ALL:
		if it.type == Items.Type.BOOST:
			ok = ok and boosts.has(it.id)
		elif it.type == Items.Type.CONSUMABLE:
			ok = ok and consumables.has(it.id)
	check(ok, "cada boost y consumible del catalogo tiene efecto implementado")
	for id in consumables:
		var t := fresh()
		t.add_block(Vector3i(2, 1, 1))
		check(t.use_item(id).has("ok"), "use_item(%s) responde" % id)


func test_streak() -> void:
	var t := fresh()
	check(is_equal_approx(t.streak_mult(3), 2.0) and is_equal_approx(t.streak_mult(50), 4.0), "sin boosts: x2 con racha 3 y tope x4")
	t.apply_perks(["mano_de_oro"])
	check(is_equal_approx(t.streak_mult(3), 3.0), "Mano de oro: la racha sube de a 1,0")
	t.apply_perks(["racha_larga"])
	check(is_equal_approx(t.streak_mult(50), 6.0) and is_equal_approx(t.streak_mult(3), 2.0), "Racha larga: tope x6")
	t.apply_perks(["racha_larga", "mano_de_oro"])
	check(is_equal_approx(t.streak_mult(4), 4.0) and is_equal_approx(t.streak_mult(50), 6.0), "los dos juntos se combinan")


func test_collapse_boosts() -> void:
	var t := fresh(6)
	t.apply_perks(["aire_extra"])
	check(t.collapse_every == 7 and t.moves_to_collapse == 14, "Aire extra: la caida llega un movimiento mas tarde (y la primera, a 2N)")
	t = fresh(6)
	t.apply_perks(["madrugada"])
	check(t.collapse_every == 12 and t.moves_to_collapse == 24, "Madrugada: la fila de abajo cae al doble de lento")
	t = fresh(6)
	t.apply_perks(["madrugada", "aire_extra"])
	check(t.collapse_every == 13, "Madrugada + Aire extra: 6 x 2 + 1")
	# Paso firme: trepar y bajar escalones no acerca la caida.
	t = fresh(3)
	t.moves_to_collapse = 3
	t.add_block(Vector3i(3, 1, 2))
	t.apply_perks(["paso_firme"])
	var before: int = t.moves_to_collapse
	t.try_action(E)  # trepa al bloque
	check(t.player == Vector3i(3, 2, 2) and t.moves_to_collapse == before, "Paso firme: trepar no cuenta para la caida")
	t.try_action(E)  # baja un escalon
	check(t.moves_to_collapse == before, "Paso firme: bajar un escalon tampoco")
	t.try_action(N)
	check(t.moves_to_collapse == before - 1, "caminar en llano si cuenta")
	t = fresh(3)
	t.moves_to_collapse = 3
	t.add_block(Vector3i(3, 1, 2))
	t.try_action(E)
	check(t.moves_to_collapse == 2, "sin el boost, trepar cuenta")


func test_purify_boosts() -> void:
	var t := fresh()
	t.apply_perks(["pies_de_luz"])
	t.try_action(E)  # purifica el bloque de partida y el de llegada (2 bloques): +1 por cada uno
	var plain0 = fresh()
	plain0.try_action(E)
	check(t.last_gain == plain0.last_gain + 2 and plain0.last_gain == 2, "Pies de luz: +1 de claridad por bloque purificado (%d vs %d)" % [t.last_gain, plain0.last_gain])
	t = fresh()
	t.apply_perks(["luz_propia"])
	t.try_action(E)  # pisa (3,0,2): tambien se purifican sus vecinos de la capa
	check(t.purified.has(t.blocks[Vector3i(3, 0, 2)]) and t.purified.has(t.blocks[Vector3i(4, 0, 2)]) and t.purified.has(t.blocks[Vector3i(3, 0, 1)]) and t.purified.has(t.blocks[Vector3i(3, 0, 3)]), "Luz propia: se purifican los vecinos de lo que pisas")
	var plain = fresh()
	plain.try_action(E)
	check(plain.purified.size() < t.purified.size(), "...y sin el boost solo el bloque pisado")


func test_other_boosts() -> void:
	var t := fresh()
	t.add_block(Vector3i(0, 1, 0), false, BOMB, 4)
	t.apply_perks(["reflejos"])
	check(t.bomb_timer[t.blocks[Vector3i(0, 1, 0)]] == 7, "Reflejos: las bombas empiezan 3 movimientos mas altas")
	t = fresh()
	t.apply_perks(["ahorro"])
	check(t.claridad == 20, "Ahorro: se arranca la etapa con 20 de claridad")
	# Ojo de hielo: se frena una celda antes.
	t = fresh()
	for x in range(1, 4):
		t.kind_of[t.blocks[Vector3i(x, 0, 2)]] = ICE
	t.recompute_zob()
	t.player = Vector3i(0, 1, 2)
	var plain = t.clone()
	plain.try_action(E)
	t.apply_perks(["ojo_de_hielo"])
	t.try_action(E)
	check(plain.player.x == 4 and t.player.x == 3, "Ojo de hielo: resbalas hasta una celda antes (%d vs %d)" % [t.player.x, plain.player.x])


func test_second_wind() -> void:
	# El bloque donde estas parado desaparece (queda sin piso): sin el boost se pierde; con el boost se vuelve a la ultima celda firme.
	var t := fresh()
	t.player = Vector3i(2, 1, 2)
	t._remove_block(Vector3i(2, 0, 2))
	t._after_action()
	check(t.lost, "sin el boost, quedarse sin piso es perder")
	t = fresh()
	t.apply_perks(["segundo_aliento"])
	t.last_safe = Vector3i(1, 1, 2)
	t.player = Vector3i(2, 1, 2)
	t._remove_block(Vector3i(2, 0, 2))
	t._after_action()
	check(not t.lost and t.player == Vector3i(1, 1, 2) and t.second_wind_used and t.perk_msg == "¡Segundo aliento!", "Segundo aliento: se vuelve a la ultima celda firme")
	# Una sola vez por etapa
	t._remove_block(Vector3i(1, 0, 2))
	t._after_action()
	check(t.lost, "...pero solo una vez por etapa")
	# Reintentar la etapa (apply_perks de nuevo) lo renueva
	t = fresh()
	t.apply_perks(["segundo_aliento"])
	check(not t.second_wind_used, "al empezar la etapa esta disponible")


func test_consumables() -> void:
	# Freno
	var t := fresh(3)
	t.moves_to_collapse = 3
	t.use_item("freno")
	check(t.collapse_pause == 5, "Freno: 5 movimientos de pausa")
	for i in 5:
		t.try_action(E if i % 2 == 0 else W)
	check(t.moves_to_collapse == 3, "Freno: durante la pausa la fila de abajo no se acerca")
	t.try_action(E)
	check(t.moves_to_collapse == 2, "...y despues vuelve a contar")
	# Desarmar
	t = fresh()
	check(not t.use_item("desarmar").ok, "Desarmar sin bombas no se puede usar")
	t.add_block(Vector3i(0, 1, 0), false, BOMB, 4)
	t.add_block(Vector3i(3, 1, 3), false, BOMB, 4)
	var near: int = t.blocks[Vector3i(3, 1, 3)]
	var far: int = t.blocks[Vector3i(0, 1, 0)]
	check(t.use_item("desarmar").ok and not t.bomb_timer.has(near) and t.bomb_timer.has(far), "Desarmar: desactiva la bomba mas cercana")
	# Hielo a roca
	t = fresh()
	check(not t.use_item_at("conv_roca", Vector3i(3, 1, 2)).ok, "el Polvo de roca sobre un lugar sin bloque no se puede usar")
	t.add_block(Vector3i(3, 1, 2), false, ICE)
	var zob_before: int = t.zob
	check(t.use_item_at("conv_roca", Vector3i(3, 1, 2)).ok and t.kind_at(Vector3i(3, 1, 2)) == TowerLogic.Kind.NORMAL, "Polvo de roca: el bloque elegido (de hielo) pasa a ser normal")
	var check_zob: int = t.zob
	t.recompute_zob()
	check(check_zob == t.zob and zob_before != t.zob, "...y la huella del estado queda al dia")
	# Catapulta de bolsillo
	t = fresh()
	t.facing = E
	check(not t.use_item_at("conv_catapulta", Vector3i(3, 1, 2)).ok, "el Resorte sin bloque ahí no se puede usar")
	t.add_block(Vector3i(3, 1, 2))
	check(t.use_item_at("conv_catapulta", Vector3i(3, 1, 2)).ok and t.kind_at(Vector3i(3, 1, 2)) == TowerLogic.Kind.CATAPULT, "Resorte: el bloque elegido pasa a ser catapulta")
	# Ancla chica
	t = fresh()
	t.facing = E
	t.add_block(Vector3i(3, 1, 2))
	t.add_block(Vector3i(4, 1, 2))
	check(t.use_item("ancla_chica").ok, "Ancla chica se usa sobre el bloque de enfrente")
	t._remove_block(Vector3i(4, 1, 2))   # el vecino se va
	t._remove_block(Vector3i(3, 0, 2))   # y el piso de abajo tambien
	t._remove_block(Vector3i(2, 0, 2))
	t._remove_block(Vector3i(4, 0, 2))
	t._remove_block(Vector3i(3, 0, 1))
	t._remove_block(Vector3i(3, 0, 3))
	t._settle()
	check(t.blocks.has(Vector3i(3, 1, 2)), "Ancla chica: el bloque anclado no cae aunque pierda a sus vecinos")
	# No se usa con la partida terminada
	t.lost = true
	check(not t.use_item("freno").ok, "no se usan consumibles con la partida terminada")
