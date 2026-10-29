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


func rich_run(stage := 1, claridad := 1000) -> RefCounted:
	var r := RunState.new()
	r.stage = stage
	r.claridad = claridad
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
	check(Roulette.POCKETS == 13 and Roulette.HOUSE == 0, "13 casillas, la 0 es la casa")
	var psum := 0.0
	for b in Roulette.BETS:
		psum += float(Roulette.BETS[b].count)
	check(psum == 19.0, "las 4 apuestas cubren 1, 3, 6 y 9 casillas")
	check(is_equal_approx(Roulette.probability(Roulette.Bet.PLENO), 1.0 / 13.0) and is_equal_approx(Roulette.probability(Roulette.Bet.RANGO), 9.0 / 13.0), "probabilidades: pleno 1/13, rango 9/13")
	# cuanto menos cubre, mejor el nivel
	check(Roulette.BETS[Roulette.Bet.PLENO].tier > Roulette.BETS[Roulette.Bet.TERNA].tier \
			and Roulette.BETS[Roulette.Bet.TERNA].tier > Roulette.BETS[Roulette.Bet.MITAD].tier \
			and Roulette.BETS[Roulette.Bet.MITAD].tier > Roulette.BETS[Roulette.Bet.RANGO].tier, "menos casillas cubiertas, mejor premio")
	# precio por etapa
	check(Roulette.price(1) == 50 and Roulette.price(2) == 54 and Roulette.price(3) == 58 and Roulette.price(11) == 90 and Roulette.price(15) == 106 and Roulette.price(0) == 50, "el precio de la ficha sube con la etapa (50 -> 106)")
	# balance: las cuatro apuestas rinden casi igual y con una pequeña ventaja de la casa
	var line := ""
	for b in Roulette.BETS:
		var ratio := Roulette.expected_ratio(b, 1)
		line += "%s %.3f  " % [Roulette.BETS[b].name, ratio]
		check(ratio >= 0.9 and ratio <= 1.0, "%s: rendimiento esperado %.3f entre 0.90 y 1.00 (ventaja chica de la casa)" % [Roulette.BETS[b].name, ratio])
		for st in [8, 15]:  # los premios valen proporcionalmente a la ficha: el rendimiento no se desbalancea con las etapas
			var r_st := Roulette.expected_ratio(b, st)
			check(r_st >= 0.9 and r_st <= 1.0, "%s etapa %d: rendimiento esperado %.3f" % [Roulette.BETS[b].name, st, r_st])
	print("rendimiento esperado por ficha, etapa 1: ", line)

	# validacion
	var r := rich_run()
	check(Roulette.validate(r, Roulette.Bet.PLENO, [5]) == "", "un pleno a la casilla 5 es valido")
	check(Roulette.validate(r, Roulette.Bet.TERNA, [1, 2]) != "", "una terna necesita 3 casillas")
	check(Roulette.validate(r, Roulette.Bet.PLENO, [0]).contains("casa"), "no se puede cubrir la casilla 0")
	check(Roulette.validate(r, Roulette.Bet.PLENO, [13]) != "" and Roulette.validate(r, Roulette.Bet.PLENO, [-1]) != "", "casillas fuera de rango")
	check(Roulette.validate(r, Roulette.Bet.TERNA, [4, 4, 5]).contains("dos veces"), "no se repite una casilla")
	check(Roulette.validate(r, 99, [1]) != "", "apuesta desconocida")
	var poor := rich_run(1, 49)
	check(Roulette.validate(poor, Roulette.Bet.PLENO, [1]).contains("claridad"), "sin claridad suficiente no se puede apostar")
	check(Roulette.validate(rich_run(1, 50), Roulette.Bet.PLENO, [1]) == "", "con justo el precio alcanza")


