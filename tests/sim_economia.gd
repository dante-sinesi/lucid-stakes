extends SceneTree
## Simulación de la economía casino + torre + Farolín (docs/diseno.md §46). Un run de 15 etapas por jugador simulado; se comparan curvas del precio de Farolín.
## Ejecutar: godot --headless --path . -s tests/sim_economia.gd   (variables: RUNS=4000, SEED=1, SKILL=1.0 habilidad del jugador, CURVES="actual,exp,ingreso,poly")
##
## Qué es medido y qué es supuesto:
##  - MEDIDO con el juego: ingreso de una torre siguiendo el camino mínimo por etapa (tests/sim_ingresos.gd), precio de la ficha (Roulette.price), costo del reintento (RunState),
##    rendimiento de las mesas (ruleta 0,91-0,96, tragamonedas 0,915, blackjack 0,979: tests/probe_rtp.gd).
##  - SUPUESTO (se puede cambiar abajo): cuánto más o menos que el camino mínimo junta cada jugador, con qué probabilidad muere en cada torre, cuántas monedas encuentra, cuánto sube su
##    ingreso cada boost de claridad. Son los números que hay que mirar al leer los resultados: lo que importa es la comparación entre curvas, no el valor absoluto.

const RunState := preload("res://scripts/run_state.gd")
const Roulette := preload("res://scripts/roulette.gd")

const STAGES := 15
## Ingreso de una torre siguiendo el camino mínimo (claridad), medido con tests/sim_ingresos.gd (2 torres por etapa; promedios 1: 193, 3: 292, 5: 156, 8: 215, 10: 260, 12: 198, 15: 404).
## Es muy irregular (depende de cuántos bloques se pisan seguidos: los empujes cortan la racha), así que se usa la recta que mejor lo ajusta: 179 + 8,7 por etapa (187 en la 1, 310 en la 15).
const INCOME_SLOPE := 8.75
const INCOME_BASE := 179.0
const INCOME_SPREAD := 0.25    # lo que varía de una torre a otra (±25 %, medido: de 144 a 301 en las etapas bajas)
const RTP := 0.94              # rendimiento medio de las mesas (promedio de ruleta, tragamonedas y blackjack)
const FREE_PLAYS := 3          # jugadas mínimas por visita (con monedas de la torre: no cuestan claridad)
const COIN_MEAN := 1.2         # monedas extra que se juntan por torre (promedio)
const BOOST_P := 0.12          # probabilidad de que una jugada dé un boost de claridad
const BOOST_GAIN := 0.14       # cuánto sube el ingreso cada boost de claridad (pies de luz, mano de oro, racha larga, ahorro...)
const BOOST_MAX := 6
const SPEND := 0.7             # fracción de lo que sobra después de apartar el precio de Farolín que se gasta en jugadas extra (con claridad)
const CLARITY_BACK := 0.3      # fracción de lo gastado en jugadas extra que vuelve como claridad (bolsas de luz)
const LIFE_P := 0.025          # probabilidad de que una jugada de ruleta dé una vida extra
const DIE_BASE := 0.04         # probabilidad de morir en una torre en la etapa 1 (sube con la etapa)
const DIE_TOP := 0.22          # y en la 15, para un jugador de habilidad 1,0

var rng := RandomNumberGenerator.new()
var skill := 1.0
var surplus_sum := PackedFloat32Array()


func _env(name: String, def: String) -> String:
	return OS.get_environment(name) if OS.get_environment(name) != "" else def


func income_opt(stage: int) -> float:
	return INCOME_BASE + INCOME_SLOPE * float(stage)


## El precio de Farolín en la etapa `s` según la curva.
func toll(curve: String, s: int) -> float:
	match curve:
		"actual":   # lo que está hoy: 40 + 4 por etapa
			return 40.0 + 4.0 * s
		"exp":   # la propuesta de la charla: 50 * 1,25^(s-1)
			return 50.0 * pow(1.25, s - 1)
		"suave":   # exponencial más lenta: 50 * 1,12^(s-1)
			return 50.0 * pow(1.12, s - 1)
		"lineal":   # 45 + 9,5 por etapa: de 45 a 178 (el 24 % del ingreso en la 1 y el 57 % en la 15)
			return 45.0 + 9.5 * float(s - 1)
		"ingreso":   # una fracción creciente del ingreso de la recta: de 0,25 en la etapa 1 a 0,80 en la 15
			return income_opt(s) * lerpf(0.25, 0.80, float(s - 1) / float(STAGES - 1))
		"poly":
			return 40.0 + 4.0 * s + 0.45 * s * s
	return 0.0


func p_die(s: int) -> float:
	return clampf(lerpf(DIE_BASE, DIE_TOP, float(s - 1) / float(STAGES - 1)) / skill, 0.0, 0.9)


