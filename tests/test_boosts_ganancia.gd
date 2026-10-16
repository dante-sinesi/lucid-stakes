extends SceneTree
## Los boosts y consumibles que disparan la ganancia (docs/diseno.md §47), la vitrina del casino y la tienda.
## Ejecutar: godot --headless --path . -s tests/test_boosts_ganancia.gd

const TowerLogic := preload("res://scripts/tower_logic.gd")
const RunState := preload("res://scripts/run_state.gd")
const Items := preload("res://scripts/items.gd")
const Showcase := preload("res://scripts/showcase.gd")
const Roulette := preload("res://scripts/roulette.gd")
const CasinoScene := preload("res://scripts/casino_scene.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


## Una torre chica de 3 columnas de 4 bloques: caminar sube escalones, así que cada paso purifica un bloque nuevo.
func stairs(perks: Array) -> RefCounted:
	var t := TowerLogic.new()
	t.size = Vector2i(8, 8)
	t.collapse_every = 1 << 20
	t.moves_to_collapse = 1 << 20
	for x in range(0, 6):
		t.add_block(Vector3i(x, 0, 0))
	for x in range(1, 6):
		for y in range(1, x + 1):
			t.add_block(Vector3i(x, y, 0))
	t.player = Vector3i(0, 1, 0)
	t.goal_y = 99
	t.apply_perks(perks)
	return t


func walk(t, n: int) -> void:
	for i in n:
		t.try_action(Vector3i(1, 0, 0))


func _init() -> void:
	test_numbers()
	test_streak()
	test_consumables()
	test_catalog()
	test_showcase()
	test_toll_discounts()
	await test_casino_use()
	print("tests de los boosts de ganancia terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_numbers() -> void:
	var base := stairs([])
	base.try_action(Vector3i(1, 0, 0))
	var g0: int = base.last_gain
	check(g0 > 0, "pisar un bloque nuevo da claridad (%d)" % g0)
	var t := stairs(["pies_de_oro"])
	t.try_action(Vector3i(1, 0, 0))
	check(t.last_gain == g0 + 2 * t.last_purified.size(), "Pies de oro: +2 por bloque purificado (%d contra %d con %d bloques)" % [t.last_gain, g0, t.last_purified.size()])
	t = stairs(["pies_de_luz", "pies_de_oro", "midas"])
	t.try_action(Vector3i(1, 0, 0))
	check(t.last_gain == g0 + 6 * t.last_purified.size(), "Pies de luz, Pies de oro y Midas suman +1, +2 y +3 por bloque (%d)" % t.last_gain)
	t = stairs(["cosecha_doble"])
	t.try_action(Vector3i(1, 0, 0))
	check(t.last_gain == g0 * 2, "Cosecha doble: ×2 (%d)" % t.last_gain)
	t = stairs(["cosecha_doble", "cosecha"])
	t.try_action(Vector3i(1, 0, 0))
	check(t.last_gain == int(round(float(g0) * 3.0)), "Cosecha doble y Cosecha se multiplican: ×3 (%d)" % t.last_gain)
	# Buen ojo: los especiales dan el doble
	t = stairs(["buen_ojo"])
	t.kind_of[t.blocks[Vector3i(1, 0, 0)]] = TowerLogic.Kind.ICE
	t.try_action(Vector3i(1, 0, 0))
	check(t.block_clarity(Vector3i(1, 0, 0)) == TowerLogic.CLARITY[TowerLogic.Kind.ICE] * 2, "Buen ojo: el hielo da el doble")
	# Bolsillo de luz: se empieza con claridad
	t = stairs(["bolsillo_de_luz"])
	check(t.claridad == TowerLogic.POCKET_START, "Bolsillo de luz: empezás la torre con %d" % TowerLogic.POCKET_START)
	# Escalador: pisos nuevos
	t = stairs(["escalador"])
	var c0: int = t.claridad
	t.try_action(Vector3i(1, 0, 0))   # sube de piso
	var plain := stairs([])
	plain.try_action(Vector3i(1, 0, 0))
	check(t.claridad - c0 == plain.claridad + TowerLogic.CLIMB_BONUS, "Escalador: +%d por el piso nuevo" % TowerLogic.CLIMB_BONUS)
	var before: int = t.claridad
	t.try_action(Vector3i(-1, 0, 0))   # baja y vuelve a subir: ya no es un piso nuevo
	t.try_action(Vector3i(1, 0, 0))
	check(t.claridad - before == 0, "Escalador: no paga dos veces el mismo piso")


func test_streak() -> void:
	# la racha se corta si una acción no purifica nada nuevo; con Racha imparable no se corta al empujar o tirar
	var t := stairs([])
	walk(t, 3)
	check(t.streak == 3, "tres pasos nuevos: racha 3")
	t.add_block(Vector3i(5, 1, 1))
	t.try_action(Vector3i(0, 0, 1), TowerLogic.Mode.GRAB)   # empuja un bloque (no purifica nada)
	check(t.streak == 0 or t.last_grab == "", "sin Racha imparable, empujar corta la racha")
	var u := stairs(["racha_imparable"])
	walk(u, 3)
	var s_before: int = u.streak
	u.add_block(Vector3i(3, 3, 1))
	u.player = Vector3i(3, 4, 0) if u.blocks.has(Vector3i(3, 3, 0)) else u.player
	u.try_action(Vector3i(0, 0, 1), TowerLogic.Mode.GRAB)
	check(u.streak == s_before, "con Racha imparable empujar no corta la racha (%d)" % u.streak)
	check(u.streak_mult(100) == 8.0, "el tope de la racha sube a ×8")


func test_consumables() -> void:
	var t := stairs([])
	walk(t, 2)
	var c0: int = t.claridad
	var res: Dictionary = t.use_item("iman_de_luz")
	check(res.ok and t.claridad > c0, "Imán de luz purifica los bloques cercanos y da claridad")
	t = stairs([])
	t.use_item("baraja_de_racha")
	check(t.streak_mult(t.streak) >= 4.0 or t.streak >= 7, "Baraja de racha: la racha pasa a ×4")
	t = stairs([])
	var r2: Dictionary = t.use_item("reloj_de_arena")
	check(r2.ok and t.collapse_pause == 10, "Reloj de arena: 10 movimientos de pausa")
	t = stairs([])
	var r3: Dictionary = t.use_item("lluvia_de_luz")
	check(r3.ok and t.claridad > 0, "Lluvia de luz purifica la capa")
	t = stairs([])
	t.use_item("pocion_de_cosecha")
	t.try_action(Vector3i(1, 0, 0))
	var plain := stairs([])
	plain.try_action(Vector3i(1, 0, 0))
	check(t.last_gain == plain.last_gain * 2, "Poción de cosecha: ×2 en la torre")
	check(not t.use_item("pocion_de_cosecha").ok, "no se puede tomar dos veces")
	var c: TowerLogic = t.clone()
	check(c.harvest_potion and c.max_floor == t.max_floor, "el clon conserva la poción y el piso más alto")


func test_catalog() -> void:
	var ids := ["cosecha_doble", "racha_imparable", "midas", "cosecha", "pies_de_oro", "buen_ojo", "escalador", "empuje_rentable", "interes", "descuento_duende", "lluvia_de_luz", "soborno",
			"bolsillo_de_luz", "pocion_de_cosecha", "iman_de_luz", "baraja_de_racha", "reloj_de_arena", "bolsa_pesada", "saquito_de_oro", "cofre_de_luz", "tesoro"]
	for id in ids:
		check(not Items.get_item(id).is_empty(), "%s está en el catálogo" % id)
		check(preload("res://scripts/item_icons.gd").has_icon(id) or Items.get_item(id).type == Items.Type.CLARITY, "%s tiene ícono" % id)
	# el rendimiento de la ruleta sigue cerca de 0,95 en todos los niveles
	for bet in Roulette.BETS:
		var r := Roulette.expected_ratio(bet, 1)
		check(r > 0.9 and r < 1.0, "el rendimiento de %s sigue entre 0,9 y 1,0 (%.3f)" % [Roulette.BETS[bet].name, r])


func test_showcase() -> void:
	var run := RunState.new()
	run.stage = 8
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	run.boosts.append("midas")
	Showcase.generate(run, rng)
	for tier in Showcase.COUNTS:
		var ids: Array = run.showcase.tiers[str(tier)]
		check(ids.size() == mini(int(Showcase.COUNTS[tier]), Items.by_tier(tier).size()), "la vitrina muestra %d premios del nivel %d" % [ids.size(), tier])
	check(not run.showcase.tiers[str(Items.Tier.EPICO)].has("midas"), "no sale un boost que ya tenés")
	# el premio de la ruleta sale de la vitrina
	for i in 60:
		var p := Showcase.pick(run, Items.Tier.EPICO, rng)
		check(run.showcase.tiers[str(Items.Tier.EPICO)].has(p.id), "el premio épico sale de la vitrina (%s)" % p.id)
		if fails > 3:
			break
	# rotar cuesta una ficha y una más por rotación
	run.claridad = 5000
	var cost1 := Showcase.rotate_cost(run)
	check(cost1 == Roulette.run_price(run), "rotar cuesta una ficha")
	check(Showcase.rotate(run, rng) and run.claridad == 5000 - cost1, "la primera rotación cobra una ficha")
	check(Showcase.rotate_cost(run) == 2 * Roulette.run_price(run), "la segunda cuesta dos fichas")
	check(Showcase.rotations(run) == 1, "se cuenta la rotación")
	run.claridad = 1
	check(not Showcase.rotate(run, rng), "sin claridad no se rota")
	# otra etapa: otra vitrina
	run.stage = 9
	Showcase.enter(run, rng)
	check(int(run.showcase.stage) == 9 and Showcase.rotations(run) == 0, "en otra etapa hay vitrina nueva y las rotaciones vuelven a cero")
	# tienda
	var offers := Showcase.shop_offers(run)
	check(offers.size() == 3, "la tienda ofrece 3 premios (%d)" % offers.size())
	run.claridad = 100000
	var first: Dictionary = offers[0]
	var price := Showcase.shop_price(run, first)
	var res := Showcase.buy(run, str(first.id))
	check(res.ok and run.claridad == 100000 - price, "comprar cobra el precio (%d)" % price)
	check(Showcase.shop_offers(run).size() == 2, "lo comprado deja de estar a la venta")
	check(not Showcase.buy(run, str(first.id)).ok, "no se compra dos veces")
	run.claridad = 0
	check(not Showcase.buy(run, str(Showcase.shop_offers(run)[0].id)).ok, "sin claridad no se compra")
	# se guarda con el run
	var back = RunState.from_dict(run.to_dict())
	check(back.showcase.get("stage", 0) == 9 and back.showcase.get("sold", []).size() == 1, "la vitrina se guarda con el run")


func test_toll_discounts() -> void:
	var run := RunState.new()
	check(run.toll_after_discounts(1000) == 1000, "sin descuentos se paga el precio")
	run.boosts.append("descuento_duende")
	check(run.toll_after_discounts(1000) == 850, "Descuento del duende: −15 %")
	run.boosts.append("descuento_duende")
	check(run.toll_after_discounts(1000) == 700, "dos Descuentos: −30 %")
	check(not run.has_room_for(Items.get_item("descuento_duende")), "el Descuento se acumula sólo hasta 2")
	run.toll_bribe = true
	check(run.toll_after_discounts(1000) == 400, "con el Soborno: −60 % en total")
	run = RunState.new()
	run.claridad = 400
	run.boosts.append("interes")
	check(run.apply_interest() == 100 and run.claridad == 500, "Interés: +25 % de lo que queda")
	run.claridad = 10000
	check(run.apply_interest() == RunState.INTEREST_CAP, "Interés tiene tope")


func test_casino_use() -> void:
	var run := RunState.new()
	run.stage = 3
	run.claridad = 10
	run.lives = 1
	run.consumables.assign(["vida_extra", "soborno", "freno"])
	var rng := RandomNumberGenerator.new()
	var c = CasinoScene.new()
	c.quick = true
	c.toll_base = RunState.toll_for(3)
	root.add_child(c)
	c.setup(run, rng)
	c.use_consumable_slot(0)
	check(run.lives == 2 and not run.consumables.has("vida_extra"), "la Vida extra se usa dentro del casino")
	c.use_consumable_slot(0)   # (la Vida extra ya se gastó: el Soborno pasó al lugar 0)
	check(run.toll_bribe and c.toll_now() < RunState.toll_for(3), "el Soborno baja lo que cobra el duende")
	c.use_consumable_slot(0)   # (ahora el lugar 0 es el Freno: no sirve en el casino)
	check(run.consumables == ["freno"], "el Freno no se gasta en el casino")
	c.queue_free()
	await process_frame