func test_roulette_resolve() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1

	# apuesta invalida: no cobra nada
	var r := rich_run()
	var bad := Roulette.resolve(r, Roulette.Bet.TERNA, [1, 2], rng)
	check(not bad.ok and r.claridad == 1000 and r.casino_spent == 0, "una apuesta invalida no cobra la ficha")

	# perder: cobra la ficha y no da nada
	r = rich_run()
	var lose := Roulette.resolve(r, Roulette.Bet.PLENO, [3], rng, 7)
	check(lose.ok and not lose.won and lose.pocket == 7 and r.claridad == 950 and lose.claridad_delta == -50 and lose.prize.is_empty(), "perder: se pierde la ficha y no hay premio")
	check(r.boosts.is_empty() and r.consumables.is_empty() and r.casino_spent == 50 and r.casino_won == 0, "perder no deja nada en el inventario y se registra el gasto")

	# la casa gana siempre que cae el 0
	r = rich_run()
	var house := Roulette.resolve(r, Roulette.Bet.RANGO, [1, 2, 3, 4, 5, 6, 7, 8, 9], rng, 0)
	check(not house.won and r.claridad == 950, "si cae la casilla 0 siempre pierde, aun cubriendo 9")

	# ganar un pleno: premio epico (un boost)
	r = rich_run()
	var win := Roulette.resolve(r, Roulette.Bet.PLENO, [12], rng, 12)
	check(win.won and win.prize.tier == Items.Tier.EPICO and win.prize.type == Items.Type.BOOST and r.boosts.size() == 1, "ganar un pleno da un boost epico y lo guarda")
	check(r.claridad == 950 and win.claridad_delta == -50, "ganar un boost no devuelve claridad: la ficha igual se paga")

	# ganar un rango: puede ser bolsa de luz (paga 1,4 x la ficha) u otro consumible barato
	var paid_bag := false
	for i in 40:
		var rr := rich_run()
		var w := Roulette.resolve(rr, Roulette.Bet.RANGO, [1, 2, 3, 4, 5, 6, 7, 8, 9], rng, 5)
		check(w.won and w.prize.tier == Items.Tier.CONSUMIBLE, "un rango ganado da un premio del nivel CONSUMIBLE")
		if w.prize.type == Items.Type.CLARITY:
			paid_bag = true
			check(rr.claridad == 1000 - 50 + 70 and w.claridad_delta == 20, "una bolsa de luz devuelve 70 por una ficha de 50 (+20 netos)")
	check(paid_bag, "entre 40 rangos ganados sale alguna bolsa de luz")

	# premio que no entra: se convierte en claridad (la mitad de su valor)
	r = rich_run()
	for id in ["aire_extra", "madrugada", "ahorro", "pies_de_luz", "paso_firme"]:
		r.take(Items.get_item(id))
	var full := Roulette.resolve(r, Roulette.Bet.PLENO, [1], rng, 1)  # un boost epico sin lugar
	check(full.won and full.converted and r.boosts.size() == r.boost_capacity(), "sin lugar para boosts el premio no se guarda")
	check(r.claridad == 1000 - 50 + int(round(full.prize.value * 0.5)), "...y se convierte en la mitad de su valor en claridad")

	# determinismo: misma semilla, misma historia
	var h1 := _history(123)
	var h2 := _history(123)
	var h3 := _history(124)
	check(h1 == h2 and h1 != h3, "con la misma semilla la ruleta repite exactamente lo mismo")

	# se puede jugar hasta quedarse sin claridad
	r = rich_run(1, 120)
	var spins := 0
	while Roulette.validate(r, Roulette.Bet.PLENO, [2]) == "" and spins < 10:
		Roulette.resolve(r, Roulette.Bet.PLENO, [2], rng, 9)
		spins += 1
	check(spins == 2 and r.claridad == 20, "con 120 de claridad se pueden hacer 2 apuestas de 50 y quedan 20")


func _history(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var r := rich_run(3, 100000)
	var out: Array = []
	for i in 30:
		var bet: int = i % 4
		var pockets: Array = range(1, 1 + Roulette.BETS[bet].count)
		var res := Roulette.resolve(r, bet, pockets, rng)
		out.append([res.pocket, res.won, res.prize.get("id", ""), r.claridad])
	return out


func test_roulette_statistics() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	# las casillas salen parejas
	var counts := {}
	var n := 13000
	for i in n:
		var r := rich_run()
		var res := Roulette.resolve(r, Roulette.Bet.PLENO, [1], rng)
		counts[res.pocket] = counts.get(res.pocket, 0) + 1
	var uniform := true
	for p in Roulette.POCKETS:
		uniform = uniform and absf(counts.get(p, 0) / float(n) - 1.0 / 13.0) < 0.01
	check(uniform, "las 13 casillas salen con la misma frecuencia (~7,7 %)")

	# la frecuencia de ganar coincide con la probabilidad de cada apuesta
	for b in Roulette.BETS:
		var wins := 0
		var trials := 6000
		var pockets: Array = range(1, 1 + Roulette.BETS[b].count)
		for i in trials:
			var r := rich_run()
			if Roulette.resolve(r, b, pockets, rng).won:
				wins += 1
		var expect := Roulette.probability(b)
		check(absf(wins / float(trials) - expect) < 0.02, "%s gana el %.1f %% de las veces (esperado %.1f %%)" % [Roulette.BETS[b].name, 100.0 * wins / trials, 100.0 * expect])

	# el rendimiento real a la larga se parece al esperado (valor de lo ganado / lo gastado)
	for b in Roulette.BETS:
		var trials := 8000
		var pockets: Array = range(1, 1 + Roulette.BETS[b].count)
		var spent := 0.0
		var got := 0.0
		for i in trials:
			var r := rich_run()  # inventario vacio: todo entra
			var res := Roulette.resolve(r, b, pockets, rng)
			spent += res.price
			if res.won:
				got += Items.value_of(res.prize, res.price)
		var real := got / spent
		var expected := Roulette.expected_ratio(b, 1)
		check(absf(real - expected) < 0.12, "%s: rendimiento medido %.2f cerca del esperado %.2f" % [Roulette.BETS[b].name, real, expected])


## La ficha de la taberna (etapas 1 a 3) es una fracción de la de la fórmula y desde la etapa 4 es la de siempre: sin saltos grandes.
func test_ficha_chica() -> void:
	var viejo_base: int = Roulette.base_price
	var viejo_paso: int = Roulette.price_step
	Roulette.base_price = 75
	Roulette.price_step = 6
	check(Roulette.price(1) == 34 and Roulette.price(2) == 57 and Roulette.price(3) == 63, "la ficha de la taberna: 34, 57 y 63 (%d, %d, %d)" % [Roulette.price(1), Roulette.price(2), Roulette.price(3)])
	check(Roulette.price(4) == 93 and Roulette.price(5) == 99, "desde la etapa 4 la ficha es la de la fórmula")
	check(Roulette.price(3) < Roulette.price(4) and Roulette.price(4) - Roulette.price(3) < 40, "no hay un salto grande al pasar al salón")
	Roulette.base_price = viejo_base
	Roulette.price_step = viejo_paso
