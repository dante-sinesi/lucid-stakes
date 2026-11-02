extends SceneTree
## Imprime por etapa: ficha, giro de ruleta, peaje, ingreso medido y lo que cuesta un premio común, raro y épico en la tienda (el valor medio de cada rareza).
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/sondas/precios_tienda.gd
const RunState := preload("res://scripts/datos/run_state.gd")
const Roulette := preload("res://scripts/casino/roulette.gd")
const Items := preload("res://scripts/datos/items.gd")
const Showcase := preload("res://scripts/casino/showcase.gd")


func _init() -> void:
	print("etapa ficha giro peaje ingreso | tienda común raro épico | sobra tras peaje")
	for e in range(1, 9):
		var run := RunState.new()
		run.stage = e
		var ficha := Roulette.run_price(run)
		var giro := Roulette.spin_price(run)
		var peaje := RunState.toll_for(e)
		var ing: int = RunState.INGRESO_MEDIDO[e - 1]
		var p := []
		for tier in [1, 2, 3]:
			p.append(int(round(float(Showcase.SHOP_FICHAS[tier]) * ficha)))   # (el precio de un premio medio de ese nivel)
		print("%d  %d  %d  %d  %d | %d %d %d | %d" % [e, ficha, giro, peaje, ing, p[0], p[1], p[2], ing - peaje])
	quit(0)
