extends SceneTree
## El cartel de ganancia (puntos y multiplicador) no se pierde aunque se gane en cada paso: un solo desvanecer a la vez.
var fails := 0


func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.quit_game_override = true
	main.test_mode = true
	root.add_child(main)
	await process_frame
	while main.generating or main.torre == null:
		await process_frame
	for i in 12:   # una ganancia cada ~0,3 s, durante unos 3,6 s (más que lo que dura un desvanecer)
		main._flash_gain("+%d x1.%d" % [i + 5, i])
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 300:
			await process_frame
	main._flash_gain("+9 x2.0")
	await process_frame
	await process_frame
	if main.gain_label.modulate.a < 0.9:
		fails += 1
		print("FAIL: el cartel de ganancia quedó casi transparente (%.2f) después de ganancias seguidas" % main.gain_label.modulate.a)
	print("test cartel de ganancia, fallos: ", fails)
	quit(1 if fails > 0 else 0)
