extends SceneTree
## Sonda: empujar un bloque que deja sin soporte la plataforma donde se está parado (¿se muestra la derrota?).
const Profile := preload("res://scripts/datos/profile.gd")
const Motor := preload("res://torre/motor.gd")
func _init() -> void:
	Profile.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	main.test_mode = true
	main.quick_portal = true
	root.add_child(main)
	for i in 4:
		await process_frame
	main.start_game()
	for i in 4:
		await process_frame
	var m = Motor.crear(6, Vector3i(7, 2, 1))
	m.poner(Vector3i(9, 1, 1), "f")
	m.poner(Vector3i(8, 2, 1), "n")
	m.poner(Vector3i(7, 1, 1), "n")
	m.bloques = m.bloques
	main.torre.t.motor = m
	print("antes: jugador ", m.jugador)
	var r: Dictionary = main.torre.accion(Vector3i(1, 0, 0), Motor.Modo.AGARRAR)
	print("resultado ", r, " muerta=", main.torre.t.muerta, " lost=", main.lost_screen.visible, " in_menu=", main.in_menu, " run_over=", main.run_over, " vidas=", main.run.lives)
	for i in 30:
		await process_frame
	print("despues: lost=", main.lost_screen.visible, " in_menu=", main.in_menu, " run_over=", main.run_over)
	quit(0)
