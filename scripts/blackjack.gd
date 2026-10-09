extends RefCounted
## Blackjack contra la casa: reglas puras, sin interfaz.
##
## Un mazo de 52 cartas (los palos son los símbolos del juego: cubo, hielo, bomba y sol) que se baraja en cada mano. Se apuesta una
## ficha (la misma de la ruleta). Hay que acercarse a 21 sin pasarse: Pedir (carta), Plantarse y Doblar (sólo con las dos primeras cartas:
## otra ficha, una sola carta más y se planta). El crupier pide hasta tener 17 (se planta en todos los 17). Un 21 con las dos primeras cartas
## (blackjack) paga 3 a 2; ganar paga 1 a 1; empatar devuelve la apuesta. Sin dividir ni seguro.

const Roulette := preload("res://scripts/roulette.gd")
const Loc := preload("res://scripts/loc.gd")
const Rules := preload("res://scripts/casino_rules.gd")

enum Phase { IDLE, PLAYER, DONE }
enum Outcome { NONE, BLACKJACK, WIN, PUSH, LOSE, BUST }

const RANK_NAMES: Array[String] = ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SUITS := 4

var run
var rng: RandomNumberGenerator
var phase := Phase.IDLE
var deck: Array[Vector2i] = []        # (rango 1..13, palo 0..3)
var player: Array[Vector2i] = []
var dealer: Array[Vector2i] = []
var bet := 0
var stake := 1                        # fichas apostadas (sólo más de una con la regla "Apuesta libre")
var doubled := false
var hole_hidden := true               # la segunda carta del crupier está boca abajo mientras se juega
var outcome := Outcome.NONE
var result := {}


func _init(run_state = null, random: RandomNumberGenerator = null) -> void:
	run = run_state
	rng = random if random != null else RandomNumberGenerator.new()


## Valor de una mano: {total, soft} (soft: cuenta un as como 11).
static func value(hand: Array) -> Dictionary:
	var total := 0
	var aces := 0
	for c in hand:
		var r: int = c.x
		if r == 1:
			aces += 1
			total += 1
		else:
			total += mini(r, 10)
	var soft := false
	if aces > 0 and total + 10 <= 21:
		total += 10
		soft = true
	return {"total": total, "soft": soft}


static func is_blackjack(hand: Array) -> bool:
	return hand.size() == 2 and value(hand).total == 21


func _draw() -> Vector2i:
	if deck.is_empty():
		_shuffle()
	return deck.pop_back()


func _shuffle() -> void:
	deck.clear()
	for s in SUITS:
		for r in range(1, 14):
			deck.append(Vector2i(r, s))
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t := deck[i]
		deck[i] = deck[j]
		deck[j] = t


## Paga la apuesta y reparte (dos cartas a cada uno). {ok, error}. Si alguien tiene blackjack la mano termina enseguida.
func deal(forced_deck: Array = []) -> Dictionary:
	if phase == Phase.PLAYER:
		return {"ok": false, "error": Loc.t("Ya hay una mano en curso")}
	stake = Rules.stake(run)
	bet = Roulette.run_price(run) * stake
	if not run.can_afford(bet):
		return {"ok": false, "error": Loc.f("No alcanza la claridad (la ficha cuesta %d)", [bet])}
	run.spend(bet)
	run.casino_spent += bet
	if forced_deck.is_empty():
		_shuffle()
	else:   # (pruebas) el mazo se saca desde el final
		deck.assign(forced_deck)
	var p0 := _draw()   # se reparte de a una carta, como en la mesa: jugador, crupier, jugador, crupier
	var d0 := _draw()
	var p1 := _draw()
	var d1 := _draw()
	player = [p0, p1]
	dealer = [d0, d1]
	doubled = false
	hole_hidden = true
	outcome = Outcome.NONE
	result = {}
	phase = Phase.PLAYER
	if is_blackjack(player) or is_blackjack(dealer):
		_settle()
	return {"ok": true, "error": ""}