## Un run. Devuelve {stage (la última que se pasó), won, lives_lost, fails (veces que faltó para pagar), claridad al final}.
func run_one(curve: String) -> Dictionary:
	var claridad := 0.0
	var lives := 3
	var boosts := 0
	var lives_lost := 0
	var short_fails := 0
	var reached := 0
	for s in range(1, STAGES + 1):
		var tower_retries := 0
		var cleared := false
		while not cleared:
			var price := float(Roulette.price(s))
			# (morir o no llegar a pagar cuesta una vida, no claridad)
			# la torre: ingreso del camino mínimo × lo que junta este jugador × boosts de claridad
			var mult := (1.0 - INCOME_SPREAD + 2.0 * INCOME_SPREAD * rng.randf()) * (0.9 + 0.1 * skill) * (1.0 + BOOST_GAIN * boosts)
			var income := income_opt(s) * mult
			if rng.randf() < p_die(s):   # se muere antes de llegar al final: pierde una vida y lo que juntó en ese intento se conserva a medias
				claridad += income * 0.4
				lives -= 1
				lives_lost += 1
				tower_retries += 1
				if lives <= 0:
					return {"stage": reached, "won": false, "lives_lost": lives_lost, "fails": short_fails, "claridad": claridad}
				continue
			claridad += income
			# el casino: jugadas con monedas (gratis) y el resto de la claridad que sobre después de Farolín se puede jugar
			var plays := FREE_PLAYS + int(COIN_MEAN + rng.randf())
			for i in plays:
				if rng.randf() < BOOST_P and boosts < BOOST_MAX:
					boosts += 1
				if lives < 3 and rng.randf() < LIFE_P:
					lives += 1
			var need := toll(curve, s)
			if claridad < need:   # no alcanza para Farolín: pierde una vida y sube la misma torre otra vez
				short_fails += 1
				lives -= 1
				lives_lost += 1
				tower_retries += 1
				if lives <= 0:
					return {"stage": reached, "won": false, "lives_lost": lives_lost, "fails": short_fails, "claridad": claridad}
				continue
			var surplus := claridad - need
			if surplus > 0.0:   # se juega con lo que sobra, apartando antes lo de Farolín (que se ve desde la torre)
				var n := int(surplus * SPEND / price)
				claridad -= float(n) * price * (1.0 - CLARITY_BACK)
				for i in n:
					if rng.randf() < BOOST_P and boosts < BOOST_MAX:
						boosts += 1
					if lives < 3 and rng.randf() < LIFE_P:
						lives += 1
				surplus_sum[s] += float(n) * price
			claridad -= need
			cleared = true
		reached = s
	return {"stage": reached, "won": true, "lives_lost": lives_lost, "fails": short_fails, "claridad": claridad}


func _init() -> void:
	rng.seed = int(_env("SEED", "1"))
	skill = float(_env("SKILL", "1.0"))
	var runs := int(_env("RUNS", "4000"))
	var curves: PackedStringArray = _env("CURVES", "actual,lineal,ingreso,suave,exp").split(",")
	print("ingreso del camino mínimo y precio de Farolín por etapa:")
	var head := "etapa  ingreso  ficha"
	for c in curves:
		head += "  %8s" % c
	print(head)
	for s in range(1, STAGES + 1):
		var line := "%5d  %7.0f  %5d" % [s, income_opt(s), Roulette.price(s)]
		for c in curves:
			line += "  %8.0f" % toll(c, s)
		print(line)
	print("")
	for c in curves:
		var reach := PackedFloat32Array()
		reach.resize(STAGES + 1)
		surplus_sum.resize(STAGES + 1)
		surplus_sum.fill(0.0)
		var wins := 0
		var lost := 0.0
		var fails := 0.0
		var left := 0.0
		for r in runs:
			var res := run_one(c)
			for s in range(1, int(res.stage) + 1):
				reach[s] += 1.0
			wins += 1 if res.won else 0
			lost += float(res.lives_lost)
			fails += float(res.fails)
			left += float(res.claridad)
		var line := "%-8s gana %5.1f %%  vidas perdidas %.2f  veces sin plata %.2f  claridad sobrante %.0f  | pasan la etapa:" % [c, 100.0 * wins / runs, lost / runs, fails / runs, left / runs]
		for s in [3, 6, 9, 12, 15]:
			line += " %d:%3.0f%%" % [s, 100.0 * reach[s] / runs]
		print(line)
		var sp := "         jugadas extra pagadas con claridad por visita (en claridad):"
		for s2 in [1, 3, 6, 9, 12, 15]:
			sp += " %d:%4.0f" % [s2, surplus_sum[s2] / maxf(reach[s2], 1.0)]
		print(sp)
	quit(0)
