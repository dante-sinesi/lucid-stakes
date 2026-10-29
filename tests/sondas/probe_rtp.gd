extends SceneTree
const Roulette := preload("res://scripts/casino/roulette.gd")
const Slots := preload("res://scripts/casino/slots.gd")
const Blackjack := preload("res://scripts/casino/blackjack.gd")
const Items := preload("res://scripts/datos/items.gd")


func _init() -> void:
	print("ruleta: el giro cuesta %.1f fichas; casillas épicas %d, raras %d, comunes %d, bolsas %d" % [Roulette.spin_mult, Roulette.count_of(Items.Tier.EPICO), Roulette.count_of(Items.Tier.RARO), Roulette.count_of(Items.Tier.COMUN), Roulette.count_of(Items.Tier.CONSUMIBLE)])
	for tier in Roulette.TIER_ORDER:
		print("  %s: valor medio del premio = %.2f fichas (etapa 1: %.0f con ficha %d)" % [Roulette.TIER_NAMES[tier], Items.mean_value(tier, 50) / 50.0, Items.mean_value(tier, 50), 50])
	for st in [1, 3, 6, 10, 15]:
		print("  rendimiento esperado del giro, etapa %d: %.3f" % [st, Roulette.expected_ratio(st)])
	print("tragamonedas rendimiento óptimo (reteniendo bien): %.3f" % Slots.optimal_rtp())
	print("blackjack rendimiento (estrategia simple): %.3f" % Blackjack.simulate_rtp(20000, 7))
	var claridad_only := 0.0
	quit(0)
