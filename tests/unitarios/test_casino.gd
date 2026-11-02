extends SceneTree
## Pruebas de la economía del casino: premios, estado del run y reglas de la ruleta.
## Ejecutar: tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_casino.gd

const Items := preload("res://scripts/datos/items.gd")
const RunState := preload("res://scripts/datos/run_state.gd")
const Roulette := preload("res://scripts/casino/roulette.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func rich_run(stage := 1, claridad := 1000, boosts: Array = []) -> RefCounted:
	var r := RunState.new()
	r.stage = stage
	r.claridad = claridad
	r.boosts.assign(boosts)
	return r


func _init() -> void:
	var old_base: int = Roulette.base_price   # (estas pruebas razonan con la ficha de los primeros balances: 50 y +4 por etapa; el balance actual se elige aparte)
	var old_step: int = Roulette.price_step
	var old_chica: Array = Roulette.chica_mult
	Roulette.chica_mult = []   # (sin la ficha chica de la taberna)
	Roulette.base_price = 50
	Roulette.price_step = 4
	test_items()
	test_run_state()
	test_roulette_rules()
	test_roulette_resolve()
	test_roulette_statistics()
	Roulette.chica_mult = old_chica
	test_ficha_chica()
	Roulette.base_price = old_base
	Roulette.price_step = old_step
	Roulette.chica_mult = old_chica
	print("tests del casino terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)


func test_items() -> void:
	var ids := {}
	var ok := true
	for it in Items.ALL:
		ok = ok and not ids.has(it.id) and it.name != "" and it.desc != "" and it.weight > 0
		ids[it.id] = true
		ok = ok and (it.type == Items.Type.CLARITY and it.has("mult") or it.has("value"))
	check(ok, "cada premio tiene id unico, nombre, descripcion, peso y valor (o multiplicador)")
	check(Items.by_tier(Items.Tier.EPICO).size() == 14 and Items.by_tier(Items.Tier.RARO).size() == 25, "14 premios epicos y 25 raros (el catálogo sin los premios que ya no existen)")
	var epic_boosts := true
	for it in Items.by_tier(Items.Tier.EPICO):
		epic_boosts = epic_boosts and (it.type == Items.Type.BOOST or it.type == Items.Type.CLARITY)
	check(epic_boosts, "los premios epicos son boosts o bolsas grandes de claridad")
	check(Items.get_item("aire_extra").name == "Aire extra" and Items.get_item("no_existe").is_empty(), "get_item busca por id")
	# el valor medio sube con el nivel
	check(Items.mean_value(Items.Tier.CONSUMIBLE, 50) < Items.mean_value(Items.Tier.COMUN, 50) \
			and Items.mean_value(Items.Tier.COMUN, 50) < Items.mean_value(Items.Tier.RARO, 50) \
			and Items.mean_value(Items.Tier.RARO, 50) < Items.mean_value(Items.Tier.EPICO, 50), "los niveles valen mas cuanto mas altos")
	# el sorteo respeta los pesos: la bolsa de luz sale según su peso entre los consumibles baratos
	var peso_total := 0.0
	for it in Items.by_tier(Items.Tier.CONSUMIBLE):
		peso_total += float(it.weight)
	var esperado: float = 6.0 / peso_total
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bags := 0
	for i in 4000:
		if Items.pick(Items.Tier.CONSUMIBLE, rng).id == "bolsa_de_luz":
			bags += 1
	check(absf(bags / 4000.0 - esperado) < 0.03, "el sorteo respeta los pesos (bolsa de luz %.3f, esperado %.3f)" % [bags / 4000.0, esperado])
	for t in 4:
		var pick := Items.pick(t, rng)
		check(pick.tier == t, "pick(%d) devuelve un premio de ese nivel" % t)


func test_run_state() -> void:
	var r := rich_run(1, 100)
	check(r.can_afford(100) and not r.can_afford(101) and not r.can_afford(-1), "can_afford")
	check(r.spend(40) and r.claridad == 60 and not r.spend(61) and r.claridad == 60, "spend cobra y no deja pasarse")
	r.gain(25)
	r.gain(-10)
	check(r.claridad == 85, "gain suma y no acepta negativos")
	var boost := Items.get_item("aire_extra")
	check(r.take(boost) and r.has_boost("aire_extra") and not r.take(boost), "un boost se guarda una vez y no se repite")
	for id in ["madrugada", "ahorro", "pies_de_luz", "paso_firme"]:
		r.take(Items.get_item(id))
	check(r.boosts.size() == r.boost_capacity() and not r.has_room_for(Items.get_item("racha_larga")), "hay un maximo de %d boosts" % r.boost_capacity())
	for i in r.consumable_capacity():
		r.take(Items.get_item("freno"))
	check(r.consumables.size() == r.consumable_capacity() and not r.has_room_for(Items.get_item("freno")), "hay un maximo de %d consumibles (los repetidos si valen)" % r.consumable_capacity())
	check(r.use_consumable("freno") and r.consumables.size() == r.consumable_capacity() - 1 and not r.use_consumable("desarmar"), "usar un consumible lo gasta; sin el no se puede")
	check(not r.has_room_for(Items.get_item("bolsa_de_luz")), "las bolsas de claridad no ocupan lugar: se pagan directo")


func test_roulette_rules() -> void:
	check(Roulette.POCKETS == 13 and Roulette.WHEEL.size() == 13, "la rueda tiene 13 casillas")
	check(Roulette.count_of(Items.Tier.EPICO) == 1 and Roulette.count_of(Items.Tier.RARO) == 2 and Roulette.count_of(Items.Tier.COMUN) == 4 and Roulette.count_of(Items.Tier.CONSUMIBLE) == 6, "1 casilla épica, 2 raras, 4 comunes y 6 de bolsas")
	var psum := 0.0
	for tier in Roulette.TIER_ORDER:
		psum += Roulette.probability(tier)
	check(is_equal_approx(psum, 1.0) and is_equal_approx(Roulette.probability(Items.Tier.EPICO), 1.0 / 13.0), "las probabilidades suman 1 (épico 1/13)")
	check(Roulette.count_of(Items.Tier.EPICO, rich_run(1, 1000, ["casilla_de_regalo"])) == 2 and Roulette.count_of(Items.Tier.COMUN, rich_run(1, 1000, ["casilla_de_regalo"])) == 3, "Casilla de regalo: una casilla común pasa a ser épica")
	# precio por etapa
	check(Roulette.price(1) == 50 and Roulette.price(2) == 54 and Roulette.price(3) == 58 and Roulette.price(11) == 90 and Roulette.price(15) == 106 and Roulette.price(0) == 50, "el precio de la ficha sube con la etapa (50 -> 106)")
	check(Roulette.spin_price(rich_run(1, 1000)) == int(round(50.0 * Roulette.spin_mult)), "el giro cuesta %.1f fichas" % Roulette.spin_mult)
	# balance: con todas las casillas premiadas el giro rinde casi lo que cuesta, con una pequeña ventaja de la casa
	for st in [1, 8, 15]:   # los premios valen proporcionalmente a la ficha: el rendimiento no se desbalancea con las etapas
		var ratio := Roulette.expected_ratio(st)
		check(ratio >= 0.9 and ratio <= 1.0, "etapa %d: rendimiento esperado del giro %.3f entre 0.90 y 1.00 (ventaja chica de la casa)" % [st, ratio])
	# validacion
	var cost := Roulette.spin_price(rich_run(1, 1000))
	check(Roulette.validate(rich_run(1, cost - 1)).contains("claridad"), "sin claridad suficiente no se puede girar")
	check(Roulette.validate(rich_run(1, cost)) == "", "con justo el precio del giro alcanza")


func test_roulette_resolve() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var cost := Roulette.spin_price(rich_run(1, 1000))

	# sin claridad: no cobra nada
	var r := rich_run(1, cost - 1)
	var bad := Roulette.resolve(r, rng)
	check(not bad.ok and r.claridad == cost - 1 and r.casino_spent == 0, "un giro que no se puede pagar no cobra nada")

	# la casilla fija la rareza del premio
	for p in Roulette.POCKETS:
		var rp := rich_run(1, 100000)
		var res := Roulette.resolve(rp, rng, p)
		check(res.ok and res.pocket == p and res.tier == Roulette.WHEEL[p] and res.prize.tier == Roulette.WHEEL[p], "la casilla %d da un premio de su rareza" % p)

	# casilla épica: un boost épico, la claridad baja lo que cuesta el giro
	r = rich_run()
	var win := Roulette.resolve(r, rng, 0)
	check(win.prize.tier == Items.Tier.EPICO and win.prize.type == Items.Type.BOOST and r.boosts.size() == 1, "la casilla épica da un boost épico y lo guarda")
	check(r.claridad == 1000 - cost and win.claridad_delta == -cost and r.casino_spent == cost, "ganar un boost no devuelve claridad: el giro igual se paga")

	# una casilla de bolsas: bolsa de luz (1,4 fichas) u otro premio barato; la ruleta nunca "pierde" (siempre da algo)
	var paid_bag := false
	for i in 40:
		var rr := rich_run()
		var w := Roulette.resolve(rr, rng, 1)
		check(w.prize.tier == Items.Tier.CONSUMIBLE and not w.prize.is_empty(), "una casilla de bolsas da un premio del nivel CONSUMIBLE")
		if w.prize.type == Items.Type.CLARITY:
			paid_bag = true
			check(rr.claridad == 1000 - cost + 70 and w.claridad_delta == 70 - cost, "una bolsa de luz devuelve 70 (1,4 fichas de 50)")
	check(paid_bag, "entre 40 giros a una casilla de bolsas sale alguna bolsa de luz")

	# premio que no entra: se convierte en claridad (la mitad de su valor)
	r = rich_run()
	for id in ["aire_extra", "madrugada", "ahorro", "pies_de_luz", "paso_firme"]:
		r.take(Items.get_item(id))
	var full := Roulette.resolve(r, rng, 0)   # un boost épico sin lugar
	check(full.converted and r.boosts.size() == r.boost_capacity(), "sin lugar para boosts el premio no se guarda")
	check(r.claridad == 1000 - cost + int(round(full.prize.value * 0.5)), "...y se convierte en la mitad de su valor en claridad")

	# Segunda vuelta: sólo si cae en común y con una chance de 1 en 5
	var segundas := 0
	var n := 600
	for i in n:
		var rs := rich_run(1, 100000, ["segunda_vuelta"])
		var rc := Roulette.resolve(rs, rng, 2)   # la casilla 2 es común
		if rc.second_spin:
			segundas += 1
			check(rc.first_pocket == 2 and rc.pocket >= 0 and rc.pocket < Roulette.POCKETS, "con Segunda vuelta la casilla final es la de la segunda tirada")
	check(absf(float(segundas) / n - Roulette.SECOND_SPIN) < 0.06, "Segunda vuelta: %.1f %% de las veces en común (esperado %.0f %%)" % [100.0 * segundas / n, 100.0 * Roulette.SECOND_SPIN])
	check(not Roulette.resolve(rich_run(1, 100000, ["segunda_vuelta"]), rng, 0).second_spin and not Roulette.resolve(rich_run(), rng, 2).second_spin, "no gira de nuevo si no es común o si no se tiene el boost")

	# determinismo: misma semilla, misma historia
	var h1 := _history(123)
	var h2 := _history(123)
	var h3 := _history(124)
	check(h1 == h2 and h1 != h3, "con la misma semilla la ruleta repite exactamente lo mismo")

	# se puede jugar hasta quedarse sin claridad
	r = rich_run(1, cost * 2 + 20)
	var spins := 0
	while Roulette.validate(r) == "" and spins < 10:
		Roulette.resolve(r, rng, 4)   # (una casilla rara: no da claridad)
		spins += 1
	check(spins == 2 and r.claridad == 20, "con %d de claridad se pueden hacer 2 giros de %d y quedan 20" % [cost * 2 + 20, cost])


func _history(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var r := rich_run(3, 100000)
	var out: Array = []
	for i in 30:
		var res := Roulette.resolve(r, rng)
		out.append([res.pocket, res.tier, res.prize.get("id", ""), r.claridad])
	return out


func test_roulette_statistics() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	# las casillas salen parejas
	var counts := {}
	var n := 13000
	for i in n:
		var r := rich_run()
		var res := Roulette.resolve(r, rng)
		counts[res.pocket] = counts.get(res.pocket, 0) + 1
	var uniform := true
	for p in Roulette.POCKETS:
		uniform = uniform and absf(counts.get(p, 0) / float(n) - 1.0 / 13.0) < 0.01
	check(uniform, "las 13 casillas salen con la misma frecuencia (~7,7 %)")

	# el rendimiento real a la larga se parece al esperado (valor de lo ganado / lo gastado)
	var trials := 8000
	var spent := 0.0
	var got := 0.0
	for i in trials:
		var r := rich_run()  # inventario vacio: todo entra
		var res := Roulette.resolve(r, rng)
		spent += res.price
		got += Items.value_of(res.prize, Roulette.run_price(r))
	var real := got / spent
	var expected := Roulette.expected_ratio(1)
	check(absf(real - expected) < 0.12, "rendimiento medido %.2f cerca del esperado %.2f" % [real, expected])


## La ficha de la taberna (etapas 1 a 3) es una fracción de la de la fórmula y desde la etapa 4 es la de siempre: sin saltos grandes.
func test_ficha_chica() -> void:
	var viejo_base: int = Roulette.base_price
	var viejo_paso: int = Roulette.price_step
	Roulette.base_price = 50
	Roulette.price_step = 4
	check(Roulette.price(1) == 23 and Roulette.price(2) == 38 and Roulette.price(3) == 42, "la ficha de la taberna: 23, 38 y 42 (%d, %d, %d)" % [Roulette.price(1), Roulette.price(2), Roulette.price(3)])
	check(Roulette.price(4) == 62 and Roulette.price(5) == 66, "desde la etapa 4 la ficha es la de la fórmula")
	check(Roulette.price(3) < Roulette.price(4) and Roulette.price(4) - Roulette.price(3) < 40, "no hay un salto grande al pasar al salón")
	Roulette.base_price = viejo_base
	Roulette.price_step = viejo_paso
