extends SceneTree
const Roulette := preload("res://scripts/casino/roulette.gd")
const Slots := preload("res://scripts/casino/slots.gd")
const Blackjack := preload("res://scripts/casino/blackjack.gd")
const Items := preload("res://scripts/datos/items.gd")


func _init() -> void:
	for bet in Roulette.BETS:
		print("ruleta %s: p=%.2f, valor medio del premio en etapa 1 = %.0f (ficha %d), rendimiento %.2f; etapa 15: %.2f" % [Roulette.BETS[bet].name, Roulette.probability(bet), Items.mean_value(Roulette.BETS[bet].tier, 50), 50, Roulette.expected_ratio(bet, 1), Roulette.expected_ratio(bet, 15)])
	print("tragamonedas rendimiento óptimo (reteniendo bien): %.3f" % Slots.optimal_rtp())
	print("blackjack rendimiento (estrategia simple): %.3f" % Blackjack.simulate_rtp(20000, 7))
	var claridad_only := 0.0
	quit(0)
