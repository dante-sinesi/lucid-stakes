extends SceneTree
## Verificación a ojo: al perder por un movimiento se ve el movimiento y, al terminar, aparece la pantalla de derrota. Uso: ... -- PREFIJO
const Profile := preload("res://scripts/datos/profile.gd")
const Motor := preload("res://torre/motor.gd")
func _init() -> void:
	var pref: String = OS.get_cmdline_user_args()[0]
	Profile.path = "user://test_profile.json"
	Profile._loaded_from = ""
	Profile.mark_tutorial_done()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	main.start_game()
	await create_timer(0.5).timeout
	main.dice.auto_start = true
	main.dice.set_ready(true)
	await create_timer(1.5).timeout
	var m = Motor.crear(6, Vector3i(7, 2, 1))
	m.poner(Vector3i(9, 1, 1), "f")
	m.poner(Vector3i(8, 2, 1), "n")
	m.poner(Vector3i(7, 1, 1), "n")
	m.poner(Vector3i(6, 1, 1), "n")
	main.torre.t.motor = m
	main.torre._refrescar(false)
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png(pref + "_antes.png")
	main.torre.accion(Vector3i(1, 0, 0), Motor.Modo.AGARRAR)
	for k in 14:
		await create_timer(0.1).timeout
		print("t=", (k + 1) * 0.1, " bloques=", main.torre.vivo.get_children().map(func(n): return snappedf(n.position.x, 0.1) if n is Node3D else 0), " cae=", main.torre.get_children().size(), " gato=", main.torre.gato_nodo.position, " lost=", main.lost_screen.visible, " alpha=", main.lost_screen.box.modulate.a)
		root.get_texture().get_image().save_png("%s_%d.png" % [pref, k])
	quit(0)