func can_double() -> bool:
	return phase == Phase.PLAYER and player.size() == 2 and run.can_afford(bet)


func hit() -> bool:
	if phase != Phase.PLAYER:
		return false
	player.append(_draw())
	if value(player).total >= 21:
		stand()
	return true


func double_down() -> bool:
	if not can_double():
		return false
	run.spend(bet)
	run.casino_spent += bet
	bet *= 2
	doubled = true
	player.append(_draw())
	stand()
	return true


## El jugador se planta: el crupier da vuelta su carta y pide hasta 17; se paga la mano.
func stand() -> void:
	if phase != Phase.PLAYER:
		return
	if value(player).total <= 21:
		while value(dealer).total < 17:
			dealer.append(_draw())
	_settle()


func _settle() -> void:
	hole_hidden = false
	phase = Phase.DONE
	var pv: int = value(player).total
	var dv: int = value(dealer).total
	var pbj := is_blackjack(player)
	var dbj := is_blackjack(dealer)
	var back := 0.0   # cuántas apuestas se devuelven (incluida la propia)
	if pv > 21:
		outcome = Outcome.BUST
	elif pbj and not dbj:
		outcome = Outcome.BLACKJACK
		back = 2.5
	elif dbj and not pbj:
		outcome = Outcome.LOSE
	elif dv > 21 or pv > dv:
		outcome = Outcome.WIN
		back = 2.0
	elif pv == dv:
		outcome = Outcome.PUSH
		back = 1.0
	else:
		outcome = Outcome.LOSE
	# `bet` ya incluye lo doblado: se devuelve en proporción a la apuesta total (el blackjack no puede doblarse)
	var reward := int(round(back * bet))
	run.gain(reward)
	run.casino_won += reward
	var rules: Dictionary = Rules.settle(run, bet, reward, outcome == Outcome.WIN or outcome == Outcome.BLACKJACK, outcome == Outcome.BLACKJACK)
	result = {"ok": true, "outcome": outcome, "player": pv, "dealer": dv, "bet": bet, "claridad": reward, "net": reward - bet + int(rules.total), "rules": rules}


static func outcome_text(o: int) -> String:
	match o:
		Outcome.BLACKJACK:
			return "¡Blackjack!"
		Outcome.WIN:
			return "¡Ganaste!"
		Outcome.PUSH:
			return "Empate: te devuelven la apuesta"
		Outcome.BUST:
			return "Te pasaste de 21"
		Outcome.LOSE:
			return "Ganó la casa"
	return ""


## Rendimiento esperado con la estrategia básica simplificada (pedir hasta 17 y doblar con 10 u 11): se calcula por simulación,
## para vigilar que el juego no regale ni robe.
static func simulate_rtp(hands: int, seed_value: int) -> float:
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = seed_value
	var spent := 0.0
	var won := 0.0
	for _i in hands:
		var g = load("res://scripts/blackjack.gd").new(_FakeRun.new(), rng2)
		g.deal()
		while g.phase == Phase.PLAYER:
			var pv: Dictionary = value(g.player)
			var up: int = mini(g.dealer[0].x, 10) if g.dealer[0].x != 1 else 11
			if g.can_double() and g.player.size() == 2 and (pv.total == 11 or (pv.total == 10 and up < 10)):
				g.double_down()
			elif pv.total < 12 or (pv.total < 17 and up >= 7) or (pv.total == 12 and up <= 3) or (pv.soft and pv.total < 18):
				g.hit()
			else:
				g.stand()
		spent += float(g.bet)
		won += float(g.result.claridad)
	return won / spent


## Una "partida" sin límite de claridad, para la simulación.
class _FakeRun:
	var casino_spent := 0
	var casino_won := 0
	func can_afford(_n: int) -> bool:
		return true
	func spend(_n: int) -> void:
		pass
	func gain(_n: int) -> void:
		pass
	var stage := 1
	var price_mult := 1.0
